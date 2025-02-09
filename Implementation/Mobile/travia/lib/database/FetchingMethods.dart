import 'package:supabase_flutter/supabase_flutter.dart';

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
