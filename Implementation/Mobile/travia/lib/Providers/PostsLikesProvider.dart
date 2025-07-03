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
      // Optimistically update state
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
  final String postId;
  final Ref ref;

  PostReactionCountNotifier({
    required this.postId,
    required this.ref,
    required int likes,
    required int dislikes,
  }) : super({'likes': likes, 'dislikes': dislikes}) {
    // Set up the listener after initialization
    _setupListener();
  }

  void _setupListener() {
    ref.listen<Map<String, String?>>(
      likePostProvider,
      (previous, next) {
        final previousReaction = previous?[postId];
        final currentReaction = next[postId];

        // Only update if the reaction for this post changed
        if (previousReaction != currentReaction) {
          updateReaction(from: previousReaction, to: currentReaction);
        }
      },
      fireImmediately: false,
    );
  }

  void updateReaction({required String? from, required String? to}) {
    // Create a new map to ensure state change detection
    final copy = Map<String, int>.from(state);

    if (from != null && copy.containsKey(from)) {
      copy[from] = (copy[from] ?? 1) - 1;
      if (copy[from]! < 0) copy[from] = 0;
    }

    if (to != null) {
      copy[to] = (copy[to] ?? 0) + 1;
    }

    // Force state update by creating a new map
    state = Map<String, int>.from(copy);
  }
}

// Use autoDispose to ensure fresh state for each post
final postReactionCountProvider = StateNotifierProvider.autoDispose.family<PostReactionCountNotifier, Map<String, int>, ({String postId, int likes, int dislikes})>(
  (ref, args) {
    return PostReactionCountNotifier(
      postId: args.postId,
      ref: ref,
      likes: args.likes,
      dislikes: args.dislikes,
    );
  },
);
