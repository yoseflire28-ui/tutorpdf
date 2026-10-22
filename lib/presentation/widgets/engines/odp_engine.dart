import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;
import 'base_engine.dart';

class OdpEngine extends StatefulWidget {
  final String filePath;
  final bool isDarkMode;

  const OdpEngine({
    super.key,
    required this.filePath,
    required this.isDarkMode,
  });

  @override
  State<OdpEngine> createState() => _OdpEngineState();
}

class _OdpEngineState extends State<OdpEngine> {
  bool _isLoading = true;
  String? _error;
  List<OdpSlide> _slides = [];
  int _currentSlideIndex = 0;

  @override
  void initState() {
    super.initState();
    _parseOdp();
  }

  @override
  void didUpdateWidget(OdpEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _parseOdp();
    }
  }

  Future<void> _parseOdp() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final contentFile = archive.findFile('content.xml');

      if (contentFile == null) {
        setState(() {
          _error = 'content.xml missing from ODP package.';
          _isLoading = false;
        });
        return;
      }

      final contentStr = utf8.decode(contentFile.content as List<int>, allowMalformed: true);
      final doc = xml.XmlDocument.parse(contentStr);

      final List<OdpSlide> slides = [];
      final pageNodes = doc.findAllElements('draw:page');

      for (int i = 0; i < pageNodes.length; i++) {
        final page = pageNodes.elementAt(i);
        final name = page.getAttribute('draw:name') ?? 'Slide ${i + 1}';
        final textElements = page.findAllElements('text:p').map((e) => e.innerText.trim()).where((s) => s.isNotEmpty).toList();

        final title = textElements.isNotEmpty ? textElements.first : name;
        final body = textElements.length > 1 ? textElements.sublist(1) : <String>[];

        slides.add(OdpSlide(slideNumber: i + 1, title: title, bodyTexts: body));
      }

      if (slides.isNotEmpty) {
        setState(() {
          _slides = slides;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'No presentation slides found in ODP package.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to parse ODP presentation: $e';
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

    if (_error != null || _slides.isEmpty) {
      return EngineErrorBoundary(
        filePath: widget.filePath,
        errorMessage: _error ?? 'Unable to display ODP slide deck.',
        isDarkMode: widget.isDarkMode,
        onRetry: _parseOdp,
      );
    }

    final activeSlide = _slides[_currentSlideIndex];

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
                  'Slide ${_currentSlideIndex + 1} of ${_slides.length}',
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
                      color: _currentSlideIndex < _slides.length - 1 ? EngineColors.coralAccent : textColor.withValues(alpha: 0.3),
                      onPressed: _currentSlideIndex < _slides.length - 1 ? () => setState(() => _currentSlideIndex++) : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Container(
                width: double.infinity,
                color: cardBg,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final slideWidth = constraints.maxWidth;
                    final slideHeight = slideWidth * (9 / 16);
                    return Container(
                      width: slideWidth,
                      height: slideHeight,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeSlide.title,
                            style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const Divider(height: 24, thickness: 1),
                          Expanded(
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: activeSlide.bodyTexts.length,
                              itemBuilder: (context, idx) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Text(
                                    activeSlide.bodyTexts[idx],
                                    style: TextStyle(color: textColor.withValues(alpha: 0.9), fontSize: 14, height: 1.4),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OdpSlide {
  final int slideNumber;
  final String title;
  final List<String> bodyTexts;
  OdpSlide({required this.slideNumber, required this.title, required this.bodyTexts});
}
