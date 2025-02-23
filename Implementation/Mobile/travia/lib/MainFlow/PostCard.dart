import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:travia/Helpers/DefaultText.dart';
import 'package:travia/Helpers/HelperMethods.dart';
import 'package:travia/MainFlow/HomePage.dart';
import 'package:travia/database/DatabaseMethods.dart';

import '../Providers/DatabaseProviders.dart';
import '../Providers/PostsLikesProvider.dart';
import 'CommentSheet.dart';

class PostCard extends StatelessWidget {
  final String? profilePicUrl;
  final String name;
  final String postImageUrl;
  final int commentCount;
  final String postId;
  final String userId;
  final int likeCount;

  const PostCard({
    super.key,
    required this.profilePicUrl,
    required this.name,
    required this.postImageUrl,
    required this.commentCount,
    required this.postId,
    required this.userId,
    required this.likeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final likeState = ref.watch(likePostProvider);
        final isLiked = likeState[postId] ?? false;
        final displayNumberOfLikes = ref.watch(postLikeCountProvider((postId: postId, initialLikeCount: likeCount)));

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Info Section
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.deepOrange,
                          width: 1,
                        ),
                      ),
                      child: ClipOval(
                        child: Image(
                          image: profilePicUrl != null ? NetworkImage(profilePicUrl!) : AssetImage(dummyDefaultUser) as ImageProvider,
                          fit: BoxFit.cover,
                          width: 50,
                          height: 50,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Text(
                            '2 minutes ago',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {},
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
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(postImageUrl),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              // Like, Comment, and Share Section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Like Button
                        GestureDetector(
                            onTap: () {
                              likePost(ref, isLiked);
                            },
                            child: Image.asset(
                              isLiked ? "assets/liked.png" : "assets/unliked.png",
                              width: 28,
                              height: 28,
                            )
                                .animate(target: isLiked ? 1 : 0)
                                .shake(
                                  hz: 8, // Number of shakes per second
                                  curve: Curves.easeOut,
                                  duration: 600.ms,
                                )
                                .fade(
                                  begin: 0.5,
                                  end: 2,
                                  duration: 700.ms,
                                )),
                        const SizedBox(width: 8),
                        DefaultText(
                          text: formatCount(displayNumberOfLikes),
                          isBold: true,
                          size: 16,
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          icon: const Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.grey,
                            size: 26,
                          ),
                          onPressed: () {
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
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${ref.watch(postCommentCountProvider(postId))}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    // Share Button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.send,
                              color: Colors.grey,
                              size: 20,
                            ),
                            onPressed: () {},
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Share',
                            style: TextStyle(
                              color: Colors.grey,
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

  void likePost(WidgetRef ref, bool isLiked) {
    String likerId = FirebaseAuth.instance.currentUser!.uid;
    ref.read(likePostProvider.notifier).toggleLike(
          postId: postId,
          likerId: likerId,
          posterId: userId,
        );
    ref.read(postLikeCountProvider((postId: postId, initialLikeCount: likeCount)).notifier).updateLikeCount(!isLiked);
    if (!isLiked) sendNotification(type: 'like', content: 'liked your post', target_user_id: userId, source_id: postId, sender_user_id: likerId);
  }
}
