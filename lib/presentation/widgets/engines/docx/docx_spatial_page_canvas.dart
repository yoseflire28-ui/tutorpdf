import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'docx_page_model.dart';
import '../universal_theme_adapter.dart';

/// DOCX Spatial Floating Element Data
class DocxSpatialFloatingElement {
  final double leftPt;
  final double topPt;
  final double widthPt;
  final double heightPt;
  final double rotationDegrees;
  final Widget child;

  DocxSpatialFloatingElement({
    required this.leftPt,
    required this.topPt,
    required this.widthPt,
    required this.heightPt,
    this.rotationDegrees = 0.0,
    required this.child,
  });
}

/// DOCX Spatial Page Canvas Renderer
/// Enforces fixed spatial page boundaries (A4 / Letter) matching WPS Mobile layout.
class DocxSpatialPageCanvas extends StatelessWidget {
  final DocxPage page;
  final int pageNumber;
  final List<DocxHeaderFooter> headers;
  final List<DocxHeaderFooter> footers;
  final List<DocxSpatialFloatingElement> floatingElements;
  final bool isDarkMode;
  final double viewportWidth;

  const DocxSpatialPageCanvas({
    super.key,
    required this.page,
    required this.pageNumber,
    required this.headers,
    required this.footers,
    this.floatingElements = const [],
    required this.isDarkMode,
    required this.viewportWidth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = UniversalThemeAdapter(isDarkMode: isDarkMode);

    // Fixed page bounds (Standard A4 = 595.3 pt x 841.9 pt if not specified)
    final pageWidthPt = page.widthPt > 0 ? page.widthPt : 595.3;
    final pageHeightPt = page.heightPt > 0 ? page.heightPt : 841.9;

    // Proportional canvas scale factor to fit mobile device viewport width
    final marginHorizontal = 32.0;
    final targetWidth = (viewportWidth - marginHorizontal).clamp(280.0, 1400.0);
    final scale = targetWidth / pageWidthPt;

    final scaledWidth = pageWidthPt * scale;
    final scaledHeight = pageHeightPt * scale;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Center(
        child: Container(
          width: scaledWidth,
          height: scaledHeight,
          decoration: BoxDecoration(
            color: theme.pageColor,
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                // 1. Page Margin Content Layer
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 36.0 * scale,
                    vertical: 36.0 * scale,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Margin Band
                      if (headers.isNotEmpty)
                        ...headers.map((h) => _buildHeaderFooter(h, theme, scale)),

                      // Main Document Content Stream
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _buildContent(theme, scale),
                          ),
                        ),
                      ),

                      // Footer Margin Band
                      if (footers.isNotEmpty)
                        ...footers.map((f) => _buildHeaderFooter(f, theme, scale)),
                    ],
                  ),
                ),

                // 2. Absolute Spatial Layer for Floating Drawings / Anchored Shapes
                ...floatingElements.map((elem) => _buildFloatingElement(elem, scale)),

                // 3. Spatial Page Number Watermark Indicator
                Positioned(
                  right: 16 * scale,
                  bottom: 12 * scale,
                  child: Text(
                    'Page $pageNumber',
                    style: TextStyle(
                      fontSize: 10 * scale,
                      color: theme.textFlutterColor.withValues(alpha: 0.4),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Render Absolute Spatial Floating Elements (Anchored Drawings, Images, Watermarks)
  Widget _buildFloatingElement(DocxSpatialFloatingElement elem, double scale) {
    Widget widget = SizedBox(
      width: elem.widthPt * scale,
      height: elem.heightPt * scale,
      child: elem.child,
    );

    if (elem.rotationDegrees != 0.0) {
      widget = Transform.rotate(
        angle: elem.rotationDegrees * math.pi / 180.0,
        alignment: Alignment.center,
        child: widget,
      );
    }

    return Positioned(
      left: elem.leftPt * scale,
      top: elem.topPt * scale,
      child: widget,
    );
  }

  /// Render Header / Footer Band
  Widget _buildHeaderFooter(DocxHeaderFooter hf, UniversalThemeAdapter theme, double scale) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4 * scale),
      margin: EdgeInsets.only(bottom: 8 * scale),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.borderFlutterColor.withValues(alpha: 0.3),
            width: 0.5 * scale,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: hf.paragraphs.map((p) => _buildParagraph(p, theme, scale)).toList(),
      ),
    );
  }

  /// Render Document Content Items
  List<Widget> _buildContent(UniversalThemeAdapter theme, double scale) {
    return page.content.map((content) {
      if (content is DocxParagraph) {
        return _buildParagraph(content, theme, scale);
      } else if (content is DocxTable) {
        return _buildTable(content, theme, scale);
      }
      return const SizedBox.shrink();
    }).toList();
  }

  /// Render DOCX Paragraph
  Widget _buildParagraph(DocxParagraph p, UniversalThemeAdapter theme, double scale) {
    final defaultColor = theme.textFlutterColor;

    return Container(
      margin: EdgeInsets.only(
        top: (p.spacingBefore ?? 0.0) * scale,
        bottom: (p.spacingAfter ?? 8.0) * scale,
        left: (p.leftIndent ?? 0.0) * scale,
        right: (p.rightIndent ?? 0.0) * scale,
      ),
      padding: EdgeInsets.only(left: (p.firstLineIndent ?? 0.0) * scale),
      child: RichText(
        textAlign: p.alignment,
        text: TextSpan(
          children: p.runs.map((run) => _buildRun(run, theme, defaultColor, scale)).toList(),
        ),
      ),
    );
  }

  /// Render DOCX Text Run
  TextSpan _buildRun(
    DocxRun run,
    UniversalThemeAdapter theme,
    Color defaultColor,
    double scale,
  ) {
    List<TextDecoration> decorations = [];
    if (run.isUnderline) decorations.add(TextDecoration.underline);
    if (run.isStrikethrough) decorations.add(TextDecoration.lineThrough);

    return TextSpan(
      text: run.text,
      style: TextStyle(
        color: run.textColor ?? defaultColor,
        fontSize: math.max((run.fontSizePt ?? 12.0) * scale, 6.0),
        fontWeight: run.isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: run.isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: decorations.isEmpty
            ? TextDecoration.none
            : TextDecoration.combine(decorations),
        fontFamily: run.fontFamily,
        backgroundColor: run.highlightColor,
      ),
    );
  }

  /// Render DOCX Spatial Table Matrix
  Widget _buildTable(DocxTable table, UniversalThemeAdapter theme, double scale) {
    final borderColor = table.borderColor ?? theme.borderFlutterColor;
    final borderWidth = (table.borderWidth?.toDouble() ?? 1.0) * scale;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8 * scale),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Table(
        border: TableBorder.all(color: borderColor, width: borderWidth),
        children: table.rows.map((row) {
          return TableRow(
            children: row.cells.map((cell) {
              return Container(
                padding: EdgeInsets.all((cell.paddingPt ?? 6.0) * scale),
                decoration: BoxDecoration(
                  color: cell.backgroundColor ?? theme.pageColor,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: cell.paragraphs
                      .map((p) => _buildParagraph(p, theme, scale))
                      .toList(),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}

/// DOCX Spatial Multi-Page Canvas Scroll List
class DocxSpatialMultiPageCanvas extends StatelessWidget {
  final List<DocxPage> pages;
  final List<DocxHeaderFooter> headers;
  final List<DocxHeaderFooter> footers;
  final bool isDarkMode;

  const DocxSpatialMultiPageCanvas({
    super.key,
    required this.pages,
    required this.headers,
    required this.footers,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = UniversalThemeAdapter(isDarkMode: isDarkMode);
    final viewportWidth = MediaQuery.of(context).size.width;

    return Container(
      color: theme.canvasColor,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: pages.length,
        itemBuilder: (context, index) {
          return DocxSpatialPageCanvas(
            page: pages[index],
            pageNumber: index + 1,
            headers: headers,
            footers: footers,
            isDarkMode: isDarkMode,
            viewportWidth: viewportWidth,
          );
        },
      ),
    );
  }
}
