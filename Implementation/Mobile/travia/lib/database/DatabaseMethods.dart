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
  required String postId,
  required String likerId,
}) async {
  try {
    print("UNLIKING POST..");
    await supabase.from('notifications').delete().match({
      'type': 'like',
      'target_user_id': targetUserId,
      'source_id': postId,
      'sender_user_id': likerId,
    });

    print('Like notification removed successfully');
  } catch (e) {
    print('Error removing like notification: $e');
    rethrow;
  }
}

Future<void> sendNotification({
  required String type,
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
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    print('Notification sent successfully');
  } catch (e) {
    print('Error sending notification: $e');
    rethrow;
  }
}

Future<void> savePostToDatabase(String userId, String imageUrl, String caption, String location) async {
  try {
    await supabase.from('posts').insert({
      'user_id': userId,
      'media_url': imageUrl,
      'caption': caption,
      'location': location,
      'created_at': DateTime.now().toIso8601String(),
    });
  } catch (e) {
    print("Database Error: $e");
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
