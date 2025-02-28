import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:uuid/uuid.dart';

final imagePickerProvider = StateNotifierProvider<ImagePickerNotifier, File?>((ref) {
  return ImagePickerNotifier();
});

class ImagePickerNotifier extends StateNotifier<File?> {
  ImagePickerNotifier() : super(null);

  Future<void> pickAndEditImage(String userId, BuildContext context) async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final File tempFile = File(pickedFile.path);
    final image = img.decodeImage(await tempFile.readAsBytes());
    double width = image!.width.toDouble();
    double height = image.height.toDouble();
    final File? editedImage = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProImageEditor.file(
          tempFile,
          configs: ProImageEditorConfigs(),
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (Uint8List bytes) async {
              final String newPath = '${Directory.systemTemp.path}/edited_${DateTime.now().millisecondsSinceEpoch}_${Uuid().v4()}.jpg';
              final File newFile = File(newPath);
              await newFile.writeAsBytes(bytes);
              Navigator.pop(context, newFile);
            },
          ),
        ),
      ),
    );

    if (editedImage != null) {
      state = editedImage;
      print("New image picked: ${editedImage.path}");
    }
  }

  void clearImage() {
    state = null;
  }
}
