import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:travia/Helpers/AppColors.dart';
import 'package:travia/Helpers/DummyCards.dart';
import 'package:travia/Helpers/Loading.dart';
import 'package:travia/Providers/ConversationNotificationsProvider.dart';

import '../Classes/UserSupabase.dart';
import '../Helpers/DeleteConfirmation.dart';
import '../Helpers/HelperMethods.dart';
import '../Helpers/PopUp.dart';
import '../Providers/ChatDetailsProvider.dart';
import '../Providers/ConversationProvider.dart';
import '../main.dart';

class DMsPage extends ConsumerStatefulWidget {
  const DMsPage({super.key});

  @override
  ConsumerState<DMsPage> createState() => _DMsPageState();
}

class _DMsPageState extends ConsumerState<DMsPage> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go("/signin");
      });
    }

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _createNewConversation() async {
    try {
      final conversationId = await showDialog<String>(
        context: context,
        builder: (context) => const NewConversationDialog(),
      );

      if (conversationId != null) {
        if (context.mounted) {
          context.push("/messages/$conversationId");
        }
      }
    } catch (e) {
      log(e.toString());
      Popup.showError(text: "Something went wrong", context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(conversationDetailsProvider);
    final isLoading = ref.watch(conversationIsLoadingProvider);

    return Scaffold(
      backgroundColor: kDeepGrey,
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              "Conversations",
              style: GoogleFonts.ibmPlexSans(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 10),
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: LoadingWidget(),
              ),
          ],
        ),
      ),
      body: detailsAsync.when(
          loading: () => ListView.builder(
                itemCount: 6,
                itemBuilder: (context, index) {
                  return Skeletonizer(
                    child: DummyChatCard(),
                  );
                },
              ),
          error: (error, stack) {
            log(error.toString());
            log(stack.toString());
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.go("/error-page/${Uri.encodeComponent(error.toString())}/${Uri.encodeComponent("/dms-page")}");
              }
            });
            return Center(
              child: Text('Failed to load conversations.'),
            );
          },
          data: (conversationDetails) {
            // Preload data for each conversation
            for (final detail in conversationDetails) {
              final conversationId = detail.conversationId;
              // Trigger providers to start fetching in the background
              ref.read(chatMetadataProvider(conversationId).future);
              ref.read(messagesProvider(conversationId));
              ref.read(conversationParticipantsProvider(conversationId));
            }

            if (conversationDetails.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [kDeepPink.withOpacity(0.1), kDeepPinkLight.withOpacity(0.1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline,
                        size: 48,
                        color: kDeepPink,
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'No conversations yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Start chatting with other travelers!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [kDeepPinkLight, kDeepPink],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kDeepPink.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _createNewConversation,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_comment_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Start a conversation',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              itemCount: conversationDetails.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final detail = conversationDetails[index];
                return ConversationTile(
                  conversationId: detail.conversationId,
                  conversationType: detail.conversationType,
                  title: detail.title,
                  lastMessageContent: detail.lastMessageContent,
                  lastMessageContentType: detail.lastMessageContentType,
                  lastMessageAt: detail.lastMessageAt,
                  userUsername: detail.userUsername,
                  userPhotoUrl: detail.userPhotoUrl,
                  unreadCount: detail.unreadCount,
                  isPinned: detail.isPinned,
                  sender: detail.sender,
                  groupPicture: detail.groupPicture,
                );
              },
            );
          }),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewConversation,
        tooltip: 'New Conversation',
        backgroundColor: Colors.white,
        child: const Icon(
          Icons.chat,
          color: kDeepPink,
        ),
      ),
    );
  }
}

class ConversationTile extends ConsumerWidget {
  final String conversationId;
  final String conversationType;
  final String? title;
  final String? lastMessageContent;
  final String? lastMessageContentType;
  final DateTime? lastMessageAt;
  final String? userUsername;
  final String? userPhotoUrl;
  final int unreadCount;
  final String? sender;
  final bool isPinned;
  final String? chatTheme;
  final String? groupPicture;

  const ConversationTile({
    super.key,
    required this.conversationId,
    required this.conversationType,
    this.title,
    this.groupPicture,
    this.lastMessageContent,
    this.lastMessageContentType,
    this.lastMessageAt,
    this.userUsername,
    this.userPhotoUrl,
    required this.unreadCount,
    this.sender,
    required this.isPinned,
    this.chatTheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationState = ref.watch(convNotificationsProvider);
    final isNotificationEnabled = notificationState[conversationId] ?? true;
    final typingUsersAsync = ref.watch(otherTypingProvider(conversationId));

    bool isDirect = conversationType == 'direct';
    bool isGroup = conversationType == 'group';

    String typingText = '';
    final typingUsers = typingUsersAsync.asData?.value ?? [];

    if (typingUsers.isNotEmpty) {
      if (isDirect) {
        typingText = "${typingUsers.first} is typing...";
      } else {
        typingText = typingUsers.length == 1 ? "${typingUsers.first} is typing..." : "${typingUsers.length} people are typing...";
      }
    }

    String displayTitle = isDirect ? ("@$userUsername") : (title ?? 'Group Conversation');

    String time = lastMessageAt != null ? timeAgo(lastMessageAt!) : "";

    return GestureDetector(
      onLongPress: isDirect ? () => _showDeleteDialog(context, ref, conversationId) : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        horizontalTitleGap: 12,
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.blue.shade100,
          backgroundImage: isDirect && userPhotoUrl != null
              ? NetworkImage(userPhotoUrl!)
              : isGroup && groupPicture != null
                  ? NetworkImage(groupPicture!)
                  : null,
        ),
        title: Text(
          displayTitle,
          style: GoogleFonts.redHatDisplay(
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (typingUsers.isNotEmpty)
                Text(
                  typingText,
                  style: GoogleFonts.lexend(fontSize: 15, color: kDeepPink, fontWeight: FontWeight.bold),
                )
              else
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.lexend(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                    children: [
                      if (!isDirect && (sender != null))
                        TextSpan(
                          text: "$sender: ",
                          style: GoogleFonts.lexend(
                            fontWeight: FontWeight.bold,
                            color: kDeepPink,
                          ),
                        ),
                      TextSpan(
                        text: lastMessageContent,
                        style: TextStyle(
                          fontWeight: lastMessageContentType != "text" ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                ),
              if (time.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    time,
                    style: GoogleFonts.lexend(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              iconSize: 21,
              padding: const EdgeInsets.all(8),
              onPressed: () {
                ref.read(convNotificationsProvider.notifier).toggleConvNotifications(conversationId: conversationId);
              },
              icon: Icon(
                isNotificationEnabled ? CupertinoIcons.bell_fill : CupertinoIcons.bell_slash_fill,
                color: kDeepPink,
              ),
            ),
            if (unreadCount > 0)
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: kDeepPink,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        onTap: () {
          context.push("/messages/$conversationId");
          print('Tapped conversation: $conversationId');
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, String conversationId) {
    showCustomDialog(
      context: context,
      title: "Delete",
      message: "Are you sure? you can't undo this",
      actionText: "Delete",
      actionIcon: Icons.delete,
      onActionPressed: () async {
        ref.read(conversationIsLoadingProvider.notifier).state = true;
        try {
          await supabase.from('conversations').delete().match({'conversation_id': conversationId});
          print('Delete conversation requested: $conversationId');
        } catch (e) {
          log(e.toString());
          if (context.mounted) {
            Popup.showError(text: "Error happened while deleting the conversation", context: context);
          }
        } finally {
          ref.read(conversationIsLoadingProvider.notifier).state = false;
        }
      },
      actionColor: Colors.red,
    );
  }
}

class NewConversationDialog extends ConsumerStatefulWidget {
  const NewConversationDialog({Key? key}) : super(key: key);

  @override
  ConsumerState<NewConversationDialog> createState() => _NewConversationDialogState();
}

final searchQueryProvider = StateProvider<String>((ref) => '');
final isCreatingGroupProvider = StateProvider<bool>((ref) => false);
final selectedUsersProvider = StateProvider<List<UserModel>>((ref) => []);

class _NewConversationDialogState extends ConsumerState<NewConversationDialog> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _groupNameController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _toggleUserSelection(UserModel user) {
    final selectedUsers = ref.read(selectedUsersProvider);
    final updatedList = [...selectedUsers];

    if (updatedList.any((u) => u.id == user.id)) {
      updatedList.removeWhere((u) => u.id == user.id);
    } else {
      updatedList.add(user);
    }

    ref.read(selectedUsersProvider.notifier).state = updatedList;
  }

  Future<void> _createDirectConversation(UserModel user) async {
    try {
      final conversationId = await ref.read(createConversationProvider(user.id).future);
      if (mounted) {
        Navigator.of(context).pop(conversationId);
      }
    } catch (e) {
      log(e.toString());
      if (mounted) {
        Navigator.of(context).pop(null);
        Popup.showError(text: 'Failed to create conversation: $e', context: context);
      }
    }
  }

  Future<void> _createGroupConversation() async {
    final selectedUsers = ref.read(selectedUsersProvider);
    final isCreatingGroup = ref.read(isCreatingGroupProvider);

    if (selectedUsers.isEmpty) {
      Popup.showWarning(text: 'Please select at least one traveler', context: context);
      return;
    }

    String groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      Popup.showWarning(text: 'Please enter a group name for your travel squad', context: context);
      return;
    }

    ref.read(isCreatingGroupProvider.notifier).state = true;

    try {
      final userIds = selectedUsers.map((u) => u.id).toList();
      final conversationId = await ref.read(createGroupConversationProvider(
        GroupChatParams(userIds: userIds, groupName: groupName),
      ).future);

      if (mounted) {
        Navigator.of(context).pop(conversationId);
      }
    } catch (e) {
      log(e.toString());
      if (mounted) {
        Popup.showError(text: 'Failed to create travel group: $e', context: context);
      }
    } finally {
      if (mounted) {
        ref.read(isCreatingGroupProvider.notifier).state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(searchQueryProvider);
    final userSearchResult = ref.watch(userSearchProvider(searchQuery));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [kDeepPink, kDeepPinkLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.explore, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Connect',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: kDeepGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.all(4),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: kDeepPink,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: [kDeepPinkLight, kDeepPink],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.person, size: 20),
                        SizedBox(width: 8),
                        Text('Direct'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.groups, size: 20),
                        SizedBox(width: 8),
                        Text('Squad'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDirectMessageTab(userSearchResult),
                  _buildGroupChatTab(userSearchResult),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectMessageTab(AsyncValue<List<UserModel>> userSearchResult) {
    return Container(
      decoration: BoxDecoration(
        color: kDeepGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Find travelers..',
              hintStyle: TextStyle(color: Colors.grey.shade600),
              suffixIcon: Icon(Icons.travel_explore, color: kDeepPinkLight),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kDeepPink.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kDeepPink, width: 2),
              ),
            ),
            onChanged: (value) {
              ref.read(searchQueryProvider.notifier).state = value;
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: userSearchResult.when(
              loading: () => Center(child: CircularProgressIndicator(color: kDeepPink)),
              error: (err, stack) => _buildErrorWidget(err.toString()),
              data: (users) {
                final searchQuery = ref.read(searchQueryProvider);
                if (searchQuery.isEmpty) {
                  return _buildEmptySearchPrompt('Search for travelers to connect with!');
                }
                if (users.isEmpty) {
                  return _buildNotFoundWidget('No travelers found');
                }

                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: kDeepPink.withOpacity(0.1)),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: kDeepPink,
                          backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                          child: user.photoUrl == null ? Text(user.displayName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null,
                        ),
                        title: Text(
                          user.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '@${user.username}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [kDeepPinkLight, kDeepPink], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.chat_bubble_outline, size: 20, color: Colors.white),
                            onPressed: () => _createDirectConversation(user),
                            tooltip: 'Start Chat',
                            constraints: BoxConstraints.tightFor(width: 40, height: 40),
                          ),
                        ),
                        onTap: () => _createDirectConversation(user),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupChatTab(AsyncValue<List<UserModel>> userSearchResult) {
    final selectedUsers = ref.watch(selectedUsersProvider);
    final isCreatingGroup = ref.watch(isCreatingGroupProvider);

    return Container(
      decoration: BoxDecoration(color: kDeepGrey, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _groupNameController,
            decoration: InputDecoration(
              hintText: 'Name your squad..',
              hintStyle: TextStyle(color: Colors.grey.shade600),
              prefixIcon: Icon(Icons.tour, color: kDeepPink),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kDeepPink.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kDeepPink, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (selectedUsers.isNotEmpty)
            Container(
              height: 70,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kDeepPink.withOpacity(0.2)),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: selectedUsers.length,
                itemBuilder: (context, index) {
                  final user = selectedUsers[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      avatar: CircleAvatar(
                        backgroundColor: kDeepPink,
                        backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                        child: user.photoUrl == null ? Text(user.displayName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)) : null,
                      ),
                      label: Text(user.displayName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      backgroundColor: kDeepPink.withOpacity(0.1),
                      deleteIcon: Icon(Icons.close, size: 18, color: kDeepPink),
                      onDeleted: () => _toggleUserSelection(user),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  );
                },
              ),
            ),
          if (selectedUsers.isNotEmpty) const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search travelers..',
              hintStyle: TextStyle(color: Colors.grey.shade600),
              prefixIcon: Icon(Icons.person_add, color: kDeepPink),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kDeepPink.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: kDeepPink, width: 2),
              ),
            ),
            onChanged: (value) {
              ref.read(searchQueryProvider.notifier).state = value;
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: userSearchResult.when(
              loading: () => Center(child: CircularProgressIndicator(color: kDeepPink)),
              error: (err, stack) => _buildErrorWidget(err.toString()),
              data: (users) {
                final query = ref.read(searchQueryProvider);
                if (query.isEmpty && selectedUsers.isEmpty) {
                  return _buildEmptySearchPrompt('Search travelers for your squad!');
                }
                if (users.isEmpty && query.isNotEmpty) {
                  return _buildNotFoundWidget('No travelers found');
                }

                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: kDeepPink.withOpacity(0.1)),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: kDeepPink,
                        backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                        child: user.photoUrl == null ? Text(user.displayName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null,
                      ),
                      title: Text(user.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('@${user.username}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600)),
                      trailing: Checkbox(
                        value: selectedUsers.contains(user),
                        onChanged: (_) => _toggleUserSelection(user),
                        activeColor: kDeepPink,
                      ),
                      onTap: () => _toggleUserSelection(user),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String errorText) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
            child: Icon(Icons.error_outline, color: Colors.red, size: 48),
          ),
          const SizedBox(height: 16),
          Text('Oops! Something went wrong', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(errorText, style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySearchPrompt(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [kDeepPink.withOpacity(0.1), kDeepPinkLight.withOpacity(0.1)]),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search, color: kDeepPink, size: 48),
          ),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildNotFoundWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search, color: Colors.grey.shade400, size: 64),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
        ],
      ),
    );
  }
}

// Parameter class for group creation
class GroupChatParams {
  final List<String> userIds;
  final String groupName;

  GroupChatParams({required this.userIds, required this.groupName});
}
