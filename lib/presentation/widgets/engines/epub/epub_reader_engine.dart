import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../base_engine.dart';

/// EPUB Reader Engine
/// Handles EPUB eBook rendering with TOC navigation, reflowable controls, and reading progress.
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
  WebViewController? _webViewController;
  bool _isLoading = true;
  String? _error;
  EpubBook? _epubBook;

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
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        throw Exception("File does not exist at path: ${widget.filePath}");
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception("File byte stream is empty (0 bytes read).");
      }

      // Parse EPUB structure
      _epubBook = EpubParser.parse(bytes);

      final html = _buildEpubHtml(_epubBook!);

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(widget.isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFE0E0E0));

      await controller.loadHtmlString(html, baseUrl: 'about:blank');

      if (mounted) {
        setState(() {
          _webViewController = controller;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canvasBg = widget.isDarkMode ? EngineColors.darkCanvas : EngineColors.lightCanvas;

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
        onRetry: _loadEpub,
      );
    }

    return Container(
      color: canvasBg,
      width: double.infinity,
      height: double.infinity,
      child: _buildWebView(),
    );
  }

  Widget _buildWebView() {
    if (_webViewController == null) return const SizedBox.shrink();
    
    return SizedBox.expand(
      child: WebViewWidget(controller: _webViewController!),
    );
  }

  String _buildEpubHtml(EpubBook book) {
    final bgColor = widget.isDarkMode ? '#1E1E1E' : '#FFFFFF';
    final textColor = widget.isDarkMode ? '#E0E0E0' : '#1A1A1A';
    final accentColor = widget.isDarkMode ? '#4A9EFF' : '#2196F3';
    final drawerBg = widget.isDarkMode ? '#2A2A2A' : '#F5F5F5';

    // Build TOC HTML
    final tocHtml = _buildTocHtml(book, drawerBg, textColor, accentColor);

    // Build content HTML
    final contentHtml = _buildContentHtml(book, bgColor, textColor);

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    html, body {
      margin: 0 !important;
      padding: 0 !important;
      background-color: $bgColor !important;
      color: $textColor !important;
      width: 100vw !important;
      height: 100vh !important;
      overflow: hidden !important;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    }
    
    .epub-container {
      display: flex;
      height: 100vh;
    }
    
    .toc-drawer {
      width: 300px;
      background-color: $drawerBg;
      border-right: 1px solid ${widget.isDarkMode ? '#555555' : '#CCCCCC'};
      overflow-y: auto;
      transition: transform 0.3s ease;
      position: absolute;
      top: 0;
      left: 0;
      bottom: 0;
      z-index: 1000;
      transform: translateX(-100%);
    }
    
    .toc-drawer.open {
      transform: translateX(0);
    }
    
    .toc-header {
      padding: 16px;
      font-size: 18px;
      font-weight: 600;
      border-bottom: 1px solid ${widget.isDarkMode ? '#555555' : '#CCCCCC'};
    }
    
    .toc-item {
      padding: 12px 16px;
      cursor: pointer;
      border-bottom: 1px solid ${widget.isDarkMode ? '#333333' : '#EEEEEE'};
      transition: background-color 0.2s;
    }
    
    .toc-item:hover {
      background-color: ${widget.isDarkMode ? '#3A3A3A' : '#E0E0E0'};
    }
    
    .toc-item.active {
      background-color: $accentColor;
      color: white;
    }
    
    .toc-item-level-1 {
      padding-left: 16px;
      font-weight: 600;
    }
    
    .toc-item-level-2 {
      padding-left: 32px;
      font-weight: 400;
    }
    
    .toc-item-level-3 {
      padding-left: 48px;
      font-weight: 400;
      font-size: 14px;
    }
    
    .content-area {
      flex: 1;
      overflow-y: auto;
      padding: 24px;
      max-width: 800px;
      margin: 0 auto;
    }
    
    .toolbar {
      position: fixed;
      top: 0;
      right: 0;
      left: 0;
      height: 56px;
      background-color: $drawerBg;
      border-bottom: 1px solid ${widget.isDarkMode ? '#555555' : '#CCCCCC'};
      display: flex;
      align-items: center;
      padding: 0 16px;
      z-index: 999;
    }
    
    .toolbar-button {
      background: none;
      border: none;
      padding: 8px 12px;
      cursor: pointer;
      color: $textColor;
      font-size: 16px;
      border-radius: 4px;
    }
    
    .toolbar-button:hover {
      background-color: ${widget.isDarkMode ? '#3A3A3A' : '#E0E0E0'};
    }
    
    .reading-controls {
      display: flex;
      gap: 16px;
      align-items: center;
      margin-left: auto;
    }
    
    .font-size-control {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    
    .progress-bar {
      position: fixed;
      bottom: 0;
      left: 0;
      right: 0;
      height: 4px;
      background-color: ${widget.isDarkMode ? '#333333' : '#E0E0E0'};
    }
    
    .progress-fill {
      height: 100%;
      background-color: $accentColor;
      width: 0%;
      transition: width 0.3s ease;
    }
    
    .epub-content {
      line-height: 1.8;
      font-size: 18px;
    }
    
    .epub-content p {
      margin-bottom: 16px;
    }
    
    .epub-content h1, .epub-content h2, .epub-content h3 {
      margin-top: 24px;
      margin-bottom: 16px;
    }
    
    .epub-content img {
      max-width: 100%;
      height: auto;
      display: block;
      margin: 16px auto;
    }
  </style>
</head>
<body>
  <div class="epub-container">
    <div class="toc-drawer" id="tocDrawer">
      <div class="toc-header">Table of Contents</div>
      $tocHtml
    </div>
    
    <div class="content-area">
      <div class="toolbar">
        <button class="toolbar-button" id="tocToggle">☰</button>
        <div class="reading-controls">
          <div class="font-size-control">
            <button class="toolbar-button" id="fontDecrease">A-</button>
            <span id="fontSizeDisplay">18px</span>
            <button class="toolbar-button" id="fontIncrease">A+</button>
          </div>
        </div>
      </div>
      
      <div class="epub-content" id="epubContent">
        $contentHtml
      </div>
    </div>
    
    <div class="progress-bar">
      <div class="progress-fill" id="progressFill"></div>
    </div>
  </div>
  
  <script>
    const tocDrawer = document.getElementById('tocDrawer');
    const tocToggle = document.getElementById('tocToggle');
    const epubContent = document.getElementById('epubContent');
    const progressFill = document.getElementById('progressFill');
    
    let currentFontSize = 18;
    
    // Toggle TOC drawer
    tocToggle.addEventListener('click', () => {
      tocDrawer.classList.toggle('open');
    });
    
    // Font size controls
    document.getElementById('fontIncrease').addEventListener('click', () => {
      if (currentFontSize < 32) {
        currentFontSize += 2;
        updateFontSize();
      }
    });
    
    document.getElementById('fontDecrease').addEventListener('click', () => {
      if (currentFontSize > 12) {
        currentFontSize -= 2;
        updateFontSize();
      }
    });
    
    function updateFontSize() {
      epubContent.style.fontSize = currentFontSize + 'px';
      document.getElementById('fontSizeDisplay').textContent = currentFontSize + 'px';
    }
    
    // Reading progress
    window.addEventListener('scroll', () => {
      const scrollTop = window.scrollY;
      const docHeight = document.documentElement.scrollHeight - window.innerHeight;
      const progress = (scrollTop / docHeight) * 100;
      progressFill.style.width = progress + '%';
    });
    
    // TOC item click handlers
    document.querySelectorAll('.toc-item').forEach(item => {
      item.addEventListener('click', () => {
        document.querySelectorAll('.toc-item').forEach(i => i.classList.remove('active'));
        item.classList.add('active');
        tocDrawer.classList.remove('open');
        
        const targetId = item.getAttribute('data-target');
        if (targetId) {
          const targetElement = document.getElementById(targetId);
          if (targetElement) {
            targetElement.scrollIntoView({ behavior: 'smooth' });
          }
        }
      });
    });
  </script>
</body>
</html>
''';
  }

  String _buildTocHtml(EpubBook book, String drawerBg, String textColor, String accentColor) {
    final buffer = StringBuffer();
    
    for (var chapter in book.chapters) {
      final levelClass = 'toc-item-level-${chapter.level}';
      final activeClass = chapter.isFirst ? 'active' : '';
      
      buffer.write('<div class="toc-item $levelClass $activeClass" data-target="${chapter.id}">');
      buffer.write(chapter.title);
      buffer.write('</div>');
    }
    
    return buffer.toString();
  }

  String _buildContentHtml(EpubBook book, String bgColor, String textColor) {
    final buffer = StringBuffer();
    
    for (var chapter in book.chapters) {
      buffer.write('<div id="${chapter.id}" class="chapter">');
      buffer.write('<h${chapter.level} class="chapter-title">${chapter.title}</h${chapter.level}>');
      buffer.write('<div class="chapter-content">');
      buffer.write(chapter.content);
      buffer.write('</div>');
      buffer.write('</div>');
    }
    
    return buffer.toString();
  }
}

/// EPUB Parser
class EpubParser {
  static EpubBook parse(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    
    // Parse container.xml to find root file
    final containerFile = archive.findFile('META-INF/container.xml');
    if (containerFile == null) {
      return EpubBook(chapters: []);
    }
    
    try {
      final containerContent = String.fromCharCodes(containerFile.content);
      final containerDoc = XmlDocument.parse(containerContent);
      final rootPath = containerDoc.findAllElements('rootfile').firstOrNull?.getAttribute('full-path') ?? 'OEBPS/content.opf';
      
      // Parse OPF file
      final opfFile = archive.findFile(rootPath);
      if (opfFile == null) {
        return EpubBook(chapters: []);
      }
      
      final opfContent = String.fromCharCodes(opfFile.content);
      final opfDoc = XmlDocument.parse(opfContent);
      
      // Parse spine for reading order
      final spineItems = opfDoc.findAllElements('itemref').map((item) {
        return item.getAttribute('idref');
      }).toList();
      
      // Parse manifest for file locations
      final manifest = <String, String>{};
      for (var item in opfDoc.findAllElements('item')) {
        final id = item.getAttribute('id');
        final href = item.getAttribute('href');
        if (id != null && href != null) {
          manifest[id] = href;
        }
      }
      
      // Build chapters from spine
      final chapters = <EpubChapter>[];
      for (int i = 0; i < spineItems.length; i++) {
        final itemId = spineItems[i];
        final href = manifest[itemId];
        
        if (href != null) {
          final contentFile = archive.findFile('$rootPath/../$href');
          if (contentFile != null) {
            final content = String.fromCharCodes(contentFile.content);
            final chapter = _parseChapter(content, i);
            chapters.add(chapter);
          }
        }
      }
      
      return EpubBook(chapters: chapters);
    } catch (e) {
      return EpubBook(chapters: []);
    }
  }
  
  static EpubChapter _parseChapter(String htmlContent, int index) {
    // Simple HTML parsing for chapter title
    final title = 'Chapter ${index + 1}';
    final id = 'chapter-$index';
    
    // Clean HTML content
    final cleanedContent = htmlContent
        .replaceAll(RegExp(r'<html[^>]*>'), '')
        .replaceAll(RegExp(r'</html>'), '')
        .replaceAll(RegExp(r'<body[^>]*>'), '')
        .replaceAll(RegExp(r'</body>'), '');
    
    return EpubChapter(
      id: id,
      title: title,
      content: cleanedContent,
      level: 1,
      isFirst: index == 0,
    );
  }
}

/// EPUB Book structure
class EpubBook {
  final List<EpubChapter> chapters;
  final String? title;
  final String? author;

  EpubBook({
    required this.chapters,
    this.title,
    this.author,
  });
}

/// EPUB Chapter
class EpubChapter {
  final String id;
  final String title;
  final String content;
  final int level; // 1-3 for heading level
  final bool isFirst;

  EpubChapter({
    required this.id,
    required this.title,
    required this.content,
    required this.level,
    required this.isFirst,
  });
}
