import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../Helpers/AppColors.dart';
import '../Helpers/PopUp.dart';
import '../main.dart';

class SharePlanDialog extends ConsumerStatefulWidget {
  final String planId;
  final String planName;
  final String cityName;

  SharePlanDialog({
    Key? key,
    required this.planId,
    required this.planName,
    required this.cityName,
  }) : super(key: key);

  final Set<String> sentConversations = <String>{};

  @override
  ConsumerState<SharePlanDialog> createState() => _SharePlanDialogState();
}

class _SharePlanDialogState extends ConsumerState<SharePlanDialog> {
  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(userConversationsProvider);
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: 400,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [kDeepPink, kDeepPinkLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Share Travel Plan',
                              style: GoogleFonts.lexendDeca(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[900],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Conversations List
            Expanded(
              child: conversationsAsync.when(
                loading: () => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(kDeepPink),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading conversations...',
                        style: GoogleFonts.lexendDeca(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load conversations',
                          style: GoogleFonts.lexendDeca(
                            fontSize: 16,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => ref.refresh(userConversationsProvider),
                          child: Text(
                            'Try Again',
                            style: GoogleFonts.lexendDeca(
                              color: kDeepPink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (conversations) {
                  if (conversations.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.chat_bubble_outline,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No conversations yet',
                              style: GoogleFonts.lexendDeca(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start a conversation to share plans',
                              style: GoogleFonts.lexendDeca(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: conversations.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Colors.grey[200],
                    ),
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      final displayName = conversation.getDisplayName(currentUserId);
                      final displayPicture = conversation.getDisplayPicture(currentUserId);
                      final isGroup = conversation.conversationType == 'group';
                      final hasSent = widget.sentConversations.contains(conversation.conversationId);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: displayPicture == null
                                ? LinearGradient(
                                    colors: [
                                      kDeepPink.withOpacity(0.8),
                                      kDeepPinkLight.withOpacity(0.8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            image: displayPicture != null
                                ? DecorationImage(
                                    image: CachedNetworkImageProvider(displayPicture),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: displayPicture == null
                              ? Center(
                                  child: Text(
                                    displayName[0].toUpperCase(),
                                    style: GoogleFonts.lexendDeca(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        title: Row(
                          children: [
                            if (isGroup)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: kDeepPink.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.group,
                                  size: 14,
                                  color: kDeepPink,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                isGroup ? displayName : "@$displayName",
                                style: GoogleFonts.lexendDeca(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        subtitle: isGroup
                            ? Text(
                                '${conversation.participants.length} members',
                                style: GoogleFonts.lexendDeca(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              )
                            : null,
                        trailing: hasSent
                            ? Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check,
                                  color: Colors.green,
                                  size: 20,
                                ),
                              )
                            : ElevatedButton(
                                onPressed: () async {
                                  try {
                                    await supabase
                                        .from('messages')
                                        .insert({
                                          'conversation_id': conversation.conversationId,
                                          'sender_id': currentUserId,
                                          'content': widget.planId,
                                          'content_type': 'plan',
                                        })
                                        .select('message_id')
                                        .single();

                                    // Add conversation to sent list
                                    setState(() {
                                      widget.sentConversations.add(conversation.conversationId);
                                    });

                                    // Show success message
                                    Popup.showSuccess(
                                      text: "Plan Sent!",
                                      context: context,
                                    );
                                  } catch (e) {
                                    // Handle error if needed
                                    Popup.showError(
                                      text: "Failed to send plan",
                                      context: context,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kDeepPinkLight,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Send',
                                  style: GoogleFonts.lexendDeca(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                      );
                    },
                  );
                },
              ),
            ),
            Text(
              'Send "${widget.planName}" to your friends',
              style: GoogleFonts.lexendDeca(
                fontSize: 13,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(
              height: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function to show the share dialog
void showSharePlanDialog(
  BuildContext context,
  String planId,
  String planName,
  String cityName,
) {
  showDialog(
    context: context,
    builder: (context) => SharePlanDialog(
      planId: planId,
      planName: planName,
      cityName: cityName,
    ),
  );
}

class ConversationWithDetails {
  final String conversationId;
  final String conversationType;
  final String? title;
  final String? groupPicture;
  final List<ConversationParticipant> participants;
  final DateTime createdAt;
  final DateTime updatedAt;

  ConversationWithDetails({
    required this.conversationId,
    required this.conversationType,
    this.title,
    this.groupPicture,
    required this.participants,
    required this.createdAt,
    required this.updatedAt,
  });

  // Get display name for the conversation
  String getDisplayName(String currentUserId) {
    if (conversationType == 'group') {
      return title ?? 'Group Chat';
    } else {
      // For direct chat, return the other user's username
      final otherUser = participants.firstWhere(
        (p) => p.userId != currentUserId,
        orElse: () => participants.first,
      );
      return otherUser.userUsername ?? 'Unknown User';
    }
  }

  // Get display picture for the conversation
  String? getDisplayPicture(String currentUserId) {
    if (conversationType == 'group') {
      return groupPicture;
    } else {
      // For direct chat, return the other user's photo
      final otherUser = participants.firstWhere(
        (p) => p.userId != currentUserId,
        orElse: () => participants.first,
      );
      return otherUser.userPhotoUrl;
    }
  }
}

class ConversationParticipant {
  final String userId;
  final String? userUsername;
  final String? userPhotoUrl;

  ConversationParticipant({
    required this.userId,
    this.userUsername,
    this.userPhotoUrl,
  });
}

// Provider to fetch user's conversations
final userConversationsProvider = FutureProvider<List<ConversationWithDetails>>((ref) async {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;

  try {
    // First, get all conversations the user is part of
    final conversationsResponse = await supabase.from('conversation_participants').select('''
          conversation_id,
          conversations!inner(
            conversation_id,
            conversation_type,
            title,
            group_picture,
            created_at,
            updated_at
          )
        ''').eq('user_id', currentUserId);

    final List<ConversationWithDetails> conversations = [];

    // For each conversation, fetch all participants
    for (final conv in conversationsResponse) {
      final conversationData = conv['conversations'];

      // Fetch participants for this conversation
      final participantsResponse = await supabase.from('conversation_participants').select('user_id, user_username, user_photourl').eq('conversation_id', conversationData['conversation_id']);

      final participants = (participantsResponse as List)
          .map((p) => ConversationParticipant(
                userId: p['user_id'],
                userUsername: p['user_username'],
                userPhotoUrl: p['user_photourl'],
              ))
          .toList();

      conversations.add(ConversationWithDetails(
        conversationId: conversationData['conversation_id'],
        conversationType: conversationData['conversation_type'],
        title: conversationData['title'],
        groupPicture: conversationData['group_picture'],
        participants: participants,
        createdAt: DateTime.parse(conversationData['created_at']),
        updatedAt: DateTime.parse(conversationData['updated_at']),
      ));
    }

    // Sort by updated_at descending (most recent first)
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return conversations;
  } catch (e) {
    throw Exception('Failed to load conversations: $e');
  }
});
