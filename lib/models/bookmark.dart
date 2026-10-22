class Bookmark {
  final int? id;
  final int documentId;
  final int pageNumber;
  final String? label;
  final String createdAt;

  const Bookmark({this.id, required this.documentId,
      required this.pageNumber, this.label, required this.createdAt});

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'document_id': documentId,
    'page_number': pageNumber, 'label': label, 'created_at': createdAt,
  };

  factory Bookmark.fromMap(Map<String, dynamic> map) => Bookmark(
    id: map['id'] as int?, documentId: map['document_id'] as int,
    pageNumber: map['page_number'] as int, label: map['label'] as String?,
    createdAt: map['created_at'] as String);
}