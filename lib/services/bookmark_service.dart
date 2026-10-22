import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/bookmark.dart';

class BookmarkService {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<Bookmark>> fetchForDocument(int documentId) async {
    final db = await _db;
    final rows = await db.query(
      'bookmarks',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'page_number ASC',
    );
    return rows.map(Bookmark.fromMap).toList();
  }

  Future<bool> isPageBookmarked(int documentId, int page) async {
    final db = await _db;
    final rows = await db.query(
      'bookmarks',
      where: 'document_id = ? AND page_number = ?',
      whereArgs: [documentId, page],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> addBookmark({
    required int documentId,
    required int pageNumber,
    String? label,
  }) async {
    final db = await _db;
    return db.insert(
      'bookmarks',
      Bookmark(
        documentId: documentId,
        pageNumber: pageNumber,
        label: label,
        createdAt: DateTime.now().toIso8601String(),
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeBookmark(int documentId, int pageNumber) async {
    final db = await _db;
    await db.delete(
      'bookmarks',
      where: 'document_id = ? AND page_number = ?',
      whereArgs: [documentId, pageNumber],
    );
  }

  Future<void> toggleBookmark(int documentId, int pageNumber) async {
    final exists = await isPageBookmarked(documentId, pageNumber);
    if (exists) {
      await removeBookmark(documentId, pageNumber);
    } else {
      await addBookmark(documentId: documentId, pageNumber: pageNumber);
    }
  }

  Future<void> deleteBookmark(int bookmarkId) async {
    final db = await _db;
    await db.delete(
      'bookmarks',
      where: 'id = ?',
      whereArgs: [bookmarkId],
    );
  }

  Future<void> updateBookmark(int bookmarkId, String newLabel) async {
    final db = await _db;
    await db.update(
      'bookmarks',
      {'label': newLabel},
      where: 'id = ?',
      whereArgs: [bookmarkId],
    );
  }
}