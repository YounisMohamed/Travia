import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../main.dart';

class LikeNotifierComment extends StateNotifier<Map<String, bool>> {
  final Box<Map<String, bool>> _likedCommentsBox = Hive.box("liked_comments_${FirebaseAuth.instance.currentUser?.uid}");

  LikeNotifierComment() : super({}) {
    _fetchLikedComments(); // Load liked posts from database on app start
  }

  Future<void> _fetchLikedComments() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print("User ID is null");
      return;
    }

    try {
      final response = await supabase.from('likes').select('comment_id').eq('liker_user_id', userId).not('comment_id', 'is', null);
      print("Fetched likes for $userId: $response"); // Debugging

      final Map<String, bool> likedPosts = {
        for (var like in response)
          if (like['comment_id'] != null) like['comment_id'] as String: true,
      };

      state = likedPosts;

      // Save likes per user ID in Hive
      _likedCommentsBox.put(userId, likedPosts);

      print("Updated state and cache for $userId: $state");
    } catch (e) {
      print("Error fetching liked posts: $e");
    }
  }

  // *Toggle Like (Optimistic Update with Hive)*
  Future<void> toggleLike({
    required String commentId,
    required String likerId,
    required String posterId,
  }) async {
    final isLiked = state[commentId] ?? false;

    try {
      // Optimistically update state
      state = {...state, commentId: !isLiked};

      // Get existing cached likes for this user
      final userLikes = _likedCommentsBox.get(likerId, defaultValue: {}) ?? {};
      userLikes[commentId] = !isLiked;
      _likedCommentsBox.put(likerId, userLikes);

      if (isLiked) {
        // Unlike the post
        await supabase.from('likes').delete().match({
          'liker_user_id': likerId,
          'comment_id': commentId,
          'liked_user_id': posterId,
        });
      } else {
        // Like the post
        await supabase.from('likes').insert({
          'liker_user_id': likerId,
          'liked_user_id': posterId,
          'comment_id': commentId,
        });
      }
    } catch (e) {
      print("Error updating like: $e");
      // Revert state on failure
      state = {...state, commentId: isLiked};

      final userLikes = _likedCommentsBox.get(likerId, defaultValue: {}) ?? {};
      userLikes[commentId] = isLiked;
      _likedCommentsBox.put(likerId, userLikes);
    }
  }
}

final likeCommentProvider = StateNotifierProvider<LikeNotifierComment, Map<String, bool>>((ref) {
  return LikeNotifierComment();
});

class CommentLikeCountNotifier extends StateNotifier<int> {
  final String commentId;

  CommentLikeCountNotifier({required this.commentId, required int initialLikeCount}) : super(initialLikeCount);

  void updateLikeCount(bool isLiked) {
    state = isLiked ? state + 1 : state - 1;
  }
}

final commentLikeCountProvider = StateNotifierProvider.family<CommentLikeCountNotifier, int, ({String commentId, int initialLikeCount})>(
  (ref, params) => CommentLikeCountNotifier(commentId: params.commentId, initialLikeCount: params.initialLikeCount),
);
