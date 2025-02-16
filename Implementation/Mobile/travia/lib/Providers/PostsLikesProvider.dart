import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../main.dart';

class LikeNotifierPost extends StateNotifier<Map<String, bool>> {
  final Box<Map<String, bool>> _likedPostsBox = Hive.box("liked_posts_${FirebaseAuth.instance.currentUser?.uid}");

  LikeNotifierPost() : super({}) {
    _fetchLikedPosts();
  }

  Future<void> _fetchLikedPosts() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print("User ID is null");
      return;
    }

    try {
      final response = await supabase.from('likes').select('post_id').eq('liker_user_id', userId).not('post_id', 'is', null);

      print("Fetched likes for $userId: $response");

      final Map<String, bool> likedPosts = {
        for (var like in response) like['post_id'] as String: true,
      };

      state = likedPosts;

      // Save likes per user ID in Hive
      _likedPostsBox.put(userId, likedPosts);

      print("Updated state and cache for $userId: $state");
    } catch (e) {
      print("Error fetching liked posts: $e");
    }
  }

  // *Toggle Like (Optimistic Update with Hive)*
  Future<void> toggleLike({
    required String postId,
    required String likerId,
    required String posterId,
  }) async {
    final isLiked = state[postId] ?? false;

    try {
      // Optimistically update state
      state = {...state, postId: !isLiked};

      // Get existing cached likes for this user
      final userLikes = _likedPostsBox.get(likerId, defaultValue: {}) ?? {};
      userLikes[postId] = !isLiked;
      _likedPostsBox.put(likerId, userLikes);

      if (isLiked) {
        // Unlike the post
        await supabase.from('likes').delete().match({
          'liker_user_id': likerId,
          'post_id': postId,
          'liked_user_id': posterId,
        });
      } else {
        // Like the post
        await supabase.from('likes').insert({
          'liker_user_id': likerId,
          'liked_user_id': posterId,
          'post_id': postId,
        });
      }
    } catch (e) {
      print("Error updating like: $e");
      // Revert state on failure
      state = {...state, postId: isLiked};

      final userLikes = _likedPostsBox.get(likerId, defaultValue: {}) ?? {};
      userLikes[postId] = isLiked;
      _likedPostsBox.put(likerId, userLikes);
    }
  }
}

final likePostProvider = StateNotifierProvider<LikeNotifierPost, Map<String, bool>>((ref) {
  return LikeNotifierPost();
});

class PostLikeCountNotifier extends StateNotifier<int> {
  final String postId;

  PostLikeCountNotifier({required this.postId, required int initialLikeCount}) : super(initialLikeCount);

  void updateLikeCount(bool isLiked) {
    state = isLiked ? state + 1 : state - 1;
  }
}

final postLikeCountProvider = StateNotifierProvider.family<PostLikeCountNotifier, int, ({String postId, int initialLikeCount})>(
  (ref, params) => PostLikeCountNotifier(postId: params.postId, initialLikeCount: params.initialLikeCount),
);
