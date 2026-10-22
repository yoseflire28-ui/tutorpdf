import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../core/app_theme.dart';
import '../data/file_service.dart';

enum ScrollDirection { vertical, horizontal }

class PdfViewer extends StatefulWidget {
  final String filePath;
  final String? fileName;
  final double? initialZoom;

  const PdfViewer({
    super.key,
    required this.filePath,
    this.fileName,
    this.initialZoom,
  });

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer> {
  late PdfViewerController _pdfViewerController;
  final TextEditingController _searchController = TextEditingController();
  
  bool _isNightMode = false;
  bool _isFullScreen = false;
  ScrollDirection _scrollDirection = ScrollDirection.vertical;
  bool _caseSensitive = false;
  
  List<PdfTextSearchResult> _searchResults = [];
  int _currentSearchIndex = 0;
  bool _isSearching = false;
  
  double _currentZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _currentZoom = widget.initialZoom ?? 1.0;
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    _searchController.dispose();
    FileService.exitFullScreen();
    super.dispose();
  }

  Future<void> _performSearch() async {
    if (_searchController.text.isEmpty) {
      setState(() {
        _searchResults = [];
        _currentSearchIndex = 0;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final searchText = _searchController.text;
      _pdfViewerController.searchText(searchText);

      setState(() {
        _searchResults = [PdfTextSearchResult(
          pageNumber: _pdfViewerController.pageNumber,
          bounds: Rect.zero,
          text: searchText,
        )];
        _currentSearchIndex = 0;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _navigateToSearchResult(int index) {
    if (index >= 0 && index < _searchResults.length) {
      setState(() {
        _currentSearchIndex = index;
      });
      _pdfViewerController.jumpToPage(_searchResults[index].pageNumber);
    }
  }

  void _nextSearchResult() {
    if (_searchResults.isNotEmpty) {
      final nextIndex = (_currentSearchIndex + 1) % _searchResults.length;
      _navigateToSearchResult(nextIndex);
    }
  }

  void _previousSearchResult() {
    if (_searchResults.isNotEmpty) {
      final prevIndex = (_currentSearchIndex - 1 + _searchResults.length) % _searchResults.length;
      _navigateToSearchResult(prevIndex);
    }
  }

  Future<void> _toggleFullScreen() async {
    try {
      await FileService.toggleFullScreen();
      setState(() {
        _isFullScreen = FileService.isFullScreen;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle full screen: $e'),
            backgroundColor: AppTheme.charcoalCard,
          ),
        );
      }
    }
  }

  void _toggleNightMode() {
    setState(() {
      _isNightMode = !_isNightMode;
    });
  }

  void _toggleScrollDirection() {
    setState(() {
      _scrollDirection = _scrollDirection == ScrollDirection.vertical 
          ? ScrollDirection.horizontal 
          : ScrollDirection.vertical;
    });
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 0.25).clamp(0.5, 3.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 0.25).clamp(0.5, 3.0);
    });
  }

  void _resetZoom() {
    setState(() {
      _currentZoom = widget.initialZoom ?? 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isNightMode ? Colors.black : AppTheme.creamBackground,
      appBar: _isFullScreen ? null : _buildAppBar(),
      body: Stack(
        children: [
          _buildPdfViewer(),
          if (_isSearching) _buildSearchingOverlay(),
          _buildControlOverlay(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        widget.fileName ?? 'PDF Viewer',
        style: const TextStyle(
          color: AppTheme.offWhiteText,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: AppTheme.charcoalCard,
      elevation: 0,
      iconTheme: const IconThemeData(color: AppTheme.offWhiteText),
      actions: [
        IconButton(
          icon: Icon(
            _scrollDirection == ScrollDirection.vertical 
                ? Icons.view_column 
                : Icons.view_stream,
            color: AppTheme.offWhiteText,
          ),
          onPressed: _toggleScrollDirection,
          tooltip: 'Toggle Scroll Direction',
        ),
        IconButton(
          icon: Icon(
            _isNightMode ? Icons.light_mode : Icons.dark_mode,
            color: AppTheme.offWhiteText,
          ),
          onPressed: _toggleNightMode,
          tooltip: 'Toggle Night Mode',
        ),
        IconButton(
          icon: Icon(
            _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
            color: AppTheme.offWhiteText,
          ),
          onPressed: _toggleFullScreen,
          tooltip: 'Toggle Full Screen',
        ),
        IconButton(
          icon: const Icon(Icons.search, color: AppTheme.offWhiteText),
          onPressed: _showSearchDialog,
          tooltip: 'Search',
        ),
        IconButton(
          icon: const Icon(Icons.zoom_in, color: AppTheme.offWhiteText),
          onPressed: _zoomIn,
          tooltip: 'Zoom In',
        ),
        IconButton(
          icon: const Icon(Icons.zoom_out, color: AppTheme.offWhiteText),
          onPressed: _zoomOut,
          tooltip: 'Zoom Out',
        ),
      ],
    );
  }

  Widget _buildPdfViewer() {
    return Container(
      color: _isNightMode ? Colors.black : AppTheme.creamBackground,
      child: SfPdfViewer.file(
        File(widget.filePath),
        controller: _pdfViewerController,
        scrollDirection: _scrollDirection == ScrollDirection.vertical 
            ? PdfScrollDirection.vertical 
            : PdfScrollDirection.horizontal,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        canShowPaginationDialog: true,
        canShowSignaturePadDialog: true,
        pageSpacing: 4,
        enableTextSelection: true,
        enableDocumentLinkAnnotation: true,
        initialZoomLevel: _currentZoom * 100,
        interactionMode: _isNightMode 
            ? PdfInteractionMode.pan 
            : PdfInteractionMode.selection,
        onDocumentLoaded: (details) {
          try {
            if (_isNightMode) {
              _applyNightMode();
            }
          } catch (e) {
            // Night mode application failed silently
          }
        },
        onPageChanged: (details) {
          setState(() {
            // Page changed
          });
        },
      ),
    );
  }

  void _applyNightMode() {
    // Note: Syncfusion PDF viewer doesn't support direct night mode
    // This is a placeholder for future implementation
    // In a production app, you would need to use a custom renderer
    // or preprocess the PDF pages to invert colors
  }

  Widget _buildControlOverlay() {
    if (_isFullScreen) {
      return Positioned(
        top: 16,
        right: 16,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.charcoalCard.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  _scrollDirection == ScrollDirection.vertical 
                      ? Icons.view_column 
                      : Icons.view_stream,
                  color: AppTheme.offWhiteText,
                ),
                onPressed: _toggleScrollDirection,
                tooltip: 'Toggle Scroll',
              ),
              IconButton(
                icon: Icon(
                  _isNightMode ? Icons.light_mode : Icons.dark_mode,
                  color: AppTheme.offWhiteText,
                ),
                onPressed: _toggleNightMode,
                tooltip: 'Toggle Night Mode',
              ),
              IconButton(
                icon: Icon(
                  _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: AppTheme.offWhiteText,
                ),
                onPressed: _toggleFullScreen,
                tooltip: 'Exit Full Screen',
              ),
              IconButton(
                icon: const Icon(Icons.search, color: AppTheme.offWhiteText),
                onPressed: _showSearchDialog,
                tooltip: 'Search',
              ),
              IconButton(
                icon: const Icon(Icons.zoom_in, color: AppTheme.offWhiteText),
                onPressed: _zoomIn,
                tooltip: 'Zoom In',
              ),
              IconButton(
                icon: const Icon(Icons.zoom_out, color: AppTheme.offWhiteText),
                onPressed: _zoomOut,
                tooltip: 'Zoom Out',
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.offWhiteText),
                onPressed: _resetZoom,
                tooltip: 'Reset Zoom',
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSearchingOverlay() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.charcoalCard.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.coralAccent),
            ),
            SizedBox(height: 16),
            Text(
              'Searching...',
              style: TextStyle(color: AppTheme.offWhiteText),
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.charcoalCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Search Document',
              style: TextStyle(color: AppTheme.offWhiteText),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppTheme.offWhiteText),
                  decoration: InputDecoration(
                    hintText: 'Enter search text',
                    hintStyle: TextStyle(
                      color: AppTheme.offWhiteText.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: AppTheme.creamBackground.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.coralAccent),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppTheme.coralAccent,
                        width: 2,
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.search,
                        color: AppTheme.coralAccent,
                      ),
                      onPressed: () {
                        _performSearch();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  onSubmitted: (_) {
                    _performSearch();
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: _caseSensitive,
                      onChanged: (value) {
                        setDialogState(() {
                          _caseSensitive = value ?? false;
                        });
                      },
                      activeColor: AppTheme.coralAccent,
                      checkColor: AppTheme.offWhiteText,
                    ),
                    const Text(
                      'Case Sensitive',
                      style: TextStyle(color: AppTheme.offWhiteText),
                    ),
                  ],
                ),
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.coralAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.coralAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_currentSearchIndex + 1} / ${_searchResults.length}',
                          style: const TextStyle(
                            color: AppTheme.offWhiteText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: AppTheme.coralAccent,
                              ),
                              onPressed: () {
                                _previousSearchResult();
                                setDialogState(() {});
                              },
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_forward,
                                color: AppTheme.coralAccent,
                              ),
                              onPressed: () {
                                _nextSearchResult();
                                setDialogState(() {});
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.offWhiteText),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  _performSearch();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.coralAccent,
                  foregroundColor: AppTheme.offWhiteText,
                ),
                child: const Text('Search'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PdfTextSearchResult {
  final int pageNumber;
  final Rect bounds;
  final String text;

  PdfTextSearchResult({
    required this.pageNumber,
    required this.bounds,
    required this.text,
  });
}
