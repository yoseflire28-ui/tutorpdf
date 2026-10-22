import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../base_engine.dart';

/// PDF Viewer Engine
/// Handles PDF rendering with canvas-based vector rendering, zoom/pan controls, and accessible text layer.
class PdfViewerEngine extends StatefulWidget {
  final String filePath;
  final bool isDarkMode;

  const PdfViewerEngine({
    super.key,
    required this.filePath,
    required this.isDarkMode,
  });

  @override
  State<PdfViewerEngine> createState() => _PdfViewerEngineState();
}

class _PdfViewerEngineState extends State<PdfViewerEngine> {
  PdfViewerController? _pdfViewerController;
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 0;
  double _zoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void didUpdateWidget(PdfViewerEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _loadPdf();
    }
  }

  Future<void> _loadPdf() async {
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

      if (mounted) {
        setState(() {
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
        onRetry: _loadPdf,
      );
    }

    return Container(
      color: canvasBg,
      width: double.infinity,
      height: double.infinity,
      child: _buildPdfViewer(),
    );
  }

  Widget _buildPdfViewer() {
    return Stack(
      children: [
        // PDF Viewer
        SfPdfViewer.file(
          File(widget.filePath),
          controller: _pdfViewerController,
          canShowScrollHead: false,
          canShowScrollStatus: false,
          canShowPaginationDialog: false,
          canShowHyperlinkDialog: false,
          canShowSignaturePadDialog: false,
          canShowTextSelectionMenu: true,
          enableTextSelection: true,
          onDocumentLoaded: (PdfDocumentLoadedDetails details) {
            setState(() {
              _totalPages = details.document.pages.count;
            });
          },
          onPageChanged: (PdfPageChangedDetails details) {
            setState(() {
              _currentPage = details.newPageNumber;
            });
          },
          onZoomLevelChanged: (PdfZoomDetails details) {
            setState(() {
              _zoomLevel = details.newZoomLevel;
            });
          },
        ),
        
        // Page navigation controls
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: _buildPageControls(),
        ),
        
        // Zoom controls
        Positioned(
          top: 16,
          right: 16,
          child: _buildZoomControls(),
        ),
      ],
    );
  }

  Widget _buildPageControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isDarkMode 
            ? Colors.black.withOpacity(0.8) 
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1 ? () => _previousPage() : null,
            color: widget.isDarkMode ? Colors.white : Colors.black,
          ),
          Text(
            '$_currentPage / $_totalPages',
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white : Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages ? () => _nextPage() : null,
            color: widget.isDarkMode ? Colors.white : Colors.black,
          ),
        ],
      ),
    );
  }

  Widget _buildZoomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.isDarkMode 
            ? Colors.black.withOpacity(0.8) 
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: _zoomLevel > 0.5 ? () => _zoomOut() : null,
            color: widget.isDarkMode ? Colors.white : Colors.black,
            iconSize: 20,
          ),
          Text(
            '${(_zoomLevel * 100).toInt()}%',
            style: TextStyle(
              color: widget.isDarkMode ? Colors.white : Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: _zoomLevel < 3.0 ? () => _zoomIn() : null,
            color: widget.isDarkMode ? Colors.white : Colors.black,
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  void _previousPage() {
    if (_pdfViewerController != null && _currentPage > 1) {
      _pdfViewerController!.previousPage();
    }
  }

  void _nextPage() {
    if (_pdfViewerController != null && _currentPage < _totalPages) {
      _pdfViewerController!.nextPage();
    }
  }

  void _zoomIn() {
    if (_pdfViewerController != null && _zoomLevel < 3.0) {
      final newZoom = _zoomLevel + 0.25;
      _pdfViewerController!.zoomLevel = newZoom;
    }
  }

  void _zoomOut() {
    if (_pdfViewerController != null && _zoomLevel > 0.5) {
      final newZoom = _zoomLevel - 0.25;
      _pdfViewerController!.zoomLevel = newZoom;
    }
  }
}
