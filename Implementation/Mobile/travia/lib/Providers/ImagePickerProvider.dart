// image_picker_notifier.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:pro_image_editor/pro_image_editor.dart' as pe;
import 'package:uuid/uuid.dart';

import '../Classes/Media.dart';
import '../MainFlow/PickerScreen.dart';

final singleMediaPickerProvider = StateNotifierProvider<SingleMediaPickerNotifier, File?>((ref) {
  return SingleMediaPickerNotifier();
});

class SingleMediaPickerNotifier extends StateNotifier<File?> {
  SingleMediaPickerNotifier() : super(null);

  /// Handles picking and editing media specifically for chat functionality
  Future<void> pickAndEditMediaForChat(BuildContext context) async {
    final selectedMedia = await _pickMedia(context);
    if (selectedMedia == null) return;

    final file = await _getFileFromMedia(selectedMedia);
    if (file == null) return;

    if (selectedMedia.assetEntity.type == AssetType.image) {
      final editedImage = await _editorService.openMainEditorForChats(context, file);
      if (editedImage != null) {
        state = editedImage;
        debugPrint("New image picked ${editedImage.path}");
      }
    } else if (selectedMedia.assetEntity.type == AssetType.video) {
      state = file;
    }
  }

  /// Helper method to pick media using the PickerScreen
  Future<Media?> _pickMedia(BuildContext context) async {
    return await Navigator.push<Media?>(
      context,
      MaterialPageRoute(
        builder: (context) => const PickerScreen(selectedMedia: null),
      ),
    );
  }

  Future<File?> _getFileFromMedia(Media media) async {
    return await media.assetEntity.file;
  }

  void clearImage() {
    state = null;
  }

  final _editorService = EditorService();

  /// Handles picking and editing media specifically for upload functionality
  Future<void> pickAndEditMediaForUpload(BuildContext context) async {
    final selectedMedia = await _pickMedia(context);
    if (selectedMedia == null) return;

    final file = await _getFileFromMedia(selectedMedia);
    if (file == null) return;

    if (selectedMedia.assetEntity.type == AssetType.image) {
      final result = await _editorService.openCropperFirst(context, file);
      if (result == null) return;

      final editedImage = result['file'] as File?;
      if (editedImage != null) {
        state = editedImage;
        debugPrint("New image picked and cropped: ${editedImage.path}");
      }
    } else if (selectedMedia.assetEntity.type == AssetType.video) {
      state = file;
    }
  }
}

final imagesOnlyPickerProvider = StateNotifierProvider<ImagesOnlyPickerNotifier, File?>((ref) {
  return ImagesOnlyPickerNotifier();
});

class ImagesOnlyPickerNotifier extends StateNotifier<File?> {
  ImagesOnlyPickerNotifier() : super(null);

  Future<void> pickAndEditMediaForChat(BuildContext context) async {
    final selectedMedia = await _pickMedia(context);
    if (selectedMedia == null) return;

    final file = await _getFileFromMedia(selectedMedia);
    if (file == null) return;
    final editedImage = await _editorService.openMainEditorForChats(context, file);
    if (editedImage != null) {
      state = editedImage;
      debugPrint("New image picked ${editedImage.path}");
    }
  }

  /// Helper method to pick media using the PickerScreen
  Future<Media?> _pickMedia(BuildContext context) async {
    return await Navigator.push<Media?>(
      context,
      MaterialPageRoute(
        builder: (context) => const ImagesOnlyPickerScreen(selectedMedia: null),
      ),
    );
  }

  Future<File?> _getFileFromMedia(Media media) async {
    return await media.assetEntity.file;
  }

  void clearImage() {
    state = null;
  }

  final _editorService = EditorService();

  Future<void> pickAndEditMediaForUpload(BuildContext context) async {
    final selectedMedia = await _pickMedia(context);
    if (selectedMedia == null) return;

    final file = await _getFileFromMedia(selectedMedia);
    if (file == null) return;
    final result = await _editorService.openCropperFirst(context, file);
    if (result == null) return;

    final editedImage = result['file'] as File?;
    if (editedImage != null) {
      state = editedImage;
      debugPrint("New image picked and cropped: ${editedImage.path}");
    }
  }
}

final multiMediaPickerProvider = StateNotifierProvider<MultiMediaPickerNotifier, List<File>>((ref) {
  return MultiMediaPickerNotifier();
});

class MultiMediaPickerNotifier extends StateNotifier<List<File>> {
  MultiMediaPickerNotifier() : super([]);

  final editorService = EditorService();

  /// Pick multiple media without editing
  Future<void> pickMultipleMedia(BuildContext context) async {
    final selectedMedias = await pickMultipleMediaHelper(context);
    if (selectedMedias.isEmpty) return;

    List<File> processedFiles = [];

    for (final media in selectedMedias) {
      final file = await getFileFromMedia(media);
      if (file == null) continue;

      if (media.assetEntity.type == AssetType.image) {
        final editedImage = await editorService.openMainEditorForChats(context, file);
        if (editedImage != null) {
          processedFiles.add(editedImage);
          debugPrint("New image picked ${editedImage.path}");
        }
      } else if (media.assetEntity.type == AssetType.video) {
        processedFiles.add(file);
      }
    }

    if (processedFiles.isNotEmpty) {
      state = [...state, ...processedFiles];
    }
  }

  /// Helper method to pick multiple media using the MultiPickerScreen
  Future<List<Media>> pickMultipleMediaHelper(BuildContext context) async {
    return await Navigator.push<List<Media>>(
          context,
          MaterialPageRoute(
            builder: (context) => const MultiPickerScreen(),
          ),
        ) ??
        [];
  }

  Future<File?> getFileFromMedia(Media media) async {
    return await media.assetEntity.file;
  }

  void removeFile(File file) {
    state = state.where((f) => f.path != file.path).toList();
  }

  void clearFiles() {
    state = [];
  }
}

class EditorService {
  final _cropEditorKey = GlobalKey<pe.CropRotateEditorState>();

  /// Opens the cropper editor first, then the main editor for posts
  Future<Map<String, dynamic>?> openCropperFirst(BuildContext context, File imageFile) async {
    final cropResult = await _openCropEditor(context, imageFile);
    if (cropResult == null) return null;

    final transformations = cropResult['transforms'] as pe.TransformConfigs;
    final imageInfos = cropResult['imageInfos'] as pe.ImageInfos;

    return await openMainEditorForPosts(context, imageFile, transformations, imageInfos);
  }

  /// Opens the crop editor with fixed aspect ratio
  Future<Map<String, dynamic>?> _openCropEditor(BuildContext context, File imageFile) async {
    final cropEditorConfigs = pe.ProImageEditorConfigs(
      cropRotateEditor: const pe.CropRotateEditorConfigs(initAspectRatio: 16 / 13, canChangeAspectRatio: false),
    );

    return await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => pe.CropRotateEditor.file(
          imageFile,
          key: _cropEditorKey,
          initConfigs: pe.CropRotateEditorInitConfigs(
            theme: _getEditorTheme(),
            configs: cropEditorConfigs,
            enablePopWhenDone: false,
            onDone: (transforms, fitToScreenFactor, infos) {
              Navigator.pop(context, {
                'transforms': transforms,
                'imageInfos': infos,
              });
            },
          ),
        ),
      ),
    );
  }

  /// Opens the main editor with transformations from cropper (for posts)
  Future<Map<String, dynamic>?> openMainEditorForPosts(
    BuildContext context,
    File imageFile,
    pe.TransformConfigs transformations,
    pe.ImageInfos imageInfos,
  ) async {
    final editorConfigs = pe.ProImageEditorConfigs(
      designMode: pe.ImageEditorDesignMode.cupertino,
      mainEditor: pe.MainEditorConfigs(
        transformSetup: pe.MainEditorTransformSetup(
          transformConfigs: transformations,
          imageInfos: imageInfos,
        ),
      ),
      cropRotateEditor: const pe.CropRotateEditorConfigs(
        enabled: false,
      ),
    );

    final result = await _openProImageEditor(context, imageFile, editorConfigs);
    if (result == null) return null;

    final File newFile = await _saveEditedImage(result);
    return {
      'file': newFile,
      'imageInfos': imageInfos,
    };
  }

  /// Opens the main editor for chats (without fixed transformations)
  Future<File?> openMainEditorForChats(BuildContext context, File imageFile) async {
    final editorConfigs = pe.ProImageEditorConfigs(
      designMode: pe.ImageEditorDesignMode.cupertino,
    );

    final result = await _openProImageEditor(context, imageFile, editorConfigs);
    if (result == null) return null;

    return await _saveEditedImage(result);
  }

  /// Helper method to open the ProImageEditor with specific configs
  Future<Uint8List?> _openProImageEditor(BuildContext context, File imageFile, pe.ProImageEditorConfigs editorConfigs) async {
    return await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (context) => pe.ProImageEditor.file(
          imageFile,
          configs: editorConfigs,
          callbacks: pe.ProImageEditorCallbacks(
            onImageEditingComplete: (Uint8List bytes) async {
              Navigator.pop(context, bytes);
            },
          ),
        ),
      ),
    );
  }

  /// Saves edited image bytes to a file
  Future<File> _saveEditedImage(Uint8List imageBytes) async {
    final String newPath = '${Directory.systemTemp.path}/edited_${const Uuid().v4()}.jpg';
    final File newFile = File(newPath);
    await newFile.writeAsBytes(imageBytes);
    return newFile;
  }

  /// Returns the theme configuration for the editor
  ThemeData _getEditorTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      textTheme: const TextTheme(
        labelLarge: TextStyle(color: Colors.white),
      ),
    );
  }
}
