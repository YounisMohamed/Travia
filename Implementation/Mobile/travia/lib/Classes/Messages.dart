class Message {
  final String messageId;
  final String conversationId;
  final String senderId;
  final String content;
  final String contentType;
  final DateTime sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final bool isEdited;
  final String? replyToMessageId;
  final Map<String, dynamic>? reactions;
  final String? senderUsername;
  final String? senderProfilePic;

  Message({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.contentType,
    required this.sentAt,
    this.deliveredAt,
    this.readAt,
    required this.isEdited,
    this.replyToMessageId,
    this.reactions,
    this.senderUsername,
    this.senderProfilePic,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      messageId: map['message_id'],
      conversationId: map['conversation_id'],
      senderId: map['sender_id'],
      content: map['content'],
      contentType: map['content_type'],
      sentAt: DateTime.parse(map['sent_at']),
      deliveredAt: map['delivered_at'] != null ? DateTime.parse(map['delivered_at']) : null,
      readAt: map['read_at'] != null ? DateTime.parse(map['read_at']) : null,
      isEdited: map['is_edited'] ?? false,
      replyToMessageId: map['reply_to_message_id'],
      reactions: map['reactions'] != null ? Map<String, dynamic>.from(map['reactions']) : null,
      senderUsername: map['sender_username'],
      senderProfilePic: map['sender_profilepic'],
    );
  }
}
