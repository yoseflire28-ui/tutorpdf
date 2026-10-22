import 'package:flutter/material.dart';
import '../../../core/utils/file_type_detector.dart';
import 'pdf_engine.dart';
import 'docx_engine.dart';
import 'doc_engine.dart';
import 'xlsx_engine.dart';
import 'xls_engine.dart';
import 'pptx_engine.dart';
import 'ppt_engine.dart';
import 'epub_engine.dart';
import 'odt_engine.dart';
import 'ods_engine.dart';
import 'odp_engine.dart';
import 'rtf_engine.dart';
import 'txt_engine.dart';
import 'markdown_engine.dart';
import 'html_engine.dart';
import 'csv_engine.dart';
import 'universal_document_controller.dart';

/// Document Engine Factory & Router
/// Instantiates the modular engine widget based on DocumentType and injects theme mode.
class DocumentEngineFactory {
  static Widget create({
    required String filePath,
    required DocumentType documentType,
    required bool isDarkMode,
    UniversalDocumentController? controller,
  }) {
    switch (documentType) {
      case DocumentType.pdf:
        return PdfEngine(
          filePath: filePath,
          isDarkMode: isDarkMode,
        );
      case DocumentType.docx:
        return DocxEngine(
          filePath: filePath,
          isDarkMode: isDarkMode,
          controller: controller,
        );
      case DocumentType.doc:
        return DocEngine(
          filePath: filePath,
          isDarkMode: isDarkMode,
        );
      case DocumentType.xlsx:
        return XlsxEngine(
          filePath: filePath,
          isDarkMode: isDarkMode,
          controller: controller,
        );
      case DocumentType.xls:
        return XlsEngine(
          filePath: filePath,
          isDarkMode: isDarkMode,
        );
      case DocumentType.pptx:
        return PptxEngine(
          filePath: filePath,
          isDarkMode: isDarkMode,
          controller: controller,
        );
      case DocumentType.ppt:
        return PptEngine(
          filePath: filePath,
          isDarkMode: isDarkMode,
        );
      case DocumentType.epub:
        return EpubEngine(
          filePath: filePath,
          isDarkMode: isDarkMode,
        );
      case DocumentType.odt:
        return OdtEngine(
          filePath: filePath,
          isDarkMode: isDarkMode,
        );
      case DocumentType.ods:
        return OdsEngine(
          filePath: filePath,
          isDarkMode: isDarkMode,
        );
      case DocumentType.odp:
        return OdpEngine(
          filePath: filePath,
          isDarkMode: isDarkMode,
        );
      case DocumentType.rtf:
        return RtfEngine(
          filePath: filePath,
          isDarkMode: isDarkMode,
        );
      case DocumentType.txt:
        return TxtEngine(
          filePath: filePath,
          isDarkMode: isDarkMode,
        );
      case DocumentType.markdown:
        return MarkdownEngine(
          filePath: filePath,
          isDarkMode: isDarkMode,
        );
      case DocumentType.html:
        return HtmlEngine(
          filePath: filePath,
          isDarkMode: isDarkMode,
        );
      case DocumentType.csv:
        return CsvEngine(
          filePath: filePath,
          isDarkMode: isDarkMode,
        );
    }
  }
}
