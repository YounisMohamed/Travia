import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Classes/Comment.dart';
import '../Classes/Post.dart';
import '../main.dart';

final postsProvider = StreamProvider<List<Post>>((ref) async* {
  final cached = postsBox.get('posts')?.cast<Post>();
  if (cached != null) {
    yield cached;
  }
  try {
    final stream = supabase.from('posts').stream(primaryKey: ['id']).order('created_at', ascending: false).map((data) => data.map((json) => Post.fromJson(json)).toList());

    await for (final posts in stream) {
      await postsBox.put('posts', posts);
      yield posts;
    }
  } catch (e) {
    print('Stream error: $e');
    if (cached != null) {
      yield cached;
    } else {
      rethrow;
    }
  }
});

final commentsProvider = StreamProvider.family<List<Comment>, String>((ref, postId) {
  return supabase.from('comments').stream(primaryKey: ['id']).eq('post_id', postId).map((data) => data.map((json) => Comment.fromJson(json)).toList());
});

class PostCommentCountNotifier extends FamilyNotifier<int, String> {
  @override
  int build(String postId) {
    // Get the initial count from the postsProvider
    final posts = ref.watch(postsProvider).maybeWhen(
          data: (posts) => posts.firstWhere((p) => p.postId == postId).commentCount,
          orElse: () => 0,
        );
    return posts;
  }

  void increment() {
    state = state + 1;
  }

  void decrement() {
    state = state - 1;
  }
}

final postCommentCountProvider = NotifierProvider.family<PostCommentCountNotifier, int, String>(
  PostCommentCountNotifier.new,
);
