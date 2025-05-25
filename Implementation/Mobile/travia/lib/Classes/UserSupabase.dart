class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String username;
  final String photoUrl;
  final String? bio;
  final bool isPrivate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String relationshipStatus;
  final String gender;
  final DateTime age;
  final List<String> viewedPosts;
  final List<String> savedPosts;
  final List<String> likedPosts;
  final List<String> uploadedPosts;
  final bool isYounis;
  final List<String>? fcmToken;
  final List<String> followingIds;
  final List<String> friendIds;
  final List<String> visitedCountries;
  final bool public;
  final bool showLikedPosts;

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.username,
    required this.followingIds,
    required this.friendIds,
    required this.visitedCountries,
    required this.photoUrl,
    required this.public,
    required this.showLikedPosts,
    this.bio,
    this.isPrivate = false,
    this.createdAt,
    this.updatedAt,
    this.relationshipStatus = 'Single',
    this.gender = 'Male',
    required this.age, // now required DateTime
    this.viewedPosts = const [],
    this.savedPosts = const [],
    this.uploadedPosts = const [],
    this.likedPosts = const [],
    this.isYounis = false,
    this.fcmToken,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      public: map['public'],
      showLikedPosts: map['showLikedPosts'],
      email: map['email'],
      displayName: map['display_name'],
      username: map['username'],
      photoUrl: map['photo_url'],
      bio: map['bio'],
      followingIds: List<String>.from(map['following_ids'] ?? []),
      friendIds: List<String>.from(map['friend_ids'] ?? []),
      isPrivate: map['is_private'] ?? false,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      relationshipStatus: map['relationship_status'] ?? 'Single',
      gender: map['gender'] ?? 'Male',
      age: map['age'] != null ? DateTime.parse(map['age']) : DateTime(2000, 1, 1),
      viewedPosts: List<String>.from(map['viewed_posts'] ?? []),
      savedPosts: List<String>.from(map['saved_posts'] ?? []),
      uploadedPosts: List<String>.from(map['uploaded_posts'] ?? []),
      likedPosts: List<String>.from(map['liked_posts'] ?? []),
      visitedCountries: List<String>.from(map['visited_countries'] ?? []),
      isYounis: map['is_younis'] ?? false,
      fcmToken: map['fcm_token'] != null ? List<String>.from(map['fcm_token']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'showLikedPosts': showLikedPosts,
      'public': public,
      'email': email,
      'display_name': displayName,
      'username': username,
      'photo_url': photoUrl,
      'bio': bio,
      'friend_ids': friendIds,
      'following_ids': followingIds,
      'is_private': isPrivate,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'relationship_status': relationshipStatus,
      'gender': gender,
      'age': age.toIso8601String(), // serialize DateTime to ISO format
      'viewed_posts': viewedPosts,
      'visited_countries': visitedCountries,
      'saved_posts': savedPosts,
      'uploaded_posts': uploadedPosts,
      'liked_posts': likedPosts,
      'is_younis': isYounis,
      'fcm_token': fcmToken,
    };
  }
}
