import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Classes/ConversationDetail.dart';
import '../Classes/UserSupabase.dart';
import '../Helpers/EncryptionHelper.dart';
import '../MainFlow/DMsPage.dart';
import '../main.dart';

final conversationIsLoadingProvider = StateProvider<bool>((ref) => false);

// Provider to get total unread count across all conversations
final unreadDMCountProvider = StreamProvider<int>((ref) async* {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    yield 0;
    return;
  }

  try {
    // Get all conversation IDs for the user
    final participantsResponse = await supabase.from('conversation_participants').select('conversation_id').eq('user_id', user.uid);

    final conversationIds = participantsResponse.map((p) => p['conversation_id'] as String).toList();

    if (conversationIds.isEmpty) {
      yield 0;
      return;
    }

    // Stream changes to messages table for all user's conversations
    final stream = supabase.from('messages').stream(primaryKey: ['message_id']).inFilter('conversation_id', conversationIds);

    await for (final event in stream) {
      // Get all unread messages
      final unreadResponse = await supabase.from('messages').select('message_id, read_by, sender_id').inFilter('conversation_id', conversationIds);

      // Filter and count unread messages on client side
      final unreadCount = unreadResponse.where((message) {
        // Skip messages from current user
        if (message['sender_id'] == user.uid) return false;

        // Check if message is unread
        final readBy = message['read_by'] as Map<String, dynamic>?;
        return readBy == null || readBy[user.uid] == null;
      }).length;

      yield unreadCount;
    }
  } catch (e) {
    print('Error in unread count stream: $e');
    yield 0;
  }
});

final deletingConversationProvider = StateProvider<Set<String>>((ref) => {});

final userSearchProvider = FutureProvider.family<List<UserModel>, String>((ref, query) async {
  if (query.isEmpty) return [];

  // debounce
  await Future.delayed(const Duration(milliseconds: 400));

  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  final response = await supabase.from('users').select().or('username.ilike.%$query%,display_name.ilike.%$query%').neq('id', currentUserId!).limit(10);

  return (response as List).map((user) => UserModel.fromMap(user)).toList();
});

final conversationDetailsProvider = FutureProvider<List<ConversationDetail>>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return [];
  }

  try {
    // Fetch conversation details using RPC
    final response = await supabase.rpc('get_conversation_details', params: {'p_user_id': user.uid});

    final List<ConversationDetail> details = (response as List).map((data) {
      // Decrypt last message content if it exists
      String? decryptedLastMessage = data['last_message_content'];
      if (decryptedLastMessage != null && decryptedLastMessage.isNotEmpty) {
        decryptedLastMessage = EncryptionHelper.decryptContent(decryptedLastMessage, data['conversation_id']);
      }

      return ConversationDetail(
          conversationId: data['conversation_id'],
          conversationType: data['conversation_type'],
          title: data['title'],
          createdAt: DateTime.parse(data['created_at']),
          updatedAt: DateTime.parse(data['updated_at']),
          userId: data['user_id'],
          userUsername: data['user_username'],
          userPhotoUrl: data['user_photo_url'],
          sender: data['sender'],
          isTyping: data['is_typing'],
          isPinned: data['is_pinned'],
          chatTheme: data['chat_theme'],
          groupPicture: data['group_picture']);
    }).toList();

    return details;
  } catch (e, stackTrace) {
    print('Error fetching conversation details: $e');
    debugPrintStack(stackTrace: stackTrace);

    // Return empty list on error
    return [];
  }
});

final createConversationProvider = FutureProvider.family<String, String>((ref, otherUserId) async {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;

  // Step 1: Get all conversation IDs of currentUser
  final currentUserConversations = await supabase.from('conversation_participants').select('conversation_id').eq('user_id', currentUserId);
  final currentUserConversationIds = (currentUserConversations as List).map((e) => e['conversation_id'] as String).toSet();

  // Step 2: Get all conversation IDs of otherUser
  final otherUserConversations = await supabase.from('conversation_participants').select('conversation_id').eq('user_id', otherUserId);
  final otherUserConversationIds = (otherUserConversations as List).map((e) => e['conversation_id'] as String).toSet();

  // Step 3: Find common conversation IDs
  final commonConversationIds = currentUserConversationIds.intersection(otherUserConversationIds);

  // Step 4: Check if there's any direct conversation among them
  if (commonConversationIds.isNotEmpty) {
    final directConversations = await supabase.from('conversations').select().eq('conversation_type', 'direct').filter('conversation_id', 'in', commonConversationIds.toList());

    if ((directConversations as List).isNotEmpty) {
      return directConversations[0]['conversation_id'];
    }
  }

  // Create a new conversation
  final conversation = await supabase
      .from('conversations')
      .insert({
        'conversation_type': 'direct',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'is_pinned': false,
      })
      .select()
      .single();

  final conversationId = conversation['conversation_id'];
  final now = DateTime.now().toIso8601String();

  // Add both users as participants with their usernames and photo URLs
  await supabase.from('conversation_participants').insert([
    {
      'conversation_id': conversationId,
      'user_id': currentUserId,
      'joined_at': now,
    },
    {
      'conversation_id': conversationId,
      'user_id': otherUserId,
      'joined_at': now,
    }
  ]);

  return conversationId;
});

final createGroupConversationProvider = FutureProvider.family<String, GroupChatParams>((ref, params) async {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final now = DateTime.now().toIso8601String();

  // Create a new group conversation
  final conversation = await supabase
      .from('conversations')
      .insert({
        'conversation_type': 'group',
        'title': params.groupName,
        'created_at': now,
        'updated_at': now,
        'is_pinned': false,
        'admin_id': currentUserId,
      })
      .select()
      .single();

  final conversationId = conversation['conversation_id'];

  // First add the current user as participant
  await supabase.from('conversation_participants').insert({
    'conversation_id': conversationId,
    'user_id': currentUserId,
    'joined_at': now,
  });

  // Then add all selected users as participants
  final participantEntries = params.userIds
      .map((userId) => {
            'conversation_id': conversationId,
            'user_id': userId,
            'joined_at': now,
          })
      .toList();

  await supabase.from('conversation_participants').insert(participantEntries);

  return conversationId;
});

class ConversationLastMessageData {
  final String conversationId;
  final DateTime? lastMessageAt;
  final String? lastMessageId;
  final String? lastMessageContent;
  final String? lastMessageContentType;
  final String? lastMessageSender;
  final DateTime? lastReadAt;
  final int unreadCount;

  ConversationLastMessageData({
    required this.conversationId,
    this.lastMessageAt,
    this.lastMessageId,
    this.lastMessageContent,
    this.lastMessageContentType,
    this.lastMessageSender,
    this.lastReadAt,
    required this.unreadCount,
  });
}

// Simple stream that just listens to messages
final conversationLastMessageStreamProvider = StreamProvider.family<ConversationLastMessageData?, String>((ref, conversationId) async* {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    yield null;
    return;
  }

  try {
    // Stream messages for this conversation, ordered by newest first
    final stream = supabase.from('messages').stream(primaryKey: ['message_id']).eq('conversation_id', conversationId).order('sent_at', ascending: false).limit(1);

    await for (final event in stream) {
      if (event.isEmpty) {
        yield ConversationLastMessageData(
          conversationId: conversationId,
          lastMessageAt: null,
          lastMessageId: null,
          lastMessageContent: 'Start Sending!',
          lastMessageContentType: null,
          lastMessageSender: null,
          lastReadAt: null,
          unreadCount: 0,
        );
        continue;
      }

      // Get the latest message
      final lastMessage = event.first;

      // Get unread count
      final unreadResponse = await supabase.from('messages').select('message_id, read_by').eq('conversation_id', conversationId).neq('sender_id', user.uid);

      final unreadCount = unreadResponse.where((message) {
        final readBy = message['read_by'] as Map<String, dynamic>?;
        return readBy == null || readBy[user.uid] == null;
      }).length;

      // Process message content
      String processedContent = lastMessage['content'];
      final contentType = lastMessage['content_type'] as String;

      switch (contentType) {
        case 'text':
          processedContent = EncryptionHelper.decryptContent(processedContent, conversationId);
          break;
        case 'record':
          processedContent = 'Record Message 🎙️';
          break;
        case 'story_reply':
          processedContent = 'Story reply 💬';
          break;
        case 'plan':
          processedContent = 'My Plan! ✈️';
          break;
        case 'image':
        case 'video':
        case 'gif': // NOT YET SUPPORTED
          processedContent = 'Media Message 📷';
          break;
      }

      yield ConversationLastMessageData(
        conversationId: conversationId,
        lastMessageAt: DateTime.parse(lastMessage['sent_at']),
        lastMessageId: lastMessage['message_id'],
        lastMessageContent: processedContent,
        lastMessageContentType: contentType,
        lastMessageSender: lastMessage['sender_username'],
        lastReadAt: null,
        unreadCount: unreadCount,
      );
    }
  } catch (e) {
    print('Error in message stream: $e');
    yield null;
  }
});

// Simple stream that monitors for new conversations and triggers refresh
final newConversationTriggerProvider = StreamProvider<bool>((ref) async* {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    yield false;
    return;
  }

  try {
    // Get initial count of conversations
    final initialResponse = await supabase.from('conversation_participants').select('conversation_id').eq('user_id', user.uid);

    int lastCount = (initialResponse as List).length;

    // Stream conversation_participants for this user
    final stream = supabase.from('conversation_participants').stream(primaryKey: ['conversation_id', 'user_id']).eq('user_id', user.uid);

    await for (final events in stream) {
      final currentCount = events.length;

      // If count increased, a new conversation was added
      if (currentCount > lastCount) {
        lastCount = currentCount;
        yield true; // Trigger refresh

        // Reset to false after a short delay
        await Future.delayed(Duration(milliseconds: 100));
        yield false;
      }
    }
  } catch (e) {
    print('Error in conversation trigger stream: $e');
    yield false;
  }
});
