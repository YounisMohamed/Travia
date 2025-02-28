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
