import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../models/document.dart';
import '../core/app_theme.dart';

/// DocumentReaderScreen (and DocumentViewerScreen)
///
/// Implements Dark Mode for Document View:
/// - Dark mode canvas and background theme: Dark Charcoal (Color(0xFF3D3D3F)).
/// - App bars, floating action buttons, and accent icons: Coral Red (Color(0xFFE65A4B)).
/// - Page text and content cards in dark mode: Off-White (Color(0xFFF9F6F0)).
class DocumentReaderScreen extends StatefulWidget {
  final Document document;
  const DocumentReaderScreen({super.key, required this.document});

  @override
  State<DocumentReaderScreen> createState() => _DocumentReaderScreenState();
}

class _DocumentReaderScreenState extends State<DocumentReaderScreen> {
  final PdfViewerController _pdfController = PdfViewerController();
  late int _currentPage;
  int _totalPages = 0;
  bool _showControls = true;
  Timer? _controlsTimer;
  bool _isNightMode = true; // Default to Dark Mode for Document View
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.document.currentPage;
    _scheduleControlsHide();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _pdfController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      if (_isFullScreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Dark Charcoal background for Dark Mode, Cream for Light Mode
    final backgroundColor = _isNightMode
        ? const Color(0xFF3D3D3F)
        : AppTheme.creamBackground;

    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: const Color(0xFF3D3D3F),
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: const Color(0xFF3D3D3F),
          secondary: const Color(0xFFE65A4B),
          surface: const Color(0xFF3D3D3F),
          onSurface: const Color(0xFFF9F6F0),
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Color(0xFF3D3D3F),
          textStyle: TextStyle(color: Color(0xFFF9F6F0)),
          iconColor: Color(0xFFE65A4B),
        ),
        textSelectionTheme: TextSelectionThemeData(
          selectionColor: const Color(0xFFE65A4B).withValues(alpha: 0.35),
          selectionHandleColor: const Color(0xFFE65A4B),
        ),
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: _showControls && !_isFullScreen
            ? AppBar(
                backgroundColor: const Color(0xFF3D3D3F),
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFFE65A4B)),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.document.fileName,
                      style: const TextStyle(
                        color: Color(0xFFF9F6F0),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Page ${_currentPage + 1} of $_totalPages',
                      style: const TextStyle(
                        color: Color(0xFFF9F6F0),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      _isNightMode
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: const Color(0xFFE65A4B),
                    ),
                    tooltip: 'Toggle Theme',
                    onPressed: () =>
                        setState(() => _isNightMode = !_isNightMode),
                  ),
                  IconButton(
                    icon: Icon(
                      _isFullScreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      color: const Color(0xFFE65A4B),
                    ),
                    tooltip: 'Full Screen',
                    onPressed: _toggleFullScreen,
                  ),
                ],
              )
            : null,
        body: GestureDetector(
          onTap: () {
            setState(() => _showControls = !_showControls);
            if (_showControls) _scheduleControlsHide();
          },
          child: Container(
            color: backgroundColor,
            child: SfPdfViewer.file(
              File(widget.document.filePath),
              controller: _pdfController,
              canShowScrollHead: true,
              canShowScrollStatus: true,
              pageLayoutMode: PdfPageLayoutMode.single,
              pageSpacing: 12,
              enableDoubleTapZooming: true,
              enableTextSelection: true,
              onDocumentLoaded: (details) {
                if (mounted) {
                  setState(() => _totalPages = details.document.pages.count);
                }
              },
              onPageChanged: (details) {
                if (mounted) {
                  setState(() => _currentPage = details.newPageNumber - 1);
                }
              },
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => setState(() => _isNightMode = !_isNightMode),
          backgroundColor: const Color(0xFFE65A4B),
          foregroundColor: const Color(0xFFF9F6F0),
          tooltip: 'Toggle Theme',
          child: Icon(_isNightMode ? Icons.dark_mode : Icons.light_mode),
        ),
      ),
    );
  }
}
