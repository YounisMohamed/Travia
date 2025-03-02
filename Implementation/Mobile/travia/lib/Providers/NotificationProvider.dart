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
