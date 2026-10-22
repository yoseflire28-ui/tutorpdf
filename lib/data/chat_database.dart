import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ChatMessage {
  final int? id;
  final String sessionId;
  final String sender;
  final String content;
  final String timestamp;

  ChatMessage({
    this.id,
    required this.sessionId,
    required this.sender,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'sender': sender,
      'content': content,
      'timestamp': timestamp,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as int?,
      sessionId: map['session_id'] as String,
      sender: map['sender'] as String,
      content: map['content'] as String,
      timestamp: map['timestamp'] as String,
    );
  }
}

class ChatSession {
  final int? id;
  final String sessionId;
  final String documentId;
  final String documentName;
  final String createdAt;
  final String lastUpdated;

  ChatSession({
    this.id,
    required this.sessionId,
    required this.documentId,
    required this.documentName,
    required this.createdAt,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'document_id': documentId,
      'document_name': documentName,
      'created_at': createdAt,
      'last_updated': lastUpdated,
    };
  }

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'] as int?,
      sessionId: map['session_id'] as String,
      documentId: map['document_id'] as String,
      documentName: map['document_name'] as String,
      createdAt: map['created_at'] as String,
      lastUpdated: map['last_updated'] as String,
    );
  }
}

class ChatDatabase {
  static final ChatDatabase _instance = ChatDatabase._internal();
  static Database? _database;

  factory ChatDatabase() {
    return _instance;
  }

  ChatDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'tutor_chat.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create chat_sessions table
    await db.execute('''
      CREATE TABLE chat_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL UNIQUE,
        document_id TEXT NOT NULL,
        document_name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        last_updated TEXT NOT NULL
      )
    ''');

    // Create chat_messages table
    await db.execute('''
      CREATE TABLE chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        sender TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES chat_sessions (session_id) ON DELETE CASCADE
      )
    ''');

    // Create index for faster queries
    await db.execute('''
      CREATE INDEX idx_messages_session_id 
      ON chat_messages(session_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_timestamp 
      ON chat_messages(timestamp)
    ''');
  }

  // Session Operations
  Future<String> createSession(String documentId, String documentName) async {
    final db = await database;
    final sessionId = '${documentId}_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();

    await db.insert(
      'chat_sessions',
      {
        'session_id': sessionId,
        'document_id': documentId,
        'document_name': documentName,
        'created_at': now,
        'last_updated': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return sessionId;
  }

  Future<ChatSession?> getSession(String sessionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_sessions',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );

    if (maps.isEmpty) return null;
    return ChatSession.fromMap(maps.first);
  }

  Future<List<ChatSession>> getAllSessions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_sessions',
      orderBy: 'last_updated DESC',
    );

    return maps.map((map) => ChatSession.fromMap(map)).toList();
  }

  Future<void> updateSessionTimestamp(String sessionId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'chat_sessions',
      {'last_updated': now},
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> deleteSession(String sessionId) async {
    final db = await database;
    await db.delete(
      'chat_messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    await db.delete(
      'chat_sessions',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  // Message Operations
  Future<int> saveMessage(String sessionId, String sender, String content) async {
    final db = await database;
    final timestamp = DateTime.now().toIso8601String();

    // Update session timestamp
    await updateSessionTimestamp(sessionId);

    return await db.insert(
      'chat_messages',
      {
        'session_id': sessionId,
        'sender': sender,
        'content': content,
        'timestamp': timestamp,
      },
    );
  }

  Future<List<ChatMessage>> getMessages(String sessionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );

    return maps.map((map) => ChatMessage.fromMap(map)).toList();
  }

  Future<List<ChatMessage>> getRecentMessages(String sessionId, {int limit = 50}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    final messages = maps.map((map) => ChatMessage.fromMap(map)).toList();
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  Future<void> deleteMessage(int messageId) async {
    final db = await database;
    await db.delete(
      'chat_messages',
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> clearSessionMessages(String sessionId) async {
    final db = await database;
    await db.delete(
      'chat_messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  // Utility Operations
  Future<int> getMessageCount(String sessionId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM chat_messages WHERE session_id = ?',
      [sessionId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('chat_messages');
    await db.delete('chat_sessions');
  }
}
