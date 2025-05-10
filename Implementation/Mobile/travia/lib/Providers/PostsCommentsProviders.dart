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

  try {
    // Create a stream that can be cancelled
    final controller = StreamController<List<Post>>();

    // Set up the Supabase stream
    final subscription = supabase.from('posts').stream(primaryKey: ['id']).order('created_at', ascending: false).map((data) => data.map((json) => Post.fromJson(json)).toList()).listen(
          (posts) => controller.add(posts),
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

final commentsProvider = StreamProvider.family<List<Comment>, String>((ref, postId) {
  return supabase.from('comments').stream(primaryKey: ['id']).eq('post_id', postId).map((data) => data.map((json) => Comment.fromJson(json)).toList());
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
