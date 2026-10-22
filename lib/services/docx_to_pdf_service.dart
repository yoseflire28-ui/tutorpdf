import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Parameters passed into the background isolate for DOCX conversion
class DocxConversionParams {
  final Uint8List docxBytes;
  final RootIsolateToken token;
  final bool isDarkMode;
  final Uint8List? fontBytes;

  const DocxConversionParams({
    required this.docxBytes,
    required this.token,
    this.isDarkMode = false,
    this.fontBytes,
  });
}

/// Native DOCX-to-PDF Conversion Service
/// 
/// Converts DOCX files to PDF using native Dart libraries without WebView.
/// Features:
/// - Full Multi-page layout flow via pw.MultiPage
/// - Complete UTF-8, smart quote, dash, and symbol sanitization
/// - Dynamic Light and Dark Mode canvas & text color theme synchronization
/// - OpenXML styling (colors, sizes, spacing, borders, tables)
class DocxToPdfService {
  /// Converts DOCX binary bytes directly to PDF binary bytes
  static Future<Uint8List> convertDocxBytesToPdf(
    Uint8List docxBytes, {
    bool isDarkMode = false,
    Uint8List? fontBytes,
  }) async {
    // Parse DOCX as ZIP archive
    final archive = ZipDecoder().decodeBytes(docxBytes);
    
    // Extract document.xml from the archive
    String documentXml = '';
    for (final file in archive) {
      if (file.name == 'word/document.xml') {
        final content = file.content as List<int>;
        documentXml = utf8.decode(content, allowMalformed: true);
        break;
      }
    }
    
    if (documentXml.isEmpty) {
      throw Exception('Could not extract document.xml from DOCX file');
    }
    
    // Parse XML document
    final document = XmlDocument.parse(documentXml);
    final bodyElements = document.findAllElements('w:body');
    if (bodyElements.isEmpty) {
      throw Exception('Invalid DOCX format: missing <w:body> element');
    }
    final body = bodyElements.first;
    
    // Configure PDF Font & Typography
    pw.ThemeData themeData;
    if (fontBytes != null && fontBytes.isNotEmpty) {
      try {
        final ttfFont = pw.Font.ttf(fontBytes.buffer.asByteData());
        themeData = pw.ThemeData.withFont(
          base: ttfFont,
          bold: ttfFont,
          italic: ttfFont,
          boldItalic: ttfFont,
        );
      } catch (e) {
        themeData = pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
          italic: pw.Font.helveticaOblique(),
          boldItalic: pw.Font.helveticaBoldOblique(),
        );
      }
    } else {
      themeData = pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
        boldItalic: pw.Font.helveticaBoldOblique(),
      );
    }

    final pdf = pw.Document(theme: themeData);
    
    // Theme-specific colors
    final pageBgColor = isDarkMode ? PdfColor.fromInt(0xFF1E1E1E) : PdfColor.fromInt(0xFFFFFFFF);
    final emptyTextColor = isDarkMode ? PdfColor.fromInt(0xFFE0E0E0) : PdfColor.fromInt(0xFF111111);

    // Build PDF content widgets from w:body child elements
    final contentWidgets = _parseBodyElements(body, isDarkMode: isDarkMode);
    
    // Encapsulate all page formatting strictly inside PageTheme
    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      theme: themeData,
      buildBackground: (pw.Context context) {
        return pw.FullPage(
          ignoreMargins: true,
          child: pw.Container(
            color: pageBgColor,
          ),
        );
      },
    );

    // MultiPage container flows content automatically across as many pages as required
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        build: (pw.Context context) {
          return contentWidgets.isEmpty 
              ? [pw.Text('Empty Document', style: pw.TextStyle(fontSize: 12, color: emptyTextColor))]
              : contentWidgets;
        },
      ),
    );
    
    return Uint8List.fromList(await pdf.save());
  }

  /// Converts a DOCX file at [docxPath] to PDF
  static Future<String> convertDocxToPdf(
    String docxPath, {
    bool isDarkMode = false,
    Uint8List? fontBytes,
  }) async {
    debugPrint('[DocxToPdf] Starting conversion: $docxPath (isDarkMode: $isDarkMode)');
    
    final docxFile = File(docxPath);
    if (!await docxFile.exists()) {
      throw Exception('DOCX file not found: $docxPath');
    }
    
    final Uint8List docxBytes = await docxFile.readAsBytes();
    final RootIsolateToken? token = RootIsolateToken.instance;
    if (token == null) {
      throw Exception('RootIsolateToken instance is null');
    }

    final Uint8List pdfBytes = await compute(
      convertDocxToPdfIsolate,
      DocxConversionParams(
        docxBytes: docxBytes,
        token: token,
        isDarkMode: isDarkMode,
        fontBytes: fontBytes,
      ),
    );
    
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final themeTag = isDarkMode ? 'dark' : 'light';
    final pdfPath = '${tempDir.path}/converted_doc_${themeTag}_$timestamp.pdf';
    
    final pdfFile = File(pdfPath);
    await pdfFile.writeAsBytes(pdfBytes);
    
    debugPrint('[DocxToPdf] Conversion complete: $pdfPath');
    return pdfPath;
  }

  /// Parses all child elements of w:body sequentially (w:p, w:tbl, etc.)
  static List<pw.Widget> _parseBodyElements(XmlElement body, {required bool isDarkMode}) {
    final widgets = <pw.Widget>[];

    for (final child in body.childElements) {
      final name = child.name.local;
      if (name == 'p') {
        final pWidget = _parseParagraph(child, isDarkMode: isDarkMode);
        if (pWidget != null) {
          widgets.add(pWidget);
        }
      } else if (name == 'tbl') {
        final tblWidget = _parseTable(child, isDarkMode: isDarkMode);
        if (tblWidget != null) {
          widgets.add(tblWidget);
        }
      } else if (name == 'sdt') {
        // Structured Document Tag / Content Control: process inner sdtContent
        final sdtContent = child.findElements('w:sdtContent').firstOrNull;
        if (sdtContent != null) {
          widgets.addAll(_parseBodyElements(sdtContent, isDarkMode: isDarkMode));
        }
      }
      // Section breaks (w:sectPr) and other tags are safely bypassed without breaking the loop
    }

    return widgets;
  }

  /// Parses a DOCX paragraph (<w:p>) into a styled PDF RichText widget
  static pw.Widget? _parseParagraph(XmlElement paragraph, {required bool isDarkMode}) {
    final pPr = paragraph.findElements('w:pPr').firstOrNull;

    // 1. Spacing & Alignment
    double spaceBefore = 0;
    double spaceAfter = 4;
    pw.TextAlign textAlign = pw.TextAlign.left;
    bool isHeading = false;
    double defaultFontSize = 12;
    bool defaultBold = false;

    if (pPr != null) {
      // Paragraph Alignment (w:jc)
      final jcVal = pPr.findElements('w:jc').firstOrNull?.getAttribute('w:val');
      if (jcVal == 'center') {
        textAlign = pw.TextAlign.center;
      } else if (jcVal == 'right') {
        textAlign = pw.TextAlign.right;
      } else if (jcVal == 'both' || jcVal == 'justify') {
        textAlign = pw.TextAlign.justify;
      }

      // Paragraph Spacing (w:spacing in twips: 1 twip = 1/20 pt)
      final spacing = pPr.findElements('w:spacing').firstOrNull;
      if (spacing != null) {
        final beforeStr = spacing.getAttribute('w:before');
        final afterStr = spacing.getAttribute('w:after');
        if (beforeStr != null) {
          final twips = double.tryParse(beforeStr);
          if (twips != null) spaceBefore = twips / 20.0;
        }
        if (afterStr != null) {
          final twips = double.tryParse(afterStr);
          if (twips != null) spaceAfter = twips / 20.0;
        }
      }

      // Heading style detection (w:pStyle)
      final pStyleVal = pPr.findElements('w:pStyle').firstOrNull?.getAttribute('w:val');
      if (pStyleVal != null) {
        if (pStyleVal.contains('Heading1') || pStyleVal.contains('Title')) {
          defaultFontSize = 22;
          defaultBold = true;
          isHeading = true;
        } else if (pStyleVal.contains('Heading2')) {
          defaultFontSize = 18;
          defaultBold = true;
          isHeading = true;
        } else if (pStyleVal.contains('Heading3')) {
          defaultFontSize = 14;
          defaultBold = true;
          isHeading = true;
        }
      }
    }

    // List item detection (w:numPr)
    final numPr = pPr?.findElements('w:numPr').firstOrNull;
    final isListItem = numPr != null;

    // 2. Extract runs (<w:r>)
    final spans = <pw.InlineSpan>[];
    final defaultTextColor = isDarkMode ? PdfColor.fromInt(0xFFE0E0E0) : PdfColor.fromInt(0xFF111111);

    if (isListItem) {
      spans.add(
        pw.TextSpan(
          text: '-  ',
          style: pw.TextStyle(
            fontSize: defaultFontSize,
            fontWeight: pw.FontWeight.bold,
            color: defaultTextColor,
          ),
        ),
      );
    }

    final runs = paragraph.findElements('w:r');
    for (final run in runs) {
      final rPr = run.findElements('w:rPr').firstOrNull;

      // Extract formatting properties
      bool isBold = defaultBold;
      bool isItalic = false;
      bool isUnderline = false;
      bool isStrike = false;
      double fontSize = defaultFontSize;
      String? colorVal;

      if (rPr != null) {
        if (rPr.findElements('w:b').isNotEmpty) isBold = true;
        if (rPr.findElements('w:i').isNotEmpty) isItalic = true;
        if (rPr.findElements('w:u').isNotEmpty) isUnderline = true;
        if (rPr.findElements('w:strike').isNotEmpty) isStrike = true;

        // Font size (w:sz in half-points)
        final szVal = rPr.findElements('w:sz').firstOrNull?.getAttribute('w:val');
        if (szVal != null) {
          final halfPts = double.tryParse(szVal);
          if (halfPts != null) fontSize = halfPts / 2.0;
        }

        // Color (w:color)
        colorVal = rPr.findElements('w:color').firstOrNull?.getAttribute('w:val');
      }

      final resolvedColor = _resolveTextColor(colorVal, isDarkMode, isHeading);

      // Extract text content (<w:t>)
      final textElements = run.findElements('w:t');
      final rawTextBuffer = StringBuffer();
      for (final textElement in textElements) {
        rawTextBuffer.write(textElement.innerText);
      }

      final textStr = rawTextBuffer.toString();
      if (textStr.isNotEmpty) {
        final sanitizedText = sanitizeText(textStr);
        
        pw.TextDecoration? decoration;
        if (isUnderline && isStrike) {
          decoration = pw.TextDecoration.combine([pw.TextDecoration.underline, pw.TextDecoration.lineThrough]);
        } else if (isUnderline) {
          decoration = pw.TextDecoration.underline;
        } else if (isStrike) {
          decoration = pw.TextDecoration.lineThrough;
        }

        spans.add(
          pw.TextSpan(
            text: sanitizedText,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontStyle: isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
              decoration: decoration,
              color: resolvedColor,
            ),
          ),
        );
      }
    }

    if (spans.isEmpty) {
      return pw.SizedBox(height: spaceAfter > 0 ? spaceAfter : 4);
    }

    return pw.Padding(
      padding: pw.EdgeInsets.only(top: spaceBefore, bottom: spaceAfter),
      child: pw.RichText(
        textAlign: textAlign,
        text: pw.TextSpan(children: spans),
      ),
    );
  }

  /// Parses a DOCX table (<w:tbl>) into a styled PDF Table widget
  static pw.Widget? _parseTable(XmlElement tableElement, {required bool isDarkMode}) {
    final rows = <pw.TableRow>[];
    final trElements = tableElement.findElements('w:tr');
    final borderColor = isDarkMode ? PdfColor.fromInt(0xFF444444) : PdfColor.fromInt(0xFFD1D5DB);

    for (final tr in trElements) {
      final cells = <pw.Widget>[];
      final tcElements = tr.findElements('w:tc');

      for (final tc in tcElements) {
        final cellWidgets = <pw.Widget>[];
        for (final child in tc.childElements) {
          if (child.name.local == 'p') {
            final pWidget = _parseParagraph(child, isDarkMode: isDarkMode);
            if (pWidget != null) cellWidgets.add(pWidget);
          }
        }

        cells.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: cellWidgets.isEmpty ? [pw.SizedBox(height: 8)] : cellWidgets,
            ),
          ),
        );
      }

      if (cells.isNotEmpty) {
        rows.add(pw.TableRow(children: cells));
      }
    }

    if (rows.isEmpty) return null;

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Table(
        border: pw.TableBorder.all(color: borderColor, width: 0.5),
        children: rows,
      ),
    );
  }

  /// Sanitizes legacy MS Word smart quotes, dashes, spaces, and private-use Unicode symbols
  static String sanitizeText(String text) {
    if (text.isEmpty) return text;
    final buffer = StringBuffer();

    for (final char in text.runes) {
      // 1. Smart Double Quotes (“ ” „ ‟ « » ″ ‶)
      if (char == 0x201C || char == 0x201D || char == 0x201E || char == 0x201F ||
          char == 0x00AB || char == 0x00BB || char == 0x2033 || char == 0x2036) {
        buffer.write('"');
      }
      // 2. Smart Single Quotes & Apostrophes (‘ ’ ‚ ‛ ` ´ ′ ‵)
      else if (char == 0x2018 || char == 0x2019 || char == 0x201A || char == 0x201B ||
               char == 0x0060 || char == 0x00B4 || char == 0x2032 || char == 0x2035) {
        buffer.write("'");
      }
      // 3. Em-Dashes, En-Dashes, Figure Dashes & Hyphens (— – ‒ ― − ‐ ‑)
      else if (char == 0x2014 || char == 0x2013 || char == 0x2012 || char == 0x2015 ||
               char == 0x2212 || char == 0x2010 || char == 0x2011) {
        buffer.write('-');
      }
      // 4. Non-breaking spaces & Unicode whitespace
      else if (char == 0x00A0 || char == 0x202F || char == 0x2007 ||
               (char >= 0x2000 && char <= 0x200A)) {
        buffer.write(' ');
      }
      // 5. Zero-width spaces & BOM characters
      else if (char == 0x200B || char == 0x200C || char == 0x200D || char == 0xFEFF) {
        // Drop zero-width formatting characters
      }
      // 6. Ellipsis (…)
      else if (char == 0x2026) {
        buffer.write('...');
      }
      // 7. Bullets and Shape Symbols
      else if (char == 0x2022 || char == 0x25CF || char == 0x25E6 ||
               char == 0x2023 || char == 0x2043 || char == 0x2219) {
        buffer.write('- ');
      }
      else if (char == 0x25AA || char == 0x25AB || char == 0x25A0 ||
               char == 0x25A1 || char == 0x25FD || char == 0x25FE) {
        buffer.write('- ');
      }
      // 8. Checkmarks & Crosses
      else if (char == 0x2713 || char == 0x2714 || char == 0x2611) {
        buffer.write('[v] ');
      }
      else if (char == 0x2717 || char == 0x2718 || char == 0x2612 || char == 0x274C) {
        buffer.write('[x] ');
      }
      // 9. Arrows & Pointers
      else if (char == 0x27A4 || char == 0x27A2 || char == 0x279C || char == 0x2192) {
        buffer.write('> ');
      }
      else if (char == 0x2190) {
        buffer.write('< ');
      }
      else if (char == 0x2194) {
        buffer.write('<> ');
      }
      // 10. Word Wingdings / Symbol Private Use Area (0xE000-0xF8FF and 0xF000-0xFFFF)
      else if (char == 0xF0B7 || char == 0xF0A7 || char == 0xB7) {
        buffer.write('- ');
      }
      else if (char == 0xF06C || char == 0xF065) {
        buffer.write('- ');
      }
      else if (char == 0xF0FC || char == 0xF0FB) {
        buffer.write('[v] ');
      }
      else if (char == 0xF0D8 || char == 0xF0DE) {
        buffer.write('> ');
      }
      else if ((char >= 0xE000 && char <= 0xF8FF) || (char >= 0xF000 && char <= 0xFFFF)) {
        buffer.write('- ');
      }
      // 11. Printable Standard Unicode
      else {
        buffer.writeCharCode(char);
      }
    }

    return buffer.toString();
  }

  /// Resolves text color based on Dark / Light Mode with contrast protection
  static PdfColor _resolveTextColor(String? colorVal, bool isDarkMode, bool isHeading) {
    final defaultColor = isDarkMode
        ? (isHeading ? PdfColor.fromInt(0xFF90CAF9) : PdfColor.fromInt(0xFFE0E0E0))
        : (isHeading ? PdfColor.fromInt(0xFF1565C0) : PdfColor.fromInt(0xFF111111));

    if (colorVal == null || colorVal.isEmpty || colorVal.toLowerCase() == 'auto') {
      return defaultColor;
    }

    final parsed = _parseColor(colorVal, defaultColor);

    if (isDarkMode) {
      // Calculate luminance: 0.299*R + 0.587*G + 0.114*B
      final double luminance = 0.299 * parsed.red + 0.587 * parsed.green + 0.114 * parsed.blue;
      if (luminance < 0.35) {
        // High contrast adjustment for dark mode: brighten dark colors
        return PdfColor(
          1.0 - (parsed.red * 0.3),
          1.0 - (parsed.green * 0.3),
          1.0 - (parsed.blue * 0.3),
        );
      }
    } else {
      final double luminance = 0.299 * parsed.red + 0.587 * parsed.green + 0.114 * parsed.blue;
      if (luminance > 0.85) {
        // Darken overly bright colors in light mode
        return PdfColor(
          parsed.red * 0.4,
          parsed.green * 0.4,
          parsed.blue * 0.4,
        );
      }
    }

    return parsed;
  }

  /// Helper to parse OpenXML color hex strings into PdfColor
  static PdfColor _parseColor(String? colorVal, PdfColor defaultColor) {
    if (colorVal == null || colorVal.isEmpty || colorVal.toLowerCase() == 'auto') {
      return defaultColor;
    }
    String hex = colorVal.replaceAll('#', '').trim();
    if (hex.length == 6) {
      try {
        final int val = int.parse('FF$hex', radix: 16);
        return PdfColor.fromInt(val);
      } catch (_) {}
    } else if (hex.length == 8) {
      try {
        final int val = int.parse(hex, radix: 16);
        return PdfColor.fromInt(val);
      } catch (_) {}
    }
    return defaultColor;
  }
}

/// Entry point for background isolate computation
Future<Uint8List> convertDocxToPdfIsolate(DocxConversionParams params) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(params.token);
  return await DocxToPdfService.convertDocxBytesToPdf(
    params.docxBytes,
    isDarkMode: params.isDarkMode,
    fontBytes: params.fontBytes,
  );
}
