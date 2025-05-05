/*
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
    ref.listen<Map<String, MessageClass>>(
      pendingMessagesProvider,
          (previous, next) {
        _setupMessageListener(currentUserId, next);
      },
    );
    _setupPendingMessagesCleanup(ref);
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

  void _setupMessageListener(String currentUserId, Map<String, MessageClass> pendingMessages) {
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
  }

  Future<void> sendMessage({
    required content,
    required contentType,
    required String target_user_id,
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
*/
