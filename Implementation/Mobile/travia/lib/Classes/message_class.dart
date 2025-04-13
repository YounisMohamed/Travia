import 'package:hive/hive.dart';

part 'message_class.g.dart';

@HiveType(typeId: 1)
class MessageClass {
  @HiveField(0)
  final String messageId;

  @HiveField(1)
  final String conversationId;

  @HiveField(2)
  final String senderId;

  @HiveField(3)
  final String content;

  @HiveField(4)
  final String contentType;

  @HiveField(5)
  final DateTime sentAt;

  @HiveField(6)
  final Map<String, String?>? readBy; // Hive does not support Maps directly

  @HiveField(7)
  final bool isEdited;

  @HiveField(8)
  final String? replyToMessageId;

  @HiveField(9)
  final String? replyToMessageSender;

  @HiveField(10)
  final Map<String, dynamic>? reactions; // Hive does not support dynamic maps

  @HiveField(11)
  final String? senderUsername;

  @HiveField(12)
  final String? senderProfilePic;

  @HiveField(13)
  final bool isConfirmed;

  @HiveField(14)
  final String? replyToMessageContent;

  @HiveField(15)
  final bool isDeleted;

  @HiveField(16)
  final List<String> deletedForMeId;

  MessageClass({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.contentType,
    required this.sentAt,
    this.readBy,
    required this.isEdited,
    required this.isDeleted,
    required this.deletedForMeId,
    this.replyToMessageId,
    this.replyToMessageSender,
    this.replyToMessageContent,
    this.reactions,
    this.senderUsername,
    this.senderProfilePic,
    this.isConfirmed = false,
  });

  factory MessageClass.fromMap(Map<String, dynamic> map) {
    return MessageClass(
      messageId: map['message_id'],
      conversationId: map['conversation_id'],
      senderId: map['sender_id'],
      content: map['content'],
      contentType: map['content_type'],
      sentAt: DateTime.parse(map['sent_at']),
      readBy: map['read_by'] != null ? Map<String, String?>.from(map['read_by']) : null,
      isEdited: map['is_edited'] ?? false,
      replyToMessageId: map['reply_to_message_id'],
      replyToMessageSender: map['reply_to_message_sender'],
      replyToMessageContent: map['reply_to_message_content'],
      reactions: map['reactions'] != null ? Map<String, dynamic>.from(map['reactions']) : null,
      senderUsername: map['sender_username'],
      senderProfilePic: map['sender_profilepic'],
      isDeleted: map['is_deleted'],
      deletedForMeId: List<String>.from(map['deleted_for_me_id'] ?? []),
      isConfirmed: true,
    );
  }

  MessageClass copyWith({
    String? messageId,
    String? conversationId,
    String? senderId,
    String? content,
    String? contentType,
    DateTime? sentAt,
    Map<String, String?>? readBy,
    bool? isEdited,
    String? replyToMessageId,
    String? replyToMessageSender,
    String? replyToMessageContent,
    Map<String, dynamic>? reactions,
    String? senderUsername,
    String? senderProfilePic,
    bool? isConfirmed,
    bool? isDeleted,
    List<String>? deletedForMeId,
  }) {
    return MessageClass(
      messageId: messageId ?? this.messageId,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      contentType: contentType ?? this.contentType,
      sentAt: sentAt ?? this.sentAt,
      readBy: readBy ?? this.readBy,
      isEdited: isEdited ?? this.isEdited,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToMessageSender: replyToMessageSender ?? this.replyToMessageSender,
      replyToMessageContent: replyToMessageContent ?? this.replyToMessageContent,
      reactions: reactions ?? this.reactions,
      senderUsername: senderUsername ?? this.senderUsername,
      senderProfilePic: senderProfilePic ?? this.senderProfilePic,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedForMeId: deletedForMeId ?? this.deletedForMeId,
    );
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is MessageClass && runtimeType == other.runtimeType && messageId == other.messageId;

  @override
  int get hashCode => messageId.hashCode;
}
