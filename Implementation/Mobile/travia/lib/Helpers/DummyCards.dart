import 'dart:math';

import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'Constants.dart';

class DummyPostCard extends StatelessWidget {
  const DummyPostCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Info Section (Skeleton)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[300], // Placeholder color
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        // Placeholder for name
                        height: 16,
                        width: 100,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        // Placeholder for time
                        height: 12,
                        width: 60,
                        color: Colors.grey[300],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // Post Image Section (Skeleton)
          Container(
            height: 300,
            color: Colors.grey[300], // Placeholder color
          ),

          // Like, Comment, and Share Section (Skeleton)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      // Placeholder for like icon
                      radius: 14,
                      backgroundColor: Colors.grey[300],
                    ),
                    const SizedBox(width: 8),
                    Container(
                      // Placeholder for like count
                      height: 16,
                      width: 40,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(width: 20),
                    CircleAvatar(
                      // Placeholder for comment icon
                      radius: 14,
                      backgroundColor: Colors.grey[300],
                    ),
                    const SizedBox(width: 8),
                    Container(
                      // Placeholder for comment count
                      height: 16,
                      width: 40,
                      color: Colors.grey[300],
                    ),
                  ],
                ),

                // Share Button (Skeleton)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[300], // Placeholder color
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Container(
                    // Placeholder for share text
                    height: 16,
                    width: 60,
                    color: Colors.grey[300],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DummyCommentCard extends StatelessWidget {
  const DummyCommentCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: contrastCommentCardColor, // Placeholder color
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Image (Skeleton)
          CircleAvatar(
            radius: 20,
            backgroundColor: contrastCommentCardColor, // Slightly darker placeholder
          ),
          const SizedBox(width: 10),

          // Comment Content (Skeleton)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username & Timestamp (Skeleton)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      // Username placeholder
                      height: 14,
                      width: 80,
                      color: contrastCommentCardColor,
                    ),
                    Container(
                      // Timestamp placeholder
                      height: 12,
                      width: 60,
                      color: contrastCommentCardColor,
                    ),
                  ],
                ),

                // Comment Text (Skeleton)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Container(
                    height: 14 * 3, // Simulate 3 lines of text
                    width: double.infinity,
                    color: contrastCommentCardColor,
                  ),
                ),

                // Like Count & Like Button (Skeleton)
                Row(
                  children: [
                    CircleAvatar(
                      // Like icon placeholder
                      radius: 11,
                      backgroundColor: contrastCommentCardColor,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      // Like count placeholder
                      height: 12,
                      width: 30,
                      color: contrastCommentCardColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DummyChatCard extends StatelessWidget {
  const DummyChatCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white70,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      height: 12,
                      width: 60,
                      color: Colors.grey[200],
                    ),
                    Container(
                      height: 10,
                      width: 40,
                      color: Colors.grey[200],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                    height: 12 * 2,
                    width: double.infinity,
                    color: Colors.grey[200],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DummyMessageBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final random = Random();
    final isCurrentUser = random.nextBool(); // Randomly switch sides

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300], // Placeholder color
            ),
            SizedBox(width: 8),
          ],
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.6, // Smaller for better placeholder effect
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white70,
              borderRadius: BorderRadius.circular(20).copyWith(
                bottomLeft: isCurrentUser ? Radius.circular(20) : Radius.circular(0),
                bottomRight: isCurrentUser ? Radius.circular(0) : Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isCurrentUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Container(
                      // Placeholder username
                      width: 80, // Adjust width as needed
                      height: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                Container(
                  //Placeholder message content
                  width: double.infinity,
                  height: 12,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      //Placeholder time
                      width: 40,
                      height: 10,
                      color: Colors.grey[400],
                    ),
                    if (isCurrentUser) ...[
                      SizedBox(width: 4),
                      Icon(
                        Icons.done_all, // Placeholder icon
                        size: 14,
                        color: Colors.grey[400],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatAppBarSkeleton extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBarSkeleton({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      containersColor: Colors.white,
      child: AppBar(
        forceMaterialTransparency: true,
        elevation: 0,
        title: Row(
          children: [
            // Fake avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fake username/title
                  Container(
                    width: 150,
                    height: 16,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 4),
                  // Fake subtitle
                  Container(
                    width: 100,
                    height: 12,
                    color: Colors.grey.shade300,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Icon(Icons.more_vert, color: Colors.transparent),
          ),
        ],
      ),
    );
  }
}
