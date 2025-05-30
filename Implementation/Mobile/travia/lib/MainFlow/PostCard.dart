import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:travia/Helpers/HelperMethods.dart';
import 'package:travia/Providers/LoadingProvider.dart';
import 'package:travia/database/DatabaseMethods.dart';

import '../Helpers/AppColors.dart';
import '../Helpers/GoogleTexts.dart';
import '../Helpers/PopUp.dart';
import '../Providers/PostsCommentsProviders.dart';
import '../Providers/PostsLikesProvider.dart';
import '../Providers/SavedPostsProvider.dart';
import 'CommentSheet.dart';
import 'MediaPreview.dart';
import 'ReportsPage.dart';

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
  final int dislikesCount;

  const PostCard({
    super.key,
    required this.profilePicUrl,
    required this.username,
    required this.postImageUrl,
    required this.commentCount,
    required this.likesCount,
    required this.dislikesCount,
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
        final reaction = likeState[postId]; // 'like', 'dislike', or null
        final reactionCount = ref.watch(postReactionCountProvider((
          postId: postId,
          likes: likesCount,
          dislikes: dislikesCount,
        )));
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final savedState = ref.watch(savedPostsProvider);
        final isSaved = savedState[postId] ?? false;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 5),
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
                colors: [
                  kDeepPink.withOpacity(0.9),
                  Colors.black87,
                ],
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
                        child: GestureDetector(
                          onTap: () {
                            context.push("/profile/${userId}");
                          },
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
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                context.push("/profile/${userId}");
                              },
                              child: Text(
                                '@$username',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
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
                          color: Colors.white,
                          onSelected: (String result) async {
                            if (result == 'delete') {
                              try {
                                ref.read(loadingProvider.notifier).setLoadingToTrue();
                                await deletePostFromDatabase(postId);
                              } catch (e) {
                                Popup.showError(text: "Error deleting post..", context: context);
                              } finally {
                                ref.invalidate(postsProvider);
                                ref.read(loadingProvider.notifier).setLoadingToFalse();
                              }
                            }
                            if (result == 'share') {
                              Share.share("When we have a domain");
                              // TODO: Share
                            }
                            if (result == 'report') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReportsPage(
                                    targetPostId: postId,
                                    reportType: 'post',
                                  ),
                                ),
                              );
                            }
                          },
                          itemBuilder: (BuildContext context) => [
                            if (userId == currentUserId)
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete, color: kDeepPink),
                                    const SizedBox(width: 10),
                                    LexendText(text: 'Delete'),
                                  ],
                                ),
                              ),
                            PopupMenuItem<String>(
                              value: 'share',
                              child: Row(
                                children: [
                                  const Icon(Icons.share, color: kDeepPink),
                                  const SizedBox(width: 10),
                                  LexendText(text: 'Share'),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'report',
                              child: Row(
                                children: [
                                  const Icon(Icons.flag, color: kDeepPink),
                                  const SizedBox(width: 10),
                                  LexendText(text: 'Report'),
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
                    ref.read(likePostProvider.notifier).toggleReaction(
                          postId: postId,
                          likerId: currentUserId!,
                          posterId: userId,
                          reactionType: 'like',
                        );

                    ref.read(postReactionCountProvider((postId: postId, likes: likesCount, dislikes: dislikesCount)).notifier).updateReaction(from: reaction, to: reaction == 'like' ? null : 'like');

                    if (reaction != 'like' && canSendNotification(postId, 'like', currentUserId!)) {
                      sendNotification(
                        type: "like",
                        title: "",
                        content: currentUserId == userId ? "liked his own post" : "liked your post",
                        target_user_id: userId,
                        source_id: postId,
                        sender_user_id: currentUserId,
                      );
                    }
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
                                    child: _buildGlassActionButton(
                                      icon: CupertinoIcons.chat_bubble,
                                      count: '${ref.watch(postCommentCountProvider(postId))}',
                                      color: kDeepPinkLight.withOpacity(0.8),
                                    )),
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
                                    ref.read(likePostProvider.notifier).toggleReaction(
                                          postId: postId,
                                          likerId: currentUserId!,
                                          posterId: userId,
                                          reactionType: 'like',
                                        );

                                    ref
                                        .read(postReactionCountProvider((postId: postId, likes: likesCount, dislikes: dislikesCount)).notifier)
                                        .updateReaction(from: reaction, to: reaction == 'like' ? null : 'like');

                                    if (reaction != 'like' && canSendNotification(postId, 'like', currentUserId!)) {
                                      sendNotification(
                                        type: "like",
                                        title: "",
                                        content: currentUserId == userId ? "liked his own post" : "liked your post",
                                        target_user_id: userId,
                                        source_id: postId,
                                        sender_user_id: currentUserId,
                                      );
                                    }
                                  },
                                  child: _buildGlassActionButton(
                                    color: kDeepPinkLight.withOpacity(0.8),
                                    icon: reaction == 'like' ? CupertinoIcons.hand_thumbsup_fill : CupertinoIcons.hand_thumbsup,
                                    count: '${reactionCount['likes'] ?? 0}',
                                  ),
                                ),
                                const SizedBox(width: 20),
                                GestureDetector(
                                  onTap: () {
                                    ref.read(likePostProvider.notifier).toggleReaction(
                                          postId: postId,
                                          likerId: currentUserId!,
                                          posterId: userId,
                                          reactionType: 'dislike',
                                        );

                                    ref
                                        .read(postReactionCountProvider((postId: postId, likes: likesCount, dislikes: dislikesCount)).notifier)
                                        .updateReaction(from: reaction, to: reaction == 'dislike' ? null : 'dislike');

                                    if (reaction != 'dislike' && canSendNotification(postId, 'dislike', currentUserId!)) {
                                      sendNotification(
                                        type: "dislike",
                                        title: "",
                                        content: currentUserId == userId ? "disliked his own post" : "disliked your post",
                                        target_user_id: userId,
                                        source_id: postId,
                                        sender_user_id: currentUserId,
                                      );
                                    }
                                  },
                                  child: _buildGlassActionButton(
                                    color: kDeepPinkLight.withOpacity(0.8),
                                    icon: reaction == 'dislike' ? CupertinoIcons.hand_thumbsdown_fill : CupertinoIcons.hand_thumbsdown,
                                    count: '${reactionCount['dislikes'] ?? 0}',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

  Widget _buildGlassActionButton({required IconData icon, required String count, required Color color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.white.withOpacity(0.1),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 6),
          Text(
            count,
            style: GoogleFonts.ibmPlexSans(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
