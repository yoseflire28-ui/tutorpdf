import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../data/providers/settings_provider.dart';
import '../../services/text_extraction_service.dart';
import 'package:provider/provider.dart';

class OfficeDocumentViewerScreen extends StatefulWidget {
  final String filePath;
  final String? fileName;

  const OfficeDocumentViewerScreen({
    super.key,
    required this.filePath,
    this.fileName,
  });

  @override
  State<OfficeDocumentViewerScreen> createState() => _OfficeDocumentViewerScreenState();
}

class _OfficeDocumentViewerScreenState extends State<OfficeDocumentViewerScreen> {
  final TextExtractionService _textExtractionService = TextExtractionService();
  String _extractedText = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDocumentContent();
  }

  Future<void> _loadDocumentContent() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        if (mounted) {
          setState(() {
            _error = 'Document file not found.';
            _isLoading = false;
          });
        }
        return;
      }

      final text = await _textExtractionService.extractText(widget.filePath);
      if (mounted) {
        setState(() {
          _extractedText = text;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load document content: $e';
          _isLoading = false;
        });
      }
    }
  }

  String get _displayName {
    if (widget.fileName != null && widget.fileName!.isNotEmpty) {
      return widget.fileName!;
    }
    return widget.filePath.split(Platform.pathSeparator).last;
  }

  String get _extension {
    return widget.filePath.split('.').last.toUpperCase();
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
              '$_extension Document',
              style: const TextStyle(
                color: AppTheme.coralAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.coralAccent),
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.charcoalCard,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.coralAccent),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.offWhiteText, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: AppTheme.charcoalCard,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _extractedText.trim().isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.description_outlined, size: 56, color: AppTheme.coralAccent),
                                SizedBox(height: 16),
                                Text(
                                  'No readable text extracted from this document.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.offWhiteText,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: SelectableText(
                              _extractedText,
                              style: const TextStyle(
                                color: AppTheme.offWhiteText,
                                fontSize: 15,
                                height: 1.6,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                  ),
                ),
    );
  }
}
