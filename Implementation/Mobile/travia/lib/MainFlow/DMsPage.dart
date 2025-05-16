import 'dart:developer';

import 'package:dismissible_page/dismissible_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:travia/Helpers/DummyCards.dart';
import 'package:travia/Helpers/Loading.dart';
import 'package:travia/MainFlow/ChatPage.dart';
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
          context.pushTransparentRoute(ChatPage(conversationId: conversationId));
        }
      }
    } catch (e) {
      log(e.toString());
      Popup.showPopUp(text: "Something went wrong", context: context, color: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(conversationDetailsProvider);
    final isLoading = ref.watch(conversationIsLoadingProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              "Conversations",
              style: GoogleFonts.actor(),
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
                    Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No conversations yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _createNewConversation,
                      child: const Text('Start a conversation'),
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
                );
              },
            );
          }),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewConversation,
        child: const Icon(Icons.chat),
        tooltip: 'New Conversation',
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

  const ConversationTile({
    super.key,
    required this.conversationId,
    required this.conversationType,
    this.title,
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
    final isNotificationEnabled = notificationState[conversationId] ?? false;
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
          backgroundImage: isDirect && userPhotoUrl != null ? NetworkImage(userPhotoUrl!) : null,
          child: isGroup ? Icon(Icons.group, color: Colors.blue.shade700, size: 22) : null,
        ),
        title: Text(
          displayTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
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
                  style: TextStyle(fontSize: 13, color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                )
              else
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                    children: [
                      if (!isDirect && (sender != null))
                        TextSpan(
                          text: "$sender: ",
                          style: GoogleFonts.roboto(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
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
                    style: TextStyle(
                      fontSize: 11,
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
              iconSize: 24,
              padding: const EdgeInsets.all(8),
              onPressed: () {
                ref.read(convNotificationsProvider.notifier).toggleConvNotifications(conversationId: conversationId);
              },
              icon: Icon(
                isNotificationEnabled ? Icons.notifications : Icons.notifications_off,
                color: Colors.grey.shade600,
              ),
            ),
            if (unreadCount > 0)
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
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
          context.pushTransparentRoute(ChatPage(conversationId: conversationId));
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
            Popup.showPopUp(text: "Error happened while deleting the conversation", context: context, color: Colors.red);
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

  final Color _primaryColor = Colors.purple;
  final Color _accentColor = const Color(0xFFFF9800);
  final Color _backgroundColor = const Color(0xFFF5F7FA);
  final Color _greenColor = const Color(0xFF4CAF50);
  final Color _errorColor = const Color(0xFFE53935);

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create conversation: $e'),
            backgroundColor: _errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _createGroupConversation() async {
    final selectedUsers = ref.read(selectedUsersProvider);
    final isCreatingGroup = ref.read(isCreatingGroupProvider);

    if (selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one traveler'),
          backgroundColor: _errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    String groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a group name for your travel squad'),
          backgroundColor: _errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create travel group: $e'),
            backgroundColor: _errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
      backgroundColor: _backgroundColor,
      child: Container(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.explore, color: _primaryColor, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Connect',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: _primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: _primaryColor,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _primaryColor,
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
                )),
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
        color: Colors.white.withOpacity(0.7),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Find travelers...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.search, color: _primaryColor),
              suffixIcon: Icon(Icons.travel_explore, color: _accentColor),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
            ),
            onChanged: (value) {
              ref.read(searchQueryProvider.notifier).state = value;
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: userSearchResult.when(
              loading: () => Center(child: CircularProgressIndicator(color: _primaryColor)),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: _errorColor, size: 48),
                    const SizedBox(height: 8),
                    Text('Error: $err', style: TextStyle(color: _errorColor)),
                  ],
                ),
              ),
              data: (users) {
                if (ref.read(searchQueryProvider).isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, color: _primaryColor.withOpacity(0.6), size: 64),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            'Search for travellers to talk to!',
                            style: TextStyle(color: _primaryColor, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search, color: Colors.grey.shade400, size: 64),
                        const SizedBox(height: 16),
                        const Text(
                          'No travelers found',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return Card(
                      elevation: 0,
                      color: Colors.transparent,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        dense: true, // Makes the ListTile more compact
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: CircleAvatar(
                          radius: 18, // Reduced from 24
                          backgroundColor: _accentColor,
                          backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                          child: user.photoUrl == null
                              ? Text(
                                  user.displayName[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        title: Text(
                          user.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis, // Ensures text doesn't wrap
                        ),
                        subtitle: Text(
                          '@${user.username}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis, // Ensures text doesn't wrap
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.chat, size: 20, color: _primaryColor),
                          onPressed: () => _createDirectConversation(user),
                          tooltip: 'Chat',
                          constraints: BoxConstraints.tightFor(width: 40, height: 40),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onTap: () => _createDirectConversation(user),
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
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _groupNameController,
            decoration: InputDecoration(
              hintText: 'Name your squad...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.tour, color: _accentColor),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _accentColor.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _accentColor, width: 2),
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
                border: Border.all(color: _primaryColor.withOpacity(0.2)),
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
                        backgroundColor: _accentColor,
                        backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                        child: user.photoUrl == null
                            ? Text(
                                user.displayName[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      label: Text(
                        user.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: _primaryColor.withOpacity(0.1),
                      deleteIcon: Icon(Icons.close, size: 16, color: _primaryColor),
                      onDeleted: () => _toggleUserSelection(user),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: 'Add to your squad...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(Icons.person_add, color: _primaryColor),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
            ),
            onChanged: (value) {
              ref.read(searchQueryProvider.notifier).state = value;
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: userSearchResult.when(
              loading: () => Center(child: CircularProgressIndicator(color: _primaryColor)),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: _errorColor, size: 48),
                    const SizedBox(height: 8),
                    Text('Error: $err', style: TextStyle(color: _errorColor)),
                  ],
                ),
              ),
              data: (users) {
                if (ref.read(searchQueryProvider).isEmpty && selectedUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_add, color: _primaryColor.withOpacity(0.6), size: 64),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            'Search to add travelers to your squad!',
                            style: TextStyle(color: _primaryColor, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (users.isEmpty && ref.read(searchQueryProvider).isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search, color: Colors.grey.shade400, size: 64),
                        const SizedBox(height: 16),
                        const Text(
                          'No travelers found with that name :(',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isSelected = selectedUsers.any((u) => u.id == user.id);

                    return Card(
                      elevation: 0,
                      color: isSelected ? _primaryColor.withOpacity(0.05) : Colors.transparent,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isSelected ? BorderSide(color: _primaryColor.withOpacity(0.3), width: 1) : BorderSide.none,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: _accentColor,
                          backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                          child: user.photoUrl == null
                              ? Text(
                                  user.displayName[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        title: Text(
                          user.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '@${user.username}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 9),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: _greenColor, size: 28)
                            : Container(
                                decoration: BoxDecoration(
                                  color: _primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(8),
                                child: Icon(Icons.add, color: _primaryColor),
                              ),
                        onTap: () => _toggleUserSelection(user),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isCreatingGroup ? null : _createGroupConversation,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: isCreatingGroup
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_add, color: Colors.white),
                        const SizedBox(width: 8),
                        const Text(
                          'Start Travel Squad',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
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
