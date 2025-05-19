class Conversation {
  final String conversationId;
  final String conversationType;
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastMessageAt;
  final String? adminId;
  final String? chatTheme;
  final String? lastMessageId;
  final String? lastMessageContent;
  final String? lastMessageContentType;
  final String? lastMessageSender;
  final String? groupPicture;
  final bool notificationsEnabled;
  final bool isTyping;
  final bool isPinned;

  Conversation({
    required this.conversationId,
    required this.conversationType,
    this.title,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessageAt,
    this.adminId,
    this.chatTheme,
    this.lastMessageId,
    this.lastMessageContent,
    this.lastMessageSender,
    this.lastMessageContentType,
    this.groupPicture,
    required this.notificationsEnabled,
    required this.isTyping,
    required this.isPinned,
  });

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      conversationId: map['conversation_id'],
      conversationType: map['conversation_type'],
      isPinned: map['is_pinned'] ?? false,
      groupPicture: map['group_picture'],
      title: map['title'] ?? "",
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      lastMessageAt: map['last_message_at'] != null ? DateTime.parse(map['last_message_at']) : null,
      adminId: map['admin_id'],
      chatTheme: map['chat_theme'],
      lastMessageId: map['last_message_id'],
      lastMessageContent: map['last_message_content'],
      lastMessageContentType: map['last_message_content_type'],
      lastMessageSender: map['last_message_sender'],
      notificationsEnabled: map['notifications_enabled'],
      isTyping: map['is_typing'],
    );
  }
}
