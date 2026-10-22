import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../core/app_theme.dart';
import '../models/document.dart';
import '../services/document_converter_service.dart';

/// Reader screen that processes non-PDF files into an offline PDF IR pipeline
/// and presents them with dark mode contrast inversion.
class ReaderScreen extends StatefulWidget {
  final String filePath;
  final String title;

  const ReaderScreen({
    super.key,
    required this.filePath,
    required this.title,
  });

  ReaderScreen.fromDocument({
    super.key,
    required Document document,
  })  : filePath = document.filePath,
        title = document.fileName;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final PdfViewerController _pdfController = PdfViewerController();
  bool _isConverting = true;
  String _statusText = 'Structuring layout...';
  double _progress = 0.1;
  String? _convertedPdfPath;
  String? _errorMessage;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _showControls = true;
  bool _isDarkMode = true;
  bool _isFullScreen = false;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _scheduleControlsHide();
    _startConversionPipeline();
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

  Future<void> _startConversionPipeline() async {
    final ext = widget.filePath.split('.').last.toLowerCase();
    if (ext == 'pdf') {
      if (mounted) {
        setState(() {
          _convertedPdfPath = widget.filePath;
          _isConverting = false;
        });
      }
      return;
    }

    try {
      final pdfFile = await DocumentConverterService.convertToPdf(
        widget.filePath,
        onProgress: (status, progress) {
          if (mounted) {
            setState(() {
              _statusText = status;
              _progress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _convertedPdfPath = pdfFile.path;
          _isConverting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to convert document: $e';
          _isConverting = false;
        });
      }
    }
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
    final backgroundColor = _isDarkMode ? const Color(0xFF3D3D3F) : AppTheme.creamBackground;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _showControls && !_isFullScreen
          ? AppBar(
              backgroundColor: const Color(0xFF3D3D3F),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFE65A4B)),
                onPressed: () => Navigator.pop(context),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Color(0xFFF9F6F0),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!_isConverting && _errorMessage == null)
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
                    _isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: const Color(0xFFE65A4B),
                  ),
                  tooltip: 'Toggle Theme',
                  onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
                ),
                IconButton(
                  icon: Icon(
                    _isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
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
          child: _buildBodyContent(),
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isConverting) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2C),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE65A4B)),
              ),
              const SizedBox(height: 20),
              Text(
                _statusText,
                style: const TextStyle(
                  color: Color(0xFFF9F6F0),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE65A4B)),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFE65A4B)),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Color(0xFFF9F6F0), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isConverting = true;
                  _errorMessage = null;
                });
                _startConversionPipeline();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65A4B),
              ),
              child: const Text('Retry Conversion'),
            ),
          ],
        ),
      );
    }

    Widget viewer = SfPdfViewer.file(
      File(_convertedPdfPath!),
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
    );

    if (_isDarkMode) {
      viewer = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -0.9, 0, 0, 0, 240,
          0, -0.9, 0, 0, 240,
          0, 0, -0.9, 0, 240,
          0, 0, 0, 1, 0,
        ]),
        child: viewer,
      );
    }

    return viewer;
  }
}
