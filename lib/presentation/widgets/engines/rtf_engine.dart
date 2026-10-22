import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'base_engine.dart';

class RtfEngine extends StatefulWidget {
  final String filePath;
  final bool isDarkMode;

  const RtfEngine({
    super.key,
    required this.filePath,
    required this.isDarkMode,
  });

  @override
  State<RtfEngine> createState() => _RtfEngineState();
}

class _RtfEngineState extends State<RtfEngine> {
  bool _isLoading = true;
  String? _error;
  String _parsedText = '';

  @override
  void initState() {
    super.initState();
    _parseRtf();
  }

  @override
  void didUpdateWidget(RtfEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _parseRtf();
    }
  }

  Future<void> _parseRtf() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final file = File(widget.filePath);
      final raw = await file.readAsString(encoding: utf8);

      // Simple RTF Control Word Parser
      String text = raw;
      // Convert \par or \line to newlines
      text = text.replaceAll(RegExp(r'\\par\b|\\line\b'), '\n');
      // Remove groups like {\fonttbl...} or {\colortbl...}
      text = text.replaceAll(RegExp(r'\{\\\*?\w+[^}]*\}'), '');
      // Strip control words like \b, \i, \fs24, etc.
      text = text.replaceAll(RegExp(r'\\[a-zA-Z]+-?\d*\s?'), '');
      // Remove group brackets { and }
      text = text.replaceAll('{', '').replaceAll('}', '');
      // Clean up multiple newlines
      text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

      if (text.isNotEmpty) {
        setState(() {
          _parsedText = text;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'RTF document contained no readable text.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to parse RTF document: $e';
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
        onRetry: _parseRtf,
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
            _parsedText,
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
