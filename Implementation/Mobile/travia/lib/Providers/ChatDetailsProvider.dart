import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Classes/ChatDetails.dart';
import '../Classes/ConversationParticipants.dart';
import '../Classes/message_class.dart';
import '../MainFlow/ChatPage.dart';
import '../main.dart';

final chatMetadataProvider = FutureProvider.family<ChatDetails, String>((ref, conversationId) async {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final response = await supabase.rpc('get_chat_details', params: {
    'p_conversation_id': conversationId,
    'p_current_user_id': currentUserId,
  });
  final data = response as List;
  if (data.isEmpty) throw Exception('Conversation not found');
  return ChatDetails.fromMap(data.first as Map<String, dynamic>);
});

final messagesProvider = StreamProvider.family<List<MessageClass>, String>((ref, conversationId) async* {
  print("Messages stream setup for conversationId: $conversationId");

  // Step 1: Load cached messages first
  final cachedMessages = getMessagesFromCache(conversationId);
  print("Loaded cached messages: ${cachedMessages.map((m) => m.messageId).toList()}");
  if (cachedMessages.isNotEmpty) {
    print("Emitting cached messages immediately");
    yield cachedMessages;
  }
  // Step 2: Fetch live updates from Supabase
  await for (final event in supabase.from('messages').stream(primaryKey: ['message_id']).eq('conversation_id', conversationId)) {
    print("Messages stream event: $event");

    final messages = event.map((json) => MessageClass.fromMap(json)).toList();
    print("Messages updated: ${messages.map((m) => m.messageId).toList()}");

    // Step 3: Save new messages to cache
    for (final message in messages) {
      saveMessageToCache(message);
    }

    // Emit new messages
    yield messages;
  }
});

final conversationParticipantsProvider = StreamProvider.family<List<ConversationParticipants>, String>((ref, conversationId) {
  return supabase
      .from('conversation_participants')
      .stream(primaryKey: ['conversation_id', 'user_id'])
      .eq('conversation_id', conversationId)
      .map((data) => data.map((json) => ConversationParticipants.fromMap(json)).toList());
});

final chatPageCombinedProvider = Provider.family<AsyncValue<ChatPageData>, String>((ref, conversationId) {
  final metadata = ref.watch(chatMetadataProvider(conversationId));
  final messages = ref.watch(messagesProvider(conversationId));
  final participants = ref.watch(conversationParticipantsProvider(conversationId));

  if (metadata is AsyncLoading || messages is AsyncLoading || participants is AsyncLoading) {
    return const AsyncValue.loading();
  }

  if (metadata is AsyncError) return AsyncValue.error(metadata.error!, metadata.stackTrace!);
  if (messages is AsyncError) return AsyncValue.error(messages.error!, messages.stackTrace!);
  if (participants is AsyncError) return AsyncValue.error(participants.error!, participants.stackTrace!);

  return AsyncValue.data(
    ChatPageData(
      metadata: metadata.value!,
      messages: messages.value!,
      participants: participants.value!,
    ),
  );
});

final pendingMessagesProvider = StateProvider<Map<String, MessageClass>>((ref) => {});

final isTypingProvider = StateNotifierProvider<TypingNotifier, bool>((ref) {
  return TypingNotifier();
});

class TypingNotifier extends StateNotifier<bool> {
  Timer? _typingTimer;

  TypingNotifier() : super(false);

  void startTyping() {
    if (!state) state = true;
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      state = false;
    });
  }

  void stopTyping() {
    _typingTimer?.cancel();
    state = false;
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    super.dispose();
  }
}

final otherTypingProvider = StreamProvider.autoDispose.family<List<String>, String>((ref, conversationId) {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  return supabase.from('conversation_participants').stream(primaryKey: ['user_id', 'conversation_id']).eq('conversation_id', conversationId).map((participants) {
        return participants.where((p) => p['user_id'] != currentUserId).where((p) => p['is_typing'] == true).map((p) => p['user_username'] as String).toList();
      });
});

class MessageActionsNotifier extends StateNotifier<Set<MessageClass>> {
  MessageActionsNotifier() : super({});

  void toggleSelectedMessage(MessageClass message) {
    final newState = Set<MessageClass>.from(state);
    if (newState.contains(message)) {
      newState.remove(message);
    } else {
      newState.add(message);
    }
    state = newState;
  }

  void clearSelectedMessages() {
    state = {};
  }
}

final messageActionsProvider = StateNotifierProvider<MessageActionsNotifier, Set<MessageClass>>((ref) {
  return MessageActionsNotifier();
});

final messageEditProvider = StateNotifierProvider<MessageEditNotifier, MessageClass?>((ref) => MessageEditNotifier());

class MessageEditNotifier extends StateNotifier<MessageClass?> {
  MessageEditNotifier() : super(null);

  void startEditing(MessageClass message) => state = message;

  void stopEditing() => state = null;

  void updateContent(String content) {
    if (state != null) {
      state = state!.copyWith(content: content, isEdited: true);
    }
  }
}

final replyMessageProvider = StateProvider<MessageClass?>((ref) => null);

final textDirectionProvider = StateProvider<TextDirection>((ref) => TextDirection.ltr);

void updateTextDirection(WidgetRef ref, String text) {
  final isRtl = RegExp(r'^[\u0600-\u06FF]').hasMatch(text);
  ref.read(textDirectionProvider.notifier).state = isRtl ? TextDirection.rtl : TextDirection.ltr;
}

class RecorderState {
  final bool showPlayer;
  final String? audioPath;

  RecorderState({this.showPlayer = false, this.audioPath});

  RecorderState copyWith({bool? showPlayer, String? audioPath}) {
    return RecorderState(
      showPlayer: showPlayer ?? this.showPlayer,
      audioPath: audioPath ?? this.audioPath,
    );
  }
}

class RecorderNotifier extends Notifier<RecorderState> {
  @override
  RecorderState build() => RecorderState();

  void setAudio(String path) {
    state = state.copyWith(showPlayer: true, audioPath: path);
  }

  void deleteAudio() {
    state = state.copyWith(showPlayer: false, audioPath: null);
  }
}

final recorderProvider = NotifierProvider<RecorderNotifier, RecorderState>(() => RecorderNotifier());

final audioPositionProvider = StateProvider.family<Duration, String>((ref, id) => Duration.zero);

// Total duration of the audio
final audioDurationProvider = StateProvider.family<Duration?, String>((ref, id) => null);

// Playback state
final audioIsPlayingProvider = StateProvider.family<bool, String>((ref, id) => false);

// Loading state
final audioIsLoadingProvider = StateProvider.family<bool, String>((ref, id) => false);

final audioInitializedProvider = StateNotifierProvider<AudioInitializedNotifier, Set<String>>((ref) {
  return AudioInitializedNotifier();
});

class AudioInitializedNotifier extends StateNotifier<Set<String>> {
  AudioInitializedNotifier() : super({});

  bool isInitialized(String url) => state.contains(url);

  void markInitialized(String url) {
    state = {...state, url};
  }
}

class RecordingStateNotifier extends StateNotifier<bool> {
  RecordingStateNotifier() : super(false);

  void startRecording() {
    state = true;
  }

  void stopRecording() {
    state = false;
  }
}

// Define the provider for the recording state
final recordingStateProvider = StateNotifierProvider<RecordingStateNotifier, bool>((ref) {
  return RecordingStateNotifier();
});
