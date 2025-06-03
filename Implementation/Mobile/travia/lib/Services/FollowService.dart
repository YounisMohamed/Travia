import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/DatabaseMethods.dart';
import '../main.dart';

// Simple follow state - just track who's following who
final followStateProvider = StateNotifierProvider<FollowStateNotifier, Map<String, bool>>((ref) {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  return FollowStateNotifier(currentUserId);
});

// Track loading states
final followLoadingProvider = StateProvider<Set<String>>((ref) => {});

// Single source of truth for follow status
final isFollowingProvider = Provider.family<bool, String>((ref, targetUserId) {
  return ref.watch(followStateProvider)[targetUserId] ?? false;
});

// Single source of truth for loading status
final isFollowLoadingProvider = Provider.family<bool, String>((ref, userId) {
  return ref.watch(followLoadingProvider).contains(userId);
});

class FollowStateNotifier extends StateNotifier<Map<String, bool>> {
  final String currentUserId;

  FollowStateNotifier(this.currentUserId) : super({});

  // Set follow status directly without extra verification
  void setFollowStatus(String targetUserId, bool isFollowing) {
    state = {...state, targetUserId: isFollowing};
  }

  // Load initial status from database
  Future<void> loadFollowStatus(String targetUserId) async {
    if (state.containsKey(targetUserId)) return; // Already loaded

    try {
      final response = await supabase.from('users').select('following_ids').eq('id', currentUserId).single();

      final followingIds = List<String>.from(response['following_ids'] ?? []);
      state = {...state, targetUserId: followingIds.contains(targetUserId)};
    } catch (e) {
      print('Error loading follow status: $e');
      state = {...state, targetUserId: false};
    }
  }

  // Clear cache for a user
  void clearCache(String targetUserId) {
    final newState = Map<String, bool>.from(state);
    newState.remove(targetUserId);
    state = newState;
  }
}

// Simplified static service methods
class FollowService {
  static Future<bool> followUser(String currentUserId, String targetUserId) async {
    if (currentUserId == targetUserId) return false;

    try {
      // Check if interaction is allowed
      final canInteract = await supabase.rpc('can_users_interact', params: {
        'user1_id': currentUserId,
        'user2_id': targetUserId,
      });

      if (!canInteract) return false;

      // Update both users in a single transaction-like operation
      await supabase.rpc('follow_user', params: {
        'follower_id': currentUserId,
        'target_id': targetUserId,
      });

      // Fire and forget notification
      _sendFollowNotification(currentUserId, targetUserId);

      return true;
    } catch (e) {
      print('Error following user: $e');
      return false;
    }
  }

  static Future<bool> unfollowUser(String currentUserId, String targetUserId) async {
    if (currentUserId == targetUserId) return false;

    try {
      // Update both users in a single transaction-like operation
      await supabase.rpc('unfollow_user', params: {
        'follower_id': currentUserId,
        'target_id': targetUserId,
      });

      return true;
    } catch (e) {
      print('Error unfollowing user: $e');
      return false;
    }
  }

  static Future<bool> removeFollower(String currentUserId, String followerUserId) async {
    if (currentUserId == followerUserId) return false;

    try {
      await supabase.rpc('remove_follower', params: {
        'user_id': currentUserId,
        'follower_id': followerUserId,
      });

      return true;
    } catch (e) {
      print('Error removing follower: $e');
      return false;
    }
  }

  static void _sendFollowNotification(String currentUserId, String targetUserId) {
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
        print("Follow notification error: $e");
      }
    });
  }
}

// Simplified controller with optimistic updates
final followControllerProvider = Provider<FollowController>((ref) {
  return FollowController(ref);
});

class FollowController {
  final Ref ref;

  FollowController(this.ref);

  Future<FollowResult> toggleFollow(String targetUserId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return FollowResult.failed('Not authenticated');

    final loadingState = ref.read(followLoadingProvider.notifier);
    final followState = ref.read(followStateProvider.notifier);

    // Prevent double-clicks
    if (ref.read(isFollowLoadingProvider(targetUserId))) {
      return FollowResult.failed('Action already in progress');
    }

    // Set loading state
    loadingState.update((state) => {...state, targetUserId});

    try {
      // Ensure we have the current state
      await followState.loadFollowStatus(targetUserId);

      final isCurrentlyFollowing = ref.read(isFollowingProvider(targetUserId));

      // Optimistic update
      followState.setFollowStatus(targetUserId, !isCurrentlyFollowing);

      // Perform the action
      bool success;
      if (!isCurrentlyFollowing) {
        success = await FollowService.followUser(currentUserId, targetUserId);
      } else {
        success = await FollowService.unfollowUser(currentUserId, targetUserId);
      }

      if (!success) {
        // Revert on failure
        followState.setFollowStatus(targetUserId, isCurrentlyFollowing);

        // Check if it's a block issue
        final canInteract = await supabase.rpc('can_users_interact', params: {
          'user1_id': currentUserId,
          'user2_id': targetUserId,
        });

        if (!canInteract) {
          return FollowResult.blocked();
        }

        return FollowResult.failed('Operation failed');
      }

      return FollowResult.success();
    } catch (e) {
      // Revert on error
      followState.clearCache(targetUserId);
      print('Error toggling follow: $e');
      return FollowResult.failed(e.toString());
    } finally {
      // Remove loading state
      loadingState.update((state) {
        final newState = Set<String>.from(state);
        newState.remove(targetUserId);
        return newState;
      });
    }
  }

  Future<FollowResult> removeFollower(String followerUserId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return FollowResult.failed('Not authenticated');

    final loadingState = ref.read(followLoadingProvider.notifier);

    // Prevent double-clicks
    if (ref.read(isFollowLoadingProvider(followerUserId))) {
      return FollowResult.failed('Action already in progress');
    }

    // Set loading state
    loadingState.update((state) => {...state, followerUserId});

    try {
      final success = await FollowService.removeFollower(currentUserId, followerUserId);

      if (!success) {
        return FollowResult.failed('Failed to remove follower');
      }

      return FollowResult.success();
    } catch (e) {
      print('Error removing follower: $e');
      return FollowResult.failed(e.toString());
    } finally {
      // Remove loading state
      loadingState.update((state) {
        final newState = Set<String>.from(state);
        newState.remove(followerUserId);
        return newState;
      });
    }
  }

  // Simple getters
  bool isFollowing(String targetUserId) {
    return ref.read(isFollowingProvider(targetUserId));
  }

  bool isLoading(String userId) {
    return ref.read(isFollowLoadingProvider(userId));
  }

  // Force refresh if needed
  Future<void> refreshFollowStatus(String targetUserId) async {
    final followState = ref.read(followStateProvider.notifier);
    followState.clearCache(targetUserId);
    await followState.loadFollowStatus(targetUserId);
  }
}

class FollowResult {
  final bool isSuccess;
  final bool isBlocked;
  final String? errorMessage;

  FollowResult._({
    required this.isSuccess,
    required this.isBlocked,
    this.errorMessage,
  });

  factory FollowResult.success() => FollowResult._(
        isSuccess: true,
        isBlocked: false,
      );

  factory FollowResult.blocked() => FollowResult._(
        isSuccess: false,
        isBlocked: true,
      );

  factory FollowResult.failed(String message) => FollowResult._(
        isSuccess: false,
        isBlocked: false,
        errorMessage: message,
      );
}
