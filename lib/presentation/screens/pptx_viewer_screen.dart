import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../core/app_theme.dart';
import '../../core/utils/file_path_resolver.dart';
import '../../core/utils/pptx_validator.dart';
import '../../data/providers/settings_provider.dart';
import '../../data/providers/active_document_provider.dart';
import '../../models/document.dart';
import '../../services/pptx_to_pdf_service.dart';

/// Native PPTX Presentation Viewer Screen
/// 
/// Converts PPTX presentations into landscape PDF slide documents 100% offline
/// using native OpenXML PresentationML parsing in background isolates.
/// Supports high-fidelity bounding box positioning, image extraction, tables,
/// typography sanitization, and real-time Dark Mode synchronization.
class PptxViewerScreen extends StatefulWidget {
  final String uri;
  final String title;

  const PptxViewerScreen({
    super.key,
    required this.uri,
    required this.title,
  });

  const PptxViewerScreen.fromPath({
    super.key,
    required String filePath,
    String? fileName,
  })  : uri = filePath,
        title = fileName ?? filePath;

  String get filePath => uri;
  String? get fileName => title;

  @override
  State<PptxViewerScreen> createState() => _PptxViewerScreenState();
}

class _PptxViewerScreenState extends State<PptxViewerScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String? _pdfPath;
  bool? _lastConvertedDarkMode;
  int _currentPage = 1;
  int _pageCount = 0;

  String get _displayName => widget.title;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    if (_lastConvertedDarkMode == null) {
      _lastConvertedDarkMode = isDarkMode;
      _convertPptxToPdf(isDarkMode: isDarkMode);
    } else if (_lastConvertedDarkMode != isDarkMode && !_isLoading) {
      _lastConvertedDarkMode = isDarkMode;
      _convertPptxToPdf(isDarkMode: isDarkMode);
    }
  }

  /// Converts PPTX to PDF in background isolate with full theme and font support
  Future<void> _convertPptxToPdf({required bool isDarkMode}) async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _hasError = false;
          _errorMessage = '';
        });
      }

      // Step 1: Resolve content:// URIs and file paths on main thread
      String resolvedPath = widget.filePath;
      if (FilePathResolver.isContentUri(widget.filePath) || FilePathResolver.isFileUri(widget.filePath)) {
        debugPrint('[PptxViewer] Resolving URI: ${widget.filePath}');
        resolvedPath = await FilePathResolver.resolveToLocalFilePath(widget.filePath);
        debugPrint('[PptxViewer] Resolved to: $resolvedPath');
      }

      // Step 2: Pre-flight ZIP magic byte verification
      final validationError = await PptxValidator.validatePptxHeaderWithDetails(resolvedPath);
      if (validationError != null) {
        throw Exception(validationError);
      }

      // Step 3: Read binary file bytes on main thread
      final Uint8List pptxBytes = await File(resolvedPath).readAsBytes();

      // Step 4: Capture RootIsolateToken on main thread
      final RootIsolateToken? token = RootIsolateToken.instance;
      if (token == null) {
        throw Exception('RootIsolateToken.instance is null on main thread');
      }

      // Step 5: Optionally load Unicode TTF font bytes on main thread
      Uint8List? fontBytes;
      try {
        final fontData = await rootBundle.load('assets/fonts/Arial.ttf');
        fontBytes = fontData.buffer.asUint8List();
      } catch (e) {
        debugPrint('[PptxViewer] Custom font not loaded, using standard typography: $e');
      }

      // Step 6: Convert PPTX in background isolate with BackgroundIsolateBinaryMessenger
      debugPrint('[PptxViewer] Starting PPTX-to-PDF conversion in isolate (isDarkMode: $isDarkMode)...');
      final Uint8List pdfBytes = await compute(
        convertPptxToPdfIsolate,
        PptxConversionParams(
          pptxBytes: pptxBytes,
          token: token,
          isDarkMode: isDarkMode,
          fontBytes: fontBytes,
        ),
      );

      // Step 7: Write compiled PDF bytes to temporary directory on main thread
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final themeTag = isDarkMode ? 'dark' : 'light';
      final pdfPath = '${tempDir.path}/converted_presentation_${themeTag}_$timestamp.pdf';
      await File(pdfPath).writeAsBytes(pdfBytes);

      if (mounted) {
        setState(() {
          _pdfPath = pdfPath;
          _isLoading = false;
        });
        try {
          final activeProvider = Provider.of<ActiveDocumentProvider>(context, listen: false);
          activeProvider.updateConvertedPdfPath(pdfPath);
          if (!activeProvider.hasActiveDocument) {
            activeProvider.setActiveDocument(
              Document(
                id: widget.filePath,
                displayName: widget.title,
                fileExtension: 'pptx',
                uriString: widget.filePath,
                lastOpened: DateTime.now().toIso8601String(),
              ),
              convertedPdfPath: pdfPath,
            );
          }
        } catch (_) {}
        debugPrint('[PptxViewer] Presentation conversion complete: $pdfPath');
      }
    } catch (e) {
      debugPrint('[PptxViewer] Conversion error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _retryLoading() async {
    final isCorruptFile = _errorMessage.contains('Invalid PPTX') ||
                          _errorMessage.contains('Missing standard ZIP header') ||
                          _errorMessage.contains('file is incomplete');
    
    final isUriError = _errorMessage.contains('Unable to access file storage') ||
                       _errorMessage.contains('Failed to resolve content URI');
    
    if (isCorruptFile) {
      await PptxValidator.deleteCorruptFile(widget.filePath);
    }
    
    if (isUriError) {
      await FilePathResolver.clearCache(deleteTempFiles: true);
    }
    
    if (mounted) {
      final isDarkMode = context.read<SettingsProvider>().isDarkMode;
      _lastConvertedDarkMode = isDarkMode;
      _convertPptxToPdf(isDarkMode: isDarkMode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final backgroundColor = settingsProvider.isDarkMode
        ? AppTheme.darkBackground
        : AppTheme.creamBackground;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.charcoalCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.coralAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _displayName,
              style: const TextStyle(
                color: AppTheme.offWhiteText,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _pageCount > 0 ? 'Slide $_currentPage / $_pageCount' : 'PPTX Presentation',
              style: const TextStyle(
                color: AppTheme.coralAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.coralAccent),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: Icon(
              settingsProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: AppTheme.coralAccent,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () => settingsProvider.updateSettingParam('isDarkMode', !settingsProvider.isDarkMode),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content: PDF viewer or loading state
          if (_isLoading)
            _buildLoadingState()
          else if (_pdfPath != null)
            _buildPdfViewer(settingsProvider.isDarkMode)
          else
            _buildErrorState(),

          // Error overlay
          if (_hasError)
            _buildErrorOverlay(),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.coralAccent),
          ),
          SizedBox(height: 20),
          Text(
            'Converting presentation slides...',
            style: TextStyle(
              color: AppTheme.offWhiteText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfViewer(bool isDarkMode) {
    return Container(
      color: isDarkMode ? const Color(0xFF121212) : const Color(0xFFE5E7EB),
      child: SfPdfViewer.file(
        File(_pdfPath!),
        controller: _pdfViewerController,
        pageLayoutMode: PdfPageLayoutMode.continuous,
        scrollDirection: PdfScrollDirection.vertical,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        canShowPaginationDialog: false,
        pageSpacing: 12,
        enableTextSelection: true,
        enableDocumentLinkAnnotation: true,
        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
          if (mounted) {
            setState(() {
              _pageCount = details.document.pages.count;
            });
          }
        },
        onPageChanged: (PdfPageChangedDetails details) {
          if (mounted) {
            setState(() {
              _currentPage = details.newPageNumber;
            });
          }
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.slideshow_rounded,
            color: AppTheme.coralAccent,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Failed to Load Presentation',
            style: TextStyle(
              color: AppTheme.offWhiteText,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.offWhiteText,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOverlay() {
    final isCorruptFile = _errorMessage.contains('Invalid PPTX') ||
                          _errorMessage.contains('Missing standard ZIP header') ||
                          _errorMessage.contains('file is incomplete');
    
    final isUriError = _errorMessage.contains('Unable to access file storage') ||
                       _errorMessage.contains('Failed to resolve content URI');
    
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.charcoalCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.coralAccent.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.3),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppTheme.coralAccent,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isUriError ? 'File Access Error' : (isCorruptFile ? 'Corrupt Presentation File' : 'Presentation Load Error'),
                    style: const TextStyle(
                      color: AppTheme.offWhiteText,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isUriError 
                  ? 'Unable to access presentation storage. Please re-select the file from your device.'
                  : (isCorruptFile 
                      ? 'The presentation file is corrupt or missing standard binary headers.'
                      : (_errorMessage.isNotEmpty 
                          ? _errorMessage 
                          : 'The file may be corrupt or unreadable.')),
              style: const TextStyle(
                color: AppTheme.offWhiteText,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _retryLoading,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: AppTheme.coralAccent,
                    size: 18,
                  ),
                  label: Text(
                    isUriError ? 'Re-open File' : (isCorruptFile ? 'Redownload / Retry' : 'Retry'),
                    style: const TextStyle(
                      color: AppTheme.coralAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    backgroundColor: AppTheme.coralAccent.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Alias typedef for PptxReaderScreen to support alternate naming conventions
typedef PptxReaderScreen = PptxViewerScreen;
