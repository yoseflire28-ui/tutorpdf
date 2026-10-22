import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/document.dart';
import '../data/providers/active_document_provider.dart';
import '../presentation/pdf_viewer_screen.dart';
import '../presentation/screens/docx_reader_screen.dart';
import '../presentation/screens/pptx_viewer_screen.dart';
import '../presentation/screens/embedded_document_reader_screen.dart';
import '../services/document_picker_service.dart';

/// Refactored Document Router
/// Inspects explicit document.fileExtension or document.mimeType
/// to route cleanly without path-splitting raw content URIs.
void openDocumentFromModel(BuildContext context, Document doc) {
  // Synchronize with global ActiveDocumentProvider
  try {
    Provider.of<ActiveDocumentProvider>(context, listen: false).setActiveDocument(doc);
  } catch (e) {
    debugPrint('[DocumentRouter] Could not sync active document: $e');
  }
  final ext = doc.fileExtension.toLowerCase();
  final mime = doc.mimeType.toLowerCase();

  Widget destinationScreen;

  if (ext == 'pdf' || mime == 'application/pdf') {
    destinationScreen = PdfViewerScreen(
      uri: doc.uriString,
      title: doc.displayName,
    );
  } else if (ext == 'docx' || ext == 'doc' ||
             mime == 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ||
             mime == 'application/msword') {
    destinationScreen = DocxReaderScreen(
      uri: doc.uriString,
      title: doc.displayName,
    );
  } else if (ext == 'pptx' || ext == 'ppt' ||
             mime == 'application/vnd.openxmlformats-officedocument.presentationml.presentation' ||
             mime == 'application/vnd.ms-powerpoint') {
    destinationScreen = PptxViewerScreen(
      uri: doc.uriString,
      title: doc.displayName,
    );
  } else {
    destinationScreen = EmbeddedDocumentReaderScreen(
      filePath: doc.uriString,
      fileName: doc.displayName,
    );
  }

  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => destinationScreen),
  );
}

/// Overload opening via file path / URI with optional metadata
void openDocument(
  BuildContext context,
  String filePath, {
  String? displayName,
  String? fileExtension,
  String? mimeType,
}) {
  String title = displayName ?? '';
  if (title.isEmpty) {
    if (!filePath.startsWith('content://') && filePath.contains('/')) {
      title = filePath.split('/').last;
    } else {
      title = 'Document';
    }
  }

  String ext = (fileExtension ?? '').toLowerCase();
  if (ext.isEmpty && title.contains('.')) {
    ext = title.split('.').last.toLowerCase();
  }

  String mime = (mimeType ?? '').toLowerCase();
  if (ext.isEmpty && mime.isNotEmpty) {
    ext = DocumentPickerService.extensionFromMimeType(mime) ?? '';
  }

  final doc = Document(
    id: '',
    displayName: title,
    fileExtension: ext,
    mimeType: mime,
    uriString: filePath,
    lastOpened: DateTime.now().toIso8601String(),
  );

  openDocumentFromModel(context, doc);
}
