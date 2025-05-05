import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travia/Classes/story_item_model.dart';

import '../Classes/story_model.dart';
import '../main.dart';

final storiesProvider = StreamProvider<List<story_model>>((ref) async* {


  try {
    final stream = supabase.from('stories').stream(primaryKey: ['story_id']);

    print('[storiesProvider] Listening to Supabase stories stream...');

    await for (final response in stream) {
      print('[storiesProvider] Received ${response.length} stories from stream');
      if (response.isEmpty) {
        print('[storiesProvider] No stories received. Skipping processing.');
        yield [];
        continue;
      }

      final List<story_model> stories = [];

      final storyIds = response.map((s) => s['story_id'] as String).toList();
      print('[storiesProvider] Story IDs: $storyIds');

      final allItemsResponse = await supabase.from('story_items').select().inFilter('story_id', storyIds).order('created_at');

      print('[storiesProvider] Fetched ${allItemsResponse.length} story items');

      final Map<String, List<story_item_model>> itemsByStoryId = {};
      for (final item in allItemsResponse) {
        final storyId = item['story_id'] as String;
        final model = story_item_model.fromJson(item);

        itemsByStoryId.putIfAbsent(storyId, () => []).add(model);
      }

      for (final storyData in response) {
        final storyId = storyData['story_id'] as String;

        final story = story_model(
          storyId: storyId,
          userId: storyData['user_id'],
          username: storyData['username'],
          userPhotoUrl: storyData['user_photo_url'],
          seenBy: storyData['seen_by'] != null ? List<String>.from(storyData['seen_by']) : [],
          items: itemsByStoryId[storyId] ?? [],
        );

        print('[storiesProvider] Built story: ${story.username} with ${story.items?.length} items');
        stories.add(story);
      }

      print('[storiesProvider] Total valid stories after item filtering: ${stories.length}');
      yield stories;
    }
  } catch (e, stackTrace) {
    print('[storiesProvider] Error: $e');
    print(stackTrace);
    yield [];
  }
});
