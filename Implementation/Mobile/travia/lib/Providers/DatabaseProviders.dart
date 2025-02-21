import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Classes/Comment.dart';
import '../Classes/Post.dart';
import '../database/DatabaseMethods.dart';
import '../main.dart';

class PostsNotifier extends AsyncNotifier<List<Post>> {
  @override
  Future<List<Post>> build() async {
    return await fetchPosts();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => fetchPosts());
  }
}

final postsProvider = AsyncNotifierProvider<PostsNotifier, List<Post>>(() {
  return PostsNotifier();
});

final commentsProvider = StreamProvider.family<List<Comment>, String>((ref, postId) {
  return supabase.from('comments').stream(primaryKey: ['id']).eq('post_id', postId).order('created_at', ascending: false).map((data) => data.map((json) => Comment.fromJson(json)).toList());
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
