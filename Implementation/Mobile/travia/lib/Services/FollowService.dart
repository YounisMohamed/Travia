import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/DatabaseMethods.dart';
import '../main.dart';
import 'BlockService.dart';

class FollowService {
  static Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    try {
      print('FollowService.isFollowing - Checking if $currentUserId follows $targetUserId');
      final response = await supabase.from('users').select('following_ids').eq('id', currentUserId).single();
      final followingIds = List<String>.from(response['following_ids'] ?? []);
      final isFollowing = followingIds.contains(targetUserId);
      print('FollowService.isFollowing - Result: $isFollowing (following_ids: $followingIds)');
      return isFollowing;
    } catch (e) {
      print('FollowService.isFollowing - Error checking follow status: $e');
      return false;
    }
  }

  static Future<bool> followUser(String currentUserId, String targetUserId) async {
    if (currentUserId == targetUserId) {
      print('FollowService.followUser - Cannot follow self');
      return false;
    }

    try {
      print('FollowService.followUser - Starting follow process: $currentUserId -> $targetUserId');

      final canInteract = await supabase.rpc('can_users_interact', params: {
        'user1_id': currentUserId,
        'user2_id': targetUserId,
      });

      if (!canInteract) {
        print('FollowService.followUser - Cannot follow user: blocked relationship exists');
        return false;
      }

      final results = await Future.wait([
        supabase.from('users').select('following_ids').eq('id', currentUserId).single(),
        supabase.from('users').select('friend_ids').eq('id', targetUserId).single(),
      ]);

      final currentUserData = results[0];
      final targetUserData = results[1];

      List<String> followingIds = List<String>.from(currentUserData['following_ids'] ?? []);
      List<String> friendIds = List<String>.from(targetUserData['friend_ids'] ?? []);

      print('FollowService.followUser - Current following_ids: $followingIds');
      print('FollowService.followUser - Target friend_ids: $friendIds');

      if (followingIds.contains(targetUserId)) {
        print('FollowService.followUser - Already following, returning true');
        return true;
      }

      followingIds.add(targetUserId);
      if (!friendIds.contains(currentUserId)) {
        friendIds.add(currentUserId);
      }

      print('FollowService.followUser - New following_ids: $followingIds');
      print('FollowService.followUser - New friend_ids: $friendIds');

      await Future.wait([
        supabase.from('users').update({'following_ids': followingIds}).eq('id', currentUserId),
        supabase.from('users').update({'friend_ids': friendIds}).eq('id', targetUserId),
      ]);

      print('FollowService.followUser - Database updated successfully');

      Future.microtask(() async {
        try {
          await sendNotification(
            type: 'follow',
            title: "started following you 👥",
            content: "started following you",
            target_user_id: targetUserId,
            source_id: currentUserId,
            sender_user_id: currentUserId,
          );
        } catch (e) {
          print("FollowService.followUser - Follow notification error: $e");
        }
      });

      return true;
    } catch (e) {
      print('FollowService.followUser - Error following user: $e');
      return false;
    }
  }

  static Future<bool> unfollowUser(String currentUserId, String targetUserId) async {
    if (currentUserId == targetUserId) {
      print('FollowService.unfollowUser - Cannot unfollow self');
      return false;
    }

    try {
      print('FollowService.unfollowUser - Starting unfollow process: $currentUserId -> $targetUserId');

      final results = await Future.wait([
        supabase.from('users').select('following_ids').eq('id', currentUserId).single(),
        supabase.from('users').select('friend_ids').eq('id', targetUserId).single(),
      ]);

      final currentUserData = results[0];
      final targetUserData = results[1];

      List<String> followingIds = List<String>.from(currentUserData['following_ids'] ?? []);
      List<String> friendIds = List<String>.from(targetUserData['friend_ids'] ?? []);

      print('FollowService.unfollowUser - Current following_ids: $followingIds');
      print('FollowService.unfollowUser - Target friend_ids: $friendIds');

      final wasFollowing = followingIds.remove(targetUserId);
      final wasInFriends = friendIds.remove(currentUserId);

      print('FollowService.unfollowUser - Removed from following: $wasFollowing');
      print('FollowService.unfollowUser - Removed from friends: $wasInFriends');
      print('FollowService.unfollowUser - New following_ids: $followingIds');
      print('FollowService.unfollowUser - New friend_ids: $friendIds');

      await Future.wait([
        supabase.from('users').update({'following_ids': followingIds}).eq('id', currentUserId),
        supabase.from('users').update({'friend_ids': friendIds}).eq('id', targetUserId),
      ]);

      print('FollowService.unfollowUser - Database updated successfully');

      return true;
    } catch (e) {
      print('FollowService.unfollowUser - Error unfollowing user: $e');
      return false;
    }
  }

  static Future<bool> removeFollower(String currentUserId, String followerUserId) async {
    if (currentUserId == followerUserId) return false;

    try {
      final results = await Future.wait([
        supabase.from('users').select('friend_ids').eq('id', currentUserId).single(),
        supabase.from('users').select('following_ids').eq('id', followerUserId).single(),
      ]);

      final currentUserData = results[0];
      final followerUserData = results[1];

      List<String> friendIds = List<String>.from(currentUserData['friend_ids'] ?? []);
      List<String> followingIds = List<String>.from(followerUserData['following_ids'] ?? []);

      friendIds.remove(followerUserId);
      followingIds.remove(currentUserId);

      await Future.wait([
        supabase.from('users').update({'friend_ids': friendIds}).eq('id', currentUserId),
        supabase.from('users').update({'following_ids': followingIds}).eq('id', followerUserId),
      ]);

      return true;
    } catch (e) {
      print('Error removing follower: $e');
      return false;
    }
  }

  static Future<bool> canUsersInteract(String userId1, String userId2) async {
    try {
      final canInteract = await supabase.rpc('can_users_interact', params: {
        'user1_id': userId1,
        'user2_id': userId2,
      });
      return canInteract;
    } catch (e) {
      print('Error checking user interaction: $e');
      return false;
    }
  }
}

class FollowStateNotifier extends StateNotifier<Map<String, bool>> {
  final String currentUserId;

  FollowStateNotifier(this.currentUserId) : super({});

  Future<void> loadFollowStatus(String targetUserId) async {
    try {
      print('Loading follow status for: $targetUserId');
      final isFollowing = await FollowService.isFollowing(currentUserId, targetUserId);
      print('Follow status loaded from DB - Following: $isFollowing');
      state = {...state, targetUserId: isFollowing};
    } catch (e) {
      print('Error loading follow status: $e');
    }
  }

  Future<bool> toggleFollow(String targetUserId) async {
    try {
      print('Fetching current follow status from database...');
      final actualFollowStatus = await FollowService.isFollowing(currentUserId, targetUserId);
      print('Actual database follow status: $actualFollowStatus');

      state = {...state, targetUserId: actualFollowStatus};

      final isCurrentlyFollowing = actualFollowStatus;
      print('Toggle follow - Verified current status: $isCurrentlyFollowing for $targetUserId');

      if (!isCurrentlyFollowing) {
        print('Checking if users can interact...');
        final canInteract = await FollowService.canUsersInteract(currentUserId, targetUserId);
        print('Can interact result: $canInteract');

        if (!canInteract) {
          print('Cannot follow user: blocked relationship exists');
          return false;
        }
      }

      state = {...state, targetUserId: !isCurrentlyFollowing};
      print('Optimistically updated state to: ${!isCurrentlyFollowing}');

      bool success;
      if (!isCurrentlyFollowing) {
        print('Attempting to follow user...');
        success = await FollowService.followUser(currentUserId, targetUserId);
      } else {
        print('Attempting to unfollow user...');
        success = await FollowService.unfollowUser(currentUserId, targetUserId);
      }

      print('Operation success: $success');

      if (!success) {
        print('Reverting state due to failure');
        state = {...state, targetUserId: isCurrentlyFollowing};
      } else {
        print('Operation completed successfully');

        Future.delayed(Duration(milliseconds: 500), () async {
          final verifyStatus = await FollowService.isFollowing(currentUserId, targetUserId);
          print('Post-operation verification: Following status is now $verifyStatus');
          state = {...state, targetUserId: verifyStatus};
        });
      }

      return success;
    } catch (e) {
      try {
        final actualStatus = await FollowService.isFollowing(currentUserId, targetUserId);
        state = {...state, targetUserId: actualStatus};
        print('Error occurred, reverted to actual database status: $actualStatus');
      } catch (revertError) {
        print('Could not revert to database status: $revertError');
      }
      print('Error toggling follow: $e');
      return false;
    }
  }

  Future<bool> removeFollower(String followerUserId) async {
    try {
      print('Attempting to remove follower: $followerUserId');
      final success = await FollowService.removeFollower(currentUserId, followerUserId);
      print('Remove follower success: $success');
      return success;
    } catch (e) {
      print('Error removing follower: $e');
      return false;
    }
  }

  bool isFollowing(String targetUserId) {
    final status = state[targetUserId] ?? false;
    print('Get follow status for $targetUserId: $status (from state)');
    return status;
  }

  Future<bool> isFollowingFromDatabase(String targetUserId) async {
    try {
      final status = await FollowService.isFollowing(currentUserId, targetUserId);
      print('Get follow status for $targetUserId: $status (from database)');
      return status;
    } catch (e) {
      print('Error getting follow status from database: $e');
      return false;
    }
  }

  Future<void> refreshFollowStatus(String targetUserId) async {
    await loadFollowStatus(targetUserId);
  }

  void forceRefreshFollowStatus(String targetUserId) {
    print('Force refreshing follow status for: $targetUserId');

    final newState = Map<String, bool>.from(state);
    newState.remove(targetUserId);
    state = newState;

    loadFollowStatus(targetUserId);
  }
}

class FollowActionsNotifier extends StateNotifier<Set<String>> {
  FollowActionsNotifier() : super({});

  void addLoading(String userId) {
    state = {...state, userId};
  }

  void removeLoading(String userId) {
    final newState = Set<String>.from(state);
    newState.remove(userId);
    state = newState;
  }

  bool isLoading(String userId) {
    return state.contains(userId);
  }
}

final currentUserProvider = Provider<String>((ref) {
  return FirebaseAuth.instance.currentUser?.uid ?? '';
});

final followStateProvider = StateNotifierProvider<FollowStateNotifier, Map<String, bool>>((ref) {
  final currentUserId = ref.watch(currentUserProvider);
  return FollowStateNotifier(currentUserId);
});

final followActionsProvider = StateNotifierProvider<FollowActionsNotifier, Set<String>>(
  (ref) => FollowActionsNotifier(),
);

final followStatusProvider = Provider.family<bool, String>((ref, targetUserId) {
  final followState = ref.watch(followStateProvider);
  return followState[targetUserId] ?? false;
});

final isFollowActionLoadingProvider = Provider.family<bool, String>((ref, userId) {
  final loadingUsers = ref.watch(followActionsProvider);
  return loadingUsers.contains(userId);
});

class FollowController {
  final Ref ref;

  FollowController(this.ref);

  Future<FollowResult> toggleFollow(String targetUserId) async {
    final actionsNotifier = ref.read(followActionsProvider.notifier);
    final followNotifier = ref.read(followStateProvider.notifier);

    actionsNotifier.addLoading(targetUserId);

    try {
      await followNotifier.loadFollowStatus(targetUserId);

      final isCurrentlyFollowing = followNotifier.isFollowing(targetUserId);
      print('FollowController - Verified following status: $isCurrentlyFollowing for user: $targetUserId');

      final success = await followNotifier.toggleFollow(targetUserId);
      print('FollowController - Operation success: $success');

      if (!success) {
        final currentUserId = ref.read(currentUserProvider);
        final canInteract = await FollowService.canUsersInteract(currentUserId, targetUserId);

        if (!canInteract) {
          return FollowResult.blocked();
        } else {
          return FollowResult.failed('Unknown error occurred');
        }
      }

      return FollowResult.success();
    } catch (e) {
      print('Error in FollowController.toggleFollow: $e');

      if (e.toString().toLowerCase().contains('block') || e.toString().toLowerCase().contains('interact')) {
        return FollowResult.blocked();
      }

      return FollowResult.failed(e.toString());
    } finally {
      actionsNotifier.removeLoading(targetUserId);
    }
  }

  Future<FollowResult> removeFollower(String followerUserId) async {
    final actionsNotifier = ref.read(followActionsProvider.notifier);
    final followNotifier = ref.read(followStateProvider.notifier);

    actionsNotifier.addLoading(followerUserId);

    try {
      print('FollowController - Remove follower - Attempting to remove: $followerUserId');

      final success = await followNotifier.removeFollower(followerUserId);

      print('FollowController - Remove follower - Operation success: $success');

      if (!success) {
        return FollowResult.failed('Failed to remove follower');
      }

      return FollowResult.success();
    } catch (e) {
      print('Error in FollowController.removeFollower: $e');
      return FollowResult.failed(e.toString());
    } finally {
      actionsNotifier.removeLoading(followerUserId);
    }
  }

  Future<void> loadFollowStatus(String targetUserId) async {
    final followNotifier = ref.read(followStateProvider.notifier);
    await followNotifier.loadFollowStatus(targetUserId);
  }

  bool isFollowing(String targetUserId, {bool verifyFromDatabase = false}) {
    if (verifyFromDatabase) {
      final followNotifier = ref.read(followStateProvider.notifier);
      followNotifier.loadFollowStatus(targetUserId);
    }
    return ref.read(followStatusProvider(targetUserId));
  }

  Future<bool> verifyFollowStatus(String targetUserId) async {
    final followNotifier = ref.read(followStateProvider.notifier);
    return await followNotifier.isFollowingFromDatabase(targetUserId);
  }

  bool isLoading(String userId) {
    return ref.read(isFollowActionLoadingProvider(userId));
  }

  Future<FollowResult> blockUser(String targetUserId) async {
    final currentUserId = ref.read(currentUserProvider);
    final actionsNotifier = ref.read(followActionsProvider.notifier);
    final followNotifier = ref.read(followStateProvider.notifier);

    actionsNotifier.addLoading(targetUserId);

    try {
      final success = await BlockService.blockUser(currentUserId, targetUserId);

      if (success) {
        followNotifier.forceRefreshFollowStatus(targetUserId);
        return FollowResult.success();
      } else {
        return FollowResult.failed('Failed to block user');
      }
    } catch (e) {
      print('Error in blockUser: $e');
      return FollowResult.failed(e.toString());
    } finally {
      actionsNotifier.removeLoading(targetUserId);
    }
  }
}

class FollowResult {
  final bool isSuccess;
  final bool isBlocked;
  final String? errorMessage;

  FollowResult._({required this.isSuccess, required this.isBlocked, this.errorMessage});

  factory FollowResult.success() => FollowResult._(isSuccess: true, isBlocked: false);
  factory FollowResult.blocked() => FollowResult._(isSuccess: false, isBlocked: true);
  factory FollowResult.failed(String message) => FollowResult._(isSuccess: false, isBlocked: false, errorMessage: message);
}

final followControllerProvider = Provider<FollowController>((ref) {
  return FollowController(ref);
});
