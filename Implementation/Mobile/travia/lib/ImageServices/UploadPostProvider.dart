import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Helpers/Popup.dart';
import 'ImagePickerProvider.dart';
import 'UploadPost.dart';

final postProvider = StateNotifierProvider<PostUploadNotifier, bool>((ref) {
  return PostUploadNotifier(ref);
});

class PostUploadNotifier extends StateNotifier<bool> {
  final Ref ref;

  PostUploadNotifier(this.ref) : super(false);

  Future<void> uploadPost(
    String userId,
    String caption,
    String location,
    BuildContext context,
  ) async {
    final image = ref.read(imagePickerProvider);
    if (image == null) {
      Popup.showPopUp(text: "Please select an image!", context: context, color: Colors.red);
      return;
    }

    state = true; // Start loading

    bool success = await PostUploader.uploadPost(
      userId: userId,
      imageFile: image,
      caption: caption,
      location: location,
    );

    if (success) {
      Popup.showPopUp(text: "Post uploaded successfully!", context: context, color: Colors.green);
    } else {
      Popup.showPopUp(text: "Post upload failed!", context: context, color: Colors.red);
    }

    state = false; // Stop loading
  }
}
