import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travia/Helpers/DummyCards.dart';
import 'package:travia/Providers/ConversationNotificationsProvider.dart';

import '../Helpers/HelperMethods.dart';
import '../Providers/ConversationProvider.dart';
import '../main.dart';

class DMsPage extends ConsumerStatefulWidget {
  const DMsPage({super.key});

  @override
  ConsumerState<DMsPage> createState() => _DMsPageState();
}

class _DMsPageState extends ConsumerState<DMsPage> {
  final user = FirebaseAuth.instance.currentUser;
  @override
  void initState() {
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go("/signin");
      });
    }
    supabase
        .channel('public:messages') // TODO: Messages page later
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              print('Change received: ${payload.toString()}');
            })
        .subscribe();
    supabase
        .channel('public:conversations')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'conversations',
            callback: (payload) {
              print('Change received: ${payload.toString()}');
            })
        .subscribe();
    supabase
        .channel('public:conversation_participants')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'conversation_participants',
            callback: (payload) {
              print('Change received: ${payload.toString()}');
            })
        .subscribe();
    super.initState();
  }

  @override
  void dispose() {
    supabase.channel('public:messages').unsubscribe();
    supabase.channel('public:conversations').unsubscribe();
    supabase.channel('public:conversation_participants').unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use the new streamlined provider
    final detailsAsync = ref.watch(conversationDetailsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Conversations"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        forceMaterialTransparency: true,
      ),
      body: detailsAsync.when(
        loading: () => ListView.builder(
          itemCount: 6,
          itemBuilder: (context, index) {
            return Skeletonizer(
              child: DummyChatCard(),
            );
          },
        ),
        error: (error, stack) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error loading conversations: ${error.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
              context.go("/error-page/${Uri.encodeComponent(error.toString())}");
            }
          });
          return Center(
            child: Text('Failed to load conversations.'),
          );
        },
        data: (conversationDetails) {
          if (conversationDetails.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      // TODO
                    },
                    child: Text('Start a conversation'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: conversationDetails.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final detail = conversationDetails[index];
              return ConversationTile(
                typingCount: detail.typingCount,
                conversationId: detail.conversationId,
                conversationType: detail.conversationType,
                title: detail.title,
                lastMessageContent: detail.lastMessageContent,
                lastMessageAt: detail.lastMessageAt,
                userUsername: detail.userUsername,
                userPhotoUrl: detail.userPhotoUrl,
                unreadCount: detail.unreadCount,
                isPinned: detail.isPinned,
                isTyping: detail.isTyping,
                sender: detail.sender,
              );
            },
          );
        },
      ),
    );
  }
}

/// A modular widget for a conversation tile in the list.
class ConversationTile extends ConsumerWidget {
  final String conversationId;
  final String conversationType;
  final String? title;
  final String? lastMessageContent;
  final DateTime? lastMessageAt;
  final String? userUsername;
  final String? userPhotoUrl;
  final int unreadCount;
  final String? sender;
  final bool isTyping;
  final bool isPinned;
  final String? chatTheme;
  final int typingCount;

  const ConversationTile({
    super.key,
    required this.conversationId,
    required this.conversationType,
    this.title,
    this.lastMessageContent,
    this.lastMessageAt,
    this.userUsername,
    this.userPhotoUrl,
    required this.unreadCount,
    this.sender,
    required this.isTyping,
    required this.isPinned,
    required this.typingCount,
    this.chatTheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print("ConversationTile: conversationId=$conversationId");
    print("ConversationTile: conversationType=$conversationType");
    print("ConversationTile: title=$title");
    print("ConversationTile: lastMessageContent=$lastMessageContent");
    print("ConversationTile: lastMessageAt=$lastMessageAt");
    print("ConversationTile: userUsername=$userUsername");
    print("ConversationTile: userPhotoUrl=$userPhotoUrl");
    print("ConversationTile: unreadCount=$unreadCount");
    print("ConversationTile: sender=$sender");
    print("ConversationTile: isTyping=$isTyping");
    print("ConversationTile: isPinned=$isPinned");
    print("ConversationTile: chatTheme=$chatTheme");
    print("Typing count: typeCount=$typingCount}");
    // for direct messages, show the participant username;
    // for group conversations, show the conversation title.
    final notificationState = ref.watch(convNotificationsProvider);
    final isNotificationEnabled = notificationState[conversationId] ?? false;
    print("NOTIFICATIONS ENABLED: $isNotificationEnabled");
    bool isDirect = conversationType == 'direct';
    bool isGroup = conversationType == 'group';

    String displayTitle = isDirect ? (userUsername ?? 'Direct Message') : (title ?? 'Group Conversation');
    String? content = "";
    if (lastMessageContent != null) {
      content = lastMessageContent;
    } else {
      content = isDirect ? ("Start a new conversation with $displayTitle") : ("Start chatting in the group");
    }
    String time = lastMessageAt != null ? timeAgo(lastMessageAt!) : "";

    String typingText = '';
    if (isTyping && isDirect) {
      typingText = "$userUsername is typing...";
    } else if (isGroup && typingCount > 0) {
      if (typingCount == 1 && isTyping) {
        typingText = "$userUsername is typing..."; // Current user is the only one typing
      } else {
        typingText = "$typingCount people are typing..."; // Multiple people typing
      }
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      horizontalTitleGap: 12,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: Colors.blue.shade100,
        backgroundImage: isDirect && userPhotoUrl != null ? NetworkImage(userPhotoUrl!) : null,
        child: isGroup ? Icon(Icons.group, color: Colors.blue.shade700, size: 22) : null,
      ),
      title: Text(
        displayTitle,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: Colors.black87,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            isTyping
                ? Text(
                    typingText,
                    style: TextStyle(fontSize: 13, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                  )
                : RichText(
                    text: TextSpan(
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                      children: [
                        if (!isDirect && (sender != null))
                          TextSpan(
                            text: "$sender: ",
                            style: GoogleFonts.roboto(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        TextSpan(text: content),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 3,
                  ),
            if (time.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  time,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            iconSize: 24,
            padding: const EdgeInsets.all(8),
            onPressed: () {
              ref.read(convNotificationsProvider.notifier).toggleConvNotifications(conversationId: conversationId);
            },
            icon: Icon(
              isNotificationEnabled ? Icons.notifications : Icons.notifications_off,
              color: Colors.grey.shade600,
            ),
          ),
          if (unreadCount > 0)
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        context.push("/messages");
        print('Tapped conversation: $conversationId');
      },
    );
  }
}
