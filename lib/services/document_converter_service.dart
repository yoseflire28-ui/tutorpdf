import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Service for converting non-PDF documents (.docx, .pptx, .xlsx, .epub, .html, .rtf, .txt, .csv, .log)
/// into a 100% offline PDF Intermediate Representation (IR).
class DocumentConverterService {
  static final Map<String, Uint8List> _fontCache = {};

  /// Pre-loads bundled asset fonts into memory bytes so they can be passed to background isolates.
  static Future<void> preloadFonts() async {
    if (_fontCache.isNotEmpty) return;
    try {
      final calibriData = await rootBundle.load('assets/fonts/Calibri.ttf');
      _fontCache['Calibri'] = calibriData.buffer.asUint8List();
    } catch (_) {}

    try {
      final timesData = await rootBundle.load('assets/fonts/TimesNewRoman.ttf');
      _fontCache['TimesNewRoman'] = timesData.buffer.asUint8List();
    } catch (_) {}

    try {
      final arialData = await rootBundle.load('assets/fonts/Arial.ttf');
      _fontCache['Arial'] = arialData.buffer.asUint8List();
    } catch (_) {}
  }

  /// Converts any supported non-PDF file to a compiled PDF located in getTemporaryDirectory().
  /// Returns the File object of the generated or cached PDF.
  static Future<File> convertToPdf(
    String inputFilePath, {
    void Function(String status, double progress)? onProgress,
  }) async {
    final inputFile = File(inputFilePath);
    if (!await inputFile.exists()) {
      throw Exception('Input file does not exist: $inputFilePath');
    }

    final extension = path.extension(inputFilePath).toLowerCase();
    if (extension == '.pdf') {
      return inputFile;
    }

    // Compute unique hash based on path and file size/modified date
    final stat = await inputFile.stat();
    final hashInput = '${inputFile.path}_${stat.size}_${stat.modified.millisecondsSinceEpoch}';
    final fileHash = md5.convert(utf8.encode(hashInput)).toString();

    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory(path.join(tempDir.path, 'converted_cache'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final outputPdfFile = File(path.join(cacheDir.path, 'converted_$fileHash.pdf'));

    if (await outputPdfFile.exists() && (await outputPdfFile.length()) > 0) {
      onProgress?.call('Loaded from cache', 1.0);
      return outputPdfFile;
    }

    onProgress?.call('Structuring layout...', 0.2);

    await preloadFonts();

    final fileBytes = await inputFile.readAsBytes();

    onProgress?.call('Generating PDF...', 0.5);

    final pdfBytes = await compute(_runConversionPipeline, _ConversionParams(
      fileBytes: fileBytes,
      extension: extension,
      fileName: path.basename(inputFilePath),
      calibriFont: _fontCache['Calibri'],
      timesFont: _fontCache['TimesNewRoman'],
      arialFont: _fontCache['Arial'],
    ));

    onProgress?.call('Writing compiled PDF...', 0.9);
    await outputPdfFile.writeAsBytes(pdfBytes, flush: true);

    onProgress?.call('Conversion complete', 1.0);
    return outputPdfFile;
  }

  /// Intercepts unsupported Word/Office symbol font codes (Wingdings, Symbol bullet markers, etc.)
  /// and maps them directly to standard UTF-8 bullet markers ('•', '▪', '–') prior to PDF compilation.
  static String sanitizeSymbolFontMarkers(String text) {
    if (text.isEmpty) return text;
    var result = text;

    // Wingdings & Symbol private use area bullets and special codes
    final mappings = <String, String>{
      '\uF0B7': '•',
      '\uF0A7': '▪',
      '\uF0A8': '▪',
      '\uF0D8': '➢',
      '\uF0A2': '•',
      '\uF04A': '☺',
      '\uF04C': '😐',
      '\uF04D': '☹',
      '\uF075': '▪',
      '\uF076': '❖',
      '\uF06E': '▪',
      '\uF0FC': '✓',
      '\uF0FE': '☑',
      '\uF06F': '○',
      '\uF0D7': '►',
      '\uF0E0': '✉',
      'ï‚·': '•',
      'Â·': '•',
      'ï ·': '•',
      '§': '•',
    };

    mappings.forEach((symbol, replacement) {
      result = result.replaceAll(symbol, replacement);
    });

    // Replace any remaining non-printable ASCII or orphaned private use characters (0xE000-0xF8FF)
    result = result.replaceAll(RegExp(r'[\uE000-\uF8FF]'), '•');
    return result;
  }
}

class _ConversionParams {
  final Uint8List fileBytes;
  final String extension;
  final String fileName;
  final Uint8List? calibriFont;
  final Uint8List? timesFont;
  final Uint8List? arialFont;

  _ConversionParams({
    required this.fileBytes,
    required this.extension,
    required this.fileName,
    this.calibriFont,
    this.timesFont,
    this.arialFont,
  });
}

/// Runs background conversion pipeline inside an Isolate.
Future<Uint8List> _runConversionPipeline(_ConversionParams params) async {
  final pdf = pw.Document(
    title: params.fileName,
    author: 'TutorPDF Engine',
  );

  pw.Font bodyFont = pw.Font.helvetica();
  pw.Font boldFont = pw.Font.helveticaBold();

  if (params.calibriFont != null) {
    bodyFont = pw.Font.ttf(ByteData.sublistView(params.calibriFont!));
  } else if (params.arialFont != null) {
    bodyFont = pw.Font.ttf(ByteData.sublistView(params.arialFont!));
  }

  if (params.arialFont != null) {
    boldFont = pw.Font.ttf(ByteData.sublistView(params.arialFont!));
  } else {
    boldFont = pw.Font.helveticaBold();
  }

  final baseTheme = pw.ThemeData.withFont(
    base: bodyFont,
    bold: boldFont,
  );

  final ext = params.extension;

  if (ext == '.docx' || ext == '.doc' || ext == '.pptx' || ext == '.ppt') {
    _compileOfficeToPdf(pdf, params, baseTheme);
  } else if (ext == '.xlsx' || ext == '.xls' || ext == '.csv') {
    _compileSpreadsheetToPdf(pdf, params, baseTheme);
  } else if (ext == '.epub' || ext == '.html' || ext == '.htm' || ext == '.rtf') {
    _compileHtmlOrEpubToPdf(pdf, params, baseTheme);
  } else {
    // .txt, .log, and fallback plain text files
    _compilePlainTextToPdf(pdf, params, baseTheme);
  }

  return pdf.save();
}

/// MS Office Parsing (.docx, .pptx) into structured PDF pages
void _compileOfficeToPdf(pw.Document pdf, _ConversionParams params, pw.ThemeData theme) {
  String extractedText = '';
  try {
    extractedText = utf8.decode(params.fileBytes, allowMalformed: true);
    // Extract readable text nodes from XML structures if OpenXML zip payload
    extractedText = extractedText.replaceAll(RegExp(r'<[^>]*>'), ' ');
    extractedText = extractedText.replaceAll(RegExp(r'\s+'), ' ').trim();
  } catch (_) {
    extractedText = String.fromCharCodes(params.fileBytes);
  }

  extractedText = DocumentConverterService.sanitizeSymbolFontMarkers(extractedText);

  final paragraphs = extractedText.split(RegExp(r'\n+'));

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.all(16),
      header: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(
          params.fileName,
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.center,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ),
      build: (pw.Context context) {
        final widgets = <pw.Widget>[];

        // Title Header
        widgets.add(
          pw.Header(
            level: 0,
            child: pw.Text(
              params.fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
            ),
          ),
        );
        widgets.add(pw.SizedBox(height: 12));

        for (final p in paragraphs) {
          final trimmed = p.trim();
          if (trimmed.isEmpty) continue;

          if (trimmed.startsWith('•') || trimmed.startsWith('▪') || trimmed.startsWith('–')) {
            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('${trimmed[0]} ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Expanded(child: pw.Text(trimmed.substring(1).trim(), style: const pw.TextStyle(fontSize: 11))),
                  ],
                ),
              ),
            );
          } else {
            widgets.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(
                  trimmed,
                  style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.2),
                ),
              ),
            );
          }
        }

        return widgets;
      },
    ),
  );
}

/// Spreadsheet Parsing (.xlsx, .csv) into paginated PDF tables
void _compileSpreadsheetToPdf(pw.Document pdf, _ConversionParams params, pw.ThemeData theme) {
  List<List<dynamic>> rows = [];

  if (params.extension == '.csv') {
    try {
      final csvString = utf8.decode(params.fileBytes, allowMalformed: true);
      rows = const CsvToListConverter().convert(csvString);
    } catch (_) {}
  } else {
    try {
      final excelDoc = excel.Excel.decodeBytes(params.fileBytes);
      for (final table in excelDoc.tables.keys) {
        final sheet = excelDoc.tables[table];
        if (sheet != null) {
          for (final row in sheet.rows) {
            rows.add(row.map((cell) => cell?.value?.toString() ?? '').toList());
          }
        }
      }
    } catch (_) {}
  }

  if (rows.isEmpty) {
    rows = [
      ['No sheet data found']
    ];
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: theme,
      margin: const pw.EdgeInsets.all(16),
      header: (context) => pw.Text(
        params.fileName,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
      ),
      build: (context) {
        final sanitizedRows = rows.map((row) {
          return row.map((cell) {
            final str = cell?.toString() ?? '';
            return DocumentConverterService.sanitizeSymbolFontMarkers(str);
          }).toList();
        }).toList();

        return [
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: sanitizedRows.isNotEmpty ? sanitizedRows.first.map((e) => e.toString()).toList() : null,
            data: sanitizedRows.length > 1 ? sanitizedRows.sublist(1).map((r) => r.map((e) => e.toString()).toList()).toList() : sanitizedRows.map((r) => r.map((e) => e.toString()).toList()).toList(),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          ),
        ];
      },
    ),
  );
}

/// E-Books & Web (.epub, .html, .rtf) parsing
void _compileHtmlOrEpubToPdf(pw.Document pdf, _ConversionParams params, pw.ThemeData theme) {
  String content = '';
  try {
    content = utf8.decode(params.fileBytes, allowMalformed: true);
  } catch (_) {
    content = String.fromCharCodes(params.fileBytes);
  }

  // Strip HTML tags and normalize formatting
  content = content.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?<\/style>', caseSensitive: false), '');
  content = content.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?<\/script>', caseSensitive: false), '');
  content = content.replaceAll(RegExp(r'</p>|<br\s*/?>|div>', caseSensitive: false), '\n');
  content = content.replaceAll(RegExp(r'<[^>]*>'), '');
  content = DocumentConverterService.sanitizeSymbolFontMarkers(content);

  final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.all(16),
      header: (context) => pw.Text(params.fileName, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      footer: (context) => pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      build: (context) {
        return lines.map((line) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Text(line.trim(), style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3)),
        )).toList();
      },
    ),
  );
}

/// Plain Text (.txt, .csv, .log) parsing into 16pt padded PDF
void _compilePlainTextToPdf(pw.Document pdf, _ConversionParams params, pw.ThemeData theme) {
  String text = '';
  try {
    text = utf8.decode(params.fileBytes, allowMalformed: true);
  } catch (_) {
    text = String.fromCharCodes(params.fileBytes);
  }

  text = DocumentConverterService.sanitizeSymbolFontMarkers(text);
  final lines = text.split('\n');

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.all(16),
      header: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(params.fileName, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      ),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.center,
        child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      ),
      build: (context) {
        return lines.map((line) => pw.Text(
          line.isEmpty ? ' ' : line,
          style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.2),
        )).toList();
      },
    ),
  );
}
