import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Classes/Post.dart';
import '../Classes/UserSupabase.dart';
import '../Services/BlockService.dart';
import '../main.dart';
import 'AllUsersProvider.dart';
import 'PostsCommentsProviders.dart';

final userStreamProvider = StreamProvider.family<UserModel, String>((ref, profileId) async* {
  try {
    final controller = StreamController<UserModel>();

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

    ref.onDispose(() {
      subscription.cancel();
      controller.close();
    });

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
      final postMap = {for (var post in posts) post.postId: post};
      final filtered = postIds.map((id) => postMap[id]).where((post) => post != null).cast<Post>().toList();
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

Future<void> refreshProviders(WidgetRef ref, String profileUserId) async {
  print('🔄 Starting profile refresh...');

  try {
    // Invalidate all providers that might be stale
    ref.invalidate(postsProvider);
    ref.invalidate(userStreamProvider(profileUserId));
    ref.invalidate(usersProvider); // Global users provider
    ref.invalidate(blockStatusProvider(profileUserId));

    // If it's own profile, also invalidate the current user's data
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null && currentUserId != profileUserId) {
      ref.invalidate(userStreamProvider(currentUserId));
    }

    print('Profile refresh completed');
  } catch (e) {
    print('Error during refresh: $e');
  }
}

final selectedPostTabProvider = StateProvider<int>((ref) => 0); // 0 = Posts, 1 = Liked, etc.

final profileLoadingProvider = StateProvider<bool>((ref) => false);
final profileTitleProvider = StateProvider<String?>((ref) => null);
final profilePictureProvider = StateProvider<String?>((ref) => null);
