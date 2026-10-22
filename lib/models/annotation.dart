enum AnnotationType { highlight, note }

class Annotation {
  final int? id;
  final int documentId;
  final int pageNumber;
  final AnnotationType type;
  final String? selectedText;
  final String? noteContent;
  final String colorHex;
  final String createdAt;

  const Annotation({this.id, required this.documentId, required this.pageNumber,
      required this.type, this.selectedText, this.noteContent,
      this.colorHex = '#FFFF00', required this.createdAt});

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id, 'document_id': documentId,
    'page_number': pageNumber, 'type': type.name,
    'selected_text': selectedText, 'note_content': noteContent,
    'color_hex': colorHex, 'created_at': createdAt,
  };

  factory Annotation.fromMap(Map<String, dynamic> map) => Annotation(
    id: map['id'] as int?, documentId: map['document_id'] as int,
    pageNumber: map['page_number'] as int,
    type: AnnotationType.values.firstWhere((e) => e.name == (map['type'] as String)),
    selectedText: map['selected_text'] as String?,
    noteContent: map['note_content'] as String?,
    colorHex: map['color_hex'] as String? ?? '#FFFF00',
    createdAt: map['created_at'] as String);
}