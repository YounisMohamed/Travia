// image_picker_notifier.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';
import 'package:pro_image_editor/pro_image_editor.dart' as pe;
import 'package:uuid/uuid.dart';

import '../Classes/Media.dart';
import '../MainFlow/PickerScreen.dart';
import 'VideoCropProvider.dart';

final imagePickerProvider = StateNotifierProvider<ImagePickerNotifier, File?>((ref) {
  return ImagePickerNotifier();
});

class ImagePickerNotifier extends StateNotifier<File?> {
  ImagePickerNotifier() : super(null);

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
      final confirmedVideo = await Navigator.push<File?>(
        context,
        MaterialPageRoute(
          builder: (context) => VideoCropPreviewPage(originalVideo: file),
        ),
      );
      if (confirmedVideo != null) {
        state = confirmedVideo;
        debugPrint("New video picked and cropped: ${confirmedVideo.path}");
      }
    }
  }

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

Future<File> cropToAspectRatioOrReturnOriginal(File videoFile, double targetAspectRatio) async {
  final inputPath = videoFile.path;
  final dir = p.dirname(inputPath);
  final outputPath = '$dir/cropped_${DateTime.now().millisecondsSinceEpoch}.mp4';

  // Step 1: Get video metadata
  final probeResult = await FFprobeKit.getMediaInformation(inputPath);
  final info = probeResult.getMediaInformation();
  if (info == null) return videoFile;

  final stream = info.getStreams().firstWhere((s) => s.getType() == 'video');
  int? width = stream.getWidth();
  int? height = stream.getHeight();
  String? rotationStr = stream.getAllProperties()?['rotation']?.toString();

  if (width == null || height == null) return videoFile;

  // Step 2: Adjust for rotation
  if (rotationStr == '90' || rotationStr == '270' || rotationStr == '-90') {
    final temp = width;
    width = height;
    height = temp;
  }

  // Step 3: Compute crop dimensions
  double currentRatio = width / height;
  if ((currentRatio - targetAspectRatio).abs() < 0.01) {
    // Close enough — no need to crop
    return videoFile;
  }

  int cropWidth = width;
  int cropHeight = (width / targetAspectRatio).round();

  if (cropHeight > height) {
    cropHeight = height;
    cropWidth = (height * targetAspectRatio).round();
  }

  if (cropWidth <= 0 || cropHeight <= 0 || cropWidth > width || cropHeight > height) {
    return videoFile; // Safety: dimensions invalid
  }

  int x = ((width - cropWidth) / 2).round();
  int y = ((height - cropHeight) / 2).round();

  final filter = 'crop=$cropWidth:$cropHeight:$x:$y';
  final cmd = '-y -i "$inputPath" -vf "$filter" -c:v libx264 -preset ultrafast -crf 23 -c:a copy "$outputPath"';

  final session = await FFmpegKit.execute(cmd);
  final returnCode = await session.getReturnCode();

  if (ReturnCode.isSuccess(returnCode)) {
    return File(outputPath);
  } else {
    // Cropping failed — fallback to original
    return videoFile;
  }
}

class VideoCropPreviewPage extends ConsumerWidget {
  final File originalVideo;
  final double aspectRatio;

  const VideoCropPreviewPage({
    super.key,
    required this.originalVideo,
    this.aspectRatio = 1,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VideoCropScreen(
      videoFile: originalVideo,
      aspectRatio: aspectRatio,
    );
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
