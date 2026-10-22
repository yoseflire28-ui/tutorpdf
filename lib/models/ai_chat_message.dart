enum MessageSender { user, ai }

class AiChatMessage {
  final int? id;
  final int documentId;
  final MessageSender sender;
  final String message;
  final String createdAt;
  final bool isError;

  const AiChatMessage({
    this.id,
    required this.documentId,
    required this.sender,
    required this.message,
    required this.createdAt,
    this.isError = false,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'document_id': documentId,
    'sender': sender.name,
    'message': message,
    'created_at': createdAt,
    'is_error': isError,
  };

  factory AiChatMessage.fromMap(Map<String, dynamic> map) => AiChatMessage(
    id: map['id'] as int?,
    documentId: map['document_id'] as int,
    sender: MessageSender.values.firstWhere((e) => e.name == (map['sender'] as String)),
    message: map['message'] as String,
    createdAt: map['created_at'] as String,
    isError: map['is_error'] as bool? ?? false,
  );
}