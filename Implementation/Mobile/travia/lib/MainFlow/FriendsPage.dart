import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:travia/Helpers/AppColors.dart';
import 'package:travia/Helpers/PopUp.dart';

import '../Classes/UserSupabase.dart';
import '../Helpers/DeleteConfirmation.dart';
import '../Helpers/Loading.dart';
import '../Providers/friendsProvider.dart';
import '../Services/FollowService.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  final String userIdOfCurrentFriendsList; // the user going to the friends page, this is to prevent users that came from someone's profile page to follow and unfollow
  const FriendsScreen({super.key, this.initialIndex = 0, required this.userIdOfCurrentFriendsList});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  late PageController _pageController = PageController();
  late int _currentIndex;
  @override
  void initState() {
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    super.initState();
  }

  void _onTabTap(int index) {
    if (_currentIndex != index) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  @override
  Widget build(BuildContext context) {
    final friendsDataAsync = ref.watch(friendsDataProvider(widget.userIdOfCurrentFriendsList));
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        forceMaterialTransparency: true,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Image.asset(
              "assets/TraviaLogo.png",
              height: 90,
              width: 90,
            ),
          ],
        ),
      ),
      body: friendsDataAsync.when(
        data: (friendsData) => Column(
          children: [
            // Tab buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: currentUserId == widget.userIdOfCurrentFriendsList ? MainAxisAlignment.center : MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTabButton("Following", 0, Icons.add),
                  const SizedBox(width: 12),
                  _buildTabButton("Followers", 1, Icons.people),
                  if (currentUserId == widget.userIdOfCurrentFriendsList) const SizedBox(width: 12),
                  if (currentUserId == widget.userIdOfCurrentFriendsList) _buildTabButton("Discover", 2, Icons.explore),
                ],
              ),
            ),

            // Tab views
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                children: [
                  _buildFollowingTab(following: friendsData.following),
                  _buildFollowersTab(followers: friendsData.followers),
                  if (currentUserId == widget.userIdOfCurrentFriendsList) _buildDiscoverTab(users: friendsData.discoverUsers),
                ],
              ),
            ),
          ],
        ),
        loading: () => const Center(
            child: LoadingWidget(
          size: 32,
        )),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading friends data',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(friendsDataProvider(currentUserId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index, IconData icon) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTap(index),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isActive ? [kDeepPink.withOpacity(0.8), kDeepPinkLight] : [Colors.white, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: kDeepPink.withOpacity(0.25),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(
          children: [
            Icon(icon),
            SizedBox(
              width: 4,
            ),
            Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendCard({
    required String userId, // Add userId parameter
    required String displayName,
    required String userName,
    required String birthDate,
    required String photoUrl,
    required bool isDiscoverCard,
    required FriendCardType cardType, // Add enum to specify card type
  }) {
    return Consumer(
      builder: (context, ref, child) {
        // Watch loading state
        final isActionLoading = ref.watch(isFollowLoadingProvider(userId));

        // Get the follow controller
        final followController = ref.read(followControllerProvider);

        final currentUserId = FirebaseAuth.instance.currentUser!.uid;
        bool isOwnProfile = currentUserId == widget.userIdOfCurrentFriendsList;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              GestureDetector(
                onTap: () => context.push('/profile/$userId'),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFBBDEFB),
                  backgroundImage: CachedNetworkImageProvider(photoUrl),
                ),
              ),
              const SizedBox(width: 16),

              // Friend info
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/profile/$userId'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "@$userName",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: kDeepPink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        birthDate,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action button
              if (isOwnProfile)
                _buildActionButton(
                  context: context,
                  isLoading: isActionLoading,
                  followController: followController,
                  userId: userId,
                  userName: userName,
                  cardType: cardType,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required bool isLoading,
    required FollowController followController,
    required String userId,
    required String userName,
    required FriendCardType cardType,
  }) {
    String buttonText;

    switch (cardType) {
      case FriendCardType.discover:
        buttonText = 'Follow';
        break;
      case FriendCardType.following:
        buttonText = 'Unfollow';
        break;
      case FriendCardType.follower:
        buttonText = 'Remove';
        break;
    }

    return SizedBox(
      width: 100,
      height: 36,
      child: ElevatedButton(
        onPressed: isLoading ? null : () => _handleButtonPress(context: context, followController: followController, userId: userId, userName: userName, cardType: cardType, ref: ref),
        style: ElevatedButton.styleFrom(
          backgroundColor: kDeepPink,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
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
                buttonText,
                style: GoogleFonts.lexendDeca(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
              ),
      ),
    );
  }

// Handle button press
  Future<void> _handleButtonPress({
    required BuildContext context,
    required FollowController followController,
    required String userId,
    required String userName,
    required FriendCardType cardType,
    required WidgetRef ref,
  }) async {
    try {
      switch (cardType) {
        case FriendCardType.discover:
          final result = await followController.toggleFollow(userId);
          ref.invalidate(friendsDataProvider);

          if (!result.isSuccess && context.mounted) {
            if (result.isBlocked) {
              Popup.showError(
                text: "Cannot follow @$userName: Blocked relationship exists",
                context: context,
              );
            } else {
              Popup.showError(
                text: result.errorMessage ?? "Failed to follow user",
                context: context,
              );
            }
          }
          break;

        case FriendCardType.following:
          final shouldUnfollow = await _showUnfollowDialog(context, userName);
          if (shouldUnfollow) {
            final result = await followController.toggleFollow(userId);
            ref.invalidate(friendsDataProvider);
            if (!result.isSuccess && context.mounted) {
              Popup.showError(
                text: "Failed to unfollow @$userName",
                context: context,
              );
            }
          }
          break;

        case FriendCardType.follower:
          final shouldRemove = await _showRemoveFollowerDialog(context, userName);
          if (shouldRemove) {
            final result = await followController.removeFollower(userId);
            ref.invalidate(friendsDataProvider);
            if (!result.isSuccess && context.mounted) {
              Popup.showError(
                text: "Failed to remove @$userName",
                context: context,
              );
            }
          }
          break;
      }
    } catch (e) {
      print('Button action error: $e');
      if (context.mounted) {
        Popup.showError(
          text: "An error occurred",
          context: context,
        );
      }
    }
  }

// Simplified dialog methods using custom dialog
  Future<bool> _showUnfollowDialog(BuildContext context, String userName) async {
    bool result = false;

    await showCustomDialog(
      context: context,
      title: "Unfollow @$userName?",
      message: "Are you sure you want to unfollow this user? You can follow them again anytime.",
      actionText: "Unfollow",
      actionIcon: Icons.person_remove,
      onActionPressed: () async {
        result = true;
      },
    );

    return result;
  }

  Future<bool> _showRemoveFollowerDialog(BuildContext context, String userName) async {
    bool result = false;

    await showCustomDialog(
      context: context,
      title: "Remove @$userName?",
      message: "This will remove them from your followers. They won't be notified about this action.",
      actionText: "Remove",
      actionIcon: Icons.block,
      onActionPressed: () async {
        result = true;
      },
    );

    return result;
  }

  Widget _buildDiscoverTab({required List<UserModel> users}) {
    return Consumer(
      builder: (context, ref, _) {
        // Watch the filtered users instead of the raw users list
        final searchQuery = ref.watch(searchQueryProvider);
        final filteredUsers = filterUsers(users, searchQuery);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  prefixIcon: const Icon(Icons.search, color: kDeepPink),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white),
                          onPressed: () {
                            ref.read(searchQueryProvider.notifier).state = '';
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  hintStyle: const TextStyle(color: Colors.black),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: kDeepPink, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: kDeepPink, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: kDeepPink, width: 1),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (query) {
                  // Update search query using Riverpod
                  ref.read(searchQueryProvider.notifier).state = query;
                },
              ),
            ),

            // Search results info
            if (searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey[600], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Found ${filteredUsers.length} result${filteredUsers.length == 1 ? '' : 's'} for "$searchQuery"',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: filteredUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            searchQuery.isNotEmpty ? Icons.search_off : Icons.people_outline,
                            size: 64,
                            color: kDeepPink,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            searchQuery.isNotEmpty ? 'No users found for "$searchQuery"' : 'You followed everyone!',
                            style: GoogleFonts.lexendDeca(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (searchQuery.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Try searching with different keywords',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        return _buildFriendCard(
                          userId: user.id,
                          displayName: user.displayName,
                          userName: user.username,
                          birthDate: "${user.age.day}/${user.age.month}/${user.age.year}",
                          photoUrl: user.photoUrl,
                          isDiscoverCard: true,
                          cardType: FriendCardType.discover,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFollowersTab({required List<UserModel> followers}) {
    if (followers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: kDeepPink),
            SizedBox(height: 16),
            Text(
              'No followers yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start connecting with people!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: followers.length,
      itemBuilder: (context, index) {
        final follower = followers[index];
        return _buildFriendCard(
          userId: follower.id,
          displayName: follower.displayName,
          userName: follower.username,
          birthDate: "${follower.age.day}/${follower.age.month}/${follower.age.year}",
          photoUrl: follower.photoUrl,
          isDiscoverCard: false,
          cardType: FriendCardType.follower,
        );
      },
    );
  }

  Widget _buildFollowingTab({required List<UserModel> following}) {
    if (following.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: kDeepPink),
            SizedBox(height: 16),
            Text(
              'No following yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Go to discover to start following people!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: following.length,
      itemBuilder: (context, index) {
        final user = following[index];
        return _buildFriendCard(
          userId: user.id,
          displayName: user.displayName,
          userName: user.username,
          birthDate: "${user.age.day}/${user.age.month}/${user.age.year}",
          photoUrl: user.photoUrl,
          isDiscoverCard: false,
          cardType: FriendCardType.following,
        );
      },
    );
  }
}

// Enum to specify the type of friend card
enum FriendCardType {
  discover,
  following,
  follower,
}
