import 'package:flutter/material.dart';
import 'package:tutorpdf/presentation/widgets/engines/docx/docx_ast.dart';
import 'package:tutorpdf/presentation/widgets/engines/docx/docx_table_renderer.dart';
import 'package:tutorpdf/presentation/widgets/engines/docx/docx_table_renderer.dart' hide DocxTable;

// Updated page canvas for WPS-style layout
class DocxPageCanvas extends StatelessWidget {
  final List<DocxNode> elements;
  final double pageHeight;
  final EdgeInsets margins;

  const DocxPageCanvas({
    super.key,
    required this.elements,
    this.pageHeight = 841.89,
    this.margins = const EdgeInsets.all(72),
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: pageHeight),
        padding: margins,
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: elements.map((node) => _renderNode(node)).toList(),
        ),
      ),
    );
  }

  Widget _renderNode(DocxNode node) {
    if (node is DocxParagraph) {
      return Padding(
        padding: EdgeInsets.only(top: node.spacingBefore, bottom: node.spacingAfter),
        child: RichText(
          textAlign: node.alignment,
          text: TextSpan(
            children: node.runs.map((run) => TextSpan(
              text: run.text,
              style: TextStyle(
                fontSize: run.fontSize,
                fontWeight: run.isBold ? FontWeight.bold : FontWeight.normal,
                fontStyle: run.isItalic ? FontStyle.italic : FontWeight.normal,
                decoration: run.isUnderline ? TextDecoration.underline : null,
                color: run.color ?? Colors.black,
                fontFamilyFallback: const ['Roboto', 'Arial', 'sans-serif'],
              ),
            )).toList(),
          ),
        ),
      );
    } else if (node is DocxTable) {
      return DocxTableRenderer(table: node);
    }
    return const SizedBox.shrink();
  }
}
