import 'package:firebase_auth/firebase_auth.dart';

import '../Classes/Post.dart';
import '../main.dart';

Future<void> insertUser({
  required String userId,
  required String email,
  required String username,
  required String displayName,
  String? bio,
  bool isPrivate = false,
  String gender = 'Male',
  relationshipStatus = 'Single',
  int age = 25,
}) async {
  try {
    String photoUrl = "";
    String? googlePhoto = FirebaseAuth.instance.currentUser!.photoURL;
    if (googlePhoto != null) {
      photoUrl = googlePhoto;
    } else {
      photoUrl = "https://ui-avatars.com/api/?name=$username&rounded=true&background=random";
    }

    await supabase.from('users').upsert({
      'id': userId,
      'email': email,
      'username': username.toLowerCase(),
      'display_name': displayName,
      'age': age,
      'gender': gender,
      'photo_url': photoUrl,
      'relationship_status': relationshipStatus,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'saved_posts': <String>[],
    });
    print('User inserted successfully');
  } catch (e) {
    print('Error inserting user: $e');
  }
}

Future<List<Post>> fetchPosts() async {
  try {
    final response = await supabase.from('posts').select("*").order('created_at', ascending: false);

    return (response as List<dynamic>).map((post) => Post.fromMap(post as Map<String, dynamic>)).toList();
  } catch (e) {
    print('Error fetching posts: ${e.toString()}');
    rethrow;
  }
}

Future<void> sendComment({required String postId, required String userId, required String content, String? parentCommentId, required String id}) async {
  try {
    await supabase.from('comments').insert({
      'id': id,
      'post_id': postId,
      'user_id': userId,
      'content': content,
      'parent_comment_id': parentCommentId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    print('Comment added successfully');
  } catch (e) {
    print('Error adding comment: $e');
    rethrow;
  }
}

Future<void> deleteComment({required String commentId}) async {
  try {
    await supabase.from('comments').delete().match({'id': commentId});
    print('Comment deleted successfully');
  } catch (e) {
    print('Error deleting comment: $e');
    rethrow;
  }
}

Future<void> removeLikeNotification({
  required String targetUserId,
  required String sourceId,
  required String senderId,
}) async {
  try {
    print("REMOVING NOTIFICATION..");
    await supabase.from('notifications').delete().match({
      'type': "like",
      'target_user_id': targetUserId,
      'source_id': sourceId,
      'sender_user_id': senderId,
    });

    //print('notification removed successfully');
  } catch (e) {
    print('Error removing notification: $e');
    rethrow;
  }
}

Future<void> sendNotification({
  required String type,
  required String title,
  required String content,
  required String target_user_id,
  required String source_id,
  required String sender_user_id,
}) async {
  try {
    await supabase.from('notifications').insert({
      'type': type,
      'content': content,
      'target_user_id': target_user_id,
      'source_id': source_id,
      'sender_user_id': sender_user_id,
      'title': title,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    //print('Notification sent successfully');
  } catch (e) {
    print('Error sending notification: $e');
    rethrow;
  }
}

Future<void> deletePostFromDatabase(String postId) async {
  print("Starting post deletion for ID: $postId");

  try {
    final post = await supabase.from('posts').select('media_url').eq('id', postId).maybeSingle();
    print("Post data retrieved: $post");

    if (post == null || post['media_url'] == null) {
      print("No media URL found, skipping storage deletion.");
    } else {
      final String mediaUrl = post['media_url'];
      print("Media URL found: $mediaUrl");

      try {
        final Uri uri = Uri.parse(mediaUrl);
        print("Parsed URI: $uri");
        final String filePath = uri.pathSegments.skip(5).join('/');
        print("File path extracted: $filePath");

        final result = await supabase.storage.from('posts').remove([filePath]);
        print(result.toString());
        print("Image deleted from storage: $filePath");
      } catch (e) {
        print("Error deleting image from storage: $e");
        rethrow;
      }
    }

    try {
      await supabase.from('posts').delete().eq('id', postId);
      print("Post deleted from database: $postId");
    } catch (e) {
      print("Error deleting post from database: $e");
      rethrow;
    }

    print("Finished post deletion process for ID: $postId");
  } catch (e) {
    print("Error in deletePostFromDatabase function: $e");
    rethrow;
  }
}

Future<void> deleteStoryFromDatabase(String storyId) async {
  print("Starting post deletion for ID: $storyId");

  try {
    final story = await supabase.from('story_items').select('media_url').eq('item_id', storyId).maybeSingle();
    print("Post data retrieved: $story");

    if (story == null || story['media_url'] == null) {
      print("No media URL found, skipping storage deletion.");
    } else {
      final String mediaUrl = story['media_url'];
      print("Media URL found: $mediaUrl");

      try {
        final Uri uri = Uri.parse(mediaUrl);
        print("Parsed URI: $uri");
        final String filePath = uri.pathSegments.skip(5).join('/');
        print("File path extracted: $filePath");

        final result = await supabase.storage.from('stories').remove([filePath]);
        print(result.toString());
        print("Image deleted from storage: $filePath");
      } catch (e) {
        print("Error deleting image from storage: $e");
        rethrow;
      }
    }

    try {
      await supabase.from('story_items').delete().match({'item_id': storyId});
      print("Story deleted from database: $storyId");
    } catch (e) {
      print("Error deleting story from database: $e");
      rethrow;
    }

    print("Finished post deletion process for ID: $storyId");
  } catch (e) {
    print("Error in deleteStoryFromDatabase function: $e");
    rethrow;
  }
}

Future<void> addViewedPost(String userId, String postId) async {
  try {
    await supabase.rpc(
      'add_viewed_post',
      params: {'user_id': userId, 'post_id': postId},
    );
  } catch (e) {
    print('Error adding viewed post: $e');
  }
}

Future<void> addSavedPost(String userId, String postId) async {
  try {
    await supabase.rpc(
      'add_saved_post',
      params: {'user_id': userId, 'post_id': postId},
    );
  } catch (e) {
    print('Error saving post: $e');
    rethrow;
  }
}

Future<void> markMessagesAsRead(String conversationId) async {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (currentUserId.isEmpty) return;

  try {
    await supabase.rpc('mark_messages_as_read', params: {
      'p_conversation_id': conversationId,
      'p_user_id': currentUserId,
    });
  } catch (e) {
    print('Error marking messages as read: $e');
  }
}

Future<void> removeMessage({required String messageId}) async {
  print("REMOVING MESSAGE..");
  await supabase.from('messages').update({
    'is_deleted': true,
    'content': "DELETED",
  }).eq('message_id', messageId);
}

Future<void> removeMessageForMe({required String messageId, required String currentUserId}) async {
  print("REMOVING MESSAGE..");
  await supabase.rpc('add_deleted_for_me_user', params: {
    'message_id': messageId,
    'user_id': currentUserId,
  });
}

Future<void> updateMessage({required String content, required String messageId}) async {
  await supabase.from('messages').update({
    'content': content,
    'is_edited': true,
  }).eq('message_id', messageId);
}

Future<List<String>> fetchConversationIds(String userId) async {
  final response = await supabase.from('conversation_participants').select('conversation_id').eq('user_id', userId);
  return (response as List).map((row) => row['conversation_id'] as String).toList();
}

Future<void> updateIsTyping({required bool isTyping, required String conversationId, required String currentUserId}) async {
  await supabase.from('conversation_participants').update({'is_typing': isTyping}).eq('conversation_id', conversationId).eq('user_id', currentUserId);
}
