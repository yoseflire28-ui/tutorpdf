import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'rich_document_viewer_screen.dart';

enum DocumentType { pdf, docx, pptx, txt, unsupported }

class EmbeddedDocumentReaderScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const EmbeddedDocumentReaderScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<EmbeddedDocumentReaderScreen> createState() =>
      _EmbeddedDocumentReaderScreenState();
}

class _EmbeddedDocumentReaderScreenState
    extends State<EmbeddedDocumentReaderScreen> {
  late PdfViewerController _pdfViewerController;
  String? _currentPdfPath;
  String? _tempPdfPath;

  DocumentType _docType = DocumentType.unsupported;
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _determineDocumentType();
    _prepareDocument();
  }

  void _determineDocumentType() {
    String extension = '';
    if (widget.fileName.contains('.')) {
      extension = widget.fileName.toLowerCase().split('.').last;
    } else if (!widget.filePath.startsWith('content://') && widget.filePath.contains('.')) {
      extension = widget.filePath.toLowerCase().split('.').last;
    }

    if (extension == 'pdf') {
      _docType = DocumentType.pdf;
    } else if (extension == 'docx' || extension == 'doc') {
      _docType = DocumentType.docx;
    } else if (extension == 'pptx' || extension == 'ppt') {
      _docType = DocumentType.pptx;
    } else if (extension == 'txt') {
      _docType = DocumentType.txt;
    } else {
      _docType = DocumentType.unsupported;
      _isLoading = false;
      _errorMessage = "Unsupported file format (.$extension)";
    }
  }

  Future<void> _prepareDocument() async {
    if (_docType == DocumentType.unsupported) return;

    try {
      if (_docType == DocumentType.pdf) {
        _currentPdfPath = widget.filePath;
      } else {
        _currentPdfPath = null;
        _errorMessage = 'This document type is opened in the in-app viewer.';
      }
    } catch (e) {
      _errorMessage = 'Unable to open document: ${e.toString()}';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_docType == DocumentType.docx || _docType == DocumentType.pptx) {
      return RichDocumentViewerScreen(
        filePath: widget.filePath,
        fileName: widget.fileName,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        title: Text(
          _currentPdfPath != null && _totalPages > 0
              ? "${widget.fileName} (Page $_currentPage of $_totalPages)"
              : widget.fileName,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildDocumentViewport()),
            if (_isLoading)
              Container(
                color: const Color(0xFF1E1E1E),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.redAccent,
                  ),
                ),
              ),
            if (_errorMessage != null)
              Container(
                color: const Color(0xFF1E1E1E),
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          _prepareDocument();
                        },
                        child: const Text(
                          'Retry',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentViewport() {
    if (_errorMessage != null) {
      return const SizedBox.shrink();
    }

    if (_currentPdfPath == null) {
      return const Center(
        child: Text(
          'Preparing document...',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return SfPdfViewer.file(
      File(_currentPdfPath!),
      controller: _pdfViewerController,
      onDocumentLoaded: (PdfDocumentLoadedDetails details) {
        setState(() {
          _totalPages = details.document.pages.count;
          _isLoading = false;
        });
      },
      onPageChanged: (PdfPageChangedDetails details) {
        setState(() {
          _currentPage = details.newPageNumber;
        });
      },
      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load PDF: ${details.description}';
        });
      },
    );
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    if (_tempPdfPath != null) {
      try {
        final tempFile = File(_tempPdfPath!);
        if (tempFile.existsSync()) {
          tempFile.deleteSync();
        }
      } catch (_) {}
    }
    super.dispose();
  }
}
