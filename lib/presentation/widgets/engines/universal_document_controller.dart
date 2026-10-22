import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;

enum DocumentFormat { docx, pptx, xlsx, txt, epub, pdf, unknown }

/// 20. CONTROLLER BRIDGE ARCHITECTURE: Connects UI to format-specific engines.
class UniversalDocumentController extends ChangeNotifier {
  final String filePath;
  bool isLoading = true;
  String? errorMessage;
  DocumentFormat format = DocumentFormat.unknown;

  // 1. FILE ACCESS LAYER: Byte streams
  Uint8List? fileBytes;
  Archive? decodedArchive;

  // 17. DECOUPLED SEARCH & AI ENGINE: Text extraction pipeline
  String plainText = '';
  
  // Visual state
  double fontSize = 16.0;
  bool isDarkMode = false;
  int currentPageIndex = 0;
  int totalPageCount = 1;

  UniversalDocumentController({
    required this.filePath,
    this.fontSize = 16.0,
    this.isDarkMode = false,
  }) {
    _initController();
  }

  Future<void> _initController() async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception("File does not exist: $filePath");
      }

      // 1. Storage Access (Simulated via File read)
      fileBytes = await file.readAsBytes();
      
      // 2. FORMAT DETECTION: Magic-byte signatures
      format = _detectFormat(fileBytes!);

      // 3. NATIVE FORMAT PARSERS (Pre-decoding for Zip based formats)
      if (format == DocumentFormat.docx ||
          format == DocumentFormat.pptx ||
          format == DocumentFormat.xlsx) {
        decodedArchive = ZipDecoder().decodeBytes(fileBytes!);
      }

      isLoading = false;
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      isLoading = false;
      notifyListeners();
    }
  }

  DocumentFormat _detectFormat(Uint8List bytes) {
    if (bytes.length < 4) return DocumentFormat.unknown;

    // PDF: %PDF-
    if (bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) {
      return DocumentFormat.pdf;
    }

    // OpenXML: PK\x03\x04
    if (bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04) {
      final ext = path.extension(filePath).toLowerCase();
      if (ext == '.docx') return DocumentFormat.docx;
      if (ext == '.pptx') return DocumentFormat.pptx;
      if (ext == '.xlsx') return DocumentFormat.xlsx;
      return DocumentFormat.docx; // Default Zip based
    }

    final ext = path.extension(filePath).toLowerCase();
    if (ext == '.txt' || ext == '.csv') return DocumentFormat.txt;
    if (ext == '.epub') return DocumentFormat.epub;

    return DocumentFormat.unknown;
  }

  void setPlainText(String text) {
    plainText = text;
    // Don't notify here to avoid build loops, engines call this during build or post-frame
  }

  void updatePage(int index, int total) {
    currentPageIndex = index;
    totalPageCount = total;
    notifyListeners();
  }

  void toggleDarkMode(bool value) {
    isDarkMode = value;
    notifyListeners();
  }

  void retryLoading() {
    _initController();
  }
}
