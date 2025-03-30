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
import 'package:travia/MainFlow/UploadPost.dart';
import 'package:travia/Providers/LoadingProvider.dart';
import 'package:travia/Services/NotificationService.dart';

import '../Auth/AuthMethods.dart';
import '../Helpers/Loading.dart';
import '../Providers/PostsCommentsProviders.dart';
import '../Services/UserPresenceService.dart';
import '../database/DatabaseMethods.dart';
import '../main.dart';
import 'PostCard.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

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
          callback: (payload) {
            /*
            print('conversation_participants channel: Change received');
            print('conversation_participants channel: Event type: ${payload.eventType}');
            print('conversation_participants channel: Errors: ${payload.errors}');
            print('conversation_participants channel: Table: ${payload.table}');
            print('conversation_participants channel: toString(): ${payload.toString()}');


             */
          },
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
    supabase
        .channel('public:comments')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'comments',
            callback: (payload) {
              //print('Change received: ${payload.toString()}');
            })
        .subscribe();

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
            callback: (payload) {
              /*
              print('conversations channel: Change received');
              print('conversations channel: Event type: ${payload.eventType}');
              print('conversations channel: Errors: ${payload.errors}');
              print('conversations channel: Table: ${payload.table}');
              print('conversations channel: toString(): ${payload.toString()}');
              */
            },
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
            callback: (payload) {
              /*
              print('messages channel: Change received');
              print('messages channel: Event type: ${payload.eventType}');
              print('messages channel: Errors: ${payload.errors}');
              print('messages channel: Table: ${payload.table}');
              print('messages channel: toString(): ${payload.toString()}');

               */
            },
          )
          .subscribe();
    });
    NotificationService.init(context);
  }

  @override
  void dispose() {
    supabase.channel('public:notifications').unsubscribe();
    supabase.channel('public:posts').unsubscribe();
    supabase.channel('public:comments').unsubscribe();
    supabase.channel('public:conversation_participants').unsubscribe();
    supabase.channel('public:messages').unsubscribe();
    supabase.channel('public:conversations').unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: pageController.hasClients && (pageController.page?.round() == 1),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && pageController.hasClients && pageController.page?.round() != 1) {
          pageController.animateToPage(
            1, // Target index
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
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final postsAsync = ref.watch(postsProvider);
                return RefreshIndicator(
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
            ],
          )
        ],
      ),
    );
  }
}
