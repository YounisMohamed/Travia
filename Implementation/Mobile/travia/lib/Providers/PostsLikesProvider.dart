import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';

class LikeNotifierPost extends StateNotifier<Map<String, bool>> {
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

      final Map<String, bool> likedPosts = {
        for (var like in response) like['post_id'] as String: true,
      };

      state = likedPosts;
    } catch (e) {
      print("Error fetching liked posts: $e");
    }
  }

  // *Toggle Like (Optimistic Update)*
  Future<void> toggleLike({
    required String postId,
    required String likerId,
    required String posterId,
  }) async {
    final isLiked = state[postId] ?? false;

    try {
      // Optimistically update state
      state = {...state, postId: !isLiked};

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
