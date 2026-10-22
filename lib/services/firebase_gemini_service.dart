// lib/services/firebase_gemini_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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

// ── FirebaseGeminiService ─────────────────────────────────────────────────────

class FirebaseGeminiService {
  static FirebaseGeminiService? _instance;
  bool _isInitialized = true;
  bool _isRateLimited = false;
  Timer? _rateLimitTimer;

  // Endpoint for the Cloudflare Worker proxy
  static const String _proxyUrl =
      'https://tutorpdf-ai-proxy.yoseflire28.workers.dev';

  final SettingsService _settingsService = SettingsService();
  String? _dynamicApiKey;
  String? _documentContext;

  FirebaseGeminiService._internal();

  factory FirebaseGeminiService() {
    _instance ??= FirebaseGeminiService._internal();
    return _instance!;
  }

  String? get apiKey => _dynamicApiKey;

  /// Called by ChatProvider or Settings to update API key.
  void setApiKey(String apiKey) {
    _dynamicApiKey = apiKey.trim();
    _isInitialized = true;
    debugPrint(
        '🔑 [FirebaseGeminiService]: API key updated (${_dynamicApiKey?.length ?? 0} chars).');
  }

  void setDocumentContext(String context) {
    _documentContext = context;
  }

  /// Initializes the service.
  Future<void> initialize() async {
    _isInitialized = true;
    debugPrint(
        '✅ [FirebaseGeminiService]: Initialized using Cloudflare Worker proxy.');
  }

  // ── Core Proxy HTTP Helper ────────────────────────────────────────────────

  /// Truncates document text to 15000 characters to prevent timeout on large contexts.
  String _truncateDocumentText(String text) {
    if (text.length <= 15000) return text;
    debugPrint('📄 [FirebaseGeminiService]: Truncating document text from ${text.length} to 15000 chars');
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

      debugPrint(
          '🌐 [FirebaseGeminiService]: Posting payload to proxy: ${body["type"]}');

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
        _startRateLimitTimer(retrySecs);
        debugPrint('🚨 [FirebaseGeminiService]: Proxy rate limit reached (429/quota), retry in ${retrySecs}s');
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
                '✅ [FirebaseGeminiService]: Received ${resultText.length} chars from proxy.');
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
            '🚨 [FirebaseGeminiService]: Proxy HTTP error ${response.statusCode}: ${response.body}');
        throw ApiClientException(
          statusCode: response.statusCode,
          message: 'HTTP ${response.statusCode}: ${response.body}',
          userFriendlyMessage:
              'AI Proxy Error (${response.statusCode}). Please try again later.',
        );
      }
    } on SocketException {
      debugPrint('🚨 [FirebaseGeminiService]: Network unreachable.');
      throw const ApiClientException(
        statusCode: 0,
        message: 'No internet connection.',
        userFriendlyMessage:
            'Network unreachable. Please check your internet connection and try again.',
      );
    } on TimeoutException {
      debugPrint('🚨 [FirebaseGeminiService]: Request timed out after 90s');
      throw const ApiClientException(
        statusCode: 408,
        message: 'Request timed out after 90 seconds.',
        userFriendlyMessage:
            'Request timed out. Please try asking a more specific question or retrying.',
      );
    } catch (e) {
      if (e is RateLimitException || e is ApiClientException) rethrow;
      debugPrint('🚨 [FirebaseGeminiService Exception]: $e');
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

  void _startRateLimitTimer(int seconds) {
    _isRateLimited = true;
    _rateLimitTimer?.cancel();
    _rateLimitTimer = Timer(Duration(seconds: seconds), () {
      _isRateLimited = false;
      _rateLimitTimer = null;
      debugPrint('✅ [FirebaseGeminiService]: Rate limit lifted — ready for new requests.');
    });
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

  // ── AI Response Generation Methods ───────────────────────────────────────

  /// Chat response generation.
  /// Payload: `{ "type": "chat", "documentText": context, "userPrompt": prompt }`
  Future<String> generateResponse(String userPrompt, [String? documentContext]) async {
    if (!_isInitialized) await initialize();
    if (_isRateLimited) {
      throw const RateLimitException(
        message: 'Rate limit exceeded. Please wait before trying again.',
      );
    }
    return _postToProxy({
      'type': 'chat',
      'documentText': documentContext ?? _documentContext ?? '',
      'userPrompt': userPrompt,
    });
  }

  /// Alias method for generateResponse.
  Future<String> generateChatResponse(String prompt, {String? context}) async {
    return generateResponse(prompt, context);
  }

  /// Streams response chunks (emits full response for stream compatibility).
  Stream<String> streamChatResponse(String prompt, {String? context}) async* {
    final responseText = await generateChatResponse(prompt, context: context);
    yield responseText;
  }

  /// Summary generation.
  /// Payload: `{ "type": "summary", "documentText": documentText }`
  Future<String> generateSummary(String documentText) async {
    if (!_isInitialized) await initialize();
    if (_isRateLimited) {
      throw const RateLimitException(message: 'Rate limit exceeded. Please wait.');
    }
    return _postToProxy({
      'type': 'summary',
      'documentText': documentText,
    });
  }

  /// Question generation.
  /// Payload: `{ "type": "questions", "documentText": documentText }`
  Future<String> generateQuestions(String documentText) async {
    if (!_isInitialized) await initialize();
    if (_isRateLimited) {
      throw const RateLimitException(message: 'Rate limit exceeded. Please wait.');
    }
    return _postToProxy({
      'type': 'questions',
      'documentText': documentText,
    });
  }

  /// Quiz generation (returns raw JSON string - use parseQuiz for List).
  /// Payload: `{ "type": "quiz", "documentText": documentText }`
  Future<String> generateQuiz(String documentText) async {
    if (!_isInitialized) await initialize();
    if (_isRateLimited) {
      throw const RateLimitException(message: 'Rate limit exceeded. Please wait.');
    }
    return _postToProxy({
      'type': 'quiz',
      'documentText': documentText,
    });
  }

  /// Parse quiz JSON string into List of Maps.
  List<Map<String, dynamic>> parseQuiz(String response) {
    try {
      final jsonString = _extractJsonString(response);
      final dynamic decoded = jsonDecode(jsonString);
      List<dynamic> jsonList = [];
      if (decoded is List) {
        jsonList = decoded;
      } else if (decoded is Map<String, dynamic> && decoded.containsKey('questions')) {
        jsonList = decoded['questions'] as List;
      } else if (decoded is Map<String, dynamic> && decoded.containsKey('quiz')) {
        jsonList = decoded['quiz'] as List;
      }

      return jsonList
          .whereType<Map<String, dynamic>>()
          .map((item) => {
                'question': item['question']?.toString() ?? '',
                'options': (item['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
                'correctIndex': item['correctIndex'] as int? ?? 0,
              })
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

  /// Flashcards generation (returns raw JSON string - use parseFlashcards for List).
  /// Payload: `{ "type": "flashcards", "documentText": documentText }`
  Future<String> generateFlashcards(String documentText) async {
    if (!_isInitialized) await initialize();
    if (_isRateLimited) {
      throw const RateLimitException(message: 'Rate limit exceeded. Please wait.');
    }
    return _postToProxy({
      'type': 'flashcards',
      'documentText': documentText,
    });
  }

  /// Parse flashcards JSON string into List of Maps.
  List<Map<String, String>> parseFlashcards(String response) {
    try {
      final jsonString = _extractJsonString(response);
      final dynamic decoded = jsonDecode(jsonString);
      List<dynamic> jsonList = [];
      if (decoded is List) {
        jsonList = decoded;
      } else if (decoded is Map<String, dynamic> && decoded.containsKey('flashcards')) {
        jsonList = decoded['flashcards'] as List;
      } else if (decoded is Map<String, dynamic> && decoded.containsKey('cards')) {
        jsonList = decoded['cards'] as List;
      }

      return jsonList
          .whereType<Map<String, dynamic>>()
          .map((item) => {
                'front': item['front']?.toString() ?? '',
                'back': item['back']?.toString() ?? '',
              })
          .toList();
    } catch (e) {
      debugPrint('Flashcard parsing error: $e');
      throw const ApiClientException(
        statusCode: 500,
        message: 'Failed to parse flashcards from response',
        userFriendlyMessage: 'Failed to generate flashcards. Please try again.',
      );
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