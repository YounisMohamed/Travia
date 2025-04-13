// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ConversationDetail.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ConversationDetailAdapter extends TypeAdapter<ConversationDetail> {
  @override
  final int typeId = 2;

  @override
  ConversationDetail read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ConversationDetail(
      conversationId: fields[0] as String,
      conversationType: fields[1] as String,
      title: fields[2] as String?,
      createdAt: fields[3] as DateTime,
      updatedAt: fields[4] as DateTime,
      lastMessageAt: fields[5] as DateTime?,
      lastMessageId: fields[6] as String?,
      lastMessageContent: fields[7] as String?,
      lastMessageContentType: fields[8] as String?,
      userId: fields[9] as String,
      lastReadAt: fields[10] as DateTime?,
      userUsername: fields[11] as String?,
      userPhotoUrl: fields[12] as String?,
      unreadCount: fields[13] as int,
      sender: fields[14] as String?,
      notificationsEnabled: fields[15] as bool,
      isTyping: fields[16] as bool,
      isPinned: fields[17] as bool,
      chatTheme: fields[18] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ConversationDetail obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.conversationId)
      ..writeByte(1)
      ..write(obj.conversationType)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt)
      ..writeByte(5)
      ..write(obj.lastMessageAt)
      ..writeByte(6)
      ..write(obj.lastMessageId)
      ..writeByte(7)
      ..write(obj.lastMessageContent)
      ..writeByte(8)
      ..write(obj.lastMessageContentType)
      ..writeByte(9)
      ..write(obj.userId)
      ..writeByte(10)
      ..write(obj.lastReadAt)
      ..writeByte(11)
      ..write(obj.userUsername)
      ..writeByte(12)
      ..write(obj.userPhotoUrl)
      ..writeByte(13)
      ..write(obj.unreadCount)
      ..writeByte(14)
      ..write(obj.sender)
      ..writeByte(15)
      ..write(obj.notificationsEnabled)
      ..writeByte(16)
      ..write(obj.isTyping)
      ..writeByte(17)
      ..write(obj.isPinned)
      ..writeByte(18)
      ..write(obj.chatTheme);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationDetailAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
