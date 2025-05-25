import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travia/Helpers/DummyCards.dart';
import 'package:travia/Providers/LoadingProvider.dart';

import '../Classes/Post.dart';
import '../Helpers/AppColors.dart';
import '../Helpers/GoogleTexts.dart';
import '../Helpers/Loading.dart';
import '../Providers/BottomBarProvider.dart';
import '../Providers/PostsCommentsProviders.dart';
import '../Services/UserPresenceService.dart';
import '../database/DatabaseMethods.dart';
import '../main.dart';
import 'DMsPage.dart';
import 'Explore.dart';
import 'NotificationsPage.dart';
import 'PostCard.dart';
import 'ProfilePage.dart';
import 'Story.dart';
import 'UploadPostPage.dart';

class MainNavigationPage extends ConsumerStatefulWidget {
  final String? type;
  final String? source_id;
  const MainNavigationPage({super.key, this.type, this.source_id});

  @override
  ConsumerState<MainNavigationPage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<MainNavigationPage> {
  final user = FirebaseAuth.instance.currentUser;
  late PageController horizontalPageController;
  late PageController mainPageController;

  @override
  void initState() {
    super.initState();

    // Initialize the horizontal page controller for sliding between UploadPost, Home, and DMs
    horizontalPageController = PageController(initialPage: 1);

    // Initialize the main page controller for the bottom navigation (with Home as default), Home index = 2,
    mainPageController = PageController(initialPage: 2);

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go("/signin");
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userPresenceServiceProvider).initialize();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Navigate to messages through notification
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupChannels();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setupChannels();
    } else if (state == AppLifecycleState.paused) {
      _disposeChannels();
    }
  }

  void _setupChannels() {
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
        .channel('public:users')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
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
            callback: (payload) {})
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
  }

  void _disposeChannels() {
    supabase.removeAllChannels();
  }

  @override
  void dispose() {
    horizontalPageController.dispose();
    mainPageController.dispose();
    super.dispose();
  }

  // Handle horizontal page changes manually
  void _changeHorizontalPage(int index) {
    ref.read(horizontalPageProvider.notifier).state = index;
    if (horizontalPageController.hasClients) {
      // For horizontal pages, always animate since they're adjacent
      horizontalPageController.animateToPage(
        index,
        duration: Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _isChangingPage = false;
  void _changeMainPage(int index) {
    if (_isChangingPage) return;

    _isChangingPage = true;

    // First update the provider state
    ref.read(currentIndexProvider.notifier).state = index;

    // Get the current index before changing
    final currentPage = mainPageController.page?.round() ?? 2; // Default to home index
    final distance = (index - currentPage).abs();

    // Then jump or animate the page controller based on distance
    if (mainPageController.hasClients) {
      if (distance > 1) {
        // If pages are not adjacent, jump immediately for instant transition
        mainPageController.jumpToPage(index);
        _isChangingPage = false;
      } else {
        // For adjacent pages, use animation for a smooth transition
        mainPageController
            .animateToPage(
          index,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        )
            .then((_) {
          _isChangingPage = false;
        });
      }
    } else {
      _isChangingPage = false;
    }

    // When Home is selected (index 2), ensure horizontal page is at Home (index 1)
    if (index == 2) {
      ref.read(horizontalPageProvider.notifier).state = 1;
      if (horizontalPageController.hasClients) {
        horizontalPageController.animateToPage(
          1,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(currentIndexProvider);

    return PopScope(
      canPop: (horizontalPageController.hasClients && horizontalPageController.page?.round() == 1) &&
          (mainPageController.hasClients && mainPageController.page?.round() == 2), // Update to check for index 2 (home)
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // If we're not on the home page in the main navigation
          if (mainPageController.hasClients && mainPageController.page?.round() != 2) {
            _changeMainPage(2); // Navigate to home (index 2)
          }
          // If we're on home but not on the home screen in horizontal navigation
          else if (horizontalPageController.hasClients && horizontalPageController.page?.round() != 1) {
            _changeHorizontalPage(1);
          }
        }
      },
      child: Scaffold(
        body: PageView(
          controller: mainPageController,
          physics: NeverScrollableScrollPhysics(), // prevent swipe
          onPageChanged: (index) {
            if (!_isChangingPage) {
              ref.read(currentIndexProvider.notifier).state = index;
            }
          },
          children: [
            ExplorePage(), // Index 0: Explore
            PlanPage(), // Index 1: Plan
            // When on Home tab, show the horizontal PageView (Index 2)
            Scaffold(
              body: PageView(
                controller: horizontalPageController,
                onPageChanged: (index) {
                  ref.read(horizontalPageProvider.notifier).state = index;
                },
                children: [
                  UploadPostPage(),
                  HomeWidget(
                    onCameraPressed: () => _changeHorizontalPage(0),
                    onMessagePressed: () => _changeHorizontalPage(2),
                    onExplorePressed: () => _changeMainPage(0),
                  ),
                  DMsPage(),
                ],
              ),
            ),
            NotificationsPage(), // Index 3: Notifications
            ProfilePage(
              profileUserId: "Xw3QpRZ7rlSvtjJEKrav2alxYTA3",
            ), // Index 4: Profile
          ],
        ),
        bottomNavigationBar: BottomNav(
          currentIndex: currentIndex,
          onTap: _changeMainPage,
        ),
      ),
    );
  }
}

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNav({
    required this.currentIndex,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Gradient background from black to deep pink
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.black,
            kDeepPink,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: CurvedNavigationBar(
        key: GlobalKey<CurvedNavigationBarState>(),
        backgroundColor: Colors.transparent, // Transparent to show gradient
        color: Colors.white,
        buttonBackgroundColor: kDeepPink,
        height: 60,
        animationDuration: Duration(milliseconds: 300),
        index: currentIndex,
        onTap: onTap,
        letIndexChange: (index) => true, // Always allow index change
        items: [
          _buildIcon(Icons.explore_outlined, currentIndex == 0), // Explore
          _buildIcon(Icons.flight_takeoff, currentIndex == 1), // Plan
          _buildIcon(Icons.home_outlined, currentIndex == 2), // Home (center)
          _buildIcon(Icons.notifications_none, currentIndex == 3), // Notifications
          _buildIcon(Icons.person_outline, currentIndex == 4), // Profile
        ],
      ),
    );
  }

  Widget _buildIcon(IconData icon, bool isSelected) {
    return Icon(
      icon,
      size: isSelected ? 30 : 26,
      color: isSelected ? Colors.white : Colors.black54,
    );
  }
}

class HomeWidget extends ConsumerWidget {
  final VoidCallback onCameraPressed;
  final VoidCallback onMessagePressed;
  final VoidCallback onExplorePressed;

  const HomeWidget({
    required this.onCameraPressed,
    required this.onMessagePressed,
    required this.onExplorePressed,
    Key? key,
  }) : super(key: key);

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
      // Swipe right to go to Upload Post
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 0) {
            // Swipe right
            onCameraPressed();
          } else if (details.primaryVelocity! < 0) {
            // Swipe left
            onMessagePressed();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.camera_alt_rounded,
              color: Colors.black,
              size: 21,
            ),
            onPressed: onCameraPressed,
            tooltip: 'Camera',
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.send_rounded,
                color: Colors.black,
                size: 21,
              ),
              onPressed: onMessagePressed,
              tooltip: 'Messages',
            ),
          ],
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Image.asset(
                "assets/TraviaLogo.png",
                height: 70,
                width: 70,
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
                    fontSize: 12.6,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 10),
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: LoadingWidget(),
                ),
            ],
          ),
        ),
        body: Column(
          children: [
            // Add the stories bar here
            StoryBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: refresh,
                displacement: 32,
                color: Colors.black,
                backgroundColor: Colors.white,
                child: postsAsync.when(
                  loading: () => Skeletonizer(
                    enabled: true,
                    child: _buildLoadingState(context),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed(BuildContext context, List<Post> posts) {
    // Function to group posts by location efficiently
    Map<String, List<Post>> groupPostsByLocation(List<Post> allPosts) {
      final result = <String, List<Post>>{};
      final cityPostCounts = <String, int>{};
      final List<Post> postsWithNoLocation = [];

      // First pass: count posts per city and collect posts with no location
      for (final post in allPosts) {
        if (post.location!.isNotEmpty) {
          final city = post.location!.split(',').first.trim();
          cityPostCounts[city] = (cityPostCounts[city] ?? 0) + 1;
        } else {
          postsWithNoLocation.add(post);
        }
      }

      // Find top cities by post count (limit to 5)
      final cityEntries = List.from(cityPostCounts.entries);
      cityEntries.sort((a, b) => b.value.compareTo(a.value));
      final topCities = cityEntries.take(5).map((e) => e.key).toSet();

      // Second pass: group posts by top cities only
      for (final post in allPosts) {
        if (post.location.isNotEmpty) {
          final city = post.location.split(',').first.trim();

          if (topCities.contains(city)) {
            if (!result.containsKey(city)) {
              result[city] = [];
            }
            result[city]!.add(post);
          }
        }
      }

      // Add the "Others" category if there are posts with no location
      if (postsWithNoLocation.isNotEmpty) {
        result["Others"] = postsWithNoLocation;
      }

      return result;
    }

    // Group posts by location
    final postsByLocation = groupPostsByLocation(posts);

    // Create a list to hold all sections (for better organization)
    final List<Widget> sections = [];

    // First section - Recommended For You
    sections.add(_buildPostSection(context: context, title: "Recommended For You", posts: posts));
    sections.add(SizedBox(height: 20));

    // Add location-based sections
    for (final entry in postsByLocation.entries) {
      // Skip "Others" section for now - we'll add it at the end
      if (entry.key == "Others") continue;

      sections.add(_buildPostSection(
        context: context,
        title: "Explore ${entry.key}",
        posts: entry.value,
      ));
      sections.add(SizedBox(height: 20));
    }

    // Add "Others" section at the end (if it exists)
    if (postsByLocation.containsKey("Others")) {
      sections.add(_buildPostSection(
        context: context,
        title: "Others",
        posts: postsByLocation["Others"]!,
      ));
      sections.add(SizedBox(height: 20));
    }

    // Add planning card at the very end
    sections.add(_buildPlanningCard(context));
    sections.add(SizedBox(height: 20));

    return ListView(
      children: sections,
    );
  }

  // Build a horizontal scrolling section with title
  Widget _buildPostSection({
    required BuildContext context,
    required String title,
    required List<Post> posts,
  }) {
    if (posts.isEmpty) return SizedBox.shrink();

    // Calculate responsive height based on screen size
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                title,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(
              width: 2,
            ),
            GestureDetector(
              onTap: () {
                onExplorePressed();
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 14.0),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        kDeepPink,
                        kDeepPinkLight,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kDeepPink.withOpacity(0.4),
                        blurRadius: 3,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: kDeepPinkLight.withOpacity(0.3),
                        blurRadius: 2,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ),
            ),
          ],
        ),

        // Horizontal scrolling posts with responsive layout
        SizedBox(
          // Use a percentage of screen height for more responsive sizing
          height: screenHeight * 0.6,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: posts.length,
            padding: EdgeInsets.symmetric(horizontal: 4),
            itemBuilder: (context, index) {
              final post = posts[index];

              // Use AspectRatio for more consistent card sizing
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: AspectRatio(
                  aspectRatio: 0.6, // Portrait card layout (width:height ratio)
                  child: GestureDetector(
                    onTap: () {
                      context.push('/post/${post.postId}');
                    },
                    child: PostCard(
                      profilePicUrl: post.userPhotoUrl,
                      username: post.userUserName,
                      postImageUrl: post.mediaUrl,
                      commentCount: post.commentCount,
                      likesCount: post.likesCount,
                      dislikesCount: post.dislikesCount,
                      postId: post.postId,
                      userId: post.userId,
                      postCaption: post.caption,
                      postLocation: post.location,
                      createdAt: post.createdAt,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return ListView(
      children: [
        // Section title skeleton
        Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Container(
            height: 24,
            width: 120,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        // Horizontal list skeleton with more responsive layout
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6, // Responsive height
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: AspectRatio(
                aspectRatio: 0.7, // Card aspect ratio
                child: DummyPostCard(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _buildPlanningCard(BuildContext context) {
  return Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          kDeepPink,
          Colors.black,
        ],
      ),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row with plane icon
        Row(
          children: [
            Icon(
              Icons.flight_takeoff,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              "Plan your next adventure",
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Description text
        Text(
          "Let our AI help you create the perfect plan",
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),

        // Start planning button
        Center(
          child: ElevatedButton(
            onPressed: () {
              // Navigate to planning page or open planning dialog
              // You can add navigation logic here
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: kDeepPink,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
            child: Text(
              "Start Planning",
              style: GoogleFonts.ibmPlexSans(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class PlanPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text("Plan Trip"),
        ),
        body: Center(child: Text("Plan Your Trip")),
      );
}
