class Post {
  final String id;
  final DateTime createdAt;
  final String userId;
  final String mediaUrl;
  final String? caption;
  final String? location;
  final String postId;
  // User details
  final String userDisplayName;
  final String? userPhotoUrl;
  // Engagement counts
  final int likeCount;
  final int commentCount;

  Post({
    required this.id,
    required this.createdAt,
    required this.userId,
    required this.mediaUrl,
    this.caption,
    this.location,
    required this.userDisplayName,
    this.userPhotoUrl,
    required this.likeCount,
    required this.commentCount,
    required this.postId,
  });

  factory Post.fromMap(Map<String, dynamic> map) {
    final userData = map['users'] as Map<String, dynamic>;
    final likesCount = (map['likes'] as List).length;
    final commentsCount = (map['comments'] as List).length;

    return Post(
      id: map['id'],
      createdAt: DateTime.parse(map['created_at']),
      userId: map['user_id'],
      mediaUrl: map['media_url'],
      caption: map['caption'],
      location: map['location'],
      userDisplayName: userData['display_name'],
      userPhotoUrl: userData['photo_url'],
      likeCount: likesCount,
      commentCount: commentsCount,
      postId: map['id'],
    );
  }
}
