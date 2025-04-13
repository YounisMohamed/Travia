import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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

Future<String?> uploadRecordToDatabase({required String localPath, required String userId}) async {
  final file = File(localPath);
  final fileName = '${Uuid().v4()}.mp3';
  final storagePath = 'audio_messages/$userId/$fileName';

  try {
    await supabase.storage.from('records').upload(
          storagePath,
          file,
          fileOptions: const FileOptions(contentType: 'audio/mpeg'),
        );

    final publicUrl = supabase.storage.from('records').getPublicUrl(storagePath);
    return publicUrl;
  } catch (e) {
    print(e);
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
