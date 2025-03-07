class MessageDetails {
  final String messageId;
  final String content;
  final String senderId;
  final String senderName;
  final String? senderProfilePic;
  final DateTime sentAt;
  final bool isCurrentUser;
  final bool isRead;

  MessageDetails({
    required this.messageId,
    required this.content,
    required this.senderId,
    required this.senderName,
    this.senderProfilePic,
    required this.sentAt,
    required this.isCurrentUser,
    this.isRead = false,
  });
}
