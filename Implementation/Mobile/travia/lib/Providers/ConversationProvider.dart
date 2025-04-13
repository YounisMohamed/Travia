import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Classes/ConversationDetail.dart';
import '../main.dart';

final conversationDetailsProvider = StreamProvider<List<ConversationDetail>>((ref) async* {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('No user logged in, returning empty stream');
    yield [];
    return;
  }

  final currentUserId = user.uid;
  print('Streaming conversations for user: $currentUserId');

  // Get cached data
  final cached = conversationDetailsBox.get('conversation_details')?.cast<ConversationDetail>();
  if (cached != null) {
    yield cached;
  }

  try {
    final stream = supabase.from('conversations').stream(primaryKey: ['conversation_id']).order('last_message_at', ascending: false).order('created_at', ascending: false);

    await for (final conversations in stream) {
      print('Streaming ${conversations.length} conversations...');
      final response = await supabase.from('conversations').select('''
            conversation_id,
            conversation_type,
            title,
            created_at,
            updated_at,
            last_message_at,
            last_message_id,
            last_message_content,
            last_message_content_type,
            last_message_sender,
            notifications_enabled,
            is_pinned,
            chat_theme,
            conversation_participants!inner (
              user_id,
              last_read_at,
              is_typing,
              user_username
            ),
            messages!messages_conversation_id_fkey (
              message_id,
              sent_at,
              sender_id,
              read_by
            )
          ''').order('last_message_at', ascending: false).order('created_at', ascending: false);

      final List<ConversationDetail> details = [];

      for (final conv in response) {
        final participants = conv['conversation_participants'] as List<dynamic>;
        final messages = conv['messages'] as List<dynamic>? ?? [];

        final participant = participants.firstWhere(
          (p) => p['user_id'] == currentUserId,
          orElse: () => throw Exception('Participant not found'),
        );

        String? userUsername;
        String? userPhotoUrl;

        if (conv['conversation_type'] == 'direct') {
          final otherParticipant = participants.firstWhere(
            (p) => p['user_id'] != currentUserId,
            orElse: () => {},
          );
          userUsername = otherParticipant['user_username'] as String?;
          if (otherParticipant['user_id'] != null) {
            final userResponse = await supabase.from('users').select('photo_url').eq('id', otherParticipant['user_id']).single();
            userPhotoUrl = userResponse['photo_url'] as String?;
          }
        } else {
          userUsername = participant['user_username'] as String?;
        }

        final unreadCount = messages.where((m) {
          final sentAt = DateTime.parse(m['sent_at']);
          final lastReadAt = participant['last_read_at'] != null ? DateTime.parse(participant['last_read_at']) : DateTime(1970, 1, 1);
          return sentAt.isAfter(lastReadAt) && m['sender_id'] != currentUserId && (m['read_by'] == null || m['read_by'][currentUserId] == null);
        }).length;

        final detail = ConversationDetail(
          conversationId: conv['conversation_id'] as String,
          conversationType: conv['conversation_type'] as String,
          title: conv['title'] as String?,
          createdAt: DateTime.parse(conv['created_at'] as String),
          updatedAt: DateTime.parse(conv['updated_at'] as String),
          lastMessageAt: conv['last_message_at'] != null ? DateTime.parse(conv['last_message_at']) : null,
          lastMessageId: conv['last_message_id'] as String?,
          lastMessageContent: conv['last_message_content_type'] == 'text'
              ? conv['last_message_content'] as String?
              : conv['last_message_content_type'] == 'record'
                  ? "Record Message 🎙️"
                  : "Media Message 📷",
          lastMessageContentType: conv['last_message_content_type'] as String?,
          userId: currentUserId,
          lastReadAt: participant['last_read_at'] != null ? DateTime.parse(participant['last_read_at']) : null,
          userUsername: userUsername,
          userPhotoUrl: userPhotoUrl,
          unreadCount: unreadCount,
          sender: conv['last_message_sender'] as String?,
          notificationsEnabled: conv['notifications_enabled'] as bool,
          isTyping: participant['is_typing'] as bool,
          isPinned: conv['is_pinned'] as bool,
          chatTheme: conv['chat_theme'] as String?,
        );

        details.add(detail);
      }

      // Cache and yield the new list
      await conversationDetailsBox.put('conversation_details', details);
      yield details;
    }
  } catch (e, stackTrace) {
    print('Error in conversation stream: $e');
    if (cached != null) {
      yield cached;
    } else {
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
});
