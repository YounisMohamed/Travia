import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:travia/Helpers/Loading.dart';
import 'package:travia/MainFlow/MediaPreview.dart';
import 'package:uuid/uuid.dart';

import '../Classes/Post.dart';
import '../Helpers/GoogleTexts.dart';
import '../Helpers/PopUp.dart';
import '../Providers/LoadingProvider.dart';
import '../Providers/PostsCommentsProviders.dart';
import '../Providers/SavedPostsProvider.dart';
import '../database/DatabaseMethods.dart';

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

    final isLoading = ref.watch(loadingProvider);
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final savedState = ref.watch(savedPostsProvider);
    final isSaved = savedState[postId] ?? false;
    final commentsAsync = ref.watch(commentsProvider(postId));
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

          return CustomScrollView(
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
                      child: GestureDetector(
                        onDoubleTap: () {},
                        child: MediaPostPreview(
                          mediaUrl: post.mediaUrl,
                          isVideo: post.mediaUrl.endsWith('.mp4') || post.mediaUrl.endsWith('.mov'),
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
                            backgroundImage: NetworkImage(post.userPhotoUrl),
                          ),
                          SizedBox(width: screenWidth * 0.03),
                          Expanded(
                            child: TextField(
                              autofocus: false,
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
                                          title: "commented on your post",
                                          type: 'comment',
                                          content: content,
                                          target_user_id: post.userId,
                                          source_id: post.postId,
                                          sender_user_id: FirebaseAuth.instance.currentUser!.uid);

                                      _commentController.clear();
                                    } catch (e) {
                                      Popup.showError(text: "Error adding comment", context: context);
                                    } finally {
                                      ref.read(loadingProvider.notifier).setLoadingToFalse();
                                    }
                                  },
                                ),
                        ],
                      ),
                    ),
                    // Last Two comments:
                    SizedBox(height: screenHeight * 0.01),
                    ref.watch(commentsProvider(post.postId)).when(
                          data: (comments) {
                            comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                            final lastComments = comments.length >= 2 ? comments.sublist(comments.length - 2) : comments;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: lastComments.map((comment) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.005),
                                  child: RichText(
                                    text: TextSpan(
                                      style: GoogleFonts.lexendDeca(
                                        color: Colors.black87,
                                        fontSize: 13,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: comment.userUsername,
                                          style: GoogleFonts.lexendDeca(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        TextSpan(text: ' ${comment.content}'),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                          loading: () => SizedBox.shrink(),
                          error: (err, stack) => SizedBox.shrink(),
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

  void sharePost({required String postId}) {
    final postUrl = 'TODOLINK!';
    Share.share(postUrl);
  }
}
