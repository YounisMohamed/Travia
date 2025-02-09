import 'package:supabase_flutter/supabase_flutter.dart';

import '../Classes/Comment.dart';
import '../Classes/Post.dart';

final supabase = Supabase.instance.client;

Future<List<Post>> fetchPosts() async {
  try {
    final response = await supabase.from('posts').select('''
          *,
          users!inner (
            display_name,
            photo_url
          ),
          likes (*),
          comments (*)
        ''').order('created_at', ascending: false);

    return (response as List<dynamic>).map((post) => Post.fromMap(post as Map<String, dynamic>)).toList();
  } catch (e) {
    print('Error fetching posts: ${e.toString()}');
    throw e;
  }
}

Future<List<Comment>> fetchComments(String postId) async {
  try {
    final response = await supabase.from('comments').select('''
          *,
          users!inner (
            display_name,
            photo_url
          )
        ''').eq('post_id', postId).order('created_at', ascending: false);

    return (response as List<dynamic>).map((comment) => Comment.fromMap(comment as Map<String, dynamic>)).toList();
  } catch (e) {
    print('Error fetching comments: ${e.toString()}');
    throw e;
  }
}

Future<void> updateLikeInDatabase(String userId, String postId, bool isLiked) async {
  try {
    if (isLiked) {
      await supabase.from('likes').insert({
        'user_id': userId,
        'post_id': postId,
      });
    } else {
      await supabase.from('likes').delete().match({
        'user_id': userId,
        'post_id': postId,
      });
    }
  } catch (e) {
    print("Error updating like: $e");
  }
}
