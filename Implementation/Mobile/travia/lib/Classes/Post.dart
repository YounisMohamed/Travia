import 'package:hive/hive.dart';

class Post extends HiveObject {
  final DateTime createdAt;
  final String userId;
  final String mediaUrl;
  final String? caption;
  final String location;
  final String postId;
  final String userPhotoUrl;
  final String userUserName;
  final int commentCount;
  final int likesCount;
  final int dislikesCount;
  final int viewCount;
  Post({
    required this.createdAt,
    required this.userId,
    required this.mediaUrl,
    this.caption,
    required this.location,
    required this.userPhotoUrl,
    required this.userUserName,
    required this.commentCount,
    required this.likesCount,
    required this.dislikesCount,
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
      likesCount: map['likes_count'],
      dislikesCount: map['dislikes_count'],
      postId: map['id'],
      viewCount: map['views'],
    );
  }
  factory Post.fromJson(Map<String, dynamic> json) => Post.fromMap(json);
}
