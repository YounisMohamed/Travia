class story_item_model {
  final String itemId;
  final String storyId;
  final String mediaUrl;
  final String mediaType;
  final String? caption;
  final DateTime createdAt;
  final List<dynamic> seenBy;

  story_item_model({
    required this.itemId,
    required this.storyId,
    required this.mediaUrl,
    required this.mediaType,
    this.caption,
    required this.createdAt,
    required this.seenBy,
  });

  factory story_item_model.fromJson(Map<String, dynamic> json) {
    return story_item_model(
        itemId: json['item_id'],
        storyId: json['story_id'],
        mediaUrl: json['media_url'],
        mediaType: json['media_type'],
        caption: json['caption'] ?? '',
        createdAt: DateTime.parse(json['created_at']),
        seenBy: json['seen_by'] ?? []);
  }
}
