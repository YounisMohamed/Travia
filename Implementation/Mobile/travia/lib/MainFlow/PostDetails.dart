import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:travia/Helpers/Loading.dart';
import 'package:uuid/uuid.dart';

import '../Classes/Post.dart';
import '../Helpers/GoogleTexts.dart';
import '../Helpers/PopUp.dart';
import '../Providers/LoadingProvider.dart';
import '../Providers/PostsCommentsProviders.dart';
import '../Providers/PostsLikesProvider.dart';
import '../Providers/SavedPostsProvider.dart';
import '../database/DatabaseMethods.dart';
import 'CommentSheet.dart';
import 'HomePage.dart';

class PostDetailsPage extends ConsumerWidget {
  final String postId;

  PostDetailsPage({
    super.key,
    required this.postId,
  });
  final TextEditingController _commentController = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(postsProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final likeState = ref.watch(likePostProvider);
    final isLiked = likeState[postId] ?? false;
    final isLoading = ref.watch(loadingProvider);
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final savedState = ref.watch(savedPostsProvider);
    final isSaved = savedState[postId] ?? false;
    Future.microtask(() async {
      await addViewedPost(userId, postId);
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: postsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: RedHatText(text: 'Error: $error')),
        data: (posts) {
          final post = posts.firstWhere((p) => p.postId == postId, orElse: () {
            return Post(
              postId: "",
              createdAt: DateTime.now(),
              userId: "",
              commentCount: 0,
              likeCount: 0,
              mediaUrl: "",
              userPhotoUrl: "",
              userUserName: "",
              viewCount: 0,
            );
          });

          if (post.postId == "") {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.go("/");
              }
            });
            return const SizedBox.shrink();
          }

          final displayNumberOfLikes = ref.watch(postLikeCountProvider((postId: postId, initialLikeCount: post.likeCount)));
          return CustomScrollView(
            // rest of code..
            slivers: [
              SliverAppBar(
                forceMaterialTransparency: true,
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Row(
                  children: [
                    CircleAvatar(
                      radius: screenWidth * 0.04,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: NetworkImage(post.userPhotoUrl),
                    ),
                    SizedBox(width: screenWidth * 0.02),
                    Expanded(
                      child: RedHatText(
                        text: post.userUserName,
                        size: 18,
                        isBold: true,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.black87),
                    onPressed: () {},
                  ),
                ],
                pinned: true,
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Post Image
                    AspectRatio(
                      aspectRatio: 1,
                      child: Image.network(
                        post.mediaUrl,
                        fit: BoxFit.cover,
                      ),
                    ),

                    // Engagement Stats Row
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.05,
                        vertical: screenHeight * 0.01,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border(
                          top: BorderSide(color: Colors.grey[200]!),
                          bottom: BorderSide(color: Colors.grey[200]!),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildEngagementStat(
                            icon: Icons.mode_comment_outlined,
                            count: '${ref.watch(postCommentCountProvider(postId))}',
                            color: Colors.blueAccent,
                          ),
                          _buildEngagementStat(
                            icon: Icons.favorite,
                            count: displayNumberOfLikes.toString(),
                            color: Colors.pinkAccent,
                          ),
                          _buildEngagementStat(
                            icon: Icons.remove_red_eye,
                            count: '${post.viewCount}',
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: screenWidth * 0.04, // horizontal spacing
                          runSpacing: screenWidth * 0.02, // vertical spacing
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildActionButton(
                                  icon: isLiked ? Icons.favorite : Icons.favorite_border, // Change icon when liked
                                  label: isLiked ? 'Liked' : 'Like',
                                  onTap: () {
                                    likePost(ref, isLiked, post.likeCount, post.userId);
                                  },
                                  color: isLiked ? Colors.red : Colors.black, // Change color when liked
                                ),
                                SizedBox(width: screenWidth * 0.03),
                                _buildActionButton(
                                  icon: Icons.mode_comment_outlined,
                                  label: 'Comments',
                                  color: Colors.black,
                                  onTap: () {
                                    showMaterialModalBottomSheet(
                                      context: context,
                                      builder: (context) => CommentModal(
                                        postId: postId,
                                        posterId: post.userId,
                                      ),
                                      backgroundColor: Colors.transparent,
                                      bounce: true,
                                    );
                                  },
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildActionButton(
                                  icon: Icons.share_outlined,
                                  label: 'Share',
                                  color: Colors.black,
                                  onTap: () {
                                    sharePost(postId);
                                  },
                                ),
                                SizedBox(width: screenWidth * 0.03),
                                _buildActionButton(
                                  icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                                  label: isSaved ? "Saved" : "Save",
                                  color: Colors.black,
                                  onTap: () {
                                    ref.read(savedPostsProvider.notifier).toggleSavePost(userId, postId);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Caption and Username
                    if (post.caption != null && post.caption!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.lexendDeca(
                              color: Colors.black87,
                              fontSize: 14,
                              height: 1.4,
                            ),
                            children: [
                              TextSpan(
                                text: post.userUserName,
                                style: GoogleFonts.lexendDeca(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                              TextSpan(text: ' ${post.caption}'),
                            ],
                          ),
                        ),
                      ),

                    // Location
                    if (post.location != null && post.location!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.grey,
                            ),
                            SizedBox(width: screenWidth * 0.01),
                            Expanded(
                              child: RedHatText(
                                text: post.location!,
                                size: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: screenHeight * 0.02),

                    // Comment Input
                    Container(
                      padding: EdgeInsets.all(screenWidth * 0.04),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Colors.grey[200]!),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: screenWidth * 0.035,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: NetworkImage(FirebaseAuth.instance.currentUser?.photoURL ?? dummyImageUrl),
                          ),
                          SizedBox(width: screenWidth * 0.03),
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              decoration: InputDecoration(
                                hintText: 'Add a comment...',
                                hintStyle: GoogleFonts.lexendDeca(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          isLoading
                              ? LoadingWidget()
                              : IconButton(
                                  icon: const Icon(
                                    Icons.send,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
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
                                        postId: post.postId,
                                        userId: userId,
                                        content: content,
                                        id: commentId,
                                      );
                                      await sendNotification(
                                          type: 'comment',
                                          content: 'commented on your post: "$content"',
                                          target_user_id: post.userId,
                                          source_id: post.postId,
                                          sender_user_id: FirebaseAuth.instance.currentUser!.uid);

                                      _commentController.clear();

                                      // Increment the comment count
                                      ref.read(postCommentCountProvider(post.postId).notifier).increment();
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
            ],
          );
        },
      ),
    );
  }

  Widget _buildEngagementStat({
    required IconData icon,
    required String count,
    required Color color, // New: Dynamic color per stat type
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Colorful Icon with Shadow
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.8), color.withOpacity(1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(icon, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 6),

            // Count with a more vibrant style
            RedHatText(
              text: count,
              size: 16,
              isBold: true,
              color: color,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        backgroundColor: Colors.grey[100],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color ?? Colors.grey[700]),
          const SizedBox(width: 4),
          RedHatText(
            text: label,
            size: 14,
            color: color ?? Colors.grey.shade700,
            isBold: true,
          ),
        ],
      ),
    );
  }

  void sharePost(String postId) {
    final postUrl = 'TODOLINK!';
    Share.share(postUrl);
  }

  void likePost(WidgetRef ref, bool isLiked, int likeCount, String userId) {
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
