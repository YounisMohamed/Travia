import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Classes/ConversationDetail.dart';
import '../Classes/UserSupabase.dart';
import '../MainFlow/DMsPage.dart';
import '../main.dart';

final conversationIsLoadingProvider = StateProvider<bool>((ref) => false);

final conversationDetailsProvider = StreamProvider<List<ConversationDetail>>((ref) async* {
  final user = FirebaseAuth.instance.currentUser;

  try {
    final stream = supabase.from('conversations').stream(primaryKey: ['conversation_id']).order('last_message_at', ascending: false);

    await for (final _ in stream) {
      final response = await supabase.rpc('get_conversation_details', params: {'p_user_id': user!.uid});

      final List<ConversationDetail> details = (response as List)
          .map((data) => ConversationDetail(
              conversationId: data['conversation_id'],
              conversationType: data['conversation_type'],
              title: data['title'],
              createdAt: DateTime.parse(data['created_at']),
              updatedAt: DateTime.parse(data['updated_at']),
              lastMessageAt: data['last_message_at'] != null ? DateTime.parse(data['last_message_at']) : null,
              lastMessageId: data['last_message_id'],
              lastMessageContent: data['last_message_content'],
              lastMessageContentType: data['last_message_content_type'],
              userId: data['user_id'],
              lastReadAt: data['last_read_at'] != null ? DateTime.parse(data['last_read_at']) : null,
              userUsername: data['user_username'],
              userPhotoUrl: data['user_photo_url'],
              unreadCount: data['unread_count'] ?? 0,
              sender: data['sender'],
              notificationsEnabled: data['notifications_enabled'],
              isTyping: data['is_typing'],
              isPinned: data['is_pinned'],
              chatTheme: data['chat_theme'],
              groupPicture: data['group_picture']))
          .toList();

      yield details;
    }
  } catch (e, stackTrace) {
    print('Error in conversation stream: $e');
    debugPrintStack(stackTrace: stackTrace);
    rethrow;
  }
});

final userSearchProvider = FutureProvider.family<List<UserModel>, String>((ref, query) async {
  if (query.isEmpty) return [];

  // debounce baby
  await Future.delayed(const Duration(milliseconds: 400));

  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  final response = await supabase.from('users').select().ilike('username', '%$query%').neq('id', currentUserId!).limit(10);

  return (response as List).map((user) => UserModel.fromMap(user)).toList();
});

final deletingConversationProvider = StateProvider<Set<String>>((ref) => {});

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
        'notifications_enabled': true,
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
        'notifications_enabled': true,
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
