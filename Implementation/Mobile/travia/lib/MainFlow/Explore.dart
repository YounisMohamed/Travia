import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:travia/Helpers/AppColors.dart';

import '../Classes/Post.dart';
import '../Helpers/DummyCards.dart';
import '../Helpers/GoogleTexts.dart';
import '../Helpers/HelperMethods.dart';
import '../Helpers/Loading.dart';
import '../Providers/LoadingProvider.dart';
import '../Providers/PostsCommentsProviders.dart';
import '../Providers/PostsLikesProvider.dart';
import '../Providers/SavedPostsProvider.dart';
import '../database/DatabaseMethods.dart';
import 'CommentSheet.dart';
import 'MediaPreview.dart';

class ExplorePage extends ConsumerWidget {
  const ExplorePage({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refresh() async {
      await Future.delayed(Duration(milliseconds: 300));
      Phoenix.rebirth(context);
    }

    bool isLoading = ref.watch(loadingProvider);
    final postsAsync = ref.watch(postsProvider);

    // Create custom swipe gesture handlers for the Home screen
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          elevation: 0,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Image.asset(
                "assets/TraviaLogo.png",
                height: 90,
                width: 90,
              ),
              Container(
                height: 24,
                width: 2,
                color: Colors.grey,
                margin: EdgeInsets.symmetric(horizontal: 8),
              ),
              Expanded(
                child: TypewriterAnimatedText(
                  text: "Plan Smart. Travel Far.",
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: LoadingWidget(),
                ),
            ],
          ),
        ),
        body: Container(
          child: RefreshIndicator(
            onRefresh: refresh,
            displacement: 32,
            color: Colors.black,
            backgroundColor: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
                  child: Text(
                    "Explore",
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kDeepPink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: Text(
                          "For You",
                          style: GoogleFonts.ibmPlexSans(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black54,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: Text(
                          "Following",
                          style: GoogleFonts.ibmPlexSans(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {},
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Icon(CupertinoIcons.plus, size: 20),
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.search, size: 24),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: postsAsync.when(
                    loading: () => Skeletonizer(
                      enabled: true,
                      child: _dummyPosts(),
                    ),
                    error: (error, stackTrace) {
                      print(error);
                      print(stackTrace);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (context.mounted) {
                          context.go("/error-page/${Uri.encodeComponent(error.toString())}/${Uri.encodeComponent("/")}");
                        }
                      });
                      return const Center(child: Text("An error occurred."));
                    },
                    data: (posts) {
                      if (posts.isEmpty) {
                        return const Center(child: Text("No posts to show for now"));
                      } else {
                        return _buildFeed(context, posts);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dummyPosts() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemCount: 3,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return ExplorePostCardSkeleton();
      },
    );
  }

  Widget _buildFeed(BuildContext context, List<Post> posts) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemCount: posts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final post = posts[index];
        return ExplorePostCard(
          username: post.userUserName,
          profileImage: post.userPhotoUrl,
          mediaUrl: post.mediaUrl,
          postDescription: post.caption,
          likes: post.likesCount,
          dislikes: post.dislikesCount,
          comments: post.commentCount,
          time: timeAgo(post.createdAt),
          postId: post.postId,
          userId: post.userId,
        );
      },
    );
  }
}

class ExplorePostCard extends ConsumerWidget {
  final String username;
  final String profileImage;
  final String mediaUrl;
  final String? postDescription;
  final int likes;
  final int dislikes;
  final int comments;
  final String time;
  final String postId;
  final String userId;

  const ExplorePostCard(
      {Key? key,
      required this.username,
      required this.profileImage,
      required this.mediaUrl,
      this.postDescription,
      required this.likes,
      required this.dislikes,
      required this.comments,
      required this.time,
      required this.postId,
      required this.userId})
      : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, child) {
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final likeState = ref.watch(likePostProvider);
        final reaction = likeState[postId];
        final reactionCount = ref.watch(postReactionCountProvider((
          postId: postId,
          likes: likes,
          dislikes: dislikes,
        )));
        final savedState = ref.watch(savedPostsProvider);
        final isSaved = savedState[postId] ?? false;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                spreadRadius: 0,
                blurRadius: 25,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.25),
                      Colors.white.withOpacity(0.1),
                    ],
                    stops: const [0.1, 1.0],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top section with gradient background
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.black87.withOpacity(0.85),
                            kDeepPink.withOpacity(0.85),
                          ],
                          stops: const [0.3, 1.0],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.white.withOpacity(0.15),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Profile section
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          context.push("/profile/${userId}");
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.6),
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.2),
                                                spreadRadius: 0,
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: CircleAvatar(
                                            radius: 22,
                                            backgroundColor: Colors.white.withOpacity(0.2),
                                            backgroundImage: CachedNetworkImageProvider(profileImage),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                context.push("/profile/${userId}");
                                              },
                                              child: Text(
                                                username,
                                                style: GoogleFonts.ibmPlexSans(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              time,
                                              style: GoogleFonts.ibmPlexSans(
                                                color: Colors.white.withOpacity(0.7),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.1),
                                            width: 1,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                            child: IconButton(
                                              onPressed: () {},
                                              icon: Icon(
                                                Icons.more_horiz,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              splashRadius: 20,
                                              padding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Post description section
                                if (postDescription != null && postDescription!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                    child: ExpandableText(
                                      text: postDescription!,
                                      postId: postId,
                                      maxLines: 3,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Media section
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.03),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                      child: ExplorePostMediaDisplay(
                        mediaUrl: mediaUrl,
                        isVideo: mediaUrl.endsWith('.mp4') || mediaUrl.endsWith('.mov'),
                      ),
                    ),

                    // Actions section
                    ClipRRect(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(24),
                              bottomRight: Radius.circular(24),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    _buildGlassActionButton(
                                        color: kDeepPink,
                                        icon: reaction == 'like' ? CupertinoIcons.hand_thumbsup_fill : CupertinoIcons.hand_thumbsup,
                                        count: '${reactionCount['likes'] ?? 0}',
                                        onTap: () {
                                          print("PRESSED");
                                          ref.read(likePostProvider.notifier).toggleReaction(
                                                postId: postId,
                                                likerId: currentUserId!,
                                                posterId: userId,
                                                reactionType: 'like',
                                              );

                                          ref
                                              .read(postReactionCountProvider((postId: postId, likes: likes, dislikes: dislikes)).notifier)
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
                                        }),
                                    const SizedBox(width: 20),
                                    _buildGlassActionButton(
                                        icon: reaction == 'dislike' ? CupertinoIcons.hand_thumbsdown_fill : CupertinoIcons.hand_thumbsdown,
                                        count: '${reactionCount['dislikes'] ?? 0}',
                                        color: Colors.grey.shade700,
                                        onTap: () {
                                          print("PRESSED");
                                          ref.read(likePostProvider.notifier).toggleReaction(
                                                postId: postId,
                                                likerId: currentUserId!,
                                                posterId: userId,
                                                reactionType: 'dislike',
                                              );

                                          ref
                                              .read(postReactionCountProvider((postId: postId, likes: likes, dislikes: dislikes)).notifier)
                                              .updateReaction(from: reaction, to: reaction == 'dislike' ? null : 'dislike');

                                          if (reaction != 'like' && canSendNotification(postId, 'dislike', currentUserId!)) {
                                            sendNotification(
                                              type: "dislike",
                                              title: "",
                                              content: currentUserId == userId ? "disliked his own post" : "disliked your post",
                                              target_user_id: userId,
                                              source_id: postId,
                                              sender_user_id: currentUserId,
                                            );
                                          }
                                        }),
                                    const SizedBox(width: 20),
                                    _buildGlassActionButton(
                                        icon: CupertinoIcons.chat_bubble,
                                        count: '${ref.watch(postCommentCountProvider(postId))}',
                                        color: Colors.grey.shade700,
                                        onTap: () {
                                          showMaterialModalBottomSheet(
                                              context: context,
                                              builder: (context) => CommentModal(
                                                    postId: postId,
                                                    posterId: userId,
                                                  ));
                                        }),
                                  ],
                                ),
                                _buildBookmarkButton(
                                    onTap: () {
                                      ref.read(savedPostsProvider.notifier).toggleSavePost(userId, postId);
                                    },
                                    icon: isSaved ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlassActionButton({required IconData icon, required String count, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(
              count,
              style: GoogleFonts.ibmPlexSans(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

// Glass effect bookmark button
  Widget _buildBookmarkButton({required VoidCallback onTap, required IconData icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.25),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: IconButton(
              onPressed: () {},
              icon: Icon(
                icon,
                size: 18,
                color: Colors.grey.shade700,
              ),
              splashRadius: 18,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}

class ExpandableText extends ConsumerWidget {
  final String text;
  final String postId;
  final int maxLines;

  const ExpandableText({
    Key? key,
    required this.text,
    required this.postId,
    this.maxLines = 5,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the expanded state from the provider
    final isExpanded = ref.watch(expandedStateProvider(postId));

    // Create text span to check if we need "Read More"
    final TextSpan textSpan = TextSpan(
      text: text,
      style: GoogleFonts.ibmPlexSans(
        fontSize: 15,
        color: Colors.white.withOpacity(0.9),
        height: 1.4,
        letterSpacing: 0.2,
      ),
    );

    // Text painter to check if text overflows
    final TextPainter textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
    );

    // Layout to check if text will overflow
    textPainter.layout(maxWidth: MediaQuery.of(context).size.width - 64);
    final bool hasOverflow = textPainter.didExceedMaxLines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 15,
            color: Colors.white.withOpacity(0.9),
            height: 1.4,
            letterSpacing: 0.2,
          ),
          maxLines: isExpanded ? null : maxLines,
          overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (hasOverflow)
          Container(
            margin: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () {
                // Update the state using Riverpod
                ref.read(expandedStateProvider(postId).notifier).state = !isExpanded;
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isExpanded ? "Show Less" : "Read More",
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isExpanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                          size: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

final expandedStateProvider = StateProvider.family<bool, String>((ref, postId) => false);
