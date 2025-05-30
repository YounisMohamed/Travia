import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Classes/Post.dart';
import '../Classes/UserSupabase.dart';
import '../main.dart';
import 'PostsCommentsProviders.dart';

final userStreamProvider = StreamProvider.family<UserModel, String>((ref, profileId) async* {
  try {
    // Create a stream controller that can be cancelled
    final controller = StreamController<UserModel>();

    // Set up the Supabase stream for the specific user
    final subscription = supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', profileId)
        .map((data) {
          if (data.isEmpty) {
            throw Exception('User not found');
          }
          return UserModel.fromMap(data.first);
        })
        .listen(
          (user) => controller.add(user),
          onError: (error) {
            print('Supabase user stream error: $error');
            controller.addError(error);
          },
        );

    // Make sure to close the subscription when the provider is disposed
    ref.onDispose(() {
      subscription.cancel();
      controller.close();
    });

    // Yield user updates from the controller
    await for (final user in controller.stream) {
      yield user;
    }
  } catch (e) {
    print('User provider error: $e');
    rethrow;
  }
});

final filteredPostsProvider = Provider.family<AsyncValue<List<Post>>, List<String>>((ref, postIds) {
  final postsAsync = ref.watch(postsProvider);

  return postsAsync.when(
    data: (posts) {
      final filtered = posts.where((p) => postIds.contains(p.postId)).toList();
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

final selectedPostTabProvider = StateProvider<int>((ref) => 0); // 0 = Posts, 1 = Liked, etc.

final profileLoadingProvider = StateProvider<bool>((ref) => false);
final profileTitleProvider = StateProvider<String?>((ref) => null);
final profilePictureProvider = StateProvider<String?>((ref) => null);
