import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:record/record.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:swipe_to/swipe_to.dart';
import 'package:travia/Classes/ConversationParticipants.dart';
import 'package:travia/Helpers/DummyCards.dart';
import 'package:travia/Helpers/Loading.dart';
import 'package:travia/Helpers/PopUp.dart';
import 'package:uuid/uuid.dart';

import '../Classes/ChatDetails.dart';
import '../Classes/message_class.dart';
import '../Helpers/Constants.dart';
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

  @override
  void initState() {
    super.initState();

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
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  Future<void> sendMessage({
    required content,
    required contentType,
    required List<String> target_user_ids,
  }) async {
    if (content.isEmpty) return;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) return;

    final replyMessage = ref.read(replyMessageProvider);
    final messageId = Uuid().v4();

    final placeholder = MessageClass(
      messageId: messageId,
      conversationId: widget.conversationId,
      senderId: currentUserId,
      content: content,
      contentType: contentType,
      sentAt: DateTime.now().toUtc(),
      readBy: {currentUserId: DateTime.now().toUtc().toIso8601String()},
      isEdited: false,
      replyToMessageId: replyMessage?.messageId,
      reactions: null,
      isConfirmed: false,
      isDeleted: false,
      deletedForMeId: [],
    );

    ref.read(pendingMessagesProvider.notifier).update((state) => {
          ...state,
          messageId: placeholder,
        });

    _messageController.clear();

    try {
      await supabase
          .from('messages')
          .insert({
            'message_id': messageId,
            'conversation_id': widget.conversationId,
            'sender_id': currentUserId,
            'content': content,
            'content_type': contentType,
            'reply_to_message_id': replyMessage?.messageId,
          })
          .select('message_id')
          .single();

      ref.read(pendingMessagesProvider.notifier).update((state) {
        final newState = Map<String, MessageClass>.from(state);
        newState[messageId] = placeholder.copyWith(isConfirmed: true);
        return newState;
      });
      for (String target_user_id in target_user_ids) {
        if (target_user_id == currentUserId) continue;
        await sendNotification(
            type: 'message',
            title: "sent you a message",
            content: contentType == "text"
                ? content
                : contentType == 'record'
                    ? "New Record 🎙️"
                    : "New Media 📷",
            target_user_id: target_user_id,
            source_id: widget.conversationId,
            sender_user_id: FirebaseAuth.instance.currentUser!.uid);
      }
    } catch (e) {
      print('Error sending message: $e');
      ref.read(pendingMessagesProvider.notifier).update((state) {
        final newState = Map<String, MessageClass>.from(state);
        newState[messageId] = placeholder.copyWith(content: '${placeholder.content} (Failed)');
        return newState;
      });
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
      decoration: backGroundColor(),
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
  final Size preferredSize;

  const ChatAppBar({Key? key, required this.conversationId, required this.metadata})
      : preferredSize = const Size.fromHeight(kToolbarHeight),
        super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMessages = ref.watch(messageActionsProvider);

    if (selectedMessages.isNotEmpty) {
      return _buildActionModeAppBar(context, ref, selectedMessages);
    }

    return AppBar(
      forceMaterialTransparency: true,
      backgroundColor: Color(0xFFFF8C00),
      elevation: 0,
      title: _buildAppBarTitle(context, metadata),
    );
  }

  Widget _buildActionModeAppBar(BuildContext context, WidgetRef ref, Set<MessageClass> selectedMessages) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final canDelete = selectedMessages.every((m) => m.senderId == currentUserId) && selectedMessages.every((m) => m.contentType == 'text');
    final canEdit = selectedMessages.length == 1 && selectedMessages.first.senderId == currentUserId && selectedMessages.every((m) => m.contentType == 'text');
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
        IconButton(
          icon: Icon(Icons.copy, color: Colors.white),
          onPressed: () {
            final content = selectedMessages.map((m) => m.content).join('\n');
            Clipboard.setData(ClipboardData(text: content));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Messages copied to clipboard')),
            );
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
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        elevation: 8,
        title: Text(
          'Delete Messages',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              messagesToDelete.length == 1 ? "Are you sure you want to delete this message?" : 'Are you sure you want to delete all ${messagesToDelete.length} messages?',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.redAccent.withOpacity(0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.start,
        actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              'CANCEL',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (canDelete)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                ref.read(messageActionsProvider.notifier).clearSelectedMessages();
                try {
                  for (final message in messagesToDelete) {
                    await removeMessage(messageId: message.messageId);
                  }
                } catch (e) {
                  Popup.showPopUp(text: "Failed to delete messages", context: context, color: Colors.redAccent);
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent, // Prominent delete color
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                'DELETE FOR ALL',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              ref.read(messageActionsProvider.notifier).clearSelectedMessages();
              try {
                final currentUserId = FirebaseAuth.instance.currentUser!.uid;
                for (final message in messagesToDelete) {
                  print(message.content);
                  print(currentUserId);
                  await removeMessageForMe(messageId: message.messageId, currentUserId: currentUserId);
                }
              } catch (e) {
                Popup.showPopUp(text: "Failed to delete messages", context: context, color: Colors.redAccent);
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent, // Prominent delete color
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(
              'DELETE FOR ME',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarTitle(BuildContext context, ChatDetails metadata) {
    return Row(
      children: [
        ChatAvatar(metadata: metadata),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metadata.conversationType == 'direct' ? (metadata.receiverUsername ?? 'Direct Message') : (metadata.title ?? 'Group Conversation'),
                style: TextStyle(
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
    );
  }

  Widget _buildSubtitle(ChatDetails metadata) {
    if (metadata.conversationType == 'direct' && metadata.receiverId != null) {
      return UserStatusIndicator(userId: metadata.receiverId!);
    } else {
      return Text(
        '${metadata.numberOfParticipants} participants',
        style: TextStyle(
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
              : "https://ui-avatars.com/api/?name=${(metadata.title ?? 'GC').substring(0, min(2, (metadata.title ?? 'GC').length))}&rounded=true&background=random",
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
          error: (e, st) => const SizedBox.shrink(),
        ),
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
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'Start the conversation!',
            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            'Send a message to begin chatting.',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class MessageInputBar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final editingMessage = ref.watch(messageEditProvider);
    final textDirection = ref.watch(textDirectionProvider);
    final isUploading = ref.watch(chatMediaUploadProvider);

    final isRecording = ref.watch(recordingStateProvider);

    if (editingMessage != null && messageController.text.isEmpty) {
      messageController.text = editingMessage.content;
    }
    void cancelReply() {
      ref.read(replyMessageProvider.notifier).state = null;
    }

    ref.listen<bool>(isTypingProvider, (previous, next) async {
      if (previous != next) {
        print(next);
        await updateIsTyping(
          currentUserId: currentUserId,
          conversationId: conversationId,
          isTyping: next,
        );
      }
    });
    void handleSendOrUpdate() async {
      final text = messageController.text.trim();
      if (text.isEmpty) return;
      if (editingMessage != null) {
        try {
          await updateMessage(content: text, messageId: editingMessage.messageId);
          ref.read(messageEditProvider.notifier).updateContent(text);
          ref.read(messageEditProvider.notifier).stopEditing();
        } catch (e) {
          print("Failed to update message: $e");
        }
      } else {
        onSendMessage(
          content: messageController.text.trim(),
          contentType: "text",
          target_user_ids: participants.where((p) => p.userId != currentUserId).map((p) => p.userId).toList(),
        );
        ref.read(isTypingProvider.notifier).stopTyping();
      }
      messageController.clear();
      cancelReply();
    }

    void cancelEditing() {
      ref.read(messageEditProvider.notifier).stopEditing();
      messageController.clear();
    }

    final replyMessage = ref.watch(replyMessageProvider);
    return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: isRecording
            ? RecordingInterface(onStop: (path) async {
                String? url = await uploadRecordToDatabase(localPath: path, userId: currentUserId);
                if (url != null) {
                  await onSendMessage(
                    content: url,
                    contentType: "record",
                    target_user_ids: participants.where((p) => p.userId != currentUserId).map((p) => p.userId).toList(),
                  );
                }
              })
            : AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: keyboardSize > 0 ? keyboardSize * 0.01 : 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  color: Colors.white,
                  child: Column(
                    children: [
                      if (replyMessage != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  replyMessage.contentType == 'text'
                                      ? 'Replying to: ${replyMessage.content.length > 50 ? replyMessage.content.substring(0, 50) : replyMessage.content}'
                                      : replyMessage.contentType == 'record'
                                          ? 'Replying to record'
                                          : 'Replying to media',
                                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: cancelReply,
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
                                  icon: const Icon(Icons.add, color: Color(0xFFFF8C00)),
                                  onPressed: () async {
                                    ref.read(imagePickerProvider.notifier).clearImage();

                                    final pickedFile = ref.watch(imagePickerProvider);

                                    if (pickedFile == null) {
                                      await ref.read(imagePickerProvider.notifier).pickAndEditMediaForChat(context);
                                    }

                                    final mediaFile = ref.watch(imagePickerProvider);
                                    if (mediaFile == null) return;

                                    final mediaUrl = await ref.read(chatMediaUploadProvider.notifier).uploadChatMedia(userId: currentUserId, mediaFile: mediaFile);
                                    if (mediaUrl == null) return;

                                    final isVideo = mediaFile.path.endsWith('.mp4') || mediaFile.path.endsWith('.mov');
                                    try {
                                      await onSendMessage(
                                        content: mediaUrl,
                                        contentType: isVideo ? 'video' : 'image',
                                        target_user_ids: participants.where((p) => p.userId != currentUserId).map((p) => p.userId).toList(),
                                      );
                                    } catch (e) {
                                      print(e);
                                      Popup.showPopUp(text: "Failed sending image", context: context, color: Colors.redAccent);
                                    }
                                    ref.read(imagePickerProvider.notifier).clearImage();
                                  },
                                ),
                          SimpleRecorderButton(
                            onStop: (path) async {
                              debugPrint('Audio saved at: $path');
                              String? url = await uploadRecordToDatabase(localPath: path, userId: currentUserId);
                              if (url != null) {
                                print("Record saved at $url");
                                onSendMessage(
                                  content: url,
                                  contentType: "record",
                                  target_user_ids: participants.where((p) => p.userId != currentUserId).map((p) => p.userId).toList(),
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
                                  controller: messageController,
                                  maxLines: null,
                                  minLines: 1,
                                  textDirection: textDirection,
                                  onChanged: (text) {
                                    updateTextDirection(ref, text);
                                    ref.read(isTypingProvider.notifier).startTyping();
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
                            icon: const Icon(Icons.send, color: Color(0xFFFF8C00)),
                            onPressed: () => handleSendOrUpdate(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ));
  }
}

class RecordingInterface extends ConsumerStatefulWidget {
  final void Function(String path) onStop;

  const RecordingInterface({Key? key, required this.onStop}) : super(key: key);

  @override
  _RecordingInterfaceState createState() => _RecordingInterfaceState();
}

class _RecordingInterfaceState extends ConsumerState<RecordingInterface> with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  late Timer _timer;
  int _seconds = 0;
  String? _recordPath;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _startRecording();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      lowerBound: 0.9,
      upperBound: 1.2,
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
    });
  }

  Future<void> _startRecording() async {
    if (await _recorder.hasPermission()) {
      final path = '${Directory.systemTemp.path}/rec_${const Uuid().v4()}.mp3';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      setState(() => _recordPath = path);
    }
  }

  Future<void> _stopRecording() async {
    _timer.cancel();
    _pulseController.stop();
    await _recorder.stop();
    ref.read(recordingStateProvider.notifier).stopRecording();
    if (_recordPath != null) widget.onStop(_recordPath!);
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseController,
            child: const Icon(Icons.mic, color: Colors.red, size: 40),
          ),
          const SizedBox(width: 16),
          Text(
            _formatDuration(_seconds),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.stop_circle, color: Colors.redAccent, size: 36),
            onPressed: _stopRecording,
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

    // Determine content type and build appropriate bubble
    if (message.contentType == 'text' || message.isDeleted) {
      return _buildSwipeWrapper(context, ref, _buildTextBubble(context, ref, isRead, isSelected, hasSelection));
    } else if (message.contentType == 'record' && !message.isDeleted) {
      return _buildSwipeWrapper(context, ref, _buildAudioBubble(context, ref, isRead, isSelected, hasSelection));
    } else {
      // Media messages
      return _buildSwipeWrapper(context, ref, _buildMediaBubble(context, ref, isSelected, hasSelection));
    }
  }

  // Common swipe wrapper for all message types
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

  // Common avatar widget for both sender and receiver
  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 16,
      backgroundImage: NetworkImage(
        message.senderProfilePic ?? "https://ui-avatars.com/api/?name=${message.senderUsername}&rounded=true&background=random",
      ),
    );
  }

  // Common timestamp and read indicator
  Widget _buildTimestampAndReadStatus(bool isRead) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          isPending ? "Sending..." : formatMessageTime(message.sentAt),
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

  // Common reply widget
  Widget _buildReplyPreview() {
    if (message.replyToMessageSender == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(8),
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.orange.shade400 : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.replyToMessageSender ?? 'Unknown',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isCurrentUser ? Colors.white.withOpacity(0.8) : Colors.black87,
            ),
          ),
          SizedBox(height: 4),
          Text(
            message.replyToMessageContent!.length > 50 ? '${message.replyToMessageContent!.substring(0, 50)}...' : message.replyToMessageContent!,
            style: TextStyle(
              fontSize: 13,
              color: isCurrentUser ? Colors.white.withOpacity(0.9) : Colors.black54,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // Build a text message bubble
  Widget _buildTextBubble(BuildContext context, WidgetRef ref, bool isRead, bool isSelected, bool hasSelection) {
    String content = "${message.content}${message.isEdited ? ' (edited)' : ''}";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            _buildAvatar(),
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
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.grey.withOpacity(0.5)
                    : isCurrentUser
                        ? (isPending ? Color(0xFFFF8C00).withOpacity(0.7) : Color(0xFFFF8C00))
                        : Colors.white,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: isCurrentUser ? Radius.circular(20) : Radius.circular(0),
                  bottomRight: isCurrentUser ? Radius.circular(0) : Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
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
                          color: Color(0xFFFF8C00),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  _buildReplyPreview(),
                  message.contentType == 'text' || message.content.toLowerCase() == "deleted"
                      ? Text(
                          content,
                          textDirection: isMostlyRtl(content),
                          style: TextStyle(
                            color: message.isDeleted ? Colors.black54 : (isCurrentUser ? Colors.white : Colors.black87),
                            fontSize: 15,
                            fontStyle: (message.isEdited || message.isDeleted) ? FontStyle.italic : FontStyle.normal,
                          ),
                        )
                      : MediaPreview(
                          mediaUrl: message.content,
                          isVideo: message.content.endsWith('.mp4') || message.content.endsWith('.mov'),
                        ),
                  SizedBox(height: 2),
                  _buildTimestampAndReadStatus(isRead),
                ],
              ),
            ),
          ),
          if (isCurrentUser) ...[
            SizedBox(width: 8),
            _buildAvatar(),
          ],
        ],
      ),
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
            _buildAvatar(),
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
                        color: Color(0xFFFF8C00),
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
            _buildAvatar(),
          ],
        ],
      ),
    );
  }

  // Build a media message bubble
  Widget _buildMediaBubble(BuildContext context, WidgetRef ref, bool isSelected, bool hasSelection) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            _buildAvatar(),
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
                    isVideo: message.content.endsWith('.mp4') || message.content.endsWith('.mov'),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                    child: Text(
                      _getFormattedTime(message.sentAt),
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
            _buildAvatar(),
          ],
        ],
      ),
    );
  }

  String _getFormattedTime(DateTime timestamp) {
    return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
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
      debugPrint('Error initializing audio source: $e');
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
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
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
          color: Theme.of(context).primaryColor,
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
        data: SliderTheme.of(context).copyWith(
          trackHeight: 4,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        ),
        child: Slider(
          min: 0,
          max: max > 0 ? max : 1,
          value: value,
          activeColor: Theme.of(context).primaryColor,
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

String formatMessageTime(DateTime? utcDateTime) {
  if (utcDateTime == null) return 'Delivering...';

  // Force the input to UTC
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

  // Convert to local time for display
  final localTime = utcTime.toLocal();

  return DateFormat('h:mm a').format(localTime);
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
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Text(
            dateText,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12.0,
              fontWeight: FontWeight.w500,
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
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withOpacity(0.9),
                ),
              ),
            ],
          );
        } else {
          final lastActiveAsync = ref.watch(userLastActiveProvider(userId));
          print("LAST: $lastActiveAsync");
          return lastActiveAsync.when(
            data: (lastActive) {
              print("LAST ACTIVE HERE: $lastActive");
              return Text(
                lastActive != null ? 'Last seen ${timeAgo(lastActive)}' : 'Offline',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withOpacity(0.9),
                ),
              );
            },
            loading: () => Text(
              'Offline',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withOpacity(0.9),
              ),
            ),
            error: (_, __) => Text(
              'Offline',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withOpacity(0.9),
              ),
            ),
          );
        }
      },
      loading: () => Text(
        'Loading...',
        style: TextStyle(
          fontSize: 12,
          color: Colors.black.withOpacity(0.9),
        ),
      ),
      error: (_, __) => Text(
        'Offline',
        style: TextStyle(
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
          style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
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
