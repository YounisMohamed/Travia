import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swipe_to/swipe_to.dart';
import 'package:travia/Classes/ConversationParticipants.dart';
import 'package:travia/Helpers/DummyCards.dart';
import 'package:travia/Helpers/PopUp.dart';
import 'package:uuid/uuid.dart';

import '../Classes/ChatDetails.dart';
import '../Classes/Messages.dart';
import '../Helpers/HelperMethods.dart';
import '../Providers/ChatDetailsProvider.dart';
import '../Services/UserPresenceService.dart';
import '../database/DatabaseMethods.dart';
import '../main.dart';

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

  @override
  void initState() {
    super.initState();
    supabase
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: widget.conversationId,
          ),
          callback: (payload) {
            print('messages channel: Change received');
            print('messages channel: Event type: ${payload.eventType}');
            print('messages channel: Errors: ${payload.errors}');
            print('messages channel: Table: ${payload.table}');
            print('messages channel: toString(): ${payload.toString()}');
          },
        )
        .subscribe();
    Future.microtask(() => markMessagesAsRead(widget.conversationId));
  }

  @override
  void dispose() {
    supabase.channel('public:messages').unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId == '') context.go("/signin");

    final pendingMessages = ref.watch(pendingMessagesProvider);

    // Setup listener for cleanup
    _setupMessageListener(currentUserId, pendingMessages);
    _setupPendingMessagesCleanup(ref);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: ChatAppBar(conversationId: widget.conversationId),
      body: ChatBodyContainer(
        conversationId: widget.conversationId,
        scrollController: _scrollController,
        currentUserId: currentUserId,
        pendingMessages: pendingMessages,
        messageController: _messageController,
        onSendMessage: sendMessage,
      ),
    );
  }

  void _setupMessageListener(String currentUserId, Map<String, Message> pendingMessages) {
    ref.listen(messagesProvider(widget.conversationId), (previous, next) {
      next.whenData((messages) {
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
      });
    });
  }

  void _setupPendingMessagesCleanup(WidgetRef ref) {
    ref.listen(messagesProvider(widget.conversationId), (previous, next) {
      next.whenData((messages) {
        final pendingMessages = ref.read(pendingMessagesProvider);
        final updatedPendingMessages = Map<String, Message>.from(pendingMessages);

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
  }

  Future<void> sendMessage(String content) async {
    if (content.isEmpty) return;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) return;

    final replyMessage = ref.read(replyMessageProvider);

    final messageId = Uuid().v4();

    final placeholder = Message(
      messageId: messageId,
      conversationId: widget.conversationId,
      senderId: currentUserId,
      content: content,
      contentType: 'text',
      sentAt: DateTime.now().toUtc(),
      readBy: {currentUserId: DateTime.now().toUtc().toIso8601String()},
      isEdited: false,
      replyToMessageId: replyMessage?.messageId,
      reactions: null,
      isConfirmed: false,
      isDeleted: false,
    );

    ref.read(pendingMessagesProvider.notifier).update((state) => {
          ...state,
          messageId: placeholder,
        });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: Duration(milliseconds: 100), curve: Curves.easeOut);
      }
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
            'content_type': 'text',
            'reply_to_message_id': replyMessage?.messageId,
          })
          .select('message_id')
          .single();

      // Update to confirmed instead of removing
      ref.read(pendingMessagesProvider.notifier).update((state) {
        final newState = Map<String, Message>.from(state);
        newState[messageId] = placeholder.copyWith(isConfirmed: true);
        return newState;
      });
    } catch (e) {
      print('Error sending message: $e');
      ref.read(pendingMessagesProvider.notifier).update((state) {
        final newState = Map<String, Message>.from(state);
        newState[messageId] = placeholder.copyWith(content: '${placeholder.content} (Failed)');
        return newState;
      });
    }
  }
}

class ChatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String conversationId;
  final Size preferredSize;

  const ChatAppBar({Key? key, required this.conversationId})
      : preferredSize = const Size.fromHeight(kToolbarHeight),
        super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadataAsync = ref.watch(chatMetadataProvider(conversationId));
    final selectedMessages = ref.watch(messageActionsProvider);

    if (selectedMessages.isNotEmpty) {
      return _buildActionModeAppBar(context, ref, selectedMessages);
    }

    // Otherwise show the normal app bar
    return AppBar(
      forceMaterialTransparency: true,
      backgroundColor: Color(0xFFFF8C00),
      elevation: 0,
      title: metadataAsync.when(
        data: (metadata) => _buildAppBarTitle(context, metadata),
        loading: () => _buildLoadingAppBar(),
        error: (error, stackTrace) {
          dev.log(error.toString());
          dev.log(stackTrace.toString());
          /*
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go("/error-page/${Uri.encodeComponent(error.toString())}");
            }
          });

           */
          return Text('Error');
        },
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.more_vert, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildActionModeAppBar(BuildContext context, WidgetRef ref, Set<Message> selectedMessages) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final canDelete = selectedMessages.every((m) => m.senderId == currentUserId);
    final canEdit = selectedMessages.length == 1 && selectedMessages.first.senderId == currentUserId;
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
        if (canDelete)
          IconButton(
            icon: Icon(Icons.delete, color: Colors.white),
            onPressed: () {
              _showDeleteConfirmation(context, ref, selectedMessages.where((m) => m.senderId == currentUserId).toSet());
            },
          ),
      ],
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Set<Message> messagesToDelete) {
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
        actionsAlignment: MainAxisAlignment.spaceBetween,
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
              'DELETE',
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

  Widget _buildLoadingAppBar() {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: AssetImage('assets/placeholder_image.png'),
        ),
        SizedBox(width: 10),
        Text(
          'Loading...',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
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

class ChatBodyContainer extends StatelessWidget {
  final String conversationId;
  final ScrollController scrollController;
  final String currentUserId;
  final Map<String, Message> pendingMessages;
  final TextEditingController messageController;
  final Function(String) onSendMessage;

  const ChatBodyContainer({
    Key? key,
    required this.conversationId,
    required this.scrollController,
    required this.currentUserId,
    required this.pendingMessages,
    required this.messageController,
    required this.onSendMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var keyBoardSize = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFEFD5), Colors.white],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: MessagesList(
              conversationId: conversationId,
              scrollController: scrollController,
              currentUserId: currentUserId,
              pendingMessages: pendingMessages,
            ),
          ),
          MessageInputBar(
            messageController: messageController,
            onSendMessage: onSendMessage,
            keyboardSize: keyBoardSize,
          ),
        ],
      ),
    );
  }
}

class MessagesList extends ConsumerWidget {
  final String conversationId;
  final ScrollController scrollController;
  final String currentUserId;
  final Map<String, Message> pendingMessages;

  const MessagesList({
    Key? key,
    required this.conversationId,
    required this.scrollController,
    required this.currentUserId,
    required this.pendingMessages,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(messagesProvider(conversationId));
    final participantsAsync = ref.watch(conversationParticipantsProvider(conversationId));

    return messagesAsync.when(
      data: (messages) => participantsAsync.when(
        data: (participants) => _buildMessageList(messages, participants),
        loading: () => _buildLoadingState(),
        error: (error, stackTrace) {
          dev.log("Participants error: $error");
          dev.log(stackTrace.toString());
          return const Center(child: Text("Error loading participants."));
        },
      ),
      loading: () => _buildLoadingState(),
      error: (error, stackTrace) {
        dev.log("Messages error: $error");
        dev.log(stackTrace.toString());
        return const Center(child: Text("An error occurred."));
      },
    );
  }

  Widget _buildMessageList(List<Message> messages, List<ConversationParticipants> participants) {
    final Map<String, Message> messagesMap = {};

    // Add server messages
    for (final message in messages) {
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
              replyToMessageContent: messagesMap[message.replyToMessageId]?.content,
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

  Widget _buildLoadingState() {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) => Skeletonizer(child: DummyMessageBubble()),
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
  final Function(String) onSendMessage;
  final double keyboardSize;

  const MessageInputBar({
    Key? key,
    required this.messageController,
    required this.onSendMessage,
    this.keyboardSize = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editingMessage = ref.watch(messageEditProvider);

    // Pre-fill the text field if in editing mode
    if (editingMessage != null && messageController.text.isEmpty) {
      messageController.text = editingMessage.content;
    }

    void cancelReply() {
      ref.read(replyMessageProvider.notifier).state = null;
    }

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
        onSendMessage(text);
      }

      messageController.clear();
      cancelReply();
    }

    void cancelEditing() {
      ref.read(messageEditProvider.notifier).stopEditing();
      messageController.clear();
    }

    final replyMessage = ref.watch(replyMessageProvider);

    return AnimatedContainer(
      duration: Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardSize > 0 ? keyboardSize * 0.01 : 0),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        color: Colors.white,
        child: Column(
          children: [
            if (replyMessage != null)
              Container(
                padding: EdgeInsets.all(8),
                margin: EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to: ${replyMessage.content.length > 50 ? replyMessage.content.substring(0, 50) : replyMessage.content}',
                        style: TextStyle(color: Colors.black87, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red),
                      onPressed: cancelReply,
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                if (editingMessage != null)
                  IconButton(
                    icon: Icon(Icons.cancel, color: Colors.red),
                    onPressed: cancelEditing,
                  ),
                IconButton(
                  icon: Icon(Icons.add, color: Color(0xFFFF8C00)),
                  onPressed: () {},
                ),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: 150,
                          ),
                          child: TextField(
                            controller: messageController,
                            maxLines: null,
                            minLines: 1,
                            decoration: InputDecoration(
                              hintText: editingMessage != null ? "Edit message..." : "Type a message...",
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Color(0xFFFF8C00)),
                  onPressed: () => handleSendOrUpdate(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MessageBubble extends ConsumerWidget {
  final Message message;
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

    String content = "";
    if (message.isDeleted) {
      content = "DELETED MESSAGE";
    } else {
      content = "${message.content}${message.isEdited ? ' (edited)' : ''}";
    }

    return SwipeTo(
      key: UniqueKey(),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isCurrentUser) ...[
              CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(
                  message.senderProfilePic ?? "https://ui-avatars.com/api/?name=${message.senderUsername}&rounded=true&background=random",
                ),
              ),
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
                    if (message.replyToMessageContent != null)
                      Container(
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
                      ),
                    Text(
                      content,
                      style: TextStyle(
                        color: isCurrentUser ? Colors.white : Colors.black87,
                        fontSize: 15,
                        fontStyle: (message.isEdited || message.isDeleted) ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    SizedBox(height: 2),
                    Row(
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
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
        'Loading status...',
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
