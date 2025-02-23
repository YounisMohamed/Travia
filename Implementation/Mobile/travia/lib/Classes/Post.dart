import '../MainFlow/HomePage.dart';

class Post {
  final DateTime createdAt;
  final String userId;
  final String mediaUrl;
  final String? caption;
  final String? location;
  final String postId;
  // User details
  final String userDisplayName;
  final String? userPhotoUrl;
  final String userUserName;
  // Engagement counts
  final int commentCount;
  final int likeCount;

  Post({
    required this.createdAt,
    required this.userId,
    required this.mediaUrl,
    this.caption,
    this.location,
    required this.userDisplayName,
    this.userPhotoUrl,
    required this.userUserName,
    required this.commentCount,
    required this.likeCount,
    required this.postId,
  });

  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      createdAt: DateTime.parse(map['created_at']),
      userId: map['user_id'],
      mediaUrl: map['media_url'],
      caption: map['caption'],
      location: map['location'],
      userDisplayName: map['poster_display_name'],
      userPhotoUrl: map['poster_photo_url'] ?? dummyImageUrl,
      userUserName: map['poster_username'],
      commentCount: map['comments_count'],
      likeCount: map['likes_count'],
      postId: map['id'],
    );
  }
}
