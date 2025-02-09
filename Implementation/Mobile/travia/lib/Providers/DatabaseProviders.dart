import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Classes/Comment.dart';
import '../Classes/Post.dart';
import '../database/FetchingMethods.dart';

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
}

// Family provider for fetching comments by post ID
final commentsProvider = AsyncNotifierProvider.family<CommentsNotifier, List<Comment>, String>(CommentsNotifier.new);


class LikeNotifier extends StateNotifier<Map<String, bool>> {
  LikeNotifier() : super({});

  void toggleLike(String postId) {
    state = {
      ...state,
      postId: !(state[postId] ?? false), // Toggle like state
    };
  }
}

final likeProvider = StateNotifierProvider<LikeNotifier, Map<String, bool>>((ref) {
  return LikeNotifier();
});
