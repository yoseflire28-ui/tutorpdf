import 'package:flutter/material.dart';
import '../models/document.dart';
import 'document_router.dart' as router;

/// Unified document navigation logic shared across HomeScreen, FilesScreen, etc.
class DocumentNavigation {
  static Future<void> openDocument(BuildContext context, Document doc) async {
    router.openDocumentFromModel(context, doc);
  }
}
