import 'package:flutter/material.dart';
import '../presentation/screens/files_screen.dart';
import '../utils/document_router.dart';

class FilesPage extends StatelessWidget {
  const FilesPage({super.key});

  static Future<void> handleFileTap(BuildContext context, String filePath, {String? fileName}) async {
    openDocument(context, filePath);
  }

  @override
  Widget build(BuildContext context) {
    return const FilesScreen();
  }
}
