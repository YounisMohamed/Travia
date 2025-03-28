import 'dart:io';

import '../main.dart';

Future<String?> uploadImageToSupabase(File imageFile, String userId) async {
  try {
    final fileExt = imageFile.path.split('.').last;
    final fileName = 'posts/$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    print(fileExt);
    print(fileName);

    await supabase.storage.from('posts').upload(fileName, imageFile);

    return supabase.storage.from('posts').getPublicUrl(fileName);
  } catch (e) {
    print('Error uploading image: $e');
    return null;
  }
}

Future<void> savePostToDatabase(String userId, String imageUrl, String caption, String location) async {
  try {
    await supabase.from('posts').insert({
      'user_id': userId,
      'media_url': imageUrl,
      'caption': caption,
      'location': location,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  } catch (e) {
    print("Database Error: $e");
    rethrow;
  }
}
