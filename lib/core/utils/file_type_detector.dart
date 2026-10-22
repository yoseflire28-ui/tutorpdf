import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

/// 16 Document Formats Supported by TutorPDF
enum DocumentType {
  pdf,
  docx,
  doc,
  xlsx,
  xls,
  pptx,
  ppt,
  epub,
  odt,
  ods,
  odp,
  rtf,
  txt,
  markdown,
  html,
  csv,
}

class FileTypeDetector {
  /// Detect DocumentType using Magic Header Bytes and File Extension fallback
  static Future<DocumentType> detect(String filePath) async {
    final ext = path.extension(filePath).replaceAll('.', '').toLowerCase();
    final file = File(filePath);

    if (await file.exists()) {
      try {
        final length = await file.length();
        if (length > 0) {
          final bytes = await file.openRead(0, length > 64 ? 64 : length).first;
          final headerStr = String.fromCharCodes(bytes);

          // 1. PDF Check (%PDF-)
          if (bytes.length >= 4 &&
              bytes[0] == 0x25 &&
              bytes[1] == 0x50 &&
              bytes[2] == 0x44 &&
              bytes[3] == 0x46) {
            return DocumentType.pdf;
          }

          // 2. RTF Check ({\rtf)
          if (headerStr.startsWith(r'{\rtf')) {
            return DocumentType.rtf;
          }

          // 3. HTML Check (<!DOC or <html or <HTML)
          final lowerHeader = headerStr.toLowerCase();
          if (lowerHeader.startsWith('<!doc') ||
              lowerHeader.startsWith('<html') ||
              lowerHeader.contains('<head') ||
              lowerHeader.contains('<body')) {
            return DocumentType.html;
          }

          // 4. PK\x03\x04 ZIP Containers (DOCX, XLSX, PPTX, EPUB, ODT, ODS, ODP)
          if (bytes.length >= 4 &&
              bytes[0] == 0x50 &&
              bytes[1] == 0x4B &&
              bytes[2] == 0x03 &&
              bytes[3] == 0x04) {
            // Differentiate ZIP-based containers using extension hint
            switch (ext) {
              case 'docx':
                return DocumentType.docx;
              case 'xlsx':
                return DocumentType.xlsx;
              case 'pptx':
                return DocumentType.pptx;
              case 'epub':
                return DocumentType.epub;
              case 'odt':
                return DocumentType.odt;
              case 'ods':
                return DocumentType.ods;
              case 'odp':
                return DocumentType.odp;
              default:
                break;
            }
          }
        }
      } catch (_) {
        // Fallback to extension on file read error
      }
    }

    // Extension-based fallback classification
    return fromExtension(ext);
  }

  /// Synchronous fallback classification via extension
  static DocumentType fromExtension(String extension) {
    final ext = extension.replaceAll('.', '').toLowerCase();
    switch (ext) {
      case 'pdf':
        return DocumentType.pdf;
      case 'docx':
        return DocumentType.docx;
      case 'doc':
        return DocumentType.doc;
      case 'xlsx':
        return DocumentType.xlsx;
      case 'xls':
        return DocumentType.xls;
      case 'pptx':
        return DocumentType.pptx;
      case 'ppt':
        return DocumentType.ppt;
      case 'epub':
        return DocumentType.epub;
      case 'odt':
        return DocumentType.odt;
      case 'ods':
        return DocumentType.ods;
      case 'odp':
        return DocumentType.odp;
      case 'rtf':
        return DocumentType.rtf;
      case 'txt':
      case 'log':
      case 'conf':
      case 'ini':
        return DocumentType.txt;
      case 'md':
      case 'markdown':
        return DocumentType.markdown;
      case 'html':
      case 'htm':
      case 'xhtml':
        return DocumentType.html;
      case 'csv':
      case 'tsv':
        return DocumentType.csv;
      default:
        return DocumentType.txt;
    }
  }

  /// Get uppercase display label (e.g. .PDF, .DOCX)
  static String getBadgeLabel(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return '.PDF';
      case DocumentType.docx:
        return '.DOCX';
      case DocumentType.doc:
        return '.DOC';
      case DocumentType.xlsx:
        return '.XLSX';
      case DocumentType.xls:
        return '.XLS';
      case DocumentType.pptx:
        return '.PPTX';
      case DocumentType.ppt:
        return '.PPT';
      case DocumentType.epub:
        return '.EPUB';
      case DocumentType.odt:
        return '.ODT';
      case DocumentType.ods:
        return '.ODS';
      case DocumentType.odp:
        return '.ODP';
      case DocumentType.rtf:
        return '.RTF';
      case DocumentType.txt:
        return '.TXT';
      case DocumentType.markdown:
        return '.MD';
      case DocumentType.html:
        return '.HTML';
      case DocumentType.csv:
        return '.CSV';
    }
  }

  /// Distinct format colors
  static Color getBadgeColor(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return const Color(0xFFE65A4B); // Coral Red
      case DocumentType.docx:
      case DocumentType.doc:
      case DocumentType.odt:
        return const Color(0xFF2B579A); // Word Blue
      case DocumentType.xlsx:
      case DocumentType.xls:
      case DocumentType.ods:
        return const Color(0xFF217346); // Excel Green
      case DocumentType.pptx:
      case DocumentType.ppt:
      case DocumentType.odp:
        return const Color(0xFFD24726); // PowerPoint Orange
      case DocumentType.epub:
        return const Color(0xFF8E44AD); // EPUB Purple
      case DocumentType.rtf:
      case DocumentType.txt:
        return const Color(0xFF7F8C8D); // Slate Grey
      case DocumentType.markdown:
        return const Color(0xFF2980B9); // Markdown Ocean Blue
      case DocumentType.html:
        return const Color(0xFFE67E22); // HTML Amber
      case DocumentType.csv:
        return const Color(0xFF16A085); // CSV Teal
    }
  }

  /// Category name for metadata
  static String getCategory(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return 'PDF Document';
      case DocumentType.docx:
      case DocumentType.doc:
      case DocumentType.odt:
      case DocumentType.rtf:
        return 'Word Document';
      case DocumentType.xlsx:
      case DocumentType.xls:
      case DocumentType.ods:
      case DocumentType.csv:
        return 'Spreadsheet';
      case DocumentType.pptx:
      case DocumentType.ppt:
      case DocumentType.odp:
        return 'Presentation';
      case DocumentType.epub:
        return 'E-Book';
      case DocumentType.txt:
      case DocumentType.markdown:
      case DocumentType.html:
        return 'Text & Web';
    }
  }
}
