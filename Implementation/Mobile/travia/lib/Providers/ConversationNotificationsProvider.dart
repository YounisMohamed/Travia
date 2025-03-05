import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';

class ConvNotificationsNotifier extends StateNotifier<Map<String, bool>> {
  ConvNotificationsNotifier() : super({}) {
    _fetchConvNotifications();
  }

  Future<void> _fetchConvNotifications() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print("User ID is null");
      return;
    }

    try {
      final response = await supabase.from('conversation_participants').select('conversation_id, conversations(notifications_enabled)').eq('user_id', userId);

      final Map<String, bool> notiMap = {
        for (var row in response) row['conversation_id'] as String: row['conversations']['notifications_enabled'] as bool,
      };

      state = notiMap;
    } catch (e) {
      print("Error fetching notification enabled conversations: $e");
    }
  }

  // *Toggle Notifications (Optimistic Update)*
  Future<void> toggleConvNotifications({
    required String conversationId,
  }) async {
    final isEnabled = state[conversationId] ?? true;

    try {
      // Optimistically update state
      state = {...state, conversationId: !isEnabled};

      // Update in database
      await supabase.from('conversations').update({'notifications_enabled': !isEnabled}).eq('conversation_id', conversationId);
    } catch (e) {
      print("Error updating notifications: $e");
      // Revert state on failure
      state = {...state, conversationId: isEnabled};
    }
  }
}

final convNotificationsProvider = StateNotifierProvider<ConvNotificationsNotifier, Map<String, bool>>((ref) {
  return ConvNotificationsNotifier();
});
