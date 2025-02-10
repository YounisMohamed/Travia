import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../Classes/Comment.dart';
import '../Classes/Post.dart';
import '../database/FetchingMethods.dart';
import '../main.dart';

class PostsNotifier extends AsyncNotifier<List<Post>> {
  @override
  Future<List<Post>> build() async {
    return await fetchPosts();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => fetchPosts());
  }
}

final postsProvider = AsyncNotifierProvider<PostsNotifier, List<Post>>(() {
  return PostsNotifier();
});

class CommentsNotifier extends FamilyAsyncNotifier<List<Comment>, String> {
  @override
  Future<List<Comment>> build(String postId) async {
    return await fetchComments(postId);
  }

  Future<void> refresh() async {
    if (state case AsyncData(:final value)) {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() => fetchComments(value.first.postId));
    }
  }
}

// Family provider for fetching comments by post ID
final commentsProvider = AsyncNotifierProvider.family<CommentsNotifier, List<Comment>, String>(CommentsNotifier.new);

class LikeNotifier extends StateNotifier<Map<String, bool>> {
  LikeNotifier() : super({}) {
    _fetchLikedPosts(); // Load liked posts from database on app start
    _subscribeToLikeChanges(); // Listen for real-time updates
  }

  // **Fetch Liked Posts from Database**
  Future<void> _fetchLikedPosts() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print("User ID is null");
      return;
    }

    try {
      final response = await supabase.from('likes').select('post_id').eq('user_id', userId);

      print("Fetched likes: $response"); // Debugging

      if (response.isNotEmpty) {
        final Map<String, bool> likedPosts = {
          for (var like in response)
            if (like['post_id'] != null) like['post_id'] as String: true,
        };

        state = likedPosts;
        print("Updated state: $state");
      } else {
        print("No likes found for user.");
        state = {}; // Ensure state is empty if there are no likes
      }
    } catch (e) {
      print("Error fetching liked posts: $e");
    }
  }

  // **Toggle Like (Now Checks Database)**
  Future<void> toggleLike({
    required String postId,
    required String likerId,
    required String posterId,
  }) async {
    final isLiked = state[postId] ?? false; // Check if post is already liked

    try {
      if (isLiked) {
        // Unlike the post
        await supabase.from('likes').delete().match({
          'user_id': likerId,
          'post_id': postId,
          'liked_user_id': posterId,
        });
      } else {
        // Like the post
        await supabase.from('likes').insert({
          'user_id': likerId,
          'liked_user_id': posterId,
          'post_id': postId,
        });
      }

      // Update UI state immediately
      state = {...state, postId: !isLiked};
    } catch (e) {
      print("Error updating like: $e");
    }
  }

  // **Subscribe to Real-Time Like Changes**
  void _subscribeToLikeChanges() {
    supabase
        .channel('likes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'likes',
          callback: (payload) {
            _fetchLikedPosts(); // Refresh likes when database updates
          },
        )
        .subscribe();
  }
}

// **Provide the LikeNotifier**
final likeProvider = StateNotifierProvider<LikeNotifier, Map<String, bool>>((ref) {
  return LikeNotifier();
});

class PostLikeCountNotifier extends FamilyAsyncNotifier<int, String> {
  @override
  Future<int> build(String postId) async {
    _subscribeToLikeChanges(postId);
    return _fetchLikeCount(postId);
  }

  // **Fetch the Like Count for a Specific Post**
  Future<int> _fetchLikeCount(String postId) async {
    try {
      final response = await supabase.from('likes').select('id').eq('post_id', postId);

      return response.length;
    } catch (e) {
      print("Error fetching like count: $e");
      return 0;
    }
  }

  // **Subscribe to Real-Time Updates for Like Count**
  void _subscribeToLikeChanges(String postId) {
    supabase
        .channel('likes_count_$postId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'likes',
          callback: (payload) {
            ref.invalidateSelf();
          },
        )
        .subscribe();
  }
}

// **Provide the Like Count Notifier**
final postLikeCountProvider = AsyncNotifierProvider.family<PostLikeCountNotifier, int, String>(
  () => PostLikeCountNotifier(),
);
