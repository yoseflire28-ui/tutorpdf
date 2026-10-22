import 'package:flutter/material.dart';

class Document {
  final String id;
  final String displayName;
  final String fileExtension;
  final String mimeType;
  final String uriString;
  final int totalPages;
  final int currentPage;
  final bool isFavorite;
  final String lastOpened;

  const Document({
    dynamic id,
    String? displayName,
    String? fileExtension,
    String? mimeType,
    String? uriString,
    String? fileName,
    String? filePath,
    String? fileType,
    this.totalPages = 0,
    this.currentPage = 0,
    this.isFavorite = false,
    required this.lastOpened,
  })  : id = id == null ? '' : '$id',
        displayName = displayName ?? fileName ?? '',
        fileExtension = fileExtension ?? fileType ?? '',
        mimeType = mimeType ?? '',
        uriString = uriString ?? filePath ?? '';

  // Backwards compatibility getters
  String get fileName => displayName;
  String get filePath => uriString;
  String get fileType => fileExtension;

  double get completionPercent =>
      totalPages == 0 ? 0.0 : (currentPage / totalPages).clamp(0.0, 1.0);

  Document copyWith({
    String? id,
    String? displayName,
    String? fileExtension,
    String? mimeType,
    String? uriString,
    String? fileName,
    String? filePath,
    String? fileType,
    int? totalPages,
    int? currentPage,
    bool? isFavorite,
    String? lastOpened,
  }) {
    return Document(
      id: id ?? this.id,
      displayName: displayName ?? fileName ?? this.displayName,
      fileExtension: fileExtension ?? fileType ?? this.fileExtension,
      mimeType: mimeType ?? this.mimeType,
      uriString: uriString ?? filePath ?? this.uriString,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      isFavorite: isFavorite ?? this.isFavorite,
      lastOpened: lastOpened ?? this.lastOpened,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'display_name': displayName,
      'file_name': displayName,
      'file_extension': fileExtension,
      'file_type': fileExtension,
      'mime_type': mimeType,
      'uri_string': uriString,
      'file_path': uriString,
      'total_pages': totalPages,
      'current_page': currentPage,
      'is_favorite': isFavorite ? 1 : 0,
      'last_opened': lastOpened,
    };
    if (id.isNotEmpty) {
      final parsedId = int.tryParse(id);
      map['id'] = parsedId ?? id;
    }
    return map;
  }

  factory Document.fromMap(Map<String, dynamic> map) {
    final rawId = map['id']?.toString() ?? '';
    final displayNameVal = (map['display_name'] as String?) ?? (map['file_name'] as String?) ?? '';
    final fileExtensionVal = (map['file_extension'] as String?) ?? (map['file_type'] as String?) ?? '';
    final mimeTypeVal = (map['mime_type'] as String?) ?? '';
    final uriStringVal = (map['uri_string'] as String?) ?? (map['file_path'] as String?) ?? '';

    return Document(
      id: rawId,
      displayName: displayNameVal,
      fileExtension: fileExtensionVal,
      mimeType: mimeTypeVal,
      uriString: uriStringVal,
      totalPages: map['total_pages'] as int? ?? 0,
      currentPage: map['current_page'] as int? ?? 0,
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      lastOpened: (map['last_opened'] as String?) ?? DateTime.now().toIso8601String(),
    );
  }

  /// Get the appropriate icon for this document type
  IconData get icon {
    final ext = fileType.toLowerCase();
    
    // Documents
    if (ext == 'pdf') return Icons.picture_as_pdf;
    if (ext == 'doc' || ext == 'docx') return Icons.description;
    if (ext == 'rtf') return Icons.text_snippet;
    if (ext == 'odt') return Icons.article;
    
    // Presentations
    if (ext == 'ppt' || ext == 'pptx' || ext == 'odp') return Icons.slideshow;
    
    // Spreadsheets
    if (ext == 'xls' || ext == 'xlsx' || ext == 'ods') return Icons.table_chart;
    if (ext == 'csv' || ext == 'tsv') return Icons.table_rows;
    
    // Text & Code
    if (ext == 'txt') return Icons.text_fields;
    if (ext == 'md') return Icons.article;
    if (ext == 'xml' || ext == 'json' || ext == 'yaml' || ext == 'yml') return Icons.code;
    if (ext == 'tex') return Icons.functions;
    if (ext == 'log' || ext == 'ini' || ext == 'cfg') return Icons.terminal;
    
    // eBooks
    if (ext == 'epub' || ext == 'mobi' || ext == 'azw' || ext == 'azw3' || ext == 'fb2') {
      return Icons.menu_book;
    }
    
    // Scanned documents
    if (ext == 'djvu') return Icons.scanner;
    
    // XPS documents
    if (ext == 'xps' || ext == 'oxps') return Icons.document_scanner;
    
    // Default
    return Icons.insert_drive_file;
  }

  /// Get the display category for this document type
  String get category {
    final ext = fileType.toLowerCase();
    
    if (ext == 'pdf') return 'PDF Document';
    if (ext == 'doc' || ext == 'docx' || ext == 'rtf' || ext == 'odt') return 'Document';
    if (ext == 'ppt' || ext == 'pptx' || ext == 'odp') return 'Presentation';
    if (ext == 'xls' || ext == 'xlsx' || ext == 'ods' || ext == 'csv' || ext == 'tsv') {
      return 'Spreadsheet';
    }
    if (ext == 'txt' || ext == 'md' || ext == 'log' || ext == 'ini' || ext == 'cfg') {
      return 'Text File';
    }
    if (ext == 'xml' || ext == 'json' || ext == 'yaml' || ext == 'yml' || ext == 'tex') {
      return 'Code/Data';
    }
    if (ext == 'epub' || ext == 'mobi' || ext == 'azw' || ext == 'azw3' || ext == 'fb2') {
      return 'eBook';
    }
    if (ext == 'djvu' || ext == 'xps' || ext == 'oxps') return 'Scanned Document';
    
    return 'File';
  }

  /// Check if this file type can be viewed directly in the app
  bool get canViewDirectly {
    final ext = fileType.toLowerCase();
    return ext == 'pdf' || 
           ext == 'txt' || 
           ext == 'md' || 
           ext == 'xml' || 
           ext == 'json' || 
           ext == 'yaml' || 
           ext == 'yml' ||
           ext == 'log' ||
           ext == 'ini' ||
           ext == 'cfg';
  }

  /// Check if this file type requires external viewer
  bool get requiresExternalViewer {
    return !canViewDirectly;
  }
}