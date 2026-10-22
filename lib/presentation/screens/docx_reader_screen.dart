import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../core/app_theme.dart';
import '../../core/utils/docx_validator.dart';
import '../../core/utils/file_path_resolver.dart';
import '../../data/providers/settings_provider.dart';
import '../../data/providers/active_document_provider.dart';
import '../../models/document.dart';
import '../../services/docx_to_pdf_service.dart';

/// Native DOCX-to-PDF Reader Screen
/// 
/// Features:
/// - Converts DOCX files to PDF using native Dart libraries
/// - Runs conversion in background isolate with BackgroundIsolateBinaryMessenger
/// - Full UTF-8 & Smart Quote / Symbol sanitization
/// - Dynamic Light/Dark Mode synchronisation matching app theme
/// - Displays converted PDF using Syncfusion PDF viewer
/// - Handles content:// URIs via FilePathResolver
/// - Pre-flight validation with magic byte verification
class DocxReaderScreen extends StatefulWidget {
  final String uri;
  final String title;

  const DocxReaderScreen({
    super.key,
    required this.uri,
    required this.title,
  });

  const DocxReaderScreen.fromPath({
    super.key,
    required String filePath,
    String? fileName,
  })  : uri = filePath,
        title = fileName ?? filePath;

  String get filePath => uri;
  String? get fileName => title;

  @override
  State<DocxReaderScreen> createState() => _DocxReaderScreenState();
}

class _DocxReaderScreenState extends State<DocxReaderScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String? _pdfPath;
  bool? _lastConvertedDarkMode;

  String get _displayName => widget.title;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
    if (_lastConvertedDarkMode == null) {
      _lastConvertedDarkMode = isDarkMode;
      _convertDocxToPdf(isDarkMode: isDarkMode);
    } else if (_lastConvertedDarkMode != isDarkMode && !_isLoading) {
      _lastConvertedDarkMode = isDarkMode;
      _convertDocxToPdf(isDarkMode: isDarkMode);
    }
  }

  /// Converts DOCX to PDF in background isolate with theme and font support
  Future<void> _convertDocxToPdf({required bool isDarkMode}) async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _hasError = false;
          _errorMessage = '';
        });
      }

      // Step 1: Perform platform channel calls on the main UI thread BEFORE spawning the isolate
      String resolvedPath = widget.filePath;
      if (FilePathResolver.isContentUri(widget.filePath) || FilePathResolver.isFileUri(widget.filePath)) {
        debugPrint('[DocxReader] Resolving URI: ${widget.filePath}');
        resolvedPath = await FilePathResolver.resolveToLocalFilePath(widget.filePath);
        debugPrint('[DocxReader] Resolved to: $resolvedPath');
      }

      // Step 2: Validate the resolved file on main thread
      final validationError = await DocxValidator.validateDocxHeaderWithDetails(resolvedPath);
      if (validationError != null) {
        throw Exception(validationError);
      }

      // Step 3: Read resolved DOCX binary file bytes into Uint8List on main thread
      final Uint8List docxBytes = await File(resolvedPath).readAsBytes();

      // Step 4: Capture RootIsolateToken on main thread
      final RootIsolateToken? token = RootIsolateToken.instance;
      if (token == null) {
        throw Exception('RootIsolateToken.instance is null on main thread');
      }

      // Step 5: Optionally load TTF font bytes on main thread for full Unicode fidelity
      Uint8List? fontBytes;
      try {
        final fontData = await rootBundle.load('assets/fonts/Arial.ttf');
        fontBytes = fontData.buffer.asUint8List();
      } catch (e) {
        debugPrint('[DocxReader] Custom font not loaded, using standard typography: $e');
      }

      // Step 6: Convert DOCX bytes to PDF bytes in background isolate with BackgroundIsolateBinaryMessenger
      debugPrint('[DocxReader] Starting DOCX-to-PDF conversion in isolate (isDarkMode: $isDarkMode)...');
      final Uint8List pdfBytes = await compute(
        convertDocxToPdfIsolate,
        DocxConversionParams(
          docxBytes: docxBytes,
          token: token,
          isDarkMode: isDarkMode,
          fontBytes: fontBytes,
        ),
      );

      // Step 7: Write compiled PDF bytes to temporary directory on main thread
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final themeTag = isDarkMode ? 'dark' : 'light';
      final pdfPath = '${tempDir.path}/converted_doc_${themeTag}_$timestamp.pdf';
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
                fileExtension: 'docx',
                uriString: widget.filePath,
                lastOpened: DateTime.now().toIso8601String(),
              ),
              convertedPdfPath: pdfPath,
            );
          }
        } catch (_) {}
        debugPrint('[DocxReader] Conversion complete: $pdfPath');
      }
    } catch (e) {
      debugPrint('[DocxReader] Conversion error: $e');
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
    final isCorruptFile = _errorMessage.contains('Invalid DOCX format') ||
                          _errorMessage.contains('File Transfer Incomplete') ||
                          _errorMessage.contains('missing standard ZIP header');
    
    final isUriError = _errorMessage.contains('Unable to access file storage') ||
                       _errorMessage.contains('Failed to resolve content URI');
    
    if (isCorruptFile) {
      await DocxValidator.deleteCorruptFile(widget.filePath);
    }
    
    if (isUriError) {
      await FilePathResolver.clearCache(deleteTempFiles: true);
    }
    
    if (mounted) {
      final isDarkMode = context.read<SettingsProvider>().isDarkMode;
      _lastConvertedDarkMode = isDarkMode;
      _convertDocxToPdf(isDarkMode: isDarkMode);
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
            const Text(
              'DOCX',
              style: TextStyle(
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
          // Main content - PDF viewer or loading state
          if (_isLoading)
            _buildLoadingState()
          else if (_pdfPath != null)
            _buildPdfViewer(settingsProvider.isDarkMode)
          else
            _buildErrorState(),
          
          // Error boundary overlay banner
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
            'Converting document to PDF...',
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
      color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF),
      child: SfPdfViewer.file(
        File(_pdfPath!),
        canShowScrollHead: true,
        canShowScrollStatus: true,
        canShowPaginationDialog: true,
        pageSpacing: 4,
        enableTextSelection: true,
        enableDocumentLinkAnnotation: true,
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.coralAccent,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Conversion Failed',
            style: TextStyle(
              color: AppTheme.offWhiteText,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.offWhiteText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOverlay() {
    final isCorruptFile = _errorMessage.contains('Invalid DOCX format') ||
                          _errorMessage.contains('File Transfer Incomplete') ||
                          _errorMessage.contains('missing standard ZIP header');
    
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
                    isUriError ? 'File Access Error' : (isCorruptFile ? 'File Transfer Incomplete' : 'Document Load Error'),
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
                  ? 'Unable to access file storage. Please re-select the document from your device.'
                  : (isCorruptFile 
                      ? 'The downloaded file is corrupt or missing binary data. Please redownload the document.'
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
