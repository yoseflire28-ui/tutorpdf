import 'dart:io';
import 'package:archive/archive.dart';
import 'file_type_detector.dart';

/// Magic-Byte & Stream Header Format Detector
/// Resolves document types via byte signatures and ZIP archive inspection
class FileSignatureDetector {
  static const List<int> pdfMagic = [0x25, 0x50, 0x44, 0x46]; // %PDF
  static const List<int> zipMagic = [0x50, 0x4B, 0x03, 0x04]; // PK\x03\x04
  static const List<int> ole2Magic = [0xD0, 0xCF, 0x11, 0xE0]; // Legacy binary Office

  /// Detect DocumentType by inspecting magic bytes
  static Future<DocumentType> detectFromBytesOrFile(String filePath, {List<int>? headerBytes}) async {
    List<int> bytes = headerBytes ?? [];

    if (bytes.isEmpty) {
      final file = File(filePath);
      if (await file.exists()) {
        try {
          final length = await file.length();
          if (length > 0) {
            bytes = await file.openRead(0, length > 2048 ? 2048 : length).first;
          }
        } catch (_) {}
      }
    }

    if (bytes.length >= 4) {
      // 1. PDF Signature
      if (bytes[0] == pdfMagic[0] &&
          bytes[1] == pdfMagic[1] &&
          bytes[2] == pdfMagic[2] &&
          bytes[3] == pdfMagic[3]) {
        return DocumentType.pdf;
      }

      // 2. OLE2 Compound Document Header (Legacy .doc, .xls, .ppt)
      if (bytes[0] == ole2Magic[0] &&
          bytes[1] == ole2Magic[1] &&
          bytes[2] == ole2Magic[2] &&
          bytes[3] == ole2Magic[3]) {
        final ext = filePath.split('.').last.toLowerCase();
        if (ext == 'xls') return DocumentType.xls;
        if (ext == 'ppt') return DocumentType.ppt;
        return DocumentType.doc;
      }

      // 3. ZIP Archive Inspection (DOCX, XLSX, PPTX, EPUB, ODF)
      if (bytes[0] == zipMagic[0] &&
          bytes[1] == zipMagic[1] &&
          bytes[2] == zipMagic[2] &&
          bytes[3] == zipMagic[3]) {
        return await _detectZipFormat(filePath);
      }

      // 4. RTF Signature
      final headerStr = String.fromCharCodes(bytes.take(32));
      if (headerStr.startsWith(r'{\rtf')) {
        return DocumentType.rtf;
      }

      // 5. HTML Signature
      final lowerStr = headerStr.toLowerCase();
      if (lowerStr.contains('<!doc') || lowerStr.contains('<html') || lowerStr.contains('<body')) {
        return DocumentType.html;
      }
    }

    return FileTypeDetector.fromExtension(filePath.split('.').last);
  }

  /// Inspect ZIP structure to differentiate OpenXML/EPUB/ODF
  static Future<DocumentType> _detectZipFormat(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return FileTypeDetector.fromExtension(filePath.split('.').last);
      }

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (var entry in archive.files) {
        final name = entry.name.toLowerCase();

        if (name.startsWith('word/')) return DocumentType.docx;
        if (name.startsWith('ppt/')) return DocumentType.pptx;
        if (name.startsWith('xl/')) return DocumentType.xlsx;
        if (name.contains('meta-inf/') || name == 'mimetype' && String.fromCharCodes(entry.content).contains('epub')) {
          return DocumentType.epub;
        }

        if (name == 'mimetype') {
          final content = String.fromCharCodes(entry.content);
          if (content.contains('opendocument.text')) return DocumentType.odt;
          if (content.contains('opendocument.spreadsheet')) return DocumentType.ods;
          if (content.contains('opendocument.presentation')) return DocumentType.odp;
        }
      }
    } catch (_) {}

    return FileTypeDetector.fromExtension(filePath.split('.').last);
  }
}
