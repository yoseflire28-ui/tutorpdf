import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:provider/provider.dart';
import '../models/document.dart';
import '../core/app_theme.dart';
import '../data/providers/settings_provider.dart';

class DocumentViewerScreen extends StatefulWidget {
  final Document document;
  const DocumentViewerScreen({super.key, required this.document});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  final PdfViewerController _pdfController = PdfViewerController();
  late int _currentPage;
  int _totalPages = 0;
  bool _showControls = true;
  Timer? _controlsTimer;
  bool _isFullScreen = false;

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

  Future<void> _onPageChanged(int page, int total) async {
    if (mounted) {
      setState(() {
        _currentPage = page;
        _totalPages = total;
      });
    }
  }

  Future<void> _onRender(int? pages) async {
    if (pages != null && pages != _totalPages && mounted) {
      setState(() => _totalPages = pages);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final backgroundColor = settingsProvider.isDarkMode
        ? AppTheme.darkBackground
        : AppTheme.creamBackground;

    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: AppTheme.charcoalCard,
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: AppTheme.charcoalCard,
          secondary: AppTheme.coralAccent,
          surface: AppTheme.charcoalCard,
          onSurface: AppTheme.offWhiteText,
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: AppTheme.charcoalCard,
          textStyle: TextStyle(color: AppTheme.offWhiteText),
          iconColor: AppTheme.coralAccent,
        ),
        textSelectionTheme: TextSelectionThemeData(
          selectionColor: AppTheme.coralAccent.withValues(alpha: 0.35),
          selectionHandleColor: AppTheme.coralAccent,
        ),
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: _showControls && !_isFullScreen
            ? AppBar(
                backgroundColor: AppTheme.charcoalCard,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppTheme.coralAccent),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.document.fileName,
                      style: const TextStyle(
                        color: AppTheme.offWhiteText,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Page ${_currentPage + 1} of $_totalPages',
                      style: const TextStyle(
                        color: AppTheme.offWhiteText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      settingsProvider.isDarkMode
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: AppTheme.coralAccent,
                    ),
                    tooltip: 'Toggle Theme',
                    onPressed: () => settingsProvider.updateSettingParam('isDarkMode', !settingsProvider.isDarkMode),
                  ),
                  IconButton(
                    icon: Icon(
                      _isFullScreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      color: AppTheme.coralAccent,
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
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.charcoalCard,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SfPdfViewer.file(
                File(widget.document.filePath),
                controller: _pdfController,
                canShowScrollHead: true,
                canShowScrollStatus: true,
                pageLayoutMode: PdfPageLayoutMode.single,
                pageSpacing: 12,
                enableDoubleTapZooming: true,
                onDocumentLoaded: (details) {
                  _onRender(details.document.pages.count);
                },
                onPageChanged: (details) {
                  _onPageChanged(
                      details.newPageNumber - 1, _pdfController.pageCount);
                },
                enableTextSelection: true,
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => settingsProvider.updateSettingParam('isDarkMode', !settingsProvider.isDarkMode),
          backgroundColor: AppTheme.coralAccent,
          foregroundColor: AppTheme.offWhiteText,
          tooltip: 'Toggle Theme',
          child: Icon(settingsProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode),
        ),
      ),
    );
  }
}