import 'package:flutter/material.dart';

/// Universal Theme Adapter
/// Provides consistent dark mode theming across all document engines (DOCX, PPTX, XLSX, EPUB, PDF, TXT).
class UniversalThemeAdapter {
  final bool isDarkMode;

  // Light mode colors
  static const String lightCanvas = '#E0E0E0';
  static const String lightPage = '#FFFFFF';
  static const String lightText = '#1A1A1A';
  static const String lightBorder = '#CCCCCC';
  static const String lightAccent = '#2196F3';
  static const String lightHeader = '#F5F5F5';

  // Dark mode colors
  static const String darkCanvas = '#1E1E1E';
  static const String darkPage = '#2A2A2A';
  static const String darkText = '#E0E0E0';
  static const String darkBorder = '#555555';
  static const String darkAccent = '#4A9EFF';
  static const String darkHeader = '#3A3A3A';

  UniversalThemeAdapter({required this.isDarkMode});

  /// Get canvas background color
  String get canvasBg => isDarkMode ? darkCanvas : lightCanvas;

  /// Get page background color
  String get pageBg => isDarkMode ? darkPage : lightPage;

  /// Get default text color
  String get textColor => isDarkMode ? darkText : lightText;

  /// Get border color
  String get borderColor => isDarkMode ? darkBorder : lightBorder;

  /// Get accent color
  String get accentColor => isDarkMode ? darkAccent : lightAccent;

  /// Get header background color
  String get headerBg => isDarkMode ? darkHeader : lightHeader;

  /// Convert a hex color to its dark mode equivalent
  String invertColor(String hexColor) {
    if (!isDarkMode) return hexColor;

    // Remove # if present
    final color = hexColor.replaceAll('#', '');
    if (color.length != 6) return hexColor;

    // Parse RGB
    final r = int.parse(color.substring(0, 2), radix: 16);
    final g = int.parse(color.substring(2, 4), radix: 16);
    final b = int.parse(color.substring(4, 6), radix: 16);

    // Invert with some adjustment for readability
    final invertedR = (255 - r).clamp(0, 255);
    final invertedG = (255 - g).clamp(0, 255);
    final invertedB = (255 - b).clamp(0, 255);

    // Return inverted hex
    return '#${invertedR.toRadixString(16).padLeft(2, '0')}${invertedG.toRadixString(16).padLeft(2, '0')}${invertedB.toRadixString(16).padLeft(2, '0')}';
  }

  /// Get CSS filter for image color protection in dark mode
  String get imageFilter {
    if (!isDarkMode) return 'none';
    return 'invert(1) hue-rotate(180deg)';
  }

  /// Get CSS for page container with theme colors
  String getPageStyle() {
    return '''
      background-color: $pageBg;
      color: $textColor;
      border: 1px solid $borderColor;
      overflow: hidden;
      word-wrap: break-word;
      overflow-wrap: break-word;
    ''';
  }

  /// Get CSS for canvas container
  String getCanvasStyle() {
    return '''
      background-color: $canvasBg;
      color: $textColor;
    ''';
  }

  /// Adapt a text color for current theme
  String adaptTextColor(String? originalColor) {
    if (originalColor == null || originalColor.isEmpty) {
      return textColor;
    }
    if (!isDarkMode) return originalColor;
    return invertColor(originalColor);
  }

  /// Adapt a background color for current theme
  String adaptBackgroundColor(String? originalColor) {
    if (originalColor == null || originalColor.isEmpty) {
      return pageBg;
    }
    if (!isDarkMode) return originalColor;
    return invertColor(originalColor);
  }

  /// Adapt a border color for current theme
  String adaptBorderColor(String? originalColor) {
    if (originalColor == null || originalColor.isEmpty) {
      return borderColor;
    }
    if (!isDarkMode) return originalColor;
    return invertColor(originalColor);
  }

  /// Get CSS variables for theme
  String getCssVariables() {
    return '''
      :root {
        --canvas-bg: $canvasBg;
        --page-bg: $pageBg;
        --text-color: $textColor;
        --border-color: $borderColor;
        --accent-color: $accentColor;
        --header-bg: $headerBg;
        --image-filter: ${imageFilter};
      }
    ''';
  }

  /// Get Flutter Color for canvas background
  Color get canvasColor => isDarkMode 
      ? const Color(0xFF1E1E1E) 
      : const Color(0xFFE0E0E0);

  /// Get Flutter Color for page background
  Color get pageColor => isDarkMode 
      ? const Color(0xFF2A2A2A) 
      : const Color(0xFFFFFFFF);

  /// Get Flutter Color for text
  Color get textFlutterColor => isDarkMode 
      ? const Color(0xFFE0E0E0) 
      : const Color(0xFF1A1A1A);

  /// Get Flutter Color for accent
  Color get accentFlutterColor => isDarkMode 
      ? const Color(0xFF4A9EFF) 
      : const Color(0xFF2196F3);

  /// Get Flutter Color for border
  Color get borderFlutterColor => isDarkMode 
      ? const Color(0xFF555555) 
      : const Color(0xFFCCCCCC);

  /// Get Flutter Color for header background
  Color get headerFlutterBg => isDarkMode 
      ? const Color(0xFF3A3A3A) 
      : const Color(0xFFF5F5F5);

  /// Get complete HTML page wrapper with theme
  String wrapWithTheme(String bodyContent, {String? pageTitle}) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${pageTitle ?? 'Document'}</title>
  <style>
    html, body {
      margin: 0 !important;
      padding: 0 !important;
      background-color: $canvasBg !important;
      color: $textColor !important;
      width: 100vw !important;
      height: 100vh !important;
      overflow-y: auto !important;
      -webkit-overflow-scrolling: touch;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    }
    ${getCssVariables()}
    * {
      box-sizing: border-box;
    }
    img {
      filter: var(--image-filter);
      max-width: 100%;
      height: auto;
    }
    a {
      color: var(--accent-color);
    }
    .doc-page {
      background-color: var(--page-bg);
      color: var(--text-color);
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
      margin: 16px auto;
      overflow: hidden;
      word-wrap: break-word;
      overflow-wrap: break-word;
    }
    .doc-content {
      padding: 16px;
      word-wrap: break-word;
      overflow-wrap: break-word;
    }
  </style>
</head>
<body>
  $bodyContent
</body>
</html>
''';
  }

  /// Get theme-specific CSS for specific engine types
  String getEngineCss(String engineType) {
    switch (engineType.toLowerCase()) {
      case 'docx':
        return _getDocxCss();
      case 'pptx':
        return _getPptxCss();
      case 'xlsx':
        return _getXlsxCss();
      case 'epub':
        return _getEpubCss();
      case 'pdf':
        return _getPdfCss();
      default:
        return _getDefaultCss();
    }
  }

  String _getDocxCss() {
    return '''
      .doc-page {
        background-color:var(--page-bg);
        color: var(--text-color);
        box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        margin: 16px auto;
        overflow: hidden;
        word-wrap: break-word;
        overflow-wrap: break-word;
      }
      .doc-textbox {
        border: 1px solid var(--border-color);
        background-color: var(--page-bg);
      }
      .doc-inline-img, .doc-floating-img {
        filter: var(--image-filter);
        max-width: 100%;
        height: auto;
      }
    ''';
  }

  String _getPptxCss() {
    return '''
      .pptx-slide {
        background-color: var(--page-bg);
        color: var(--text-color);
      }
      .pptx-shape {
        filter: var(--image-filter);
      }
      .pptx-picture {
        filter: var(--image-filter);
      }
    ''';
  }

  String _getXlsxCss() {
    return '''
      .xlsx-grid th {
        background-color: var(--header-bg);
        color: var(--text-color);
      }
      .xlsx-grid td {
        border-color: var(--border-color);
      }
      .sheet-tab.active {
        background-color: var(--page-bg);
        border-color: var(--border-color);
      }
    ''';
  }

  String _getEpubCss() {
    return '''
      .epub-content {
        line-height: 1.8;
        color: var(--text-color);
        word-wrap: break-word;
        overflow-wrap: break-word;
      }
      .toc-drawer {
        background-color: var(--header-bg);
        border-color: var(--border-color);
      }
      .toc-item.active {
        background-color: var(--accent-color);
        color: white;
      }
    ''';
  }

  String _getPdfCss() {
    return '''
      .pdf-page {
        background-color: var(--page-bg);
      }
    ''';
  }

  String _getDefaultCss() {
    return '''
      .content {
        color: var(--text-color);
        background-color: var(--page-bg);
      }
    ''';
  }
}
