import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Classes/Notification.dart';
import '../main.dart';

final notificationsProvider = StreamProvider<List<NotificationModel>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]); // Handle logged-out state
  final currentUserId = user.uid;

  return supabase.from('notifications').stream(primaryKey: ['id']).map(
      (data) => data.map((json) => NotificationModel.fromMap(json)).where((notification) => notification.targetUserId == currentUserId || notification.targetUserId == null).toList());
});

class NotificationReadState extends StateNotifier<Map<String, bool>> {
  NotificationReadState() : super({});

  void markAsRead(String notificationId) {
    // Optimistically update the state instantly
    state = {...state, notificationId: true};

    // Update the database in the background without affecting UI
    _updateDatabase(notificationId);
  }

  Future<void> _updateDatabase(String notificationId) async {
    try {
      await supabase.from('notifications').update({'is_read': true}).eq('id', notificationId);
    } catch (e) {
      print('Error updating notification read status: $e');
    }
  }
}

final notificationReadProvider = StateNotifierProvider<NotificationReadState, Map<String, bool>>(
  (ref) => NotificationReadState(),
);
