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
      // Updated query to get notifications_enabled from conversation_participants
      final response = await supabase.from('conversation_participants').select('conversation_id, notifications_enabled').eq('user_id', userId);

      final Map<String, bool> notiMap = {
        for (var row in response) row['conversation_id'] as String: row['notifications_enabled'] as bool,
      };

      state = notiMap;
    } catch (e) {
      print("Error fetching notification enabled conversations: $e");
    }
  }

  // Updated toggle method for per-participant notifications
  Future<void> toggleConvNotifications({
    required String conversationId,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print("User ID is null");
      return;
    }

    final isEnabled = state[conversationId] ?? true;

    try {
      // Optimistically update state
      state = {...state, conversationId: !isEnabled};

      // Update in conversation_participants table instead of conversations
      await supabase.from('conversation_participants').update({'notifications_enabled': !isEnabled}).eq('conversation_id', conversationId).eq('user_id', userId);

      print("Notification toggled for user $userId in conversation $conversationId: ${!isEnabled}");
    } catch (e) {
      print("Error updating notifications: $e");
      // Revert state on failure
      state = {...state, conversationId: isEnabled};
    }
  }

  // Optional: Method to get notification status for a specific conversation
  bool getNotificationStatus(String conversationId) {
    return state[conversationId] ?? true; // Default to enabled
  }

  // Optional: Method to refresh notifications for a specific conversation
  Future<void> refreshConversationNotification(String conversationId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final response = await supabase.from('conversation_participants').select('notifications_enabled').eq('conversation_id', conversationId).eq('user_id', userId).single();

      state = {...state, conversationId: response['notifications_enabled'] as bool};
    } catch (e) {
      print("Error refreshing notification for conversation $conversationId: $e");
    }
  }
}

final convNotificationsProvider = StateNotifierProvider<ConvNotificationsNotifier, Map<String, bool>>((ref) {
  return ConvNotificationsNotifier();
});
