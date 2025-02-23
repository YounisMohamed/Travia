import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:travia/Helpers/Constants.dart';
import 'package:travia/Helpers/DummyCards.dart';
import 'package:travia/Helpers/HelperMethods.dart';
import 'package:travia/Helpers/Loading.dart';
import 'package:travia/Helpers/PopUp.dart';
import 'package:travia/Providers/CommentsLikesProvider.dart';
import 'package:uuid/uuid.dart';

import '../Classes/Comment.dart';
import '../Providers/DatabaseProviders.dart';
import '../Providers/LoadingProvider.dart';
import '../Providers/ReplyToCommentProvider.dart';
import '../database/DatabaseMethods.dart';

class CommentModal extends ConsumerStatefulWidget {
  final String postId;
  final String posterId;
  const CommentModal({super.key, required this.postId, required this.posterId});

  @override
  ConsumerState<CommentModal> createState() => _CommentModalState();
}

class _CommentModalState extends ConsumerState<CommentModal> {
  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Map<String, List<Comment>> _organizeComments(List<Comment> comments) {
    Map<String, List<Comment>> threadedComments = {};

    // Initialize all comments in the map
    for (var comment in comments) {
      threadedComments[comment.id] = [];
    }

    // Associate replies with their parent comments
    for (var comment in comments) {
      if (comment.parentCommentId != null && threadedComments.containsKey(comment.parentCommentId)) {
        threadedComments[comment.parentCommentId]!.add(comment);
      }
    }

    // Sort replies for each comment
    threadedComments.forEach((_, replies) {
      replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });

    return threadedComments;
  }

  // Helper method to get root comments
  List<Comment> _getRootComments(List<Comment> comments) {
    return comments.where((comment) => comment.parentCommentId == null).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by newest first
  }

  @override
  Widget build(BuildContext context) {
    final replyState = ref.watch(replyStateProvider);
    final isLoading = ref.watch(loadingProvider);

    return SafeArea(
      child: Padding(
        // Add padding to handle keyboard
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          // Remove fixed height to allow dynamic resizing
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: commentSheetColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Allow column to shrink
            children: [
              // Modal Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [contrastCommentColorGradient2, contrastCommentColorGradient1],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Text(
                      "Comments",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: contrastCommentCardColor),
                    ),
                    SizedBox(
                      width: 16,
                    ),
                    isLoading ? LoadingWidget() : SizedBox.shrink(),
                    Expanded(child: Container()),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: contrastCommentCardColor, size: 26),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Colors.white24),

              // Comments List
              Flexible(
                child: Consumer(
                  builder: (context, ref, child) {
                    final commentsAsync = ref.watch(commentsProvider(widget.postId));

                    return commentsAsync.when(
                      loading: () => Skeletonizer(
                        ignoreContainers: true,
                        child: ListView.builder(
                          itemCount: 3,
                          itemBuilder: (context, index) => DummyCommentCard(),
                        ),
                      ),
                      error: (error, stackTrace) {
                        print(error);
                        return Center(
                          child: Text("Error loading comments", style: TextStyle(color: contrastCommentCardColor)),
                        );
                      },
                      data: (comments) {
                        final threadedComments = _organizeComments(comments);
                        final rootComments = _getRootComments(comments);
                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: rootComments.length,
                          itemBuilder: (context, index) {
                            final rootComment = rootComments[index];
                            return _buildCommentTree(rootComment, threadedComments, 0);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              // Comment Input Field
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: contrastCommentCardColor,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, child) {
                          final replyState = ref.watch(replyStateProvider);

                          return TextField(
                            controller: _commentController,
                            style: const TextStyle(color: commentSheetColor),
                            decoration: InputDecoration(
                              hintText: replyState != null ? "Replying to @${replyState.username}..." : "Add a comment...",
                              hintStyle: TextStyle(color: commentSheetColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.black12,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          );
                        },
                      ),
                    ),

                    // Cancel Reply Button (Only visible when replying)
                    Consumer(
                      builder: (context, ref, child) {
                        final isReplying = ref.watch(replyStateProvider) != null;
                        return isReplying
                            ? IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () {
                                  ref.read(replyStateProvider.notifier).cancelReply();
                                },
                              )
                            : const SizedBox.shrink(); // Hide if not replying
                      },
                    ),

                    // Send Button
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.blueAccent),
                      onPressed: () async {
                        ref.read(loadingProvider.notifier).setLoadingToTrue();
                        String userId = FirebaseAuth.instance.currentUser!.uid;
                        String content = _commentController.text.trim();

                        if (content.isEmpty) {
                          ref.read(loadingProvider.notifier).setLoadingToFalse();
                          return;
                        }

                        try {
                          String commentId = Uuid().v4();
                          await sendComment(
                            postId: widget.postId,
                            userId: userId,
                            content: content,
                            id: commentId,
                            parentCommentId: replyState?.parentCommentId, // Ensure correct threading
                          );
                          await sendNotification(type: 'comment', content: 'commented on your post: "$content"', target_user_id: widget.posterId, source_id: widget.postId, sender_user_id: userId);

                          // Clear input field and reset reply state
                          _commentController.clear();
                          ref.read(replyStateProvider.notifier).cancelReply();

                          // Increment the comment count
                          ref.read(postCommentCountProvider(widget.postId).notifier).increment();
                        } catch (e) {
                          Popup.showPopUp(text: "Error adding comment", context: context);
                        } finally {
                          ref.read(loadingProvider.notifier).setLoadingToFalse();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentTree(Comment comment, Map<String, List<Comment>> threadedComments, int depth) {
    List<Comment> replies = threadedComments[comment.id] ?? [];

    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Comment Card
          CommentCard(
            userName: comment.userUsername,
            userPhotoUrl: comment.userPhotoUrl,
            content: comment.content,
            createdAt: timeAgo(comment.createdAt),
            likeCount: comment.likeCount,
            commentId: comment.id,
            userId: comment.userId,
            postId: widget.postId,
            posterId: widget.posterId,
            isReply: comment.parentCommentId != null,
            userNameOfParentComment: comment.usernameOfParentComment,
          ).animate().fadeIn(duration: 280.ms, delay: 280.ms),

          // Render Replies (Recursive)
          ...replies.map((reply) => _buildCommentTree(reply, threadedComments, depth)),
        ],
      ),
    );
  }
}

class CommentCard extends ConsumerWidget {
  final String userName;
  final String userPhotoUrl;
  final String content;
  final String createdAt;
  final String commentId;
  final String userId;
  final int likeCount;
  final String postId;
  final String posterId;
  final bool isReply;
  final String? userNameOfParentComment;

  const CommentCard({
    super.key,
    required this.userName,
    required this.userPhotoUrl,
    required this.content,
    required this.createdAt,
    required this.likeCount,
    required this.commentId,
    required this.userId,
    required this.postId,
    required this.posterId,
    this.isReply = false,
    this.userNameOfParentComment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(loadingProvider);
    return Consumer(
      builder: (context, ref, child) {
        final likeState = ref.watch(likeCommentProvider);
        final isLiked = likeState[commentId] ?? false;
        final displayNumberOfLikes = ref.watch(commentLikeCountProvider((commentId: commentId, initialLikeCount: likeCount)));
        final currentUserId = FirebaseAuth.instance.currentUser!.uid;
        final canDelete = currentUserId == userId || currentUserId == posterId;

        return GestureDetector(
          onDoubleTap: () {
            ref.read(likeCommentProvider.notifier).toggleLike(
                  commentId: commentId,
                  likerId: currentUserId,
                  posterId: userId,
                );
            ref.read(commentLikeCountProvider((commentId: commentId, initialLikeCount: likeCount)).notifier).updateLikeCount(!isLiked);
          },
          child: Container(
            margin: EdgeInsets.only(
              left: isReply ? 48 : 16,
              right: 16,
              top: 8,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: commentSheetColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Picture Column
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: GestureDetector(
                      onTap: () {
                        // TODO: GO TO PROFILE PAGE
                      },
                      child: CircleAvatar(
                        backgroundImage: NetworkImage(userPhotoUrl),
                        radius: isReply ? 16 : 20,
                      ),
                    ),
                  ),

                  // Main Content Column
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Username and Timestamp Row
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () {
                                    // TODO: Go to profile page
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    alignment: Alignment.centerLeft,
                                  ),
                                  child: Text(
                                    "@$userName",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: contrastCommentCardColor,
                                      fontSize: isReply ? 13 : 15,
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                createdAt,
                                style: TextStyle(
                                  fontSize: isReply ? 11 : 13,
                                  color: contrastCommentCardColor.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),

                          // Reply Reference (if applicable)
                          if (isReply && userNameOfParentComment != null)
                            Row(
                              children: [
                                Text(
                                  'Replying to ',
                                  style: TextStyle(
                                    color: contrastCommentCardColor.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    // TODO: Go to profile page
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                  ),
                                  child: Text(
                                    "@$userNameOfParentComment",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                          // Comment Content
                          RichText(
                            text: TextSpan(
                              children: content.split(' ').map((word) {
                                if (word.startsWith('@')) {
                                  return TextSpan(
                                    text: "$word ",
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: isReply ? 13 : 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        print("Tapped on: $word");
                                      },
                                  );
                                }
                                return TextSpan(
                                  text: "$word ",
                                  style: TextStyle(
                                    color: contrastCommentCardColor,
                                    fontSize: isReply ? 13 : 15,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          SizedBox(
                            height: 16,
                          ),

                          // Interaction Row
                          Row(
                            children: [
                              // Like Button and Count
                              GestureDetector(
                                onTap: () {
                                  ref.read(likeCommentProvider.notifier).toggleLike(
                                        commentId: commentId,
                                        likerId: FirebaseAuth.instance.currentUser!.uid,
                                        posterId: userId,
                                      );
                                  ref.read(commentLikeCountProvider((commentId: commentId, initialLikeCount: likeCount)).notifier).updateLikeCount(!isLiked);
                                },
                                child: Row(
                                  children: [
                                    Image.asset(
                                      isLiked ? "assets/liked.png" : "assets/unliked.png",
                                      width: isReply ? 18 : 22,
                                      height: isReply ? 18 : 22,
                                      color: Colors.purple,
                                    )
                                        .animate(target: isLiked ? 1 : 0)
                                        .rotate(
                                          begin: 0.0,
                                          end: 0.2,
                                          duration: 100.ms,
                                        )
                                        .then()
                                        .rotate(
                                          begin: 0.2,
                                          end: -0.2,
                                          duration: 100.ms,
                                          curve: Curves.easeInOut,
                                        )
                                        .then()
                                        .rotate(
                                          begin: -0.2,
                                          end: 0,
                                          duration: 80.ms,
                                        )
                                        .moveY(
                                          begin: 0,
                                          end: -5,
                                          duration: 150.ms,
                                          curve: Curves.easeOut,
                                        )
                                        .then()
                                        .moveY(
                                          begin: -5,
                                          end: 0,
                                          duration: 120.ms,
                                          curve: Curves.bounceOut,
                                        ),
                                    const SizedBox(width: 8),
                                    Text(
                                      formatCount(displayNumberOfLikes),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: isReply ? 12 : 14,
                                        color: contrastCommentCardColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 16),

                              // Reply Button
                              GestureDetector(
                                onTap: () {
                                  ref.read(replyStateProvider.notifier).startReply(
                                        commentId,
                                        userName,
                                      );
                                },
                                child: Text(
                                  "Reply",
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: isReply ? 12 : 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                              const Spacer(),

                              // Delete Button (if applicable)
                              if (canDelete)
                                IconButton(
                                  onPressed: () async {
                                    try {
                                      ref.read(loadingProvider.notifier).setLoadingToTrue();
                                      await deleteComment(commentId: commentId);
                                      ref.read(postCommentCountProvider(postId).notifier).decrement();
                                      ref.invalidate(commentsProvider(postId));
                                    } catch (e) {
                                      print("Could not delete the comment: $e");
                                    } finally {
                                      ref.read(loadingProvider.notifier).setLoadingToFalse();
                                    }
                                  },
                                  style: IconButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                  ),
                                  icon: Icon(
                                    Icons.delete,
                                    size: isReply ? 18 : 20,
                                    color: contrastCommentCardColor,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
