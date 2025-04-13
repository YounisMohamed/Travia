import 'package:hive/hive.dart';

part 'ConversationDetail.g.dart';

@HiveType(typeId: 2)
class ConversationDetail extends HiveObject {
  @HiveField(0)
  final String conversationId;

  @HiveField(1)
  final String conversationType;

  @HiveField(2)
  final String? title;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime updatedAt;

  @HiveField(5)
  final DateTime? lastMessageAt;

  @HiveField(6)
  final String? lastMessageId;

  @HiveField(7)
  final String? lastMessageContent;

  @HiveField(8)
  final String? lastMessageContentType;

  @HiveField(9)
  final String userId;

  @HiveField(10)
  final DateTime? lastReadAt;

  @HiveField(11)
  final String? userUsername;

  @HiveField(12)
  final String? userPhotoUrl;

  @HiveField(13)
  final int unreadCount;

  @HiveField(14)
  final String? sender;

  @HiveField(15)
  final bool notificationsEnabled;

  @HiveField(16)
  final bool isTyping;

  @HiveField(17)
  final bool isPinned;

  @HiveField(18)
  final String? chatTheme;

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
    required this.notificationsEnabled,
    required this.isTyping,
    required this.isPinned,
    this.chatTheme,
  });

  factory ConversationDetail.fromMap(Map<String, dynamic> map) {
    return ConversationDetail(
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
      userPhotoUrl: map['user_photourl'],
      unreadCount: (map['unread_count'] as num).toInt(),
      sender: map['sender'],
      notificationsEnabled: map['notifications_enabled'],
      isTyping: map['is_typing'],
      isPinned: map['is_pinned'],
      chatTheme: map['chat_theme'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
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
      'user_photourl': userPhotoUrl,
      'unread_count': unreadCount,
      'sender': sender,
      'notifications_enabled': notificationsEnabled,
      'is_typing': isTyping,
      'is_pinned': isPinned,
      'chat_theme': chatTheme,
    };
  }
}
