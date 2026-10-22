import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Parameters passed into the background isolate for PPTX conversion
class PptxConversionParams {
  final Uint8List pptxBytes;
  final RootIsolateToken token;
  final bool isDarkMode;
  final Uint8List? fontBytes;

  const PptxConversionParams({
    required this.pptxBytes,
    required this.token,
    this.isDarkMode = false,
    this.fontBytes,
  });
}

/// Extracted PPTX Presentation Theme Color Palette
class PptxTheme {
  final Map<String, PdfColor> colorScheme;

  PptxTheme({required this.colorScheme});

  /// Fallback standard Office theme palette
  factory PptxTheme.defaultTheme() {
    return PptxTheme(
      colorScheme: const {
        'dk1': PdfColor.fromInt(0xFF000000),
        'lt1': PdfColor.fromInt(0xFFFFFFFF),
        'dk2': PdfColor.fromInt(0xFF1F497D),
        'lt2': PdfColor.fromInt(0xFFEEECE1),
        'accent1': PdfColor.fromInt(0xFF4F81BD),
        'accent2': PdfColor.fromInt(0xFFC0504D),
        'accent3': PdfColor.fromInt(0xFF9BBB59),
        'accent4': PdfColor.fromInt(0xFF8064A2),
        'accent5': PdfColor.fromInt(0xFF4BACC6),
        'accent6': PdfColor.fromInt(0xFFF79646),
        'hlink': PdfColor.fromInt(0xFF0000FF),
        'folHlink': PdfColor.fromInt(0xFF800080),
      },
    );
  }

  /// Parses theme XML (ppt/theme/theme1.xml)
  factory PptxTheme.fromXml(String xmlStr) {
    final colors = <String, PdfColor>{};
    try {
      final doc = XmlDocument.parse(xmlStr);
      final clrScheme = doc.findAllElements('a:clrScheme').firstOrNull;
      if (clrScheme != null) {
        for (final child in clrScheme.childElements) {
          final schemeKey = child.name.local;
          final srgb = child.findElements('a:srgbClr').firstOrNull?.getAttribute('val');
          final sysLastClr = child.findElements('a:sysClr').firstOrNull?.getAttribute('lastClr');
          final hexVal = srgb ?? sysLastClr;
          if (hexVal != null) {
            final parsed = PptxColorHelper.parseHex(hexVal);
            if (parsed != null) {
              colors[schemeKey] = parsed;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[PptxToPdf] Error parsing theme xml: $e');
    }

    final fallback = PptxTheme.defaultTheme();
    for (final entry in fallback.colorScheme.entries) {
      colors.putIfAbsent(entry.key, () => entry.value);
    }

    return PptxTheme(colorScheme: colors);
  }

  /// Resolves an OpenXML color node (<a:srgbClr>, <a:schemeClr>, <a:sysClr>, <a:prstClr>, etc.)
  PdfColor resolveColor(XmlElement? colorContainer, PdfColor defaultColor) {
    if (colorContainer == null) return defaultColor;

    // Direct srgbClr child
    final srgbElem = colorContainer.findElements('a:srgbClr').firstOrNull;
    if (srgbElem != null) {
      final hex = srgbElem.getAttribute('val');
      final base = PptxColorHelper.parseHex(hex) ?? defaultColor;
      return PptxColorHelper.applyColorTransforms(srgbElem, base);
    }

    // Scheme color child (accent1-accent6, tx1, tx2, bg1, bg2, dk1, dk2, lt1, lt2, etc.)
    final schemeElem = colorContainer.findElements('a:schemeClr').firstOrNull;
    if (schemeElem != null) {
      final val = schemeElem.getAttribute('val');
      PdfColor base = defaultColor;
      if (val != null) {
        if (val == 'tx1' || val == 'dk1') {
          base = colorScheme['dk1'] ?? const PdfColor.fromInt(0xFF000000);
        } else if (val == 'tx2' || val == 'dk2') {
          base = colorScheme['dk2'] ?? const PdfColor.fromInt(0xFF1F497D);
        } else if (val == 'bg1' || val == 'lt1') {
          base = colorScheme['lt1'] ?? const PdfColor.fromInt(0xFFFFFFFF);
        } else if (val == 'bg2' || val == 'lt2') {
          base = colorScheme['lt2'] ?? const PdfColor.fromInt(0xFFEEECE1);
        } else if (val == 'phClr') {
          base = defaultColor;
        } else if (colorScheme.containsKey(val)) {
          base = colorScheme[val]!;
        }
      }
      return PptxColorHelper.applyColorTransforms(schemeElem, base);
    }

    // System color child (a:sysClr)
    final sysElem = colorContainer.findElements('a:sysClr').firstOrNull;
    if (sysElem != null) {
      final lastClr = sysElem.getAttribute('lastClr');
      final base = PptxColorHelper.parseHex(lastClr) ?? defaultColor;
      return PptxColorHelper.applyColorTransforms(sysElem, base);
    }

    // Preset color child (a:prstClr)
    final prstElem = colorContainer.findElements('a:prstClr').firstOrNull;
    if (prstElem != null) {
      final prstVal = prstElem.getAttribute('val');
      final base = PptxColorHelper.parsePresetColor(prstVal) ?? defaultColor;
      return PptxColorHelper.applyColorTransforms(prstElem, base);
    }

    // Direct attributes if the container itself is a color element
    final name = colorContainer.name.local;
    if (name == 'srgbClr') {
      final hex = colorContainer.getAttribute('val');
      final base = PptxColorHelper.parseHex(hex) ?? defaultColor;
      return PptxColorHelper.applyColorTransforms(colorContainer, base);
    } else if (name == 'schemeClr') {
      final val = colorContainer.getAttribute('val');
      PdfColor base = defaultColor;
      if (val != null) {
        if (val == 'tx1' || val == 'dk1') {
          base = colorScheme['dk1'] ?? const PdfColor.fromInt(0xFF000000);
        } else if (val == 'tx2' || val == 'dk2') {
          base = colorScheme['dk2'] ?? const PdfColor.fromInt(0xFF1F497D);
        } else if (val == 'bg1' || val == 'lt1') {
          base = colorScheme['lt1'] ?? const PdfColor.fromInt(0xFFFFFFFF);
        } else if (val == 'bg2' || val == 'lt2') {
          base = colorScheme['lt2'] ?? const PdfColor.fromInt(0xFFEEECE1);
        } else if (colorScheme.containsKey(val)) {
          base = colorScheme[val]!;
        }
      }
      return PptxColorHelper.applyColorTransforms(colorContainer, base);
    } else if (name == 'sysClr') {
      final lastClr = colorContainer.getAttribute('lastClr');
      final base = PptxColorHelper.parseHex(lastClr) ?? defaultColor;
      return PptxColorHelper.applyColorTransforms(colorContainer, base);
    } else if (name == 'prstClr') {
      final prstVal = colorContainer.getAttribute('val');
      final base = PptxColorHelper.parsePresetColor(prstVal) ?? defaultColor;
      return PptxColorHelper.applyColorTransforms(colorContainer, base);
    }

    return defaultColor;
  }
}

/// Helper for parsing hex codes, preset colors, and DrawingML color transformations
class PptxColorHelper {
  static PdfColor? parseHex(String? hexVal) {
    if (hexVal == null || hexVal.isEmpty || hexVal.toLowerCase() == 'auto') return null;
    final clean = hexVal.replaceAll('#', '').trim();
    if (clean.length == 6) {
      try {
        final val = int.parse('FF$clean', radix: 16);
        return PdfColor.fromInt(val);
      } catch (_) {}
    } else if (clean.length == 8) {
      try {
        final val = int.parse(clean, radix: 16);
        return PdfColor.fromInt(val);
      } catch (_) {}
    }
    return parsePresetColor(hexVal);
  }

  /// Resolves standard OpenXML preset colors (white, black, blue, red, etc.)
  static PdfColor? parsePresetColor(String? prst) {
    if (prst == null || prst.isEmpty) return null;
    switch (prst.toLowerCase()) {
      case 'white':
        return const PdfColor.fromInt(0xFFFFFFFF);
      case 'black':
        return const PdfColor.fromInt(0xFF000000);
      case 'blue':
        return const PdfColor.fromInt(0xFF0000FF);
      case 'red':
        return const PdfColor.fromInt(0xFFFF0000);
      case 'green':
        return const PdfColor.fromInt(0xFF008000);
      case 'yellow':
        return const PdfColor.fromInt(0xFFFFFF00);
      case 'gray':
      case 'grey':
        return const PdfColor.fromInt(0xFF808080);
      case 'lightgray':
      case 'lightgrey':
        return const PdfColor.fromInt(0xFFD3D3D3);
      case 'darkgray':
      case 'darkgrey':
        return const PdfColor.fromInt(0xFFA9A9A9);
      case 'navy':
        return const PdfColor.fromInt(0xFF000080);
      case 'teal':
        return const PdfColor.fromInt(0xFF008080);
      case 'cyan':
        return const PdfColor.fromInt(0xFF00FFFF);
      case 'magenta':
        return const PdfColor.fromInt(0xFFFF00FF);
      case 'orange':
        return const PdfColor.fromInt(0xFFFFA500);
      case 'transparent':
        return const PdfColor.fromInt(0x00000000);
      default:
        return null;
    }
  }

  /// Applies DrawingML color transformations (lumMod, lumOff, tint, shade, alpha)
  static PdfColor applyColorTransforms(XmlElement elem, PdfColor base) {
    double r = base.red;
    double g = base.green;
    double b = base.blue;

    // Tint (mix towards white: new = c * tint + (1 - tint))
    final tintVal = elem.findElements('a:tint').firstOrNull?.getAttribute('val');
    if (tintVal != null) {
      final factor = (double.tryParse(tintVal) ?? 100000.0) / 100000.0;
      r = (r * factor) + (1.0 - factor);
      g = (g * factor) + (1.0 - factor);
      b = (b * factor) + (1.0 - factor);
    }

    // Shade (mix towards black: new = c * shade)
    final shadeVal = elem.findElements('a:shade').firstOrNull?.getAttribute('val');
    if (shadeVal != null) {
      final factor = (double.tryParse(shadeVal) ?? 100000.0) / 100000.0;
      r = r * factor;
      g = g * factor;
      b = b * factor;
    }

    // LumMod (luminance modulation)
    final lumModVal = elem.findElements('a:lumMod').firstOrNull?.getAttribute('val');
    if (lumModVal != null) {
      final factor = (double.tryParse(lumModVal) ?? 100000.0) / 100000.0;
      r = r * factor;
      g = g * factor;
      b = b * factor;
    }

    // LumOff (luminance offset)
    final lumOffVal = elem.findElements('a:lumOff').firstOrNull?.getAttribute('val');
    if (lumOffVal != null) {
      final offset = (double.tryParse(lumOffVal) ?? 0.0) / 100000.0;
      r = r + offset;
      g = g + offset;
      b = b + offset;
    }

    return PdfColor(
      r.clamp(0.0, 1.0),
      g.clamp(0.0, 1.0),
      b.clamp(0.0, 1.0),
    );
  }
}

/// Represents slide background fill properties
class PptxBackgroundFill {
  final PdfColor? solidColor;
  final pw.LinearGradient? gradient;
  final Uint8List? imageBytes;

  const PptxBackgroundFill({
    this.solidColor,
    this.gradient,
    this.imageBytes,
  });

  bool get isEmpty => solidColor == null && gradient == null && imageBytes == null;
}

/// Represents a dark background or banner region on the slide for contrast detection
class PptxDarkRegion {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const PptxDarkRegion({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  bool containsPoint(double x, double y) {
    return x >= left && x <= right && y >= top && y <= bottom;
  }
}

/// Slide Layout & Master Presentation Container
class PptxMasterLayoutInfo {
  final PptxBackgroundFill? background;
  final List<XmlElement> decorativeShapes;
  final Map<String, String> rels;
  final bool showMasterShapes;

  const PptxMasterLayoutInfo({
    this.background,
    this.decorativeShapes = const [],
    this.rels = const {},
    this.showMasterShapes = true,
  });
}

/// Native PPTX-to-PDF Conversion Service
/// 
/// 100% offline, native OpenXML PresentationML parser converting PPTX presentations
/// into landscape 16:9 PDF slide documents with precise EMU spatial positioning,
/// slide master & layout shape extraction, background gradient and vector wave extraction,
/// table layouts, subtitle/title placeholder inheritance, and typography sanitization.
class PptxToPdfService {
  /// Converts PPTX binary bytes directly into PDF binary bytes
  static Future<Uint8List> convertPptxBytesToPdf(
    Uint8List pptxBytes, {
    bool isDarkMode = false,
    Uint8List? fontBytes,
  }) async {
    // 1. Decode PPTX as ZIP archive
    final archive = ZipDecoder().decodeBytes(pptxBytes);

    // 2. Extract media assets into memory map (ppt/media/*)
    final mediaMap = <String, Uint8List>{};
    for (final file in archive) {
      if (file.name.startsWith('ppt/media/')) {
        final content = file.content as List<int>;
        final fileName = file.name.split('/').last;
        mediaMap[fileName] = Uint8List.fromList(content);
        mediaMap[file.name] = Uint8List.fromList(content);
      }
    }

    // 3. Extract Theme (ppt/theme/theme1.xml)
    PptxTheme theme = PptxTheme.defaultTheme();
    final themeFile = archive.findFile('ppt/theme/theme1.xml');
    if (themeFile != null) {
      final themeXml = utf8.decode(themeFile.content as List<int>, allowMalformed: true);
      theme = PptxTheme.fromXml(themeXml);
    }

    // 4. Determine Slide Dimensions (from ppt/presentation.xml)
    // Default: Strict 16:9 widescreen layout (960 pt x 540 pt)
    double slideWidthPt = 960.0;
    double slideHeightPt = 540.0;
    
    final presentationFile = archive.findFile('ppt/presentation.xml');
    String presentationXml = '';
    if (presentationFile != null) {
      presentationXml = utf8.decode(presentationFile.content as List<int>, allowMalformed: true);
      try {
        final doc = XmlDocument.parse(presentationXml);
        final sldSz = doc.findAllElements('p:sldSz').firstOrNull;
        if (sldSz != null) {
          final cx = double.tryParse(sldSz.getAttribute('cx') ?? '');
          final cy = double.tryParse(sldSz.getAttribute('cy') ?? '');
          if (cx != null && cy != null && cx > 0 && cy > 0) {
            slideWidthPt = cx / 12700.0;
            slideHeightPt = cy / 12700.0;
          }
        }
      } catch (e) {
        debugPrint('[PptxToPdf] Error parsing presentation.xml sldSz: $e');
      }
    }

    // 5. Determine Slide Sequence from Relationships
    final slidePaths = _determineSlidePaths(archive, presentationXml);
    if (slidePaths.isEmpty) {
      throw Exception('No slides found in PPTX presentation archive.');
    }

    // 6. Pre-cache Slide Masters and Layouts
    final masterCache = <String, PptxMasterLayoutInfo>{};
    final layoutCache = <String, PptxMasterLayoutInfo>{};
    _cacheMastersAndLayouts(archive, theme, mediaMap, masterCache, layoutCache);

    // 7. Configure PDF Typography
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
      } catch (_) {
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
    final pageFormat = PdfPageFormat(slideWidthPt, slideHeightPt, marginAll: 0);

    // 8. Build exactly ONE landscape PDF Page per Slide
    for (int i = 0; i < slidePaths.length; i++) {
      final slidePath = slidePaths[i];
      final slideFile = archive.findFile(slidePath);
      if (slideFile == null) continue;

      final slideXmlStr = utf8.decode(slideFile.content as List<int>, allowMalformed: true);
      
      // Extract slide relationships (images / media / slide layout)
      final slideRelsPath = _getSlideRelsPath(slidePath);
      final relsFile = archive.findFile(slideRelsPath);
      final relsMap = <String, String>{};
      if (relsFile != null) {
        final relsXml = utf8.decode(relsFile.content as List<int>, allowMalformed: true);
        _parseRelationships(relsXml, relsMap);
      }

      // Identify referenced slide layout
      String? layoutPath;
      for (final target in relsMap.values) {
        if (target.contains('slideLayout')) {
          layoutPath = _normalizeZipPath('ppt/slides', target);
          break;
        }
      }

      final layoutInfo = layoutPath != null ? layoutCache[layoutPath] : null;

      // Build slide positioned widgets with full background and master graphic extraction
      final slideWidgets = _parseSlide(
        slideXmlStr: slideXmlStr,
        slideWidthPt: slideWidthPt,
        slideHeightPt: slideHeightPt,
        theme: theme,
        mediaMap: mediaMap,
        slideRelsMap: relsMap,
        layoutInfo: layoutInfo,
        isDarkMode: isDarkMode,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(0),
          build: (pw.Context context) {
            return pw.Stack(
              children: slideWidgets,
            );
          },
        ),
      );
    }

    return Uint8List.fromList(await pdf.save());
  }

  /// Pre-caches slide master and slide layout information
  static void _cacheMastersAndLayouts(
    Archive archive,
    PptxTheme theme,
    Map<String, Uint8List> mediaMap,
    Map<String, PptxMasterLayoutInfo> masterCache,
    Map<String, PptxMasterLayoutInfo> layoutCache,
  ) {
    // 1. Process Slide Masters (ppt/slideMasters/slideMaster*.xml)
    for (final file in archive) {
      if (file.name.startsWith('ppt/slideMasters/slideMaster') && file.name.endsWith('.xml') && !file.name.contains('_rels')) {
        final xmlStr = utf8.decode(file.content as List<int>, allowMalformed: true);
        final relsPath = _getSlideRelsPath(file.name);
        final relsFile = archive.findFile(relsPath);
        final relsMap = <String, String>{};
        if (relsFile != null) {
          final relsXml = utf8.decode(relsFile.content as List<int>, allowMalformed: true);
          _parseRelationships(relsXml, relsMap);
        }

        final bgFill = _extractBackgroundFill(xmlStr, theme, relsMap, mediaMap);
        final decorativeShapes = _extractMasterDecorativeShapes(xmlStr);

        masterCache[file.name] = PptxMasterLayoutInfo(
          background: bgFill,
          decorativeShapes: decorativeShapes,
          rels: relsMap,
          showMasterShapes: true,
        );
      }
    }

    // 2. Process Slide Layouts (ppt/slideLayouts/slideLayout*.xml)
    for (final file in archive) {
      if (file.name.startsWith('ppt/slideLayouts/slideLayout') && file.name.endsWith('.xml') && !file.name.contains('_rels')) {
        final xmlStr = utf8.decode(file.content as List<int>, allowMalformed: true);
        final relsPath = _getSlideRelsPath(file.name);
        final relsFile = archive.findFile(relsPath);
        final relsMap = <String, String>{};
        if (relsFile != null) {
          final relsXml = utf8.decode(relsFile.content as List<int>, allowMalformed: true);
          _parseRelationships(relsXml, relsMap);
        }

        // Find associated master
        String? masterPath;
        for (final target in relsMap.values) {
          if (target.contains('slideMaster')) {
            masterPath = _normalizeZipPath('ppt/slideLayouts', target);
            break;
          }
        }

        final masterInfo = masterPath != null ? masterCache[masterPath] : null;
        var bgFill = _extractBackgroundFill(xmlStr, theme, relsMap, mediaMap);
        if (bgFill.isEmpty && masterInfo?.background != null && !masterInfo!.background!.isEmpty) {
          bgFill = masterInfo.background!;
        }

        final decorativeShapes = _extractMasterDecorativeShapes(xmlStr);

        // Check if layout hides master shapes (<p:cSld showMasterSp="0"/>)
        bool showMasterShapes = true;
        try {
          final doc = XmlDocument.parse(xmlStr);
          final cSld = doc.findAllElements('p:cSld').firstOrNull;
          if (cSld?.getAttribute('showMasterSp') == '0' || cSld?.getAttribute('showMasterSp') == 'false') {
            showMasterShapes = false;
          }
        } catch (_) {}

        final combinedShapes = <XmlElement>[];
        if (showMasterShapes && masterInfo != null) {
          combinedShapes.addAll(masterInfo.decorativeShapes);
        }
        combinedShapes.addAll(decorativeShapes);

        final combinedRels = <String, String>{};
        if (masterInfo != null) {
          combinedRels.addAll(masterInfo.rels);
        }
        combinedRels.addAll(relsMap);

        layoutCache[file.name] = PptxMasterLayoutInfo(
          background: bgFill,
          decorativeShapes: combinedShapes,
          rels: combinedRels,
          showMasterShapes: showMasterShapes,
        );
      }
    }
  }

  /// Extracts decorative non-placeholder shapes from master/layout XML
  static List<XmlElement> _extractMasterDecorativeShapes(String xmlStr) {
    final shapes = <XmlElement>[];
    try {
      final doc = XmlDocument.parse(xmlStr);
      final spTree = doc.findAllElements('p:spTree').firstOrNull;
      if (spTree != null) {
        for (final child in spTree.childElements) {
          final name = child.name.local;
          if (name == 'sp') {
            final nvPr = child.findElements('p:nvSpPr').firstOrNull?.findElements('p:nvPr').firstOrNull;
            final ph = nvPr?.findElements('p:ph').firstOrNull;
            final phType = ph?.getAttribute('type')?.toLowerCase();
            
            final spPr = child.findElements('p:spPr').firstOrNull;
            final hasFill = spPr?.findElements('a:solidFill').isNotEmpty == true ||
                            spPr?.findElements('a:gradFill').isNotEmpty == true ||
                            spPr?.findElements('a:blipFill').isNotEmpty == true;
            final hasLine = spPr?.findElements('a:ln').isNotEmpty == true;

            // Include if non-placeholder shape, or if it has graphic fill/border styling
            if (ph == null || hasFill || hasLine) {
              if (phType == null || (phType != 'title' && phType != 'body' && phType != 'subtitle' && phType != 'ctrtitle' && phType != 'subtitle')) {
                shapes.add(child);
              } else if (hasFill || hasLine) {
                // Keep as a visual decorative background container
                shapes.add(child);
              }
            }
          } else if (name == 'pic' || name == 'grpSp') {
            shapes.add(child);
          }
        }
      }
    } catch (_) {}
    return shapes;
  }

  /// Extracts background fill from slide/layout/master XML
  static PptxBackgroundFill _extractBackgroundFill(
    String xmlStr,
    PptxTheme theme,
    Map<String, String> relsMap,
    Map<String, Uint8List> mediaMap,
  ) {
    try {
      final doc = XmlDocument.parse(xmlStr);
      final bg = doc.findAllElements('p:bg').firstOrNull;
      if (bg != null) {
        final bgPr = bg.findElements('p:bgPr').firstOrNull;
        if (bgPr != null) {
          // 1. Solid Fill
          final solidFill = bgPr.findElements('a:solidFill').firstOrNull;
          if (solidFill != null) {
            final color = theme.resolveColor(solidFill, PdfColors.white);
            return PptxBackgroundFill(solidColor: color);
          }

          // 2. Gradient Fill
          final gradFill = bgPr.findElements('a:gradFill').firstOrNull;
          if (gradFill != null) {
            final gradient = _parseGradient(gradFill, theme);
            if (gradient != null) {
              return PptxBackgroundFill(gradient: gradient);
            }
          }

          // 3. Blip Fill (Background image)
          final blipFill = bgPr.findElements('a:blipFill').firstOrNull;
          if (blipFill != null) {
            final rEmbed = blipFill.findElements('a:blip').firstOrNull?.getAttribute('r:embed');
            if (rEmbed != null) {
              final bytes = _findImageBytes(rEmbed, relsMap, mediaMap);
              if (bytes != null && bytes.isNotEmpty) {
                return PptxBackgroundFill(imageBytes: bytes);
              }
            }
          }
        }

        // Background reference (<p:bgRef>)
        final bgRef = bg.findElements('p:bgRef').firstOrNull;
        if (bgRef != null) {
          final color = theme.resolveColor(bgRef, PdfColors.white);
          return PptxBackgroundFill(solidColor: color);
        }
      }
    } catch (_) {}

    return const PptxBackgroundFill();
  }

  /// Normalizes relative zip paths (e.g. "ppt/slides" + "../slideLayouts/slideLayout1.xml" -> "ppt/slideLayouts/slideLayout1.xml")
  static String _normalizeZipPath(String baseDir, String relativePath) {
    if (!relativePath.startsWith('../') && !relativePath.startsWith('./')) {
      if (relativePath.startsWith('ppt/')) return relativePath;
      return '$baseDir/$relativePath';
    }

    final segments = baseDir.split('/');
    final relParts = relativePath.split('/');

    for (final part in relParts) {
      if (part == '..') {
        if (segments.isNotEmpty) segments.removeLast();
      } else if (part != '.') {
        segments.add(part);
      }
    }

    return segments.join('/');
  }

  /// Converts a PPTX file at [pptxPath] to PDF
  static Future<String> convertPptxToPdf(
    String pptxPath, {
    bool isDarkMode = false,
    Uint8List? fontBytes,
  }) async {
    debugPrint('[PptxToPdf] Starting conversion: $pptxPath (isDarkMode: $isDarkMode)');
    
    final pptxFile = File(pptxPath);
    if (!await pptxFile.exists()) {
      throw Exception('PPTX presentation file not found: $pptxPath');
    }
    
    final Uint8List pptxBytes = await pptxFile.readAsBytes();
    final RootIsolateToken? token = RootIsolateToken.instance;
    if (token == null) {
      throw Exception('RootIsolateToken.instance is null on main thread');
    }

    final Uint8List pdfBytes = await compute(
      convertPptxToPdfIsolate,
      PptxConversionParams(
        pptxBytes: pptxBytes,
        token: token,
        isDarkMode: isDarkMode,
        fontBytes: fontBytes,
      ),
    );

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final themeTag = isDarkMode ? 'dark' : 'light';
    final pdfPath = '${tempDir.path}/converted_presentation_${themeTag}_$timestamp.pdf';
    
    final pdfFile = File(pdfPath);
    await pdfFile.writeAsBytes(pdfBytes);
    
    debugPrint('[PptxToPdf] Conversion complete: $pdfPath');
    return pdfPath;
  }

  /// Resolves the ordered slide file paths
  static List<String> _determineSlidePaths(Archive archive, String presentationXml) {
    final paths = <String>[];
    final allSlideFiles = <String>{};

    for (final file in archive) {
      if (file.name.startsWith('ppt/slides/slide') && file.name.endsWith('.xml') && !file.name.contains('_rels')) {
        allSlideFiles.add(file.name);
      }
    }

    if (presentationXml.isNotEmpty) {
      try {
        final relsFile = archive.findFile('ppt/_rels/presentation.xml.rels');
        final presRels = <String, String>{};
        if (relsFile != null) {
          final relsXml = utf8.decode(relsFile.content as List<int>, allowMalformed: true);
          _parseRelationships(relsXml, presRels);
        }

        final doc = XmlDocument.parse(presentationXml);
        final sldIds = doc.findAllElements('p:sldId');
        for (final sldId in sldIds) {
          final rId = sldId.getAttribute('r:id') ?? sldId.getAttribute('id');
          if (rId != null && presRels.containsKey(rId)) {
            var target = presRels[rId]!;
            if (!target.startsWith('ppt/')) {
              target = 'ppt/$target';
            }
            if (allSlideFiles.contains(target)) {
              paths.add(target);
            }
          }
        }
      } catch (e) {
        debugPrint('[PptxToPdf] Error ordering slides from presentation.xml: $e');
      }
    }

    // Append any slides not listed in presentation.xml or fallback to natural sorting
    if (paths.isEmpty) {
      final sortedList = allSlideFiles.toList();
      sortedList.sort((a, b) {
        final reg = RegExp(r'slide(\d+)\.xml');
        final matchA = reg.firstMatch(a);
        final matchB = reg.firstMatch(b);
        if (matchA != null && matchB != null) {
          final int numA = int.tryParse(matchA.group(1) ?? '0') ?? 0;
          final int numB = int.tryParse(matchB.group(1) ?? '0') ?? 0;
          return numA.compareTo(numB);
        }
        return a.compareTo(b);
      });
      paths.addAll(sortedList);
    } else {
      // Add any leftover slides that weren't referenced
      for (final slide in allSlideFiles) {
        if (!paths.contains(slide)) {
          paths.add(slide);
        }
      }
    }

    return paths;
  }

  /// Derives the .rels path for a slide
  static String _getSlideRelsPath(String slidePath) {
    final parts = slidePath.split('/');
    final slideName = parts.last;
    parts.removeLast();
    return '${parts.join('/')}/_rels/$slideName.rels';
  }

  /// Parses an OpenXML relationship file
  static void _parseRelationships(String xmlStr, Map<String, String> outMap) {
    try {
      final doc = XmlDocument.parse(xmlStr);
      for (final rel in doc.findAllElements('Relationship')) {
        final id = rel.getAttribute('Id');
        final target = rel.getAttribute('Target');
        if (id != null && target != null) {
          outMap[id] = target;
        }
      }
    } catch (_) {}
  }

  /// Helper to lookup image bytes from mediaMap
  static Uint8List? _findImageBytes(String rEmbed, Map<String, String> relsMap, Map<String, Uint8List> mediaMap) {
    if (!relsMap.containsKey(rEmbed)) return null;
    final target = relsMap[rEmbed]!;
    final filename = target.split('/').last;
    
    if (mediaMap.containsKey(target)) return mediaMap[target];
    if (mediaMap.containsKey(filename)) return mediaMap[filename];
    if (mediaMap.containsKey('ppt/media/$filename')) return mediaMap['ppt/media/$filename'];
    if (mediaMap.containsKey('media/$filename')) return mediaMap['media/$filename'];

    for (final entry in mediaMap.entries) {
      if (entry.key.toLowerCase().endsWith(filename.toLowerCase())) {
        return entry.value;
      }
    }
    return null;
  }

  /// Parses a single slide XML into positioned PDF widgets with background and master shape graphics
  static List<pw.Widget> _parseSlide({
    required String slideXmlStr,
    required double slideWidthPt,
    required double slideHeightPt,
    required PptxTheme theme,
    required Map<String, Uint8List> mediaMap,
    required Map<String, String> slideRelsMap,
    PptxMasterLayoutInfo? layoutInfo,
    required bool isDarkMode,
  }) {
    final widgets = <pw.Widget>[];
    final darkRegions = <PptxDarkRegion>[];

    try {
      final doc = XmlDocument.parse(slideXmlStr);

      // Check if slide explicitly hides master shapes (<p:cSld showMasterSp="0"/>)
      final cSld = doc.findAllElements('p:cSld').firstOrNull;
      final showMasterSp = cSld?.getAttribute('showMasterSp') != '0' && cSld?.getAttribute('showMasterSp') != 'false';

      // 1. Resolve Slide Background (Slide -> Layout -> Master -> Theme Fallback)
      var bgFill = _extractBackgroundFill(slideXmlStr, theme, slideRelsMap, mediaMap);
      if (bgFill.isEmpty && layoutInfo?.background != null && !layoutInfo!.background!.isEmpty) {
        bgFill = layoutInfo.background!;
      }

      // Explicit Canvas Base Colors
      const darkCanvasColor = PdfColor.fromInt(0xFF181818);
      const lightCanvasColor = PdfColor.fromInt(0xFFFFFFFF);

      if (bgFill.imageBytes != null && bgFill.imageBytes!.length > 200) {
        widgets.add(
          pw.Positioned.fill(
            child: pw.Image(pw.MemoryImage(bgFill.imageBytes!), fit: pw.BoxFit.cover),
          ),
        );
      } else if (bgFill.gradient != null) {
        pw.LinearGradient canvasGradient = bgFill.gradient!;
        double totalLum = 0;
        for (final clr in bgFill.gradient!.colors) {
          totalLum += 0.299 * clr.red + 0.587 * clr.green + 0.114 * clr.blue;
        }
        final avgLum = totalLum / bgFill.gradient!.colors.length;

        if (isDarkMode) {
          // If background gradient is light, adapt it to a sleek dark gradient
          if (avgLum > 0.5) {
            canvasGradient = pw.LinearGradient(
              begin: canvasGradient.begin,
              end: canvasGradient.end,
              colors: [const PdfColor.fromInt(0xFF181818), const PdfColor.fromInt(0xFF222226)],
            );
          }
          darkRegions.add(PptxDarkRegion(left: 0, top: 0, right: slideWidthPt, bottom: slideHeightPt));
        } else {
          if (avgLum < 0.55) {
            darkRegions.add(PptxDarkRegion(left: 0, top: 0, right: slideWidthPt, bottom: slideHeightPt));
          }
        }

        widgets.add(
          pw.Positioned(
            left: 0,
            top: 0,
            child: pw.Container(
              width: slideWidthPt,
              height: slideHeightPt,
              decoration: pw.BoxDecoration(gradient: canvasGradient),
            ),
          ),
        );
      } else {
        PdfColor color;
        if (isDarkMode) {
          if (bgFill.solidColor != null) {
            final lum = 0.299 * bgFill.solidColor!.red + 0.587 * bgFill.solidColor!.green + 0.114 * bgFill.solidColor!.blue;
            // Adapt light backgrounds (white, cream, light grey) to dark canvas
            color = (lum > 0.5) ? darkCanvasColor : bgFill.solidColor!;
          } else {
            color = darkCanvasColor;
          }
          darkRegions.add(PptxDarkRegion(left: 0, top: 0, right: slideWidthPt, bottom: slideHeightPt));
        } else {
          color = bgFill.solidColor ?? lightCanvasColor;
          final lum = 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue;
          if (lum < 0.55) {
            darkRegions.add(PptxDarkRegion(left: 0, top: 0, right: slideWidthPt, bottom: slideHeightPt));
          }
        }

        widgets.add(
          pw.Positioned(
            left: 0,
            top: 0,
            child: pw.Container(
              width: slideWidthPt,
              height: slideHeightPt,
              color: color,
            ),
          ),
        );
      }

      // 2. Render Slide Master / Layout Decorative Shapes (Banners, Wave Accents, Footer Strips)
      if (showMasterSp && layoutInfo != null && layoutInfo.decorativeShapes.isNotEmpty) {
        final masterRels = layoutInfo.rels;
        for (final masterShape in layoutInfo.decorativeShapes) {
          final name = masterShape.name.local;
          if (name == 'sp') {
            final w = _parseShape(
              masterShape,
              slideWidthPt,
              slideHeightPt,
              theme,
              mediaMap,
              masterRels,
              isDarkMode,
              isMasterGraphic: true,
              darkRegions: darkRegions,
            );
            if (w != null) widgets.add(w);
          } else if (name == 'pic') {
            final w = _parsePicture(masterShape, slideWidthPt, slideHeightPt, mediaMap, masterRels);
            if (w != null) widgets.add(w);
          }
        }
      }

      // 3. Parse Slide's own Shape Tree (<p:spTree>)
      final spTree = doc.findAllElements('p:spTree').firstOrNull;
      if (spTree != null) {
        _parseShapeTree(
          spTree,
          widgets,
          slideWidthPt,
          slideHeightPt,
          theme,
          mediaMap,
          slideRelsMap,
          isDarkMode,
          darkRegions: darkRegions,
        );
      }
    } catch (e) {
      debugPrint('[PptxToPdf] Error parsing slide elements: $e');
    }

    if (widgets.isEmpty) {
      widgets.add(
        pw.Positioned(
          left: 0,
          top: 0,
          child: pw.Container(
            width: slideWidthPt,
            height: slideHeightPt,
            color: isDarkMode ? const PdfColor.fromInt(0xFF1E1E1E) : const PdfColor.fromInt(0xFFFFFFFF),
            child: pw.Center(
              child: pw.Text('Slide', style: pw.TextStyle(color: isDarkMode ? PdfColors.white : PdfColors.black)),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  /// Parses elements inside <p:spTree> sequentially
  static void _parseShapeTree(
    XmlElement container,
    List<pw.Widget> outWidgets,
    double slideWidthPt,
    double slideHeightPt,
    PptxTheme theme,
    Map<String, Uint8List> mediaMap,
    Map<String, String> relsMap,
    bool isDarkMode, {
    List<PptxDarkRegion>? darkRegions,
  }) {
    for (final child in container.childElements) {
      final name = child.name.local;

      if (name == 'sp') {
        // Shape or Text Box
        final widget = _parseShape(
          child,
          slideWidthPt,
          slideHeightPt,
          theme,
          mediaMap,
          relsMap,
          isDarkMode,
          darkRegions: darkRegions,
        );
        if (widget != null) outWidgets.add(widget);
      } else if (name == 'pic') {
        // Picture / Image
        final widget = _parsePicture(child, slideWidthPt, slideHeightPt, mediaMap, relsMap);
        if (widget != null) outWidgets.add(widget);
      } else if (name == 'graphicFrame') {
        // Table or Graphic Object
        final widget = _parseGraphicFrame(child, slideWidthPt, slideHeightPt, theme, isDarkMode);
        if (widget != null) outWidgets.add(widget);
      } else if (name == 'grpSp') {
        // Group shape: recursively parse inner shapes
        _parseShapeTree(
          child,
          outWidgets,
          slideWidthPt,
          slideHeightPt,
          theme,
          mediaMap,
          relsMap,
          isDarkMode,
          darkRegions: darkRegions,
        );
      }
    }
  }

  /// Parses a DrawingML gradient fill (<a:gradFill>)
  static pw.LinearGradient? _parseGradient(XmlElement gradFill, PptxTheme theme) {
    final gsLst = gradFill.findElements('a:gsLst').firstOrNull;
    if (gsLst == null) return null;

    final stopsList = <MapEntry<double, PdfColor>>[];

    for (final gs in gsLst.findElements('a:gs')) {
      final posStr = gs.getAttribute('pos');
      final pos = ((double.tryParse(posStr ?? '0') ?? 0.0) / 100000.0).clamp(0.0, 1.0);
      final color = theme.resolveColor(gs, PdfColors.blue);
      stopsList.add(MapEntry(pos, color));
    }

    if (stopsList.isEmpty) return null;

    // Sort stops ascending by position
    stopsList.sort((a, b) => a.key.compareTo(b.key));

    final colors = stopsList.map((e) => e.value).toList();
    final stops = stopsList.map((e) => e.key).toList();

    if (colors.length == 1) {
      colors.add(colors.first);
      stops.add(1.0);
    }

    // Gradient Angle (ang is in 60,000ths of a degree)
    final lin = gradFill.findElements('a:lin').firstOrNull;
    final angStr = lin?.getAttribute('ang');
    double angleDeg = 90.0; // Default top-to-bottom
    if (angStr != null) {
      angleDeg = (double.tryParse(angStr) ?? 5400000.0) / 60000.0;
    }

    final rad = (angleDeg * math.pi) / 180.0;
    final x = math.cos(rad);
    final y = math.sin(rad);

    return pw.LinearGradient(
      begin: pw.Alignment(-x, -y),
      end: pw.Alignment(x, y),
      colors: colors,
      stops: stops,
    );
  }

  /// Parses a Shape (<p:sp>) into a positioned container with vector graphic, text, background fill, or image
  static pw.Widget? _parseShape(
    XmlElement spElem,
    double slideWidthPt,
    double slideHeightPt,
    PptxTheme theme,
    Map<String, Uint8List> mediaMap,
    Map<String, String> relsMap,
    bool isDarkMode, {
    bool isMasterGraphic = false,
    List<PptxDarkRegion>? darkRegions,
  }) {
    final spPr = spElem.findElements('p:spPr').firstOrNull;
    final xfrm = spPr?.findElements('a:xfrm').firstOrNull;
    if (xfrm == null) return null;

    final off = xfrm.findElements('a:off').firstOrNull;
    final ext = xfrm.findElements('a:ext').firstOrNull;
    if (off == null || ext == null) return null;

    final xEmus = double.tryParse(off.getAttribute('x') ?? '0') ?? 0;
    final yEmus = double.tryParse(off.getAttribute('y') ?? '0') ?? 0;
    final wEmus = double.tryParse(ext.getAttribute('cx') ?? '0') ?? 0;
    final hEmus = double.tryParse(ext.getAttribute('cy') ?? '0') ?? 0;

    if (wEmus <= 0 || hEmus <= 0) return null;

    final leftPt = xEmus / 12700.0;
    final topPt = yEmus / 12700.0;
    final widthPt = wEmus / 12700.0;
    final heightPt = hEmus / 12700.0;

    // Detect placeholder type
    final nvPr = spElem.findElements('p:nvSpPr').firstOrNull?.findElements('p:nvPr').firstOrNull;
    final ph = nvPr?.findElements('p:ph').firstOrNull;
    final phType = ph?.getAttribute('type')?.toLowerCase() ?? '';
    final isTitle = phType == 'title' || phType == 'ctrtitle';
    final isSubTitle = phType == 'subtitle' || phType == 'subTitle';

    // Preset geometry or custom geometry (<a:prstGeom> / <a:custGeom>)
    final prstGeom = spPr?.findElements('a:prstGeom').firstOrNull?.getAttribute('prst')?.toLowerCase() ?? 'rect';
    final isCircleOrEllipse = prstGeom == 'ellipse';
    final isRoundedRect = prstGeom.startsWith('round');

    // Shape Fill Color / Gradient / Image
    PdfColor? shapeBgColor;
    pw.LinearGradient? shapeGradient;
    Uint8List? shapeImageBytes;

    // 1. Solid Fill (<a:solidFill>)
    final solidFill = spPr?.findElements('a:solidFill').firstOrNull;
    if (solidFill != null) {
      shapeBgColor = theme.resolveColor(
        solidFill,
        isDarkMode ? const PdfColor.fromInt(0xFF2A2A2E) : const PdfColor.fromInt(0xFFF3F4F6),
      );
    }

    // 2. Gradient Fill (<a:gradFill>)
    final gradFill = spPr?.findElements('a:gradFill').firstOrNull;
    if (gradFill != null) {
      shapeGradient = _parseGradient(gradFill, theme);
    }

    // 3. Pattern Fill (<a:pattFill>) - Intercept pattern fills and render as crisp solid vector fills
    final pattFill = spPr?.findElements('a:pattFill').firstOrNull;
    if (pattFill != null && shapeBgColor == null && shapeGradient == null) {
      final fgClr = pattFill.findElements('a:fgClr').firstOrNull;
      final bgClr = pattFill.findElements('a:bgClr').firstOrNull;
      final chosen = fgClr ?? bgClr;
      if (chosen != null) {
        shapeBgColor = theme.resolveColor(
          chosen,
          isDarkMode ? const PdfColor.fromInt(0xFF2A2A2E) : const PdfColor.fromInt(0xFFF3F4F6),
        );
      }
    }

    // 4. Picture / Image Fill (<a:blipFill>)
    final blipFill = spPr?.findElements('a:blipFill').firstOrNull;
    final rEmbed = blipFill?.findElements('a:blip').firstOrNull?.getAttribute('r:embed');
    if (rEmbed != null) {
      final img = _findImageBytes(rEmbed, relsMap, mediaMap);
      // Suppress tiny/low-res pattern bitmap tiles (< 200 bytes) that cause staircase grid artifacts
      if (img != null && img.length > 200) {
        shapeImageBytes = img;
      }
    }

    // 5. Check <p:style><a:fillRef> for shapes inheriting theme styles
    if (shapeBgColor == null && shapeGradient == null && shapeImageBytes == null) {
      final style = spElem.findElements('p:style').firstOrNull;
      final fillRef = style?.findElements('a:fillRef').firstOrNull;
      if (fillRef != null) {
        final idx = int.tryParse(fillRef.getAttribute('idx') ?? '0') ?? 0;
        if (idx > 0) {
          shapeBgColor = theme.resolveColor(
            fillRef,
            isDarkMode ? const PdfColor.fromInt(0xFF2A2A2E) : const PdfColor.fromInt(0xFFF3F4F6),
          );
        }
      }
    }

    // Shape Border / Outline (<a:ln> or <p:style><a:lnRef>)
    pw.BoxBorder? border;
    final ln = spPr?.findElements('a:ln').firstOrNull;
    if (ln != null) {
      final lnW = double.tryParse(ln.getAttribute('w') ?? '12700') ?? 12700;
      final strokeWidth = (lnW / 12700.0).clamp(0.5, 6.0);
      final lnSolid = ln.findElements('a:solidFill').firstOrNull;
      if (lnSolid != null) {
        final lnColor = theme.resolveColor(lnSolid, isDarkMode ? PdfColors.grey700 : PdfColors.grey400);
        border = pw.Border.all(color: lnColor, width: strokeWidth);
      }
    } else {
      final style = spElem.findElements('p:style').firstOrNull;
      final lnRef = style?.findElements('a:lnRef').firstOrNull;
      if (lnRef != null) {
        final idx = int.tryParse(lnRef.getAttribute('idx') ?? '0') ?? 0;
        if (idx > 0) {
          final lnColor = theme.resolveColor(lnRef, isDarkMode ? PdfColors.grey700 : PdfColors.grey400);
          border = pw.Border.all(color: lnColor, width: 1.0);
        }
      }
    }

    // Determine if shape background or overlapping canvas is dark to enforce high-contrast text
    bool isBackgroundDark = false;
    if (shapeBgColor != null) {
      final lum = 0.299 * shapeBgColor.red + 0.587 * shapeBgColor.green + 0.114 * shapeBgColor.blue;
      if (lum < 0.55) isBackgroundDark = true;
    } else if (shapeGradient != null && shapeGradient.colors.isNotEmpty) {
      double totalLum = 0;
      for (final clr in shapeGradient.colors) {
        totalLum += 0.299 * clr.red + 0.587 * clr.green + 0.114 * clr.blue;
      }
      final avgLum = totalLum / shapeGradient.colors.length;
      if (avgLum < 0.65) isBackgroundDark = true;
    }

    // Check if this shape sits over a registered dark region (e.g. master header/footer banner)
    if (!isBackgroundDark && darkRegions != null && darkRegions.isNotEmpty) {
      final centerX = leftPt + (widthPt / 2.0);
      final centerY = topPt + (heightPt / 2.0);
      for (final region in darkRegions) {
        if (region.containsPoint(centerX, centerY)) {
          isBackgroundDark = true;
          break;
        }
      }
    }

    // Register this shape as a dark region if it has dark fill so subsequent shapes inherit contrast
    if (isBackgroundDark && (shapeBgColor != null || shapeGradient != null) && darkRegions != null) {
      darkRegions.add(PptxDarkRegion(
        left: leftPt,
        top: topPt,
        right: leftPt + widthPt,
        bottom: topPt + heightPt,
      ));
    }

    // Text Content (<p:txBody>)
    // Master layout shapes are purely decorative visual graphics; never parse placeholder prompt strings
    final txBody = isMasterGraphic ? null : spElem.findElements('p:txBody').firstOrNull;
    final textWidgets = <pw.Widget>[];

    // Read Text Box Padding Insets (lIns, tIns, rIns, bIns in EMUs)
    final bodyPr = txBody?.findElements('a:bodyPr').firstOrNull;
    double lInsPt = 7.2; // default 91440 EMU
    double tInsPt = 3.6; // default 45720 EMU
    double rInsPt = 7.2;
    double bInsPt = 3.6;

    if (bodyPr != null) {
      final lIns = double.tryParse(bodyPr.getAttribute('lIns') ?? '');
      final tIns = double.tryParse(bodyPr.getAttribute('tIns') ?? '');
      final rIns = double.tryParse(bodyPr.getAttribute('rIns') ?? '');
      final bIns = double.tryParse(bodyPr.getAttribute('bIns') ?? '');
      if (lIns != null) lInsPt = lIns / 12700.0;
      if (tIns != null) tInsPt = tIns / 12700.0;
      if (rIns != null) rInsPt = rIns / 12700.0;
      if (bIns != null) bInsPt = bIns / 12700.0;
    }

    if (txBody != null) {
      final paragraphs = txBody.findElements('a:p');
      for (final p in paragraphs) {
        final pWidget = _parseSlideParagraph(
          p,
          theme: theme,
          isDarkMode: isDarkMode,
          isTitle: isTitle,
          isSubTitle: isSubTitle,
          isInsideDarkShape: isBackgroundDark,
        );
        if (pWidget != null) {
          textWidgets.add(pWidget);
        }
      }
    }

    // If placeholder shape on slide has no override text and no explicit fill/border, suppress it entirely
    if (ph != null && textWidgets.isEmpty && shapeBgColor == null && shapeGradient == null && shapeImageBytes == null && border == null) {
      return null;
    }

    // If master graphic and has no real text content and no fill/stroke/image, skip
    if (isMasterGraphic && textWidgets.isEmpty && shapeBgColor == null && shapeGradient == null && shapeImageBytes == null && border == null) {
      return null;
    }

    // If standard shape has nothing to display, skip
    if (textWidgets.isEmpty && shapeBgColor == null && shapeGradient == null && shapeImageBytes == null && border == null) {
      return null;
    }

    // Vertical alignment inside text frame
    final anchor = bodyPr?.getAttribute('anchor');
    pw.MainAxisAlignment mainAxisAlignment = pw.MainAxisAlignment.start;
    if (anchor == 'ctr') {
      mainAxisAlignment = pw.MainAxisAlignment.center;
    } else if (anchor == 'b') {
      mainAxisAlignment = pw.MainAxisAlignment.end;
    }

    // Standard / Rounded / Elliptical Shapes & Vector Containers
    pw.BoxShape boxShape = isCircleOrEllipse ? pw.BoxShape.circle : pw.BoxShape.rectangle;
    pw.BorderRadius? borderRadius;
    if (isRoundedRect && !isCircleOrEllipse) {
      borderRadius = pw.BorderRadius.circular(math.min(12.0, heightPt / 3.0));
    }

    return pw.Positioned(
      left: leftPt,
      top: topPt,
      child: pw.Container(
        width: widthPt,
        height: heightPt,
        padding: textWidgets.isNotEmpty
            ? pw.EdgeInsets.fromLTRB(lInsPt, tInsPt, rInsPt, bInsPt)
            : const pw.EdgeInsets.all(0),
        decoration: pw.BoxDecoration(
          color: shapeBgColor,
          gradient: shapeGradient,
          border: border,
          shape: boxShape,
          borderRadius: borderRadius,
        ),
        child: pw.Stack(
          children: [
            if (shapeImageBytes != null)
              pw.Positioned.fill(
                child: pw.Image(pw.MemoryImage(shapeImageBytes), fit: pw.BoxFit.fill),
              ),
            if (textWidgets.isNotEmpty)
              pw.Column(
                crossAxisAlignment: isTitle || isSubTitle ? pw.CrossAxisAlignment.center : pw.CrossAxisAlignment.start,
                mainAxisAlignment: mainAxisAlignment,
                children: textWidgets,
              ),
          ],
        ),
      ),
    );
  }

  /// Parses a Picture (<p:pic>) into a positioned image widget
  static pw.Widget? _parsePicture(
    XmlElement picElem,
    double slideWidthPt,
    double slideHeightPt,
    Map<String, Uint8List> mediaMap,
    Map<String, String> relsMap,
  ) {
    final spPr = picElem.findElements('p:spPr').firstOrNull;
    final xfrm = spPr?.findElements('a:xfrm').firstOrNull;
    if (xfrm == null) return null;

    final off = xfrm.findElements('a:off').firstOrNull;
    final ext = xfrm.findElements('a:ext').firstOrNull;
    if (off == null || ext == null) return null;

    final xEmus = double.tryParse(off.getAttribute('x') ?? '0') ?? 0;
    final yEmus = double.tryParse(off.getAttribute('y') ?? '0') ?? 0;
    final wEmus = double.tryParse(ext.getAttribute('cx') ?? '0') ?? 0;
    final hEmus = double.tryParse(ext.getAttribute('cy') ?? '0') ?? 0;

    if (wEmus <= 0 || hEmus <= 0) return null;

    final leftPt = xEmus / 12700.0;
    final topPt = yEmus / 12700.0;
    final widthPt = wEmus / 12700.0;
    final heightPt = hEmus / 12700.0;

    // Extract embedded image relationship ID
    final blip = picElem.findAllElements('a:blip').firstOrNull;
    final rEmbed = blip?.getAttribute('r:embed');
    if (rEmbed == null) return null;

    final imageBytes = _findImageBytes(rEmbed, relsMap, mediaMap);
    if (imageBytes == null || imageBytes.isEmpty) return null;

    try {
      final memoryImage = pw.MemoryImage(imageBytes);
      return pw.Positioned(
        left: leftPt,
        top: topPt,
        child: pw.SizedBox(
          width: widthPt,
          height: heightPt,
          child: pw.Image(memoryImage, fit: pw.BoxFit.contain),
        ),
      );
    } catch (e) {
      debugPrint('[PptxToPdf] Error loading embedded slide image: $e');
      return null;
    }
  }

  /// Parses a Graphic Frame (<p:graphicFrame>) holding Tables (<a:tbl>)
  static pw.Widget? _parseGraphicFrame(
    XmlElement gfElem,
    double slideWidthPt,
    double slideHeightPt,
    PptxTheme theme,
    bool isDarkMode,
  ) {
    final xfrm = gfElem.findElements('p:xfrm').firstOrNull;
    if (xfrm == null) return null;

    final off = xfrm.findElements('a:off').firstOrNull;
    final ext = xfrm.findElements('a:ext').firstOrNull;
    if (off == null || ext == null) return null;

    final xEmus = double.tryParse(off.getAttribute('x') ?? '0') ?? 0;
    final yEmus = double.tryParse(off.getAttribute('y') ?? '0') ?? 0;
    final wEmus = double.tryParse(ext.getAttribute('cx') ?? '0') ?? 0;
    final hEmus = double.tryParse(ext.getAttribute('cy') ?? '0') ?? 0;

    if (wEmus <= 0 || hEmus <= 0) return null;

    final leftPt = xEmus / 12700.0;
    final topPt = yEmus / 12700.0;
    final widthPt = wEmus / 12700.0;
    final heightPt = hEmus / 12700.0;

    final tbl = gfElem.findAllElements('a:tbl').firstOrNull;
    if (tbl == null) return null;

    final rows = <pw.TableRow>[];
    final trElements = tbl.findElements('a:tr');
    final borderColor = isDarkMode ? const PdfColor.fromInt(0xFF444444) : const PdfColor.fromInt(0xFFD1D5DB);

    for (final tr in trElements) {
      final cells = <pw.Widget>[];
      final tcElements = tr.findElements('a:tc');

      for (final tc in tcElements) {
        final cellTextWidgets = <pw.Widget>[];
        final txBody = tc.findElements('a:txBody').firstOrNull;
        if (txBody != null) {
          for (final p in txBody.findElements('a:p')) {
            final pWidget = _parseSlideParagraph(p, theme: theme, isDarkMode: isDarkMode);
            if (pWidget != null) cellTextWidgets.add(pWidget);
          }
        }

        // Cell background
        PdfColor? cellBg;
        final tcPr = tc.findElements('a:tcPr').firstOrNull;
        final solidFill = tcPr?.findElements('a:solidFill').firstOrNull;
        if (solidFill != null) {
          cellBg = theme.resolveColor(
            solidFill,
            isDarkMode ? const PdfColor.fromInt(0xFF2A2A2E) : const PdfColor.fromInt(0xFFF9FAFB),
          );
        }

        cells.add(
          pw.Container(
            color: cellBg,
            padding: const pw.EdgeInsets.all(4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: cellTextWidgets.isEmpty ? [pw.SizedBox(height: 6)] : cellTextWidgets,
            ),
          ),
        );
      }

      if (cells.isNotEmpty) {
        rows.add(pw.TableRow(children: cells));
      }
    }

    if (rows.isEmpty) return null;

    return pw.Positioned(
      left: leftPt,
      top: topPt,
      child: pw.SizedBox(
        width: widthPt,
        height: heightPt,
        child: pw.Table(
          border: pw.TableBorder.all(color: borderColor, width: 0.5),
          children: rows,
        ),
      ),
    );
  }

  /// Parses a slide paragraph (<a:p>) with placeholder inheritance and exact contrast fallbacks
  static pw.Widget? _parseSlideParagraph(
    XmlElement pElem, {
    required PptxTheme theme,
    required bool isDarkMode,
    bool isTitle = false,
    bool isSubTitle = false,
    bool isInsideDarkShape = false,
  }) {
    final pPr = pElem.findElements('a:pPr').firstOrNull;

    // Alignment
    pw.TextAlign textAlign = pw.TextAlign.left;
    if (pPr != null) {
      final algn = pPr.getAttribute('algn');
      if (algn == 'ctr') {
        textAlign = pw.TextAlign.center;
      } else if (algn == 'r') {
        textAlign = pw.TextAlign.right;
      } else if (algn == 'just') {
        textAlign = pw.TextAlign.justify;
      }
    } else if (isTitle || isSubTitle) {
      textAlign = pw.TextAlign.center;
    }

    // Default font sizes based on role
    double defaultFontSize = 14.0;
    bool defaultBold = false;
    if (isTitle) {
      defaultFontSize = 28.0;
      defaultBold = true;
    } else if (isSubTitle) {
      defaultFontSize = 16.0;
    }

    final spans = <pw.InlineSpan>[];
    final defaultBulletColor = isInsideDarkShape 
        ? PdfColors.white 
        : (isDarkMode ? const PdfColor.fromInt(0xFFE0E0E0) : const PdfColor.fromInt(0xFF111111));

    // Check bullet formatting (<a:buChar>, <a:buAutoNum>)
    final buChar = pPr?.findElements('a:buChar').firstOrNull?.getAttribute('char');
    final buNone = pPr?.findElements('a:buNone').firstOrNull;
    if (buNone == null && buChar != null && buChar.isNotEmpty) {
      spans.add(
        pw.TextSpan(
          text: '${sanitizeText(buChar)} ',
          style: pw.TextStyle(
            fontSize: defaultFontSize,
            fontWeight: pw.FontWeight.bold,
            color: defaultBulletColor,
          ),
        ),
      );
    }

    final childElements = pElem.childElements;
    for (final child in childElements) {
      if (child.name.local == 'r') {
        // Text run
        final rPr = child.findElements('a:rPr').firstOrNull;
        
        bool isBold = defaultBold;
        bool isItalic = false;
        bool isUnderline = false;
        double fontSize = defaultFontSize;
        XmlElement? solidFill;

        if (rPr != null) {
          if (rPr.getAttribute('b') == '1') isBold = true;
          if (rPr.getAttribute('i') == '1') isItalic = true;
          if (rPr.getAttribute('u') != null && rPr.getAttribute('u') != 'none') isUnderline = true;

          // Font size in hundredths of a point (e.g. 2800 = 28pt)
          final szStr = rPr.getAttribute('sz');
          if (szStr != null) {
            final sz = double.tryParse(szStr);
            if (sz != null && sz > 0) {
              fontSize = sz / 100.0;
            }
          }

          solidFill = rPr.findElements('a:solidFill').firstOrNull;
        }

        final resolvedColor = _resolveTextColor(
          solidFillNode: solidFill,
          theme: theme,
          isDarkMode: isDarkMode,
          isTitle: isTitle,
          isSubTitle: isSubTitle,
          isInsideDarkShape: isInsideDarkShape,
        );

        final tElem = child.findElements('a:t').firstOrNull;
        if (tElem != null) {
          final rawText = tElem.innerText;
          if (rawText.isNotEmpty && !_isPlaceholderPromptText(rawText)) {
            final sanitizedText = sanitizeText(rawText);
            if (sanitizedText.trim().isNotEmpty) {
              spans.add(
                pw.TextSpan(
                  text: sanitizedText,
                  style: pw.TextStyle(
                    fontSize: fontSize,
                    lineSpacing: 1.3,
                    fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    fontStyle: isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
                    decoration: isUnderline ? pw.TextDecoration.underline : null,
                    color: resolvedColor,
                  ),
                ),
              );
            }
          }
        }
      } else if (child.name.local == 'br') {
        if (spans.isNotEmpty) {
          spans.add(const pw.TextSpan(text: '\n'));
        }
      }
    }

    if (spans.isEmpty) {
      return null;
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        textAlign: textAlign,
        text: pw.TextSpan(children: spans),
      ),
    );
  }

  /// Checks whether a given string is a default OpenXML template prompt
  static bool isMasterPlaceholderPrompt(String text) {
    final clean = text.trim().toLowerCase();
    if (clean.isEmpty) return true;
    if (clean.startsWith('click to edit') || clean.startsWith('click to add')) return true;
    if (clean.contains('master title style') ||
        clean.contains('master subtitle style') ||
        clean.contains('master text style') ||
        clean.contains('master text styles') ||
        clean.contains('master body style') ||
        clean.contains('master body styles') ||
        clean.contains('master header style') ||
        clean.contains('master footer style')) {
      return true;
    }
    if (clean == 'second level' ||
        clean == 'third level' ||
        clean == 'fourth level' ||
        clean == 'fifth level') {
      return true;
    }
    return false;
  }

  static bool _isPlaceholderPromptText(String text) => isMasterPlaceholderPrompt(text);

  /// Sanitizes smart quotes, dashes, spaces, and private-use Unicode symbols
  static String sanitizeText(String text) {
    if (text.isEmpty) return text;
    final buffer = StringBuffer();

    for (final char in text.runes) {
      // 1. Smart Double Quotes
      if (char == 0x201C || char == 0x201D || char == 0x201E || char == 0x201F ||
          char == 0x00AB || char == 0x00BB || char == 0x2033 || char == 0x2036) {
        buffer.write('"');
      }
      // 2. Smart Single Quotes & Apostrophes
      else if (char == 0x2018 || char == 0x2019 || char == 0x201A || char == 0x201B ||
               char == 0x0060 || char == 0x00B4 || char == 0x2032 || char == 0x2035) {
        buffer.write("'");
      }
      // 3. Em-Dashes, En-Dashes & Hyphens
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
        // Skip
      }
      // 6. Ellipsis
      else if (char == 0x2026) {
        buffer.write('...');
      }
      // 7. Bullets and Shapes
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
      // 10. Word Wingdings / Symbol Private Use Area
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
      else {
        buffer.writeCharCode(char);
      }
    }

    return buffer.toString();
  }

  /// Resolves text color with high-contrast rules, theme resolution, and placeholder defaults
  static PdfColor _resolveTextColor({
    XmlElement? solidFillNode,
    required PptxTheme theme,
    required bool isDarkMode,
    bool isTitle = false,
    bool isSubTitle = false,
    bool isInsideDarkShape = false,
  }) {
    // 1. If text sits on a dark/gradient shape or dark canvas region, enforce high contrast white
    if (isInsideDarkShape) {
      if (solidFillNode != null) {
        final parsed = theme.resolveColor(solidFillNode, PdfColors.white);
        final lum = 0.299 * parsed.red + 0.587 * parsed.green + 0.114 * parsed.blue;
        if (lum < 0.55) {
          return PdfColors.white;
        }
        return parsed;
      }
      return PdfColors.white;
    }

    // 2. Explicit Solid Fill Node (srgbClr, schemeClr, sysClr, prstClr with modifiers)
    if (solidFillNode != null) {
      final defaultFallback = isDarkMode ? const PdfColor.fromInt(0xFFE0E0E0) : const PdfColor.fromInt(0xFF111111);
      final parsed = theme.resolveColor(solidFillNode, defaultFallback);

      if (isDarkMode) {
        final double luminance = 0.299 * parsed.red + 0.587 * parsed.green + 0.114 * parsed.blue;
        if (luminance < 0.45) {
          // Adapt dark text to high-contrast light grey on dark canvas
          return const PdfColor.fromInt(0xFFE0E0E0);
        }
      } else {
        final double luminance = 0.299 * parsed.red + 0.587 * parsed.green + 0.114 * parsed.blue;
        if (luminance > 0.85) {
          // Adapt white/very light text to charcoal on white canvas
          return const PdfColor.fromInt(0xFF111111);
        }
      }
      return parsed;
    }

    // 3. Fallbacks based on placeholder role
    if (isTitle) {
      return isDarkMode ? const PdfColor.fromInt(0xFF90CAF9) : const PdfColor.fromInt(0xFF111111);
    }
    if (isSubTitle) {
      return isDarkMode ? const PdfColor.fromInt(0xFFD1D5DB) : const PdfColor.fromInt(0xFF333333);
    }
    return isDarkMode ? const PdfColor.fromInt(0xFFE0E0E0) : const PdfColor.fromInt(0xFF111111);
  }
}

/// Background isolate entry point for PPTX-to-PDF conversion
Future<Uint8List> convertPptxToPdfIsolate(PptxConversionParams params) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(params.token);
  return await PptxToPdfService.convertPptxBytesToPdf(
    params.pptxBytes,
    isDarkMode: params.isDarkMode,
    fontBytes: params.fontBytes,
  );
}
