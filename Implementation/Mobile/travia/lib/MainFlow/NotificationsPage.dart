import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:travia/Helpers/DummyCards.dart';
import 'package:travia/MainFlow/HomePage.dart';

import '../Classes/Notification.dart';
import '../Helpers/DefaultText.dart';
import '../Helpers/HelperMethods.dart';
import '../Providers/NotificationProvider.dart';
import '../main.dart';

class NotificationsPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please log in to see notifications')),
      );
    }
    final currentUserId = user.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        forceMaterialTransparency: true,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase.from('notifications').stream(primaryKey: ['id']).order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return Skeletonizer(
              ignoreContainers: true,
              child: ListView.builder(
                itemCount: 5,
                itemBuilder: (context, index) => DummyCommentCard(),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final rawNotifications = snapshot.data ?? [];
          final notifications = rawNotifications.map((json) => NotificationModel.fromMap(json)).where((n) => n.targetUserId == currentUserId || n.targetUserId == null).toList();

          if (notifications.isEmpty) {
            return const Center(
              child: Text(
                'No notifications yet',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return NotificationTile(
                senderPhoto: notification.senderPhoto,
                displayName: notification.displayName,
                content: notification.content,
                is_read: notification.isRead, // Initial DB value
                createdAt: notification.createdAt,
                notificationId: notification.id,
                targetUserId: notification.targetUserId,
                type: notification.type,
                sourceId: notification.sourceId,
                senderUserId: notification.senderUserId,
                ref: ref,
              );
            },
          );
        },
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  final String? senderPhoto;
  final String content;
  final bool is_read;
  final DateTime createdAt;
  final String notificationId;
  final String? targetUserId;
  final String type;
  final String? sourceId;
  final String? senderUserId;
  final String? displayName;
  final WidgetRef ref;

  const NotificationTile({
    super.key,
    this.senderPhoto,
    this.displayName,
    required this.content,
    required this.is_read,
    required this.createdAt,
    required this.notificationId,
    required this.targetUserId,
    required this.type,
    required this.sourceId,
    required this.senderUserId,
    required this.ref,
  });

  // Icon based on notification type
  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'like':
        return Icons.favorite_border;
      case 'comment':
      case 'comment_reply':
        return Icons.chat_bubble_outline;
      case 'follow':
        return Icons.person_add_outlined;
      case 'mention':
        return Icons.alternate_email;
      case 'message':
        return Icons.message_outlined;
      case 'announcement':
      case 'system':
        return Icons.notifications_none;
      default:
        return Icons.circle; // Default small dot
    }
  }

  @override
  Widget build(BuildContext context) {
    final readStates = ref.watch(notificationReadProvider);
    final isRead = readStates[notificationId] ?? is_read;
    final isAnnouncement = type.toLowerCase() == 'announcement';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () {
          if (!isRead) {
            ref.read(notificationReadProvider.notifier).markAsRead(notificationId);
          }
        },
        borderRadius: BorderRadius.circular(14),
        splashColor: Colors.blue.withOpacity(0.1),
        highlightColor: Colors.grey.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: isAnnouncement
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.purple.shade100,
                      Colors.blue.shade50,
                    ],
                  )
                : null,
            color: isAnnouncement ? null : (isRead ? Colors.white : Colors.blue.shade50),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isAnnouncement ? Colors.purple.shade200 : (isRead ? Colors.grey.shade200 : Colors.blue.shade100),
              width: isAnnouncement ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (isAnnouncement ? Colors.purple : Colors.grey).withOpacity(isRead ? 0.1 : 0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Special Icon for Announcements
              if (isAnnouncement)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.purple.shade200, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.2),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.campaign_outlined,
                    size: 32,
                    color: Colors.purple.shade700,
                  ),
                )
              else
                // Regular Profile Picture with Type Icon
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: NetworkImage(senderPhoto ?? dummyImageUrl),
                    ),
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300, width: 1),
                      ),
                      child: Icon(
                        _getIconForType(type),
                        size: 14,
                        color: isRead ? Colors.grey : Colors.blue,
                      ),
                    ),
                  ],
                ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isAnnouncement)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.purple.shade200,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          "ANNOUNCEMENT",
                          style: TextStyle(
                            color: Colors.purple.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    RichText(
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: TextStyle(
                          color: isAnnouncement ? Colors.purple.shade900 : Colors.black87,
                          fontSize: isAnnouncement ? 16 : 15,
                          height: 1.3,
                        ),
                        children: [
                          if (displayName != null && !isAnnouncement)
                            TextSpan(
                              text: displayName,
                              style: TextStyle(
                                fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                color: isRead ? Colors.black87 : Colors.black,
                              ),
                            ),
                          TextSpan(
                            text: displayName == null || isAnnouncement ? content : " $content",
                            style: TextStyle(
                              fontWeight: isAnnouncement ? FontWeight.w500 : (isRead ? FontWeight.normal : FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Timestamp for announcements
                    if (!isAnnouncement)
                      DefaultText(
                        text: timeAgo(createdAt),
                        size: 11,
                      ),
                  ],
                ),
              ),

              // Special indicator for unread announcements
              if (isAnnouncement && !isRead)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.purple.shade400,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
