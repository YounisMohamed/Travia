import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:travia/Helpers/AppColors.dart';
import 'package:travia/Helpers/DummyCards.dart';
import 'package:travia/Helpers/Loading.dart';
import 'package:travia/Providers/ConversationNotificationsProvider.dart';

import '../Helpers/DeleteConfirmation.dart';
import '../Helpers/HelperMethods.dart';
import '../Helpers/PopUp.dart';
import '../Providers/ChatDetailsProvider.dart';
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

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _createNewConversation() async {
    try {
      // Navigate to the new conversation page
      context.push("/dms-page/new");
    } catch (e) {
      log(e.toString());
      Popup.showError(text: "Something went wrong", context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(conversationDetailsProvider);
    final isLoading = ref.watch(conversationIsLoadingProvider);

    return Scaffold(
      backgroundColor: kDeepGrey,
      appBar: AppBar(
        forceMaterialTransparency: true,
        title: Row(
          children: [
            Text(
              "Conversations",
              style: GoogleFonts.ibmPlexSans(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 10),
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: LoadingWidget(),
              ),
          ],
        ),
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
                    Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [kDeepPink.withOpacity(0.1), kDeepPinkLight.withOpacity(0.1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline,
                        size: 48,
                        color: kDeepPink,
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'No conversations yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Start chatting with other travelers!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [kDeepPinkLight, kDeepPink],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kDeepPink.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _createNewConversation,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_comment_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Start a conversation',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
                  groupPicture: detail.groupPicture,
                );
              },
            );
          }),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewConversation,
        tooltip: 'New Conversation',
        backgroundColor: Colors.white,
        child: const Icon(
          Icons.chat,
          color: kDeepPink,
        ),
      ),
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
  final String? groupPicture;

  const ConversationTile({
    super.key,
    required this.conversationId,
    required this.conversationType,
    this.title,
    this.groupPicture,
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
    final isNotificationEnabled = notificationState[conversationId] ?? true;
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

    String displayTitle = isDirect ? ("@$userUsername") : (title ?? 'Group Conversation');

    String time = lastMessageAt != null ? timeAgo(lastMessageAt!) : "";

    return GestureDetector(
      onLongPress: isDirect ? () => _showDeleteDialog(context, ref, conversationId) : () => _showLeaveGroupDialog(context, ref, conversationId, FirebaseAuth.instance.currentUser!.uid),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        horizontalTitleGap: 12,
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.blue.shade100,
          backgroundImage: isDirect && userPhotoUrl != null
              ? NetworkImage(userPhotoUrl!)
              : isGroup && groupPicture != null
                  ? NetworkImage(groupPicture!)
                  : null,
        ),
        title: Text(
          displayTitle,
          style: GoogleFonts.redHatDisplay(
            fontWeight: FontWeight.w600,
            fontSize: 17,
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
                  style: GoogleFonts.lexend(fontSize: 15, color: kDeepPink, fontWeight: FontWeight.bold),
                )
              else
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.lexend(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                    children: [
                      if (!isDirect && (sender != null))
                        TextSpan(
                          text: "$sender: ",
                          style: GoogleFonts.lexend(
                            fontWeight: FontWeight.bold,
                            color: kDeepPink,
                          ),
                        ),
                      TextSpan(
                        text: lastMessageContent,
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
                    style: GoogleFonts.lexend(
                      fontSize: 13,
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
              iconSize: 21,
              padding: const EdgeInsets.all(8),
              onPressed: () {
                ref.read(convNotificationsProvider.notifier).toggleConvNotifications(conversationId: conversationId);
              },
              icon: Icon(
                isNotificationEnabled ? CupertinoIcons.bell_fill : CupertinoIcons.bell_slash_fill,
                color: kDeepPink,
              ),
            ),
            if (unreadCount > 0)
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: kDeepPink,
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
          context.push("/messages/$conversationId");
          print('Tapped conversation: $conversationId');
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, String conversationId) {
    showCustomDialog(
      context: context,
      title: "Delete",
      message: "Are you sure? This will delete the whole conversation for both users.",
      actionText: "Delete",
      actionIcon: Icons.delete,
      onActionPressed: () async {
        ref.read(conversationIsLoadingProvider.notifier).state = true;
        try {
          await supabase.from('conversations').delete().match({'conversation_id': conversationId});
          print('Delete conversation requested: $conversationId');
        } catch (e) {
          log(e.toString());
          if (context.mounted) {
            Popup.showError(text: "Error happened while deleting the conversation", context: context);
          }
        } finally {
          ref.read(conversationIsLoadingProvider.notifier).state = false;
        }
      },
      actionColor: Colors.red,
    );
  }

  void _showLeaveGroupDialog(BuildContext context, WidgetRef ref, String conversationId, String currentUserId) {
    showCustomDialog(
      context: context,
      title: "Leave",
      message: "Are you sure? you can't undo this",
      actionText: "Leave",
      actionIcon: Icons.arrow_back,
      onActionPressed: () async {
        ref.read(conversationIsLoadingProvider.notifier).state = true;
        try {
          await supabase.from('conversation_participants').delete().eq('conversation_id', conversationId).eq('user_id', currentUserId);
          ref.invalidate(conversationDetailsProvider);
          print('Leave conversation requested: $conversationId');
        } catch (e) {
          log(e.toString());
          if (context.mounted) {
            Popup.showError(text: "Error happened while leaving the conversation", context: context);
          }
        } finally {
          ref.read(conversationIsLoadingProvider.notifier).state = false;
        }
      },
      actionColor: Colors.red,
    );
  }
}

// Parameter class for group creation
class GroupChatParams {
  final List<String> userIds;
  final String groupName;

  GroupChatParams({required this.userIds, required this.groupName});
}
