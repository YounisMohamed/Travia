import 'dart:developer';

import 'package:dismissible_page/dismissible_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:travia/Helpers/DummyCards.dart';
import 'package:travia/MainFlow/ChatPage.dart';
import 'package:travia/Providers/ConversationNotificationsProvider.dart';

import '../Helpers/HelperMethods.dart';
import '../Providers/ChatDetailsProvider.dart';
import '../Providers/ConversationProvider.dart';

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

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(conversationDetailsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text("Conversations"),
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
            log(error.toString());
            log(stack.toString());
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.go("/error-page/${Uri.encodeComponent(error.toString())}/${Uri.encodeComponent("/dms-page")}");
              }
            });
            return Center(
              child: Text('Failed to load conversations.'),
            );
          },
          data: (conversationDetails) {
            // Preload data for each conversation
            for (final detail in conversationDetails) {
              final conversationId = detail.conversationId;
              // Trigger providers to start fetching in the background
              ref.read(chatMetadataProvider(conversationId).future);
              ref.read(messagesProvider(conversationId));
              ref.read(conversationParticipantsProvider(conversationId));
            }

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
                  conversationId: detail.conversationId,
                  conversationType: detail.conversationType,
                  title: detail.title,
                  lastMessageContent: detail.lastMessageContent,
                  lastMessageContentType: detail.lastMessageContentType,
                  lastMessageAt: detail.lastMessageAt,
                  userUsername: detail.userUsername,
                  userPhotoUrl: detail.userPhotoUrl,
                  unreadCount: detail.unreadCount,
                  isPinned: detail.isPinned,
                  sender: detail.sender,
                );
              },
            );
          }),
    );
  }
}

class ConversationTile extends ConsumerWidget {
  final String conversationId;
  final String conversationType;
  final String? title;
  final String? lastMessageContent;
  final String? lastMessageContentType;
  final DateTime? lastMessageAt;
  final String? userUsername;
  final String? userPhotoUrl;
  final int unreadCount;
  final String? sender;
  final bool isPinned;
  final String? chatTheme;

  const ConversationTile({
    super.key,
    required this.conversationId,
    required this.conversationType,
    this.title,
    this.lastMessageContent,
    this.lastMessageContentType,
    this.lastMessageAt,
    this.userUsername,
    this.userPhotoUrl,
    required this.unreadCount,
    this.sender,
    required this.isPinned,
    this.chatTheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationState = ref.watch(convNotificationsProvider);
    final isNotificationEnabled = notificationState[conversationId] ?? false;
    final typingUsersAsync = ref.watch(otherTypingProvider(conversationId));

    bool isDirect = conversationType == 'direct';
    bool isGroup = conversationType == 'group';

    String typingText = '';
    final typingUsers = typingUsersAsync.asData?.value ?? [];

    if (typingUsers.isNotEmpty) {
      if (isDirect) {
        typingText = "${typingUsers.first} is typing...";
      } else {
        typingText = typingUsers.length == 1 ? "${typingUsers.first} is typing..." : "${typingUsers.length} people are typing...";
      }
    }

    String displayTitle = isDirect ? (userUsername ?? 'Direct Message') : (title ?? 'Group Conversation');

    // Determine the message content based on its type
    String content = "";
    if (lastMessageContentType == "image") {
      content = "📷 New Image Sent";
    } else if (lastMessageContentType == "video") {
      content = "🎥 New Video Sent";
    } else if (lastMessageContent != null) {
      content = lastMessageContent!;
    } else {
      content = isDirect ? ("Start a new conversation with $displayTitle") : ("Start chatting in the group");
    }

    String time = lastMessageAt != null ? timeAgo(lastMessageAt!) : "";

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
            if (typingUsers.isNotEmpty)
              Text(
                typingText,
                style: TextStyle(fontSize: 13, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
              )
            else
              RichText(
                text: TextSpan(
                  style: GoogleFonts.roboto(
                    fontSize: 12,
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
                    TextSpan(
                      text: content,
                      style: TextStyle(
                        fontWeight: lastMessageContentType != "text" ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
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
        context.pushTransparentRoute(ChatPage(conversationId: conversationId));
        print('Tapped conversation: $conversationId');
      },
    );
  }
}
