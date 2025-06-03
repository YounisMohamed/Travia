import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travia/Classes/story_item_model.dart';
import 'package:video_player/video_player.dart';

import '../Classes/story_model.dart';
import '../main.dart';

final storiesProvider = StreamProvider<List<story_model>>((ref) async* {
  try {
    final now = DateTime.now();
    final utcNow = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );

    final nowIsoUtc = utcNow.toIso8601String();

    final stream = supabase.from('stories').stream(primaryKey: ['story_id']);

    print('[storiesProvider] Listening to Supabase stories stream...');

    await for (final response in stream) {
      if (response.isEmpty) {
        yield [];
        continue;
      }

      final List<story_model> stories = [];

      final storyIds = response.map((s) => s['story_id'] as String).toList();

      // Fetch story items that are not expired
      final allItemsResponse = await supabase.from('story_items').select().inFilter('story_id', storyIds).gte('expires_at', nowIsoUtc).order('created_at');

      final Map<String, List<story_item_model>> itemsByStoryId = {};
      for (final item in allItemsResponse) {
        final storyId = item['story_id'] as String;
        final model = story_item_model.fromJson(item);
        itemsByStoryId.putIfAbsent(storyId, () => []).add(model);
      }

      for (final storyData in response) {
        final storyId = storyData['story_id'] as String;
        final items = itemsByStoryId[storyId] ?? [];

        // Skip stories that have no valid items
        if (items.isEmpty) continue;

        final story = story_model(
          storyId: storyId,
          userId: storyData['user_id'],
          username: storyData['username'],
          userPhotoUrl: storyData['user_photo_url'],
          seenBy: storyData['seen_by'] != null ? List<String>.from(storyData['seen_by']) : [],
          items: items,
        );

        stories.add(story);
      }

      // Sort stories by latest story item creation time initially (will be reordered by seen status in UI)
      stories.sort((a, b) {
        final aLatest = (a.items?.isNotEmpty == true) ? a.items!.map((item) => item.createdAt).reduce((a, b) => a.isAfter(b) ? a : b) : DateTime.now();
        final bLatest = (b.items?.isNotEmpty == true) ? b.items!.map((item) => item.createdAt).reduce((a, b) => a.isAfter(b) ? a : b) : DateTime.now();
        return bLatest.compareTo(aLatest);
      });

      yield stories;
    }
  } catch (e, stackTrace) {
    print('Error in storiesProvider: $e');
    print(stackTrace);
    yield [];
  }
});

final currentStoryItemIndexProvider = StateProvider<int>((ref) => 0);

final storyPausedProvider = StateProvider.autoDispose<bool>((ref) => false);

final videoLoadingProvider = StateProvider.family<bool, String>((ref, id) => true);

// Provider for video error state
final videoErrorProvider = StateProvider.family<bool, String>((ref, id) => false);

// Provider for video controller
final videoControllerProvider = StateProvider.family<VideoPlayerController?, String>((ref, id) => null);

class LikeNotifierStoryItem extends StateNotifier<Map<String, bool>> {
  LikeNotifierStoryItem() : super({}) {
    _fetchLikedStoryItems();
  }

  Future<void> _fetchLikedStoryItems() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print("User ID is null");
      return;
    }

    try {
      // Get likes where the story_id is not null (meaning it's a story item like)
      final response = await supabase.from('likes').select('story_id').eq('liker_user_id', userId).not('story_id', 'is', null);

      final Map<String, bool> likedStoryItems = {};

      // Process the response
      for (var like in response) {
        final storyItemId = like['story_id'] as String;
        likedStoryItems[storyItemId] = true;
      }

      state = likedStoryItems;
      print("Fetched ${likedStoryItems.length} liked story items");
    } catch (e) {
      print("Error fetching liked story items: $e");
    }
  }

  // Toggle Like with Optimistic Update for a specific story item
  Future<void> toggleLike({
    required String storyItemId,
    required String likerId,
    required String storyOwnerId,
  }) async {
    final isLiked = state[storyItemId] ?? false;

    // Create a new map for state update
    final newState = Map<String, bool>.from(state);
    newState[storyItemId] = !isLiked;

    try {
      // Optimistically update state
      state = newState;
      print("Optimistically ${isLiked ? 'unliking' : 'liking'} story item: $storyItemId");

      if (isLiked) {
        // Unlike the story item
        await supabase.from('likes').delete().match({
          'liker_user_id': likerId,
          'story_id': storyItemId,
          'liked_user_id': storyOwnerId,
        });
        print("Unliked story item: $storyItemId");
      } else {
        // Like the story item
        await supabase.from('likes').insert({
          'liker_user_id': likerId,
          'liked_user_id': storyOwnerId,
          'story_id': storyItemId,
        });
        print("Liked story item: $storyItemId");
      }
    } catch (e) {
      print("Error updating story item like: $e");
      // Revert state on failure
      newState[storyItemId] = isLiked;
      state = newState;
    }
  }
}

final likeStoryItemProvider = StateNotifierProvider<LikeNotifierStoryItem, Map<String, bool>>((ref) {
  return LikeNotifierStoryItem();
});
