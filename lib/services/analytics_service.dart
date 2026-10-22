import 'dart:async';
import '../database/database_helper.dart';

class AnalyticsService {
  Timer? _timer;
  int? _activeDocumentId;
  // Tracks the last page seen; written on each page change for future features.
  int? _lastTrackedPage;

  final Set<int> _visitedPagesToday = {};

  void startSession(int documentId, int currentPage) {
    stopSession();
    _activeDocumentId = documentId;
    _lastTrackedPage = currentPage;
    _visitedPagesToday.clear();
    _visitedPagesToday.add(currentPage);

    _timer = Timer.periodic(const Duration(seconds: 60), (_) async {
      await _tick();
    });
  }

  Future<void> onPageChange(int newPage) async {
    final docId = _activeDocumentId;
    if (docId == null) return;

    if (!_visitedPagesToday.contains(newPage)) {
      _visitedPagesToday.add(newPage);
      await _incrementPagesRead(docId);
    }
    _lastTrackedPage = newPage;
  }

  Future<void> _tick() async {
    final docId = _activeDocumentId;
    if (docId == null) return;
    final today = _todayString();

    final db = await DatabaseHelper.instance.database;
    await db.execute('''
      INSERT INTO reading_analytics (document_id, date, time_spent_seconds, pages_read)
      VALUES (?, ?, 60, 0)
      ON CONFLICT(document_id, date)
      DO UPDATE SET time_spent_seconds = time_spent_seconds + 60
    ''', [docId, today]);
  }

  Future<void> _incrementPagesRead(int docId) async {
    final today = _todayString();
    final db = await DatabaseHelper.instance.database;
    await db.execute('''
      INSERT INTO reading_analytics (document_id, date, time_spent_seconds, pages_read)
      VALUES (?, ?, 0, 1)
      ON CONFLICT(document_id, date)
      DO UPDATE SET pages_read = pages_read + 1
    ''', [docId, today]);
  }

  void stopSession() {
    _timer?.cancel();
    _timer = null;
    _activeDocumentId = null;
    _lastTrackedPage = null;
    _visitedPagesToday.clear();
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<int> totalSecondsLast7Days() async {
    final db = await DatabaseHelper.instance.database;
    final cutoff = DateTime.now().subtract(const Duration(days: 6));
    final cutoffStr =
        '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(time_spent_seconds), 0) AS total
      FROM reading_analytics
      WHERE date >= ?
    ''', [cutoffStr]);
    return (result.first['total'] as int?) ?? 0;
  }

  Future<int> totalPagesThisMonth() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final prefix =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(pages_read), 0) AS total
      FROM reading_analytics
      WHERE date LIKE ?
    ''', ['$prefix%']);
    return (result.first['total'] as int?) ?? 0;
  }

  Future<double> completionPercent(int documentId) async {
    final db = await DatabaseHelper.instance.database;
    final docRows = await db.query('documents',
        columns: ['current_page', 'total_pages'],
        where: 'id = ?',
        whereArgs: [documentId],
        limit: 1);
    if (docRows.isEmpty) return 0.0;
    final current = (docRows.first['current_page'] as int?) ?? 0;
    final total = (docRows.first['total_pages'] as int?) ?? 0;
    if (total == 0) return 0.0;
    return (current / total * 100).clamp(0.0, 100.0);
  }

  Future<List<Map<String, dynamic>>> dailyBreakdownLast7Days() async {
    final db = await DatabaseHelper.instance.database;
    final cutoff = DateTime.now().subtract(const Duration(days: 6));
    final cutoffStr =
        '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';

    final rows = await db.rawQuery('''
      SELECT
        date,
        SUM(time_spent_seconds) / 60.0 AS minutes,
        SUM(pages_read) AS pages
      FROM reading_analytics
      WHERE date >= ?
      GROUP BY date
      ORDER BY date ASC
    ''', [cutoffStr]);

    return rows.map((r) => {
          'date': r['date'] as String,
          'minutes': (r['minutes'] as double?) ?? 0.0,
          'pages': (r['pages'] as int?) ?? 0,
        }).toList();
  }

  Future<List<Map<String, dynamic>>> monthlyBreakdown() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT
        SUBSTR(date, 1, 7) AS month,
        SUM(time_spent_seconds) / 60.0 AS minutes,
        SUM(pages_read) AS pages
      FROM reading_analytics
      GROUP BY month
      ORDER BY month ASC
    ''');
    return rows.map((r) => {
          'month': r['month'] as String,
          'minutes': (r['minutes'] as double?) ?? 0.0,
          'pages': (r['pages'] as int?) ?? 0,
        }).toList();
  }
}