import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../data/providers/settings_provider.dart';
import '../../utils/file_icon_helper.dart';
import 'package:provider/provider.dart';

class TextViewerScreen extends StatefulWidget {
  final String filePath;
  final String? fileName;
  final String? fileType;

  const TextViewerScreen({
    super.key,
    required this.filePath,
    this.fileName,
    this.fileType,
  });

  @override
  State<TextViewerScreen> createState() => _TextViewerScreenState();
}

class _TextViewerScreenState extends State<TextViewerScreen> {
  String _content = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFileContent();
  }

  Future<void> _loadFileContent() async {
    try {
      final file = File(widget.filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        if (mounted) {
          setState(() {
            _content = content;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'File not found';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error reading file: $e';
          _isLoading = false;
        });
      }
    }
  }

  String get _resolvedFileName {
    if (widget.fileName != null && widget.fileName!.isNotEmpty) {
      return widget.fileName!;
    }
    return widget.filePath.split(Platform.pathSeparator).last;
  }

  String get _resolvedFileType {
    if (widget.fileType != null && widget.fileType!.isNotEmpty) {
      return widget.fileType!;
    }
    return widget.filePath.split('.').last;
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
        title: Text(
          _resolvedFileName,
          style: const TextStyle(
            color: AppTheme.offWhiteText,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Icon(
            FileIconHelper.getIcon(_resolvedFileType),
            color: AppTheme.coralAccent,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              settingsProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: AppTheme.coralAccent,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () => settingsProvider.updateSettingParam('isDarkMode', !settingsProvider.isDarkMode),
          ),
          const SizedBox(width: 8),
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
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: AppTheme.coralAccent,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: AppTheme.offWhiteText,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : _content.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.charcoalCard,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 48,
                              color: AppTheme.coralAccent,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'This file is empty',
                              style: TextStyle(
                                color: AppTheme.offWhiteText,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        padding: const EdgeInsets.all(16.0),
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
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: SelectableText(
                            _content,
                            style: const TextStyle(
                              color: AppTheme.offWhiteText,
                              fontSize: 14,
                              fontFamily: 'monospace',
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
    );
  }
}
