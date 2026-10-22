import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'base_engine.dart';

class HtmlEngine extends StatefulWidget {
  final String filePath;
  final bool isDarkMode;

  const HtmlEngine({
    super.key,
    required this.filePath,
    required this.isDarkMode,
  });

  @override
  State<HtmlEngine> createState() => _HtmlEngineState();
}

class _HtmlEngineState extends State<HtmlEngine> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _error;
  String _fallbackHtmlText = '';

  @override
  void initState() {
    super.initState();
    _initHtml();
  }

  @override
  void didUpdateWidget(HtmlEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath || oldWidget.isDarkMode != widget.isDarkMode) {
      _initHtml();
    }
  }

  Future<void> _initHtml() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final file = File(widget.filePath);
      final rawHtml = await file.readAsString(encoding: utf8);

      // Inject dark mode CSS styling if dark mode is active
      String styledHtml = rawHtml;
      if (widget.isDarkMode) {
        const darkCss = '''
        <style>
          body {
            background-color: #1A1A1A !important;
            color: #F5F5F5 !important;
            font-family: -apple-system, Roboto, sans-serif !important;
          }
          a { color: #E65A4B !important; }
          table, th, td { border-color: #555555 !important; }
          pre, code { background-color: #2D2D30 !important; color: #F5F5F5 !important; }
        </style>
        ''';
        if (styledHtml.contains('</head>')) {
          styledHtml = styledHtml.replaceFirst('</head>', '$darkCss</head>');
        } else {
          styledHtml = '$darkCss$styledHtml';
        }
      }

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(widget.isDarkMode ? EngineColors.darkCanvas : EngineColors.lightCanvas)
        ..loadHtmlString(styledHtml);

      setState(() {
        _controller = controller;
        _isLoading = false;
      });
    } catch (e) {
      // Fallback: strip tags and display formatted text
      try {
        final file = File(widget.filePath);
        final raw = await file.readAsString(encoding: utf8);
        final clean = raw.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        setState(() {
          _fallbackHtmlText = clean;
          _isLoading = false;
        });
      } catch (err) {
        setState(() {
          _error = 'Failed to load HTML file: $e';
          _isLoading = false;
        });
      }
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
        onRetry: _initHtml,
      );
    }

    if (_controller != null) {
      return Container(
        color: canvasBg,
        child: WebViewWidget(controller: _controller!),
      );
    }

    return Container(
      color: canvasBg,
      width: double.infinity,
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: cardBg,
          ),
          child: SelectableText(
            _fallbackHtmlText,
            style: TextStyle(color: textColor, fontSize: 15, height: 1.6),
          ),
        ),
      ),
    );
  }
}
