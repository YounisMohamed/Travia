class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String username;
  final String? photoUrl;
  final String? bio;
  final bool isPrivate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String relationshipStatus;
  final String gender;
  final int age;
  final List<String> viewedPosts;
  final List<String> savedPosts;
  final bool isYounis;
  final List<String>? fcmToken;

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.username,
    this.photoUrl,
    this.bio,
    this.isPrivate = false,
    this.createdAt,
    this.updatedAt,
    this.relationshipStatus = 'Single',
    this.gender = 'Male',
    this.age = 25,
    this.viewedPosts = const [],
    this.savedPosts = const [],
    this.isYounis = false,
    this.fcmToken,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      email: map['email'],
      displayName: map['display_name'],
      username: map['username'],
      photoUrl: map['photo_url'],
      bio: map['bio'],
      isPrivate: map['is_private'] ?? false,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      relationshipStatus: map['relationship_status'] ?? 'Single',
      gender: map['gender'] ?? 'Male',
      age: map['age'] ?? 25,
      viewedPosts: List<String>.from(map['viewed_posts'] ?? []),
      savedPosts: List<String>.from(map['saved_posts'] ?? []),
      isYounis: map['is_younis'] ?? false,
      fcmToken: map['fcm_token'] != null ? List<String>.from(map['fcm_token']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'username': username,
      'photo_url': photoUrl,
      'bio': bio,
      'is_private': isPrivate,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'relationship_status': relationshipStatus,
      'gender': gender,
      'age': age,
      'viewed_posts': viewedPosts,
      'saved_posts': savedPosts,
      'is_younis': isYounis,
      'fcm_token': fcmToken,
    };
  }
}
