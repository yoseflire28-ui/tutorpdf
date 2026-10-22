import 'package:flutter/material.dart';
import 'package:tutorpdf/presentation/widgets/engines/docx/docx_ast.dart';

/// Calculates spatial boundaries and handles pagination.
class DocxLayoutPaginator {
  double _estimateHeight(DocxNode node) {
    if (node is DocxParagraph) return 20.0;
    if (node is DocxTable) return 50.0;
    return 20.0;
  }

  List<List<DocxNode>> paginate(List<DocxNode> elements, double pageHeight, EdgeInsets margins) {
    List<List<DocxNode>> pages = [];
    List<DocxNode> currentPage = [];
    double currentHeight = margins.top;
    double usableHeight = pageHeight - margins.top - margins.bottom;

    for (var el in elements) {
      double elHeight = _estimateHeight(el);
      
      if (currentHeight + elHeight > usableHeight) {
        pages.add(currentPage);
        currentPage = [];
        currentHeight = margins.top;
      }
      
      currentPage.add(el);
      currentHeight += elHeight;
    }
    
    if (currentPage.isNotEmpty) pages.add(currentPage);
    return pages;
  }
}
