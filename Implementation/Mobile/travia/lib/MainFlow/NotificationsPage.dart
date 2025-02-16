import 'dart:math';

import 'package:flutter/material.dart';

import '../Helpers/HelperMethods.dart';

class NotificationsPage extends StatefulWidget {
  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

Random random = Random();

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> notifications = [
    {
      "id": "1",
      "target_user_id": "user_123",
      "type": "like",
      "content": "Younis liked your post",
      "created_at": DateTime.now().subtract(Duration(minutes: 5)),
      "is_read": false,
      "source_id": "post_456",
      "sender_user_id": "user_789",
      "sender_name": "John",
      "sender_photo": "https://lh3.googleusercontent.com/a/ACg8ocKstmlfI0S9ZjDG-7UCvToQOhYVIz7YX9bUJpsSNdT7XoKVsgc=s96-c" // Placeholder image
    },
    {
      "id": "2",
      "target_user_id": "user_123",
      "type": "comment",
      "content": "Sarah commented on your photo",
      "created_at": DateTime.now().subtract(Duration(hours: 1)),
      "is_read": false,
      "source_id": "post_123",
      "sender_user_id": "user_456",
      "sender_name": "Sarah",
      "sender_photo": "https://randomuser.me/api/portraits/women/${1 + random.nextInt((20 + 1) - 1)}.jpg" // Placeholder image
    },
    {
      "id": "3",
      "target_user_id": "user_123",
      "type": "follow",
      "content": "Michael started following you",
      "created_at": DateTime.now().subtract(Duration(days: 1)),
      "is_read": true,
      "source_id": null,
      "sender_user_id": "user_654",
      "sender_name": "Michael",
      "sender_photo": "https://randomuser.me/api/portraits/men/${1 + random.nextInt((20 + 1) - 1)}.jpg" // Placeholder image
    }
  ];

  void markAsRead(int index) {
    setState(() {
      notifications[index]["is_read"] = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Notifications",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(notification["sender_photo"]),
            ),
            title: Text(
              notification["content"],
              style: TextStyle(
                fontWeight: notification["is_read"] ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            subtitle: Text(timeAgo(notification["created_at"])),
            trailing: notification["is_read"]
                ? null
                : Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
            onTap: () => markAsRead(index),
          );
        },
      ),
    );
  }
}
