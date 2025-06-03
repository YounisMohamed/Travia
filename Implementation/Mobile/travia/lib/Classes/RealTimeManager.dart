import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/DatabaseMethods.dart';
import '../main.dart';

class RealtimeManager {
  static const String PERSONAL_CHANNEL = 'personal_updates';
  static const String PUBLIC_CHANNEL = 'public_updates';
  static const String CONVERSATIONS_CHANNEL = 'conversations_updates';

  RealtimeChannel? _personalChannel;
  RealtimeChannel? _publicChannel;
  RealtimeChannel? _conversationsChannel;

  void setupChannels(String currentUserId) {
    disposeChannels(); // Clean up any existing channels first

    // Channel 1: Personal updates (user-specific data)
    _personalChannel = supabase
        .channel(PERSONAL_CHANNEL)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'stories',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: currentUserId,
          ),
          callback: (payload) => _handleStoryChange(payload),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'story_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: currentUserId,
          ),
          callback: (payload) => _handleStoryItemChange(payload),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'target_user_id',
            value: currentUserId,
          ),
          callback: (payload) => _handleNotificationChange(payload),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversation_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: currentUserId,
          ),
          callback: (payload) => _handleConversationParticipantChange(payload),
        )
        .subscribe();

    // Channel 2: Public updates (non-filtered data)
    _publicChannel = supabase
        .channel(PUBLIC_CHANNEL)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'posts',
          callback: (payload) => _handlePostChange(payload),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'comments',
          callback: (payload) => _handleCommentChange(payload),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          callback: (payload) => _handleUserChange(payload),
        )
        .subscribe();

    // Channel 3: Conversations (dynamically filtered)
    _setupConversationsChannel(currentUserId);
  }

  Future<void> _setupConversationsChannel(String currentUserId) async {
    try {
      final conversationIds = await fetchConversationIds(currentUserId);

      if (conversationIds.isNotEmpty) {
        _conversationsChannel = supabase
            .channel(CONVERSATIONS_CHANNEL)
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'conversations',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.inFilter,
                column: 'conversation_id',
                value: conversationIds,
              ),
              callback: (payload) => _handleConversationChange(payload),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'messages',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.inFilter,
                column: 'conversation_id',
                value: conversationIds,
              ),
              callback: (payload) => _handleMessageChange(payload),
            )
            .subscribe();
      }
    } catch (e) {
      print('Error setting up conversations channel: $e');
    }
  }

  // Handler methods
  void _handleStoryChange(PostgresChangePayload payload) {
    // Handle story updates
    print('Story change: ${payload.eventType}');
  }

  void _handleStoryItemChange(PostgresChangePayload payload) {
    // Handle story item updates
    print('Story item change: ${payload.eventType}');
  }

  void _handleNotificationChange(PostgresChangePayload payload) {
    // Handle notification updates
    // You can emit events or update providers here
    print('Notification change: ${payload.eventType}');
  }

  void _handleConversationParticipantChange(PostgresChangePayload payload) {
    // When a user is added to a new conversation, refresh the conversations channel
    if (payload.eventType == PostgresChangeEvent.insert) {
      _setupConversationsChannel(payload.newRecord['user_id']);
    }
  }

  void _handlePostChange(PostgresChangePayload payload) {
    // Handle post updates
    print('Post change: ${payload.eventType}');
  }

  void _handleCommentChange(PostgresChangePayload payload) {
    // Handle comment updates
    print('Comment change: ${payload.eventType}');
  }

  void _handleUserChange(PostgresChangePayload payload) {
    // Handle user updates
    print('User change: ${payload.eventType}');
  }

  void _handleConversationChange(PostgresChangePayload payload) {
    // Handle conversation updates
    print('Conversation change: ${payload.eventType}');
  }

  void _handleMessageChange(PostgresChangePayload payload) {
    // Handle message updates
    print('Message change: ${payload.eventType}');
  }

  void disposeChannels() {
    _personalChannel?.unsubscribe();
    _publicChannel?.unsubscribe();
    _conversationsChannel?.unsubscribe();

    _personalChannel = null;
    _publicChannel = null;
    _conversationsChannel = null;
  }
}

final realtimeManagerProvider = Provider((ref) => RealtimeManager());
