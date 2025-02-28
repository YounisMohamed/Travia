import 'dart:io';

import 'package:mime/mime.dart';

import 'StorageMethods.dart';

class ImageUploader {
  static Future<String?> uploadImage(File file, String userId) async {
    try {
      final mimeType = lookupMimeType(file.path);
      if (mimeType != 'image/png' && mimeType != 'image/jpeg') {
        return null;
      }

      final imageUrl = await uploadImageToSupabase(file, userId);
      return imageUrl;
    } catch (e) {
      print("Upload error: $e");
      return null;
    }
  }
}
