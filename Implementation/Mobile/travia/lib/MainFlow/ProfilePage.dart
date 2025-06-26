import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:travia/Helpers/DummyCards.dart';
import 'package:travia/Helpers/GoogleTexts.dart';
import 'package:travia/MainFlow/EditProfile.dart';
import 'package:travia/MainFlow/FriendsPage.dart';
import 'package:travia/MainFlow/UploadPostPage.dart';

import '../Classes/Post.dart';
import '../Helpers/AppColors.dart';
import '../Helpers/Constants.dart';
import '../Helpers/DeleteConfirmation.dart';
import '../Helpers/HelperMethods.dart';
import '../Helpers/PopUp.dart';
import '../Providers/ConversationProvider.dart';
import '../Providers/ImagePickerProvider.dart';
import '../Providers/ProfileProviders.dart';
import '../Providers/UploadProviders.dart';
import '../Services/BlockService.dart';
import '../Services/FollowService.dart';
import '../main.dart';
import 'ReportsPage.dart';
import 'SettingsPage.dart';

class ProfilePage extends ConsumerStatefulWidget {
  final String profileUserId;
  ProfilePage({
    required this.profileUserId,
    super.key,
  });

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final PageController _pageController = PageController();
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(followStateProvider.notifier).loadFollowStatus(widget.profileUserId);
    });
    _pageController.addListener(() {
      if (_pageController.page!.round() != ref.read(selectedPostTabProvider)) {
        ref.read(selectedPostTabProvider.notifier).state = _pageController.page!.round();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Future<void> _handleBlockUser(BuildContext context, WidgetRef ref) async {
      // Show confirmation dialog
      showCustomDialog(
        context: context,
        title: "Block user",
        message: "Are you sure you want to block this user? They won\'t be able to see your posts, comment on your content, or message you.",
        actionText: "Block",
        actionIcon: Icons.person,
        onActionPressed: () async {
          try {
            final success = await ref.read(blockStatusProvider(widget.profileUserId).notifier).blockUser(currentUserId);

            Navigator.of(context).pop();

            if (success) {
              Popup.showSuccess(text: "User blocked successfully", context: context);
              Phoenix.rebirth(context);
            } else {
              Popup.showError(text: "Error while blocking user", context: context);
            }
          } catch (e) {
            Navigator.of(context).pop();
            Popup.showError(text: "Error while blocking user", context: context);
          }
        },
      );
    }

    Future<void> _handleUnblockUser(BuildContext context, WidgetRef ref) async {
      showCustomDialog(
        context: context,
        title: "Unblock user",
        message: "Are you sure you want to unblock this user?",
        actionText: "Unblock",
        actionIcon: Icons.person,
        onActionPressed: () async {
          try {
            final success = await ref.read(blockStatusProvider(widget.profileUserId).notifier).unblockUser(currentUserId);

            Navigator.of(context).pop(); // Close loading dialog

            if (success) {
              // Show success message
              Popup.showSuccess(text: "User unblocked successfully", context: context);
              Phoenix.rebirth(context);
            } else {
              // Show error message
              Popup.showError(text: "Error while unblocking user", context: context);
            }
          } catch (e) {
            Navigator.of(context).pop(); // Close loading dialog
            Popup.showError(text: "Error while unblocking user", context: context);
          }
        },
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isOwnProfile = widget.profileUserId == currentUserId;
    final tabLabels = isOwnProfile ? ['Posts', 'Liked', 'Saved'] : ['Posts', 'Liked'];
    final selectedTab = ref.watch(selectedPostTabProvider);
    final isLoading = ref.watch(profileLoadingProvider);
    final userAsync = ref.watch(userStreamProvider(widget.profileUserId));
    final blockStatus = ref.watch(blockStatusProvider(widget.profileUserId));
    final followController = ref.read(followControllerProvider);
    final isFollowing = ref.watch(isFollowingProvider(widget.profileUserId));

    return userAsync.when(
        data: (user) {
          final List<AsyncValue<List<Post>>> postLists = [
            ref.watch(filteredPostsProvider(user.uploadedPosts)),
            ref.watch(filteredPostsProvider(user.likedPosts)),
            if (isOwnProfile) ref.watch(filteredPostsProvider(user.savedPosts)),
          ];

          return Scaffold(
            body: RefreshIndicator(
              onRefresh: () async {
                refresh(context);
              },
              displacement: 32,
              color: kDeepPink,
              backgroundColor: Colors.white,
              child: Stack(
                children: [
                  // Gradient background
                  Container(
                    height: screenHeight,
                    width: screenWidth,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [kDeepBlue, kDeepPink, kDeepPinkLight],
                      ),
                    ),
                  ),

                  SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.02),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (isOwnProfile)
                                Container(
                                  height: screenWidth * 0.12,
                                  width: screenWidth * 0.12,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(screenWidth * 0.06),
                                  ),
                                  child: IconButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => UploadPostPage()),
                                      );
                                    },
                                    icon: Icon(Icons.add),
                                    color: kDeepPink,
                                  ),
                                ),
                              Container(
                                  height: screenWidth * 0.12,
                                  width: screenWidth * 0.12,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(screenWidth * 0.06),
                                  ),
                                  child: isOwnProfile
                                      ? IconButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => SettingsPage(),
                                              ),
                                            );
                                          },
                                          icon: Icon(Icons.settings),
                                          color: kDeepPink,
                                        )
                                      : PopupMenuButton<String>(
                                          onSelected: (String value) async {
                                            switch (value) {
                                              case 'block':
                                                await _handleBlockUser(context, ref);
                                                break;
                                              case 'unblock':
                                                await _handleUnblockUser(context, ref);
                                                break;
                                              case 'report':
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ReportsPage(
                                                      targetUserId: widget.profileUserId,
                                                      reportType: 'account',
                                                    ),
                                                  ),
                                                );
                                                break;
                                            }
                                          },
                                          icon: Icon(Icons.more_horiz, color: kDeepPink),
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            side: BorderSide(color: kDeepPink.withOpacity(0.2), width: 1),
                                          ),
                                          elevation: 8,
                                          shadowColor: kDeepPink.withOpacity(0.3),
                                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                            PopupMenuItem<String>(
                                              value: blockStatus.when(
                                                data: (isBlocked) => isBlocked ? 'unblock' : 'block',
                                                loading: () => 'block',
                                                error: (_, __) => 'block',
                                              ),
                                              child: blockStatus.when(
                                                data: (isBlocked) => Row(
                                                  children: [
                                                    Icon(
                                                      isBlocked ? Icons.person_add : Icons.block,
                                                      color: kDeepPink,
                                                      size: 20,
                                                    ),
                                                    SizedBox(width: 12),
                                                    Text(
                                                      isBlocked ? 'Unblock User' : 'Block User',
                                                      style: TextStyle(
                                                        color: Colors.black87,
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                loading: () => Row(
                                                  children: [
                                                    SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: kDeepPink,
                                                      ),
                                                    ),
                                                    SizedBox(width: 12),
                                                    Text(
                                                      'Loading...',
                                                      style: TextStyle(
                                                        color: Colors.black87,
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                error: (_, __) => Row(
                                                  children: [
                                                    Icon(
                                                      Icons.block,
                                                      color: kDeepPink,
                                                      size: 20,
                                                    ),
                                                    SizedBox(width: 12),
                                                    Text(
                                                      'Block User',
                                                      style: TextStyle(
                                                        color: Colors.black87,
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            PopupMenuDivider(
                                              height: 1,
                                            ),
                                            PopupMenuItem<String>(
                                              value: 'report',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.flag,
                                                    color: kDeepPink,
                                                    size: 20,
                                                  ),
                                                  SizedBox(width: 12),
                                                  Text(
                                                    'Report User',
                                                    style: TextStyle(
                                                      color: Colors.black87,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        )),
                            ],
                          ),
                        ),

                        // Main content
                        Expanded(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Grey background content
                              Container(
                                width: double.infinity,
                                margin: EdgeInsets.only(top: screenWidth * 0.12),
                                decoration: const BoxDecoration(
                                  color: kBackground,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(40),
                                    topRight: Radius.circular(40),
                                  ),
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      SizedBox(height: screenWidth * 0.15),

                                      // Stats
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            GestureDetector(
                                                onTap: () {
                                                  Navigator.of(context).push(MaterialPageRoute(
                                                      builder: (_) => FriendsScreen(
                                                            initialIndex: 0,
                                                            userIdOfCurrentFriendsList: widget.profileUserId,
                                                          )));
                                                },
                                                child: _buildStatColumn(user.followingIds.length, 'Following')),
                                            GestureDetector(
                                                onTap: () {
                                                  Navigator.of(context).push(MaterialPageRoute(
                                                      builder: (_) => FriendsScreen(
                                                            initialIndex: 1,
                                                            userIdOfCurrentFriendsList: widget.profileUserId,
                                                          )));
                                                },
                                                child: _buildStatColumn(user.friendIds.length, 'Followers')),
                                          ],
                                        ),
                                      ),

                                      SizedBox(height: screenHeight * 0.02),

                                      // User info
                                      Text(
                                        user.displayName,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 5),

                                      Text(
                                        '@${user.username}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      Padding(
                                        padding: const EdgeInsets.only(left: 12, right: 12),
                                        child: Center(
                                          child: Text(
                                            textAlign: TextAlign.center,
                                            user.visitedCountries.join(' | '),
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        ),
                                      ),

                                      SizedBox(height: screenHeight * 0.02),

                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: IBMPlexSansText(
                                          text: user.bio ?? "No Bio",
                                          size: 15,
                                          center: true,
                                          isBold: true,
                                        ),
                                      ),

                                      SizedBox(height: screenHeight * 0.02),

                                      Text(
                                        '${user.gender} | ${DateTime.now().year - user.age.year - (DateTime.now().month < user.age.month || (DateTime.now().month == user.age.month && DateTime.now().day < user.age.day) ? 1 : 0)} | ${user.relationshipStatus}',
                                        style: TextStyle(
                                          fontSize: 14,
                                        ),
                                      ),

                                      SizedBox(height: screenHeight * 0.02),

                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: (user.badges.isEmpty
                                                ? [
                                                    'New User',
                                                  ]
                                                : user.badges)
                                            .map((badge) {
                                          final badgeStyle = badgeStyles[badge] ?? defaultBadgeStyle;

                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(colors: badgeStyle.gradient),
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: badgeStyle.gradient.first.withOpacity(0.3),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  badgeStyle.icon,
                                                  size: 12,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  badge,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),

                                      SizedBox(height: screenHeight * 0.02),

                                      // Check if the user is blocked
                                      blockStatus.when(
                                        data: (isBlocked) {
                                          if (isBlocked && !isOwnProfile) {
                                            // Show blocked message instead of profile content
                                            return Container(
                                              width: double.infinity,
                                              margin: EdgeInsets.only(top: screenHeight * 0.02),
                                              padding: EdgeInsets.all(screenWidth * 0.1),
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.only(
                                                  topLeft: Radius.circular(30),
                                                  topRight: Radius.circular(30),
                                                ),
                                              ),
                                              child: Column(
                                                children: [
                                                  Icon(
                                                    Icons.block,
                                                    size: 60,
                                                    color: kDeepPink,
                                                  ),
                                                  SizedBox(height: screenHeight * 0.02),
                                                  Text(
                                                    'You have blocked this user',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                                  SizedBox(height: screenHeight * 0.01),
                                                  Text(
                                                    'Unblock to see their profile content',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                  SizedBox(height: screenHeight * 0.04),
                                                ],
                                              ),
                                            );
                                          }

                                          // If not blocked, show the rest of the profile
                                          return Column(
                                            children: [
                                              // Follow - Message
                                              if (currentUserId != widget.profileUserId)
                                                Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                                                  child: Row(
                                                    children: [
                                                      Consumer(
                                                        builder: (context, ref, _) {
                                                          return Expanded(
                                                            child: GestureDetector(
                                                              onTap: isLoading
                                                                  ? null
                                                                  : () async {
                                                                      final result = await followController.toggleFollow(widget.profileUserId);

                                                                      if (!result.isSuccess && context.mounted) {
                                                                        if (result.isBlocked) {
                                                                          Popup.showError(
                                                                            text: "Cannot follow @${user.username}: You have a blocked relationship with this user",
                                                                            context: context,
                                                                          );
                                                                        } else {
                                                                          Popup.showError(
                                                                            text: result.errorMessage ?? "Failed to follow user",
                                                                            context: context,
                                                                          );
                                                                        }
                                                                      }
                                                                    },
                                                              child: AnimatedContainer(
                                                                duration: const Duration(milliseconds: 200),
                                                                height: screenHeight * 0.06,
                                                                margin: const EdgeInsets.only(right: 10),
                                                                decoration: BoxDecoration(
                                                                  color: isFollowing ? kDeepPinkLight.withValues(alpha: 0.9) : kDeepPink,
                                                                  borderRadius: BorderRadius.circular(25),
                                                                  boxShadow: [
                                                                    BoxShadow(
                                                                      color: kDeepPink.withOpacity(0.3),
                                                                      blurRadius: 10,
                                                                      offset: const Offset(0, 5),
                                                                    ),
                                                                  ],
                                                                ),
                                                                child: Center(
                                                                  child: isLoading
                                                                      ? const SizedBox(
                                                                          width: 20,
                                                                          height: 20,
                                                                          child: CircularProgressIndicator(
                                                                            strokeWidth: 2,
                                                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                                          ),
                                                                        )
                                                                      : Text(
                                                                          isFollowing ? 'Unfollow' : 'Follow',
                                                                          style: const TextStyle(
                                                                            color: Colors.white,
                                                                            fontWeight: FontWeight.bold,
                                                                            fontSize: 16,
                                                                          ),
                                                                        ),
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                      Expanded(
                                                        child: GestureDetector(
                                                          onTap: () async {
                                                            final conversationId = await ref.read(createConversationProvider(widget.profileUserId).future);
                                                            context.push("/messages/$conversationId");
                                                          },
                                                          child: Container(
                                                            height: screenHeight * 0.06,
                                                            margin: const EdgeInsets.only(left: 10),
                                                            decoration: BoxDecoration(
                                                              color: Colors.white,
                                                              borderRadius: BorderRadius.circular(25),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Colors.black.withOpacity(0.1),
                                                                  blurRadius: 10,
                                                                  offset: const Offset(0, 5),
                                                                ),
                                                              ],
                                                            ),
                                                            child: const Center(
                                                              child: Text(
                                                                'Message',
                                                                style: TextStyle(
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 16,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              // Edit Profile if you look at your own profile
                                              if (currentUserId == widget.profileUserId)
                                                Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.2),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: GestureDetector(
                                                          onTap: () {
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(builder: (_) => EditProfilePage(user: user)),
                                                            );
                                                          },
                                                          child: Container(
                                                            height: screenHeight * 0.06,
                                                            margin: const EdgeInsets.only(left: 10),
                                                            decoration: BoxDecoration(
                                                              color: kDeepPink,
                                                              borderRadius: BorderRadius.circular(25),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Colors.black.withOpacity(0.1),
                                                                  blurRadius: 10,
                                                                  offset: const Offset(0, 5),
                                                                ),
                                                              ],
                                                            ),
                                                            child: const Center(
                                                              child: Text(
                                                                'Edit Profile',
                                                                style: TextStyle(
                                                                  color: Colors.white,
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 16,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              SizedBox(height: screenHeight * 0.02),

                                              // Posts section with tab
                                              Container(
                                                width: double.infinity,
                                                decoration: const BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.only(
                                                    topLeft: Radius.circular(30),
                                                    topRight: Radius.circular(30),
                                                  ),
                                                ),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    // Tab section
                                                    Padding(
                                                      padding: EdgeInsets.only(top: screenHeight * 0.02, bottom: screenHeight * 0.01),
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                        children: List.generate((isOwnProfile || user.showLikedPosts) ? tabLabels.length : 1, (index) {
                                                          final isSelected = selectedTab == index;
                                                          final currentTabLabel = tabLabels[index];

                                                          return GestureDetector(
                                                            onTap: () {
                                                              ref.read(selectedPostTabProvider.notifier).state = index;
                                                            },
                                                            child: Column(
                                                              children: [
                                                                Text(
                                                                  currentTabLabel,
                                                                  style: TextStyle(
                                                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                                    color: isSelected ? Colors.black : Colors.grey,
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 5),
                                                                if (isSelected)
                                                                  Container(
                                                                    height: 2,
                                                                    width: 40,
                                                                    color: kDeepPink,
                                                                  )
                                                                else
                                                                  const SizedBox(height: 2),
                                                              ],
                                                            ),
                                                          );
                                                        }),
                                                      ),
                                                    ),

                                                    // Posts Grid - Remove PageView and fixed height
                                                    Padding(
                                                      padding: const EdgeInsets.all(10),
                                                      child: postLists[selectedTab].when(
                                                        loading: () => GridView.count(
                                                          shrinkWrap: true,
                                                          physics: const NeverScrollableScrollPhysics(),
                                                          crossAxisCount: 2,
                                                          crossAxisSpacing: 10,
                                                          mainAxisSpacing: 10,
                                                          children: List.generate(4, (index) {
                                                            return Skeletonizer(
                                                              containersColor: Colors.grey.shade300,
                                                              child: Container(
                                                                decoration: BoxDecoration(
                                                                  color: Colors.white,
                                                                  borderRadius: BorderRadius.circular(15),
                                                                ),
                                                              ),
                                                            );
                                                          }),
                                                        ),
                                                        error: (e, _) => Center(
                                                          child: Padding(
                                                            padding: const EdgeInsets.all(20),
                                                            child: IBMPlexSansText(
                                                              text: "Error loading posts",
                                                              size: 25,
                                                            ),
                                                          ),
                                                        ),
                                                        data: (currentPosts) {
                                                          final isTabEqualPosts = tabLabels[selectedTab].toLowerCase() == "posts";
                                                          currentPosts = currentPosts.reversed.toList();
                                                          if (currentPosts.isEmpty) {
                                                            return Padding(
                                                              padding: const EdgeInsets.all(40),
                                                              child: Column(
                                                                children: [
                                                                  Icon(Icons.inbox, size: 60, color: kDeepPinkLight),
                                                                  const SizedBox(height: 10),
                                                                  Text(
                                                                    'No${isTabEqualPosts ? "" : " ${tabLabels[selectedTab].toLowerCase()}"} posts yet\nIf this was an Error\nTry Refreshing',
                                                                    textAlign: TextAlign.center,
                                                                    style: TextStyle(
                                                                      fontSize: 16,
                                                                      color: Colors.black.withOpacity(0.7),
                                                                      fontWeight: FontWeight.bold,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                          }

                                                          return GridView.count(
                                                            shrinkWrap: true,
                                                            physics: const NeverScrollableScrollPhysics(),
                                                            crossAxisCount: 2,
                                                            crossAxisSpacing: 10,
                                                            mainAxisSpacing: 5,
                                                            children: currentPosts.map((post) {
                                                              final isVideo = post.mediaUrl.endsWith(".mp4") || post.mediaUrl.endsWith(".mov");
                                                              final displayUrl = isVideo ? post.videoThumbnail ?? post.mediaUrl : post.mediaUrl;

                                                              return GestureDetector(
                                                                onTap: () {
                                                                  context.push("/post/${post.postId}");
                                                                },
                                                                child: Stack(
                                                                  children: [
                                                                    Container(
                                                                      decoration: BoxDecoration(
                                                                        borderRadius: BorderRadius.circular(15),
                                                                        image: DecorationImage(
                                                                          image: CachedNetworkImageProvider(displayUrl),
                                                                          fit: BoxFit.cover,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    if (isVideo)
                                                                      const Center(
                                                                        child: Icon(
                                                                          Icons.play_circle_fill_rounded,
                                                                          color: Colors.white,
                                                                          size: 48,
                                                                        ),
                                                                      ),
                                                                  ],
                                                                ),
                                                              )
                                                                  .animate()
                                                                  .fade(duration: 500.ms, curve: Curves.easeOut)
                                                                  .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 400.ms)
                                                                  .shimmer(duration: 1200.ms, color: Colors.white.withOpacity(0.3));
                                                            }).toList(),
                                                          );
                                                        },
                                                      ),
                                                    ),

                                                    // Add some bottom padding
                                                    const SizedBox(height: 20),
                                                  ],
                                                ),
                                              )
                                            ],
                                          );
                                        },
                                        loading: () => const Center(
                                          child: Padding(
                                            padding: EdgeInsets.all(20),
                                            child: CircularProgressIndicator(
                                              color: kDeepPink,
                                            ),
                                          ),
                                        ),
                                        error: (_, __) => Container(), // Handle error case
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Profile picture
                              if (isOwnProfile)
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: GestureDetector(
                                      onTap: isLoading
                                          ? null
                                          : () {
                                              _updateGroupPicture(currentUserId);
                                            },
                                      child: Stack(
                                        alignment: Alignment.bottomRight,
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2),
                                            ),
                                            child: CircleAvatar(
                                              radius: 40,
                                              backgroundImage: NetworkImage(user.photoUrl),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: kDeepPink,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2),
                                            ),
                                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              if (!isOwnProfile)
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: Container(
                                        height: screenWidth * 0.24,
                                        width: screenWidth * 0.24,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 3,
                                          ),
                                          image: DecorationImage(
                                            image: NetworkImage(user.photoUrl),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
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
        },
        error: (e, st) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go("/error-page/${Uri.encodeComponent(e.toString())}/${Uri.encodeComponent("/profile/$currentUserId")}");
            }
          });
          return const Center(child: Text("An error occurred."));
        },
        loading: () => const Skeletonizer(
              enabled: true,
              child: ProfilePageSkeleton(),
            ));
  }

  Widget _buildStatColumn(int count, String label) {
    return Container(
      width: 115,
      height: 115,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            formatCount(count),
            style: GoogleFonts.lexendDeca(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.lexendDeca(fontSize: 13, color: kDeepPink, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _updateGroupPicture(String currentUserId) async {
    ref.read(imagesOnlyPickerProvider.notifier).clearImage();
    await ref.read(imagesOnlyPickerProvider.notifier).pickAndEditMediaForUpload(context);

    final mediaFile = ref.read(imagesOnlyPickerProvider);
    if (mediaFile == null) return;

    ref.read(profileLoadingProvider.notifier).state = true;

    try {
      final mediaUrl = await ref.read(changePictureProvider.notifier).uploadChatMedia(
            userId: currentUserId,
            mediaFile: mediaFile,
            context: context,
          );

      if (mediaUrl == null) {
        Popup.showError(text: "Failed To edit picture", context: context);
        return;
      }

      await supabase.from('users').update({'photo_url': mediaUrl}).eq('id', currentUserId);
      FirebaseAuth.instance.currentUser!.updatePhotoURL(mediaUrl);

      ref.read(profilePictureProvider.notifier).state = mediaUrl;

      Popup.showSuccess(text: "Picture updated.", context: context);
    } catch (e) {
      Popup.showError(text: "Failed To edit picture", context: context);
    } finally {
      ref.read(imagesOnlyPickerProvider.notifier).clearImage();
      ref.read(profileLoadingProvider.notifier).state = false;
    }
  }
}
