import 'package:flutter/material.dart';

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
            backgroundColor: Colors.grey,
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
                      color: Colors.grey[300],
                    ),
                    Container(
                      height: 10,
                      width: 40,
                      color: Colors.grey[300],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                    height: 12 * 2,
                    width: double.infinity,
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
