import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../database/DatabaseMethods.dart';
import 'PostsCommentsProviders.dart';

class CommentSubmitNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submitComment({
    required String postId,
    required String content,
    required String posterId,
    String? parentCommentId,
  }) async {
    state = const AsyncLoading();

    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      String commentId = const Uuid().v4();

      await sendComment(
        postId: postId,
        userId: userId,
        content: content,
        id: commentId,
        parentCommentId: parentCommentId,
      );

      await sendNotification(
        type: 'comment',
        title: "commented on your post",
        content: content,
        target_user_id: posterId,
        source_id: postId,
        sender_user_id: userId,
      );

      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final commentSubmitProvider = AsyncNotifierProvider<CommentSubmitNotifier, void>(
  CommentSubmitNotifier.new,
);

class DeleteCommentNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> delete(String commentId, String postId) async {
    state = const AsyncLoading();
    try {
      await deleteComment(commentId: commentId);
      ref.invalidate(commentsProvider(postId));
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final deleteCommentProvider = AsyncNotifierProvider<DeleteCommentNotifier, void>(
  DeleteCommentNotifier.new,
);
