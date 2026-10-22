import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';
import 'package:archive/archive.dart';

import 'package:tutorpdf/core/utils/ooxml_color_parser.dart';
import 'package:tutorpdf/presentation/widgets/engines/docx/docx_ast.dart';
import 'package:tutorpdf/presentation/widgets/engines/docx/docx_theme_adapter.dart';

class DocxEngine {
  final DocxStyleParser _styleParser = DocxStyleParser();
  final Map<String, Uint8List> _media = {};

  Future<List<DocxNode>> parseDocument(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Extract media
    for (var file in archive) {
      if (file.name.startsWith('word/media/')) {
        _media[file.name.replaceAll('word/', '')] = Uint8List.fromList(file.content as List<int>);
      }
    }

    // Load Styles
    final stylesXml = archive.findFile('word/styles.xml');
    if (stylesXml != null) {
      _styleParser.parse(utf8.decode(stylesXml.content as List<int>, allowMalformed: true));
    }

    final documentXml = archive.findFile('word/document.xml');
    if (documentXml == null) return [];

    final xmlContent = utf8.decode(documentXml.content as List<int>, allowMalformed: true);
    final document = XmlDocument.parse(xmlContent);

    final body = document.findAllElements('w:body').firstOrNull;
    if (body == null) return [];

    return _parseBody(body);
  }

  List<DocxNode> _parseBody(XmlElement body) {
    List<DocxNode> nodes = [];
    for (var element in body.childElements) {
      if (element.name.local == 'p') {
        nodes.add(_parseParagraph(element));
      } else if (element.name.local == 'tbl') {
        nodes.add(_parseTable(element));
      }
    }
    return nodes;
  }

  DocxParagraph _parseParagraph(XmlElement p) {
    List<DocxRun> runs = [];
    final pPr = p.getElement('w:pPr');
    final pStyle = pPr?.getElement('w:pStyle')?.getAttribute('w:val');
    
    // Default spacing and alignment
    double spacingBefore = 0.0;
    double spacingAfter = 6.0;
    TextAlign alignment = TextAlign.left;
    double defaultSize = 12.0;
    bool isHeadingBold = false;

    // Heading hierarchy mapping
    if (pStyle != null) {
      if (pStyle.contains('Heading 1') || pStyle.contains('Heading1')) {
        defaultSize = 22.0;
        isHeadingBold = true;
        spacingBefore = 12.0;
        spacingAfter = 6.0;
      } else if (pStyle.contains('Heading 2') || pStyle.contains('Heading2')) {
        defaultSize = 18.0;
        isHeadingBold = true;
        spacingBefore = 10.0;
        spacingAfter = 4.0;
      } else if (pStyle.contains('Heading 3') || pStyle.contains('Heading3')) {
        defaultSize = 15.0;
        isHeadingBold = true; // Semi-bold approximated with bold
        spacingBefore = 8.0;
        spacingAfter = 4.0;
      }
    }

    // Spacing
    final spacing = pPr?.getElement('w:spacing');
    if (spacing != null) {
      if (spacing.getAttribute('w:before') != null) {
        spacingBefore = (double.tryParse(spacing.getAttribute('w:before')!) ?? 0.0) / 20.0;
      }
      if (spacing.getAttribute('w:after') != null) {
        spacingAfter = (double.tryParse(spacing.getAttribute('w:after')!) ?? 0.0) / 20.0;
      }
    }

    // Alignment
    final jc = pPr?.getElement('w:jc')?.getAttribute('w:val');
    if (jc == 'center') alignment = TextAlign.center;
    else if (jc == 'right') alignment = TextAlign.right;
    else if (jc == 'both') alignment = TextAlign.justify;

    final styleMap = pStyle != null ? _styleParser.getStyle(pStyle) : null;

    for (var run in p.findAllElements('w:r')) {
      final rPr = run.getElement('w:rPr');
      final textNode = run.findAllElements('w:t').firstOrNull;
      
      if (textNode != null) {
        // Run specific font size
        final szVal = rPr?.getElement('w:sz')?.getAttribute('w:val');
        final fontSize = szVal != null ? (double.tryParse(szVal)! / 2.0) : defaultSize;
        
        final isBold = isHeadingBold || (rPr?.getElement('w:b') != null);
        final isItalic = rPr?.getElement('w:i') != null;
        final isUnderline = rPr?.getElement('w:u') != null;
        
        runs.add(DocxRun(
          text: textNode.innerText,
          fontSize: fontSize,
          isBold: isBold,
          isItalic: isItalic,
          isUnderline: isUnderline,
        ));
      }
    }
    
    return DocxParagraph(
      runs: runs,
      alignment: alignment,
      spacingBefore: spacingBefore,
      spacingAfter: spacingAfter,
    );
  }

  DocxTable _parseTable(XmlElement tbl) {
    List<DocxTableRow> rows = [];
    for (var tr in tbl.findAllElements('w:tr')) {
      List<DocxTableCell> cells = [];
      for (var tc in tr.findAllElements('w:tc')) {
        cells.add(DocxTableCell(
          content: _parseBody(tc),
          backgroundColor: OoxmlColorParser.parse(
            tc.getElement('w:tcPr')?.getElement('w:shd')?.getAttribute('w:fill')
          ),
        ));
      }
      rows.add(DocxTableRow(cells: cells));
    }
    return DocxTable(rows: rows);
  }
}
