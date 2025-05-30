import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Classes/Notification.dart';
import '../main.dart';

class NotificationReadDeleteState extends StateNotifier<Map<String, dynamic>> {
  NotificationReadDeleteState()
      : super({
          'read': {}, // Map of notificationId -> isRead
          'removed': {}, // Map of notificationId -> true for removed notifications
        });

  void markAsRead(String notificationId) {
    // Optimistically update the read state
    state = {
      'read': {...state['read'], notificationId: true},
      'removed': state['removed'],
    };

    // Update the database in the background
    _updateDatabase(notificationId);
  }

  void removeNotification(String notificationId) {
    // Optimistically mark as removed
    state = {
      'read': state['read'],
      'removed': {...state['removed'], notificationId: true},
    };

    _deleteFromDatabase(notificationId);
  }

  // NEW: Mark all notifications as read
  Future<void> markAllAsRead(List<NotificationModel> notifications) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // Get all unread notification IDs
    final unreadNotificationIds = notifications.where((notification) => !notification.isRead).map((notification) => notification.id).toList();

    if (unreadNotificationIds.isEmpty) return;

    // Optimistically update all unread notifications to read
    final updatedReadMap = Map<String, bool>.from(state['read']);
    for (final id in unreadNotificationIds) {
      updatedReadMap[id] = true;
    }

    state = {
      'read': updatedReadMap,
      'removed': state['removed'],
    };

    // Update database in background
    _markAllAsReadInDatabase(currentUserId);
  }

  Future<void> _updateDatabase(String notificationId) async {
    try {
      await supabase.from('notifications').update({'is_read': true}).eq('id', notificationId);
    } catch (e) {
      print('Error updating notification read status: $e');
    }
  }

  Future<void> _deleteFromDatabase(String notificationId) async {
    try {
      await supabase.from('notifications').delete().eq('id', notificationId);
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  Future<void> _markAllAsReadInDatabase(String currentUserId) async {
    try {
      await supabase.from('notifications').update({'is_read': true}).eq('target_user_id', currentUserId).eq('is_read', false);
      print('All notifications marked as read successfully');
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }
}

final notificationReadProvider = StateNotifierProvider<NotificationReadDeleteState, Map<String, dynamic>>(
  (ref) => NotificationReadDeleteState(),
);

final notificationsProvider = StreamProvider<List<NotificationModel>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);
  final currentUserId = user.uid;

  return supabase.from('notifications').stream(primaryKey: ['id']).order('created_at', ascending: false).map((data) {
        return data.map((json) => NotificationModel.fromMap(json)).where((notification) => notification.targetUserId == currentUserId || notification.targetUserId == null).toList();
      });
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notificationsAsync = ref.watch(notificationsProvider);
  final readState = ref.watch(notificationReadProvider);

  return notificationsAsync.when(
    data: (notifications) {
      if (notifications.isEmpty) return 0;

      int unreadCount = 0;
      for (final notification in notifications) {
        // Check if notification is removed locally
        bool isRemovedLocally = readState['removed'][notification.id] == true;
        if (isRemovedLocally) continue;

        // Check if notification is read (either from database or local state)
        bool isReadLocally = readState['read'][notification.id] == true;
        bool isRead = notification.isRead || isReadLocally;

        if (!isRead) {
          unreadCount++;
        }
      }

      return unreadCount;
    },
    loading: () => 0,
    error: (_, __) => 0,
  );
});
