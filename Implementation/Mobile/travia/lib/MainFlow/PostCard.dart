import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:travia/Helpers/GoogleTexts.dart';
import 'package:travia/Helpers/HelperMethods.dart';
import 'package:travia/Providers/LoadingProvider.dart';
import 'package:travia/database/DatabaseMethods.dart';

import '../Helpers/PopUp.dart';
import '../Providers/DatabaseProviders.dart';
import '../Providers/PostsLikesProvider.dart';
import '../Providers/SavedPostsProvider.dart';
import 'CommentSheet.dart';

class PostCard extends StatelessWidget {
  final String profilePicUrl;
  final String username;
  final String postImageUrl;
  final int commentCount;
  final String postId;
  final String userId;
  final int likeCount;
  final String? postCaption;
  final String? postLocation;
  final DateTime createdAt;

  const PostCard({
    super.key,
    required this.profilePicUrl,
    required this.username,
    required this.postImageUrl,
    required this.commentCount,
    required this.postId,
    required this.userId,
    required this.likeCount,
    required this.createdAt,
    this.postCaption,
    this.postLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final likeState = ref.watch(likePostProvider);
        final isLiked = likeState[postId] ?? false;
        final displayNumberOfLikes = ref.watch(postLikeCountProvider((postId: postId, initialLikeCount: likeCount)));
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final savedState = ref.watch(savedPostsProvider);
        final isSaved = savedState[postId] ?? false;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          elevation: 2,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Info Section
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.deepOrange.shade300,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image(
                          image: NetworkImage(profilePicUrl),
                          fit: BoxFit.cover,
                          width: 50,
                          height: 50,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                color: Colors.deepOrange.shade300,
                                strokeWidth: 2,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.person,
                                color: Colors.grey,
                                size: 30,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                timeAgo(createdAt),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // More Button with improved styling
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                      child: PopupMenuButton<String>(
                        onSelected: (String result) async {
                          if (result == 'delete') {
                            try {
                              ref.read(loadingProvider.notifier).setLoadingToTrue();
                              await deletePostFromDatabase(postId);
                            } catch (e) {
                              Popup.showPopUp(text: "Error deleting post..", context: context);
                            } finally {
                              ref.invalidate(postsProvider);
                              ref.read(loadingProvider.notifier).setLoadingToFalse();
                            }
                          }
                          if (result == 'share') {
                            Share.share("When we have a domain");
                            // TODO: Share
                          }
                          // TODO: REPORT FUNCTIONALITY
                        },
                        itemBuilder: (BuildContext context) => [
                          if (userId == currentUserId)
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 10),
                                  Text('Delete Post'),
                                ],
                              ),
                            ),
                          const PopupMenuItem<String>(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share, color: Colors.blue),
                                SizedBox(width: 10),
                                Text('Share'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'report',
                            child: Row(
                              children: [
                                Icon(Icons.flag, color: Colors.orange),
                                SizedBox(width: 10),
                                Text('Report'),
                              ],
                            ),
                          ),
                        ],
                        icon: const Icon(Icons.more_vert),
                        offset: const Offset(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Post Image Section
              GestureDetector(
                onDoubleTap: () {
                  likePost(ref, isLiked);
                },
                child: Container(
                  height: 300,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image(
                        image: NetworkImage(postImageUrl),
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: 300,
                      ),
                      // Location indicator
                      if (postLocation != null && postLocation!.isNotEmpty)
                        Positioned(
                          bottom: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  postLocation!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Like, Comment, and Share Section
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            // Like Button
                            GestureDetector(
                              onTap: () {
                                likePost(ref, isLiked);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isLiked ? Colors.red.withValues(alpha: 0.1) : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Image.asset(
                                  isLiked ? "assets/liked.png" : "assets/unliked.png",
                                  width: 24,
                                  height: 24,
                                )
                                    .animate(target: isLiked ? 1 : 0)
                                    .shake(
                                      hz: 8,
                                      curve: Curves.easeOut,
                                      duration: 600.ms,
                                    )
                                    .fade(
                                      begin: 0.5,
                                      end: 2,
                                      duration: 700.ms,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            RedHatText(
                              text: formatCount(displayNumberOfLikes),
                              isBold: true,
                              size: 15,
                            ),
                            const SizedBox(width: 16),

                            // Comment button
                            GestureDetector(
                              onTap: () {
                                showMaterialModalBottomSheet(
                                  context: context,
                                  builder: (context) => CommentModal(
                                    postId: postId,
                                    posterId: userId,
                                  ),
                                  backgroundColor: Colors.transparent,
                                  bounce: true,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline,
                                  color: Colors.grey,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${ref.watch(postCommentCountProvider(postId))}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        // Save Button
                        GestureDetector(
                          onTap: () {
                            ref.read(savedPostsProvider.notifier).toggleSavePost(userId, postId);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSaved ? Colors.amber.withValues(alpha: 0.1) : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isSaved ? Icons.bookmark : Icons.bookmark_border,
                              color: isSaved ? Colors.amber.shade800 : null,
                              size: 24,
                            )
                                .animate(target: isSaved ? 1 : 0)
                                .scale(
                                  begin: const Offset(0.8, 0.8),
                                  end: const Offset(1.2, 1.2),
                                  duration: 300.ms,
                                )
                                .then()
                                .scale(
                                  begin: const Offset(1.2, 1.2),
                                  end: const Offset(1.0, 1.0),
                                  duration: 200.ms,
                                ),
                          ),
                        ),
                      ],
                    ),

                    // timestamp and like details
                    if (displayNumberOfLikes > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.person,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              displayNumberOfLikes > 1 ? 'Liked by $username and ${displayNumberOfLikes - 1} others' : 'Liked by $username',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void likePost(WidgetRef ref, bool isLiked) async {
    String likerId = FirebaseAuth.instance.currentUser!.uid;

    ref.read(likePostProvider.notifier).toggleLike(
          postId: postId,
          likerId: likerId,
          posterId: userId,
        );

    ref.read(postLikeCountProvider((postId: postId, initialLikeCount: likeCount)).notifier).updateLikeCount(!isLiked);

    if (!isLiked) {
      // Send notification when the post is liked
      if (likerId == userId) {
        sendNotification(
          type: 'like',
          content: 'liked his own post :)',
          target_user_id: userId,
          source_id: postId,
          sender_user_id: likerId,
        );
      } else {
        sendNotification(
          type: 'like',
          content: 'liked your post',
          target_user_id: userId,
          source_id: postId,
          sender_user_id: likerId,
        );
      }
    } else {
      print("ELSE");
      // Remove notification when the post is unliked
      removeLikeNotification(
        targetUserId: userId,
        sourceId: postId,
        senderId: likerId,
      );
    }
  }
}
