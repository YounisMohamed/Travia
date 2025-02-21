class Comment {
  final String id;
  final String postId;
  final String? parentCommentId;
  final String userId;
  final String content;
  final int likeCount;
  final DateTime createdAt;
  final String userDisplayName;
  final String userPhotoUrl;
  final String userUsername;
  final bool isReplyToParentComment;
  final String? usernameOfParentComment;

  Comment({
    required this.id,
    required this.postId,
    this.parentCommentId,
    required this.userId,
    required this.content,
    required this.likeCount,
    required this.createdAt,
    required this.userDisplayName,
    required this.userPhotoUrl,
    required this.userUsername,
    this.isReplyToParentComment = false,
    this.usernameOfParentComment,
  });

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'],
      postId: map['post_id'],
      parentCommentId: map['parent_comment_id'],
      isReplyToParentComment: map['parent_comment_id'] == null,
      userId: map['user_id'],
      content: map['content'],
      likeCount: map['likes_count'],
      createdAt: DateTime.parse(map['created_at']),
      userDisplayName: map['user_display_name'],
      userPhotoUrl: map['user_photo_url'] ?? '',
      userUsername: map['user_username'],
      usernameOfParentComment: map['username_of_parent_comment'],
    );
  }

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      parentCommentId: json['parent_comment_id'] as String?,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      likeCount: json['likes_count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      userDisplayName: json['user_display_name'] as String,
      userPhotoUrl: json['user_photo_url'] as String? ?? '',
      userUsername: json['user_username'] as String,
      isReplyToParentComment: json['parent_comment_id'] == null,
      usernameOfParentComment: json['username_of_parent_comment'] as String?,
    );
  }
}
