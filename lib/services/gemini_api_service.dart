// lib/services/gemini_api_service.dart
//
// TutorPDF — Gemini API Service (Cloudflare Worker Proxy)
// ─────────────────────────────────────────────────────────────────────────────
// Routes all HTTP requests through Cloudflare Worker proxy at:
// https://tutorpdf-ai-proxy.yoseflire28.workers.dev
// Replaced direct google_generative_ai SDK initializations to prevent HTTP 404 errors.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/app_theme.dart';
import 'settings_service.dart';

// ── Exception types ───────────────────────────────────────────────────────────

/// Thrown when the Gemini API / Proxy signals HTTP 429 / quota-exceeded.
class RateLimitException implements Exception {
  final String message;
  final int retryAfterSeconds;

  const RateLimitException({
    required this.message,
    this.retryAfterSeconds = 60,
  });

  @override
  String toString() =>
      'RateLimitException: $message (retry in ${retryAfterSeconds}s)';
}

/// Thrown when the API returns an explicit client error (e.g. 404 model-not-found, 400 bad-request, 401/403 auth failure).
class ApiClientException implements Exception {
  final int statusCode;
  final String message;
  final String userFriendlyMessage;

  const ApiClientException({
    required this.statusCode,
    required this.message,
    required this.userFriendlyMessage,
  });

  @override
  String toString() => 'ApiClientException($statusCode): $message';
}

// ── GeminiApiService ──────────────────────────────────────────────────────────

class GeminiApiService {
  static const String _proxyUrl =
      'https://tutorpdf-ai-proxy.yoseflire28.workers.dev';

  final SettingsService _settingsService = SettingsService();
  Timer? _rateLimitTimer;
  int _retryAfterSeconds = 60;
  bool _isRateLimited = false;
  String? _apiKey;

  void setApiKey(String apiKey) {
    _apiKey = apiKey;
    debugPrint('🔑 [GeminiApiService]: API key updated (${_apiKey?.length ?? 0} chars).');
  }

  // ── Core Proxy HTTP Helper ────────────────────────────────────────────────

  /// Truncates document text to 15000 characters to prevent timeout on large contexts.
  String _truncateDocumentText(String text) {
    if (text.length <= 15000) return text;
    debugPrint('📄 [GeminiApiService]: Truncating document text from ${text.length} to 15000 chars');
    return text.substring(0, 15000) + '\n\n... (content truncated for performance)';
  }

  Future<String> _postToProxy(Map<String, dynamic> body) async {
    final activeKey = await _settingsService.getApiKey() ?? _apiKey;
    if (activeKey == null || activeKey.trim().isEmpty) {
      throw const ApiClientException(
        statusCode: 401,
        message: 'No Gemini API key configured',
        userFriendlyMessage:
            'Add your Gemini API key in Settings to use AI features',
      );
    }

    try {
      // Truncate documentText if present to prevent timeouts
      if (body.containsKey('documentText') && body['documentText'] is String) {
        final docText = body['documentText'] as String;
        body['documentText'] = _truncateDocumentText(docText);
      }

      debugPrint(
          '🌐 [GeminiApiService]: Posting payload to proxy: ${body["type"]}');
      final response = await http
          .post(
            Uri.parse(_proxyUrl),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': activeKey,
              'Authorization': 'Bearer $activeKey',
            },
            body: jsonEncode({
              ...body,
              'apiKey': activeKey,
            }),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final resultText = (decoded['result'] ??
                  decoded['response'] ??
                  decoded['text'] ??
                  decoded['content'])
              ?.toString();
          if (resultText != null && resultText.trim().isNotEmpty) {
            return resultText.trim();
          }
        }
        throw const ApiClientException(
          statusCode: 200,
          message: 'Empty response from AI proxy.',
          userFriendlyMessage:
              'AI proxy returned an empty response. Please try again.',
        );
      } else if (response.statusCode == 429) {
        _startRateLimitTimer(30);
        throw const RateLimitException(
          message: 'Rate limit reached on AI proxy.',
          retryAfterSeconds: 30,
        );
      } else {
        throw ApiClientException(
          statusCode: response.statusCode,
          message: 'HTTP ${response.statusCode}: ${response.body}',
          userFriendlyMessage:
              'AI Proxy Error (${response.statusCode}). Please try again later.',
        );
      }
    } on TimeoutException {
      throw const ApiClientException(
        statusCode: 408,
        message: 'Request timed out after 90 seconds.',
        userFriendlyMessage:
            'Request timed out. Please try asking a more specific question or retrying.',
      );
    } catch (e) {
      if (e is RateLimitException || e is ApiClientException) rethrow;
      throw ApiClientException(
        statusCode: 500,
        message: e.toString(),
        userFriendlyMessage: 'AI service error. Please try again.',
      );
    }
  }

  // ── JSON Helper ───────────────────────────────────────────────────────────

  dynamic _parseJsonSafely(String jsonString) {
    try {
      var cleanJson = jsonString.trim();
      cleanJson =
          cleanJson.replaceAll(RegExp(r'^```json\s*', multiLine: true), '');
      cleanJson = cleanJson.replaceAll(RegExp(r'^```\s*', multiLine: true), '');
      cleanJson = cleanJson.replaceAll(RegExp(r'```$', multiLine: true), '');
      cleanJson = cleanJson.trim();

      final arrayStart = cleanJson.indexOf('[');
      final arrayEnd = cleanJson.lastIndexOf(']');
      if (arrayStart != -1 && arrayEnd > arrayStart) {
        cleanJson = cleanJson.substring(arrayStart, arrayEnd + 1);
      }

      return const JsonDecoder().convert(cleanJson);
    } catch (e) {
      debugPrint('TutorPDF ✖ JSON parse error: $e');
      return [];
    }
  }

  // ── Rate Limit UI / Timer ────────────────────────────────────────────────

  Stream<int> getRateLimitCountdown() async* {
    while (_rateLimitTimer != null && _rateLimitTimer!.isActive) {
      yield _retryAfterSeconds;
      await Future.delayed(const Duration(seconds: 1));
      _retryAfterSeconds--;
    }
  }

  void _startRateLimitTimer(int seconds) {
    _retryAfterSeconds = seconds;
    _isRateLimited = true;
    _rateLimitTimer?.cancel();
    _rateLimitTimer = Timer(Duration(seconds: seconds), () {
      _rateLimitTimer = null;
      _isRateLimited = false;
    });
  }

  bool get isRateLimited => _isRateLimited;

  // ── Chat Streaming ──────────────────────────────────────────────────────

  Stream<String> streamChatResponse({
    required String userMessage,
    required String pageContext,
    required List<Map<String, dynamic>> history,
  }) async* {
    if (_isRateLimited) {
      throw RateLimitException(
        message: 'Rate limit in effect. Please wait.',
        retryAfterSeconds: _retryAfterSeconds,
      );
    }

    final responseText = await _postToProxy({
      'type': 'chat',
      'documentText': pageContext,
      'userPrompt': userMessage,
    });

    yield responseText;
  }

  // ── Flashcard Generation ────────────────────────────────────────────────

  Future<List<Map<String, String>>> generateFlashcards(
    String textChunk, {
    int count = 8,
    bool isFallbackAttempt = false,
  }) async {
    if (_isRateLimited) {
      throw RateLimitException(
        message: 'Rate limit in effect. Please wait.',
        retryAfterSeconds: _retryAfterSeconds,
      );
    }

    final prompt = 'Generate $count flashcards from the following text. '
        'Return a JSON array where each item has "front" and "back" string fields.\n\n'
        'Text: $textChunk';

    try {
      final responseText = await _postToProxy({
        'type': 'flashcards',
        'documentText': textChunk,
        'userPrompt': prompt,
      });

      final parsed = _parseJsonSafely(responseText) as List;
      return parsed
          .map((e) => {
                'front': e['front']?.toString() ?? '',
                'back': e['back']?.toString() ?? '',
              })
          .toList();
    } catch (e) {
      debugPrint('TutorPDF ✖ generateFlashcards error: $e');
      if (e is RateLimitException || e is ApiClientException) rethrow;
      return [];
    }
  }

  // ── Quiz Question Generation ────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> generateQuizQuestions(
    String textChunk, {
    int count = 5,
    bool isFallbackAttempt = false,
  }) async {
    if (_isRateLimited) {
      throw RateLimitException(
        message: 'Rate limit in effect. Please wait.',
        retryAfterSeconds: _retryAfterSeconds,
      );
    }

    final prompt =
        'Generate $count multiple choice quiz questions from the following text. '
        'Return a JSON array where each item has a "question" string and an '
        '"options" array with objects containing "text" (string) and '
        '"isCorrect" (boolean) fields.\n\nText: $textChunk';

    try {
      final responseText = await _postToProxy({
        'type': 'quiz',
        'documentText': textChunk,
        'userPrompt': prompt,
      });

      final parsed = _parseJsonSafely(responseText) as List;
      return parsed
          .map((e) => {
                'question': e['question']?.toString() ?? '',
                'options': (e['options'] as List?)
                        ?.map((opt) => {
                              'text': opt['text']?.toString() ?? '',
                              'isCorrect': opt['isCorrect'] == true,
                            })
                        .toList() ??
                    [],
              })
          .toList();
    } catch (e) {
      debugPrint('TutorPDF ✖ generateQuizQuestions error: $e');
      if (e is RateLimitException || e is ApiClientException) rethrow;
      return [];
    }
  }

  // ── Summary Generation ──────────────────────────────────────────────────

  Future<String> generateSummary(
    String textChunk, {
    bool isFallbackAttempt = false,
  }) async {
    if (_isRateLimited) {
      throw RateLimitException(
        message: 'Rate limit in effect. Please wait.',
        retryAfterSeconds: _retryAfterSeconds,
      );
    }

    final prompt = 'Generate a concise summary of the following text. '
        'Focus on key points and main ideas.\n\nText: $textChunk';

    try {
      return await _postToProxy({
        'type': 'summary',
        'documentText': textChunk,
        'userPrompt': prompt,
      });
    } catch (e) {
      debugPrint('TutorPDF ✖ generateSummary error: $e');
      if (e is RateLimitException || e is ApiClientException) rethrow;
      return 'Error generating summary. Please try again.';
    }
  }

  // ── Rate Limit UI Widget ────────────────────────────────────────────────

  static Widget buildRateLimitBanner({
    required int remainingSeconds,
    required VoidCallback onDismiss,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.charcoalCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.coralAccent.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.coralAccent.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.coralAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.timer_outlined,
                  color: AppTheme.coralAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rate Limit Reached',
                      style: TextStyle(
                        color: AppTheme.offWhiteText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "You've sent a lot of requests. The AI needs a short break.",
                      style: TextStyle(
                        color: AppTheme.offWhiteText.withValues(alpha: 0.55),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.coralAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.coralAccent.withValues(alpha: 0.18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.refresh_rounded,
                  color: AppTheme.coralAccent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Retry in ',
                  style: TextStyle(
                    color: AppTheme.offWhiteText,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${remainingSeconds}s',
                  style: const TextStyle(
                    color: AppTheme.coralAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onDismiss,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.offWhiteText.withValues(alpha: 0.5),
            ),
            child: const Text('Dismiss', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ── Cleanup ─────────────────────────────────────────────────────────────

  void dispose() {
    _rateLimitTimer?.cancel();
  }
}
