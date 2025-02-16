import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travia/Helpers/Constants.dart';
import 'package:travia/Helpers/DefaultText.dart';
import 'package:travia/Helpers/DummyCards.dart';
import 'package:travia/Helpers/HelperMethods.dart';
import 'package:travia/Helpers/PopUp.dart';
import 'package:travia/MainFlow/HomePage.dart';
import 'package:travia/Providers/CommentsLikesProvider.dart';
import 'package:uuid/uuid.dart';

import '../Classes/Comment.dart';
import '../Providers/DatabaseProviders.dart';
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
    // Clean up controller when widget is disposed
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(widget.postId));

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
            color: Colors.black.withValues(alpha: 0.9),
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
                    colors: [Colors.black87, Colors.black54],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Comments",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white, size: 26),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Colors.white24),

              // Comments List
              Flexible(
                // Use Flexible instead of Expanded
                child: commentsAsync.when(
                  loading: () => ListView.builder(itemCount: 3, itemBuilder: (context, index) => DummyCommentCard().animate().fade(duration: 300.ms)),
                  error: (error, stackTrace) => const Center(
                    child: Text("Error loading comments", style: TextStyle(color: Colors.white70)),
                  ),
                  data: (comments) => ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      return CommentCard(
                        userName: comment.userId == FirebaseAuth.instance.currentUser!.uid ? "You" : comment.userName,
                        userPhotoUrl: comment.userPhotoUrl,
                        content: comment.content,
                        createdAt: timeAgo(comment.createdAt),
                        likeCount: comment.likeCount,
                        commentId: comment.id,
                        userId: comment.userId,
                        postId: widget.postId,
                        posterId: widget.posterId,
                      ).animate().fadeIn(duration: 280.ms, delay: 280.ms);
                    },
                  ),
                ),
              ),

              // Comment Input Field
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Form(
                        child: TextField(
                          controller: _commentController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Add a comment...",
                            hintStyle: TextStyle(color: Colors.white54),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white10,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.blueAccent),
                      onPressed: () {
                        String userId = FirebaseAuth.instance.currentUser!.uid;
                        String postId = widget.postId;
                        String content = _commentController.text;

                        final newComment = Comment(
                          id: Uuid().v4(),
                          postId: postId,
                          userId: userId,
                          content: content,
                          createdAt: DateTime.now(),
                          likeCount: 0,
                          userName: "You",
                          userPhotoUrl: FirebaseAuth.instance.currentUser!.photoURL ?? dummyDefaultUser,
                        );

                        try {
                          sendComment(postId: postId, userId: userId, content: content, id: newComment.id);
                          ref.read(commentsProvider(postId).notifier).addComment(newComment);
                          ref.read(postCommentCountProvider(postId).notifier).increment();
                          _commentController.clear();
                        } catch (e) {
                          Popup.showPopUp(text: "Error adding comment", context: context);
                          ref.read(commentsProvider(postId).notifier).removeComment(newComment.id);
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
}

class CommentCard extends StatelessWidget {
  final String userName;
  final String userPhotoUrl;
  final String content;
  final String createdAt;
  final String commentId;
  final String userId;
  final int likeCount;
  final String postId;
  final String posterId;
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
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: commentCardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                // Add boxShadow
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  spreadRadius: 2, // Spread radius
                  blurRadius: 5, // Blur radius
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Image
                CircleAvatar(
                  backgroundImage: NetworkImage(userPhotoUrl),
                  radius: 20,
                ),
                const SizedBox(width: 10),

                // Comment Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Username & Timestamp
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            userName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: contrastCommentCardColor,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            createdAt,
                            style: TextStyle(
                              fontSize: 12,
                              color: contrastCommentCardColor,
                            ),
                          ),
                        ],
                      ),

                      // Comment Text
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          content,
                          style: TextStyle(color: contrastCommentCardColor, fontSize: 14),
                        ),
                      ),
                      SizedBox(
                        height: 4,
                      ),

                      // Like Count & Like Button
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
                            child: Image.asset(
                              isLiked ? "assets/liked.png" : "assets/unliked.png",
                              width: 22,
                              height: 22,
                            )
                                .animate(target: isLiked ? 1 : 0)
                                .rotate(
                                  begin: 0.0,
                                  end: 0.2, // Slight tilt
                                  duration: 100.ms,
                                )
                                .then()
                                .rotate(
                                  begin: 0.2,
                                  end: -0.2, // Wobble back
                                  duration: 100.ms,
                                  curve: Curves.easeInOut,
                                )
                                .then()
                                .rotate(
                                  begin: -0.2,
                                  end: 0, // Reset
                                  duration: 80.ms,
                                )
                                .moveY(
                                  begin: 0,
                                  end: -5, // Small bounce
                                  duration: 150.ms,
                                  curve: Curves.easeOut,
                                )
                                .then()
                                .moveY(
                                  begin: -5,
                                  end: 0, // Back down
                                  duration: 120.ms,
                                  curve: Curves.bounceOut,
                                ),
                          ),
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: DefaultText(
                              text: formatCount(displayNumberOfLikes),
                              isBold: true,
                              size: 16,
                            ),
                          ),
                          Expanded(child: SizedBox()),
                          if (canDelete)
                            IconButton(
                                onPressed: () async {
                                  try {
                                    ref.read(commentsProvider(postId).notifier).removeComment(commentId);
                                    ref.read(postCommentCountProvider(postId).notifier).decrement();
                                    await deleteComment(commentId: commentId);
                                  } catch (e) {
                                    print("Could not delete the comment");
                                  }
                                },
                                icon: Icon(Icons.delete))
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
