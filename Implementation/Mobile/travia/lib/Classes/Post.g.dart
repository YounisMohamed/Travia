// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'Post.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PostAdapter extends TypeAdapter<Post> {
  @override
  final int typeId = 0;

  @override
  Post read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Post(
      createdAt: fields[0] as DateTime,
      userId: fields[1] as String,
      mediaUrl: fields[2] as String,
      caption: fields[3] as String?,
      location: fields[4] as String?,
      userPhotoUrl: fields[6] as String,
      userUserName: fields[7] as String,
      commentCount: fields[8] as int,
      likeCount: fields[9] as int,
      postId: fields[5] as String,
      viewCount: fields[10] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Post obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.createdAt)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.mediaUrl)
      ..writeByte(3)
      ..write(obj.caption)
      ..writeByte(4)
      ..write(obj.location)
      ..writeByte(5)
      ..write(obj.postId)
      ..writeByte(6)
      ..write(obj.userPhotoUrl)
      ..writeByte(7)
      ..write(obj.userUserName)
      ..writeByte(8)
      ..write(obj.commentCount)
      ..writeByte(9)
      ..write(obj.likeCount)
      ..writeByte(10)
      ..write(obj.viewCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
