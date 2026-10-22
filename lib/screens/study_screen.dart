// lib/screens/study_screen.dart
//
// TutorPDF — Study Screen (Flashcards & Quiz)
// ─────────────────────────────────────────────────────────────────────────────
// Fix summary (2026-07):
//   • All hardcoded non-brand colors replaced with AppTheme design tokens
//     (creamBackground, charcoalCard, offWhiteText, coralAccent).
//   • _ErrorView "Try Again" button now uses coralAccent per brand spec.
//   • Loading and empty-state widgets updated to match brand palette.
//   • ApiClientException now caught separately so the error panel shows
//     the student-friendly message instead of a raw Dart exception string.

import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../data/providers/settings_provider.dart';
import '../models/document.dart';
import '../models/study_models.dart';
import '../services/gemini_service.dart';
import '../services/text_extraction_service.dart';
import '../services/settings_service.dart';
import 'api_settings_screen.dart';
import '../widgets/flashcard_widget.dart';
import '../widgets/quiz_widget.dart';
import 'package:provider/provider.dart';

class StudyScreen extends StatefulWidget {
  final Document? document;
  final int currentPage;

  const StudyScreen({
    super.key,
    this.document,
    this.currentPage = 0,
  });

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen>
    with SingleTickerProviderStateMixin {
  final _geminiService = GeminiService();
  final _textService = TextExtractionService();
  late TabController _tabController;

  List<StudyCard> _flashcards = [];
  List<QuizQuestion> _quizQuestions = [];
  bool _loadingCards = false;
  bool _loadingQuiz = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _generateContent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<String> _getPageContext() async {
    if (widget.document == null) {
      return 'Generate study materials and quiz questions about general learning topics.';
    }
    final fullText = await _textService.extractText(widget.document!.filePath);
    if (fullText.isEmpty) {
      return 'Generate content about the topic on page ${widget.currentPage + 1} of "${widget.document!.fileName}".';
    }
    final chunks = _textService.chunkByPages(fullText);
    return _textService.chunkForPage(chunks, widget.currentPage);
  }

  Future<void> _generateContent() async {
    final hasKey = await SettingsService().hasApiKey();
    if (!hasKey) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Add your Gemini API key in Settings to use AI features';
          _loadingCards = false;
          _loadingQuiz = false;
        });
      }
      return;
    }

    setState(() {
      _loadingCards = true;
      _loadingQuiz = true;
      _errorMessage = null;
    });

    try {
      final context = await _getPageContext();

      final cards = await _geminiService.generateFlashcards(context, count: 8);
      final questions =
          await _geminiService.generateQuizQuestions(context, count: 5);

      if (mounted) {
        setState(() {
          _flashcards = cards;
          _quizQuestions = questions;
          _loadingCards = false;
          _loadingQuiz = false;
        });
      }
    } on RateLimitException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'You\'ve sent too many requests. Please wait ${e.retryAfterSeconds}s and try again.';
          _loadingCards = false;
          _loadingQuiz = false;
        });
      }
    } on ApiClientException catch (e) {
      // Typed API errors show the student-friendly message, not the raw error.
      if (mounted) {
        setState(() {
          _errorMessage = e.userFriendlyMessage;
          _loadingCards = false;
          _loadingQuiz = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Strip the "Exception: " prefix for cleaner display.
        final msg = e.toString().replaceAll('Exception: ', '');
        setState(() {
          _errorMessage = msg;
          _loadingCards = false;
          _loadingQuiz = false;
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
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.offWhiteText),
              onPressed: () => Navigator.pop(context),
            ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Study Mode',
              style: TextStyle(
                color: AppTheme.offWhiteText,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            Text(
              'Page ${widget.currentPage + 1}',
              style: TextStyle(
                color: AppTheme.offWhiteText.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: AppTheme.offWhiteText.withValues(alpha: 0.6)),
            tooltip: 'Regenerate',
            onPressed: _generateContent,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          // ── Brand token: indicator = coralAccent ───────────────────────────
          indicatorColor: AppTheme.coralAccent,
          labelColor: AppTheme.offWhiteText,
          unselectedLabelColor: AppTheme.offWhiteText.withValues(alpha: 0.4),
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.style_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('Flashcards'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.quiz_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('Quiz'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _errorMessage != null
          ? _ErrorView(error: _errorMessage!, onRetry: _generateContent)
          : TabBarView(
              controller: _tabController,
              children: [
                // Flashcards tab
                _loadingCards
                    ? const _LoadingView(label: 'Generating flashcards…')
                    : _flashcards.isEmpty
                        ? const _EmptyView(
                            icon: Icons.style_rounded,
                            message: 'No flashcards generated.')
                        : FlashcardWidget(cards: _flashcards),

                // Quiz tab
                _loadingQuiz
                    ? const _LoadingView(label: 'Generating quiz…')
                    : _quizQuestions.isEmpty
                        ? const _EmptyView(
                            icon: Icons.quiz_rounded,
                            message: 'No quiz generated.')
                        : QuizWidget(questions: _quizQuestions),
              ],
            ),
        );
      },
    );
  }
}

// ── Loading View ─────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  final String label;
  const _LoadingView({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Brand token: coralAccent spinner
          const CircularProgressIndicator(color: AppTheme.coralAccent),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.charcoalCard.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty View ───────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyView({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              color: AppTheme.charcoalCard.withValues(alpha: 0.25), size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: AppTheme.charcoalCard.withValues(alpha: 0.45),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error View ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error icon in a charcoalCard container on cream background
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.charcoalCard,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.coralAccent.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                // Brand token: coralAccent for error indicator
                color: AppTheme.coralAccent,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              error.contains('Gemini API key')
                  ? 'API Key Required'
                  : 'Generation Failed',
              style: const TextStyle(
                // Brand token: charcoalCard for headings on cream canvas
                color: AppTheme.charcoalCard,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.charcoalCard.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.charcoalCard.withValues(alpha: 0.12)),
              ),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.charcoalCard.withValues(alpha: 0.65),
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (error.contains('Gemini API key'))
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ApiSettingsScreen(),
                    ),
                  ).then((_) => _generateContent());
                },
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: const Text(
                  'Open Settings',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.coralAccent,
                  foregroundColor: AppTheme.offWhiteText,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                  shadowColor: AppTheme.coralAccent.withValues(alpha: 0.4),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Try Again',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.coralAccent,
                  foregroundColor: AppTheme.offWhiteText,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                  shadowColor: AppTheme.coralAccent.withValues(alpha: 0.4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}