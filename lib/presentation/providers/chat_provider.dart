import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/document.dart';
import '../../services/firebase_gemini_service.dart';
import '../../services/text_extraction_service.dart';
import '../../services/settings_service.dart';

class ChatMessage {
  final String sender;
  final String content;
  final String timestamp;

  ChatMessage({
    String? sender,
    String? content,
    String? text,
    bool? isUser,
    String? timestamp,
  })  : sender = sender ?? ((isUser ?? true) ? 'user' : 'ai'),
        content = content ?? text ?? '',
        timestamp = timestamp ?? DateTime.now().toIso8601String();

  bool get isUser => sender == 'user';
  String get text => content;

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      sender: data['sender'] as String? ?? 'unknown',
      content: data['content'] as String? ?? '',
      timestamp: data['timestamp'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender': sender,
      'content': content,
      'timestamp': timestamp,
    };
  }
}

class ChatSession {
  final String sessionId;
  final String documentId;
  final String documentName;
  final String createdAt;
  final String lastUpdated;

  ChatSession({
    required this.sessionId,
    required this.documentId,
    required this.documentName,
    required this.createdAt,
    required this.lastUpdated,
  });

  factory ChatSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatSession(
      sessionId: doc.id,
      documentId: data['documentId'] as String? ?? '',
      documentName: data['documentName'] as String? ?? '',
      createdAt: data['createdAt'] as String? ?? '',
      lastUpdated: data['lastUpdated'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'documentId': documentId,
      'documentName': documentName,
      'createdAt': createdAt,
      'lastUpdated': lastUpdated,
    };
  }
}

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseGeminiService _geminiService = FirebaseGeminiService();
  final TextExtractionService _textExtractionService = TextExtractionService();
  final SettingsService _settingsService = SettingsService();

  StreamSubscription<QuerySnapshot>? _messagesSubscription;

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _currentSessionId;
  Document? _currentDocument;
  String? _errorMessage;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  set isLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String? get currentSessionId => _currentSessionId;
  Document? get currentDocument => _currentDocument;
  String? get errorMessage => _errorMessage;
  bool get hasMessages => _messages.isNotEmpty;

  // Null when user is not signed in — safe to check before any Firestore call
  String? get _userId => _auth.currentUser?.uid;
  bool get _isSignedIn => _userId != null;

  ChatProvider() {
    _auth.authStateChanges().listen((user) {
      if (user == null) {
        // On sign-out: clear remote state but keep local messages in-memory
        _currentSessionId = null;
        _messagesSubscription?.cancel();
        // Don't clear _messages so the user can still see the conversation
        notifyListeners();
      }
    });
    _initializeGeminiService();
  }

  Future<void> _initializeGeminiService() async {
    try {
      final apiKey = await _settingsService.getApiKey();
      if (apiKey != null && apiKey.isNotEmpty) {
        _geminiService.setApiKey(apiKey);
      }
    } catch (e) {
      debugPrint('⚠️ [ChatProvider]: Failed to load API key: $e');
    }
  }

  // ── Initialize Chat ────────────────────────────────────────────────────────
  //
  // Works in two modes:
  //   • Guest / unauthenticated → local in-memory only, no Firestore
  //   • Signed-in               → Firestore persistence with real-time sync

  Future<void> initializeChat(Document document, {String? extractedText}) async {
    // Reset state for new document
    _currentDocument = document;
    if (extractedText != null && extractedText.isNotEmpty) {
      _geminiService.setDocumentContext(extractedText);
    }
    _errorMessage = null;
    _messages = [];
    _isLoading = false;
    notifyListeners();

    if (!_isSignedIn) {
      // ── GUEST MODE: skip all Firestore, chat lives in-memory ──────────────
      debugPrint('👤 [ChatProvider]: Guest user — using local in-memory chat mode.');
      _currentSessionId = null;
      notifyListeners();
      return;
    }

    // ── SIGNED-IN MODE: use Firestore ─────────────────────────────────────
    try {
      final sessionsQuery = _firestore
          .collection('users')
          .doc(_userId)
          .collection('chats')
          .where('documentId', isEqualTo: document.id.toString())
          .orderBy('lastUpdated', descending: true)
          .limit(1);

      final sessionsSnapshot = await sessionsQuery.get();

      if (sessionsSnapshot.docs.isNotEmpty) {
        _currentSessionId = sessionsSnapshot.docs.first.id;
      } else {
        final now = DateTime.now().toIso8601String();
        final sessionRef = await _firestore
            .collection('users')
            .doc(_userId)
            .collection('chats')
            .add({
          'documentId': document.id.toString(),
          'documentName': document.fileName,
          'createdAt': now,
          'lastUpdated': now,
        });
        _currentSessionId = sessionRef.id;
      }

      await _loadChatHistoryFromFirestore(_currentSessionId!);
    } catch (e) {
      // Firestore failure → fall back to local mode gracefully
      _errorMessage = null; // Don't show an error — just work locally
      _currentSessionId = null;
      debugPrint('⚠️ [ChatProvider]: Firestore init failed ($e) — falling back to local mode.');
      notifyListeners();
    }
  }

  // Load chat history from Firestore with real-time updates
  Future<void> _loadChatHistoryFromFirestore(String sessionId) async {
    _isLoading = true;
    notifyListeners();

    await _messagesSubscription?.cancel();

    try {
      final messagesRef = _firestore
          .collection('users')
          .doc(_userId)
          .collection('chats')
          .doc(sessionId)
          .collection('messages')
          .orderBy('timestamp', descending: false);

      _messagesSubscription = messagesRef.snapshots().listen(
        (snapshot) {
          _messages = snapshot.docs
              .map((doc) => ChatMessage.fromFirestore(doc))
              .toList();
          _isLoading = false;
          notifyListeners();
        },
        onError: (error) {
          // Stream error — fall back to local mode (keep existing messages)
          debugPrint('⚠️ [ChatProvider]: Firestore stream error ($error) — switching to local mode.');
          _isLoading = false;
          _currentSessionId = null;
          notifyListeners();
        },
      );
    } catch (e) {
      _isLoading = false;
      _currentSessionId = null;
      debugPrint('⚠️ [ChatProvider]: Firestore load error ($e) — using local mode.');
      notifyListeners();
    }
  }

  // ── Public alias kept for backward compat ─────────────────────────────────
  Future<void> loadChatHistory(String sessionId) => _loadChatHistoryFromFirestore(sessionId);

  // ── Send Message ───────────────────────────────────────────────────────────
  //
  // Always adds messages to the local list for instant UI feedback.
  // Only persists to Firestore when signed in AND a sessionId exists.

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_isLoading) return; // Prevent double-send

    _isLoading = true;
    _errorMessage = null;

    final userMessage = text.trim();
    final userMsg = ChatMessage(text: userMessage, isUser: true);

    // Immediately add to local list for instant UI feedback
    _messages.add(userMsg);
    notifyListeners();

    try {
      // Check for Gemini API key before proceeding
      final apiKey = await _settingsService.getApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        _messages.add(ChatMessage(
          text: 'Add your Gemini API key in Settings to use AI features',
          isUser: false,
        ));
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Initialize Gemini service if not already done
      if (!_geminiService.isInitialized) {
        await _geminiService.initialize();
      }

      // Persist user message to Firestore only when authenticated
      if (_isSignedIn && _currentSessionId != null) {
        _persistMessageToFirestore(userMsg, _currentSessionId!);
      }

      // Extract text from the document for context
      String? documentText;
      if (_currentDocument != null) {
        try {
          debugPrint('📄 [ChatProvider]: Extracting text from: ${_currentDocument!.fileName}');
          final extracted =
              await _textExtractionService.extractText(_currentDocument!.filePath);
          if (extracted.isNotEmpty) {
            final truncated = extracted.length > 15000
                ? '${extracted.substring(0, 15000)}\n\n... (content truncated for performance)'
                : extracted;
            documentText =
                'Document: ${_currentDocument!.fileName}\n\nContent:\n$truncated';
            debugPrint('✅ [ChatProvider]: Extracted ${extracted.length} chars');
          } else {
            debugPrint('⚠️ [ChatProvider]: Text extraction returned empty');
          }
        } catch (e) {
          debugPrint('⚠️ [ChatProvider]: Text extraction failed: $e');
        }
      }

      // Call Gemini and handle response
      try {
        final reply = await _geminiService.generateResponse(userMessage, documentText);
        final aiMsg = ChatMessage(
          text: reply.isNotEmpty
              ? reply
              : 'AI returned an empty response. Please try again.',
          isUser: false,
        );
        _messages.add(aiMsg);

        // Persist AI response to Firestore only when authenticated
        if (_isSignedIn && _currentSessionId != null) {
          _persistMessageToFirestore(aiMsg, _currentSessionId!);
        }
      } on ApiClientException catch (e) {
        // Handle specific API errors with user-friendly messages
        String userMessage;
        if (e.statusCode == 408) {
          userMessage = '⏱️ Request timed out. Please try asking a more specific question or retrying.';
        } else if (e.statusCode == 429) {
          userMessage = '🚦 Rate limit reached. Please wait a moment and try again.';
        } else if (e.statusCode == 0) {
          userMessage = '🔌 Network connection failed. Please check your internet and try again.';
        } else if (e.userFriendlyMessage.contains('Gemini API key')) {
          userMessage = e.userFriendlyMessage;
        } else {
          userMessage = '⚠️ AI Error: ${e.userFriendlyMessage}';
        }
        
        _messages.add(ChatMessage(
          text: userMessage,
          isUser: false,
        ));
        debugPrint('🚨 [ChatProvider]: API error (${e.statusCode}): ${e.message}');
      } catch (e) {
        // Surface other AI errors as a visible error bubble
        _messages.add(ChatMessage(
          text: '⚠️ AI Error: $e',
          isUser: false,
        ));
        debugPrint('🚨 [ChatProvider]: Gemini error: $e');
      }
    } catch (e, stackTrace) {
      debugPrint('🚨 [ChatProvider Exception]: $e\n$stackTrace');
      _messages.add(ChatMessage(
        text: '⚠️ Error: $e',
        isUser: false,
      ));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Firestore Helpers (fire-and-forget) ────────────────────────────────────

  void _persistMessageToFirestore(ChatMessage msg, String sessionId) {
    if (_userId == null) return;
    _firestore
        .collection('users')
        .doc(_userId)
        .collection('chats')
        .doc(sessionId)
        .collection('messages')
        .add(msg.toMap())
        .then((_) {
      _firestore
          .collection('users')
          .doc(_userId)
          .collection('chats')
          .doc(sessionId)
          .update({'lastUpdated': msg.timestamp})
          .catchError((e) => debugPrint('Firestore update lastUpdated failed: $e'));
    }).catchError((e) => debugPrint('Firestore message save failed: $e'));
  }

  // ── Delete Specific Message ────────────────────────────────────────────────

  Future<void> deleteMessage(int index) async {
    if (index < 0 || index >= _messages.length) return;
    final message = _messages[index];

    _messages.removeAt(index);
    notifyListeners();

    if (_isSignedIn && _currentSessionId != null) {
      try {
        final messagesRef = _firestore
            .collection('users')
            .doc(_userId)
            .collection('chats')
            .doc(_currentSessionId!)
            .collection('messages')
            .where('sender', isEqualTo: message.sender)
            .where('content', isEqualTo: message.content)
            .where('timestamp', isEqualTo: message.timestamp);

        final snapshot = await messagesRef.get();
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('Delete single message error: $e');
      }
    }
  }

  // ── Regenerate Last Response ───────────────────────────────────────────────

  Future<void> regenerateLastResponse() async {
    if (_messages.isEmpty) return;

    String? lastUserPrompt;
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].sender == 'user') {
        lastUserPrompt = _messages[i].content;
        break;
      }
    }
    if (lastUserPrompt == null) return;

    if (_messages.isNotEmpty && _messages.last.sender == 'ai') {
      await deleteMessage(_messages.length - 1);
    }
    await sendMessage(lastUserPrompt);
  }

  // ── Clear Chat ─────────────────────────────────────────────────────────────

  Future<void> clearChat() async {
    _messages.clear();
    notifyListeners();

    if (_isSignedIn && _currentSessionId != null) {
      try {
        final messagesRef = _firestore
            .collection('users')
            .doc(_userId)
            .collection('chats')
            .doc(_currentSessionId)
            .collection('messages');

        final snapshot = await messagesRef.get();
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('Clear chat Firestore error (non-fatal): $e');
      }
    }
  }

  // ── Delete Session ─────────────────────────────────────────────────────────

  Future<void> deleteSession() async {
    if (_isSignedIn && _currentSessionId != null) {
      try {
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('chats')
            .doc(_currentSessionId)
            .delete();
      } catch (e) {
        debugPrint('Delete session Firestore error (non-fatal): $e');
      }
    }

    _messages.clear();
    _currentSessionId = null;
    _currentDocument = null;
    await _messagesSubscription?.cancel();
    notifyListeners();
  }

  // ── Get All Sessions (signed-in only) ─────────────────────────────────────

  Future<List<ChatSession>> getAllSessions() async {
    if (!_isSignedIn) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('chats')
          .orderBy('lastUpdated', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ChatSession.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Load sessions error (non-fatal): $e');
      return [];
    }
  }

  // ── Load Session ───────────────────────────────────────────────────────────

  Future<void> loadSession(String sessionId) async {
    if (!_isSignedIn) return;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('chats')
          .doc(sessionId)
          .get();

      if (doc.exists) {
        final session = ChatSession.fromFirestore(doc);
        _currentSessionId = sessionId;
        _currentDocument = Document(
          id: session.documentId,
          displayName: session.documentName,
          fileExtension: 'pdf',
          mimeType: 'application/pdf',
          uriString: '',
          lastOpened: DateTime.now().toIso8601String(),
        );
        await _loadChatHistoryFromFirestore(sessionId);
      }
    } catch (e) {
      debugPrint('Load session error (non-fatal): $e');
    }
  }

  // ── Utility ────────────────────────────────────────────────────────────────

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    super.dispose();
  }
}
