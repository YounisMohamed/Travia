import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Classes/Post.dart';
import '../Classes/UserSupabase.dart';
import '../main.dart';
import 'PostsCommentsProviders.dart';

final followStatusProvider = StateNotifierProvider.family<FollowStatusNotifier, bool, String>(
  (ref, profileUserId) => FollowStatusNotifier(profileUserId),
);

class FollowStatusNotifier extends StateNotifier<bool> {
  final String profileUserId;
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;

  FollowStatusNotifier(this.profileUserId) : super(false) {
    _loadFollowStatus();
  }

  Future<void> _loadFollowStatus() async {
    final res = await supabase.from('users').select('following_ids').eq('id', currentUserId).single();

    final followingIds = List<String>.from(res['following_ids'] ?? []);
    state = followingIds.contains(profileUserId);
  }

  Future<void> toggleFollow() async {
    // Store the current state
    final isCurrentlyFollowing = state;

    // Update state optimistically for better UI responsiveness
    state = !isCurrentlyFollowing;

    try {
      final currentUserRes = await supabase.from('users').select('following_ids').eq('id', currentUserId).single();

      final profileUserRes = await supabase.from('users').select('friend_ids').eq('id', profileUserId).single();

      List<String> followingIds = List<String>.from(currentUserRes['following_ids'] ?? []);
      List<String> friendIds = List<String>.from(profileUserRes['friend_ids'] ?? []);

      if (!isCurrentlyFollowing) {
        // Follow action: Add IDs
        if (!followingIds.contains(profileUserId)) {
          followingIds.add(profileUserId);
        }
        if (!friendIds.contains(currentUserId)) {
          friendIds.add(currentUserId);
        }
      } else {
        followingIds.remove(profileUserId);
        friendIds.remove(currentUserId);
      }

      await Future.wait([
        supabase.from('users').update({
          'following_ids': followingIds,
        }).eq('id', currentUserId),
        supabase.from('users').update({
          'friend_ids': friendIds,
        }).eq('id', profileUserId)
      ]);
    } catch (e) {
      print('Error updating follow/friend lists: $e');
      state = isCurrentlyFollowing;
    }
  }
}

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
