import 'package:travia/Classes/story_item_model.dart';

class story_model {
  final String storyId;
  final String userId;
  final String username;
  final String userPhotoUrl;
  final List<String>? seenBy;
  final List<story_item_model>? items;

  story_model({
    required this.storyId,
    required this.userId,
    required this.username,
    required this.userPhotoUrl,
    this.seenBy,
    this.items,
  });

  factory story_model.fromJson(Map<String, dynamic> json) {
    return story_model(
      storyId: json['story_id'],
      userId: json['user_id'],
      username: json['username'],
      userPhotoUrl: json['user_photo_url'],
      seenBy: json['seen_by'] != null ? List<String>.from(json['seen_by']) : null,
      items: json['items'] != null ? (json['items'] as List).map((item) => story_item_model.fromJson(item)).toList() : null,
    );
  }
}
