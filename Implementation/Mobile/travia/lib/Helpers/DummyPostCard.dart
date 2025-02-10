import 'package:flutter/material.dart';

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
