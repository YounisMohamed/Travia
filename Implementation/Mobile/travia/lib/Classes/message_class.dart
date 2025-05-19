import 'package:hive/hive.dart';


class MessageClass {
  final String messageId;
  final String conversationId;
  final String senderId;
  final String content;
  final String contentType;
  final DateTime sentAt;
  final Map<String, String?>? readBy;
  final bool isEdited;
  final String? replyToMessageId;
  final String? replyToMessageSender;
  final Map<String, dynamic>? reactions;
  final String? senderUsername;
  final String? senderProfilePic;
  final bool isConfirmed;
  final String? replyToMessageContent;
  final bool isDeleted;
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
