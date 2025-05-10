import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../main.dart';

String timeAgo(DateTime utcDateTime) {
  // Force the input to UTC (Every body's time is different so its a time mw7d)
  final utcTime = utcDateTime.isUtc
      ? utcDateTime
      : DateTime.utc(
          utcDateTime.year,
          utcDateTime.month,
          utcDateTime.day,
          utcDateTime.hour,
          utcDateTime.minute,
          utcDateTime.second,
          utcDateTime.millisecond,
          utcDateTime.microsecond,
        );

  final now = DateTime.now().toUtc();

  final difference = now.difference(utcTime);
  if (difference.inSeconds < 60) {
    return 'Just Now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
  } else if (difference.inDays < 7) {
    return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
  } else if (difference.inDays < 30) {
    final weeks = (difference.inDays / 7).floor();
    return '$weeks week${weeks == 1 ? '' : 's'} ago';
  } else if (difference.inDays < 365) {
    final months = (difference.inDays / 30).floor();
    return '$months month${months == 1 ? '' : 's'} ago';
  } else {
    final years = (difference.inDays / 365).floor();
    return '$years year${years == 1 ? '' : 's'} ago';
  }
}

String formatCount(int count) {
  if (count < 1000) {
    return count.toString();
  } else if (count < 1000000) {
    return '${(count / 1000).toStringAsFixed(1)}K';
  } else if (count >= 1000000 && count < 1000000000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  } else {
    if (count > 1000000000000) {
      return "Too many views 😯";
    } else {
      return '${(count / 1000000000000).toStringAsFixed(1)}B';
    }
  }
}

dynamic isMostlyRtl(String text) {
  // Lw el kalam mostly arabic, rtl, else ltr
  final rtlChars = RegExp(r'[\u0600-\u06FF]');
  final rtlCount = rtlChars.allMatches(text).length;
  final totalCount = text.length;
  return (rtlCount / totalCount > 0.5) ? TextDirection.rtl : TextDirection.ltr;
}

Future<bool> createStory({
  required String mediaUrl,
  required String mediaType,
  String? caption,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  try {
    final storyResponse = await supabase
        .from('stories')
        .insert({
          'user_id': user.uid,
        })
        .select()
        .single();

    // Create story item
    await supabase.from('story_items').insert({
      'story_id': storyResponse['story_id'],
      'media_url': mediaUrl,
      'media_type': mediaType,
      'caption': caption,
    });
    return true;
  } catch (e) {
    print('Error creating story: $e');
    return false;
  }
}

// New function to only create a story and return its ID
Future<String?> createNewStory() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("createNewStory failed: No user logged in");
      return null;
    }

    // Create a new story
    final storyData = {
      'user_id': user.uid,
      // The trigger will populate username and user_photo_url
    };

    // Insert story into database
    final response = await supabase.from('stories').insert(storyData).select('story_id').single();

    final storyId = response['story_id'] as String;
    print("Created new story with ID: $storyId");

    return storyId;
  } catch (e) {
    print("Error creating story: $e");
    return null;
  }
}

Future<bool> addStoryItem({
  required String storyId,
  required String mediaUrl,
  required String mediaType,
  String? caption,
}) async {
  try {
    // Create story item
    final itemData = {
      'story_id': storyId,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'caption': caption,
    };

    // Insert story item
    await supabase.from('story_items').insert(itemData);
    print("Added story item to story $storyId: $mediaUrl ($mediaType)");

    return true;
  } catch (e) {
    print("Error adding story item: $e");
    return false;
  }
}
