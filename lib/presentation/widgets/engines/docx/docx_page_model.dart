import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';
import 'package:archive/archive.dart';

/// DOCX Page Model
/// Handles page-based OOXML parsing with section properties, page dimensions, and pagination.
class DocxPageModel {
  static const int twipsPerPoint = 20;
  static const int pointsPerInch = 72;
  static const int twipsPerInch = twipsPerPoint * pointsPerInch;

  final double widthPt;
  final double heightPt;
  final double marginTopPt;
  final double marginBottomPt;
  final double marginLeftPt;
  final double marginRightPt;
  final String orientation;
  final List<XmlElement> contentNodes;

  DocxPageModel({
    required this.widthPt,
    required this.heightPt,
    required this.marginTopPt,
    required this.marginBottomPt,
    required this.marginLeftPt,
    required this.marginRightPt,
    required this.orientation,
    required this.contentNodes,
  });

  /// Parse section properties from <w:sectPr> element
  static DocxPageModel fromSectionPr(XmlElement sectPr, List<XmlElement> nodes) {
    // Default A4 portrait dimensions in twips
    final defaultWidth = 11906.0; // A4 width in twips (595.3 pt)
    final defaultHeight = 16838.0; // A4 height in twips (841.9 pt)
    final defaultMargins = 1440.0; // 1 inch margin in twips (72 pt)

    final pgSz = sectPr.getElement('w:pgSz');
    final pgMar = sectPr.getElement('w:pgMar');

    // Parse page size
    double width = defaultWidth;
    double height = defaultHeight;
    String orientation = 'portrait';

    if (pgSz != null) {
      final wAttr = pgSz.getAttribute('w:w');
      final hAttr = pgSz.getAttribute('w:h');
      final orientAttr = pgSz.getAttribute('w:orient');

      if (wAttr != null) width = double.tryParse(wAttr) ?? defaultWidth;
      if (hAttr != null) height = double.tryParse(hAttr) ?? defaultHeight;
      if (orientAttr != null) orientation = orientAttr;
    }

    // Parse margins
    double marginTop = defaultMargins;
    double marginBottom = defaultMargins;
    double marginLeft = defaultMargins;
    double marginRight = defaultMargins;

    if (pgMar != null) {
      final topAttr = pgMar.getAttribute('w:top');
      final bottomAttr = pgMar.getAttribute('w:bottom');
      final leftAttr = pgMar.getAttribute('w:left');
      final rightAttr = pgMar.getAttribute('w:right');

      if (topAttr != null) marginTop = double.tryParse(topAttr) ?? defaultMargins;
      if (bottomAttr != null) marginBottom = double.tryParse(bottomAttr) ?? defaultMargins;
      if (leftAttr != null) marginLeft = double.tryParse(leftAttr) ?? defaultMargins;
      if (rightAttr != null) marginRight = double.tryParse(rightAttr) ?? defaultMargins;
    }

    // Convert twips to points
    return DocxPageModel(
      widthPt: width / twipsPerPoint,
      heightPt: height / twipsPerPoint,
      marginTopPt: marginTop / twipsPerPoint,
      marginBottomPt: marginBottom / twipsPerPoint,
      marginLeftPt: marginLeft / twipsPerPoint,
      marginRightPt: marginRight / twipsPerPoint,
      orientation: orientation,
      contentNodes: nodes,
    );
  }

  /// Get content area dimensions (page size minus margins)
  double get contentWidthPt => widthPt - marginLeftPt - marginRightPt;
  double get contentHeightPt => heightPt - marginTopPt - marginBottomPt;

  /// Convert points to pixels (assuming 96 DPI)
  double ptToPx(double pt) => pt * 96 / pointsPerInch;

  /// Get page dimensions in pixels
  double get widthPx => ptToPx(widthPt);
  double get heightPx => ptToPx(heightPt);
  double get contentWidthPx => ptToPx(contentWidthPt);
  double get contentHeightPx => ptToPx(contentHeightPt);

  /// Get CSS style for page container
  String get pageStyle {
    return '''
      width: ${widthPx}px;
      height: ${heightPx}px;
      margin: 0 auto;
      position: relative;
      overflow: hidden;
    ''';
  }

  /// Get CSS style for content area
  String get contentStyle {
    return '''
      position: absolute;
      top: ${ptToPx(marginTopPt)}px;
      left: ${ptToPx(marginLeftPt)}px;
      width: ${contentWidthPx}px;
      height: ${contentHeightPx}px;
      overflow: hidden;
    ''';
  }
}

/// DOCX Document Paginator
/// Splits document content into pages based on section breaks and page breaks.
class DocxDocumentPaginator {
  /// Parse document and split into pages
  static List<DocxPageModel> paginate(XmlDocument doc) {
    final pages = <DocxPageModel>[];
    final body = doc.findAllElements('w:body').firstOrNull;
    if (body == null) return pages;

    final allNodes = body.children.whereType<XmlElement>().toList();
    final sectionPrs = body.findAllElements('w:sectPr').toList();

    // If no section properties, use default A4
    if (sectionPrs.isEmpty) {
      pages.add(DocxPageModel.fromSectionPr(
        XmlElement(XmlName.fromString('w:sectPr')),
        allNodes,
      ));
      return pages;
    }

    // Split content by section breaks
    int nodeIndex = 0;
    for (int i = 0; i < sectionPrs.length; i++) {
      final sectPr = sectionPrs[i];
      final pageNodes = <XmlElement>[];

      // Collect nodes up to this section break
      while (nodeIndex < allNodes.length) {
        final node = allNodes[nodeIndex];
        if (node == sectPr) {
          nodeIndex++;
          break;
        }
        pageNodes.add(node);
        nodeIndex++;
      }

      // Also check for page breaks within this section
      final subPages = _splitByPageBreaks(pageNodes);
      for (var subPageNodes in subPages) {
        pages.add(DocxPageModel.fromSectionPr(sectPr, subPageNodes));
      }
    }

    // Handle any remaining nodes after last section break
    if (nodeIndex < allNodes.length) {
      final remainingNodes = allNodes.sublist(nodeIndex);
      final subPages = _splitByPageBreaks(remainingNodes);
      for (var subPageNodes in subPages) {
        pages.add(DocxPageModel.fromSectionPr(
          sectionPrs.last,
          subPageNodes,
        ));
      }
    }

    return pages;
  }

  /// Split nodes by hard page breaks (<w:br w:type="page"/>) and paragraph page breaks (<w:pageBreakBefore/>)
  static List<List<XmlElement>> _splitByPageBreaks(List<XmlElement> nodes) {
    final pages = <List<XmlElement>>[];
    final currentPage = <XmlElement>[];

    for (var node in nodes) {
      // Check for paragraph-level page break before
      final pageBreakBefore = node.getElement('w:pPr')?.getElement('w:pageBreakBefore') != null;
      
      // Check for page break in paragraph (within runs)
      final pageBreaks = node.findAllElements('w:br').where((br) {
        final type = br.getAttribute('w:type');
        return type == 'page';
      });

      if (pageBreakBefore || pageBreaks.isNotEmpty) {
        // Add current page if it has content
        if (currentPage.isNotEmpty) {
          pages.add(List.from(currentPage));
          currentPage.clear();
        }
        // Don't add the page break itself to content
        continue;
      }

      currentPage.add(node);
    }

    // Add last page
    if (currentPage.isNotEmpty) {
      pages.add(currentPage);
    }

    return pages;
  }

  /// Parse document.xml from archive and paginate
  static List<DocxPageModel> fromArchive(Archive archive) {
    final docFile = archive.findFile('word/document.xml');
    if (docFile == null) return [];

    try {
      final docContent = utf8.decode(docFile.content, allowMalformed: true);
      final doc = XmlDocument.parse(docContent);
      return paginate(doc);
    } catch (e) {
      return [];
    }
  }
}

/// DOCX Page - Native Flutter widget model
class DocxPage {
  final double widthPt;
  final double heightPt;
  final List<DocxContent> content;

  DocxPage({
    required this.widthPt,
    required this.heightPt,
    required this.content,
  });
}

/// DOCX Content base class
abstract class DocxContent {}

/// DOCX Paragraph
class DocxParagraph extends DocxContent {
  final List<DocxRun> runs;
  final List<Map<String, dynamic>> shapes;
  final TextAlign alignment;
  final int headingLevel;
  final double? spacingBefore;
  final double? spacingAfter;
  final double? lineSpacing;
  final double? leftIndent;
  final double? rightIndent;
  final double? firstLineIndent;

  DocxParagraph({
    required this.runs,
    required this.shapes,
    required this.alignment,
    required this.headingLevel,
    this.spacingBefore,
    this.spacingAfter,
    this.lineSpacing,
    this.leftIndent,
    this.rightIndent,
    this.firstLineIndent,
  });
}

/// DOCX Text Run
class DocxRun {
  final String text;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final bool isStrikethrough;
  final bool isSmallCaps;
  final Color? textColor;
  final Color? highlightColor;
  final double fontSizePt;
  final String? fontFamily;
  final List<DocxImage> images;

  DocxRun({
    required this.text,
    required this.isBold,
    required this.isItalic,
    required this.isUnderline,
    required this.isStrikethrough,
    required this.isSmallCaps,
    this.textColor,
    this.highlightColor,
    required this.fontSizePt,
    this.fontFamily,
    required this.images,
  });
}

/// DOCX Image
class DocxImage {
  final String dataUri;
  final double widthPt;
  final double heightPt;

  DocxImage({
    required this.dataUri,
    required this.widthPt,
    required this.heightPt,
  });
}

/// DOCX Table
class DocxTable extends DocxContent {
  final List<DocxTableRow> rows;
  final double? widthPt;
  final Color? borderColor;
  final double? borderWidth;

  DocxTable({
    required this.rows,
    this.widthPt,
    this.borderColor,
    this.borderWidth,
  });
}

/// DOCX Table Row
class DocxTableRow {
  final List<DocxTableCell> cells;
  final double? heightPt;

  DocxTableRow({
    required this.cells,
    this.heightPt,
  });
}

/// DOCX Table Cell
class DocxTableCell {
  final List<DocxParagraph> paragraphs;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderWidth;
  final int? gridSpan;
  final int? vMerge;
  final double? paddingPt;

  DocxTableCell({
    required this.paragraphs,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.gridSpan,
    this.vMerge,
    this.paddingPt,
  });
}

/// DOCX Header/Footer
class DocxHeaderFooter {
  final int index;
  final List<DocxParagraph> paragraphs;
  final List<DocxImage> images;

  DocxHeaderFooter({
    required this.index,
    required this.paragraphs,
    required this.images,
  });
}

/// DOCX Styles
class DocxStyles {
  final Map<String, DocxStyle> paragraphStyles;
  final Map<String, DocxStyle> characterStyles;

  DocxStyles({
    this.paragraphStyles = const {},
    this.characterStyles = const {},
  });
}

/// DOCX Style
class DocxStyle {
  final String name;
  final String? basedOn;
  final bool? isBold;
  final bool? isItalic;
  final double? fontSizePt;
  final String? color;
  final TextAlign? alignment;

  DocxStyle({
    required this.name,
    this.basedOn,
    this.isBold,
    this.isItalic,
    this.fontSizePt,
    this.color,
    this.alignment,
  });
}
