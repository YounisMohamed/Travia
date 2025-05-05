import 'package:hive/hive.dart';

part 'Post.g.dart';

@HiveType(typeId: 0)
class Post extends HiveObject {
  @HiveField(0)
  final DateTime createdAt;
  @HiveField(1)
  final String userId;
  @HiveField(2)
  final String mediaUrl;
  @HiveField(3)
  final String? caption;
  @HiveField(4)
  final String? location;
  @HiveField(5)
  final String postId;
  @HiveField(6)
  final String userPhotoUrl;
  @HiveField(7)
  final String userUserName;
  @HiveField(8)
  final int commentCount;
  @HiveField(9)
  final int likeCount;
  @HiveField(10)
  final int viewCount;
  Post({
    required this.createdAt,
    required this.userId,
    required this.mediaUrl,
    this.caption,
    this.location,
    required this.userPhotoUrl,
    required this.userUserName,
    required this.commentCount,
    required this.likeCount,
    required this.postId,
    required this.viewCount,
  });
  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      createdAt: DateTime.parse(map['created_at']),
      userId: map['user_id'],
      mediaUrl: map['media_url'],
      caption: map['caption'],
      location: map['location'],
      userPhotoUrl: map['poster_photo_url'],
      userUserName: map['poster_username'],
      commentCount: map['comments_count'],
      likeCount: map['likes_count'],
      postId: map['id'],
      viewCount: map['views'],
    );
  }
  factory Post.fromJson(Map<String, dynamic> json) => Post.fromMap(json);
}
