import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';

class LikeNotifierPost extends StateNotifier<Map<String, String?>> {
  LikeNotifierPost() : super({}) {
    _fetchPostReactions();
  }

  Future<void> _fetchPostReactions() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final response = await supabase.from('likes').select('post_id, type').eq('liker_user_id', userId).not('post_id', 'is', null);

      final Map<String, String?> reactions = {
        for (var row in response) row['post_id'] as String: row['type'] as String?,
      };

      state = reactions;
    } catch (e) {
      print("[likes] Error fetching reactions: $e");
    }
  }

  Future<void> toggleReaction({
    required String postId,
    required String likerId,
    required String posterId,
    required String reactionType, // 'like' or 'dislike'
  }) async {
    final current = state[postId];

    final isSameReaction = current == reactionType;
    final newState = isSameReaction ? null : reactionType;

    try {
      state = {...state, postId: newState};

      if (isSameReaction) {
        await supabase.from('likes').delete().match({
          'liker_user_id': likerId,
          'post_id': postId,
        });
      } else {
        await supabase.from('likes').upsert({
          'liker_user_id': likerId,
          'liked_user_id': posterId,
          'post_id': postId,
          'type': reactionType,
        }, onConflict: 'liker_user_id, post_id');
      }
    } catch (e) {
      state = {...state, postId: current}; // rollback
    }
  }
}

final likePostProvider = StateNotifierProvider<LikeNotifierPost, Map<String, String?>>((ref) {
  return LikeNotifierPost();
});

class PostReactionCountNotifier extends StateNotifier<Map<String, int>> {
  PostReactionCountNotifier({required int likes, required int dislikes}) : super({'likes': likes, 'dislikes': dislikes});

  void updateReaction({required String? from, required String? to}) {
    final copy = Map<String, int>.from(state);

    if (from != null) copy[from] = (copy[from] ?? 1) - 1;
    if (to != null) copy[to] = (copy[to] ?? 0) + 1;

    state = copy;
  }
}

final postReactionCountProvider = StateNotifierProvider.family<PostReactionCountNotifier, Map<String, int>, ({String postId, int likes, int dislikes})>(
  (ref, args) => PostReactionCountNotifier(likes: args.likes, dislikes: args.dislikes),
);
