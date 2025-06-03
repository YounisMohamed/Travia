import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../Classes/UserSupabase.dart';
import '../Helpers/AppColors.dart';
import '../Helpers/DeleteConfirmation.dart';
import '../Helpers/PopUp.dart';
import '../Providers/ChatGroupProvider.dart';
import '../Providers/ConversationProvider.dart';
import '../Providers/ImagePickerProvider.dart';
import '../Providers/UploadProviders.dart';
import '../main.dart';

class GroupMembersPage extends ConsumerStatefulWidget {
  final String conversationId;

  const GroupMembersPage({
    super.key,
    required this.conversationId,
  });

  @override
  ConsumerState<GroupMembersPage> createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends ConsumerState<GroupMembersPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _currentUserId;
  String? _adminId;
  List<String> _currentParticipantIds = [];

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _fetchConversationDetails();
    _fetchCurrentParticipants();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchConversationDetails() async {
    try {
      final response = await supabase.from('conversations').select('title, group_picture, admin_id').eq('conversation_id', widget.conversationId).single();

      ref.read(groupTitleProvider.notifier).state = response['title'];
      ref.read(groupPictureProvider.notifier).state = response['group_picture'];
      _titleController.text = response['title'] ?? '';
      _adminId = response['admin_id'];

      if (mounted) setState(() {});
    } catch (e) {
      print('Error fetching conversation details: $e');
    }
  }

  Future<void> _fetchCurrentParticipants() async {
    try {
      final participants = await supabase.from('conversation_participants').select('user_id').eq('conversation_id', widget.conversationId);

      _currentParticipantIds = participants.map((p) => p['user_id'].toString()).toList();

      if (mounted) setState(() {});
    } catch (e) {
      print('Error fetching participants: $e');
    }
  }

  bool get _isCurrentUserAdmin => _currentUserId != null && _currentUserId == _adminId;

  Future<void> _addMember(UserModel user) async {
    if (!_isCurrentUserAdmin) {
      Popup.showError(text: "Only admins can add members", context: context);
      return;
    }

    ref.read(groupLoadingProvider.notifier).state = true;

    try {
      await supabase.from('conversation_participants').insert({
        'conversation_id': widget.conversationId,
        'user_id': user.id,
      });

      // Update local participant list
      _currentParticipantIds.add(user.id);

      // Clear search and refresh participants
      _searchController.clear();
      setState(() => _searchQuery = '');

      // Refresh the participants provider
      ref.invalidate(participantsProvider(widget.conversationId));

      Popup.showInfo(text: "${user.username} added to group", context: context);
    } catch (e) {
      Popup.showError(text: "Failed to add member", context: context);
    } finally {
      ref.read(groupLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _removeMember(String userId, String username) async {
    if (!_isCurrentUserAdmin) {
      Popup.showError(text: "Only admins can remove members", context: context);
      return;
    }

    if (userId == _adminId) {
      Popup.showError(text: "Cannot remove admin from group", context: context);
      return;
    }

    bool confirmed = false;

    await showCustomDialog(
      context: context,
      title: "Remove @$username?",
      message: "This will remove them from the group. They won't be notified about this action.",
      actionText: "Remove",
      actionIcon: Icons.block,
      onActionPressed: () async {
        confirmed = true;
      },
    );

    if (!confirmed) return;

    ref.read(groupLoadingProvider.notifier).state = true;

    try {
      await supabase.from('conversation_participants').delete().eq('conversation_id', widget.conversationId).eq('user_id', userId);

      // Update local participant list
      _currentParticipantIds.remove(userId);

      // Refresh the participants provider
      ref.invalidate(participantsProvider(widget.conversationId));

      Popup.showInfo(text: "$username removed from group", context: context);
    } catch (e) {
      Popup.showError(text: "Failed to remove member", context: context);
    } finally {
      ref.read(groupLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _updateGroupPicture() async {
    if (!_isCurrentUserAdmin) {
      Popup.showError(text: "Only admins can change group picture", context: context);
      return;
    }

    ref.read(imagesOnlyPickerProvider.notifier).clearImage();
    await ref.read(imagesOnlyPickerProvider.notifier).pickAndEditMediaForUpload(context);

    final mediaFile = ref.read(imagesOnlyPickerProvider);
    if (mediaFile == null) return;

    ref.read(groupLoadingProvider.notifier).state = true;

    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      final mediaUrl = await ref.read(changePictureProvider.notifier).uploadChatMedia(userId: currentUserId, mediaFile: mediaFile, context: context);

      if (mediaUrl == null) {
        Popup.showError(text: "Failed to edit group picture", context: context);
        return;
      }

      await supabase.from('conversations').update({'group_picture': mediaUrl}).eq('conversation_id', widget.conversationId);

      ref.read(groupPictureProvider.notifier).state = mediaUrl;

      Popup.showInfo(text: "Group Picture Updated", context: context);
    } catch (e) {
      Popup.showError(text: "Failed to edit group picture", context: context);
    } finally {
      ref.read(imagesOnlyPickerProvider.notifier).clearImage();
      ref.read(groupLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _updateGroupTitle() async {
    if (!_isCurrentUserAdmin) {
      Popup.showError(text: "Only admins can change group title", context: context);
      return;
    }

    final newTitle = _titleController.text.trim();
    final currentTitle = ref.read(groupTitleProvider);

    if (newTitle.isEmpty) {
      Popup.showWarning(text: "Title cannot be empty", context: context);
      return;
    }

    if (newTitle == currentTitle) {
      return;
    }

    ref.read(groupLoadingProvider.notifier).state = true;

    try {
      await supabase.from('conversations').update({'title': newTitle}).eq('conversation_id', widget.conversationId);
      ref.read(groupTitleProvider.notifier).state = newTitle;

      Popup.showInfo(text: "Group title updated", context: context);
    } catch (e) {
      Popup.showError(text: "Failed to update title", context: context);
    } finally {
      ref.read(groupLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text(
              'Group Information',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_isCurrentUserAdmin) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: kDeepPink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Admin',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: kDeepPink,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      body: Column(
        children: [
          _buildHeader(),
          if (_isCurrentUserAdmin) _buildAddMemberSection(),
          Expanded(child: _buildMembersList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isLoading = ref.watch(groupLoadingProvider);
    final groupPicture = ref.watch(groupPictureProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: isLoading ? null : _updateGroupPicture,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: groupPicture != null ? NetworkImage(groupPicture) : null,
                  child: groupPicture == null ? const Icon(Icons.group, size: 40) : null,
                ),
                if (_isCurrentUserAdmin)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: kDeepPink,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                textSelectionTheme: TextSelectionThemeData(
                  selectionHandleColor: kDeepPink,
                  selectionColor: kDeepPinkLight,
                ),
              ),
              child: TextField(
                cursorColor: Colors.black,
                controller: _titleController,
                enabled: _isCurrentUserAdmin,
                decoration: InputDecoration(
                  labelText: 'Group Title',
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                  labelStyle: const TextStyle(color: Colors.black),
                  focusColor: Colors.black,
                  suffixIcon: _isCurrentUserAdmin
                      ? IconButton(
                          icon: const Icon(Icons.edit, size: 16),
                          onPressed: _updateGroupTitle,
                        )
                      : null,
                ),
                onEditingComplete: _updateGroupTitle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMemberSection() {
    final searchResults = ref.watch(userSearchProvider(_searchQuery));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.symmetric(
          horizontal: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Members',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search users to add...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: kDeepPink, width: 1),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: kDeepPink, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: kDeepPink, width: 1),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: kDeepPink, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: kDeepPink, width: 1),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.trim();
              });
            },
          ),
          searchResults.when(
            data: (users) {
              if (_searchQuery.isEmpty) return const SizedBox.shrink();

              // Filter out users who are already participants
              final availableUsers = users.where((user) => !_currentParticipantIds.contains(user.id)).toList();

              if (availableUsers.isEmpty && _searchQuery.isNotEmpty) {
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              if (availableUsers.isNotEmpty) {
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableUsers.length,
                    itemBuilder: (context, index) {
                      final user = availableUsers[index];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundImage: NetworkImage(user.photoUrl),
                        ),
                        title: Text(user.username ?? 'Unknown'),
                        subtitle: user.displayName != null ? Text(user.displayName!, style: const TextStyle(fontSize: 12)) : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle, color: kDeepPink),
                          onPressed: () => _addMember(user),
                        ),
                      );
                    },
                  ),
                );
              }

              return const SizedBox.shrink();
            },
            loading: () {
              if (_searchQuery.isEmpty) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(16),
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            error: (error, stack) {
              if (_searchQuery.isEmpty) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Error searching users: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
    final participantsAsync = ref.watch(participantsProvider(widget.conversationId));

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.black, kDeepPink],
        ),
      ),
      child: participantsAsync.when(
        data: (participants) {
          if (participants.isEmpty) {
            return const Center(
              child: Text(
                'No members found.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: participants.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: Colors.white.withOpacity(0.2),
            ),
            itemBuilder: (context, index) {
              final user = participants[index];
              final userId = user['user_id'];
              final username = user['user_username'] ?? 'Unknown';
              final photoUrl = user['user_photourl'];
              final isAdmin = userId == _adminId;

              return ListTile(
                onTap: () {
                  Navigator.pop(context);
                  context.push('/profile/$userId');
                },
                leading: Stack(
                  children: [
                    CircleAvatar(
                      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                      backgroundColor: photoUrl == null ? Colors.white24 : null,
                      child: photoUrl == null ? const Icon(Icons.person, color: Colors.white70) : null,
                    ),
                    if (isAdmin)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star, size: 12, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        username,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    if (isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Admin',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: _isCurrentUserAdmin && !isAdmin
                    ? IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                        onPressed: () => _removeMember(userId, username),
                      )
                    : null,
              );
            },
          );
        },
        loading: () => ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: 5,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: Colors.white.withOpacity(0.2),
          ),
          itemBuilder: (context, index) {
            return Skeletonizer(
              enabled: true,
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, color: Colors.white70),
                ),
                title: const Text(''),
              ),
            );
          },
        ),
        error: (error, stackTrace) => Center(
          child: Text(
            'Error: $error',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
