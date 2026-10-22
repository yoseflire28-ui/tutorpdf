class ReadingAnalytics {
  final int? id;
  final int documentId;
  final String date;
  final int timeSpentSeconds;
  final int pagesRead;

  const ReadingAnalytics({this.id, required this.documentId,
      required this.date, this.timeSpentSeconds = 0, this.pagesRead = 0});

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'document_id': documentId,
    'date': date, 'time_spent_seconds': timeSpentSeconds, 'pages_read': pagesRead,
  };

  factory ReadingAnalytics.fromMap(Map<String, dynamic> map) => ReadingAnalytics(
    id: map['id'] as int?, documentId: map['document_id'] as int,
    date: map['date'] as String,
    timeSpentSeconds: map['time_spent_seconds'] as int? ?? 0,
    pagesRead: map['pages_read'] as int? ?? 0);
}