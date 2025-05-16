import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:travia/Helpers/DummyCards.dart';
import 'package:travia/Helpers/GoogleTexts.dart';

import '../Classes/Post.dart';
import '../Helpers/AppColors.dart';
import '../Providers/ConversationProvider.dart';
import '../Providers/ProfileProviders.dart';

class ProfilePage extends ConsumerWidget {
  final String profileUserId;
  const ProfilePage({
    required this.profileUserId,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom + 45;
    final userAsync = ref.watch(userStreamProvider(profileUserId));
    final isOwnProfile = profileUserId == currentUserId;
    final tabLabels = isOwnProfile ? ['Posts', 'Liked', 'Viewed', 'Saved'] : ['Posts', 'Liked'];
    final selectedTab = ref.watch(selectedPostTabProvider);

    return userAsync.when(
        data: (user) {
          final List<AsyncValue<List<Post>>> postLists = [
            ref.watch(filteredPostsProvider(user.uploadedPosts)),
            ref.watch(filteredPostsProvider(user.likedPosts)),
            if (isOwnProfile) ref.watch(filteredPostsProvider(user.viewedPosts)),
            if (isOwnProfile) ref.watch(filteredPostsProvider(user.savedPosts)),
          ];
          final currentPostsAsync = postLists[selectedTab];

          return Scaffold(
            body: Stack(
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
                      // Navigation bar
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.02),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: screenWidth * 0.12,
                              width: screenWidth * 0.12,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(screenWidth * 0.06),
                              ),
                              child: const Icon(
                                Icons.more_horiz,
                                color: kDeepPink,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.02),

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
                                color: kDeepGrey,
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
                                          _buildStatColumn(user.friendIds.length.toString(), 'Friends'),
                                          _buildStatColumn(user.followingIds.length.toString(), 'Following'),
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

                                    Text(
                                      user.bio ?? "No Bio",
                                      style: TextStyle(
                                        fontSize: 16,
                                      ),
                                    ),

                                    SizedBox(height: screenHeight * 0.02),

                                    Text(
                                      '${user.age} | ${user.relationshipStatus}',
                                      style: TextStyle(
                                        fontSize: 14,
                                      ),
                                    ),

                                    SizedBox(height: screenHeight * 0.02),

                                    // Follow - Message
                                    if (currentUserId != profileUserId)
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                                        child: Row(
                                          children: [
                                            Consumer(
                                              builder: (context, ref, _) {
                                                final isFollowing = ref.watch(followStatusProvider(profileUserId));
                                                final notifier = ref.read(followStatusProvider(profileUserId).notifier);

                                                return Expanded(
                                                  child: GestureDetector(
                                                    onTap: notifier.toggleFollow,
                                                    child: Container(
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
                                                        child: Text(
                                                          isFollowing ? 'Following' : 'Follow',
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
                                                  final conversationId = await ref.read(createConversationProvider(profileUserId).future);
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
                                    if (currentUserId == profileUserId)
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.2),
                                        child: Row(
                                          children: [
                                            Expanded(
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
                                          ],
                                        ),
                                      ),
                                    SizedBox(height: screenHeight * 0.02),

                                    // Posts section

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
                                              children: List.generate(tabLabels.length, (index) {
                                                final isSelected = selectedTab == index;
                                                return GestureDetector(
                                                  onTap: () => ref.read(selectedPostTabProvider.notifier).state = index,
                                                  child: Column(
                                                    children: [
                                                      Text(
                                                        tabLabels[index],
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

                                          // Grid items
                                          Padding(
                                            padding: const EdgeInsets.all(10),
                                            child: currentPostsAsync.when(
                                              loading: () => GridView.count(
                                                shrinkWrap: true,
                                                physics: const NeverScrollableScrollPhysics(),
                                                crossAxisCount: 2,
                                                crossAxisSpacing: 10,
                                                mainAxisSpacing: 10,
                                                children: List.generate(6, (index) {
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
                                                child: IBMPlexSansText(
                                                  text: "Error loading posts",
                                                  size: 25,
                                                ),
                                              ),
                                              data: (currentPosts) {
                                                if (currentPosts.isEmpty) {
                                                  return Column(
                                                    children: [
                                                      const SizedBox(height: 50),
                                                      Icon(Icons.inbox, size: 60, color: kDeepPinkLight),
                                                      const SizedBox(height: 10),
                                                      Text(
                                                        'No ${tabLabels[selectedTab].toLowerCase()} posts yet.',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          color: Colors.black.withOpacity(0.7),
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                }

                                                return GridView.count(
                                                  shrinkWrap: true,
                                                  physics: const NeverScrollableScrollPhysics(),
                                                  crossAxisCount: 2,
                                                  crossAxisSpacing: 10,
                                                  mainAxisSpacing: 10,
                                                  children: currentPosts.map((post) {
                                                    return GestureDetector(
                                                      onTap: () {
                                                        context.push("/post/${post.postId}");
                                                      },
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.circular(15),
                                                          image: DecorationImage(
                                                            image: CachedNetworkImageProvider(post.mediaUrl),
                                                            fit: BoxFit.cover,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                );
                                              },
                                            ),
                                          ),

                                          // Extra bottom padding to ensure visibility above bottom nav bar
                                          SizedBox(height: MediaQuery.of(context).padding.bottom + 90),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),

                            // Profile picture
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Center(
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
                            SizedBox(height: bottomPadding),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        error: (e, st) => Center(child: Text('Error: $e')),
        loading: () => const Skeletonizer(
              enabled: true,
              child: ProfilePageSkeleton(),
            ));
  }

  Widget _buildStatColumn(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
