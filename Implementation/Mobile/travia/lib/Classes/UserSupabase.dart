class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String username;
  final String photoUrl;
  final String? bio;
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
  final bool showLikedPosts;
  final List<String> blockedUserIds;
  final List<String> blockedByUserIds;
  final bool isBanned;
  final List<String> badges;

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.username,
    required this.followingIds,
    required this.friendIds,
    required this.visitedCountries,
    required this.photoUrl,
    required this.showLikedPosts,
    this.bio,
    this.createdAt,
    this.updatedAt,
    this.relationshipStatus = 'Single',
    this.gender = 'Male',
    required this.age,
    this.viewedPosts = const [],
    this.savedPosts = const [],
    this.uploadedPosts = const [],
    this.likedPosts = const [],
    this.isYounis = false,
    this.fcmToken,
    this.blockedUserIds = const [],
    this.blockedByUserIds = const [],
    required this.isBanned,
    required this.badges,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      showLikedPosts: map['showLikedPosts'],
      email: map['email'],
      displayName: map['display_name'],
      username: map['username'],
      photoUrl: map['photo_url'],
      bio: map['bio'],
      followingIds: List<String>.from(map['following_ids'] ?? []),
      friendIds: List<String>.from(map['friend_ids'] ?? []),
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
      blockedUserIds: List<String>.from(map['blocked_user_ids'] ?? []),
      blockedByUserIds: List<String>.from(map['blocked_by_user_ids'] ?? []),
      isBanned: map['is_banned'] ?? false,
      badges: List<String>.from(map['badges'] ?? []),
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      displayName: json['display_name'] ?? '',
      username: json['username'] ?? '',
      photoUrl: json['photo_url'] ?? '',
      bio: json['bio'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      relationshipStatus: json['relationship_status'] ?? 'Single',
      gender: json['gender'] ?? 'Male',
      age: json['age'] != null ? DateTime.parse(json['age']) : DateTime(2000),
      viewedPosts: json['viewed_posts'] != null ? List<String>.from(json['viewed_posts']) : [],
      savedPosts: json['saved_posts'] != null ? List<String>.from(json['saved_posts']) : [],
      likedPosts: json['liked_posts'] != null ? List<String>.from(json['liked_posts']) : [],
      uploadedPosts: json['uploaded_posts'] != null ? List<String>.from(json['uploaded_posts']) : [],
      isYounis: json['is_younis'] ?? false,
      fcmToken: json['fcm_token'] != null ? List<String>.from(json['fcm_token']) : null,
      followingIds: json['following_ids'] != null ? List<String>.from(json['following_ids']) : [],
      friendIds: json['friend_ids'] != null ? List<String>.from(json['friend_ids']) : [],
      visitedCountries: json['visited_countries'] != null ? List<String>.from(json['visited_countries']) : [],
      showLikedPosts: json['showLikedPosts'] ?? true,
      blockedUserIds: json['blocked_user_ids'] != null ? List<String>.from(json['blocked_user_ids']) : [],
      blockedByUserIds: json['blocked_by_user_ids'] != null ? List<String>.from(json['blocked_by_user_ids']) : [],
      isBanned: json['is_banned'] ?? false,
      badges: json['badges'] != null ? List<String>.from(json['badges']) : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'showLikedPosts': showLikedPosts,
      'email': email,
      'display_name': displayName,
      'username': username,
      'photo_url': photoUrl,
      'bio': bio,
      'friend_ids': friendIds,
      'following_ids': followingIds,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'relationship_status': relationshipStatus,
      'gender': gender,
      'age': age.toIso8601String(),
      'viewed_posts': viewedPosts,
      'visited_countries': visitedCountries,
      'saved_posts': savedPosts,
      'uploaded_posts': uploadedPosts,
      'liked_posts': likedPosts,
      'is_younis': isYounis,
      'fcm_token': fcmToken,
      'blocked_user_ids': blockedUserIds,
      'blocked_by_user_ids': blockedByUserIds,
      'is_banned': isBanned,
      'badges': badges,
    };
  }

  bool hasBlocked(String userId) {
    return blockedUserIds.contains(userId);
  }

  bool isBlockedBy(String userId) {
    return blockedByUserIds.contains(userId);
  }

  bool isBlockedOrBlocking(String userId) {
    return hasBlocked(userId) || isBlockedBy(userId);
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? username,
    String? photoUrl,
    String? bio,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? relationshipStatus,
    String? gender,
    DateTime? age,
    List<String>? viewedPosts,
    List<String>? savedPosts,
    List<String>? likedPosts,
    List<String>? uploadedPosts,
    bool? isYounis,
    List<String>? fcmToken,
    List<String>? followingIds,
    List<String>? friendIds,
    List<String>? visitedCountries,
    bool? showLikedPosts,
    List<String>? blockedUserIds,
    List<String>? blockedByUserIds,
    bool? isBanned,
    List<String>? badges,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      relationshipStatus: relationshipStatus ?? this.relationshipStatus,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      viewedPosts: viewedPosts ?? this.viewedPosts,
      savedPosts: savedPosts ?? this.savedPosts,
      likedPosts: likedPosts ?? this.likedPosts,
      uploadedPosts: uploadedPosts ?? this.uploadedPosts,
      isYounis: isYounis ?? this.isYounis,
      fcmToken: fcmToken ?? this.fcmToken,
      followingIds: followingIds ?? this.followingIds,
      friendIds: friendIds ?? this.friendIds,
      visitedCountries: visitedCountries ?? this.visitedCountries,
      showLikedPosts: showLikedPosts ?? this.showLikedPosts,
      blockedUserIds: blockedUserIds ?? this.blockedUserIds,
      blockedByUserIds: blockedByUserIds ?? this.blockedByUserIds,
      isBanned: isBanned ?? this.isBanned,
      badges: badges ?? this.badges,
    );
  }
}
