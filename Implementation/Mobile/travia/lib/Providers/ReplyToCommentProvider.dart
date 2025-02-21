import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReplyState extends StateNotifier<ReplyStateModel?> {
  ReplyState() : super(null);

  void startReply(String commentId, String username) {
    state = ReplyStateModel(
      isReplying: true,
      parentCommentId: commentId,
      username: username,
    );
  }

  void cancelReply() {
    state = null; // Reset reply state
  }
}

class ReplyStateModel {
  final bool isReplying;
  final String parentCommentId;
  final String username;

  ReplyStateModel({
    required this.isReplying,
    required this.parentCommentId,
    required this.username,
  });
}

final replyStateProvider = StateNotifierProvider<ReplyState, ReplyStateModel?>(
  (ref) => ReplyState(),
);
