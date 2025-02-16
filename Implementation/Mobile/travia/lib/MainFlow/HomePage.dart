import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:modular_ui/modular_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:travia/Helpers/Constants.dart';
import 'package:travia/Helpers/DefaultText.dart';
import 'package:travia/Helpers/DummyCards.dart';

import '../Authentacation/AuthMethods.dart';
import '../Providers/DatabaseProviders.dart';
import 'PostCard.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

final dummyImageUrl = "https://picsum.photos/200";
final dummyDefaultUser = "assets/defaultUser.png";
final currentlyLoggedInUserId = FirebaseAuth.instance.currentUser!.uid;

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    initHive();
    super.initState();
  }

  Future<void> initHive() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    await Hive.initFlutter();
    await Hive.openBox<Map<String, bool>>("liked_posts_$userId");
    await Hive.openBox<Map<String, bool>>("liked_comments_$userId");
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    print(user?.uid);
    print(user?.email);
    print(user?.photoURL);
    print(user?.displayName);

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Home",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: IconButton(
              icon: Icon(
                Icons.notifications_none,
                color: Colors.black,
                size: 28,
              ),
              onPressed: () {
                context.go("/notifications");
              },
            ),
          ),
        ],
      ),
      body: Container(
        color: backgroundColor,
        child: Column(
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
                        itemBuilder: (context, index) => DummyPostCard(),
                      ),
                    ),
                    error: (error, stackTrace) => Center(
                      child: DefaultText(
                        text: "Posts not available",
                        center: true,
                      ),
                    ),
                    data: (posts) => posts.isEmpty
                        ? Center(child: DefaultText(text: "No posts to show for now"))
                        : ListView.builder(
                            itemCount: posts.length,
                            itemBuilder: (context, index) => PostCard(
                              profilePicUrl: posts[index].userPhotoUrl,
                              name: posts[index].userDisplayName,
                              postImageUrl: posts[index].mediaUrl,
                              commentCount: posts[index].commentCount,
                              postId: posts[index].postId,
                              userId: posts[index].userId,
                              likeCount: posts[index].likeCount,
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
              },
            ),
          ],
        ),
      ),
    );
  }
}
