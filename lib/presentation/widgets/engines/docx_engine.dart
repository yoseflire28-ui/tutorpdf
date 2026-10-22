import 'package:flutter/material.dart';
import 'docx/docx_engine.dart' as inner;
import 'docx/docx_ast.dart';
import 'base_engine.dart';
import 'universal_document_controller.dart';

/// DOCX Engine Widget
/// Parses DOCX documents and renders document AST elements.
class DocxEngine extends StatefulWidget {
  final String filePath;
  final bool isDarkMode;
  final UniversalDocumentController? controller;

  const DocxEngine({
    super.key,
    required this.filePath,
    required this.isDarkMode,
    this.controller,
  });

  @override
  State<DocxEngine> createState() => _DocxEngineState();
}

class _DocxEngineState extends State<DocxEngine> {
  bool _isLoading = true;
  String? _error;
  List<DocxNode> _nodes = [];

  @override
  void initState() {
    super.initState();
    _parseDocx();
  }

  @override
  void didUpdateWidget(DocxEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _parseDocx();
    }
  }

  Future<void> _parseDocx() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final parser = inner.DocxEngine();
      final nodes = await parser.parseDocument(widget.filePath);
      setState(() {
        _nodes = nodes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to parse DOCX document: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canvasBg = widget.isDarkMode ? EngineColors.darkCanvas : EngineColors.lightCanvas;
    final cardBg = widget.isDarkMode ? EngineColors.darkCard : EngineColors.lightCard;
    final textColor = widget.isDarkMode ? EngineColors.darkText : EngineColors.lightText;

    if (_isLoading) {
      return Container(
        color: canvasBg,
        child: const Center(
          child: CircularProgressIndicator(color: EngineColors.coralAccent),
        ),
      );
    }

    if (_error != null) {
      return EngineErrorBoundary(
        filePath: widget.filePath,
        errorMessage: _error!,
        isDarkMode: widget.isDarkMode,
        onRetry: _parseDocx,
      );
    }

    return Container(
      color: canvasBg,
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _nodes.map((node) => _buildNode(node, textColor)).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildNode(DocxNode node, Color textColor) {
    if (node is DocxParagraph) {
      final text = node.runs.map((r) => r.text).join();
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: SelectableText(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
