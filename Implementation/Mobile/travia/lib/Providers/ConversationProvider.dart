import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Helpers/ConversationDetail.dart';
import '../main.dart';

// Fetch participant for direct messages
final conversationDetailsProvider = StreamProvider<List<ConversationDetail>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  final currentUserId = user.uid;

  return supabase
      .from('conversations')
      .stream(primaryKey: ['conversation_id'])
      .order('COALESCE(last_message_at, created_at)', ascending: false)
      .order('created_at', ascending: false)
      .asyncMap((_) async {
        final response = await supabase.rpc('get_conversation_details', params: {'p_user_id': currentUserId});
        //print('RPC Response: $response');
        return (response as List).map((json) => ConversationDetail.fromMap(json as Map<String, dynamic>)).toList();
      });
});
