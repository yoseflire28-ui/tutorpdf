import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'base_engine.dart';

class PdfEngine extends StatelessWidget {
  final String filePath;
  final bool isDarkMode;

  const PdfEngine({
    super.key,
    required this.filePath,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final canvasBg = isDarkMode ? EngineColors.darkCanvas : EngineColors.lightCanvas;

    Widget pdfView = SfPdfViewer.file(
      File(filePath),
      canShowScrollHead: true,
      canShowScrollStatus: true,
      canShowPaginationDialog: true,
      pageSpacing: 8,
      enableTextSelection: true,
    );

    if (isDarkMode) {
      pdfView = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1,  0,  0, 0, 255,
           0, -1,  0, 0, 255,
           0,  0, -1, 0, 255,
           0,  0,  0, 1,   0,
        ]),
        child: pdfView,
      );
    }

    return Container(
      color: canvasBg,
      child: pdfView,
    );
  }
}
