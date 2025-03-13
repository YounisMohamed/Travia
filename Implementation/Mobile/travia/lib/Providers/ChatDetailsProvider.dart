import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Classes/ChatDetails.dart';
import '../Classes/ConversationParticipants.dart';
import '../Classes/Messages.dart';
import '../main.dart';

final chatMetadataProvider = FutureProvider.family<ChatDetails, String>((ref, conversationId) async {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final response = await supabase.rpc('get_chat_details', params: {
    'p_conversation_id': conversationId,
    'p_current_user_id': currentUserId,
  });
  final data = response as List;
  if (data.isEmpty) throw Exception('Conversation not found');
  return ChatDetails.fromMap(data.first as Map<String, dynamic>);
});

final messagesProvider = StreamProvider.family<List<Message>, String>((ref, conversationId) {
  print("Messages stream setup for conversationId: $conversationId");
  return supabase.from('messages').stream(primaryKey: ['message_id']).eq('conversation_id', conversationId).map((event) {
        print("Messages stream event: $event");
        final messages = event.map((json) => Message.fromMap(json)).toList();
        print("Messages updated: ${messages.map((m) => m.messageId).toList()}");
        return messages;
      });
});

final pendingMessagesProvider = StateProvider<Map<String, Message>>((ref) => {});

final conversationParticipantsProvider = StreamProvider.family<List<ConversationParticipants>, String>((ref, conversationId) {
  return supabase
      .from('conversation_participants')
      .stream(primaryKey: ['conversation_id', 'user_id'])
      .eq('conversation_id', conversationId)
      .map((data) => data.map((json) => ConversationParticipants.fromMap(json)).toList());
});

class MessageActionsNotifier extends StateNotifier<Set<Message>> {
  MessageActionsNotifier() : super({});

  void toggleSelectedMessage(Message message) {
    final newState = Set<Message>.from(state);
    if (newState.contains(message)) {
      newState.remove(message);
    } else {
      newState.add(message);
    }
    state = newState;
  }

  void clearSelectedMessages() {
    state = {};
  }
}

final messageActionsProvider = StateNotifierProvider<MessageActionsNotifier, Set<Message>>((ref) {
  return MessageActionsNotifier();
});

final messageEditProvider = StateNotifierProvider<MessageEditNotifier, Message?>((ref) => MessageEditNotifier());

class MessageEditNotifier extends StateNotifier<Message?> {
  MessageEditNotifier() : super(null);

  void startEditing(Message message) => state = message;

  void stopEditing() => state = null;

  void updateContent(String content) {
    if (state != null) {
      state = state!.copyWith(content: content, isEdited: true);
    }
  }
}

final replyMessageProvider = StateProvider<Message?>((ref) => null);
