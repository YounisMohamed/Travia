import '../Classes/Comment.dart';
import '../Classes/Post.dart';
import '../main.dart';

Future<void> insertUser({
  required String userId,
  required String email,
  required String username,
  required String displayName,
  String? photoUrl,
  String? bio,
  bool isPrivate = false,
  String gender = 'Male',
  relationshipStatus = 'Single',
  int age = 25,
}) async {
  try {
    await supabase.from('users').upsert({
      'id': userId,
      'email': email,
      'username': username.toLowerCase(),
      'display_name': displayName,
      'age': age,
      'gender': gender,
      'photo_url': photoUrl,
      'relationship_status': relationshipStatus,
      'last_active': DateTime.now().toUtc().toIso8601String(),
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

Future<List<Comment>> fetchComments(String postId) async {
  try {
    final response = await supabase.from('comments').select("*").eq('post_id', postId).order('created_at', ascending: false);

    return (response as List<dynamic>).map((comment) => Comment.fromMap(comment as Map<String, dynamic>)).toList();
  } catch (e) {
    print('Error fetching comments: ${e.toString()}');
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
    print("Hour: ${DateTime.now().toUtc().hour}");

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
    print("Hour: ${DateTime.now().toUtc().hour}");

    print('Notification sent successfully');
  } catch (e) {
    print('Error sending notification: $e');
    rethrow;
  }
}
