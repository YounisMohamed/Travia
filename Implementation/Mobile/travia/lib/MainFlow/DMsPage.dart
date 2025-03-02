import 'package:flutter/material.dart';

import '../Classes/Conversation.dart';
import '../Classes/ConversationParticipants.dart';

class DMsPage extends StatefulWidget {
  const DMsPage({super.key});

  @override
  State<DMsPage> createState() => _DMsPageState();
}

class _DMsPageState extends State<DMsPage> {
  // Dummy data for conversations
  final List<Conversation> _conversations = [
    Conversation(
      conversationId: '1',
      conversationType: 'direct',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      lastMessageAt: DateTime.now().subtract(const Duration(hours: 1)),
      lastMessageId: 'm1',
      lastMessageContent: 'Hey, are we still meeting tomorrow?',
    ),
    Conversation(
      conversationId: '2',
      conversationType: 'group',
      title: 'Project Alpha Team',
      createdAt: DateTime.now().subtract(const Duration(days: 14)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      lastMessageAt: DateTime.now().subtract(const Duration(hours: 3)),
      adminId: 'user123',
      chatTheme: 'purple',
      lastMessageId: 'm2',
      lastMessageContent: 'I just pushed the latest changes to the repo',
    ),
    Conversation(
      conversationId: '3',
      conversationType: 'direct',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 12)),
      lastMessageAt: DateTime.now().subtract(const Duration(hours: 12)),
      lastMessageId: 'm3',
      lastMessageContent: 'The designs look great! Ill review them tonight.',
    ),
    Conversation(
      conversationId: '4',
      conversationType: 'group',
      title: 'Weekend Plans 🎉',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 6)),
      lastMessageAt: DateTime.now().subtract(const Duration(hours: 6)),
      adminId: 'user456',
      chatTheme: 'orange',
      lastMessageId: 'm4',
      lastMessageContent: 'I found this great place for dinner on Saturday',
    ),
    Conversation(
      conversationId: '5',
      conversationType: 'direct',
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      lastMessageAt: DateTime.now().subtract(const Duration(days: 2)),
      lastMessageId: 'm5',
      lastMessageContent: 'Thanks for your help with the presentation',
    ),
  ];

  // Dummy data for conversation participants
  final List<ConversationParticipants> _participants = [
    ConversationParticipants(
      conversationId: '1',
      userId: 'user456',
      joinedAt: DateTime.now().subtract(const Duration(days: 30)),
      isTyping: false,
      notificationsEnabled: true,
      userUsername: 'Alex Johnson',
      userPhotoUrl: 'https://i.pravatar.cc/150?img=1',
      lastReadAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    ConversationParticipants(
      conversationId: '2',
      userId: 'user123',
      joinedAt: DateTime.now().subtract(const Duration(days: 14)),
      isTyping: false,
      notificationsEnabled: true,
      userUsername: 'Sarah Miller',
      userPhotoUrl: 'https://i.pravatar.cc/150?img=2',
      lastReadAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    ConversationParticipants(
      conversationId: '2',
      userId: 'user456',
      joinedAt: DateTime.now().subtract(const Duration(days: 14)),
      isTyping: false,
      notificationsEnabled: true,
      userUsername: 'Alex Johnson',
      userPhotoUrl: 'https://i.pravatar.cc/150?img=1',
      lastReadAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    ConversationParticipants(
      conversationId: '3',
      userId: 'user789',
      joinedAt: DateTime.now().subtract(const Duration(days: 5)),
      isTyping: true,
      notificationsEnabled: true,
      userUsername: 'Michael Chen',
      userPhotoUrl: 'https://i.pravatar.cc/150?img=3',
      lastReadAt: DateTime.now().subtract(const Duration(hours: 12)),
    ),
    ConversationParticipants(
      conversationId: '4',
      userId: 'user123',
      joinedAt: DateTime.now().subtract(const Duration(days: 2)),
      isTyping: false,
      notificationsEnabled: true,
      userUsername: 'Sarah Miller',
      userPhotoUrl: 'https://i.pravatar.cc/150?img=2',
      lastReadAt: DateTime.now().subtract(const Duration(hours: 8)),
    ),
    ConversationParticipants(
      conversationId: '4',
      userId: 'user789',
      joinedAt: DateTime.now().subtract(const Duration(days: 2)),
      isTyping: false,
      notificationsEnabled: true,
      userUsername: 'Michael Chen',
      userPhotoUrl: 'https://i.pravatar.cc/150?img=3',
      lastReadAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    ConversationParticipants(
      conversationId: '4',
      userId: 'user101',
      joinedAt: DateTime.now().subtract(const Duration(days: 2)),
      isTyping: false,
      notificationsEnabled: true,
      userUsername: 'Emma Wong',
      userPhotoUrl: 'https://i.pravatar.cc/150?img=4',
      lastReadAt: DateTime.now().subtract(const Duration(hours: 7)),
    ),
    ConversationParticipants(
      conversationId: '5',
      userId: 'user202',
      joinedAt: DateTime.now().subtract(const Duration(days: 60)),
      isTyping: false,
      notificationsEnabled: false,
      userUsername: 'Jordan Smith',
      userPhotoUrl: 'https://i.pravatar.cc/150?img=5',
      lastReadAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  // Get the other participant in a direct message conversation.
  ConversationParticipants? _getDirectMessageParticipant(String conversationId) {
    final participants = _participants.where((p) => p.conversationId == conversationId).toList();
    // In a real app, you would filter out the current user and return the other participant.
    return participants.isNotEmpty ? participants.first : null;
  }

  // Get the sender of the last message in a group conversation.
  ConversationParticipants? _getLastMessageSender(String conversationId) {
    // In a real app, you would get this from the actual message data.
    final participants = _participants.where((p) => p.conversationId == conversationId).toList();
    return participants.isNotEmpty ? participants.first : null;
  }

  // Check if there are unread messages.
  int _getUnreadCount(Conversation conversation) {
    if (conversation.lastMessageAt == null) return 0;
    final participant = _getDirectMessageParticipant(conversation.conversationId);
    if (participant == null || participant.lastReadAt == null) return 0;
    if (conversation.lastMessageAt!.isAfter(participant.lastReadAt!)) {
      return int.parse(conversation.conversationId) % 3 == 0 ? 0 : (int.parse(conversation.conversationId) % 2 == 0 ? 3 : 1);
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Conversations"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        forceMaterialTransparency: true,
      ),
      body: ListView.separated(
        itemCount: _conversations.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final conversation = _conversations[index];
          final unreadCount = _getUnreadCount(conversation);
          final participant = conversation.conversationType == 'direct' ? _getDirectMessageParticipant(conversation.conversationId) : _getLastMessageSender(conversation.conversationId);
          return ConversationTile(
            conversation: conversation,
            participant: participant,
            unreadCount: unreadCount,
          );
        },
      ),
    );
  }
}

/// A modular widget for a conversation tile in the list.
class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final ConversationParticipants? participant;
  final int unreadCount;

  const ConversationTile({
    Key? key,
    required this.conversation,
    this.participant,
    required this.unreadCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // For direct messages, show the participant's username;
    // for group conversations, show the conversation title.
    String title = conversation.conversationType == 'direct' ? (participant?.userUsername ?? 'Direct Message') : (conversation.title ?? 'Group Conversation');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue, // variable color reference
        backgroundImage: conversation.conversationType == 'direct' && participant?.userPhotoUrl != null ? NetworkImage(participant!.userPhotoUrl!) : null,
        child: conversation.conversationType == 'group' ? const Icon(Icons.group, color: Colors.white) : null,
      ),
      title: Text(title),
      subtitle: Text(conversation.lastMessageContent ?? ''),
      trailing: unreadCount > 0 ? UnreadBadge(count: unreadCount) : null,
      onTap: () {
        // Button does nothing for now.
      },
    );
  }
}

/// A small badge widget to display the number of unread messages.
class UnreadBadge extends StatelessWidget {
  final int count;

  const UnreadBadge({Key? key, required this.count}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.red, // using variable color from the Colors class
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count.toString(),
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
