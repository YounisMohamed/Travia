class ConversationDetail {
  final String conversationId;
  final String conversationType;
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userId;
  final String? userUsername;
  final String? userPhotoUrl;
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
    required this.userId,
    this.userUsername,
    this.userPhotoUrl,
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
      userId: map['user_id'],
      userUsername: map['user_username'],
      userPhotoUrl: map['user_photo_url'], // Fixed key name
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
      'user_id': userId,
      'user_username': userUsername,
      'user_photo_url': userPhotoUrl, // Fixed key name
      'sender': sender,
      'is_typing': isTyping,
      'is_pinned': isPinned,
      'chat_theme': chatTheme,
    };
  }

  ConversationDetail copyWith({
    String? conversationId,
    String? conversationType,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastMessageAt,
    String? lastMessageId,
    String? lastMessageContent,
    String? lastMessageContentType,
    String? userId,
    DateTime? lastReadAt,
    String? userUsername,
    String? userPhotoUrl,
    int? unreadCount,
    String? sender,
    bool? isTyping,
    bool? isPinned,
    String? chatTheme,
    String? groupPicture,
  }) {
    return ConversationDetail(
      conversationId: conversationId ?? this.conversationId,
      conversationType: conversationType ?? this.conversationType,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      userUsername: userUsername ?? this.userUsername,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      sender: sender ?? this.sender,
      isTyping: isTyping ?? this.isTyping,
      isPinned: isPinned ?? this.isPinned,
      chatTheme: chatTheme ?? this.chatTheme,
      groupPicture: groupPicture ?? this.groupPicture,
    );
  }
}
