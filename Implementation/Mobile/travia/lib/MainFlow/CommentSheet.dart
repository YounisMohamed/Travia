import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:travia/Helpers/DummyCards.dart';
import 'package:travia/Helpers/HelperMethods.dart';
import 'package:travia/Helpers/Loading.dart';
import 'package:travia/Providers/CommentsLikesProvider.dart';

import '../Classes/Comment.dart';
import '../Helpers/AppColors.dart';
import '../Helpers/PopUp.dart';
import '../Providers/ChatDetailsProvider.dart';
import '../Providers/CommentLogicProvider.dart';
import '../Providers/LoadingProvider.dart';
import '../Providers/PostsCommentsProviders.dart';
import '../Providers/ReplyToCommentProvider.dart';
import '../database/DatabaseMethods.dart';
import 'ReportsPage.dart';

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
    final textDirection = ref.watch(textDirectionProvider);
    final isLoading = ref.watch(commentSubmitProvider).isLoading || ref.watch(deleteCommentProvider).isLoading;
    ref.listen(commentSubmitProvider, (prev, next) {
      if (next is AsyncLoading) {
        ref.read(isCommentsLoadingProvider.notifier).state = true;
      } else {
        ref.read(isCommentsLoadingProvider.notifier).state = false;
      }

      if (next is AsyncData) {
        _commentController.clear();
        ref.read(replyStateProvider.notifier).cancelReply();
      }

      if (next is AsyncError) {
        Popup.showError(text: "Error adding comment", context: context);
      }
    });
    ref.listen(deleteCommentProvider, (prev, next) {
      if (next is AsyncLoading) {
        ref.read(isCommentsLoadingProvider.notifier).state = true;
      } else {
        ref.read(isCommentsLoadingProvider.notifier).state = false;
      }

      if (next is AsyncError) {
        Popup.showError(text: "Error deleting comment", context: context);
      }
    });

    return SafeArea(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Container(
          decoration: BoxDecoration(
            color: commentSheetColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 12,
                spreadRadius: 3,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // **Modal Header**
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
                    const SizedBox(width: 8),
                    Text(
                      "Comments",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: contrastCommentCardColor,
                      ),
                    ),
                    const Spacer(),
                    isLoading
                        ? LoadingWidget(
                            size: 23,
                          )
                        : const SizedBox.shrink(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: contrastCommentCardColor, size: 26),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Colors.white24),

              // **Comment Input Field**
              Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: commentInputBackground,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, child) {
                          final replyState = ref.watch(replyStateProvider);
                          return TextField(
                            textDirection: textDirection,
                            onChanged: (text) {
                              updateTextDirection(ref, text);
                            },
                            controller: _commentController,
                            cursorColor: Colors.black,
                            style: GoogleFonts.lexendDeca(color: commentTextColor, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: replyState != null ? "Replying to @${replyState.username}..." : "Add a comment...",
                              hintStyle: GoogleFonts.lexendDeca(color: hintTextColor, fontSize: 15, fontWeight: FontWeight.bold),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            ),
                          );
                        },
                      ),
                    ),

                    // **Cancel Reply Button**
                    Consumer(
                      builder: (context, ref, child) {
                        final isReplying = ref.watch(replyStateProvider) != null;
                        return isReplying
                            ? GestureDetector(
                                onTap: () => ref.read(replyStateProvider.notifier).cancelReply(),
                                child: Icon(Icons.close, color: cancelButtonColor, size: 22),
                              )
                            : const SizedBox.shrink();
                      },
                    ),

                    // **Send Button**
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onTap: () {
                          final content = _commentController.text.trim();
                          if (content.isEmpty) return;
                          ref.read(commentSubmitProvider.notifier).submitComment(
                                postId: widget.postId,
                                content: content,
                                posterId: widget.posterId,
                                parentCommentId: replyState?.parentCommentId,
                              );
                        },
                        child: Icon(Icons.send, color: kDeepPink, size: 22),
                      ),
                    ),
                  ],
                ),
              ),

              // **Comments List**
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
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (context.mounted) {
                            context.go("/error-page/${Uri.encodeComponent(error.toString())}/${Uri.encodeComponent("/")}");
                          }
                        });
                        return const Center(child: LoadingWidget());
                      },
                      data: (comments) {
                        final threadedComments = _organizeComments(comments);
                        final rootComments = _getRootComments(comments);
                        return ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: rootComments.length,
                          itemBuilder: (context, index) {
                            final rootComment = rootComments[index];
                            return _buildCommentTree(rootComment, threadedComments, 0, ref);
                          },
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  final replyExpandProvider = StateProvider.family<bool, String>((ref, commentId) => false);

  Widget _buildCommentTree(Comment comment, Map<String, List<Comment>> threadedComments, double depth, WidgetRef ref) {
    List<Comment> replies = threadedComments[comment.id] ?? [];
    final isExpanded = ref.watch(replyExpandProvider(comment.id));

    return Padding(
      padding: EdgeInsets.only(left: depth > 3 ? depth : depth * 8.0),
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
          ),

          // Show "Show all replies" button if replies exist
          if (replies.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: depth == 0 ? MediaQuery.of(context).size.width * 0.201 : MediaQuery.of(context).size.width * 0.24, bottom: 10),
              child: GestureDetector(
                onTap: () {
                  // Toggle the state with minimal rebuild
                  ref.read(replyExpandProvider(comment.id).notifier).state = !isExpanded;
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 14,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isExpanded ? "Hide replies" : "Show replies (${replies.length})",
                      style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

          // Simple and reliable animation approach
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0, width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: replies.map((reply) => _buildCommentTree(reply, threadedComments, depth + 1, ref)).toList(),
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 400),
            sizeCurve: Curves.easeInOut,
            firstCurve: Curves.easeOut,
            secondCurve: Curves.easeIn,
          ),
        ],
      ),
    );
  }
}

// Main Comment Card Widget that decides which card to render
class CommentCard extends StatelessWidget {
  final String commentId;
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final String content;
  final String createdAt;
  final int likeCount;
  final String posterId;
  final String postId;
  final bool isReply;
  final String? userNameOfParentComment;

  const CommentCard({
    super.key,
    required this.commentId,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.content,
    required this.createdAt,
    required this.likeCount,
    required this.posterId,
    required this.postId,
    required this.isReply,
    this.userNameOfParentComment,
  });

  @override
  Widget build(BuildContext context) {
    // Return either a regular comment card or a reply card based on isReply
    return isReply
        ? ReplyCommentCard(
            commentId: commentId,
            userId: userId,
            userName: userName,
            userPhotoUrl: userPhotoUrl,
            content: content,
            createdAt: createdAt,
            likeCount: likeCount,
            posterId: posterId,
            postId: postId,
            userNameOfParentComment: userNameOfParentComment,
          )
        : RegularCommentCard(
            commentId: commentId,
            userId: userId,
            userName: userName,
            userPhotoUrl: userPhotoUrl,
            content: content,
            createdAt: createdAt,
            likeCount: likeCount,
            posterId: posterId,
            postId: postId,
          );
  }
}

// Regular Comment Card
class RegularCommentCard extends StatelessWidget {
  final String commentId;
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final String content;
  final String createdAt;
  final int likeCount;
  final String posterId;
  final String postId;

  const RegularCommentCard({
    super.key,
    required this.commentId,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.content,
    required this.createdAt,
    required this.likeCount,
    required this.posterId,
    required this.postId,
  });

  @override
  Widget build(BuildContext context) {
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
            margin: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: commentSheetColor,
              borderRadius: BorderRadius.circular(12),
            ),
            // Using a Stack with Padding instead of IntrinsicHeight
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Picture - Now directly in the row with proper alignment
                  GestureDetector(
                    onTap: () {
                      context.push("/profile/${userId}");
                    },
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(userPhotoUrl),
                      radius: 20,
                    ),
                  ),
                  const SizedBox(width: 12), // Add spacing between avatar and content
                  // Main Content Column
                  Expanded(
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
                                  context.push("/profile/${userId}");
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
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              createdAt,
                              style: TextStyle(
                                fontSize: 13,
                                color: contrastCommentCardColor.withOpacity(0.7),
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
                                    fontSize: 15,
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
                                  fontSize: 15,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(
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
                                    width: 22,
                                    height: 22,
                                    color: kDeepPink,
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
                                      fontSize: 14,
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
                                  color: kDeepPink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Report Button
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ReportsPage(
                                      targetCommentId: commentId,
                                      reportType: 'comment',
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                "Report",
                                style: TextStyle(
                                  color: Colors.black.withOpacity(0.3),
                                  fontSize: 12,
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
                                    await deleteComment(commentId: commentId);
                                    //ref.read(postCommentCountProvider(postId).notifier).decrement();
                                    ref.invalidate(commentsProvider(postId));
                                  } catch (e) {
                                    print("Could not delete the comment: $e");
                                  } finally {}
                                },
                                style: IconButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                ),
                                icon: Icon(
                                  Icons.delete,
                                  size: 18,
                                  color: contrastCommentCardColor,
                                ),
                              ),
                          ],
                        ),
                      ],
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

// Reply Comment Card
class ReplyCommentCard extends ConsumerWidget {
  final String commentId;
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final String content;
  final String createdAt;
  final int likeCount;
  final String posterId;
  final String postId;
  final String? userNameOfParentComment;

  const ReplyCommentCard({
    super.key,
    required this.commentId,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.content,
    required this.createdAt,
    required this.likeCount,
    required this.posterId,
    required this.postId,
    this.userNameOfParentComment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            margin: const EdgeInsets.only(
              left: 32,
              right: 16,
              top: 8,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: commentSheetColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      context.push("/profile/${userId}");
                    },
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(userPhotoUrl),
                      radius: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  context.push("/profile/${userId}");
                                },
                                child: Text(
                                  "@$userName",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: contrastCommentCardColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              createdAt,
                              style: TextStyle(
                                fontSize: 12,
                                color: contrastCommentCardColor.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        if (userNameOfParentComment != null)
                          Row(
                            children: [
                              Text(
                                'Replying to ',
                                style: GoogleFonts.lexendDeca(color: contrastCommentCardColor.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              GestureDetector(
                                onTap: () {
                                  context.push("/profile/${userId}");
                                },
                                child: Text(
                                  "@$userNameOfParentComment",
                                  style: GoogleFonts.lexendDeca(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        SizedBox(
                          height: 10,
                        ),
                        RichText(
                          textDirection: isMostlyRtl(content),
                          text: TextSpan(
                            children: content.split(' ').map((word) {
                              if (word.startsWith('@')) {
                                return TextSpan(
                                  text: "$word ",
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 14,
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
                                  fontSize: 14,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
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
                                    width: 20,
                                    height: 20,
                                    color: kDeepPink,
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
                                  const SizedBox(width: 6),
                                  Text(
                                    formatCount(displayNumberOfLikes),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: contrastCommentCardColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
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
                                  color: kDeepPink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Report Button
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ReportsPage(
                                      targetCommentId: commentId,
                                      reportType: 'comment',
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                "Report",
                                style: TextStyle(
                                  color: Colors.black.withOpacity(0.3),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (canDelete)
                              IconButton(
                                onPressed: () async {
                                  try {
                                    ref.read(deleteCommentProvider.notifier).delete(commentId, postId);
                                  } catch (e) {
                                    print("Could not delete the comment: $e");
                                  } finally {}
                                },
                                icon: Icon(
                                  Icons.delete,
                                  size: 18,
                                  color: contrastCommentCardColor,
                                ),
                              ),
                          ],
                        ),
                      ],
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
