import 'dart:typed_data';
import 'package:flutter/material.dart';

abstract class DocxNode {}

class DocxRun extends DocxNode {
  final String text;
  final double fontSize;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final Color? color;
  final Color? highlightColor;

  DocxRun({
    required this.text,
    this.fontSize = 12.0,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.color,
    this.highlightColor,
  });
}

class DocxParagraph extends DocxNode {
  final List<DocxRun> runs;
  final TextAlign alignment;
  final double spacingBefore;
  final double spacingAfter;

  DocxParagraph({
    required this.runs,
    this.alignment = TextAlign.left,
    this.spacingBefore = 0.0,
    this.spacingAfter = 6.0,
  });
}

class DocxTableCell {
  final List<DocxNode> content;
  final Color? backgroundColor;
  final double width;

  DocxTableCell({required this.content, this.backgroundColor, this.width = 100.0});
}

class DocxTableRow {
  final List<DocxTableCell> cells;
  DocxTableRow({required this.cells});
}

class DocxTable extends DocxNode {
  final List<DocxTableRow> rows;
  DocxTable({required this.rows});
}

class DocxImageNode extends DocxNode {
  final Uint8List bytes;
  final double width;
  final double height;

  DocxImageNode({required this.bytes, required this.width, required this.height});
}

class DocxSection {
  final double pageWidth;
  final double pageHeight;
  final EdgeInsets margins;

  DocxSection({
    this.pageWidth = 595.27,
    this.pageHeight = 841.89,
    this.margins = const EdgeInsets.all(72.0),
  });
}
