import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;
import 'base_engine.dart';

class EpubEngine extends StatefulWidget {
  final String filePath;
  final bool isDarkMode;

  const EpubEngine({
    super.key,
    required this.filePath,
    required this.isDarkMode,
  });

  @override
  State<EpubEngine> createState() => _EpubEngineState();
}

class _EpubEngineState extends State<EpubEngine> {
  bool _isLoading = true;
  String? _error;
  List<EpubChapter> _chapters = [];
  int _currentChapterIndex = 0;
  double _fontSize = 16.0;

  @override
  void initState() {
    super.initState();
    _loadEpub();
  }

  @override
  void didUpdateWidget(EpubEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _loadEpub();
    }
  }

  Future<void> _loadEpub() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Find HTML/XHTML chapter files in archive
      final htmlFiles = archive.files
          .where((f) => f.name.endsWith('.html') || f.name.endsWith('.xhtml') || f.name.endsWith('.htm'))
          .toList();

      if (htmlFiles.isEmpty) {
        setState(() {
          _error = 'No readable chapter HTML documents found in EPUB package.';
          _isLoading = false;
        });
        return;
      }

      final List<EpubChapter> chapters = [];

      for (int i = 0; i < htmlFiles.length; i++) {
        final contentStr = utf8.decode(htmlFiles[i].content as List<int>, allowMalformed: true);
        
        String chapterTitle = 'Chapter ${i + 1}';
        try {
          final doc = xml.XmlDocument.parse(contentStr);
          final titleEl = doc.findAllElements('title').firstOrNull;
          if (titleEl != null && titleEl.innerText.trim().isNotEmpty) {
            chapterTitle = titleEl.innerText.trim();
          }
        } catch (_) {}

        // Strip HTML tags for clean ebook page typography
        final cleanText = contentStr
            .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '')
            .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '')
            .replaceAll(RegExp(r'<[^>]*>'), ' ')
            .replaceAll(RegExp(r'&nbsp;'), ' ')
            .replaceAll(RegExp(r'&amp;'), '&')
            .replaceAll(RegExp(r'&lt;'), '<')
            .replaceAll(RegExp(r'&gt;'), '>')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        if (cleanText.isNotEmpty) {
          chapters.add(EpubChapter(
            title: chapterTitle,
            content: cleanText,
            fileName: htmlFiles[i].name,
          ));
        }
      }

      if (chapters.isNotEmpty) {
        setState(() {
          _chapters = chapters;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'EPUB chapters contained no extractable text.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to parse EPUB archive: $e';
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

    if (_error != null || _chapters.isEmpty) {
      return EngineErrorBoundary(
        filePath: widget.filePath,
        errorMessage: _error ?? 'Unable to load EPUB chapters.',
        isDarkMode: widget.isDarkMode,
        onRetry: _loadEpub,
      );
    }

    final activeChapter = _chapters[_currentChapterIndex];

    return Container(
      color: canvasBg,
      child: Column(
        children: [
          // EPUB Toolbar with Chapter Selector & Font Size Controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: widget.isDarkMode ? const Color(0xFF252526) : const Color(0xFFD6D6D6),
            child: Row(
              children: [
                const Icon(Icons.book, color: EngineColors.coralAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<int>(
                    value: _currentChapterIndex,
                    isExpanded: true,
                    dropdownColor: cardBg,
                    underline: const SizedBox(),
                    items: List.generate(_chapters.length, (index) {
                      return DropdownMenuItem<int>(
                        value: index,
                        child: Text(
                          _chapters[index].title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: textColor, fontSize: 13),
                        ),
                      );
                    }),
                    onChanged: (newIdx) {
                      if (newIdx != null) {
                        setState(() => _currentChapterIndex = newIdx);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  color: textColor,
                  onPressed: () => setState(() => _fontSize = (_fontSize - 1).clamp(12.0, 30.0)),
                  tooltip: 'Smaller Font',
                ),
                Text('${_fontSize.toInt()}pt', style: TextStyle(color: textColor, fontSize: 12)),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  color: textColor,
                  onPressed: () => setState(() => _fontSize = (_fontSize + 1).clamp(12.0, 30.0)),
                  tooltip: 'Larger Font',
                ),
              ],
            ),
          ),
          // Ebook Page Surface - Full Width
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Container(
                width: double.infinity,
                color: cardBg,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeChapter.title,
                      style: TextStyle(
                        color: EngineColors.coralAccent,
                        fontSize: _fontSize + 6,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 24),
                    SelectableText(
                      activeChapter.content,
                      style: TextStyle(
                        color: textColor,
                        fontSize: _fontSize,
                        height: 1.7,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Chapter Navigation Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: widget.isDarkMode ? const Color(0xFF252526) : const Color(0xFFD6D6D6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _currentChapterIndex > 0
                      ? () => setState(() => _currentChapterIndex--)
                      : null,
                  icon: const Icon(Icons.navigate_before, size: 18),
                  label: const Text('Prev Chapter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EngineColors.coralAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
                Text(
                  '${_currentChapterIndex + 1} / ${_chapters.length}',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                ElevatedButton.icon(
                  onPressed: _currentChapterIndex < _chapters.length - 1
                      ? () => setState(() => _currentChapterIndex++)
                      : null,
                  icon: const Icon(Icons.navigate_next, size: 18),
                  label: const Text('Next Chapter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EngineColors.coralAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EpubChapter {
  final String title;
  final String content;
  final String fileName;

  EpubChapter({
    required this.title,
    required this.content,
    required this.fileName,
  });
}
