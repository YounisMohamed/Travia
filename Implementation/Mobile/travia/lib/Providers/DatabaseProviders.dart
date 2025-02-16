import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Classes/Comment.dart';
import '../Classes/Post.dart';
import '../database/DatabaseMethods.dart';

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

class CommentsNotifier extends FamilyAsyncNotifier<List<Comment>, String> {
  @override
  Future<List<Comment>> build(String postId) async {
    return await fetchComments(postId);
  }

  Future<void> refresh() async {
    if (state case AsyncData(:final value)) {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() => fetchComments(value.first.postId));
    }
  }

  void addComment(Comment newComment) {
    if (state case AsyncData(:final value)) {
      state = AsyncData([...value, newComment]); // Append the new comment
    }
  }

  // ✅ Remove comment if insertion fails
  void removeComment(String commentId) {
    if (state case AsyncData(:final value)) {
      state = AsyncData(value.where((c) => c.id != commentId).toList());
    }
  }
}

// Family provider for fetching comments by post ID
final commentsProvider = AsyncNotifierProvider.family<CommentsNotifier, List<Comment>, String>(CommentsNotifier.new);

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
