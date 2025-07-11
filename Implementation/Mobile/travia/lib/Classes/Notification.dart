class NotificationModel {
  final String id;
  final String? targetUserId;
  final String type;
  final String content;
  final DateTime createdAt;
  final bool isRead;
  final String? sourceId;
  final String? senderUserId;
  final String? senderPhoto;
  final String? senderUsername;

  NotificationModel({
    required this.id,
    required this.type,
    required this.content,
    required this.createdAt,
    required this.isRead,
    this.targetUserId,
    this.sourceId,
    this.senderUserId,
    this.senderPhoto,
    this.senderUsername,
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
        senderPhoto: map['sender_photo'] as String?,
        senderUsername: map['user_username']);
  }

  // Convert NotificationModel to JSON/Map (for Supabase insertion)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'target_user_id': targetUserId,
      'type': type,
      'content': content,
      'created_at': createdAt,
      'is_read': isRead,
      'source_id': sourceId,
      'sender_user_id': senderUserId,
      'sender_photo': senderPhoto,
      'user_username': senderUsername,
    };
  }
}