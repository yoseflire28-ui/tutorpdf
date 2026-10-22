import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'tutorpdf.db');
    return openDatabase(path, version: 4,
        onCreate: _onCreate, onUpgrade: _onUpgrade, onConfigure: _onConfigure);
  }

  Future<void> _onConfigure(Database db) async {
    // PRAGMA statements that return rows must use rawQuery on Android.
    await db.rawQuery('PRAGMA foreign_keys = ON');
    try {
      await db.rawQuery('PRAGMA journal_mode = WAL');
    } catch (_) {
      // WAL is optional; default journal mode works if unavailable.
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createAllTables(db);
    await _createIndexes(db);
    await _createFTSTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _createIndexes(db);
    if (oldVersion < 3) await _createFTSTables(db);
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE documents ADD COLUMN display_name TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE documents ADD COLUMN file_extension TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE documents ADD COLUMN mime_type TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE documents ADD COLUMN uri_string TEXT');
      } catch (_) {}

      try {
        await db.execute('UPDATE documents SET display_name = file_name WHERE display_name IS NULL');
        await db.execute('UPDATE documents SET file_extension = file_type WHERE file_extension IS NULL');
        await db.execute('UPDATE documents SET uri_string = file_path WHERE uri_string IS NULL');
        await db.execute("UPDATE documents SET mime_type = '' WHERE mime_type IS NULL");
      } catch (_) {}
    }
  }

  Future<void> _createAllTables(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS documents (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      display_name TEXT,
      file_name TEXT NOT NULL,
      file_extension TEXT,
      file_type TEXT NOT NULL,
      mime_type TEXT,
      uri_string TEXT,
      file_path TEXT NOT NULL UNIQUE,
      total_pages INTEGER DEFAULT 0,
      current_page INTEGER DEFAULT 0,
      is_favorite INTEGER DEFAULT 0,
      last_opened TEXT NOT NULL
    )''');

    await db.execute('''CREATE TABLE IF NOT EXISTS bookmarks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      document_id INTEGER NOT NULL,
      page_number INTEGER NOT NULL,
      label TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE,
      UNIQUE(document_id, page_number)
    )''');

    await db.execute('''CREATE TABLE IF NOT EXISTS annotations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      document_id INTEGER NOT NULL,
      page_number INTEGER NOT NULL,
      type TEXT NOT NULL CHECK(type IN ('highlight', 'note')),
      selected_text TEXT,
      note_content TEXT,
      color_hex TEXT DEFAULT '#FFFF00',
      created_at TEXT NOT NULL,
      FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
    )''');

    await db.execute('''CREATE TABLE IF NOT EXISTS ai_chat_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      document_id INTEGER NOT NULL,
      sender TEXT NOT NULL CHECK(sender IN ('user', 'ai')),
      message TEXT NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
    )''');

    await db.execute('''CREATE TABLE IF NOT EXISTS reading_analytics (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      document_id INTEGER NOT NULL,
      date TEXT NOT NULL,
      time_spent_seconds INTEGER DEFAULT 0,
      pages_read INTEGER DEFAULT 0,
      FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE,
      UNIQUE(document_id, date)
    )''');
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_documents_last_opened ON documents(last_opened DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_bookmarks_document_id ON bookmarks(document_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_annotations_document_id ON annotations(document_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_chat_document_id ON ai_chat_history(document_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_analytics_document_id ON reading_analytics(document_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_analytics_date ON reading_analytics(date)');
  }

  Future<bool> _isFts5Supported(Database db) async {
    try {
      await db.execute('CREATE VIRTUAL TABLE temp.fts5_test USING fts5(val)');
      await db.execute('DROP TABLE temp.fts5_test');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _isFts5Table(Database db, String tableName) async {
    try {
      final List<Map<String, dynamic>> result = await db.rawQuery(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
        [tableName],
      );
      if (result.isNotEmpty) {
        final sql = result.first['sql'] as String;
        return sql.toLowerCase().contains('using fts5');
      }
    } catch (_) {}
    return false;
  }

  Future<void> _createFTSTables(Database db) async {
    final hasFts5 = await _isFts5Supported(db);
    if (hasFts5) {
      await db.execute('''CREATE VIRTUAL TABLE IF NOT EXISTS documents_fts USING fts5(
        document_id UNINDEXED, file_name, page_number UNINDEXED, page_content
      )''');
    } else {
      await db.execute('''CREATE VIRTUAL TABLE IF NOT EXISTS documents_fts USING fts4(
        document_id, file_name, page_number, page_content,
        notindexed=document_id,
        notindexed=page_number
      )''');
    }
  }

  Future<void> insertFTSContent({required int documentId, required int pageNumber,
      required String content, required String fileName}) async {
    final db = await database;
    await db.insert('documents_fts', {
      'document_id': documentId, 'file_name': fileName,
      'page_number': pageNumber, 'page_content': content,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> ftsSearch(
      {required int documentId, required String query}) async {
    final db = await database;
    final isFts5 = await _isFts5Table(db, 'documents_fts');
    if (isFts5) {
      return db.rawQuery('''
        SELECT document_id, page_number,
               snippet(documents_fts, 3, '<b>', '</b>', '...', 20) AS snippet
        FROM documents_fts
        WHERE documents_fts MATCH ? AND document_id = ?
        ORDER BY rank''', [query, documentId]);
    } else {
      return db.rawQuery('''
        SELECT document_id, page_number,
               snippet(documents_fts, '<b>', '</b>', '...', 3, 20) AS snippet
        FROM documents_fts
        WHERE documents_fts MATCH ? AND document_id = ?''', [query, documentId]);
    }
  }

  Future<void> deleteFTSForDocument(int documentId) async {
    final db = await database;
    await db.delete('documents_fts', where: 'document_id = ?', whereArgs: [documentId]);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) { await db.close(); _database = null; }
  }
}