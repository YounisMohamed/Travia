import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modular_ui/modular_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travia/Helpers/Constants.dart';
import 'package:travia/Helpers/DummyCards.dart';

import '../Authentacation/AuthMethods.dart';
import '../Providers/DatabaseProviders.dart';
import '../main.dart';
import 'PostCard.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

final dummyImageUrl = "https://picsum.photos/200";
final dummyDefaultUser = "assets/defaultUser.png";

class _HomePageState extends ConsumerState<HomePage> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    if (user == null) {
      context.go("/signin");
    }
    supabase
        .channel('public:notifications')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            callback: (payload) {
              print('Change received: ${payload.toString()}');
            })
        .subscribe();
    supabase
        .channel('public:comments')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'comments',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: user!.uid,
            ),
            callback: (payload) {
              print('Change received: ${payload.toString()}');
            })
        .subscribe();
    print(user?.uid);
    print(user?.email);
    print(user?.photoURL);
    print(user?.displayName);
    print("------------");
    super.initState();
  }

  @override
  void dispose() {
    supabase.channel('public:notifications').unsubscribe();
    supabase.channel('public:comments').unsubscribe();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                context.push("/notifications");
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
                    error: (error, stackTrace) => const Center(
                      child: Text(
                        "Posts not available",
                        textAlign: TextAlign.center,
                      ),
                    ),
                    data: (posts) => posts.isEmpty
                        ? const Center(child: Text("No posts to show for now"))
                        : ListView.builder(
                            itemCount: posts.length,
                            itemBuilder: (context, index) {
                              final post = posts[index];
                              return GestureDetector(
                                onTap: () {
                                  context.push('/post/${post.postId}');
                                },
                                child: PostCard(
                                  profilePicUrl: post.userPhotoUrl,
                                  name: post.userDisplayName,
                                  postImageUrl: post.mediaUrl,
                                  commentCount: post.commentCount,
                                  postId: post.postId,
                                  userId: post.userId,
                                  likeCount: post.likeCount,
                                ),
                              );
                            },
                          ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                MUIGradientButton(
                  text: "Sign out",
                  onPressed: () async {
                    await signOut(context, ref);
                  },
                  bgGradient: LinearGradient(colors: [Colors.black, Colors.black]),
                ),
                SizedBox(
                  width: 15,
                ),
                MUIGradientButton(
                  text: "Update profile",
                  onPressed: () {
                    context.push("/complete-profile");
                  },
                  bgGradient: LinearGradient(colors: [Colors.black, Colors.black]),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
