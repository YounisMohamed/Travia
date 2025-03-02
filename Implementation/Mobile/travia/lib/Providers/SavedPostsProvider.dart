import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';

class SavedPostsNotifier extends StateNotifier<Map<String, bool>> {
  SavedPostsNotifier() : super({}) {
    _fetchSavedPosts();
  }

  Future<void> _fetchSavedPosts() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print("User ID is null");
      return;
    }

    try {
      final response = await supabase.from('users').select('saved_posts').eq('id', userId).single();

      if (response['saved_posts'] != null) {
        final List<dynamic> savedPosts = response['saved_posts'];
        state = {for (var postId in savedPosts) postId as String: true};
      }
    } catch (e) {
      print("Error fetching saved posts: $e");
    }
  }

  // *Toggle Save (Optimistic Update)*
  Future<void> toggleSavePost(String userId, String postId) async {
    final isSaved = state[postId] ?? false;

    try {
      // Optimistically update state
      state = {...state, postId: !isSaved};

      if (isSaved) {
        // Remove from saved posts
        await supabase.rpc('remove_saved_post', params: {
          'user_id': userId,
          'post_id': postId,
        });
      } else {
        // Add to saved posts
        await supabase.rpc('add_saved_post', params: {
          'user_id': userId,
          'post_id': postId,
        });
      }
    } catch (e) {
      print("Error updating saved post: $e");
      // Revert state on failure
      state = {...state, postId: isSaved};
    }
  }
}

final savedPostsProvider = StateNotifierProvider<SavedPostsNotifier, Map<String, bool>>((ref) {
  return SavedPostsNotifier();
});
