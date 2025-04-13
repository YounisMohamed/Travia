import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travia/ImageServices/StorageMethods.dart';

import '../Helpers/Popup.dart';
import 'ImagePickerProvider.dart';
import 'UploadPost.dart';

final postProvider = StateNotifierProvider<PostUploadNotifier, bool>((ref) {
  return PostUploadNotifier(ref);
});

class PostUploadNotifier extends StateNotifier<bool> {
  final Ref ref;

  PostUploadNotifier(this.ref) : super(false);

  Future<void> uploadPost({
    required String userId,
    required String caption,
    required String location,
    required BuildContext context,
  }) async {
    final image = ref.read(imagePickerProvider);
    if (image == null) {
      Popup.showPopUp(text: "Please select an image!", context: context, color: Colors.red);
      return;
    }

    state = true; // loading

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

final chatMediaUploadProvider = StateNotifierProvider<ChatMediaUploadNotifier, bool>((ref) {
  return ChatMediaUploadNotifier(ref);
});

class ChatMediaUploadNotifier extends StateNotifier<bool> {
  final Ref ref;

  ChatMediaUploadNotifier(this.ref) : super(false);

  Future<String?> uploadChatMediaToSupabase({
    required String userId,
    required File mediaFile,
  }) async {
    state = true; // loading
    String? url = await uploadImageToSupabase(mediaFile, userId);
    state = false; // Stop loading
    return url;
  }
}
