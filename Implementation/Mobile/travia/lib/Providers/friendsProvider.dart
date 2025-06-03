import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Classes/UserSupabase.dart';
import '../main.dart';

// Model for the friends data
class FriendsData {
  final List<UserModel> followers;
  final List<UserModel> following;
  final List<UserModel> discoverUsers;

  FriendsData({
    required this.followers,
    required this.following,
    required this.discoverUsers,
  });

  FriendsData copyWith({
    List<UserModel>? followers,
    List<UserModel>? following,
    List<UserModel>? discoverUsers,
  }) {
    return FriendsData(
      followers: followers ?? this.followers,
      following: following ?? this.following,
      discoverUsers: discoverUsers ?? this.discoverUsers,
    );
  }
}

// Main provider for friends data
final friendsDataProvider = StreamProvider.family<FriendsData, String>((ref, currentUserId) async* {
  try {
    final controller = StreamController<FriendsData>();

    // Set up the Supabase stream for the current user to get their following/friend lists
    final userSubscription = supabase.from('users').stream(primaryKey: ['id']).eq('id', currentUserId).listen(
          (userData) async {
            if (userData.isEmpty) {
              controller.addError(Exception('Current user not found'));
              return;
            }

            final currentUser = userData.first;
            final List<String> followingIds = List<String>.from(currentUser['following_ids'] ?? []);
            final List<String> friendIds = List<String>.from(currentUser['friend_ids'] ?? []);

            List<UserModel> followers = [];
            if (friendIds.isNotEmpty) {
              final followersData = await supabase.from('users').select().inFilter('id', friendIds);
              followers = followersData.map((user) => UserModel.fromMap(user)).toList();
            }

            List<UserModel> following = [];
            if (followingIds.isNotEmpty) {
              final followingData = await supabase.from('users').select().inFilter('id', followingIds);
              following = followingData.map((user) => UserModel.fromMap(user)).toList();
            }

            final excludeIds = {currentUserId, ...followingIds}.toList(); // Removed friendIds from here

            final discoverData = await supabase.from('users').select().not('id', 'in', excludeIds).limit(50);

            final discoverUsers = discoverData.map((user) => UserModel.fromMap(user)).toList();

            // Sort discover users by follower count (descending order - most followers first)
            discoverUsers.sort((a, b) {
              final aFollowerCount = (a.followingIds.length);
              final bFollowerCount = (b.followingIds.length);
              return bFollowerCount.compareTo(aFollowerCount);
            });

            // Emit the combined data
            controller.add(FriendsData(
              followers: followers,
              following: following,
              discoverUsers: discoverUsers,
            ));
          },
          onError: (error) {
            print('Friends data stream error: $error');
            controller.addError(error);
          },
        );

    // Clean up when provider is disposed
    ref.onDispose(() {
      userSubscription.cancel();
      controller.close();
    });

    // Yield updates from the controller
    await for (final friendsData in controller.stream) {
      yield friendsData;
    }
  } catch (e) {
    print('Friends provider error: $e');
    rethrow;
  }
});

final searchQueryProvider = StateProvider<String>((ref) => '');

// Filtered users provider that combines search query with users list
List<UserModel> filterUsers(List<UserModel> users, String searchQuery) {
  if (searchQuery.isEmpty) {
    return users;
  }

  final query = searchQuery.toLowerCase().trim();

  return users.where((user) {
    final displayNameMatch = user.displayName.toLowerCase().contains(query);
    final usernameMatch = user.username.toLowerCase().contains(query);
    final emailMatch = user.email.toLowerCase().contains(query);

    return displayNameMatch || usernameMatch || emailMatch;
  }).toList();
}
