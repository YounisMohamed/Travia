import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:modular_ui/modular_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:travia/Helpers/Constants.dart';
import 'package:travia/Helpers/DefaultText.dart';

import '../Helpers/Icons.dart';
import '../Helpers/Methods.dart';
import '../Providers/LoadingProvider.dart';
import '../Providers/PostsProvider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final dummyImageUrl = "https://dummyimage.com/300";

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
                          index: index,
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
                        index: index,
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
                                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
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
  final int index;

  PostCard({
    Key? key,
    required this.profilePicUrl,
    required this.name,
    required this.postImageUrl,
    required this.likes,
    required this.comments,
    required this.index,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).primaryColor,
                      width: 2,
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
          Hero(
            tag: "${postImageUrl}_$index",
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(postImageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {},
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        child: likeIcon,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$likes',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 20),
                    IconButton(
                      icon: Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.grey,
                        size: 26,
                      ),
                      onPressed: () {
                        // TODO: FIX
                        showMaterialModalBottomSheet(
                          context: context,
                          builder: (context) => const CommentModal(),
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
  }
}

class CommentModal extends StatelessWidget {
  const CommentModal({Key? key}) : super(key: key);

  // Dummy comments data
  final List<Map<String, dynamic>> dummyComments = const [
    {
      "username": "Michael Chen",
      "profilePic": "https://dummyimage.com/100x100",
      "text": "Great shot! The composition is really interesting.",
      "timestamp": "4h ago",
      "likes": 12,
      "id": "1",
    },
    {
      "username": "Sarah Johnson",
      "profilePic": "https://dummyimage.com/100x100/ffcc00/ffffff",
      "text": "Love the colors in this photo!",
      "timestamp": "3h ago",
      "likes": 8,
      "id": "2",
    },
    {
      "username": "David Lee",
      "profilePic": "https://dummyimage.com/100x100/00ffcc/ffffff",
      "text": "Absolutely stunning! What camera did you use?",
      "timestamp": "2h ago",
      "likes": 15,
      "id": "3",
    },
  ];

  @override
  Widget build(BuildContext context) {
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
              // Header

              // Divider
              const Divider(height: 1, thickness: 1),

              // Comments List
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(), // Enable smooth scrolling
                  itemCount: dummyComments.length,
                  itemBuilder: (context, index) {
                    final comment = dummyComments[index];
                    return ListTile(
                      leading: Hero(
                        tag: '${comment["profilePic"]}_$index',
                        child: CircleAvatar(
                          backgroundImage: NetworkImage(comment["profilePic"]),
                        ),
                      ),
                      title: Text(
                        comment["username"],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(comment["text"]),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                comment["timestamp"],
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "${comment["likes"]} likes",
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.favorite_border, color: Colors.red),
                        onPressed: () {},
                      ),
                    );
                  },
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
                      onPressed: () {},
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
