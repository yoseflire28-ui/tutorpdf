import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'base_engine.dart';

class DocEngine extends StatefulWidget {
  final String filePath;
  final bool isDarkMode;

  const DocEngine({
    super.key,
    required this.filePath,
    required this.isDarkMode,
  });

  @override
  State<DocEngine> createState() => _DocEngineState();
}

class _DocEngineState extends State<DocEngine> {
  bool _isLoading = true;
  String? _error;
  String _extractedText = '';

  @override
  void initState() {
    super.initState();
    _parseLegacyDoc();
  }

  @override
  void didUpdateWidget(DocEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _parseLegacyDoc();
    }
  }

  Future<void> _parseLegacyDoc() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();

      // Legacy OLE Binary doc parser fallback: extract ASCII/UTF printable strings
      final sb = StringBuffer();
      final currentWord = StringBuffer();

      for (int i = 0; i < bytes.length; i++) {
        final byte = bytes[i];
        if ((byte >= 32 && byte <= 126) || byte == 10 || byte == 13 || byte == 9) {
          currentWord.writeCharCode(byte);
        } else {
          if (currentWord.length >= 3) {
            final wordStr = utf8.decode(currentWord.toString().codeUnits, allowMalformed: true).trim();
            if (wordStr.isNotEmpty && !_isOleGarbage(wordStr)) {
              sb.writeln(wordStr);
            }
          }
          currentWord.clear();
        }
      }

      final result = sb.toString().trim();
      if (result.isEmpty) {
        setState(() {
          _extractedText = 'Legacy binary DOC document. Text content could not be extracted directly.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _extractedText = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to parse legacy DOC binary format: $e';
        _isLoading = false;
      });
    }
  }

  bool _isOleGarbage(String s) {
    if (s.contains('Root Entry') ||
        s.contains('WordDocument') ||
        s.contains('SummaryInformation') ||
        s.contains('CompObj') ||
        s.contains('Microsoft Word Document')) {
      return true;
    }
    return false;
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
        onRetry: _parseLegacyDoc,
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
            _extractedText,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              height: 1.6,
              fontFamily: 'Roboto',
            ),
          ),
        ),
      ),
    );
  }
}
