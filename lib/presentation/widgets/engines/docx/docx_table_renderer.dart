import 'package:flutter/material.dart';
import 'package:tutorpdf/presentation/widgets/engines/docx/docx_ast.dart';

class DocxTableRenderer extends StatelessWidget {
  final DocxTable table;

  const DocxTableRenderer({super.key, required this.table});

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: Colors.grey),
      children: table.rows.map((row) {
        return TableRow(
          children: row.cells.map((cell) => Container(
            color: cell.backgroundColor,
            padding: const EdgeInsets.all(4),
            child: Column(
              children: cell.content.whereType<DocxParagraph>().map((p) => 
                Text.rich(TextSpan(children: p.runs.map((r) => TextSpan(
                  text: r.text, 
                  style: TextStyle(
                    fontSize: r.fontSize,
                    fontWeight: r.isBold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: r.isItalic ? FontStyle.italic : FontStyle.normal,
                    decoration: r.isUnderline ? TextDecoration.underline : null,
                    color: r.color,
                    backgroundColor: r.highlightColor,
                  ),
                )).toList()))
              ).toList(),
            ),
          )).toList(),
        );
      }).toList(),
    );
  }
}
