import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Auth/AuthMethods.dart';
import '../Classes/Comment.dart';
import '../Classes/Post.dart';
import '../main.dart';

final postsProvider = StreamProvider<List<Post>>((ref) async* {
  // Watch the Firebase auth state
  final authStateAsync = ref.watch(firebaseAuthProvider);

  // Return an empty list while loading auth state
  if (authStateAsync.isLoading) {
    yield [];
    return;
  }

  // If there's an error or user is null (logged out), yield empty list
  if (authStateAsync.hasError || authStateAsync.value == null) {
    yield [];
    return;
  }

  final currentUserId = authStateAsync.value!.uid;

  try {
    // Create a stream that can be cancelled
    final controller = StreamController<List<Post>>();

    // Set up the Supabase stream
    final subscription = supabase.from('posts').stream(primaryKey: ['id']).order('created_at', ascending: false).map((data) => data.map((json) => Post.fromJson(json)).toList()).listen(
          (allPosts) async {
            try {
              // Get unique user IDs from posts (excluding current user)
              final uniqueUserIds = allPosts.map((post) => post.userId).where((userId) => userId != currentUserId).toSet().toList();

              if (uniqueUserIds.isEmpty) {
                // Only current user's posts, return all
                controller.add(allPosts);
                return;
              }

              // Batch check interactions for all unique users
              List<bool> canInteractResults = [];
              for (String userId in uniqueUserIds) {
                final canInteract = await supabase.rpc('can_users_interact', params: {
                  'user1_id': currentUserId,
                  'user2_id': userId,
                });
                canInteractResults.add(canInteract);
              }

              // Create a map of userId -> canInteract for quick lookup
              final interactionMap = Map<String, bool>.fromIterables(
                uniqueUserIds,
                canInteractResults,
              );

              // Filter posts based on interaction capability
              final filteredPosts = allPosts.where((post) {
                // Always show own posts
                if (post.userId == currentUserId) return true;

                // Check if can interact with post author
                return interactionMap[post.userId] ?? false;
              }).toList();

              controller.add(filteredPosts);
            } catch (filterError) {
              print('Error filtering posts: $filterError');
              // If filtering fails, add all posts to avoid breaking the UI
              controller.add(allPosts);
            }
          },
          onError: (error) {
            print('Supabase stream error: $error');
            controller.addError(error);
          },
        );

    // Make sure to close the subscription when the provider is disposed
    ref.onDispose(() {
      subscription.cancel();
      controller.close();
    });

    // Yield posts from the controller
    await for (final posts in controller.stream) {
      yield posts;
    }
  } catch (e) {
    print('Posts provider error: $e');
    rethrow;
  }
});

final commentsProvider = StreamProvider.family<List<Comment>, String>((ref, postId) async* {
  // Watch the Firebase auth state
  final authStateAsync = ref.watch(firebaseAuthProvider);

  // Return an empty list while loading auth state
  if (authStateAsync.isLoading) {
    yield [];
    return;
  }

  // If there's an error or user is null (logged out), yield empty list
  if (authStateAsync.hasError || authStateAsync.value == null) {
    yield [];
    return;
  }

  final currentUserId = authStateAsync.value!.uid;

  try {
    // Create a stream that can be cancelled
    final controller = StreamController<List<Comment>>();

    // Set up the Supabase stream for comments on specific post
    final subscription = supabase.from('comments').stream(primaryKey: ['id']).eq('post_id', postId).map((data) => data.map((json) => Comment.fromJson(json)).toList()).listen(
          (allComments) async {
            try {
              // Get unique user IDs from comments (excluding current user)
              final uniqueUserIds = allComments
                  .map((comment) => comment.userId) // Adjust field name if different
                  .where((userId) => userId != currentUserId)
                  .toSet()
                  .toList();

              if (uniqueUserIds.isEmpty) {
                // Only current user's comments, return all
                controller.add(allComments);
                return;
              }

              // Batch check interactions for all unique users
              List<bool> canInteractResults = [];
              for (String userId in uniqueUserIds) {
                final canInteract = await supabase.rpc('can_users_interact', params: {
                  'user1_id': currentUserId,
                  'user2_id': userId,
                });
                canInteractResults.add(canInteract);
              }

              // Create a map of userId -> canInteract for quick lookup
              final interactionMap = Map<String, bool>.fromIterables(
                uniqueUserIds,
                canInteractResults,
              );

              // Filter comments based on interaction capability
              final filteredComments = allComments.where((comment) {
                // Always show own comments
                if (comment.userId == currentUserId) return true;

                // Check if can interact with comment author
                return interactionMap[comment.userId] ?? false;
              }).toList();

              controller.add(filteredComments);
            } catch (filterError) {
              print('Error filtering comments: $filterError');
              // If filtering fails, add all comments to avoid breaking the UI
              controller.add(allComments);
            }
          },
          onError: (error) {
            print('Supabase comments stream error: $error');
            controller.addError(error);
          },
        );

    // Make sure to close the subscription when the provider is disposed
    ref.onDispose(() {
      subscription.cancel();
      controller.close();
    });

    // Yield comments from the controller
    await for (final comments in controller.stream) {
      yield comments;
    }
  } catch (e) {
    print('Comments provider error: $e');
    rethrow;
  }
});

class PostCommentCountNotifier extends FamilyNotifier<int, String> {
  @override
  int build(String postId) {
    // Get the initial count from the postsProvider
    final posts = ref.watch(postsProvider).maybeWhen(
          data: (posts) => posts.firstWhere((p) => p.postId == postId).commentCount,
          orElse: () => 0,
        );
    return posts;
  }

  void increment() {
    state = state + 1;
  }

  void decrement() {
    state = state - 1;
  }
}

final postCommentCountProvider = NotifierProvider.family<PostCommentCountNotifier, int, String>(
  PostCommentCountNotifier.new,
);
