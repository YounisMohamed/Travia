import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:modular_ui/modular_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travia/Helpers/DummyCards.dart';
import 'package:travia/MainFlow/DMsPage.dart';
import 'package:travia/MainFlow/UploadPostPage.dart';
import 'package:travia/Providers/LoadingProvider.dart';

import '../Auth/AuthMethods.dart';
import '../Helpers/Loading.dart';
import '../Providers/PostsCommentsProviders.dart';
import '../Services/UserPresenceService.dart';
import '../database/DatabaseMethods.dart';
import '../main.dart';
import 'PostCard.dart';
import 'Story.dart';

class HomePage extends ConsumerStatefulWidget {
  final String? type;
  final String? source_id;
  const HomePage({super.key, this.type, this.source_id});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final user = FirebaseAuth.instance.currentUser;
  PageController pageController = PageController(
    initialPage: 1,
  );

  @override
  void initState() {
    super.initState();

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go("/signin");
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userPresenceServiceProvider).initialize();
    });

    final currentUserId = user!.uid;

    supabase
        .channel('public:stories')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'stories',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: currentUserId,
          ),
          callback: (payload) {},
        )
        .subscribe();
    supabase
        .channel('public:story_items')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'story_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: currentUserId,
          ),
          callback: (payload) {},
        )
        .subscribe();

    supabase
        .channel('public:conversation_participants')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversation_participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: currentUserId,
          ),
          callback: (payload) {},
        )
        .subscribe();
    supabase
        .channel('public:notifications')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'target_user_id',
              value: currentUserId,
            ),
            callback: (payload) {
              print('Change received: ${payload.toString()}');
            })
        .subscribe();
    supabase
        .channel('public:posts')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'posts',
            callback: (payload) {
              //print('Change received: ${payload.toString()}');
            })
        .subscribe();
    supabase.channel('public:comments').onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'comments', callback: (payload) {}).subscribe();

    fetchConversationIds(user!.uid).then((conversationIds) {
      supabase
          .channel('public:conversations')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'conversations',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.inFilter,
              column: 'conversation_id',
              value: conversationIds,
            ),
            callback: (payload) {},
          )
          .subscribe();
      supabase
          .channel('public:messages')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.inFilter,
              column: 'conversation_id',
              value: conversationIds,
            ),
            callback: (payload) {},
          )
          .subscribe();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.type != null && widget.source_id != null) {
        print("Navigating with type: ${widget.type}, source_id: ${widget.source_id}");
        String type = widget.type!;
        String source_id = widget.source_id!;
        if (type == "comment" || type == "post" || type == "like") {
          context.push("/post/$source_id");
        } else if (type == "message") {
          context.push("/messages/$source_id");
        }
      }
    });
  }

  @override
  void dispose() {
    supabase.channel('public:notifications').unsubscribe();
    supabase.channel('public:posts').unsubscribe();
    supabase.channel('public:comments').unsubscribe();
    supabase.channel('public:conversation_participants').unsubscribe();
    supabase.channel('public:messages').unsubscribe();
    supabase.channel('public:conversations').unsubscribe();
    supabase.channel('public:stories').unsubscribe();
    supabase.channel('public:story_items').unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: pageController.hasClients && (pageController.page?.round() == 1),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && pageController.hasClients && pageController.page?.round() != 1) {
          pageController.animateToPage(
            1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      child: PageView(
        controller: pageController,
        children: [
          UploadPostPage(),
          HomeWidget(),
          DMsPage(),
        ],
      ),
    );
  }
}

class HomeWidget extends ConsumerWidget {
  const HomeWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refresh() async {
      await Future.delayed(Duration(milliseconds: 300));
      Phoenix.rebirth(context);
    }

    bool isLoading = ref.watch(loadingProvider);
    final postsAsync = ref.watch(postsProvider);

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Text("Home"),
            SizedBox(width: 10),
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: LoadingWidget(),
              ),
          ],
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
      body: Column(
        children: [
          // Add the stories bar here
          StoryBar(),

          Divider(height: 1),

          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              displacement: 32,
              color: Colors.black,
              backgroundColor: Colors.white,
              child: postsAsync.when(
                loading: () => Skeletonizer(
                  enabled: true,
                  child: ListView.builder(
                    itemCount: 3,
                    itemBuilder: (context, index) => DummyPostCard(),
                  ),
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
                data: (posts) => posts.isEmpty
                    ? const Center(child: Text("No posts to show for now"))
                    : ListView.builder(
                        physics: AlwaysScrollableScrollPhysics(),
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          return GestureDetector(
                            onTap: () {
                              context.push('/post/${post.postId}');
                            },
                            child: PostCard(
                              profilePicUrl: post.userPhotoUrl,
                              username: post.userUserName,
                              postImageUrl: post.mediaUrl,
                              commentCount: post.commentCount,
                              postId: post.postId,
                              userId: post.userId,
                              likeCount: post.likeCount,
                              postCaption: post.caption,
                              postLocation: post.location,
                              createdAt: post.createdAt,
                            ),
                          );
                        },
                      ),
              ),
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
            ],
          )
        ],
      ),
    );
  }
}
