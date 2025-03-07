import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../Classes/MessageDetails.dart';

class ChatPage extends StatefulWidget {
  ChatPage({Key? key}) : super(key: key);

  // Dummy data for the chat
  final String currentUserId = "user1";
  final String conversationId = "conv123";
  final String conversationTitle = "TODO: CHAT PAGE";

  // Dummy messages
  final List<MessageDetails> messages = [
    MessageDetails(
      messageId: "msg1",
      content: "Hey everyone! How's the Flutter project coming along?",
      senderId: "user1",
      senderName: "Alex",
      senderProfilePic: "https://ui-avatars.com/api/?name=Ke&rounded=true&background=random",
      sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      isCurrentUser: true,
      isRead: true,
    ),
    MessageDetails(
      messageId: "msg2",
      content: "Making good progress! Just finished implementing the authentication flow.",
      senderId: "user2",
      senderName: "Taylor",
      senderProfilePic: "https://ui-avatars.com/api/?name=Mi&rounded=true&background=random",
      sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 1, minutes: 45)),
      isCurrentUser: false,
      isRead: true,
    ),
    MessageDetails(
      messageId: "msg3",
      content: "Nice! I'm still working on the UI components. The animations are a bit tricky.",
      senderId: "user3",
      senderName: "Jordan",
      senderProfilePic: "https://ui-avatars.com/api/?name=Mi&rounded=true&background=random",
      sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 1, minutes: 30)),
      isCurrentUser: false,
      isRead: true,
    ),
    MessageDetails(
      messageId: "msg4",
      content: "Have you tried using the AnimationController with Tween? It worked great for my last project.",
      senderId: "user2",
      senderName: "Taylor",
      senderProfilePic: "https://ui-avatars.com/api/?name=Yo&rounded=true&background=random",
      sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
      isCurrentUser: false,
      isRead: true,
    ),
    MessageDetails(
      messageId: "msg5",
      content: "Good suggestion, I'll try that out. Also, anyone having issues with the new Flutter update?",
      senderId: "user1",
      senderName: "Alex",
      senderProfilePic: "https://ui-avatars.com/api/?name=Ke&rounded=true&background=random",
      sentAt: DateTime.now().subtract(const Duration(minutes: 45)),
      isCurrentUser: true,
      isRead: true,
    ),
    MessageDetails(
      messageId: "msg6",
      content: "I had some migration issues but fixed them by updating the dependencies. I can share my pubspec.yaml if you need it.",
      senderId: "user3",
      senderName: "Jordan",
      senderProfilePic: "https://ui-avatars.com/api/?name=Mi&rounded=true&background=random",
      sentAt: DateTime.now().subtract(const Duration(minutes: 30)),
      isCurrentUser: false,
      isRead: true,
    ),
    MessageDetails(
      messageId: "msg7",
      content: "That would be great, thanks! By the way, I found this awesome package for chat UI components we could use.",
      senderId: "user1",
      senderName: "Alex",
      senderProfilePic: "https://ui-avatars.com/api/?name=Ke&rounded=true&background=random",
      sentAt: DateTime.now().subtract(const Duration(minutes: 15)),
      isCurrentUser: true,
      isRead: false,
    ),
    MessageDetails(
      messageId: "msg8",
      content: "Sounds interesting! Share the link when you get a chance.",
      senderId: "user2",
      senderName: "Taylor",
      senderProfilePic: "https://ui-avatars.com/api/?name=Yo&rounded=true&background=random",
      sentAt: DateTime.now().subtract(const Duration(minutes: 5)),
      isCurrentUser: false,
      isRead: false,
    ),
  ];

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFFF8C00),
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(
                "https://ui-avatars.com/api/?name=FD&rounded=true&background=random",
              ),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.conversationTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  "3 participants",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            )
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFEFD5),
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            // Chat messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(16),
                itemCount: widget.messages.length,
                itemBuilder: (context, index) {
                  final message = widget.messages[index];
                  final isCurrentUser = message.senderId == widget.currentUserId;

                  // Check if we need to show date header
                  bool showDateHeader = false;
                  final DateTime messageDate = message.sentAt;

                  if (index == 0) {
                    showDateHeader = true;
                  } else {
                    final DateTime previousMessageDate = widget.messages[index - 1].sentAt;
                    if (!isSameDay(previousMessageDate, messageDate)) {
                      showDateHeader = true;
                    }
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showDateHeader)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                              child: Text(
                                getDateHeader(messageDate),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      MessageBubble(
                        message: message,
                        isCurrentUser: isCurrentUser,
                      ),
                    ],
                  );
                },
              ),
            ),
            // Message input
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.add, color: Color(0xFFFF8C00)),
                    onPressed: () {},
                  ),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: "Type a message...",
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.mic, color: Color(0xFFFF8C00)),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(Icons.send, color: Color(0xFFFF8C00)),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  String getDateHeader(DateTime date) {
    final now = DateTime.now();

    if (isSameDay(date, now)) {
      return "Today";
    } else if (isSameDay(date, now.subtract(Duration(days: 1)))) {
      return "Yesterday";
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date); // Day name
    } else {
      return DateFormat('MMM d, yyyy').format(date); // Full date
    }
  }
}

class MessageBubble extends StatelessWidget {
  final MessageDetails message;
  final bool isCurrentUser;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isCurrentUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(message.senderProfilePic ?? ""),
            ),
            SizedBox(width: 8),
          ],
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isCurrentUser ? Color(0xFFFF8C00) : Colors.white,
              borderRadius: BorderRadius.circular(20).copyWith(
                bottomLeft: isCurrentUser ? Radius.circular(20) : Radius.circular(0),
                bottomRight: isCurrentUser ? Radius.circular(0) : Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isCurrentUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      message.senderName,
                      style: TextStyle(
                        color: Color(0xFFFF8C00),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                Text(
                  message.content,
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white : Colors.black87,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('h:mm a').format(message.sentAt),
                      style: TextStyle(
                        color: isCurrentUser ? Colors.white.withOpacity(0.7) : Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      SizedBox(width: 4),
                      Icon(
                        message.isRead ? Icons.done_all : Icons.done,
                        size: 14,
                        color: message.isRead ? Colors.white.withOpacity(0.9) : Colors.white.withOpacity(0.7),
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
