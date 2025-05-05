class story_item_model {
  final String itemId;
  final String storyId;
  final String mediaUrl;
  final String mediaType;
  final String? caption;
  final String? backgroundColor;
  final DateTime createdAt;

  story_item_model({
    required this.itemId,
    required this.storyId,
    required this.mediaUrl,
    required this.mediaType,
    this.caption,
    this.backgroundColor,
    required this.createdAt,
  });

  factory story_item_model.fromJson(Map<String, dynamic> json) {
    return story_item_model(
      itemId: json['item_id'],
      storyId: json['story_id'],
      mediaUrl: json['media_url'],
      mediaType: json['media_type'],
      caption: json['caption'] ?? '',
      backgroundColor: json['background_color'] ?? '#FFFFFF',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
