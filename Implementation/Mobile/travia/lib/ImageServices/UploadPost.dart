import 'dart:io';

import 'StorageMethods.dart';

class PostUploader {
  static Future<bool> uploadPost({
    required String userId,
    required File? imageFile,
    required String caption,
    required String location,
  }) async {
    if (imageFile == null) return false;

    try {
      // Upload Image to Supabase Storage
      final imageUrl = await uploadImageToSupabase(imageFile, userId);
      if (imageUrl == null) return false;

      // Save Post Details in DatabaseAWGAWG
      await savePostToDatabase(userId, imageUrl, caption, location);
      return true;
    } catch (e) {
      print("Post Upload Error: $e");
      return false;
    }
  }
}
