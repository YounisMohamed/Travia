class ConversationDetail {
  final String conversationId;
  final String conversationType;
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastMessageAt;
  final String? lastMessageId;
  final String? lastMessageContent;
  final String userId;
  final DateTime? lastReadAt;
  final String? userUsername;
  final String? userPhotoUrl;
  final int unreadCount;
  final String? sender;
  final bool notificationsEnabled;
  final bool isTyping;
  final bool isPinned;
  final String? chatTheme;
  final int typingCount;

  ConversationDetail({
    required this.conversationId,
    required this.conversationType,
    this.title,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessageAt,
    this.lastMessageId,
    this.lastMessageContent,
    required this.userId,
    this.lastReadAt,
    this.userUsername,
    this.userPhotoUrl,
    required this.unreadCount,
    this.sender,
    required this.notificationsEnabled,
    required this.isTyping,
    required this.isPinned,
    this.chatTheme,
    required this.typingCount,
  });

  factory ConversationDetail.fromMap(Map<String, dynamic> map) {
    return ConversationDetail(
      conversationId: map['conversation_id'] as String,
      conversationType: map['conversation_type'] as String,
      title: map['title'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      lastMessageAt: map['last_message_at'] != null ? DateTime.parse(map['last_message_at'] as String) : null,
      lastMessageId: map['last_message_id'] as String?,
      lastMessageContent: map['last_message_content'] as String?,
      userId: map['user_id'] as String,
      lastReadAt: map['last_read_at'] != null ? DateTime.parse(map['last_read_at'] as String) : null,
      userUsername: map['user_username'] as String?,
      userPhotoUrl: map['user_photourl'] as String?,
      unreadCount: (map['unread_count'] as num).toInt(),
      sender: map['sender'] as String?,
      notificationsEnabled: map['notifications_enabled'] as bool,
      isTyping: map['is_typing'] as bool,
      isPinned: map['is_pinned'] as bool,
      chatTheme: map['chat_theme'] as String?,
      typingCount: map['typing_count'] as int,
    );
  }
}
