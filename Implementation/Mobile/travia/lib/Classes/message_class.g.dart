// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_class.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MessageClassAdapter extends TypeAdapter<MessageClass> {
  @override
  final int typeId = 1;

  @override
  MessageClass read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MessageClass(
      messageId: fields[0] as String,
      conversationId: fields[1] as String,
      senderId: fields[2] as String,
      content: fields[3] as String,
      contentType: fields[4] as String,
      sentAt: fields[5] as DateTime,
      readBy: (fields[6] as Map?)?.cast<String, String?>(),
      isEdited: fields[7] as bool,
      isDeleted: fields[15] as bool,
      deletedForMeId: (fields[16] as List).cast<String>(),
      replyToMessageId: fields[8] as String?,
      replyToMessageSender: fields[9] as String?,
      replyToMessageContent: fields[14] as String?,
      reactions: (fields[10] as Map?)?.cast<String, dynamic>(),
      senderUsername: fields[11] as String?,
      senderProfilePic: fields[12] as String?,
      isConfirmed: fields[13] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, MessageClass obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.messageId)
      ..writeByte(1)
      ..write(obj.conversationId)
      ..writeByte(2)
      ..write(obj.senderId)
      ..writeByte(3)
      ..write(obj.content)
      ..writeByte(4)
      ..write(obj.contentType)
      ..writeByte(5)
      ..write(obj.sentAt)
      ..writeByte(6)
      ..write(obj.readBy)
      ..writeByte(7)
      ..write(obj.isEdited)
      ..writeByte(8)
      ..write(obj.replyToMessageId)
      ..writeByte(9)
      ..write(obj.replyToMessageSender)
      ..writeByte(10)
      ..write(obj.reactions)
      ..writeByte(11)
      ..write(obj.senderUsername)
      ..writeByte(12)
      ..write(obj.senderProfilePic)
      ..writeByte(13)
      ..write(obj.isConfirmed)
      ..writeByte(14)
      ..write(obj.replyToMessageContent)
      ..writeByte(15)
      ..write(obj.isDeleted)
      ..writeByte(16)
      ..write(obj.deletedForMeId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageClassAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
