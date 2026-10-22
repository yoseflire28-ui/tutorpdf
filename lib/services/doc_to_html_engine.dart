import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

class RenderedDocument {
  const RenderedDocument({
    required this.html,
    required this.pageCount,
    required this.title,
  });

  final String html;
  final int pageCount;
  final String title;
}

class DocToHtmlEngine {
  DocToHtmlEngine._();

  factory DocToHtmlEngine() => _instance;

  static final DocToHtmlEngine _instance = DocToHtmlEngine._();

  Future<String> convertToHtml(String inputPath) async {
    return (await renderDocument(inputPath)).html;
  }

  Future<RenderedDocument> renderDocument(String inputPath) async {
    final extension = p.extension(inputPath).toLowerCase();
    if (extension == '.pdf') {
      final fallbackHtml = '<html><body><p>PDF files are rendered by the native PDF reader.</p></body></html>';
      return RenderedDocument(
        html: fallbackHtml,
        pageCount: 1,
        title: p.basenameWithoutExtension(inputPath),
      );
    }

    final tempDir = await _getTemporaryDirectory();
    final outputFileName = '${p.basenameWithoutExtension(inputPath)}_${DateTime.now().millisecondsSinceEpoch}.html';
    final outputPath = p.join(tempDir, outputFileName);
    return Isolate.run(() => _convertToHtml(inputPath, outputPath));
  }

  Future<RenderedDocument> convertToHtmlInBackground(String inputPath) async {
    return renderDocument(inputPath);
  }
}

Future<RenderedDocument> _convertToHtml(String inputPath, String outputPath) async {
  final extension = p.extension(inputPath).toLowerCase();
  final title = p.basenameWithoutExtension(inputPath);
  late final RenderedDocument renderedDocument;

  switch (extension) {
    case '.docx':
      renderedDocument = RenderedDocument(
        html: await _buildDocxHtml(inputPath),
        pageCount: 1,
        title: title,
      );
      break;
    case '.pptx':
      renderedDocument = RenderedDocument(
        html: await _buildPptxHtml(inputPath),
        pageCount: await _countPptxSlides(inputPath),
        title: title,
      );
      break;
    case '.txt':
      renderedDocument = RenderedDocument(
        html: _buildTextHtml(await File(inputPath).readAsString()),
        pageCount: 1,
        title: title,
      );
      break;
    default:
      throw UnsupportedError('Unsupported document type: $extension');
  }

  await File(outputPath).writeAsString(renderedDocument.html, flush: true);
  return renderedDocument;
}

Future<String> _buildDocxHtml(String inputPath) async {
  final archive = _decodeZipArchive(inputPath);
  final documentXml = _extractXmlFile(archive, 'word/document.xml');
  final xmlDoc = XmlDocument.parse(documentXml);
  final body = xmlDoc.findElements('w:document').firstOrNull?.findElements('w:body').firstOrNull;
  final blocks = <String>[];

  if (body != null) {
    for (final child in body.children.whereType<XmlElement>()) {
      if (child.name.local == 'p') {
        final paragraphHtml = _renderDocxParagraph(child);
        if (paragraphHtml.isNotEmpty) {
          blocks.add(paragraphHtml);
        }
      } else if (child.name.local == 'tbl') {
        final tableHtml = _renderDocxTable(child);
        if (tableHtml.isNotEmpty) {
          blocks.add(tableHtml);
        }
      }
    }
  }

  final bodyContent = blocks.isNotEmpty ? blocks.join('\n') : '<p>Unable to parse DOCX content.</p>';
  return _wrapDocumentHtml(bodyContent, title: p.basenameWithoutExtension(inputPath));
}

Future<String> _buildPptxHtml(String inputPath) async {
  final archive = _decodeZipArchive(inputPath);
  final slideRegex = RegExp(r'^ppt/slides/slide(\d+)\.xml$');
  final slideEntries = archive.files
      .where((file) => slideRegex.hasMatch(file.name))
      .toList()
    ..sort((a, b) {
      final aMatch = slideRegex.firstMatch(a.name);
      final bMatch = slideRegex.firstMatch(b.name);
      final aIndex = aMatch != null ? int.parse(aMatch.group(1)!) : 0;
      final bIndex = bMatch != null ? int.parse(bMatch.group(1)!) : 0;
      return aIndex.compareTo(bIndex);
    });

  if (slideEntries.isEmpty) {
    return _wrapDocumentHtml('<p>No PPTX slides detected.</p>', title: p.basenameWithoutExtension(inputPath));
  }

  final slideHtml = slideEntries.map((slideFile) {
    final slideXml = utf8.decode(slideFile.content as List<int>);
    final xmlDoc = XmlDocument.parse(slideXml);
    final shapes = <String>[];
    for (final paragraph in xmlDoc.descendants.whereType<XmlElement>()) {
      if (paragraph.name.local == 't' && (paragraph.name.namespaceUri == 'http://schemas.openxmlformats.org/drawingml/2006/main' || (paragraph.name.namespaceUri?.isEmpty ?? true))) {
        final text = _normalizeText(paragraph.innerText);
        if (text.isNotEmpty) {
          shapes.add('<p>$text</p>');
        }
      }
    }
    final content = shapes.isEmpty ? '<p>Slide contains non-text media or diagrams.</p>' : shapes.join('\n');
    return '<div class="slide">$content</div>';
  }).join('\n');

  return _wrapDocumentHtml(slideHtml, title: p.basenameWithoutExtension(inputPath));
}

Future<int> _countPptxSlides(String inputPath) async {
  final archive = _decodeZipArchive(inputPath);
  final slideRegex = RegExp(r'^ppt/slides/slide(\d+)\.xml$');
  return archive.files.where((file) => slideRegex.hasMatch(file.name)).length;
}

Future<String> _getTemporaryDirectory() async {
  try {
    final directory = await getTemporaryDirectory();
    return directory.path;
  } catch (_) {
    return Directory.systemTemp.path;
  }
}

String _buildTextHtml(String text) {
  final paragraphs = text.replaceAll('\r\n', '\n').split('\n').where((line) => line.trim().isNotEmpty).toList();
  final content = paragraphs.isEmpty
      ? '<p>No text content found.</p>'
      : paragraphs.map((paragraph) => '<p>$paragraph</p>').join('\n');
  return _wrapDocumentHtml(content, title: 'Text Document');
}

String _wrapDocumentHtml(String content, {required String title}) {
  return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes" />
  <title>$title</title>
  <style>
    html, body { margin: 0; padding: 0; background: #f7f5ef; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
    body { padding: 20px 18px 40px; color: #1f1f1f; }
    .document-shell { max-width: 900px; margin: 0 auto; }
    p { margin: 0 0 10px; line-height: 1.45; }
    table { width: 100%; border-collapse: collapse; margin: 12px 0; font-size: 14px; }
    th, td { border: 1px solid #d0d7de; padding: 8px 10px; text-align: left; vertical-align: top; }
    th { background-color: #f6f8fa; font-weight: bold; }
    .slide { border: 1px solid #ddd; border-radius: 16px; padding: 24px 28px; margin: 0 0 20px; background: white; box-shadow: 0 2px 12px rgba(0,0,0,0.06); aspect-ratio: 4 / 3; display: flex; flex-direction: column; justify-content: center; }
    .slide p { font-size: 18px; }
    sup { vertical-align: super; font-size: 0.7em; }
    sub { vertical-align: sub; font-size: 0.7em; }
    @media (max-width: 700px) {
      body { padding: 12px 10px 28px; }
      .slide { padding: 16px; }
    }
  </style>
</head>
<body>
  <div class="document-shell">$content</div>
</body>
</html>''';
}

String _renderDocxParagraph(XmlElement paragraph) {
  final alignment = _readParagraphAlignment(paragraph);
  final marginBottom = _readParagraphSpacing(paragraph);
  final styles = <String>[];
  if (alignment != null) {
    styles.add('text-align: $alignment');
  }
  if (marginBottom != null) {
    styles.add('margin-bottom: $marginBottom');
  }

  final textParts = <String>[];
  for (final child in paragraph.children.whereType<XmlElement>()) {
    if (child.name.local == 'r') {
      final runText = _renderDocxRun(child);
      if (runText.isNotEmpty) {
        textParts.add(runText);
      }
    }
  }

  final content = textParts.join('');
  if (content.isEmpty) {
    return '';
  }

  final styleAttribute = styles.isEmpty ? '' : ' style="${styles.join('; ')}"';
  return '<p$styleAttribute>${content}</p>';
}

String _renderDocxTable(XmlElement table) {
  final rows = <String>[];
  for (final row in table.children.whereType<XmlElement>()) {
    if (row.name.local != 'tr') {
      continue;
    }

    final cells = <String>[];
    for (final cell in row.children.whereType<XmlElement>()) {
      if (cell.name.local != 'tc') {
        continue;
      }

      final paragraphs = <String>[];
      for (final paragraph in cell.children.whereType<XmlElement>()) {
        if (paragraph.name.local == 'p') {
          final paragraphHtml = _renderDocxParagraph(paragraph);
          if (paragraphHtml.isNotEmpty) {
            paragraphs.add(paragraphHtml);
          }
        }
      }

      final cellContent = paragraphs.isNotEmpty ? paragraphs.join('') : '<p></p>';
      final isHeader = _isTableHeaderRow(table, rows.length);
      final tag = isHeader ? 'th' : 'td';
      cells.add('<$tag>$cellContent</$tag>');
    }

    if (cells.isNotEmpty) {
      rows.add('<tr>${cells.join()}</tr>');
    }
  }

  if (rows.isEmpty) {
    return '';
  }

  final tableBody = rows.join('\n');
  return '<table><tbody>$tableBody</tbody></table>';
}

bool _isTableHeaderRow(XmlElement table, int rowIndex) {
  if (table.children.whereType<XmlElement>().where((child) => child.name.local == 'tr').isEmpty) {
    return false;
  }

  final firstRowIndex = 0;
  return rowIndex == firstRowIndex;
}

String _renderDocxRun(XmlElement run) {
  final runProperties = run.findElements('w:rPr').firstOrNull;
  final styleParts = <String>[];
  final content = _extractTextFromRun(run);
  if (content.isEmpty) {
    return '';
  }

  final isBold = runProperties?.findElements('w:b').isNotEmpty ?? false;
  if (isBold) {
    styleParts.add('font-weight: bold');
  }

  final isItalic = runProperties?.findElements('w:i').isNotEmpty ?? false;
  if (isItalic) {
    styleParts.add('font-style: italic');
  }

  final hasUnderline = runProperties?.findElements('w:u').isNotEmpty ?? false;
  if (hasUnderline) {
    styleParts.add('text-decoration: underline');
  }

  final fontName = _readRunFontName(runProperties);
  if (fontName != null) {
    styleParts.add('font-family: $fontName');
  }

  final fontSize = _readRunFontSize(runProperties);
  if (fontSize != null) {
    styleParts.add('font-size: ${fontSize.toStringAsFixed(0)}px');
  }

  final color = _readRunColor(runProperties);
  if (color != null) {
    styleParts.add('color: #$color');
  }

  final highlight = _readRunHighlight(runProperties);
  if (highlight != null) {
    styleParts.add('background-color: #$highlight');
  }

  final spacing = _readRunSpacing(runProperties);
  if (spacing != null) {
    styleParts.add('letter-spacing: ${spacing}px');
  }

  final position = _readRunPosition(runProperties);
  if (position != null) {
    if (position > 0) {
      styleParts.add('vertical-align: super');
    } else if (position < 0) {
      styleParts.add('vertical-align: sub');
    }
  }

  final lineHeight = _readLineHeight(runProperties);
  if (lineHeight != null) {
    styleParts.add('line-height: $lineHeight');
  }

  if (styleParts.isEmpty) {
    return content;
  }

  final style = styleParts.join('; ');
  return '<span style="$style">$content</span>';
}

String _extractTextFromRun(XmlElement run) {
  return run.findElements('w:t').map((node) => _normalizeText(node.innerText)).join('');
}

String? _readParagraphAlignment(XmlElement paragraph) {
  final pPr = paragraph.findElements('w:pPr').firstOrNull;
  final jc = pPr?.findElements('w:jc').firstOrNull;
  final val = jc?.getAttribute('w:val') ?? jc?.getAttribute('val');
  if (val == null) return null;
  switch (val) {
    case 'center':
      return 'center';
    case 'right':
      return 'right';
    case 'justify':
      return 'justify';
    default:
      return 'left';
  }
}

String? _readParagraphSpacing(XmlElement paragraph) {
  final pPr = paragraph.findElements('w:pPr').firstOrNull;
  final spacing = pPr?.findElements('w:spacing').firstOrNull;
  final after = spacing?.getAttribute('w:after') ?? spacing?.getAttribute('after');
  if (after == null) return null;
  final value = double.tryParse(after);
  return value == null ? null : '${(value / 20).toStringAsFixed(2)}px';
}

String? _readRunFontName(XmlElement? properties) {
  final fonts = properties?.findElements('w:rFonts').firstOrNull;
  final fontName = fonts?.getAttribute('w:ascii') ?? fonts?.getAttribute('ascii');
  return fontName;
}

double? _readRunFontSize(XmlElement? properties) {
  final size = properties?.findElements('w:sz').firstOrNull;
  final val = size?.getAttribute('w:val') ?? size?.getAttribute('val');
  if (val == null) return null;
  final number = double.tryParse(val);
  return number == null ? null : number / 2;
}

String? _readRunColor(XmlElement? properties) {
  final color = properties?.findElements('w:color').firstOrNull;
  final val = color?.getAttribute('w:val') ?? color?.getAttribute('val');
  return val?.toLowerCase();
}

String? _readRunHighlight(XmlElement? properties) {
  final highlight = properties?.findElements('w:highlight').firstOrNull;
  final val = highlight?.getAttribute('w:val') ?? highlight?.getAttribute('val');
  return val?.toLowerCase();
}

double? _readRunSpacing(XmlElement? properties) {
  final spacing = properties?.findElements('w:spacing').firstOrNull;
  final val = spacing?.getAttribute('w:val') ?? spacing?.getAttribute('val');
  if (val == null) return null;
  final number = double.tryParse(val);
  return number == null ? null : number / 20;
}

int? _readRunPosition(XmlElement? properties) {
  final position = properties?.findElements('w:position').firstOrNull;
  final val = position?.getAttribute('w:val') ?? position?.getAttribute('val');
  if (val == null) return null;
  return int.tryParse(val);
}

String? _readLineHeight(XmlElement? properties) {
  final lineHeight = properties?.findElements('w:spacing').firstOrNull;
  final val = lineHeight?.getAttribute('w:val') ?? lineHeight?.getAttribute('val');
  if (val == null) return null;
  final number = double.tryParse(val);
  return number == null ? null : '${(number / 20).toStringAsFixed(2)}px';
}

Archive _decodeZipArchive(String path) {
  final input = InputFileStream(path);
  return ZipDecoder().decodeBuffer(input);
}

String _extractXmlFile(Archive archive, String name) {
  final file = archive.files.firstWhere(
    (file) => file.name == name,
    orElse: () => throw Exception('Missing OOXML part: $name'),
  );
  return utf8.decode(file.content as List<int>);
}

String _normalizeText(String text) {
  return text
      .replaceAll('\u00A0', ' ')
      .replaceAll('â€™', "'")
      .replaceAll('â€˜', "'")
      .replaceAll('â€œ', '"')
      .trim();
}

extension IterableExtensions<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
