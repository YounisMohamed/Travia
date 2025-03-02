class ConversationParticipants {
  final String conversationId;
  final String userId;
  final DateTime joinedAt;
  final DateTime? lastReadAt;
  final DateTime? lastActiveAt;
  final bool isTyping;
  final bool notificationsEnabled;
  final String? userUsername;
  final String? userPhotoUrl;

  ConversationParticipants({
    required this.conversationId,
    required this.userId,
    required this.joinedAt,
    this.lastReadAt,
    this.lastActiveAt,
    required this.isTyping,
    required this.notificationsEnabled,
    this.userUsername,
    this.userPhotoUrl,
  });

  factory ConversationParticipants.fromMap(Map<String, dynamic> map) {
    return ConversationParticipants(
      conversationId: map['conversation_id'],
      userId: map['user_id'],
      joinedAt: DateTime.parse(map['joined_at']),
      lastReadAt: map['last_read_at'] != null ? DateTime.parse(map['last_read_at']) : null,
      lastActiveAt: map['last_active_at'] != null ? DateTime.parse(map['last_active_at']) : null,
      isTyping: map['is_typing'] ?? false,
      notificationsEnabled: map['notifications_enabled'] ?? true,
      userUsername: map['user_username'],
      userPhotoUrl: map['user_photourl'],
    );
  }
}
