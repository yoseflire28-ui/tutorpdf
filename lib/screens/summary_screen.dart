import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../data/providers/settings_provider.dart';
import '../models/document.dart';
import '../services/gemini_service.dart';
import '../services/text_extraction_service.dart';
import '../services/settings_service.dart';
import 'api_settings_screen.dart';

class SummaryScreen extends StatefulWidget {
  final Document document;
  final int currentPage;

  const SummaryScreen({
    super.key,
    required this.document,
    this.currentPage = 0,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final _geminiService = GeminiService();
  final _textService = TextExtractionService();
  
  String _summary = '';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _generateSummary();
  }

  Future<String> _getPageContext() async {
    final fullText = await _textService.extractText(widget.document.filePath);
    if (fullText.isEmpty) {
      return '';
    }
    final chunks = _textService.chunkByPages(fullText);
    return _textService.chunkForPage(chunks, widget.currentPage);
  }

  Future<void> _generateSummary() async {
    final hasKey = await SettingsService().hasApiKey();
    if (!hasKey) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Add your Gemini API key in Settings to use AI features';
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final contextText = await _getPageContext();
      if (contextText.isEmpty) {
        throw Exception("No text content could be extracted from this document.");
      }

      final summaryText = await _geminiService.generateSummary(contextText);

      if (mounted) {
        setState(() {
          _summary = summaryText;
          _isLoading = false;
        });
      }
    } on RateLimitException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'You\'ve sent too many requests. Please wait ${e.retryAfterSeconds}s and try again.';
          _isLoading = false;
        });
      }
    } on ApiClientException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.userFriendlyMessage;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        setState(() {
          _errorMessage = msg;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        final backgroundColor = settingsProvider.isDarkMode 
            ? AppTheme.darkBackground 
            : AppTheme.creamBackground;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: AppTheme.charcoalCard,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppTheme.offWhiteText,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Document Summary',
                  style: TextStyle(
                    color: AppTheme.offWhiteText,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  widget.document.fileName,
                  style: TextStyle(
                    color: AppTheme.offWhiteText.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            actions: [
              if (!_isLoading && _errorMessage == null)
                IconButton(
                  icon: const Icon(Icons.copy_all_rounded, color: AppTheme.offWhiteText),
                  tooltip: 'Copy Summary',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _summary));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Summary copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.offWhiteText),
                tooltip: 'Regenerate',
                onPressed: _generateSummary,
              ),
            ],
          ),
          body: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: AppTheme.coralAccent),
                      const SizedBox(height: 16),
                      Text(
                        'AI is preparing summary notes...',
                        style: TextStyle(
                          color: AppTheme.charcoalCard.withValues(alpha: 0.7),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : _errorMessage != null
                  ? _buildErrorView()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.summarize_rounded,
                                  color: AppTheme.coralAccent,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Key Notes & Summary',
                                  style: TextStyle(
                                    color: AppTheme.offWhiteText,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24, color: Colors.white24),
                            SelectableText(
                              _summary,
                              style: const TextStyle(
                                color: AppTheme.offWhiteText,
                                fontSize: 15,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
        );
      },
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppTheme.charcoalCard,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppTheme.coralAccent,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _errorMessage!.contains('Gemini API key')
                  ? 'API Key Required'
                  : 'Summary Generation Failed',
              style: const TextStyle(
                color: AppTheme.charcoalCard,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.charcoalCard.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.charcoalCard.withValues(alpha: 0.12),
                ),
              ),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.charcoalCard.withValues(alpha: 0.65),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_errorMessage!.contains('Gemini API key'))
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ApiSettingsScreen(),
                    ),
                  ).then((_) => _generateSummary());
                },
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: const Text(
                  'Open Settings',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.coralAccent,
                  foregroundColor: AppTheme.offWhiteText,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _generateSummary,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Try Again',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.coralAccent,
                  foregroundColor: AppTheme.offWhiteText,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}