import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:modular_ui/modular_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:travia/Helpers/Constants.dart';
import 'package:travia/Helpers/DefaultText.dart';
import 'package:travia/Helpers/HelperMethods.dart';

import '../Authentacation/AuthMethods.dart';
import '../Providers/DatabaseProviders.dart';
import '../Providers/LoadingProvider.dart';
import '../database/FetchingMethods.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final dummyImageUrl = "https://picsum.photos/200";

  @override
  Widget build(BuildContext context) {
    final _isLoading = ref.watch(loadingProvider);

    return Container(
      color: backgroundColor,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: Column(
          children: [
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final postsAsync = ref.watch(postsProvider);
                  return postsAsync.when(
                    loading: () => Skeletonizer(
                      enabled: true,
                      child: ListView.builder(
                        itemCount: 3,
                        itemBuilder: (context, index) => PostCard(
                          profilePicUrl: dummyImageUrl,
                          name: "",
                          postImageUrl: dummyImageUrl,
                          likes: 0,
                          comments: 0,
                          postId: "",
                          userId: "",
                        ),
                      ),
                    ),
                    error: (error, stackTrace) => Center(
                      child: DefaultText(text: "You may not have stable internet connection"),
                    ),
                    data: (posts) => ListView.builder(
                      itemCount: posts.length,
                      itemBuilder: (context, index) => PostCard(
                        profilePicUrl: posts[index].userPhotoUrl ?? dummyImageUrl,
                        name: posts[index].userDisplayName,
                        postImageUrl: posts[index].mediaUrl,
                        likes: posts[index].likeCount,
                        comments: posts[index].commentCount,
                        postId: posts[index].postId,
                        userId: posts[index].userId,
                      ),
                    ),
                  );
                },
              ),
            ),
            MUIGradientButton(
                text: "Sign out",
                onPressed: () async {
                  await signOut(context, ref);
                }),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Your Friends",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "67 friends online",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: 140,
                    height: 40,
                    child: Stack(
                      children: [
                        for (var i = 0; i < 3; i++)
                          Positioned(
                            left: i * 30.0,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundImage: i < 2 ? NetworkImage(dummyImageUrl) : null,
                                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                child: i == 2
                                    ? Text(
                                        "65+",
                                        style: TextStyle(
                                          color: Theme.of(context).primaryColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
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
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  final String profilePicUrl;
  final String name;
  final String postImageUrl;
  final int likes;
  final int comments;
  final String postId;
  final String userId;

  PostCard({
    Key? key,
    required this.profilePicUrl,
    required this.name,
    required this.postImageUrl,
    required this.likes,
    required this.comments,
    required this.postId,
    required this.userId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final likeState = ref.watch(likeProvider);
        final isLiked = likeState[postId] ?? false;

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
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.deepOrange,
                          width: 1,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundImage: NetworkImage(profilePicUrl),
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
                  ref.read(likeProvider.notifier).toggleLike(postId);
                  updateLikeInDatabase(userId, postId, !isLiked);
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
                            ref.read(likeProvider.notifier).toggleLike(postId);
                            updateLikeInDatabase(userId, postId, !isLiked);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 1000),
                            child: Image.asset(
                              isLiked ? "assets/liked.png" : "assets/unliked.png",
                              width: 28,
                              height: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${likes + (isLiked ? 1 : 0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 20),

                        // Comment Button
                        IconButton(
                          icon: const Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.grey,
                            size: 26,
                          ),
                          onPressed: () {
                            // TODO: FIX
                            showMaterialModalBottomSheet(
                              context: context,
                              builder: (context) => CommentModal(
                                postId: postId,
                              ),
                              backgroundColor: Colors.transparent,
                              bounce: true,
                              enableDrag: true,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$comments',
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
                        children: const [
                          Icon(
                            Icons.send,
                            color: Colors.grey,
                            size: 20,
                          ),
                          SizedBox(width: 4),
                          Text(
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
}

class CommentModal extends ConsumerWidget {
  final String postId; // Receive postId from PostCard
  const CommentModal({Key? key, required this.postId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(commentsProvider(postId));
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: DefaultText(
            text: "Comments",
            size: 19,
          ),
          automaticallyImplyLeading: false,
          forceMaterialTransparency: true,
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 15),
              child: IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: Icon(Icons.close),
                iconSize: 26,
              ),
            ),
          ],
        ),
        resizeToAvoidBottomInset: true,
        body: Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Divider
              const Divider(height: 1, thickness: 1),
              // Comments List
              Expanded(
                child: commentsAsync.when(
                  loading: () => Skeletonizer(
                    enabled: true,
                    child: ListView.builder(
                      itemCount: 10,
                      itemBuilder: (context, index) => CommentCard(
                        content: "",
                        createdAt: "",
                        likeCount: 0,
                        userName: "",
                        userPhotoUrl: "",
                      ),
                    ),
                  ),
                  error: (error, stackTrace) => Center(
                    child: Text("Error loading comments"),
                  ),
                  data: (comments) => ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      return CommentCard(
                        userName: comment.userName,
                        userPhotoUrl: comment.userPhotoUrl,
                        content: comment.content,
                        createdAt: timeAgo(comment.createdAt), // ex: 45 minutes ago
                        likeCount: comment.likeCount,
                      );
                    },
                  ),
                ),
              ),
              // Input Field
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Add a comment...",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.blue),
                      onPressed: () {
                        // Add send comment functionality here
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
  final int likeCount;

  const CommentCard({
    Key? key,
    required this.userName,
    required this.userPhotoUrl,
    required this.content,
    required this.createdAt,
    required this.likeCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: NetworkImage(userPhotoUrl),
      ),
      title: Text(
        userName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(content),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                createdAt,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(width: 8),
              Text(
                "$likeCount likes",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.favorite_border, color: Colors.red),
        onPressed: () {
          // TODO: Like functionality
        },
      ),
    );
  }
}
