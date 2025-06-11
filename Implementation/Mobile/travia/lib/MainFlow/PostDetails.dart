import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:travia/MainFlow/MediaPreview.dart';

import '../Classes/Post.dart';
import '../Helpers/AppColors.dart';
import '../Helpers/GoogleTexts.dart';
import '../Helpers/HelperMethods.dart';
import '../Helpers/PopUp.dart';
import '../Providers/LoadingProvider.dart';
import '../Providers/PostsCommentsProviders.dart';
import '../Providers/PostsLikesProvider.dart';
import '../Providers/SavedPostsProvider.dart';
import '../database/DatabaseMethods.dart';
import 'CommentSheet.dart';
import 'ReportsPage.dart';

class PostDetailsPage extends ConsumerWidget {
  final String postId;

  PostDetailsPage({
    super.key,
    required this.postId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(postsProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final isLoading = ref.watch(loadingProvider);
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final savedState = ref.watch(savedPostsProvider);
    final isSaved = savedState[postId] ?? false;
    final commentsAsync = ref.watch(commentsProvider(postId));

    final likeState = ref.watch(likePostProvider);

    Future.microtask(() async {
      await addViewedPost(userId, postId);
    });

    return Scaffold(
      backgroundColor: kBackground,
      body: postsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            color: kDeepPink,
          ),
        ),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: kDeepPink),
              SizedBox(height: 16),
              Text(
                'Oops! Something went wrong',
                style: GoogleFonts.lexendDeca(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                error.toString(),
                style: GoogleFonts.lexendDeca(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        data: (posts) {
          final post = posts.firstWhere((p) => p.postId == postId, orElse: () {
            return Post(
              postId: "",
              createdAt: DateTime.now(),
              userId: "",
              commentCount: 0,
              likesCount: 0,
              dislikesCount: 0,
              location: "",
              mediaUrl: "",
              userPhotoUrl: "",
              userUserName: "",
              viewCount: 0,
            );
          });

          if (post.postId == "") {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.go("/home");
              }
            });
            return const SizedBox.shrink();
          }
          final reaction = likeState[postId]; // 'like', 'dislike', or null
          final reactionCount = ref.watch(postReactionCountProvider((
            postId: postId,
            likes: post.likesCount,
            dislikes: post.dislikesCount,
          )));
          print("POSTER OF ${postId} is ${post.userId}");

          return CustomScrollView(
            slivers: [
              // Custom App Bar
              SliverAppBar(
                backgroundColor: kBackground,
                forceMaterialTransparency: true,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.black87, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                title: InkWell(
                  onTap: () {
                    context.push("/profile/${post.userId}");
                  },
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [kDeepPinkLight, kDeepPink],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: screenWidth * 0.045,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: screenWidth * 0.04,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: NetworkImage(post.userPhotoUrl),
                          ),
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.025),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              post.userUserName,
                              style: GoogleFonts.lexendDeca(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (post.location != null && post.location!.isNotEmpty)
                              Text(
                                post.location!,
                                style: GoogleFonts.lexendDeca(
                                  fontSize: 12,
                                  color: kDeepPink,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  Container(
                    margin: EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Container(
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
                          if (post.userId == userId)
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
                        icon: const Icon(Icons.more_vert, color: Colors.black),
                        offset: const Offset(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
                pinned: true,
                expandedHeight: 80,
              ),

              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Post Media with rounded corners
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: GestureDetector(
                            onDoubleTap: () {
                              ref.read(likePostProvider.notifier).toggleReaction(
                                    postId: postId,
                                    likerId: userId,
                                    posterId: post.userId,
                                    reactionType: 'like',
                                  );

                              ref
                                  .read(postReactionCountProvider((postId: postId, likes: post.likesCount, dislikes: post.dislikesCount)).notifier)
                                  .updateReaction(from: reaction, to: reaction == 'like' ? null : 'like');

                              if (reaction != 'like' && canSendNotification(postId, 'like', userId)) {
                                sendNotification(
                                  type: "like",
                                  title: "",
                                  content: userId == post.userId ? "liked his own post" : "liked your post",
                                  target_user_id: post.userId,
                                  source_id: postId,
                                  sender_user_id: userId,
                                );
                              }
                            },
                            child: MediaPostPreview(
                              mediaUrl: post.mediaUrl,
                              isVideo: isPathVideo(post.mediaUrl),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Action Buttons
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.04,
                        vertical: screenHeight * 0.02,
                      ),
                      child: Row(
                        children: [
                          // Like Button
                          _buildActionButton(
                            icon: reaction == 'like' ? CupertinoIcons.hand_thumbsup_fill : CupertinoIcons.hand_thumbsup,
                            color: kDeepPinkLight.withOpacity(0.75),
                            count: reactionCount['likes'] ?? 0,
                            onTap: () async {
                              ref.read(likePostProvider.notifier).toggleReaction(
                                    postId: postId,
                                    likerId: userId,
                                    posterId: post.userId,
                                    reactionType: 'like',
                                  );

                              ref
                                  .read(postReactionCountProvider((postId: postId, likes: post.likesCount, dislikes: post.dislikesCount)).notifier)
                                  .updateReaction(from: reaction, to: reaction == 'like' ? null : 'like');

                              if (reaction != 'like' && canSendNotification(postId, 'like', userId)) {
                                sendNotification(
                                  type: "like",
                                  title: "",
                                  content: userId == post.userId ? "liked his own post" : "liked your post",
                                  target_user_id: post.userId,
                                  source_id: postId,
                                  sender_user_id: userId,
                                );
                              }
                            },
                          ),
                          SizedBox(width: screenWidth * 0.04),

                          // Dislike Button
                          _buildActionButton(
                            icon: reaction == 'dislike' ? CupertinoIcons.hand_thumbsdown_fill : CupertinoIcons.hand_thumbsdown,
                            color: kDeepPinkLight.withOpacity(0.75),
                            count: reactionCount['dislikes'] ?? 0,
                            onTap: () async {
                              ref.read(likePostProvider.notifier).toggleReaction(
                                    postId: postId,
                                    likerId: userId,
                                    posterId: post.userId,
                                    reactionType: 'dislike',
                                  );

                              ref
                                  .read(postReactionCountProvider((postId: postId, likes: post.likesCount, dislikes: post.dislikesCount)).notifier)
                                  .updateReaction(from: reaction, to: reaction == 'like' ? null : 'like');

                              if (reaction != 'dislike' && canSendNotification(postId, 'dislike', userId)) {
                                sendNotification(
                                  type: "dislike",
                                  title: "",
                                  content: userId == post.userId ? "disliked his own post" : "disliked your post",
                                  target_user_id: post.userId,
                                  source_id: postId,
                                  sender_user_id: userId,
                                );
                              }
                            },
                          ),
                          SizedBox(width: screenWidth * 0.04),

                          // Comment Button
                          _buildActionButton(
                            icon: CupertinoIcons.chat_bubble,
                            color: kDeepPinkLight.withOpacity(0.75),
                            count: ref.watch(postCommentCountProvider(postId)),
                            onTap: () {
                              showMaterialModalBottomSheet(
                                  context: context,
                                  builder: (context) => CommentModal(
                                        postId: postId,
                                        posterId: post.userId,
                                      ));
                            },
                          ),
                          SizedBox(width: screenWidth * 0.04),

                          // Share Button
                          _buildActionButton(
                            icon: Icons.share_outlined,
                            color: kDeepPinkLight.withOpacity(0.75),
                            onTap: () {
                              sharePost(postId: post.postId);
                            },
                          ),

                          Spacer(),

                          // Save Button
                          Container(
                            decoration: BoxDecoration(
                              color: isSaved ? kDeepPink.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: Icon(
                                isSaved ? Icons.bookmark : Icons.bookmark_border,
                                color: kDeepPinkLight.withOpacity(0.75),
                                size: 24,
                              ),
                              onPressed: () async {
                                ref.read(savedPostsProvider.notifier).toggleSavePost(userId, postId);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Views Count
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                      child: Text(
                        '${post.viewCount} views',
                        style: GoogleFonts.lexendDeca(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // Caption
                    if (post.caption != null && post.caption!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: GoogleFonts.lexendDeca(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  height: 1.5,
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
                                  TextSpan(text: '  ${post.caption}'),
                                ],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              timeAgo(post.createdAt),
                              style: GoogleFonts.lexendDeca(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Comments Preview
                    if (commentsAsync.hasValue && commentsAsync.value!.isNotEmpty)
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        decoration: BoxDecoration(
                          color: kBackground,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Comments',
                                  style: GoogleFonts.lexendDeca(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    showMaterialModalBottomSheet(
                                        context: context,
                                        builder: (context) => CommentModal(
                                              postId: postId,
                                              posterId: post.userId,
                                            ));
                                  },
                                  child: Text(
                                    'View all',
                                    style: GoogleFonts.lexendDeca(
                                      fontSize: 13,
                                      color: kDeepPink,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            ...commentsAsync.value!.take(3).map((comment) {
                              return Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      child: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Colors.grey.shade300,
                                        backgroundImage: NetworkImage(comment.userPhotoUrl),
                                      ),
                                      onTap: () {
                                        context.push("/profile/${comment.userId}");
                                      },
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          GestureDetector(
                                            child: Text(
                                              comment.userUsername,
                                              style: GoogleFonts.lexendDeca(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            onTap: () {
                                              context.push("/profile/${comment.userId}");
                                            },
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            comment.content.length > 50 ? "${comment.content.substring(0, 50)}..." : comment.content,
                                            style: GoogleFonts.lexendDeca(
                                              fontSize: 13,
                                              color: Colors.black87,
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),

                    SizedBox(height: screenHeight * 0.1),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    int? count,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            if (count != null && count > 0) ...[
              SizedBox(width: 6),
              Text(
                formatCount(count),
                style: GoogleFonts.lexendDeca(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void sharePost({required String postId}) {
    final postUrl = 'NO_DOMAIN_YET_:)';
    Share.share(
      'Check out this amazing travel post on Travia! $postUrl',
      subject: 'Travia Post',
    );
  }
}
