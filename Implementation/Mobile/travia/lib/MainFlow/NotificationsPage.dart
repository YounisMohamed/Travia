import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:travia/Helpers/DummyCards.dart';

import '../Helpers/HelperMethods.dart';
import '../Providers/NotificationProvider.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please log in to see notifications')),
      );
    }

    // Listen to the global notificationsProvider
    final notificationsAsyncValue = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        forceMaterialTransparency: true,
      ),
      body: notificationsAsyncValue.when(
        loading: () => Skeletonizer(
          ignoreContainers: true,
          child: ListView.builder(
            itemCount: 5,
            itemBuilder: (context, index) => DummyCommentCard(),
          ),
        ),
        error: (error, stack) {
          print(error);
          print(stack);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go("/error-page/${Uri.encodeComponent(error.toString())}/${Uri.encodeComponent("/notifications")}");
            }
          });
          return const Center(child: Text("An error occurred."));
        },
        data: (notifications) {
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
                username: notification.senderUsername,
                content: notification.content,
                isRead: notification.isRead,
                createdAt: notification.createdAt,
                notificationId: notification.id,
                targetUserId: notification.targetUserId,
                type: notification.type,
                sourceId: notification.sourceId,
                senderUserId: notification.senderUserId,
                ref: ref,
              ).animate().fadeIn(duration: 120.ms, delay: 120.ms);
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
  final bool isRead;
  final DateTime createdAt;
  final String notificationId;
  final String? targetUserId;
  final String type;
  final String? sourceId;
  final String? senderUserId;
  final String? username;
  final WidgetRef ref;

  const NotificationTile({
    super.key,
    this.senderPhoto,
    this.username,
    required this.content,
    required this.isRead,
    required this.createdAt,
    required this.notificationId,
    required this.targetUserId,
    required this.type,
    required this.sourceId,
    required this.senderUserId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final isAnnouncement = type.toLowerCase() == 'announcement';

    return isAnnouncement
        ? AnnouncementNotificationTile(
            content: content,
            isRead: isRead,
            createdAt: createdAt,
            notificationId: notificationId,
            ref: ref,
          )
        : StandardNotificationTile(
            senderPhoto: senderPhoto,
            content: content,
            isRead: isRead,
            createdAt: createdAt,
            notificationId: notificationId,
            senderUserId: senderUserId,
            username: username,
            sourceId: sourceId,
            type: type,
            ref: ref,
          );
  }
}

class AnnouncementNotificationTile extends StatelessWidget {
  final String content;
  final bool isRead;
  final DateTime createdAt;
  final String notificationId;
  final WidgetRef ref;

  const AnnouncementNotificationTile({
    super.key,
    required this.content,
    required this.isRead,
    required this.createdAt,
    required this.notificationId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
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
        splashColor: Colors.purple.withOpacity(0.1),
        highlightColor: Colors.grey.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.purple.shade100, Colors.blue.shade50],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.purple.shade200, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(isRead ? 0.1 : 0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200, width: 1),
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
              Text(
                content,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.purple.shade900,
                ),
              ),
              if (!isRead)
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
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
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class StandardNotificationTile extends StatelessWidget {
  final String? senderPhoto;
  final String content;
  final bool isRead;
  final DateTime createdAt;
  final String notificationId;
  final String? senderUserId;
  final String? username;
  final String type;
  final String? sourceId;
  final WidgetRef ref;

  const StandardNotificationTile({
    super.key,
    this.senderPhoto,
    this.username,
    required this.content,
    required this.isRead,
    required this.createdAt,
    required this.notificationId,
    required this.senderUserId,
    this.sourceId,
    required this.type,
    required this.ref,
  });

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
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notificationId),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        ref.read(notificationReadProvider.notifier).removeNotification(notificationId);
        return true;
      },
      background: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 15),
            child: Icon(
              Icons.delete,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          onTap: () {
            if (!isRead) {
              ref.read(notificationReadProvider.notifier).markAsRead(notificationId);
            }
            if (type == "comment" || type == "post" || type == "like") {
              context.push('/post/$sourceId');
            } else if (type == "message") {
              context.push("/messages/$sourceId");
            }
          },
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.blue.withOpacity(0.1),
          highlightColor: Colors.grey.withOpacity(0.1),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isRead ? Colors.white : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isRead ? Colors.grey.shade200 : Colors.blue.shade100,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(isRead ? 0.1 : 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile picture with notification type icon
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: senderPhoto != null ? NetworkImage(senderPhoto!) : null,
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

                // Notification content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 15,
                            height: 1.3,
                          ),
                          children: [
                            if (username != null)
                              TextSpan(
                                text: username,
                                style: TextStyle(
                                  fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                  color: isRead ? Colors.black87 : Colors.black,
                                ),
                              ),
                            TextSpan(
                              text: username == null ? content : " $content",
                              style: TextStyle(
                                fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Time ago text
                      const SizedBox(height: 4),
                      Text(
                        timeAgo(createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
