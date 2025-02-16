class NotificationModel {
  final String id;
  final String? targetUserId;
  final String type;
  final String content;
  final DateTime createdAt;
  final bool isRead;
  final String? sourceId;
  final String? senderUserId;

  NotificationModel({
    required this.id,
    required this.type,
    required this.content,
    required this.createdAt,
    required this.isRead,
    this.targetUserId,
    this.sourceId,
    this.senderUserId,
  });

  // Convert JSON/Map from Supabase to NotificationModel
  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as String,
      targetUserId: map['target_user_id'] as String?,
      type: map['type'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at']),
      isRead: map['is_read'] as bool,
      sourceId: map['source_id'] as String?,
      senderUserId: map['sender_user_id'] as String?,
    );
  }

  // Convert NotificationModel to JSON/Map (for Supabase insertion)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'target_user_id': targetUserId,
      'type': type,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
      'source_id': sourceId,
      'sender_user_id': senderUserId,
    };
  }
}
