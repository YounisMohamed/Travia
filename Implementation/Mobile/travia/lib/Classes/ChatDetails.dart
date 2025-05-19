class ChatDetails {
  final String conversationId;
  final String? title;
  final String conversationType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? adminId;
  final String? chatTheme;
  final int numberOfParticipants;
  final String? receiverUsername;
  final String? receiverPhotoUrl;
  final String? receiverId;
  final String? groupChatPicture;

  ChatDetails({
    required this.conversationId,
    this.title,
    required this.conversationType,
    required this.createdAt,
    required this.updatedAt,
    this.adminId,
    this.chatTheme,
    required this.numberOfParticipants,
    this.receiverUsername,
    this.receiverPhotoUrl,
    this.receiverId,
    this.groupChatPicture,
  });

  factory ChatDetails.fromMap(Map<String, dynamic> map) {
    return ChatDetails(
        conversationId: map['conversation_id'],
        title: map['title'],
        conversationType: map['conversation_type'],
        createdAt: DateTime.parse(map['created_at']),
        updatedAt: DateTime.parse(map['updated_at']),
        adminId: map['admin_id'],
        chatTheme: map['chat_theme'],
        numberOfParticipants: map['number_of_participants'] ?? 0,
        receiverUsername: map['receiver_username'],
        receiverPhotoUrl: map['receiver_photourl'],
        receiverId: map['receiver_id'],
        groupChatPicture: map['group_picture']);
  }
}
