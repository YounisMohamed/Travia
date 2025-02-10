import '../Classes/Comment.dart';
import '../Classes/Post.dart';
import '../main.dart';

Future<List<Post>> fetchPosts() async {
  try {
    final response = await supabase.from('posts').select('''
          *,
          users!inner (
            display_name,
            photo_url
          ),
          comments (id)
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
          id, content, created_at, user_id, parent_comment_id, post_id,
          users!inner (display_name, photo_url),
          likes(count)
        ''').eq('post_id', postId).order('created_at', ascending: false);

    return (response as List<dynamic>).map((comment) => Comment.fromMap(comment as Map<String, dynamic>)).toList();
  } catch (e) {
    print('Error fetching comments: ${e.toString()}');
    throw e;
  }
}

Future<void> updatePostLikeInDatabase({required String likerId, required String posterId, required String postId}) async {
  try {
    // Check if the user already liked the post
    final existingLike = await supabase
        .from('likes')
        .select('id') // Fetch only the `id`
        .eq('user_id', likerId)
        .eq('post_id', postId)
        .limit(1) // Ensure we only fetch one row
        .maybeSingle(); // Returns `null` if no match is found
    print(existingLike);

    if (existingLike != null) {
      // If like exists, remove it
      await supabase.from('likes').delete().match({'id': existingLike['id']});
    } else {
      // No like found, add a new one
      await supabase.from('likes').insert({
        'user_id': likerId,
        'liked_user_id': posterId,
        'post_id': postId,
      });
    }
  } catch (e) {
    print("Error updating like: $e");
  }
}

Future<void> updateCommentLikeInDatabase({required String likerId, required String posterId, required String commentId}) async {
  try {
    // Check if the user already liked the post
    final existingLike = await supabase
        .from('likes')
        .select('id') // Fetch only the `id`
        .eq('user_id', likerId)
        .eq('comment_id', commentId)
        .limit(1) // Ensure we only fetch one row
        .maybeSingle(); // Returns `null` if no match is found
    print(existingLike);

    if (existingLike != null) {
      // If like exists, remove it
      await supabase.from('likes').delete().match({'id': existingLike['id']});
    } else {
      // No like found, add a new one
      await supabase.from('likes').insert({
        'user_id': likerId,
        'liked_user_id': posterId,
        'comment_id': commentId,
      });
    }
  } catch (e) {
    print("Error updating like: $e");
  }
}
