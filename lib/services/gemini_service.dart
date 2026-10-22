// lib/services/gemini_service.dart
//
// TutorPDF — Gemini AI Service (Cloudflare Worker Proxy Architecture)
// ─────────────────────────────────────────────────────────────────────────────
// Routes all AI HTTP requests through Cloudflare Worker proxy at:
// https://tutorpdf-ai-proxy.yoseflire28.workers.dev
// Replaced legacy model initializations ('gemini-1.5-flash-latest', 'gemini-2.5-flash').

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ai_chat_message.dart';
import '../models/study_models.dart';
import 'settings_service.dart';

// ── Exception types ───────────────────────────────────────────────────────────

/// Thrown when the Gemini API / Proxy returns HTTP 429 or a quota-exceeded error.
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

/// Thrown for explicit non-429 HTTP client/server errors (400, 401, 403, 404, 5xx).
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

// ── GeminiService ─────────────────────────────────────────────────────────────

class GeminiService {
  static GeminiService? _instance;
  bool _isInitialized = true;
  final bool _isRateLimited = false;
  Timer? _rateLimitTimer;

  // Endpoint for the Cloudflare Worker proxy
  static const String _proxyUrl =
      'https://tutorpdf-ai-proxy.yoseflire28.workers.dev';

  final SettingsService _settingsService = SettingsService();
  String? _dynamicApiKey;

  GeminiService._internal();

  factory GeminiService() {
    _instance ??= GeminiService._internal();
    return _instance!;
  }

  String? get apiKey => _dynamicApiKey;

  /// Called by ChatProvider or Settings to update API key.
  void setApiKey(String apiKey) {
    _dynamicApiKey = apiKey.trim();
    _isInitialized = true;
    debugPrint(
        '🔑 [GeminiService]: API key updated (${_dynamicApiKey?.length ?? 0} chars).');
  }

  /// Initializes the service.
  Future<void> initialize() async {
    _isInitialized = true;
    debugPrint('✅ [GeminiService]: Initialized using Cloudflare Worker proxy.');
  }

  // ── Core Proxy HTTP Helper ────────────────────────────────────────────────

  /// Truncates document text to 15000 characters to prevent timeout on large contexts.
  String _truncateDocumentText(String text) {
    if (text.length <= 15000) return text;
    debugPrint('📄 [GeminiService]: Truncating document text from ${text.length} to 15000 chars');
    return text.substring(0, 15000) + '\n\n... (content truncated for performance)';
  }

  Future<String> _postToProxy(Map<String, dynamic> body) async {
    final activeKey = await _settingsService.getApiKey() ?? _dynamicApiKey;
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

      debugPrint('🌐 [GeminiService]: Posting payload to proxy: ${body["type"]}');
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

      final responseBodyStr = response.body.toLowerCase();
      final isRateLimit = response.statusCode == 429 ||
          responseBodyStr.contains('quota') ||
          responseBodyStr.contains('rate limit') ||
          responseBodyStr.contains('resource_exhausted') ||
          responseBodyStr.contains('too many requests');

      if (isRateLimit) {
        final retrySecs = _parseRetrySeconds(response.body);
        debugPrint(
            '🚨 [GeminiService]: Proxy rate limit reached (429/quota), retry in ${retrySecs}s');
        throw RateLimitException(
          message: 'Rate limit reached on AI proxy.',
          retryAfterSeconds: retrySecs,
        );
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final resultText = (decoded['result'] ??
                  decoded['response'] ??
                  decoded['text'] ??
                  decoded['content'])
              ?.toString();
          if (resultText != null && resultText.trim().isNotEmpty) {
            debugPrint(
                '✅ [GeminiService]: Received ${resultText.length} chars from proxy.');
            return resultText.trim();
          }
        }
        throw const ApiClientException(
          statusCode: 200,
          message: 'Empty result from AI proxy.',
          userFriendlyMessage:
              'AI proxy returned an empty response. Please try again.',
        );
      } else {
        debugPrint(
            '🚨 [GeminiService]: Proxy HTTP error ${response.statusCode}: ${response.body}');
        throw ApiClientException(
          statusCode: response.statusCode,
          message: 'HTTP ${response.statusCode}: ${response.body}',
          userFriendlyMessage:
              'AI Proxy Error (${response.statusCode}). Please try again later.',
        );
      }
    } on SocketException {
      debugPrint('🚨 [GeminiService]: Network unreachable.');
      throw const ApiClientException(
        statusCode: 0,
        message: 'No internet connection.',
        userFriendlyMessage:
            'Network connection failed. Please check your internet settings.',
      );
    } on TimeoutException {
      debugPrint('🚨 [GeminiService]: Request timed out after 90s');
      throw const ApiClientException(
        statusCode: 408,
        message: 'Request timed out after 90 seconds.',
        userFriendlyMessage:
            'Request timed out. Please try asking a more specific question or retrying.',
      );
    } catch (e) {
      if (e is RateLimitException || e is ApiClientException) rethrow;
      debugPrint('🚨 [GeminiService Exception]: $e');
      throw ApiClientException(
        statusCode: 500,
        message: e.toString(),
        userFriendlyMessage: 'AI Service Error: $e',
      );
    }
  }

  int _parseRetrySeconds(String responseBody) {
    try {
      final regex = RegExp(r'(\d+(?:\.\d+)?)\s*s', caseSensitive: false);
      final match = regex.firstMatch(responseBody);
      if (match != null) {
        final secs = double.tryParse(match.group(1) ?? '');
        if (secs != null && secs > 0) return secs.ceil();
      }
    } catch (_) {}
    return 30;
  }

  // ── JSON Helper ───────────────────────────────────────────────────────────

  /// Strips markdown code fences (e.g. ```json ... ```) and extracts valid JSON block.
  static String _extractJsonString(String response) {
    var cleaned = response.trim();
    cleaned = cleaned.replaceAll(RegExp(r'^```json\s*', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'^```\s*', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'```$', multiLine: true), '');
    cleaned = cleaned.trim();

    final arrayStart = cleaned.indexOf('[');
    final arrayEnd = cleaned.lastIndexOf(']');
    if (arrayStart != -1 && arrayEnd > arrayStart) {
      return cleaned.substring(arrayStart, arrayEnd + 1);
    }

    final objStart = cleaned.indexOf('{');
    final objEnd = cleaned.lastIndexOf('}');
    if (objStart != -1 && objEnd > objStart) {
      return cleaned.substring(objStart, objEnd + 1);
    }

    return cleaned;
  }

  // ── Chat History (Firestore) ──────────────────────────────────────────────

  /// Fetches stored chat history for [documentId] from Firestore.
  Future<List<AiChatMessage>> fetchHistory(int documentId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return [];

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chats')
          .doc(documentId.toString())
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return AiChatMessage(
          documentId: documentId,
          sender: data['sender'] == 'user'
              ? MessageSender.user
              : MessageSender.ai,
          message: data['message']?.toString() ?? '',
          createdAt: data['createdAt']?.toString() ??
              DateTime.now().toIso8601String(),
        );
      }).toList();
    } catch (e) {
      debugPrint('fetchHistory error: $e');
      return [];
    }
  }

  /// Clears stored chat history for [documentId] from Firestore.
  Future<void> clearHistory(int documentId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chats')
          .doc(documentId.toString())
          .collection('messages');

      final batch = FirebaseFirestore.instance.batch();
      final docs = await col.get();
      for (final doc in docs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('clearHistory error: $e');
    }
  }

  // ── Chat Generation ───────────────────────────────────────────────────────

  /// Generates a chat response using Cloudflare Worker proxy.
  /// Payload: `{ "type": "chat", "documentText": context, "userPrompt": prompt }`
  Future<String> generateChatResponse(String prompt, {String? context}) async {
    if (!_isInitialized) await initialize();

    return _postToProxy({
      'type': 'chat',
      'documentText': context ?? '',
      'userPrompt': prompt,
    });
  }

  /// Streams a chat response (emits full response for stream compatibility).
  Stream<String> streamChatResponse({
    required int documentId,
    required String userMessage,
    required String pageContext,
    required List<AiChatMessage> history,
  }) async* {
    if (!_isInitialized) await initialize();

    final responseText =
        await generateChatResponse(userMessage, context: pageContext);

    // Persist to Firestore only when signed in
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && responseText.isNotEmpty) {
      try {
        final col = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('chats')
            .doc(documentId.toString())
            .collection('messages');

        final now = DateTime.now().toIso8601String();
        await col.add(
            {'sender': 'user', 'message': userMessage, 'createdAt': now});
        await col.add({
          'sender': 'ai',
          'message': responseText,
          'createdAt': DateTime.now().toIso8601String()
        });
        debugPrint('✅ [GeminiService]: Chat history persisted to Firestore');
      } catch (firestoreError) {
        debugPrint(
            '⚠️ [GeminiService]: Firestore persistence failed (non-fatal): $firestoreError');
      }
    }

    yield responseText;
  }

  // ── Flashcard Generation ──────────────────────────────────────────────────

  /// Flashcard generation.
  /// Payload: `{ "type": "flashcards", "documentText": content }`
  Future<List<StudyCard>> generateFlashcards(
    String content, {
    int count = 8,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      final response = await _postToProxy({
        'type': 'flashcards',
        'documentText': content,
      });
      return _parseFlashcards(response);
    } catch (e) {
      debugPrint('Flashcard generation error: $e');
      rethrow;
    }
  }

  List<StudyCard> _parseFlashcards(String response) {
    try {
      final jsonString = _extractJsonString(response);
      final dynamic decoded = jsonDecode(jsonString);
      List<dynamic> jsonList = [];
      if (decoded is List) {
        jsonList = decoded;
      } else if (decoded is Map<String, dynamic> &&
          decoded.containsKey('flashcards')) {
        jsonList = decoded['flashcards'] as List;
      } else if (decoded is Map<String, dynamic> &&
          decoded.containsKey('cards')) {
        jsonList = decoded['cards'] as List;
      }

      return jsonList
          .whereType<Map<String, dynamic>>()
          .map((item) => StudyCard.fromMap(item))
          .toList();
    } catch (e) {
      debugPrint('Flashcard parsing error: $e');
      throw const ApiClientException(
        statusCode: 500,
        message: 'Failed to parse flashcards from response',
        userFriendlyMessage:
            'Failed to generate flashcards. Please try again.',
      );
    }
  }

  // ── Quiz Generation ───────────────────────────────────────────────────────

  /// Quiz question generation.
  /// Payload: `{ "type": "quiz", "documentText": content }`
  Future<List<QuizQuestion>> generateQuizQuestions(
    String content, {
    int count = 5,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      final response = await _postToProxy({
        'type': 'quiz',
        'documentText': content,
      });
      return _parseQuizQuestions(response);
    } catch (e) {
      debugPrint('Quiz generation error: $e');
      rethrow;
    }
  }

  List<QuizQuestion> _parseQuizQuestions(String response) {
    try {
      final jsonString = _extractJsonString(response);
      final dynamic decoded = jsonDecode(jsonString);
      List<dynamic> jsonList = [];
      if (decoded is List) {
        jsonList = decoded;
      } else if (decoded is Map<String, dynamic> &&
          decoded.containsKey('questions')) {
        jsonList = decoded['questions'] as List;
      } else if (decoded is Map<String, dynamic> &&
          decoded.containsKey('quiz')) {
        jsonList = decoded['quiz'] as List;
      }

      return jsonList
          .whereType<Map<String, dynamic>>()
          .map((item) => QuizQuestion.fromMap(item))
          .toList();
    } catch (e) {
      debugPrint('Quiz parsing error: $e');
      throw const ApiClientException(
        statusCode: 500,
        message: 'Failed to parse quiz from response',
        userFriendlyMessage: 'Failed to generate quiz. Please try again.',
      );
    }
  }

  // ── Legacy Quiz (raw maps) ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> generateQuiz(
    String content,
    int questionCount,
  ) async {
    final questions =
        await generateQuizQuestions(content, count: questionCount);
    return questions
        .map((q) => {
              'question': q.question,
              'options': q.options.map((o) => o.text).toList(),
              'correctIndex':
                  q.options.indexWhere((o) => o.isCorrect).clamp(0, 3),
            })
        .toList();
  }

  // ── Summary Generation ────────────────────────────────────────────────────

  /// Summary generation.
  /// Payload: `{ "type": "summary", "documentText": content }`
  Future<String> generateSummary(String content) async {
    if (!_isInitialized) await initialize();

    try {
      return await _postToProxy({
        'type': 'summary',
        'documentText': content,
      });
    } catch (e) {
      debugPrint('Summary generation error: $e');
      rethrow;
    }
  }

  // ── Utility & Status ─────────────────────────────────────────────────────

  bool get isRateLimited => _isRateLimited;
  bool get isInitialized => _isInitialized;

  void dispose() {
    _rateLimitTimer?.cancel();
    _rateLimitTimer = null;
  }
}
