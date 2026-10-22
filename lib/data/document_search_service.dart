import '../database/database_helper.dart';
import '../models/document.dart';

class DocumentSearchService {
  Future<List<Document>> searchDocuments({required String query}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return _fetchAll();
    }

    final db = await DatabaseHelper.instance.database;
    final sanitized = trimmed.replaceAll(RegExp(r"[^a-zA-Z0-9\s]"), ' ').trim();
    final searchQuery = sanitized.isEmpty ? trimmed : sanitized;

    final rows = await db.rawQuery('''
      SELECT DISTINCT d.*
      FROM documents d
      LEFT JOIN documents_fts fts ON d.id = fts.document_id
      WHERE d.file_name LIKE ?
         OR fts.page_content MATCH ?
      ORDER BY d.last_opened DESC
    ''', ['%$searchQuery%', '$searchQuery*']);

    return rows.map(Document.fromMap).toList();
  }

  Future<List<Document>> _fetchAll() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('documents', orderBy: 'last_opened DESC');
    return rows.map(Document.fromMap).toList();
  }
}
