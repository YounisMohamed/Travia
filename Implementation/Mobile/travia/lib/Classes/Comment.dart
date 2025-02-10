class Comment {
  final String id;
  final String postId;
  final String? parentCommentId;
  final String userId;
  final String content;
  final int likeCount;
  final DateTime createdAt;
  final String userName;
  final String userPhotoUrl;

  Comment({
    required this.id,
    required this.postId,
    this.parentCommentId,
    required this.userId,
    required this.content,
    required this.likeCount,
    required this.createdAt,
    required this.userName,
    required this.userPhotoUrl,
  });

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'],
      postId: map['post_id'],
      parentCommentId: map['parent_comment_id'],
      userId: map['user_id'],
      content: map['content'],
      likeCount: map['likes'] != null ? map['likes'][0]['count'] as int : 0,
      createdAt: DateTime.parse(map['created_at']),
      userName: map['users']['display_name'],
      userPhotoUrl: map['users']['photo_url'] ?? '',
    );
  }
}
