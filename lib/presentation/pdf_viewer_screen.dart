import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../core/theme_and_file_engine.dart';
import '../data/providers/settings_provider.dart';
import '../data/providers/active_document_provider.dart';
import '../models/document.dart';
import '../services/content_stream_reader.dart';

enum ScrollMode { vertical, horizontal }

class PdfViewerScreen extends StatefulWidget {
  final String uri;
  final String title;

  const PdfViewerScreen({
    super.key,
    required this.uri,
    required this.title,
  });

  const PdfViewerScreen.fromPath({
    super.key,
    required String filePath,
    String? fileName,
  })  : uri = filePath,
        title = fileName ?? filePath;

  String get filePath => uri;
  String? get fileName => title;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late PdfViewerController _pdfViewerController;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  bool _isNightMode = false;
  bool _syncWithGlobalTheme = true;
  bool _isFullScreen = false;
  ScrollMode _scrollMode = ScrollMode.vertical;
  bool _caseSensitive = false;
  bool _showOverlays = true;
  Uint8List? _pdfBytes;
  bool _isLoadingPdf = true;
  
  List<PdfTextSearchResult> _searchResults = [];
  int _currentSearchIndex = 0;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _loadPdfBytes();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        Provider.of<ActiveDocumentProvider>(context, listen: false).setActiveDocument(
          Document(
            id: widget.uri,
            displayName: widget.title,
            fileExtension: 'pdf',
            uriString: widget.uri,
            lastOpened: DateTime.now().toIso8601String(),
          ),
        );
      } catch (_) {}
    });
    // Sync with global theme on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();
      if (_syncWithGlobalTheme) {
        setState(() {
          _isNightMode = settings.isDarkMode;
        });
      }
    });
  }

  Future<void> _loadPdfBytes() async {
    try {
      if (widget.uri.startsWith('content://')) {
        final bytes = await ContentStreamReader.readBytes(widget.uri);
        if (mounted) {
          setState(() {
            _pdfBytes = bytes;
            _isLoadingPdf = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingPdf = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPdf = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Gracefully restore system overlays
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (e) {
      debugPrint('Error restoring system overlays: $e');
    }
    _pdfViewerController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
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
      setState(() {
        _isFullScreen = !_isFullScreen;
        // Automatically hide other overlays when entering fullscreen
        if (_isFullScreen) {
          _showOverlays = false;
        } else {
          _showOverlays = true;
        }
      });

      if (_isFullScreen) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    } catch (e) {
      debugPrint('Fullscreen toggle error: $e');
    }
  }

  void _toggleNightMode() {
    setState(() {
      _isNightMode = !_isNightMode;
      _syncWithGlobalTheme = false; // User manually toggled, stop auto-sync
    });
  }

  void _toggleScrollMode() {
    setState(() {
      _scrollMode = _scrollMode == ScrollMode.vertical 
          ? ScrollMode.horizontal 
          : ScrollMode.vertical;
    });
  }

  void _toggleOverlays() {
    setState(() {
      _showOverlays = !_showOverlays;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
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
            backgroundColor: _isNightMode ? const Color(0xFF1E1E1E) : Theme.of(context).scaffoldBackgroundColor,
            appBar: null,
            body: Stack(
              children: [
                GestureDetector(
                  onTap: _toggleOverlays,
                  child: Positioned.fill(
                    child: _buildPdfViewer(settings),
                  ),
                ),
                _buildHeaderOverlay(),
                if (_isSearching) _buildSearchingOverlay(),
                _buildFloatingControlOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPdfViewer(SettingsProvider settings) {
    Widget viewer;
    if (widget.uri.startsWith('content://')) {
      if (_isLoadingPdf) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFFE65A4B)),
        );
      }
      if (_pdfBytes == null || _pdfBytes!.isEmpty) {
        return const Center(
          child: Text(
            'Failed to load PDF content.',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        );
      }
      viewer = SfPdfViewer.memory(
        _pdfBytes!,
        controller: _pdfViewerController,
        scrollDirection: _scrollMode == ScrollMode.vertical 
            ? PdfScrollDirection.vertical 
            : PdfScrollDirection.horizontal,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        canShowPaginationDialog: true,
        canShowSignaturePadDialog: true,
        pageSpacing: 8,
        enableTextSelection: true,
        enableDocumentLinkAnnotation: true,
        initialZoomLevel: settings.defaultZoom,
        interactionMode: _isNightMode 
            ? PdfInteractionMode.pan 
            : PdfInteractionMode.selection,
      );
    } else {
      viewer = SfPdfViewer.file(
        File(widget.uri),
        controller: _pdfViewerController,
        scrollDirection: _scrollMode == ScrollMode.vertical 
            ? PdfScrollDirection.vertical 
            : PdfScrollDirection.horizontal,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        canShowPaginationDialog: true,
        canShowSignaturePadDialog: true,
        pageSpacing: 8,
        enableTextSelection: true,
        enableDocumentLinkAnnotation: true,
        initialZoomLevel: settings.defaultZoom,
        interactionMode: _isNightMode 
            ? PdfInteractionMode.pan 
            : PdfInteractionMode.selection,
      );
    }

    // Apply color inversion filter for night mode
    if (_isNightMode) {
      viewer = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1,  0,  0, 0, 255,
           0, -1,  0, 0, 255,
           0,  0, -1, 0, 255,
           0,  0,  0, 1,   0,
        ]),
        child: viewer,
      );
    }

    return viewer;
  }

  Widget _buildHeaderOverlay() {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final bool shouldShow = _showOverlays && !_isFullScreen;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      top: shouldShow ? 0 : -80 - statusBarHeight,
      left: 0,
      right: 0,
      child: Container(
        height: 60 + statusBarHeight,
        padding: EdgeInsets.only(top: statusBarHeight, left: 8, right: 8),
        color: const Color(0xFF3D3D3F),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFE65A4B)),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: Color(0xFFF9F6F0),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(
                _scrollMode == ScrollMode.vertical 
                    ? Icons.view_column_rounded 
                    : Icons.view_stream_rounded,
                color: const Color(0xFFE65A4B),
              ),
              onPressed: _toggleScrollMode,
              tooltip: 'Toggle Scroll Mode',
            ),
            IconButton(
              icon: Icon(
                _isNightMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: const Color(0xFFE65A4B),
              ),
              onPressed: _toggleNightMode,
              tooltip: 'Toggle Night Mode',
            ),
            IconButton(
              icon: Icon(
                _isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                color: const Color(0xFFE65A4B),
              ),
              onPressed: _toggleFullScreen,
              tooltip: 'Toggle Full Screen',
            ),
            IconButton(
              icon: const Icon(Icons.search_rounded, color: Color(0xFFE65A4B)),
              onPressed: _showSearchDialog,
              tooltip: 'Search',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingControlOverlay() {
    // Only display if in fullscreen or header is hidden
    final bool shouldShow = _isFullScreen || !_showOverlays;
    
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      top: shouldShow ? 16 + MediaQuery.of(context).padding.top : -60,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF3D3D3F).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ]
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                _scrollMode == ScrollMode.vertical 
                    ? Icons.view_column_rounded 
                    : Icons.view_stream_rounded,
                color: const Color(0xFFE65A4B),
              ),
              onPressed: _toggleScrollMode,
            ),
            IconButton(
              icon: Icon(
                _isNightMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: const Color(0xFFE65A4B),
              ),
              onPressed: _toggleNightMode,
            ),
            IconButton(
              icon: Icon(
                _isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                color: const Color(0xFFE65A4B),
              ),
              onPressed: _toggleFullScreen,
            ),
            IconButton(
              icon: const Icon(Icons.search_rounded, color: Color(0xFFE65A4B)),
              onPressed: _showSearchDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchingOverlay() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Searching Document...',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Search Document',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _searchController,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Enter search keyword...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: AppColors.creamBackground.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                    ),
                  ),
                  onSubmitted: (_) {
                    _performSearch();
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: _caseSensitive,
                      onChanged: (value) {
                        setDialogState(() {
                          _caseSensitive = value ?? false;
                        });
                      },
                      activeColor: AppColors.coralAccent,
                      checkColor: AppColors.offWhiteText,
                    ),
                    Text(
                      'Case Sensitive',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ],
                ),
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_currentSearchIndex + 1} / ${_searchResults.length}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.arrow_back_rounded, color: Theme.of(context).colorScheme.primary),
                              onPressed: () {
                                _previousSearchResult();
                                setDialogState(() {});
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.arrow_forward_rounded, color: Theme.of(context).colorScheme.primary),
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
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  _performSearch();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
