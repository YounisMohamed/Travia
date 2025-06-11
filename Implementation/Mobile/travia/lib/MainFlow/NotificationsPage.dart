import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:travia/Helpers/DummyCards.dart';

import '../Helpers/AppColors.dart';
import '../Helpers/DeleteConfirmation.dart';
import '../Helpers/HelperMethods.dart';
import '../Helpers/PopUp.dart';
import '../Providers/NotificationProvider.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Alerts')),
        body: const Center(child: Text('Please log in to see alerts')),
      );
    }

    // Listen to the global notificationsProvider
    final notificationsAsyncValue = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              "Alerts",
              style: GoogleFonts.ibmPlexSans(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              height: 24,
              width: 2,
              color: Colors.grey,
              margin: EdgeInsets.symmetric(horizontal: 8),
            ),
            Image.asset(
              "assets/TraviaLogo.png",
              height: 90,
              width: 90,
            ),
          ],
        ),
        forceMaterialTransparency: true,
        actions: [
          // Mark All as Read Button
          notificationsAsyncValue.when(
            data: (notifications) {
              // Check if there are any unread notifications
              final hasUnreadNotifications = notifications.any((notification) => !notification.isRead);

              if (!hasUnreadNotifications || notifications.isEmpty) {
                return const SizedBox.shrink();
              }

              return Container(
                margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                child: IconButton(
                  onPressed: () async {
                    // Show confirmation dialog using custom dialog function
                    await showCustomDialog(
                      context: context,
                      title: 'Mark All as Read',
                      message: 'Are you sure? This action cannot be undone.',
                      actionText: 'Mark All',
                      actionIcon: Icons.mark_email_read_rounded,
                      actionColor: kDeepPink,
                      onActionPressed: () async {
                        await ref.read(notificationReadProvider.notifier).markAllAsRead(notifications);

                        // Show success message
                        if (context.mounted) {
                          Popup.showSuccess(text: "All alerts marked as read", context: context);
                        }
                      },
                    );
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kDeepPinkLight, kDeepPink],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mark_email_read_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kDeepPinkLight.withOpacity(0.1), kDeepPink.withOpacity(0.1)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_none_rounded,
                      size: 64,
                      color: kDeepPink.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No alerts yet',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your social interactions will appear here',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: notifications.where((notification) => notification.type != "message").length,
            itemBuilder: (context, index) {
              final filteredNotifications = notifications.where((notification) => notification.type != "message").toList();
              final notification = filteredNotifications[index];
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
              ).animate().fadeIn(duration: 120.ms);
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!isRead) {
              ref.read(notificationReadProvider.notifier).markAsRead(notificationId);
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isRead ? Colors.white : Colors.white.withOpacity(0.98),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isRead ? Colors.grey.shade200 : kDeepPink.withOpacity(0.2),
                width: isRead ? 1 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isRead ? Colors.grey.withOpacity(0.08) : kDeepPink.withOpacity(0.12),
                  blurRadius: isRead ? 8 : 16,
                  offset: const Offset(0, 4),
                  spreadRadius: isRead ? 0 : 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [kDeepPinkLight, kDeepPink],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.campaign_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: kDeepPink.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: kDeepPink,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "ANNOUNCEMENT",
                                      style: GoogleFonts.lexendDeca(
                                        color: kDeepPink,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              if (!isRead)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [kDeepPinkLight, kDeepPink],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    "NEW",
                                    style: GoogleFonts.lexendDeca(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "From Travia Team",
                            style: GoogleFonts.lexendDeca(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.grey.shade50 : kDeepPink.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isRead ? Colors.grey.shade200 : kDeepPink.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content,
                        style: GoogleFonts.lexendDeca(
                          fontSize: 15,
                          fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                      if (!isRead) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              size: 16,
                              color: kDeepPink.withOpacity(0.7),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Tap to mark as read",
                              style: GoogleFonts.lexendDeca(
                                fontSize: 12,
                                color: kDeepPink.withOpacity(0.7),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeAgo(createdAt),
                      style: GoogleFonts.lexendDeca(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
      case 'story_like':
        return Icons.favorite_border;
      case 'dislike':
        return Icons.thumb_down_alt;
      case 'comment':
      case 'comment_reply':
        return Icons.chat_bubble_outline;
      case 'follow':
        return Icons.person_add_outlined;
      case 'report':
        return Icons.flag;
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
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: () async {
              if (!isRead) {
                ref.read(notificationReadProvider.notifier).markAsRead(notificationId);
              }

              if (type == "comment" || type == "post" || type == "like" || type == "dislike") {
                context.push('/post/$sourceId');
              } else if (type == 'follow' || type == 'report') {
                context.push('/profile/$sourceId');
              } else if (type == "message") {
                context.push("/messages/$sourceId");
              }
            },
            borderRadius: BorderRadius.circular(16),
            splashColor: kDeepPink.withOpacity(0.1),
            highlightColor: kDeepPinkLight.withOpacity(0.1),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: isRead
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          kDeepPinkLight.withOpacity(0.05),
                          kDeepPink.withOpacity(0.02),
                        ],
                      ),
                color: kBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isRead ? Colors.grey.shade200 : kDeepPink.withOpacity(0.2),
                  width: isRead ? 1 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isRead ? Colors.grey.withOpacity(0.1) : kDeepPink.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                    spreadRadius: 1,
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
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              kDeepPinkLight.withOpacity(0.1),
                              kDeepPink.withOpacity(0.1),
                            ],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey.shade100,
                          backgroundImage: senderPhoto != null ? NetworkImage(senderPhoto!) : null,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [kDeepPinkLight, kDeepPink],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: kDeepPink.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _getIconForType(type),
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),

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
                              height: 1.4,
                            ),
                            children: [
                              if (username != null)
                                TextSpan(
                                  text: username,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isRead ? Colors.black87 : kDeepPink,
                                    fontSize: 16,
                                  ),
                                ),
                              TextSpan(
                                text: username == null ? content : " $content",
                                style: TextStyle(
                                  fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Time ago text with travel-themed styling
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: isRead ? Colors.grey.shade500 : kDeepPinkLight,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeAgo(createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: isRead ? Colors.grey.shade500 : kDeepPinkLight,
                                fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Unread indicator
                  if (!isRead)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [kDeepPinkLight, kDeepPink],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: kDeepPink.withOpacity(0.4),
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
        ));
  }
}
