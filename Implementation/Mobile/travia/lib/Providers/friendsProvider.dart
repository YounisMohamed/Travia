import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Classes/UserSupabase.dart';
import '../main.dart';

// Model for the friends data
class FriendsData {
  final List<UserModel> followers;
  final List<UserModel> following;
  final List<UserModel> discoverUsers;

  FriendsData({
    required this.followers,
    required this.following,
    required this.discoverUsers,
  });

  FriendsData copyWith({
    List<UserModel>? followers,
    List<UserModel>? following,
    List<UserModel>? discoverUsers,
  }) {
    return FriendsData(
      followers: followers ?? this.followers,
      following: following ?? this.following,
      discoverUsers: discoverUsers ?? this.discoverUsers,
    );
  }
}

// Main provider for friends data
final friendsDataProvider = StreamProvider.family<FriendsData, String>((ref, currentUserId) async* {
  try {
    final controller = StreamController<FriendsData>();

    // Set up the Supabase stream for the current user to get their following/friend lists
    final userSubscription = supabase.from('users').stream(primaryKey: ['id']).eq('id', currentUserId).listen(
          (userData) async {
            if (userData.isEmpty) {
              controller.addError(Exception('Current user not found'));
              return;
            }

            final currentUser = userData.first;
            final List<String> followingIds = List<String>.from(currentUser['following_ids'] ?? []);
            final List<String> friendIds = List<String>.from(currentUser['friend_ids'] ?? []);

            // Fetch followers (users who have currentUserId in their following_ids)
            final followersData = await supabase.from('users').select().contains('following_ids', [currentUserId]);

            final followers = followersData.map((user) => UserModel.fromMap(user)).toList();

            // Fetch following users
            List<UserModel> following = [];
            if (followingIds.isNotEmpty) {
              final followingData = await supabase.from('users').select().inFilter('id', followingIds);

              following = followingData.map((user) => UserModel.fromMap(user)).toList();
            }

            // Fetch discover users (exclude current user, followers, and following)
            final excludeIds = {currentUserId, ...followingIds, ...friendIds}.toList();

            final discoverData = await supabase.from('users').select().not('id', 'in', excludeIds).limit(50);

            final discoverUsers = discoverData.map((user) => UserModel.fromMap(user)).toList();

            // Sort discover users by follower count (descending order - most followers first)
            discoverUsers.sort((a, b) {
              final aFollowerCount = (a.followingIds.length);
              final bFollowerCount = (b.followingIds.length);
              return bFollowerCount.compareTo(aFollowerCount);
            });

            // Emit the combined data
            controller.add(FriendsData(
              followers: followers,
              following: following,
              discoverUsers: discoverUsers,
            ));
          },
          onError: (error) {
            print('Friends data stream error: $error');
            controller.addError(error);
          },
        );

    // Clean up when provider is disposed
    ref.onDispose(() {
      userSubscription.cancel();
      controller.close();
    });

    // Yield updates from the controller
    await for (final friendsData in controller.stream) {
      yield friendsData;
    }
  } catch (e) {
    print('Friends provider error: $e');
    rethrow;
  }
});

// Individual providers for each tab (optional, for more granular access)
final followersProvider = Provider.family<AsyncValue<List<UserModel>>, String>((ref, userId) {
  final friendsData = ref.watch(friendsDataProvider(userId));
  return friendsData.when(
    data: (data) => AsyncValue.data(data.followers),
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

final followingProvider = Provider.family<AsyncValue<List<UserModel>>, String>((ref, userId) {
  final friendsData = ref.watch(friendsDataProvider(userId));
  return friendsData.when(
    data: (data) => AsyncValue.data(data.following),
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

final discoverUsersProvider = Provider.family<AsyncValue<List<UserModel>>, String>((ref, userId) {
  final friendsData = ref.watch(friendsDataProvider(userId));
  return friendsData.when(
    data: (data) => AsyncValue.data(data.discoverUsers),
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

// Friends actions provider for follow/unfollow functionality
class FriendsActionsNotifier extends StateNotifier<Set<String>> {
  FriendsActionsNotifier() : super({});

  // Follow a user
  Future<void> followUser(String currentUserId, String targetUserId) async {
    // Add to loading state
    state = {...state, targetUserId};

    try {
      // Get current user's following list
      final currentUserData = await supabase.from('users').select('following_ids').eq('id', currentUserId).single();

      final List<String> currentFollowing = List<String>.from(currentUserData['following_ids'] ?? []);

      // Add target user to following list if not already following
      if (!currentFollowing.contains(targetUserId)) {
        currentFollowing.add(targetUserId);

        // Update current user's following_ids
        await supabase.from('users').update({'following_ids': currentFollowing}).eq('id', currentUserId);

        // Get target user's friend list
        final targetUserData = await supabase.from('users').select('friend_ids').eq('id', targetUserId).single();

        final List<String> targetFriends = List<String>.from(targetUserData['friend_ids'] ?? []);

        // Add current user to target user's friends list if not already there
        if (!targetFriends.contains(currentUserId)) {
          targetFriends.add(currentUserId);

          await supabase.from('users').update({'friend_ids': targetFriends}).eq('id', targetUserId);
        }
      }
    } catch (e) {
      print('Error following user: $e');
      rethrow;
    } finally {
      // Remove from loading state
      final newState = Set<String>.from(state);
      newState.remove(targetUserId);
      state = newState;
    }
  }

  // Unfollow a user (delete from following)
  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    // Add to loading state
    state = {...state, targetUserId};

    try {
      // Get current user's following list
      final currentUserData = await supabase.from('users').select('following_ids').eq('id', currentUserId).single();

      final List<String> currentFollowing = List<String>.from(currentUserData['following_ids'] ?? []);

      // Remove target user from following list
      currentFollowing.remove(targetUserId);

      // Update current user's following_ids
      await supabase.from('users').update({'following_ids': currentFollowing}).eq('id', currentUserId);

      // Get target user's friend list
      final targetUserData = await supabase.from('users').select('friend_ids').eq('id', targetUserId).single();

      final List<String> targetFriends = List<String>.from(targetUserData['friend_ids'] ?? []);

      // Remove current user from target user's friends list
      targetFriends.remove(currentUserId);

      await supabase.from('users').update({'friend_ids': targetFriends}).eq('id', targetUserId);
    } catch (e) {
      print('Error unfollowing user: $e');
      rethrow;
    } finally {
      // Remove from loading state
      final newState = Set<String>.from(state);
      newState.remove(targetUserId);
      state = newState;
    }
  }

  // Remove a follower (delete from followers)
  Future<void> removeFollower(String currentUserId, String followerUserId) async {
    // Add to loading state
    state = {...state, followerUserId};

    try {
      // Get follower's following list
      final followerUserData = await supabase.from('users').select('following_ids').eq('id', followerUserId).single();

      final List<String> followerFollowing = List<String>.from(followerUserData['following_ids'] ?? []);

      // Remove current user from follower's following list
      followerFollowing.remove(currentUserId);

      // Update follower's following_ids
      await supabase.from('users').update({'following_ids': followerFollowing}).eq('id', followerUserId);

      // Get current user's friend list
      final currentUserData = await supabase.from('users').select('friend_ids').eq('id', currentUserId).single();

      final List<String> currentFriends = List<String>.from(currentUserData['friend_ids'] ?? []);

      // Remove follower from current user's friends list
      currentFriends.remove(followerUserId);

      await supabase.from('users').update({'friend_ids': currentFriends}).eq('id', currentUserId);
    } catch (e) {
      print('Error removing follower: $e');
      rethrow;
    } finally {
      // Remove from loading state
      final newState = Set<String>.from(state);
      newState.remove(followerUserId);
      state = newState;
    }
  }

  // Check if an action is in progress for a specific user
  bool isActionInProgress(String userId) {
    return state.contains(userId);
  }
}

// Provider for friends actions
final friendsActionsProvider = StateNotifierProvider<FriendsActionsNotifier, Set<String>>(
  (ref) => FriendsActionsNotifier(),
);

// Helper providers for easier access to actions
final followUserProvider = Provider((ref) {
  final notifier = ref.read(friendsActionsProvider.notifier);
  return notifier.followUser;
});

final unfollowUserProvider = Provider((ref) {
  final notifier = ref.read(friendsActionsProvider.notifier);
  return notifier.unfollowUser;
});

final removeFollowerProvider = Provider((ref) {
  final notifier = ref.read(friendsActionsProvider.notifier);
  return notifier.removeFollower;
});

final isActionInProgressProvider = Provider.family<bool, String>((ref, userId) {
  final loadingUsers = ref.watch(friendsActionsProvider);
  return loadingUsers.contains(userId);
});
