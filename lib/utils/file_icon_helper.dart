import 'package:flutter/material.dart';

class FileIconHelper {
  static IconData getIcon(String extension) {
    final ext = extension.toLowerCase();
    
    // Documents
    if (ext == 'pdf') return Icons.picture_as_pdf;
    if (ext == 'doc' || ext == 'docx') return Icons.description;
    if (ext == 'rtf' || ext == 'odt') return Icons.article;
    if (ext == 'xps' || ext == 'oxps') return Icons.document_scanner;
    
    // Presentations
    if (ext == 'ppt' || ext == 'pptx' || ext == 'odp') return Icons.slideshow;
    
    // Spreadsheets
    if (ext == 'xls' || ext == 'xlsx' || ext == 'ods') return Icons.table_chart;
    if (ext == 'csv' || ext == 'tsv') return Icons.table_rows;
    
    // Plain Text & Code
    if (ext == 'txt' || ext == 'md') return Icons.notes;
    if (ext == 'xml' || ext == 'json' || ext == 'yaml' || ext == 'yml') return Icons.code;
    if (ext == 'tex') return Icons.functions;
    if (ext == 'log') return Icons.history;
    
    // eBooks
    if (ext == 'epub' || ext == 'mobi' || ext == 'azw' || ext == 'azw3' || ext == 'fb2') {
      return Icons.menu_book;
    }
    
    // Scanned Documents
    if (ext == 'djvu') return Icons.scanner;
    
    // Default
    return Icons.insert_drive_file;
  }

  static Color getColor(String extension) {
    final ext = extension.toLowerCase();
    
    // PDF - Red (existing)
    if (ext == 'pdf') return const Color(0xFFE65A4B);
    
    // Word/Text documents - Blue
    if (ext == 'doc' || ext == 'docx' || ext == 'rtf' || ext == 'odt' || ext == 'txt' || ext == 'md') {
      return const Color(0xFF2196F3);
    }
    
    // Presentations - Orange
    if (ext == 'ppt' || ext == 'pptx' || ext == 'odp') {
      return const Color(0xFFFF9800);
    }
    
    // Spreadsheets - Green
    if (ext == 'xls' || ext == 'xlsx' || ext == 'ods' || ext == 'csv' || ext == 'tsv') {
      return const Color(0xFF4CAF50);
    }
    
    // Code/Structured data - Purple
    if (ext == 'xml' || ext == 'json' || ext == 'yaml' || ext == 'yml' || ext == 'tex' || ext == 'log') {
      return const Color(0xFF9C27B0);
    }
    
    // eBooks - Teal
    if (ext == 'epub' || ext == 'mobi' || ext == 'azw' || ext == 'azw3' || ext == 'fb2') {
      return const Color(0xFF009688);
    }
    
    // Scanned Documents - Grey
    if (ext == 'djvu') return const Color(0xFF607D8B);
    
    // Default - Grey
    return const Color(0xFF607D8B);
  }

  static String getCategory(String extension) {
    final ext = extension.toLowerCase();
    
    if (ext == 'pdf' || ext == 'doc' || ext == 'docx' || ext == 'rtf' || ext == 'odt' || ext == 'xps' || ext == 'oxps') {
      return 'Document';
    }
    
    if (ext == 'ppt' || ext == 'pptx' || ext == 'odp') {
      return 'Presentation';
    }
    
    if (ext == 'xls' || ext == 'xlsx' || ext == 'ods' || ext == 'csv' || ext == 'tsv') {
      return 'Spreadsheet';
    }
    
    if (ext == 'txt' || ext == 'md' || ext == 'xml' || ext == 'json' || ext == 'yaml' || ext == 'yml' || ext == 'tex' || ext == 'log') {
      return 'Text';
    }
    
    if (ext == 'epub' || ext == 'mobi' || ext == 'azw' || ext == 'azw3' || ext == 'fb2') {
      return 'eBook';
    }
    
    if (ext == 'djvu') {
      return 'Scanned';
    }
    
    return 'File';
  }

  static bool isTextFile(String extension) {
    final ext = extension.toLowerCase();
    const textExtensions = ['txt', 'md', 'xml', 'json', 'yaml', 'yml', 'tex', 'log', 'csv', 'tsv'];
    return textExtensions.contains(ext);
  }

  static bool isPdfFile(String extension) {
    return extension.toLowerCase() == 'pdf';
  }

  static bool isAiSupportedFile(String extension) {
    final ext = extension.toLowerCase();
    const supported = [
      'pdf', 'docx', 'doc', 'pptx', 'ppt', 'txt', 'md',
      'xml', 'json', 'yaml', 'yml', 'csv', 'tsv', 'xlsx', 'xls', 'epub', 'rtf'
    ];
    return supported.contains(ext);
  }
}
