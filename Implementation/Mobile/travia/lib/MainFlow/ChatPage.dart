import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:swipe_to/swipe_to.dart';
import 'package:travia/Classes/ConversationParticipants.dart';
import 'package:travia/Helpers/DummyCards.dart';
import 'package:travia/Helpers/Loading.dart';
import 'package:travia/Helpers/PopUp.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../Classes/ChatDetails.dart';
import '../Classes/message_class.dart';
import '../Helpers/AppColors.dart';
import '../Helpers/Constants.dart';
import '../Helpers/DeleteConfirmation.dart';
import '../Helpers/EncryptionHelper.dart';
import '../Helpers/HelperMethods.dart';
import '../Providers/ChatDetailsProvider.dart';
import '../Providers/ImagePickerProvider.dart';
import '../Providers/UploadProviders.dart';
import '../RecorderService/SimpleRecorder.dart';
import '../Services/UserPresenceService.dart';
import '../database/DatabaseMethods.dart';
import '../main.dart';
import 'MediaPreview.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String conversationId;
  const ChatPage({super.key, required this.conversationId});

  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  static String? _lastMessageContent;
  static DateTime? _lastMessageTime;
  static String? _lastConversationId;

  @override
  void initState() {
    super.initState();
    print("CONV ID: ${widget.conversationId}");

    Future.microtask(() {
      markMessagesAsRead(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to messages changes for new message detection and read status
    ref.listen(messagesProvider(widget.conversationId), (previous, next) {
      next.whenData((messages) {
        final pendingMessages = ref.read(pendingMessagesProvider);

        // Check for new messages (previously in _setupMessageListener)
        if (previous?.valueOrNull?.length != messages.length) {
          final newMessage = messages.firstWhere(
            (m) => m.senderId != currentUserId && !pendingMessages.containsKey(m.messageId),
            orElse: () => messages.first,
          );

          if (newMessage.senderId != currentUserId) {
            _debounceTimer?.cancel();
            _debounceTimer = Timer(Duration(milliseconds: 100), () {
              markMessagesAsRead(widget.conversationId);
            });
          }
        }

        // Clean up pending messages (previously in _setupPendingMessagesCleanup)
        final updatedPendingMessages = Map<String, MessageClass>.from(pendingMessages);

        for (final message in messages) {
          if (pendingMessages.containsKey(message.messageId) && pendingMessages[message.messageId]!.isConfirmed) {
            updatedPendingMessages.remove(message.messageId);
          }
        }

        if (updatedPendingMessages.length != pendingMessages.length) {
          ref.read(pendingMessagesProvider.notifier).update((state) => updatedPendingMessages);
        }
      });
    });

    final pendingMessages = ref.watch(pendingMessagesProvider);
    final chatPageAsync = ref.watch(chatPageCombinedProvider(widget.conversationId));

    return chatPageAsync.when(
        data: (chatData) => Scaffold(
              resizeToAvoidBottomInset: true,
              backgroundColor: kBackground,
              appBar: ChatAppBar(
                conversationId: widget.conversationId,
                metadata: chatData.metadata,
              ),
              body: ChatBodyContainer(
                conversationId: widget.conversationId,
                scrollController: _scrollController,
                currentUserId: currentUserId,
                pendingMessages: pendingMessages,
                messageController: _messageController,
                metadata: chatData.metadata,
                messages: chatData.messages,
                participants: chatData.participants,
                onSendMessage: sendMessage,
              ),
            ),
        loading: () => Container(
              decoration: backGroundColor(),
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: const ChatAppBarSkeleton(),
                body: Center(
                  child: ListView.builder(
                    itemCount: 10,
                    itemBuilder: (context, index) => Skeletonizer(child: DummyMessageBubble()),
                  ),
                ),
              ),
            ),
        error: (error, stack) {
          print(error);
          print(stack);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go("/error-page/${Uri.encodeComponent(error.toString())}/${Uri.encodeComponent("/messages/${widget.conversationId}")}");
            }
          });
          return const Center(child: Text("An error occurred."));
        });
  }

  Future<void> sendMessage({
    required content,
    required contentType,
    required List<String> target_user_ids,
  }) async {
    if (content.isEmpty) return;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) return;

    // Duplicate message prevention
    final now = DateTime.now();
    final contentString = content.toString();

    // Check for duplicate within 1 second for the same conversation
    if (_lastMessageContent == contentString && _lastConversationId == widget.conversationId && _lastMessageTime != null && now.difference(_lastMessageTime!) < const Duration(seconds: 1)) {
      print('Duplicate message detected, skipping send');
      return;
    }

    // Update tracking variables
    _lastMessageContent = contentString;
    _lastMessageTime = now;
    _lastConversationId = widget.conversationId;

    try {
      // Get conversation type to determine blocking logic
      final conversationResponse = await supabase.from('conversations').select('conversation_type').eq('conversation_id', widget.conversationId).single();

      final conversationType = conversationResponse['conversation_type'];

      // Only check blocking for direct conversations
      List<String> validTargetUsers = [];

      if (conversationType == 'direct') {
        // For direct chats, check if users can interact
        for (String targetUserId in target_user_ids) {
          if (targetUserId == currentUserId) continue;

          final canInteract = await supabase.rpc('can_users_interact', params: {
            'user1_id': currentUserId,
            'user2_id': targetUserId,
          });

          if (!canInteract) {
            Popup.showError(text: "Cannot send message, blocked relationship.", context: context);
            return;
          }

          validTargetUsers.add(targetUserId);
        }
      } else {
        // For group chats, include all target users but filter for notifications later
        validTargetUsers = target_user_ids.where((id) => id != currentUserId).toList();
      }

      final replyMessage = ref.read(replyMessageProvider);
      final messageId = Uuid().v4();

      // ENCRYPT THE CONTENT HERE
      String encryptedContent = content;
      String? encryptedReplyContent;

      // Encrypt based on content type
      if (contentType == 'text' || contentType == 'image' || contentType == 'video' || contentType == 'gif' || contentType == 'record' || contentType == 'story_reply') {
        encryptedContent = EncryptionHelper.encryptContent(content.toString(), widget.conversationId);
      }

      // Encrypt reply content if exists
      if (replyMessage != null && replyMessage.content.isNotEmpty) {
        encryptedReplyContent = EncryptionHelper.encryptContent(replyMessage.content, widget.conversationId);
      }

      // Create placeholder with ORIGINAL content for UI
      final placeholder = MessageClass(
          messageId: messageId,
          conversationId: widget.conversationId,
          senderId: currentUserId,
          content: content, // Use original content for UI
          contentType: contentType,
          sentAt: DateTime.now().toUtc(),
          readBy: {currentUserId: DateTime.now().toUtc().toIso8601String()},
          isEdited: false,
          replyToMessageId: replyMessage?.messageId,
          replyToMessageContent: replyMessage?.content, // Original content
          reactions: null,
          isConfirmed: false,
          isDeleted: false,
          deletedForMeId: [],
          senderProfilePic: 'https://cqcsgwlskhuylgbqegnz.supabase.co/storage/v1/object/public/stories/TraviaStories/NeIevdY1yJX0YVrOtlzaIJbTHum2/1748921970453.jpg');

      ref.read(pendingMessagesProvider.notifier).update((state) => {
            ...state,
            messageId: placeholder,
          });

      // Send to database with ENCRYPTED content
      await supabase
          .from('messages')
          .insert({
            'message_id': messageId,
            'conversation_id': widget.conversationId,
            'sender_id': currentUserId,
            'content': encryptedContent, // Encrypted content
            'content_type': contentType,
            'reply_to_message_id': replyMessage?.messageId,
            'reply_to_message_content': encryptedReplyContent, // Encrypted reply
          })
          .select('message_id')
          .single();

      ref.read(replyMessageProvider.notifier).state = null;

      ref.read(pendingMessagesProvider.notifier).update((state) {
        final newState = Map<String, MessageClass>.from(state);
        newState[messageId] = placeholder.copyWith(isConfirmed: true);
        return newState;
      });

      // Send notifications with smart filtering
      List<String> notificationTargets = [];

      if (conversationType == 'direct') {
        // For direct chats, we already verified interaction capability
        notificationTargets = validTargetUsers;
      } else {
        // For group chats, check interaction capability only for notifications
        for (String target_user_id in validTargetUsers) {
          final canInteract = await supabase.rpc('can_users_interact', params: {
            'user1_id': currentUserId,
            'user2_id': target_user_id,
          });

          if (canInteract) {
            notificationTargets.add(target_user_id);
          }
        }
      }

      // Send notifications only to users who can receive them
      for (String target_user_id in notificationTargets) {
        await sendNotification(
            type: 'message',
            title: "sent you a message",
            content: contentType == "text"
                ? content // Use original content for notification
                : contentType == 'record'
                    ? "New Record 🎙️"
                    : "New Media 📷",
            target_user_id: target_user_id,
            source_id: widget.conversationId,
            sender_user_id: FirebaseAuth.instance.currentUser!.uid);
      }
    } catch (e) {
      // Reset tracking on error to allow retry
      _lastMessageContent = null;
      _lastMessageTime = null;
      _lastConversationId = null;

      // Handle specific blocking errors
      if (e.toString().contains('blocked') || e.toString().contains('interact')) {
        Popup.showError(text: "Cannot send message, blocked relationship.", context: context);
      } else {
        // Handle other errors
        ref.read(pendingMessagesProvider.notifier).update((state) {
          final newState = Map<String, MessageClass>.from(state);
          final messageId = state.keys.last; // Get the last message ID
          if (state.containsKey(messageId)) {
            newState[messageId] = state[messageId]!.copyWith(content: '${state[messageId]!.content} (Failed)');
          }
          return newState;
        });

        Popup.showError(text: "Failed to send message, try again", context: context);
        print(e);
      }
    }
  }
}

class ChatBodyContainer extends StatelessWidget {
  final String conversationId;
  final ScrollController scrollController;
  final String currentUserId;
  final Map<String, MessageClass> pendingMessages;
  final TextEditingController messageController;
  final ChatDetails metadata;
  final List<MessageClass> messages;
  final List<ConversationParticipants> participants;
  final Future<void> Function({
    required String content,
    required String contentType,
    required List<String> target_user_ids,
  }) onSendMessage;

  const ChatBodyContainer({
    super.key,
    required this.conversationId,
    required this.scrollController,
    required this.currentUserId,
    required this.pendingMessages,
    required this.messageController,
    required this.onSendMessage,
    required this.metadata,
    required this.messages,
    required this.participants,
  });

  @override
  Widget build(BuildContext context) {
    var keyBoardSize = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(color: kBackground),
      child: Column(
        children: [
          Expanded(
            child: MessagesList(
              conversationId: conversationId,
              scrollController: scrollController,
              currentUserId: currentUserId,
              pendingMessages: pendingMessages,
              messages: messages,
              participants: participants,
            ),
          ),
          MessageInputBar(
            messageController: messageController,
            onSendMessage: onSendMessage,
            keyboardSize: keyBoardSize,
            conversationId: conversationId,
            currentUserId: currentUserId,
            metadata: metadata,
            participants: participants,
          ),
        ],
      ),
    );
  }
}

class ChatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String conversationId;
  final ChatDetails metadata;
  @override
  final Size preferredSize;

  const ChatAppBar({super.key, required this.conversationId, required this.metadata}) : preferredSize = const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMessages = ref.watch(messageActionsProvider);

    if (selectedMessages.isNotEmpty) {
      return _buildActionModeAppBar(context, ref, selectedMessages);
    }

    return AppBar(
      forceMaterialTransparency: true,
      elevation: 0,
      title: _buildAppBarTitle(context, metadata),
    );
  }

  Widget _buildActionModeAppBar(BuildContext context, WidgetRef ref, Set<MessageClass> selectedMessages) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Remove the contentType check from canDelete - users should be able to delete their own messages regardless of type
    final canDelete = selectedMessages.every((m) => m.senderId == currentUserId);

    // Keep canEdit only for text messages
    final canEdit = selectedMessages.length == 1 && selectedMessages.first.senderId == currentUserId && selectedMessages.first.contentType == 'text';

    final canReply = selectedMessages.length == 1;

    return AppBar(
      backgroundColor: Colors.grey[800],
      elevation: 4,
      leading: IconButton(
        icon: Icon(Icons.close, color: Colors.white),
        onPressed: () {
          ref.read(messageActionsProvider.notifier).clearSelectedMessages();
        },
      ),
      title: Text(
        '${selectedMessages.length} selected',
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
      actions: [
        // Only show copy button for text messages
        if (selectedMessages.every((m) => m.contentType == 'text'))
          IconButton(
            icon: Icon(Icons.copy, color: Colors.white),
            onPressed: () {
              final content = selectedMessages.map((m) => m.content).join('\n');
              Clipboard.setData(ClipboardData(text: content));
              Popup.showInfo(text: "Copied to clipboard!", context: context);
              ref.read(messageActionsProvider.notifier).clearSelectedMessages();
            },
          ),
        if (canEdit)
          IconButton(
            icon: Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              final message = selectedMessages.first;
              ref.read(messageEditProvider.notifier).startEditing(message);
              ref.read(messageActionsProvider.notifier).clearSelectedMessages();
            },
          ),
        if (canReply)
          IconButton(
            icon: Icon(Icons.reply, color: Colors.white),
            onPressed: () {
              final message = selectedMessages.first;
              ref.read(replyMessageProvider.notifier).state = message;
              ref.read(messageActionsProvider.notifier).clearSelectedMessages();
            },
          ),
        IconButton(
          icon: Icon(Icons.delete, color: Colors.white),
          onPressed: () {
            _showDeleteConfirmation(context, ref, selectedMessages.toSet(), canDelete);
          },
        ),
      ],
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Set<MessageClass> messagesToDelete, bool canDelete) {
    final message = messagesToDelete.length == 1
        ? "Are you sure you want to delete this message? This action cannot be undone."
        : "Are you sure you want to delete all ${messagesToDelete.length} messages? This action cannot be undone.";

    final actions = <DialogAction>[];

    // Add delete for me action
    actions.add(DialogAction(
      text: 'For Me',
      icon: Icons.delete,
      onPressed: () async {
        ref.read(messageActionsProvider.notifier).clearSelectedMessages();
        try {
          final currentUserId = FirebaseAuth.instance.currentUser!.uid;
          for (final message in messagesToDelete) {
            await removeMessageForMe(messageId: message.messageId, currentUserId: currentUserId);
          }
        } catch (e) {
          Popup.showError(text: "Failed to delete messages", context: context);
        }
      },
    ));

    // Add delete for all action if permitted
    if (canDelete) {
      actions.add(DialogAction(
        text: 'For all',
        icon: Icons.delete_forever,
        onPressed: () async {
          ref.read(messageActionsProvider.notifier).clearSelectedMessages();
          try {
            for (final message in messagesToDelete) {
              await removeMessage(messageId: message.messageId);
            }
          } catch (e) {
            Popup.showError(text: "Failed to delete messages", context: context);
          }
        },
      ));
    }

    showCustomDialogWithMultipleActions(
      context: context,
      title: 'Delete Messages',
      message: message,
      actions: actions,
    );
  }

  Widget _buildAppBarTitle(BuildContext context, ChatDetails metadata) {
    return GestureDetector(
      onTap: () {
        if (metadata.conversationType == 'direct') {
          context.push("/profile/${metadata.receiverId}");
        } else {
          context.push('/group-members/${conversationId}');
        }
      },
      child: Row(
        children: [
          ChatAvatar(metadata: metadata),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metadata.conversationType == 'direct' ? (metadata.receiverUsername ?? 'Direct Message') : (metadata.title ?? 'Group Conversation'),
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                _buildSubtitle(metadata),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle(ChatDetails metadata) {
    if (metadata.conversationType == 'direct' && metadata.receiverId != null) {
      return UserStatusIndicator(userId: metadata.receiverId!);
    } else {
      return Text(
        '${metadata.numberOfParticipants} Members',
        style: GoogleFonts.ibmPlexSans(
          fontSize: 12,
          color: Colors.black54,
        ),
      );
    }
  }
}

class ChatAvatar extends StatelessWidget {
  final ChatDetails metadata;

  const ChatAvatar({Key? key, required this.metadata}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundImage: FadeInImage(
        placeholder: AssetImage('assets/placeholder_image.png'),
        image: NetworkImage(
          metadata.conversationType == 'direct'
              ? (metadata.receiverPhotoUrl ?? "https://ui-avatars.com/api/?name=${metadata.receiverUsername ?? 'DM'}&rounded=true&background=random")
              : (metadata.groupChatPicture ?? "https://ui-avatars.com/api/?name=${metadata.title ?? 'GC'}&rounded=true&background=random"),
        ),
      ).image,
    );
  }
}

class MessagesList extends ConsumerWidget {
  final String conversationId;
  final ScrollController scrollController;
  final String currentUserId;
  final Map<String, MessageClass> pendingMessages;
  final List<MessageClass> messages;
  final List<ConversationParticipants> participants;
  const MessagesList({
    Key? key,
    required this.conversationId,
    required this.scrollController,
    required this.currentUserId,
    required this.pendingMessages,
    required this.participants,
    required this.messages,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typingUsersAsyncValue = ref.watch(otherTypingProvider(conversationId));

    return Column(
      children: [
        Expanded(child: _buildMessageList(messages, participants)),
        typingUsersAsyncValue.when(
            data: (typingUsers) {
              if (typingUsers.isNotEmpty) {
                return _buildTypingIndicator(typingUsers);
              } else {
                return const SizedBox.shrink();
              }
            },
            loading: () => const SizedBox.shrink(),
            error: (e, st) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  context.go("/error-page/${Uri.encodeComponent(e.toString())}/${Uri.encodeComponent("/messages/${conversationId}")}");
                }
              });
              return const Center(child: Text("An error occurred."));
            }),
      ],
    );
  }

  Widget _buildMessageList(List<MessageClass> messages, List<ConversationParticipants> participants) {
    final Map<String, MessageClass> messagesMap = {};

    // Add server messages
    for (final message in messages) {
      if (message.deletedForMeId.contains(currentUserId)) continue;
      messagesMap[message.messageId] = message;
    }

    // Add pending messages if not in server messages
    for (final pendingMessage in pendingMessages.values) {
      if (!messagesMap.containsKey(pendingMessage.messageId)) {
        messagesMap[pendingMessage.messageId] = pendingMessage;
      }
    }

    final allMessages = messagesMap.values.toList()..sort((a, b) => b.sentAt.compareTo(a.sentAt));

    if (allMessages.isEmpty) {
      return EmptyConversationIndicator();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients && scrollController.offset > 0) {
        scrollController.jumpTo(0);
      }
    });

    final participantIds = participants.map((p) => p.userId).toList();

    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: EdgeInsets.all(16),
      itemCount: allMessages.length,
      itemBuilder: (context, index) {
        final message = allMessages[index];
        final isCurrentUser = message.senderId == currentUserId;
        final isPending = pendingMessages.containsKey(message.messageId) && !message.isConfirmed;

        List<Widget> columnChildren = [];

        if (index == allMessages.length - 1 || !isSameDay(message.sentAt, allMessages[index + 1].sentAt)) {
          columnChildren.add(
            DateHeader(dateText: getDateHeader(message.sentAt)),
          );
        }

        columnChildren.add(
          MessageBubble(
            key: ValueKey(message.messageId),
            message: message.copyWith(
              replyToMessageContent: messagesMap[message.replyToMessageId]?.contentType == "text"
                  ? messagesMap[message.replyToMessageId]?.content
                  : messagesMap[message.replyToMessageId]?.contentType == "record"
                      ? "Replying To Record"
                      : messagesMap[message.replyToMessageId]?.contentType == "story_reply"
                          ? "Replying to story reply"
                          : "Replying To Media",
              replyToMessageSender: messagesMap[message.replyToMessageId]?.senderUsername,
            ),
            isCurrentUser: isCurrentUser,
            isPending: isPending,
            conversationId: conversationId,
            participantIds: participantIds,
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: columnChildren,
        );
      },
    );
  }
}

class EmptyConversationIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: kDeepPink.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: kDeepPink.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Start the conversation!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kDeepPink,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Send a message to begin your journey together',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kDeepPink, kDeepPinkLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: kDeepPink.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Type your first message below',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MessageInputBar extends ConsumerStatefulWidget {
  final TextEditingController messageController;
  final List<ConversationParticipants> participants;
  final Future<void> Function({
    required String content,
    required String contentType,
    required List<String> target_user_ids,
  }) onSendMessage;
  final double keyboardSize;
  final String conversationId;
  final String currentUserId;
  final ChatDetails metadata;

  const MessageInputBar({
    Key? key,
    required this.messageController,
    required this.onSendMessage,
    required this.conversationId,
    required this.currentUserId,
    required this.metadata,
    required this.participants,
    this.keyboardSize = 0,
  }) : super(key: key);

  @override
  ConsumerState<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends ConsumerState<MessageInputBar> {
  Timer? _debounceTimer;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    // Load saved draft on initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isInitialized) {
        final savedDraft = ref.read(messageDraftProvider.notifier).getDraft(widget.conversationId);
        if (savedDraft != null && savedDraft.isNotEmpty && widget.messageController.text.isEmpty) {
          widget.messageController.text = savedDraft;
          _isInitialized = true;
        }
      }
    });

    // Listen to text changes for draft saving
    widget.messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    // Cancel previous timer
    _debounceTimer?.cancel();

    // Update typing state immediately
    final text = widget.messageController.text;
    if (text.isNotEmpty) {
      ref.read(isTypingProvider.notifier).startTyping();
    } else {
      ref.read(isTypingProvider.notifier).stopTyping();
    }

    // Debounce draft saving (save after 500ms of no typing)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      ref.read(messageDraftProvider.notifier).saveDraft(
            widget.conversationId,
            widget.messageController.text,
          );
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.messageController.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editingMessage = ref.watch(messageEditProvider);
    final textDirection = ref.watch(textDirectionProvider);
    final isUploading = ref.watch(chatMediaUploadProvider);
    final isRecording = ref.watch(recordingStateProvider);

    // Handle editing message
    if (editingMessage != null && widget.messageController.text.isEmpty) {
      widget.messageController.text = editingMessage.content;
    }

    void cancelReply() {
      ref.read(replyMessageProvider.notifier).state = null;
    }

    ref.listen<bool>(isTypingProvider, (previous, next) async {
      if (previous != next) {
        await updateIsTyping(
          currentUserId: widget.currentUserId,
          conversationId: widget.conversationId,
          isTyping: next,
        );
      }
    });

    void handleSendOrUpdate() async {
      final text = widget.messageController.text.trim();
      if (text.isEmpty) return;

      final messageContent = text;
      widget.messageController.clear();

      try {
        if (editingMessage != null) {
          await updateMessage(content: messageContent, messageId: editingMessage.messageId);
          ref.read(messageEditProvider.notifier).updateContent(messageContent);
          ref.read(messageEditProvider.notifier).stopEditing();
        } else {
          await widget.onSendMessage(
            content: messageContent,
            contentType: "text",
            target_user_ids: widget.participants.where((p) => p.userId != widget.currentUserId).map((p) => p.userId).toList(),
          );
          ref.read(isTypingProvider.notifier).stopTyping();

          // Clear the reply message after sending
          ref.read(replyMessageProvider.notifier).state = null;
        }

        // Clear the draft after sending
        ref.read(messageDraftProvider.notifier).clearDraft(widget.conversationId);
        cancelReply();
      } catch (e) {
        if (widget.messageController.text.trim().isEmpty) {
          widget.messageController.text = messageContent;
        }
        print('Error sending message: $e');
      }
    }

    void cancelEditing() {
      ref.read(messageEditProvider.notifier).stopEditing();
      widget.messageController.clear();
      // Save current text as draft when canceling edit
      ref.read(messageDraftProvider.notifier).saveDraft(
            widget.conversationId,
            widget.messageController.text,
          );
    }

    final replyMessage = ref.watch(replyMessageProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: isRecording
          ? Dismissible(
              key: const Key('recording_interface'),
              direction: DismissDirection.down,
              dismissThresholds: const {
                DismissDirection.down: 0.3, // 30% swipe to trigger dismiss
              },
              onDismissed: (direction) {
                ref.read(recordingStateProvider.notifier).stopRecording();
                ref.read(recordingDurationProvider.notifier).state = 0;
                ref.read(recordingPausedProvider.notifier).state = false;
              },
              child: RecordingInterface(
                onCancel: () {
                  ref.read(recordingStateProvider.notifier).stopRecording();
                },
                onStop: (path) async {
                  String? url = await uploadRecordToDatabase(
                    localPath: path,
                    userId: widget.currentUserId,
                  );
                  if (url != null) {
                    await widget.onSendMessage(
                      content: url,
                      contentType: "record",
                      target_user_ids: widget.participants.where((p) => p.userId != widget.currentUserId).map((p) => p.userId).toList(),
                    );
                  }
                },
              ),
            )
          : AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: widget.keyboardSize > 0 ? widget.keyboardSize * 0.01 : 0,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                color: kBackground,
                child: Column(
                  children: [
                    if (replyMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: kDeepPink.withOpacity(0.05),
                          border: Border(
                            left: BorderSide(
                              color: kDeepPink,
                              width: 4,
                            ),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: kDeepPink.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                getReplyIcon(replyMessage.contentType),
                                color: kDeepPink,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Replying to ${replyMessage.senderUsername ?? 'someone'}',
                                    style: GoogleFonts.lexendDeca(
                                      color: kDeepPink,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    getReplyPreviewText(replyMessage),
                                    style: GoogleFonts.lexendDeca(
                                      color: Colors.black87,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                onPressed: cancelReply,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        if (editingMessage != null)
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: cancelEditing,
                          ),
                        isUploading
                            ? SizedBox(
                                width: MediaQuery.sizeOf(context).width * 0.101,
                                child: LoadingWidget(),
                              )
                            : IconButton(
                                icon: const Icon(Icons.add, color: kDeepPinkLight),
                                onPressed: () async {
                                  // Clear any previously selected files
                                  ref.read(multiMediaPickerProvider.notifier).clearFiles();

                                  // Open the multiple media picker
                                  await ref.read(multiMediaPickerProvider.notifier).pickMultipleMedia(context);

                                  // Get the selected files after picker is closed
                                  final mediaFiles = ref.read(multiMediaPickerProvider);

                                  // If no files were selected, return early
                                  if (mediaFiles.isEmpty) return;

                                  // Show loading indicator if multiple files selected
                                  if (mediaFiles.length > 1) {
                                    Popup.showInfo(
                                      text: "Uploading ${mediaFiles.length} files...",
                                      context: context,
                                    );
                                  }

                                  // Process each selected file
                                  for (final mediaFile in mediaFiles) {
                                    // Upload the media file
                                    final mediaUrl = await ref.read(chatMediaUploadProvider.notifier).uploadChatMedia(userId: widget.currentUserId, mediaFile: mediaFile, context: context);

                                    // If upload failed, continue to next file
                                    if (mediaUrl == null) continue;

                                    // Determine if it's a video
                                    final isVideo = isPathVideo(mediaFile.path);

                                    try {
                                      // Send the message with the uploaded media
                                      await widget.onSendMessage(
                                        content: mediaUrl,
                                        contentType: isVideo ? 'video' : 'image',
                                        target_user_ids: widget.participants.where((p) => p.userId != widget.currentUserId).map((p) => p.userId).toList(),
                                      );
                                    } catch (e) {
                                      Popup.showError(
                                        text: "Failed sending media",
                                        context: context,
                                      );
                                    }
                                  }

                                  // Clear the files after processing
                                  ref.read(multiMediaPickerProvider.notifier).clearFiles();

                                  // Show success message if multiple files were sent
                                  if (mediaFiles.length > 1) {
                                    Popup.showSuccess(
                                      text: "Sent ${mediaFiles.length} media files",
                                      context: context,
                                    );
                                  }
                                },
                              ),
                        SimpleRecorderButton(
                          onStop: (path) async {
                            debugPrint('Audio saved at: $path');
                            String? url = await uploadRecordToDatabase(
                              localPath: path,
                              userId: widget.currentUserId,
                            );
                            if (url != null) {
                              print("Record saved at $url");
                              widget.onSendMessage(
                                content: url,
                                contentType: "record",
                                target_user_ids: widget.participants.where((p) => p.userId != widget.currentUserId).map((p) => p.userId).toList(),
                              );
                            }
                          },
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 150),
                              child: TextField(
                                controller: widget.messageController,
                                cursorColor: Colors.black,
                                maxLines: null,
                                minLines: 1,
                                textDirection: textDirection,
                                onChanged: (text) {
                                  if (text.isEmpty || (text.length == 1) || (text.isNotEmpty && textDirection != getTextDirectionForText(text))) {
                                    updateTextDirection(ref, text);
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: editingMessage != null ? "Edit message..." : "Type a message...",
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: kDeepPinkLight),
                          onPressed: () => handleSendOrUpdate(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class RecordingInterface extends ConsumerStatefulWidget {
  final void Function(String path) onStop;
  final VoidCallback onCancel;

  const RecordingInterface({
    Key? key,
    required this.onStop,
    required this.onCancel,
  }) : super(key: key);

  @override
  _RecordingInterfaceState createState() => _RecordingInterfaceState();
}

class _RecordingInterfaceState extends ConsumerState<RecordingInterface> with TickerProviderStateMixin {
  final _recorder = AudioRecorder();
  Timer? _timer;
  String? _recordPath;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      lowerBound: 0.9,
      upperBound: 1.1,
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _slideController.forward();
    _startRecording();
  }

  Future<void> _startRecording() async {
    if (await _recorder.hasPermission()) {
      final path = '${Directory.systemTemp.path}/rec_${const Uuid().v4()}.mp3';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      setState(() => _recordPath = path);
      _startTimer();
      _pulseController.repeat(reverse: true);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!ref.read(recordingPausedProvider)) {
        ref.read(recordingDurationProvider.notifier).state++;
      }
    });
  }

  Future<void> _pauseRecording() async {
    await _recorder.pause();
    ref.read(recordingPausedProvider.notifier).state = true;
    _pulseController.stop();
  }

  Future<void> _resumeRecording() async {
    await _recorder.resume();
    ref.read(recordingPausedProvider.notifier).state = false;
    _pulseController.repeat(reverse: true);
  }

  Future<void> _stopAndSend() async {
    _timer?.cancel();
    _pulseController.stop();
    await _recorder.stop();
    ref.read(recordingStateProvider.notifier).stopRecording();
    ref.read(recordingDurationProvider.notifier).state = 0;
    ref.read(recordingPausedProvider.notifier).state = false;

    if (_recordPath != null) {
      widget.onStop(_recordPath!);
    }
  }

  Future<void> _discardRecording() async {
    await _slideController.reverse();
    _timer?.cancel();
    _pulseController.stop();
    await _recorder.stop();

    // Delete the temporary file
    if (_recordPath != null) {
      try {
        final file = File(_recordPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('Error deleting recording: $e');
      }
    }

    ref.read(recordingStateProvider.notifier).stopRecording();
    ref.read(recordingDurationProvider.notifier).state = 0;
    ref.read(recordingPausedProvider.notifier).state = false;
    widget.onCancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _slideController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPaused = ref.watch(recordingPausedProvider);
    final duration = ref.watch(recordingDurationProvider);

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: kDeepPink.withOpacity(0.1),
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Recording status
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!isPaused)
                          ScaleTransition(
                            scale: _pulseController,
                            child: Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.mic,
                                color: Colors.red,
                                size: 32,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.pause,
                              color: Colors.orange,
                              size: 32,
                            ),
                          ),
                        SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPaused ? 'Recording Paused' : 'Recording...',
                              style: GoogleFonts.lexendDeca(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: GoogleFonts.lexendDeca(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: kDeepPink,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: 32),

                    // Control buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Delete button
                        _buildControlButton(
                          onPressed: _discardRecording,
                          icon: Icons.delete_outline,
                          label: 'Delete',
                          color: Colors.red,
                        ),

                        // Pause/Resume button
                        _buildControlButton(
                          onPressed: isPaused ? _resumeRecording : _pauseRecording,
                          icon: isPaused ? Icons.play_arrow : Icons.pause,
                          label: isPaused ? 'Resume' : 'Pause',
                          color: Colors.orange,
                        ),

                        // Send button
                        _buildControlButton(
                          onPressed: _stopAndSend,
                          icon: Icons.send_rounded,
                          label: 'Send',
                          color: kDeepPink,
                          isPrimary: true,
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Swipe to cancel hint
                    Text(
                      'Swipe down to cancel',
                      style: GoogleFonts.lexendDeca(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    bool isPrimary = false,
    bool isDisabled = false,
  }) {
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: isPrimary
                  ? LinearGradient(
                      colors: [kDeepPinkLight, kDeepPink],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: !isPrimary ? color.withOpacity(0.1) : null,
              shape: BoxShape.circle,
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: kDeepPink.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isDisabled ? null : onPressed,
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: EdgeInsets.all(16),
                  child: Icon(
                    icon,
                    color: isPrimary ? Colors.white : color,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.lexendDeca(
              fontSize: 12,
              color: isDisabled ? Colors.grey : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }
}

class MessageBubble extends ConsumerWidget {
  final MessageClass message;
  final bool isCurrentUser;
  final bool isPending;
  final String conversationId;
  final List<String> participantIds;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isCurrentUser,
    this.isPending = false,
    required this.conversationId,
    required this.participantIds,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nonSenderParticipants = participantIds.where((id) => id != message.senderId).toSet();
    final readers = message.readBy?.keys.toSet() ?? {};

    // Read if all non-sender participants have an entry in readBy
    bool isRead = message.readBy != null && nonSenderParticipants.isNotEmpty && nonSenderParticipants.difference(readers).isEmpty;

    final selectedMessages = ref.watch(messageActionsProvider);
    final isSelected = selectedMessages.contains(message);
    final hasSelection = selectedMessages.isNotEmpty;

    // Check if this is a story reply message
    final isStoryReply = message.contentType == 'story_reply';

    // For story reply, parse content to separate media URL and message
    String? storyMediaUrl;
    String messageContent = message.content;

    if (isStoryReply && !message.isDeleted) {
      final contentParts = message.content.split(' ');
      if (contentParts.length > 1) {
        storyMediaUrl = contentParts[0];
        messageContent = contentParts.sublist(1).join(' ');
      }
    }

    // Determine content type and build appropriate bubble
    if ((message.contentType == 'text' || message.isDeleted) && !isStoryReply) {
      return _buildSwipeWrapper(context, ref, _buildTextBubble(context, ref, isRead, isSelected, hasSelection));
    } else if (message.contentType == 'record' && !message.isDeleted) {
      return _buildSwipeWrapper(context, ref, _buildAudioBubble(context, ref, isRead, isSelected, hasSelection));
    } else if (isStoryReply && !message.isDeleted) {
      // Add special case for story reply
      return _buildSwipeWrapper(context, ref, _buildStoryReplyBubble(context, ref, isRead, isSelected, hasSelection, storyMediaUrl ?? '', messageContent));
    } else if (message.contentType == 'plan' && !message.isDeleted) {
      return _buildPlanBubble(context, ref, isRead, isSelected, hasSelection);
    } else {
      // Media messages
      return _buildSwipeWrapper(context, ref, _buildMediaBubble(context, ref, isSelected, hasSelection));
    }
  }

  // PLAN BUBBLE
  Widget _buildPlanBubble(BuildContext context, WidgetRef ref, bool isRead, bool isSelected, bool hasSelection) {
    final planDetailsAsync = ref.watch(planDetailsProvider(message.content));

    final bubbleContent = planDetailsAsync.when(
      data: (planDetails) {
        final itinerary = planDetails.itinerary;
        final businesses = planDetails.businesses;
        print("ITINERARY DATA: $itinerary");

        String? getCoverPhoto() {
          if (businesses.isEmpty) return null;
          final businessesWithPhotos = businesses.where((b) => b['photos'] != null && (b['photos'] as List).isNotEmpty).toList();
          if (businessesWithPhotos.isEmpty) return null;
          return (businessesWithPhotos.first['photos'] as List).first as String?;
        }

        final coverPhotoUrl = getCoverPhoto();

        return Column(
          crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isCurrentUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0, left: 12.0, top: 8.0),
                child: Text(
                  message.senderUsername ?? 'Unknown',
                  style: TextStyle(color: kDeepPink, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            GestureDetector(
              onTap: () {
                context.push("/plan-result/${itinerary["trip_id"]}");
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4.0, 4.0, 4.0, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (coverPhotoUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          height: 110,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          imageUrl: coverPhotoUrl,
                          placeholder: (context, url) => Container(height: 110, color: Colors.grey[300]),
                          errorWidget: (context, url, error) => Container(height: 110, color: Colors.grey[300], child: Icon(Icons.image_not_supported)),
                        ),
                      )
                    else
                      Container(
                        height: 110,
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12)),
                        child: Center(child: Icon(Icons.map_outlined, color: Colors.grey[600], size: 40)),
                      ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        itinerary['trip_name'] ?? 'Trip Plan',
                        style: GoogleFonts.lexendDeca(fontWeight: FontWeight.bold, fontSize: 14, color: isCurrentUser ? Colors.white : Colors.grey[900]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: isCurrentUser ? Colors.white70 : Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text("${itinerary['preferences_snapshot']['travel_days'] ?? 1} days", style: GoogleFonts.lexendDeca(fontSize: 12, color: isCurrentUser ? Colors.white70 : Colors.grey[700])),
                          const SizedBox(width: 10),
                          Icon(Icons.place, size: 12, color: isCurrentUser ? Colors.white70 : Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text("${businesses.length} places", style: GoogleFonts.lexendDeca(fontSize: 12, color: isCurrentUser ? Colors.white70 : Colors.grey[700])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 6),
              child: _buildTimestampAndReadStatus(isRead),
            ),
          ],
        );
      },
      loading: () => Skeletonizer(
        enabled: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isCurrentUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0, left: 12.0, top: 8.0),
                child: Text(
                  message.senderUsername ?? 'Unknown',
                  style: TextStyle(color: kDeepPink, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 110,
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12)),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Bone.text(words: 3, style: GoogleFonts.lexendDeca(fontSize: 14)),
                  ),
                  const SizedBox(height: 5),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Bone.text(words: 4, style: GoogleFonts.lexendDeca(fontSize: 12)),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, right: 4, bottom: 2),
                    child: Bone.text(words: 1, style: TextStyle(fontSize: 11)),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
      error: (err, stack) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 20.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: isCurrentUser ? Colors.white70 : Colors.grey[700], size: 16),
            const SizedBox(width: 8),
            Text('Plan was deleted', style: TextStyle(color: isCurrentUser ? Colors.white70 : Colors.grey[700])),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            _buildAvatar(context),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: hasSelection ? () => ref.read(messageActionsProvider.notifier).toggleSelectedMessage(message) : () => print("Plan bubble tapped!"),
            onLongPress: () => ref.read(messageActionsProvider.notifier).toggleSelectedMessage(message),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.65, // Reduced max width
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.grey.withOpacity(0.5)
                    : isCurrentUser
                        ? (isPending ? kDeepPink.withOpacity(0.7) : kDeepPink)
                        : Colors.white,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: isCurrentUser ? const Radius.circular(20) : const Radius.circular(0),
                  bottomRight: isCurrentUser ? const Radius.circular(0) : const Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isCurrentUser ? kDeepPink : Colors.grey).withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                gradient: isCurrentUser
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [kDeepPink, kDeepPink.withOpacity(0.9)],
                      )
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: bubbleContent,
              ),
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(width: 8),
            _buildAvatar(context),
          ],
        ],
      ),
    );
  }

  // Build a text message bubble
  Widget _buildTextBubble(BuildContext context, WidgetRef ref, bool isRead, bool isSelected, bool hasSelection) {
    final String content = "${message.content}${message.isEdited ? ' (edited)' : ''}";
    final bool isEmojiOnlyMessage = isEmojiOnly(message.content);
    final bool isTextMessage = message.contentType == 'text' || message.content.toLowerCase() == "deleted";

    final bubbleColor = isSelected
        ? Colors.grey.withOpacity(0.5)
        : isCurrentUser
            ? (isPending ? kDeepPink.withOpacity(0.7) : kDeepPink)
            : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            _buildAvatar(context),
            SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: hasSelection
                ? () {
                    ref.read(messageActionsProvider.notifier).toggleSelectedMessage(message);
                  }
                : null,
            onLongPress: () {
              ref.read(messageActionsProvider.notifier).toggleSelectedMessage(message);
            },
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isEmojiOnlyMessage ? 8 : 16,
                vertical: isEmojiOnlyMessage ? 6 : 10,
              ),
              decoration: isEmojiOnlyMessage
                  ? null
                  : BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(20).copyWith(
                        bottomLeft: isCurrentUser ? Radius.circular(20) : Radius.circular(0),
                        bottomRight: isCurrentUser ? Radius.circular(0) : Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isCurrentUser ? kDeepPink : Colors.grey).withOpacity(0.2),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                      gradient: isCurrentUser
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                kDeepPink,
                                kDeepPink.withOpacity(0.9),
                              ],
                            )
                          : null,
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        message.senderUsername ?? 'Unknown',
                        style: TextStyle(
                          color: kDeepPink,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  _buildReplyPreview(),
                  if (isTextMessage)
                    Text(
                      content,
                      textDirection: isMostlyRtl(content),
                      style: TextStyle(
                        fontSize: isEmojiOnlyMessage ? 28 : 15,
                        fontStyle: (message.isEdited || message.isDeleted) ? FontStyle.italic : FontStyle.normal,
                        color: message.isDeleted
                            ? Colors.grey
                            : isEmojiOnlyMessage
                                ? (isCurrentUser ? kDeepPink : Colors.black87)
                                : isCurrentUser
                                    ? kWhite
                                    : Colors.black87,
                      ),
                    )
                  else
                    MediaPreview(
                      mediaUrl: message.content,
                      isVideo: isPathVideo(message.content),
                    ),
                  SizedBox(height: 4),
                  _buildTimestampAndReadStatus(isRead),
                ],
              ),
            ),
          ),
          if (isCurrentUser) ...[
            SizedBox(width: 8),
            _buildAvatar(context),
          ],
        ],
      ),
    );
  }

  // Story Reply Bubble
  Widget _buildStoryReplyBubble(BuildContext context, WidgetRef ref, bool isRead, bool isSelected, bool hasSelection, String storyMediaUrl, String messageText) {
    final isVideo = isPathVideo(storyMediaUrl);
    final isImage = !isVideo;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            _buildAvatar(context),
            SizedBox(width: 8),
          ] else if (!isCurrentUser) ...[
            SizedBox(width: 40), // Space for avatar alignment
          ],
          GestureDetector(
            onTap: hasSelection
                ? () {
                    ref.read(messageActionsProvider.notifier).toggleSelectedMessage(message);
                  }
                : null,
            onLongPress: () {
              ref.read(messageActionsProvider.notifier).toggleSelectedMessage(message);
            },
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.grey.withOpacity(0.5)
                    : isCurrentUser
                        ? (isPending ? kDeepPink.withOpacity(0.7) : kDeepPink)
                        : Colors.white,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: isCurrentUser ? Radius.circular(20) : Radius.circular(0),
                  bottomRight: isCurrentUser ? Radius.circular(0) : Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isCurrentUser ? kDeepPink : Colors.grey).withOpacity(0.2),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
                // Add gradient for more appealing bubbles
                gradient: isCurrentUser
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          kDeepPink,
                          kDeepPink.withOpacity(0.9),
                        ],
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2.0, left: 12.0, top: 6.0),
                      child: Text(
                        message.senderUsername ?? 'Unknown',
                        style: TextStyle(
                          color: kDeepPink,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  // Story Preview Container
                  Container(
                    margin: EdgeInsets.only(bottom: 6, left: 8, right: 8, top: isCurrentUser ? 6 : 0),
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrentUser ? kWhite.withOpacity(0.2) : kDeepPink.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          // Story Media Preview
                          Positioned.fill(
                            child: isImage
                                ? CachedNetworkImage(
                                    imageUrl: storyMediaUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          isCurrentUser ? Colors.white70 : kDeepPinkLight,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: Colors.grey[300],
                                      child: Icon(Icons.error, color: Colors.red),
                                    ),
                                  )
                                : isVideo
                                    ? VideoThumbnailWidget(videoUrl: storyMediaUrl)
                                    : Container(
                                        color: Colors.grey[300],
                                        child: Center(
                                          child: Icon(Icons.image_not_supported, color: Colors.grey[600]),
                                        ),
                                      ),
                          ),

                          // "Replied to a story" banner
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.6),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Text(
                                'Replied to a story',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Message Text
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      messageText,
                      textDirection: isMostlyRtl(messageText),
                      style: TextStyle(
                        color: isCurrentUser ? kWhite : Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                  ),

                  // Timestamp and Read Status
                  Padding(
                    padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
                    child: _buildTimestampAndReadStatus(isRead),
                  ),
                ],
              ),
            ),
          ),
          if (isCurrentUser) ...[
            SizedBox(width: 8),
            _buildAvatar(context),
          ] else if (isCurrentUser) ...[
            SizedBox(width: 40), // Space for avatar alignment
          ],
        ],
      ),
    );
  }

// Common reply widget
  Widget _buildReplyPreview() {
    if (message.replyToMessageId == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(8),
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrentUser ? kDeepPinkLight.withOpacity(0.3) : kDeepPink,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser ? Colors.white.withOpacity(0.2) : Colors.black54,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.replyToMessageSender ?? 'Unknown',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            message.replyToMessageContent!.length > 50 ? '${message.replyToMessageContent!.substring(0, 50)}...' : message.replyToMessageContent!,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaBubble(BuildContext context, WidgetRef ref, bool isSelected, bool hasSelection) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            _buildAvatar(context),
            SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: hasSelection
                ? () {
                    ref.read(messageActionsProvider.notifier).toggleSelectedMessage(message);
                  }
                : null,
            onLongPress: () {
              ref.read(messageActionsProvider.notifier).toggleSelectedMessage(message);
            },
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? Colors.grey.withOpacity(0.5) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Add this line
                crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  MediaPreview(
                    mediaUrl: message.content,
                    isVideo: isPathVideo(message.content),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                    child: Text(
                      formatTimeLabel(message.sentAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isCurrentUser) ...[
            SizedBox(width: 8),
            _buildAvatar(context),
          ],
        ],
      ),
    );
  }

  Widget _buildSwipeWrapper(BuildContext context, WidgetRef ref, Widget child) {
    return SwipeTo(
      key: ValueKey(message.messageId),
      onRightSwipe: isCurrentUser
          ? null
          : (details) {
              ref.read(replyMessageProvider.notifier).state = message;
            },
      onLeftSwipe: isCurrentUser
          ? (details) {
              ref.read(replyMessageProvider.notifier).state = message;
            }
          : null,
      animationDuration: Duration(milliseconds: 120),
      child: child,
    );
  }

  // Build an audio message bubble
  Widget _buildAudioBubble(BuildContext context, WidgetRef ref, bool isRead, bool isSelected, bool hasSelection) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            _buildAvatar(context),
            SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: hasSelection
                ? () {
                    ref.read(messageActionsProvider.notifier).toggleSelectedMessage(message);
                  }
                : null,
            onLongPress: () {
              ref.read(messageActionsProvider.notifier).toggleSelectedMessage(message);
            },
            child: Column(
              crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isCurrentUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0, left: 8.0),
                    child: Text(
                      message.senderUsername ?? 'Unknown',
                      style: TextStyle(
                        color: kDeepPinkLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                _buildReplyPreview(),
                // Audio message placed outside the bubble
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.grey.withOpacity(0.5) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: AudioMessage(audioUrl: message.content),
                ),
                SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                  child: _buildTimestampAndReadStatus(isRead),
                ),
              ],
            ),
          ),
          if (isCurrentUser) ...[
            SizedBox(width: 8),
            _buildAvatar(context),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push("/profile/${message.senderId}");
      },
      child: CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(
          message.senderProfilePic ?? "",
        ),
      ),
    );
  }

  // Common timestamp and read indicator
  Widget _buildTimestampAndReadStatus(bool isRead) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isPending ? "Sending..." : formatTimeLabel(message.sentAt),
          style: TextStyle(
            color: isCurrentUser ? Colors.white.withOpacity(0.7) : Colors.grey[500],
            fontSize: 11,
          ),
        ),
        if (isCurrentUser && !isPending) ...[
          SizedBox(width: 4),
          Icon(
            isRead ? Icons.done_all : Icons.done,
            size: 14,
            color: isRead ? Colors.greenAccent : Colors.white,
          ),
        ],
      ],
    );
  }
}

class AudioMessage extends ConsumerStatefulWidget {
  final String audioUrl;
  final VoidCallback? onPlaybackComplete;

  const AudioMessage({
    super.key,
    required this.audioUrl,
    this.onPlaybackComplete,
  });

  @override
  ConsumerState<AudioMessage> createState() => _AudioMessageState();
}

class _AudioMessageState extends ConsumerState<AudioMessage> {
  final _audioPlayer = ap.AudioPlayer()..setReleaseMode(ap.ReleaseMode.stop);
  late StreamSubscription<void> _playerCompleteSub;
  late StreamSubscription<Duration?> _durationChangedSub;
  late StreamSubscription<Duration> _positionChangedSub;

  @override
  void initState() {
    super.initState();

    _positionChangedSub = _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;
      ref.read(audioPositionProvider(widget.audioUrl).notifier).state = position;
    });

    _durationChangedSub = _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;
      ref.read(audioDurationProvider(widget.audioUrl).notifier).state = duration;
      ref.read(audioIsLoadingProvider(widget.audioUrl).notifier).state = false;
    });

    _playerCompleteSub = _audioPlayer.onPlayerComplete.listen((_) async {
      if (!mounted) return;
      await _stop();
      widget.onPlaybackComplete?.call();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final initialized = ref.read(audioInitializedProvider.notifier).isInitialized(widget.audioUrl);
      if (!initialized) {
        ref.read(audioIsLoadingProvider(widget.audioUrl).notifier).state = true;
        final success = await _initializeAudioSource();
        if (success) {
          if (mounted) {
            ref.read(audioInitializedProvider.notifier).markInitialized(widget.audioUrl);
          }
        } else {
          if (mounted) {
            ref.read(audioIsLoadingProvider(widget.audioUrl).notifier).state = false;
          }
        }
      }
    });
  }

  Future<bool> _initializeAudioSource() async {
    try {
      await _audioPlayer.stop();
      ref.read(audioIsPlayingProvider(widget.audioUrl).notifier).state = false;
      await _audioPlayer.setSource(_getSource(widget.audioUrl));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _togglePlayPause() async {
    final isPlaying = ref.read(audioIsPlayingProvider(widget.audioUrl));
    if (isPlaying) {
      await _pause();
    } else {
      await _play();
    }
  }

  Future<void> _play() async {
    try {
      await _audioPlayer.play(_getSource(widget.audioUrl));
      ref.read(audioIsPlayingProvider(widget.audioUrl).notifier).state = true;
    } catch (e) {}
  }

  Future<void> _pause() async {
    await _audioPlayer.pause();
    ref.read(audioIsPlayingProvider(widget.audioUrl).notifier).state = false;
  }

  Future<void> _stop() async {
    await _audioPlayer.stop();
    ref.read(audioIsPlayingProvider(widget.audioUrl).notifier).state = false;
  }

  ap.Source _getSource(String url) {
    return url.startsWith('http') ? ap.UrlSource(url) : ap.DeviceFileSource(url);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _playerCompleteSub.cancel();
    _positionChangedSub.cancel();
    _durationChangedSub.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPlaying = ref.watch(audioIsPlayingProvider(widget.audioUrl));
    final isLoading = ref.watch(audioIsLoadingProvider(widget.audioUrl));
    final position = ref.watch(audioPositionProvider(widget.audioUrl));
    final duration = ref.watch(audioDurationProvider(widget.audioUrl)) ?? Duration.zero;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPlayButton(isPlaying, isLoading),
              const SizedBox(width: 8),
              _buildProgressBar(position, duration),
              const SizedBox(width: 8),
              _buildDurationText(position, duration),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton(bool isPlaying, bool isLoading) {
    return GestureDetector(
      onTap: isLoading ? null : _togglePlayPause,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kDeepPink,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: Icon(
                    Icons.access_time,
                    color: Colors.white,
                    size: 24,
                  ))
              : Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 24,
                ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(Duration position, Duration duration) {
    final max = duration.inMilliseconds.toDouble();
    final value = position.inMilliseconds.clamp(0, max).toDouble();

    return Expanded(
      child: SliderTheme(
        data: SliderTheme.of(context)
            .copyWith(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), overlayShape: const RoundSliderOverlayShape(overlayRadius: 12), thumbColor: kDeepPink),
        child: Slider(
          min: 0,
          max: max > 0 ? max : 1,
          value: value,
          activeColor: kDeepPink,
          inactiveColor: Colors.grey.shade300,
          onChanged: (newValue) {
            // Seek the audio to the new position while dragging
            _audioPlayer.seek(Duration(milliseconds: newValue.round()));
            ref.read(audioPositionProvider(widget.audioUrl).notifier).state = Duration(milliseconds: newValue.round());
          },
        ),
      ),
    );
  }

  Widget _buildDurationText(Duration position, Duration duration) {
    return Text(
      '${_formatDuration(position)} / ${_formatDuration(duration)}',
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey.shade700,
      ),
    );
  }
}

bool isSameDay(DateTime date1, DateTime date2) {
  return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
}

String getDateHeader(DateTime utcDateTime) {
  final utcTime = utcDateTime.isUtc
      ? utcDateTime
      : DateTime.utc(
          utcDateTime.year,
          utcDateTime.month,
          utcDateTime.day,
          utcDateTime.hour,
          utcDateTime.minute,
          utcDateTime.second,
          utcDateTime.millisecond,
          utcDateTime.microsecond,
        );
  DateTime now = DateTime.now();
  final nowUtc = DateTime.utc(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute,
    now.second,
    now.millisecond,
    now.microsecond,
  );

  if (isSameDay(utcTime, nowUtc)) {
    return "Today";
  } else if (isSameDay(utcTime, nowUtc.subtract(Duration(days: 1)))) {
    return "Yesterday";
  } else if (nowUtc.difference(utcTime).inDays < 7) {
    return DateFormat('EEEE').format(utcTime.toLocal()); // Day name
  } else {
    return DateFormat('MMM d, yyyy').format(utcTime.toLocal()); // Full date
  }
}

class DateHeader extends StatelessWidget {
  final String dateText;

  const DateHeader({
    Key? key,
    required this.dateText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: kDeepPink.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              color: kDeepPink.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: kDeepPink.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            dateText,
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w500,
              color: kDeepPink,
            ),
          ),
        ),
      ),
    );
  }
}

class UserStatusIndicator extends ConsumerWidget {
  final String userId;

  const UserStatusIndicator({required this.userId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineStatusAsync = ref.watch(userOnlineStatusProvider(userId));

    ref.listen<AsyncValue<bool>>(
      userOnlineStatusProvider(userId),
      (previous, next) {
        final wasOnline = previous?.maybeWhen(data: (data) => data, orElse: () => null);
        final isOnline = next.maybeWhen(data: (data) => data, orElse: () => null);
        if (wasOnline == true && isOnline == false) {
          ref.invalidate(userLastActiveProvider(userId));
        }
      },
    );
    return onlineStatusAsync.when(
      data: (isOnline) {
        if (isOnline) {
          return Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                ),
              ),
              SizedBox(width: 4),
              Text(
                'Online',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  color: Colors.black.withOpacity(0.9),
                ),
              ),
            ],
          );
        } else {
          final lastActiveAsync = ref.watch(userLastActiveProvider(userId));
          return lastActiveAsync.when(
            data: (lastActive) {
              return Text(
                lastActive != null ? 'Last seen ${timeAgo(lastActive)}' : 'Offline',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  color: Colors.black.withOpacity(0.9),
                ),
              );
            },
            loading: () => Text(
              'Offline',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                color: Colors.black.withOpacity(0.9),
              ),
            ),
            error: (_, __) => Text(
              'Offline',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                color: Colors.black.withOpacity(0.9),
              ),
            ),
          );
        }
      },
      loading: () => Text(
        '...',
        style: GoogleFonts.ibmPlexSans(
          fontSize: 12,
          color: Colors.black.withOpacity(0.9),
        ),
      ),
      error: (_, __) => Text(
        'Offline',
        style: GoogleFonts.ibmPlexSans(
          fontSize: 12,
          color: Colors.black.withOpacity(0.9),
        ),
      ),
    );
  }
}

Widget _buildTypingIndicator(List<String> typingUsers) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        const Icon(Icons.keyboard, size: 16, color: Colors.grey),
        const SizedBox(width: 5),
        Text(
          typingUsers.length == 1 ? "${typingUsers.first} is typing..." : "Multiple people are typing...",
          style: GoogleFonts.ibmPlexSans(color: Colors.grey, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

class ChatPageData {
  final ChatDetails metadata;
  final List<MessageClass> messages;
  final List<ConversationParticipants> participants;

  ChatPageData({
    required this.metadata,
    required this.messages,
    required this.participants,
  });
}

class VideoThumbnailWidget extends StatefulWidget {
  final String videoUrl;

  const VideoThumbnailWidget({Key? key, required this.videoUrl}) : super(key: key);

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  Uint8List? _thumbnailBytes;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  @override
  void didUpdateWidget(VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _generateThumbnail();
    }
  }

  Future<void> _generateThumbnail() async {
    if (widget.videoUrl.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Check if we already have this thumbnail cached
      final cacheKey = 'video_thumbnail_${widget.videoUrl.hashCode}';
      final cacheDir = await getTemporaryDirectory();
      final cacheFile = File('${cacheDir.path}/$cacheKey.jpg');

      if (await cacheFile.exists()) {
        // Use cached thumbnail
        final bytes = await cacheFile.readAsBytes();
        if (mounted) {
          setState(() {
            _thumbnailBytes = bytes;
            _isLoading = false;
          });
        }
        return;
      }

      // Generate thumbnail
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: widget.videoUrl,
        thumbnailPath: cacheFile.path,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
        timeMs: 1000, // Get thumbnail from 1 second into the video
      );

      if (thumbnailPath != null) {
        final bytes = await File(thumbnailPath).readAsBytes();
        if (mounted) {
          setState(() {
            _thumbnailBytes = bytes;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.black26,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
          ),
        ),
      );
    }

    if (_hasError || _thumbnailBytes == null) {
      return Container(
        color: Colors.grey[800],
        child: Center(
          child: Icon(Icons.video_library, color: Colors.white70, size: 40),
        ),
      );
    }

    return Image.memory(
      _thumbnailBytes!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[800],
          child: Center(
            child: Icon(Icons.broken_image, color: Colors.white70, size: 40),
          ),
        );
      },
    );
  }
}

class PlanDetails {
  final Map<String, dynamic> itinerary;
  final List<dynamic> businesses;
  final int totalDays;
  PlanDetails({required this.itinerary, required this.businesses, required this.totalDays});
}

final planDetailsProvider = FutureProvider.family<PlanDetails, String>((ref, tripId) async {
  // Fetch all days for this trip
  final itineraryDataList = await supabase.from('itineraries').select().eq('trip_id', tripId);

  if (itineraryDataList.isEmpty) {
    throw Exception('Plan not found');
  }

  // Get all business IDs
  final Set<int> businessIds = {};
  for (final dayData in itineraryDataList) {
    businessIds.addAll(List<int>.from(dayData['business_ids'] ?? []));
  }

  // Fetch businesses
  List<dynamic> businesses = [];
  if (businessIds.isNotEmpty) {
    businesses = await supabase.from('businesses').select('id, name, photos').inFilter('id', businessIds.toList());
  }

  return PlanDetails(
    itinerary: itineraryDataList.first,
    businesses: businesses,
    totalDays: itineraryDataList.length,
  );
});
