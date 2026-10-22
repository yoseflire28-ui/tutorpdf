import 'dart:io';
import 'package:flutter/material.dart';
import 'base_engine.dart';

class PptEngine extends StatefulWidget {
  final String filePath;
  final bool isDarkMode;

  const PptEngine({
    super.key,
    required this.filePath,
    required this.isDarkMode,
  });

  @override
  State<PptEngine> createState() => _PptEngineState();
}

class _PptEngineState extends State<PptEngine> {
  bool _isLoading = true;
  String? _error;
  List<String> _slideContents = [];
  int _currentSlideIndex = 0;

  @override
  void initState() {
    super.initState();
    _parseLegacyPpt();
  }

  @override
  void didUpdateWidget(PptEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _parseLegacyPpt();
    }
  }

  Future<void> _parseLegacyPpt() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();

      // Extract printable text sections from binary stream
      final sb = StringBuffer();
      for (int i = 0; i < bytes.length; i++) {
        final b = bytes[i];
        if ((b >= 32 && b <= 126) || b == 10 || b == 13) {
          sb.writeCharCode(b);
        } else {
          sb.write(' ');
        }
      }

      final text = sb.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
      final chunks = text.split(RegExp(r'(Slide \d+|Title|Presentation)'));
      final cleanSlides = chunks.where((c) => c.trim().length > 10).toList();

      if (cleanSlides.isNotEmpty) {
        setState(() {
          _slideContents = cleanSlides;
          _isLoading = false;
        });
      } else {
        setState(() {
          _slideContents = [text.isNotEmpty ? text : 'Legacy PPT presentation file.'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load legacy PPT presentation: $e';
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

    if (_error != null || _slideContents.isEmpty) {
      return EngineErrorBoundary(
        filePath: widget.filePath,
        errorMessage: _error ?? 'Unable to parse PPT slide deck.',
        isDarkMode: widget.isDarkMode,
        onRetry: _parseLegacyPpt,
      );
    }

    return Container(
      color: canvasBg,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: widget.isDarkMode ? const Color(0xFF252526) : const Color(0xFFD6D6D6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Slide ${_currentSlideIndex + 1} of ${_slideContents.length}',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 18),
                      color: _currentSlideIndex > 0 ? EngineColors.coralAccent : textColor.withValues(alpha: 0.3),
                      onPressed: _currentSlideIndex > 0 ? () => setState(() => _currentSlideIndex--) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 18),
                      color: _currentSlideIndex < _slideContents.length - 1 ? EngineColors.coralAccent : textColor.withValues(alpha: 0.3),
                      onPressed: _currentSlideIndex < _slideContents.length - 1 ? () => setState(() => _currentSlideIndex++) : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(28),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _slideContents[_currentSlideIndex],
                        style: TextStyle(color: textColor, fontSize: 15, height: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
