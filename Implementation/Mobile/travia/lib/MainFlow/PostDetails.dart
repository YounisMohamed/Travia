import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:travia/MainFlow/MediaPreview.dart';

import '../Classes/Post.dart';
import '../Helpers/AppColors.dart';
import '../Helpers/GoogleTexts.dart';
import '../Helpers/HelperMethods.dart';
import '../Providers/LoadingProvider.dart';
import '../Providers/PostsCommentsProviders.dart';
import '../Providers/PostsLikesProvider.dart';
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
    final likeState = ref.watch(likePostProvider);
    final isLiked = likeState[postId] ?? false;
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
              mediaUrl: "",
              userPhotoUrl: "",
              userUserName: "",
              viewCount: 0,
              location: '',
              likesCount: 0,
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

          return Container(
            color: Colors.white,
            child: SafeArea(
              child: Column(
                children: [
                  // Header with back button and user info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Back button
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.arrow_back_ios,
                            color: kDeepPink,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // User profile picture
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(post.userPhotoUrl),
                        ),
                        const SizedBox(width: 12),

                        // Username and time
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.userUserName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                timeAgo(post.createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Post caption
                  if (post.caption != null && post.caption!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          post.caption!,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),

                  // Post image
                  SizedBox(
                    width: screenWidth,
                    height: screenHeight * 0.3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: MediaPostPreview(
                        mediaUrl: post.mediaUrl,
                        isVideo: post.mediaUrl.endsWith('.mp4') || post.mediaUrl.endsWith('.mov'),
                      ),
                    ),
                  ),

                  // Likes, dislikes, comments counter
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Like button and count
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                // Like functionality will be added later
                              },
                              child: Icon(
                                isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                                color: isLiked ? kDeepPink : Colors.black,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              post.likesCount.toString(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),

                        // Dislike button and count
                        Row(
                          children: [
                            const Icon(Icons.thumb_down_outlined),
                            const SizedBox(width: 8),
                            Text(
                              "54", // This is hardcoded as per your image
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),

                        // Comments button and count
                        Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline),
                            const SizedBox(width: 8),
                            Text(
                              post.commentCount.toString(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  const Divider(height: 1),

                  // Comments section
                  Expanded(
                    child: commentsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (error, stack) => Center(child: Text('Error loading comments: $error')),
                        data: (comments) {
                          if (comments.isEmpty) {
                            return const Center(child: Text('No comments yet'));
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: comments.length,
                            itemBuilder: (context, index) {
                              final comment = comments[index];
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Commenter profile picture
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundImage: NetworkImage(comment.userPhotoUrl),
                                    ),
                                    const SizedBox(width: 12),

                                    // Comment content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            comment.userUsername,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            comment.content,
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        }),
                  ),

                  // Comment input box at bottom
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: kDeepPink,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      width: double.infinity,
                      child: const Center(
                        child: Text(
                          "Write a comment...",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
