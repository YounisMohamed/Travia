import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../Classes/UserSupabase.dart';
import '../Helpers/AppColors.dart';
import '../Helpers/PopUp.dart';
import '../Providers/ConversationProvider.dart';
import 'DMsPage.dart';

class NewConversationPage extends ConsumerStatefulWidget {
  const NewConversationPage({Key? key}) : super(key: key);

  @override
  ConsumerState<NewConversationPage> createState() => _NewConversationPageState();
}

final searchQueryProvider = StateProvider<String>((ref) => '');
final isCreatingGroupProvider = StateProvider<bool>((ref) => false);
final selectedUsersProvider = StateProvider<List<UserModel>>((ref) => []);

class _NewConversationPageState extends ConsumerState<NewConversationPage> with SingleTickerProviderStateMixin {
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
    // Clear providers when leaving the page
    ref.invalidate(searchQueryProvider);
    ref.invalidate(selectedUsersProvider);
    ref.invalidate(isCreatingGroupProvider);
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
        context.push("/messages/$conversationId");
      }
    } catch (e) {
      log(e.toString());
      if (mounted) {
        Popup.showError(text: 'Failed to create conversation: $e', context: context);
      }
    }
  }

  Future<void> _createGroupConversation() async {
    final selectedUsers = ref.read(selectedUsersProvider);

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
        context.push("/messages/$conversationId");
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final horizontalPadding = isSmallScreen ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: kDeepGrey,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 16,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [kDeepPink, kDeepPinkLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.explore, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Connect',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            // Tab bar
            Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                16,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: kDeepGrey,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
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
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDirectMessageTab(userSearchResult, horizontalPadding),
                  _buildGroupChatTab(userSearchResult, horizontalPadding),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectMessageTab(AsyncValue<List<UserModel>> userSearchResult, double horizontalPadding) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Search field
          Container(
            decoration: BoxDecoration(
              color: kDeepGrey,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: TextField(
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
              },
            ),
          ),
          const SizedBox(height: 16),
          // Results
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

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: kDeepPink,
                          backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                          child: user.photoUrl == null
                              ? Text(
                                  user.displayName[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(
                          user.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '@${user.username}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [kDeepPinkLight, kDeepPink],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.chat_bubble_outline, size: 22, color: Colors.white),
                            onPressed: () => _createDirectConversation(user),
                            tooltip: 'Start Chat',
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

  Widget _buildGroupChatTab(AsyncValue<List<UserModel>> userSearchResult, double horizontalPadding) {
    final selectedUsers = ref.watch(selectedUsersProvider);
    final isCreatingGroup = ref.watch(isCreatingGroupProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Group name field
          Container(
            decoration: BoxDecoration(
              color: kDeepGrey,
              borderRadius: BorderRadius.circular(16),
            ),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                // Selected users chips
                if (selectedUsers.isNotEmpty) ...[
                  Container(
                    constraints: const BoxConstraints(maxHeight: 80),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kDeepPink.withOpacity(0.2)),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: selectedUsers.map((user) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Chip(
                              avatar: CircleAvatar(
                                backgroundColor: kDeepPink,
                                backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                                child: user.photoUrl == null
                                    ? Text(
                                        user.displayName[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      )
                                    : null,
                              ),
                              label: Text(
                                user.displayName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              backgroundColor: kDeepPink.withOpacity(0.1),
                              deleteIcon: Icon(Icons.close, size: 18, color: kDeepPink),
                              onDeleted: () => _toggleUserSelection(user),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Search field
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    ref.read(searchQueryProvider.notifier).state = value;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // User list
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: userSearchResult.when(
              loading: () => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: kDeepPink),
                ),
              ),
              error: (err, stack) => _buildErrorWidget(err.toString()),
              data: (users) {
                final query = ref.read(searchQueryProvider);
                if (query.isEmpty && selectedUsers.isEmpty) {
                  return _buildEmptySearchPrompt('Search travelers for your squad!');
                }
                if (users.isEmpty && query.isNotEmpty) {
                  return _buildNotFoundWidget('No travelers found');
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isSelected = selectedUsers.any((u) => u.id == user.id);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected ? Border.all(color: kDeepPink, width: 2) : Border.all(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: kDeepPink,
                          backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                          child: user.photoUrl == null
                              ? Text(
                                  user.displayName[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(
                          user.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          '@${user.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleUserSelection(user),
                          activeColor: kDeepPink,
                        ),
                        onTap: () => _toggleUserSelection(user),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          // Create button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: selectedUsers.isEmpty || isCreatingGroup ? null : _createGroupConversation,
              style: ElevatedButton.styleFrom(
                backgroundColor: kDeepPinkLight,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
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
                        const Icon(Icons.group_add, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          selectedUsers.isEmpty ? 'Select Travelers First' : 'Start Travel Squad (${selectedUsers.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String errorText) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: Colors.red, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Oops! Something went wrong',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              errorText,
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearchPrompt(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kDeepPink.withOpacity(0.1),
                    kDeepPinkLight.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search, color: kDeepPink, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundWidget(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search, color: Colors.grey.shade400, size: 64),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
