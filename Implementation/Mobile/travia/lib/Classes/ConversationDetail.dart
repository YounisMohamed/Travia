class ConversationDetail {
  final String conversationId;
  final String conversationType;
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastMessageAt;
  final String? lastMessageId;
  final String? lastMessageContent;
  final String? lastMessageContentType;
  final String userId;
  final DateTime? lastReadAt;
  final String? userUsername;
  final String? userPhotoUrl;
  final int unreadCount;
  final String? sender;
  final bool isTyping;
  final bool isPinned;
  final String? chatTheme;
  final String? groupPicture;

  ConversationDetail({
    required this.conversationId,
    required this.conversationType,
    this.title,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessageAt,
    this.lastMessageId,
    this.lastMessageContent,
    this.lastMessageContentType,
    required this.userId,
    this.lastReadAt,
    this.userUsername,
    this.userPhotoUrl,
    required this.unreadCount,
    this.sender,
    this.groupPicture,
    required this.isTyping,
    required this.isPinned,
    this.chatTheme,
  });

  factory ConversationDetail.fromMap(Map<String, dynamic> map) {
    return ConversationDetail(
      groupPicture: map['group_picture'],
      conversationId: map['conversation_id'],
      conversationType: map['conversation_type'],
      title: map['title'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      lastMessageAt: map['last_message_at'] != null ? DateTime.parse(map['last_message_at']) : null,
      lastMessageId: map['last_message_id'],
      lastMessageContent: map['last_message_content'],
      lastMessageContentType: map['last_message_content_type'],
      userId: map['user_id'],
      lastReadAt: map['last_read_at'] != null ? DateTime.parse(map['last_read_at']) : null,
      userUsername: map['user_username'],
      userPhotoUrl: map['user_photo_url'], // Fixed key name
      unreadCount: (map['unread_count'] as num).toInt(),
      sender: map['sender'],
      isTyping: map['is_typing'],
      isPinned: map['is_pinned'],
      chatTheme: map['chat_theme'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'group_picture': groupPicture,
      'conversation_id': conversationId,
      'conversation_type': conversationType,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_message_at': lastMessageAt?.toIso8601String(),
      'last_message_id': lastMessageId,
      'last_message_content': lastMessageContent,
      'last_message_content_type': lastMessageContentType,
      'user_id': userId,
      'last_read_at': lastReadAt?.toIso8601String(),
      'user_username': userUsername,
      'user_photo_url': userPhotoUrl, // Fixed key name
      'unread_count': unreadCount,
      'sender': sender,
      'is_typing': isTyping,
      'is_pinned': isPinned,
      'chat_theme': chatTheme,
    };
  }
}
