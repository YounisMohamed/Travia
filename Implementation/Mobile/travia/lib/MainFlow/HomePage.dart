import 'dart:math';

import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:travia/Helpers/DummyCards.dart';
import 'package:travia/Providers/LoadingProvider.dart';

import '../Classes/Post.dart';
import '../Classes/RealTimeManager.dart';
import '../Helpers/AppColors.dart';
import '../Helpers/GoogleTexts.dart';
import '../Helpers/Loading.dart';
import '../Providers/BottomBarProvider.dart';
import '../Providers/ConversationProvider.dart';
import '../Providers/NotificationProvider.dart';
import '../Providers/PostsCommentsProviders.dart';
import '../Services/UserPresenceService.dart';
import 'DMsPage.dart';
import 'Explore.dart';
import 'NotificationsPage.dart';
import 'PostCard.dart';
import 'ProfilePage.dart';
import 'Story.dart';

class MainNavigationPage extends ConsumerStatefulWidget {
  final String? type;
  final String? source_id;
  const MainNavigationPage({super.key, this.type, this.source_id});

  @override
  ConsumerState<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends ConsumerState<MainNavigationPage> with WidgetsBindingObserver {
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go("/splash-screen");
      });
    }

    // Setup realtime channels
    if (user != null) {
      ref.read(realtimeManagerProvider).setupChannels(user!.uid);
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
    // You can also setup channels here if needed
    if (user != null) {
      ref.read(realtimeManagerProvider).setupChannels(user!.uid);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final realtimeManager = ref.read(realtimeManagerProvider);

    if (state == AppLifecycleState.resumed) {
      if (user != null) {
        realtimeManager.setupChannels(user!.uid);
      }
    } else if (state == AppLifecycleState.paused) {
      realtimeManager.disposeChannels(); // Note: remove the underscore since it's called from outside
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(realtimeManagerProvider).disposeChannels(); // Clean up channels
    super.dispose();
  }

  late PageController horizontalPageController;

  void _changeMainPage(int index) {
    // Simply update the provider state - no page controller needed
    ref.read(currentIndexProvider.notifier).state = index;

    // When Home is selected (index 2), ensure horizontal page is at Home (index 0)
    if (index == 2) {
      ref.read(horizontalPageProvider.notifier).state = 0;
    }
  }

  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(currentIndexProvider);
    final horizontalIndex = ref.watch(horizontalPageProvider);

    // Helper function to get the current page widget
    Widget getCurrentPage() {
      switch (currentIndex) {
        case 0:
          return ExplorePage();
        case 1:
          return PlanPage();
        case 2:
          // When on Home tab, show the horizontal PageView
          return HomePageViewWidget(
            key: ValueKey('home_page_view'),
            onChangeMainPage: _changeMainPage,
          );
        case 3:
          return NotificationsPage();
        case 4:
          return ProfilePage(
            profileUserId: FirebaseAuth.instance.currentUser!.uid,
          );
        default:
          return ExplorePage();
      }
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        // Check if we're on the home page (main index 2) and home screen (horizontal index 0)
        final isOnHomePage = currentIndex == 2;
        final isOnHomeScreen = horizontalIndex == 0;

        if (isOnHomePage && isOnHomeScreen) {
          // We're on the home screen, handle exit logic
          final now = DateTime.now();
          if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > Duration(seconds: 2)) {
            // First back press or more than 2 seconds since last press
            _lastBackPressTime = now;

            // Show exit confirmation
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.exit_to_app, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Press back again to exit',
                      style: GoogleFonts.lexendDeca(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                duration: Duration(seconds: 2),
                backgroundColor: kDeepPink,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: EdgeInsets.all(16),
              ),
            );
          } else {
            FlutterExitApp.exitApp();
          }
        } else {
          // Not on home screen, navigate back to home
          if (!isOnHomePage) {
            _changeMainPage(2); // Navigate to home (index 2)
          } else if (!isOnHomeScreen) {
            // Need to navigate back to home screen within HomePageViewWidget
            ref.read(horizontalPageProvider.notifier).state = 0;
          }
        }
      },
      child: Scaffold(
        body: getCurrentPage(),
        bottomNavigationBar: BottomNav(
          currentIndex: currentIndex,
          onTap: _changeMainPage,
          ref: ref,
        ),
      ),
    );
  }
}

class HomePageViewWidget extends ConsumerStatefulWidget {
  final Function(int) onChangeMainPage;

  const HomePageViewWidget({
    Key? key,
    required this.onChangeMainPage,
  }) : super(key: key);

  @override
  ConsumerState<HomePageViewWidget> createState() => _HomePageViewWidgetState();
}

class _HomePageViewWidgetState extends ConsumerState<HomePageViewWidget> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    final initialPage = ref.read(horizontalPageProvider);
    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _changeHorizontalPage(int index) {
    ref.read(horizontalPageProvider.notifier).state = index;
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to horizontal page changes from other sources (like back button)
    ref.listen<int>(horizontalPageProvider, (previous, next) {
      if (_pageController.hasClients && _pageController.page?.round() != next) {
        _pageController.jumpToPage(next);
      }
    });

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          ref.read(horizontalPageProvider.notifier).state = index;
        },
        children: [
          HomeWidget(
            onMessagePressed: () => _changeHorizontalPage(1),
            onExplorePressed: () => widget.onChangeMainPage(0),
          ),
          DMsPage(),
        ],
      ),
    );
  }
}

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final WidgetRef ref;

  const BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.ref,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Container(
      decoration: BoxDecoration(
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
        backgroundColor: Colors.transparent,
        color: kDeepGrey,
        buttonBackgroundColor: kDeepPink,
        height: 75, // Increased height to accommodate text
        animationDuration: Duration(milliseconds: 300),
        index: currentIndex,
        onTap: onTap,
        letIndexChange: (index) => true, // Always allow index change
        items: [
          _buildIconWithLabel(Icons.explore_outlined, 'Explore', currentIndex == 0),
          _buildIconWithLabel(Icons.flight_takeoff, 'Plan', currentIndex == 1),
          _buildIconWithLabel(Icons.home_outlined, 'Home', currentIndex == 2),
          _buildNotificationIcon(unreadCount, 'Alerts', currentIndex == 3),
          _buildIconWithLabel(Icons.person_outline, 'Profile', currentIndex == 4),
        ],
      ),
    );
  }

  Widget _buildIconWithLabel(IconData icon, String label, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: isSelected ? 24 : 20,
          color: isSelected ? Colors.white : Colors.black54,
        ),
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: isSelected ? 11 : 10,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildNotificationIcon(int unreadCount, String label, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.notifications_none,
              size: isSelected ? 24 : 20,
              color: isSelected ? Colors.white : Colors.black54,
            ),
            if (unreadCount > 0)
              Positioned(
                right: -8,
                top: -4,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: kDeepPink.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: Colors.white,
                      width: 1,
                    ),
                  ),
                  constraints: BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: isSelected ? 11 : 10,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class HomeWidget extends ConsumerWidget {
  final VoidCallback onMessagePressed;
  final VoidCallback onExplorePressed;

  const HomeWidget({
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
    final unreadDMCount = ref.watch(unreadDMCountProvider);

    // Create custom swipe gesture handlers for the Home screen
    return GestureDetector(
      // SWIPE LEFT TO GO TO MESSAGES
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < 0) {
            onMessagePressed();
          }
        }
      },
      child: Scaffold(
        backgroundColor: kDeepGrey,
        appBar: AppBar(
          forceMaterialTransparency: true,
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.send_rounded,
                    color: kDeepPinkLight,
                    size: 28,
                  ),
                  onPressed: onMessagePressed,
                  tooltip: 'Messages',
                ),
                if (unreadDMCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: kDeepPink.withOpacity(0.8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          unreadDMCount > 99 ? '99+' : unreadDMCount.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: unreadDMCount > 99 ? 8 : 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Image.asset(
                "assets/TraviaLogo.png",
                height: 90,
                width: 90,
              ),
              Container(
                height: 26,
                width: 2,
                color: Colors.grey,
                margin: EdgeInsets.symmetric(horizontal: 8),
              ),
              Expanded(
                child: TypewriterAnimatedText(
                  text: "Plan Smart. Travel Far.",
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 16,
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
        ), // rest of code
        body: Column(
          children: [
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
    // Function to calculate engagement score for post ranking

    double calculateEngagementScore(Post post) {
      final likes = post.likesCount;
      final dislikes = post.dislikesCount;
      final comments = post.commentCount;

      // Weights for different engagement types
      const double likeWeight = 1.0;
      const double dislikeWeight = -0.8; // Negative impact, but less than likes
      const double commentWeight = 1.5; // Comments are valuable engagement

      // Base score calculation
      double score = (likes * likeWeight) + (dislikes * dislikeWeight) + (comments * commentWeight);

      // Apply time decay factor (newer posts get slight boost)
      final now = DateTime.now();
      final daysSincePost = now.difference(post.createdAt).inDays;

      // Gradual decay over time (posts lose 5% score per day, minimum 50% of original)
      final timeFactor = max(0.5, 1.0 - (daysSincePost * 0.05));
      score *= timeFactor;

      // Prevent negative scores from dominating
      return max(0, score);
    }

    // Function to sort posts by engagement score
    List<Post> sortPostsByEngagement(List<Post> postsToSort) {
      final sortedPosts = List<Post>.from(postsToSort);
      sortedPosts.sort((a, b) {
        final scoreA = calculateEngagementScore(a);
        final scoreB = calculateEngagementScore(b);
        return scoreB.compareTo(scoreA); // Descending order (highest score first)
      });
      return sortedPosts;
    }

    // Function to group posts by location efficiently
    Map<String, List<Post>> groupPostsByLocation(List<Post> allPosts) {
      final result = <String, List<Post>>{};
      final cityPostCounts = <String, int>{};
      final List<Post> postsWithNoLocation = [];

      // First pass: count posts per city and collect posts with no location
      for (final post in allPosts) {
        if (post.location.isNotEmpty) {
          final city = post.location.split(',').first.trim();
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

      // Sort posts within each location group by engagement
      for (final key in result.keys) {
        result[key] = sortPostsByEngagement(result[key]!);
      }

      return result;
    }

    // Sort all posts by engagement for the recommended section
    final sortedPosts = sortPostsByEngagement(posts);

    // Group posts by location (already sorted within each group)
    final postsByLocation = groupPostsByLocation(posts);

    // Create a list to hold all sections (for better organization)
    final List<Widget> sections = [];

    // First section - Recommended For You (using sorted posts)
    sections.add(_buildPostSection(
      context: context,
      title: "Recommended For You",
      posts: sortedPosts.take(20).toList(), // Limit to top 20 for performance
    ));
    sections.add(SizedBox(height: 20));

    // Add location-based sections (posts already sorted within each group)
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
        // Section title with engagement indicator for recommended section
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (title == "Recommended For You") ...[
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kDeepPink.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kDeepPink.withOpacity(0.3)),
                      ),
                      child: Text(
                        "Trending",
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: kDeepPink,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 2),
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
