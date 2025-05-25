import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travia/Helpers/AppColors.dart';
import 'package:travia/Helpers/PopUp.dart';

import '../Classes/UserSupabase.dart';
import '../Helpers/DeleteConfirmation.dart';
import '../Helpers/Loading.dart';
import '../Providers/friendsProvider.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  void _onTabTap(int index) {
    if (_currentIndex != index) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  final String userId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    final friendsDataAsync = ref.watch(friendsDataProvider(userId));

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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTabButton("Followers", 0),
                  const SizedBox(width: 12),
                  _buildTabButton("Following", 1),
                  const SizedBox(width: 12),
                  _buildTabButton("Discover", 2),
                ],
              ),
            ),

            // Tab views
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                children: [
                  // Followers Tab
                  _buildFollowersTab(followers: friendsData.followers),
                  // Following Tab
                  _buildFollowingTab(following: friendsData.following),
                  // Discover Tab
                  _buildDiscoverTab(users: friendsData.discoverUsers),
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
                onPressed: () => ref.refresh(friendsDataProvider(userId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTap(index),
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE91E63) : Colors.grey[200],
          borderRadius: BorderRadius.circular(25),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

Widget _buildDiscoverTab({required List<UserModel> users}) {
  return Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search users...',
            prefixIcon: const Icon(Icons.search, color: Colors.white),
            filled: true,
            fillColor: kDeepPink,
            hintStyle: const TextStyle(color: Colors.white70),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: (query) {
            // TODO: Implement search logic
          },
        ),
      ),
      Expanded(
        child: users.isEmpty
            ? const Center(
                child: Text(
                  'No results found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
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
      // Watch if this user's action is in progress
      final isActionLoading = ref.watch(isActionInProgressProvider(userId));

      // Get action functions
      final followUser = ref.read(followUserProvider);
      final unfollowUser = ref.read(unfollowUserProvider);
      final removeFollower = ref.read(removeFollowerProvider);

      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

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
              onTap: () {
                context.push('/profile/$userId');
              },
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
                onTap: () {
                  context.push('/profile/$userId');
                },
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
            // Action button (Follow/Delete)
            ElevatedButton(
              onPressed: isActionLoading
                  ? null
                  : () async {
                      try {
                        switch (cardType) {
                          case FriendCardType.discover:
                            await followUser(currentUserId, userId);
                            break;
                          case FriendCardType.following:
                            await _showUnfollowDialog(context, userName, () => unfollowUser(currentUserId, userId));
                            break;
                          case FriendCardType.follower:
                            await _showRemoveFollowerDialog(context, userName, () => removeFollower(currentUserId, userId));
                            break;
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Popup.showError(text: "Error happened while following", context: context);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: kDeepPink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: isActionLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _getButtonText(cardType),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ],
        ),
      );
    },
  );
}

// Helper method to get button text based on card type
String _getButtonText(FriendCardType cardType) {
  switch (cardType) {
    case FriendCardType.discover:
      return "Follow";
    case FriendCardType.following:
      return "Unfollow";
    case FriendCardType.follower:
      return "Remove";
  }
}

// Helper method to show unfollow confirmation dialog
Future<void> _showUnfollowDialog(
  BuildContext context,
  String userName,
  VoidCallback onConfirm,
) async {
  await showCustomDialog(
    context: context,
    title: 'Unfollow User',
    message: 'Are you sure you want to unfollow @$userName?',
    actionText: 'Unfollow',
    actionIcon: Icons.person_remove_alt_1_outlined,
    onActionPressed: () async {
      onConfirm();
    },
  );
}

Future<void> _showRemoveFollowerDialog(
  BuildContext context,
  String userName,
  VoidCallback onConfirm,
) async {
  await showCustomDialog(
    context: context,
    title: 'Remove Follower',
    message: 'Are you sure you want to remove @$userName from your followers?',
    actionText: 'Remove',
    actionIcon: Icons.person_remove_outlined,
    onActionPressed: () async {
      onConfirm();
    },
  );
}

// Enum to specify the type of friend card
enum FriendCardType {
  discover,
  following,
  follower,
}
