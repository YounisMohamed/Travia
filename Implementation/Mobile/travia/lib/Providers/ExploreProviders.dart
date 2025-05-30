import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Auth/AuthMethods.dart';
import '../Classes/Post.dart';
import '../main.dart';
import 'PostsCommentsProviders.dart';
import 'ProfileProviders.dart';

final followingPostsProvider = StreamProvider<List<Post>>((ref) async* {
  final authStateAsync = ref.watch(firebaseAuthProvider);

  if (authStateAsync.isLoading || authStateAsync.hasError || authStateAsync.value == null) {
    yield [];
    return;
  }

  final userId = authStateAsync.value!.uid;
  final currentUserAsync = ref.watch(userStreamProvider(userId));

  if (currentUserAsync.isLoading) {
    yield [];
    return;
  }

  if (currentUserAsync.hasError || currentUserAsync.value == null) {
    yield [];
    return;
  }

  final currentUser = currentUserAsync.value!;
  final followingIds = currentUser.followingIds;

  // If user is not following anyone, return empty list
  if (followingIds.isEmpty) {
    yield [];
    return;
  }

  try {
    final controller = StreamController<List<Post>>();

    final subscription = supabase
        .from('posts')
        .stream(primaryKey: ['id'])
        .inFilter('user_id', followingIds)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => Post.fromJson(json)).toList())
        .listen(
          (posts) => controller.add(posts),
          onError: (error) {
            print('Following posts stream error: $error');
            controller.addError(error);
          },
        );

    ref.onDispose(() {
      subscription.cancel();
      controller.close();
    });

    await for (final posts in controller.stream) {
      yield posts;
    }
  } catch (e) {
    print('Following posts provider error: $e');
    rethrow;
  }
});

// 2. Create a state provider to manage which feed is selected
final selectedFeedProvider = StateProvider<String>((ref) => "For You");

// 3. Create a computed provider that returns the appropriate posts based on selection
final currentFeedPostsProvider = Provider<AsyncValue<List<Post>>>((ref) {
  final selectedFeed = ref.watch(selectedFeedProvider);

  if (selectedFeed == "Following") {
    return ref.watch(followingPostsProvider);
  } else {
    return ref.watch(postsProvider);
  }
});
