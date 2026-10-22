import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/annotation.dart';

class AnnotationService {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<Annotation>> fetchForPage(int documentId, int page) async {
    final db = await _db;
    final rows = await db.query(
      'annotations',
      where: 'document_id = ? AND page_number = ?',
      whereArgs: [documentId, page],
      orderBy: 'created_at ASC',
    );
    return rows.map(Annotation.fromMap).toList();
  }

  Future<List<Annotation>> fetchAllForDocument(int documentId) async {
    final db = await _db;
    final rows = await db.query(
      'annotations',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'page_number ASC, created_at ASC',
    );
    return rows.map(Annotation.fromMap).toList();
  }

  Future<int> addHighlight({
    required int documentId,
    required int pageNumber,
    required String selectedText,
    String colorHex = '#FFFF00',
  }) async {
    final db = await _db;
    return db.insert(
      'annotations',
      Annotation(
        documentId: documentId,
        pageNumber: pageNumber,
        type: AnnotationType.highlight,
        selectedText: selectedText,
        colorHex: colorHex,
        createdAt: DateTime.now().toIso8601String(),
      ).toMap(),
    );
  }

  Future<int> addNote({
    required int documentId,
    required int pageNumber,
    required String noteContent,
    String colorHex = '#FFD700',
  }) async {
    final db = await _db;
    return db.insert(
      'annotations',
      Annotation(
        documentId: documentId,
        pageNumber: pageNumber,
        type: AnnotationType.note,
        noteContent: noteContent,
        colorHex: colorHex,
        createdAt: DateTime.now().toIso8601String(),
      ).toMap(),
    );
  }

  Future<void> updateNote(int id, String newContent) async {
    final db = await _db;
    await db.update(
      'annotations',
      {'note_content': newContent},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAnnotation(int id) async {
    final db = await _db;
    await db.delete('annotations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllForDocument(int documentId) async {
    final db = await _db;
    await db.delete(
      'annotations',
      where: 'document_id = ?',
      whereArgs: [documentId],
    );
  }
}