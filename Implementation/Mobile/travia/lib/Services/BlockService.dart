import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';

class BlockService {
  /// Block a user
  /// This adds targetUserId to currentUser's blocked_user_ids array
  /// and adds currentUserId to targetUser's blocked_by_user_ids array
  static Future<bool> blockUser(String currentUserId, String targetUserId) async {
    try {
      // Start a transaction-like operation by performing both updates

      // 1. Add targetUserId to current user's blocked_user_ids
      await supabase.rpc('add_to_array', params: {
        'table_name': 'users',
        'column_name': 'blocked_user_ids',
        'user_id': currentUserId,
        'value_to_add': targetUserId,
      });

      // 2. Add currentUserId to target user's blocked_by_user_ids
      await supabase.rpc('add_to_array', params: {
        'table_name': 'users',
        'column_name': 'blocked_by_user_ids',
        'user_id': targetUserId,
        'value_to_add': currentUserId,
      });

      // 3. Remove from following/friends if they were connected
      await _removeFromConnections(currentUserId, targetUserId);

      return true;
    } catch (e) {
      print('Error blocking user: $e');
      return false;
    }
  }

  /// Unblock a user
  /// This removes targetUserId from currentUser's blocked_user_ids array
  /// and removes currentUserId from targetUser's blocked_by_user_ids array
  static Future<bool> unblockUser(String currentUserId, String targetUserId) async {
    try {
      // 1. Remove targetUserId from current user's blocked_user_ids
      await supabase.rpc('remove_from_array', params: {
        'table_name': 'users',
        'column_name': 'blocked_user_ids',
        'user_id': currentUserId,
        'value_to_remove': targetUserId,
      });

      // 2. Remove currentUserId from target user's blocked_by_user_ids
      await supabase.rpc('remove_from_array', params: {
        'table_name': 'users',
        'column_name': 'blocked_by_user_ids',
        'user_id': targetUserId,
        'value_to_remove': currentUserId,
      });

      return true;
    } catch (e) {
      print('Error unblocking user: $e');
      return false;
    }
  }

  /// Check if currentUser has blocked targetUser
  static Future<bool> hasBlocked(String currentUserId, String targetUserId) async {
    try {
      final response = await supabase.from('users').select('blocked_user_ids').eq('id', currentUserId).single();

      final blockedIds = List<String>.from(response['blocked_user_ids'] ?? []);
      return blockedIds.contains(targetUserId);
    } catch (e) {
      print('Error checking if user is blocked: $e');
      return false;
    }
  }

  /// Check if currentUser is blocked by targetUser
  static Future<bool> isBlockedBy(String currentUserId, String targetUserId) async {
    try {
      final response = await supabase.from('users').select('blocked_by_user_ids').eq('id', currentUserId).single();

      final blockedByIds = List<String>.from(response['blocked_by_user_ids'] ?? []);
      return blockedByIds.contains(targetUserId);
    } catch (e) {
      print('Error checking if blocked by user: $e');
      return false;
    }
  }

  /// Check if there's any blocking relationship between two users
  static Future<bool> areUsersBlocked(String userId1, String userId2) async {
    final hasBlocked1 = await hasBlocked(userId1, userId2);
    final hasBlocked2 = await hasBlocked(userId2, userId1);
    return hasBlocked1 || hasBlocked2;
  }

  /// Get list of users that current user has blocked
  static Future<List<String>> getBlockedUsers(String currentUserId) async {
    try {
      final response = await supabase.from('users').select('blocked_user_ids').eq('id', currentUserId).single();

      return List<String>.from(response['blocked_user_ids'] ?? []);
    } catch (e) {
      print('Error getting blocked users: $e');
      return [];
    }
  }

  /// Remove users from following/friends when blocking
  static Future<void> _removeFromConnections(String currentUserId, String targetUserId) async {
    try {
      // Remove target from current user's following and friends
      await supabase.rpc('remove_from_array', params: {
        'table_name': 'users',
        'column_name': 'following_ids',
        'user_id': currentUserId,
        'value_to_remove': targetUserId,
      });

      await supabase.rpc('remove_from_array', params: {
        'table_name': 'users',
        'column_name': 'friend_ids',
        'user_id': currentUserId,
        'value_to_remove': targetUserId,
      });

      // Remove current user from target's following and friends
      await supabase.rpc('remove_from_array', params: {
        'table_name': 'users',
        'column_name': 'following_ids',
        'user_id': targetUserId,
        'value_to_remove': currentUserId,
      });

      await supabase.rpc('remove_from_array', params: {
        'table_name': 'users',
        'column_name': 'friend_ids',
        'user_id': targetUserId,
        'value_to_remove': currentUserId,
      });
    } catch (e) {
      print('Error removing connections: $e');
    }
  }
}

final blockStatusProvider = StateNotifierProvider.family<BlockStatusNotifier, AsyncValue<bool>, String>(
  (ref, targetUserId) => BlockStatusNotifier(targetUserId),
);

// StateNotifier to manage block status
class BlockStatusNotifier extends StateNotifier<AsyncValue<bool>> {
  final String targetUserId;

  BlockStatusNotifier(this.targetUserId) : super(const AsyncValue.loading()) {
    _checkBlockStatus();
  }

  Future<void> _checkBlockStatus() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final isBlocked = await BlockService.hasBlocked(currentUserId, targetUserId);
      state = AsyncValue.data(isBlocked);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<bool> blockUser(String currentUserId) async {
    try {
      final success = await BlockService.blockUser(currentUserId, targetUserId);
      if (success) {
        state = const AsyncValue.data(true);
      }
      return success;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  Future<bool> unblockUser(String currentUserId) async {
    try {
      final success = await BlockService.unblockUser(currentUserId, targetUserId);
      if (success) {
        state = const AsyncValue.data(false);
      }
      return success;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  void refresh() {
    _checkBlockStatus();
  }
}
