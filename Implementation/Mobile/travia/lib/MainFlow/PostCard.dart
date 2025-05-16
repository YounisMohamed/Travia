import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:travia/Helpers/HelperMethods.dart';
import 'package:travia/Providers/LoadingProvider.dart';
import 'package:travia/database/DatabaseMethods.dart';

import '../Helpers/AppColors.dart';
import '../Helpers/PopUp.dart';
import '../Providers/PostsCommentsProviders.dart';
import '../Providers/PostsLikesProvider.dart';
import '../Providers/SavedPostsProvider.dart';
import 'CommentSheet.dart';
import 'MediaPreview.dart';

class PostCard extends StatelessWidget {
  final String profilePicUrl;
  final String username;
  final String postImageUrl;
  final int commentCount;
  final String postId;
  final String userId;
  final String? postCaption;
  final String? postLocation;
  final DateTime createdAt;
  final int likesCount;

  const PostCard({
    super.key,
    required this.profilePicUrl,
    required this.username,
    required this.postImageUrl,
    required this.commentCount,
    required this.likesCount,
    required this.postId,
    required this.userId,
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
        final displayNumberOfLikes = ref.watch(postLikeCountProvider((postId: postId, initialLikeCount: likesCount)));
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final savedState = ref.watch(savedPostsProvider);
        final isSaved = savedState[postId] ?? false;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 4,
          shadowColor: Colors.black38,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.8), kDeepPink.withOpacity(0.9)],
              ),
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
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image(
                            image: CachedNetworkImageProvider(profilePicUrl),
                            fit: BoxFit.cover,
                            width: 46,
                            height: 46,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade800,
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white70,
                                  size: 28,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@$username',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeAgo(createdAt),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // More Button
                      Container(
                        decoration: const BoxDecoration(
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
                          icon: const Icon(Icons.more_vert, color: Colors.white),
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
                    ref.read(likePostProvider.notifier).toggleLike(
                          postId: postId,
                          likerId: currentUserId!,
                          posterId: userId,
                        );
                    ref.read(postLikeCountProvider((postId: postId, initialLikeCount: likesCount)).notifier).updateLikeCount(!isLiked);
                  },
                  child: Container(
                    height: 280,
                    width: double.infinity,
                    child: ClipRRect(
                      child: MediaPostPreview(
                        mediaUrl: postImageUrl,
                        isVideo: postImageUrl.endsWith('.mp4') || postImageUrl.endsWith('.mov'),
                      ),
                    ),
                  ),
                ),

                // Action buttons (like, comment, save)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Comment count
                          Container(
                            padding: const EdgeInsets.all(6),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    showMaterialModalBottomSheet(
                                        context: context,
                                        builder: (context) => CommentModal(
                                              postId: postId,
                                              posterId: userId,
                                            ));
                                  },
                                  child: const Icon(
                                    Icons.chat_bubble_outline,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${ref.watch(postCommentCountProvider(postId))}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 24),

                          // Like count
                          Container(
                            padding: const EdgeInsets.all(6),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    ref.read(likePostProvider.notifier).toggleLike(
                                          postId: postId,
                                          likerId: currentUserId!,
                                          posterId: userId,
                                        );
                                    ref.read(postLikeCountProvider((postId: postId, initialLikeCount: likesCount)).notifier).updateLikeCount(!isLiked);
                                  },
                                  child: Image.asset(
                                    isLiked ? "assets/liked.png" : "assets/unliked.png",
                                    width: 22,
                                    height: 22,
                                    color: isLiked ? Colors.red : Colors.white,
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
                                const SizedBox(width: 4),
                                Text(
                                  '$displayNumberOfLikes',
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Save button
                      GestureDetector(
                        onTap: () {
                          ref.read(savedPostsProvider.notifier).toggleSavePost(userId, postId);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            isSaved ? Icons.bookmark : Icons.bookmark_border,
                            color: isSaved ? Colors.amber : Colors.white,
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
                ),

                // Location indicator - if present
                if (postLocation != null && postLocation!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          postLocation!,
                          style: const TextStyle(
                            color: Colors.white70,
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

    if (!isLiked) {
      // Send notification when the post is liked
      if (likerId == userId) {
        sendNotification(
          type: 'like',
          title: "",
          content: 'liked his own post :)',
          target_user_id: userId,
          source_id: postId,
          sender_user_id: likerId,
        );
      } else {
        sendNotification(
          title: "liked your post",
          type: 'like',
          content: 'gave you a like',
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
