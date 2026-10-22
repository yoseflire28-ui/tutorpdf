import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../utils/document_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static Future<void> handleFileTap(BuildContext context, String filePath, {String? fileName}) async {
    openDocument(context, filePath);
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
