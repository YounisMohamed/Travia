import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart';

final groupLoadingProvider = StateProvider<bool>((ref) => false);
final groupTitleProvider = StateProvider<String?>((ref) => null);
final groupPictureProvider = StateProvider<String?>((ref) => null);
// Create a provider for participants
final participantsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, conversationId) async* {
  try {
    // Create a stream controller that can be cancelled
    final controller = StreamController<List<Map<String, dynamic>>>();

    // Set up the Supabase stream for the conversation participants
    final subscription = supabase
        .from('conversation_participants')
        .stream(primaryKey: ['user_id', 'conversation_id'])
        .eq('conversation_id', conversationId)
        .order('joined_at', ascending: true)
        .map((data) => data)
        .listen(
          (participants) => controller.add(participants),
          onError: (error) {
            print('Supabase participants stream error: $error');
            controller.addError(error);
          },
        );

    // Make sure to close the subscription when the provider is disposed
    ref.onDispose(() {
      subscription.cancel();
      controller.close();
    });

    // Yield participant updates from the controller
    await for (final participants in controller.stream) {
      yield participants;
    }
  } catch (e) {
    print('Participants provider error: $e');
    rethrow;
  }
});
