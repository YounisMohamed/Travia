import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../Helpers/PopUp.dart';
import '../Services/ClassificationService.dart';
import '../main.dart';
import 'ImagePickerProvider.dart';

class MediaCompressor {
  static Future<File?> compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath = p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');

    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 100,
        minWidth: 1080,
        minHeight: 1080,
        format: CompressFormat.jpeg,
      );

      return result != null ? File(result.path) : null;
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  // Compress video
  static Future<File?> compressVideo(File file) async {
    try {
      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      return mediaInfo?.file;
    } catch (e) {
      print('Error compressing video: $e');
      return null;
    }
  }

  // Detect media type and compress accordingly
  static Future<File?> compressMedia(File file) async {
    final extension = p.extension(file.path).toLowerCase();

    // Image types
    if (['.jpg', '.jpeg', '.png', '.webp', '.heic'].contains(extension)) {
      return await compressImage(file);
    }
    // Video types
    else if (['.mp4', '.mov', '.avi', '.mkv', '.flv', '.wmv'].contains(extension)) {
      return await compressVideo(file);
    }
    // Unknown type - return original
    else {
      return file;
    }
  }
}

class MediaUploadService {
  static Future<String?> uploadMedia({
    required File mediaFile,
    required String userId,
    required String bucketName,
    required String folderPath,
    required BuildContext context,
    bool compress = true,
  }) async {
    try {
      File fileToUpload = mediaFile;

      const int maxFileSizeInBytes = 8 * 1024 * 1024; // 8MB

      final fileSize = fileToUpload.lengthSync();
      if (fileSize > maxFileSizeInBytes) {
        final fileSizeToInt = (fileSize / (1024 * 1024)).round();
        print('File too large: ${fileSizeToInt} MB. Max allowed is 8 MB.');
        Popup.showWarning(text: "File too large. Max allowed is 8 MB.", context: context);
        return null;
      }

      // Determine if this is a video file
      final extension = p.extension(mediaFile.path).toLowerCase();
      final isVideo = ['.mp4', '.mov', '.avi', '.mkv', '.flv', '.wmv'].contains(extension);

      // Compress the media if enabled
      if (compress) {
        final compressedFile = await MediaCompressor.compressMedia(mediaFile);
        if (compressedFile != null) {
          fileToUpload = compressedFile;
          print('Original size: ${mediaFile.lengthSync()} bytes');
          print('Compressed size: ${fileToUpload.lengthSync()} bytes');
          print('Compression ratio: ${(fileToUpload.lengthSync() / mediaFile.lengthSync() * 100).toStringAsFixed(2)}%');
        } else {
          print('Compression failed, using original file');
        }
      }

      // Determine final extension to use
      String fileExt;
      if (isVideo) {
        fileExt = compress && fileToUpload != mediaFile ? p.extension(fileToUpload.path).replaceFirst('.', '') : extension.replaceFirst('.', '');
      } else {
        fileExt = compress ? 'jpg' : extension.replaceFirst('.', '');
      }

      final fileName = '$folderPath/$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage.from(bucketName).upload(
            fileName,
            fileToUpload,
            fileOptions: FileOptions(
              cacheControl: '3600',
              contentType: _getContentType(fileExt),
            ),
          );

      return supabase.storage.from(bucketName).getPublicUrl(fileName);
    } catch (e) {
      Popup.showWarning(text: "Error uploading media.", context: context);
      return null;
    }
  }

  static String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }

  static Future<String?> uploadRecord({
    required String localPath,
    required String userId,
  }) async {
    final file = File(localPath);
    final fileName = '${Uuid().v4()}.mp3';
    final storagePath = 'audio_messages/$userId/$fileName';

    try {
      // Audio compression could be added here

      await supabase.storage.from('records').upload(
            storagePath,
            file,
            fileOptions: const FileOptions(
              contentType: 'audio/mpeg',
              cacheControl: '3600', // Cache for 1 hour
            ),
          );

      return supabase.storage.from('records').getPublicUrl(storagePath);
    } catch (e) {
      print('Error uploading record: $e');
      return null;
    }
  }

  static Future<void> savePostToDatabase(
      {required String postId, required String userId, required String mediaUrl, required String caption, required String location, required String? videoThumbnail}) async {
    try {
      await supabase.from('posts').insert({
        'id': postId,
        'user_id': userId,
        'media_url': mediaUrl,
        'caption': caption,
        'location': location,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'comments_count': 0,
        if (videoThumbnail != null) 'video_thumbnail': videoThumbnail,
      });
    } catch (e) {
      print("Database Error: $e");
      rethrow;
    }
  }
}

// Base notifier class for all media uploads
abstract class MediaUploadNotifier extends StateNotifier<bool> {
  final Ref ref;

  MediaUploadNotifier(this.ref) : super(false);

  void setLoading(bool isLoading) {
    state = isLoading;
  }
}

class UploadState {
  final bool isUploading;
  final String? currentStep;
  final double? progress;

  const UploadState({
    this.isUploading = false,
    this.currentStep,
    this.progress,
  });

  UploadState copyWith({
    bool? isUploading,
    String? currentStep,
    double? progress,
  }) {
    return UploadState(
      isUploading: isUploading ?? this.isUploading,
      currentStep: currentStep ?? this.currentStep,
      progress: progress ?? this.progress,
    );
  }
}

// Post upload provider
final postProvider = StateNotifierProvider<PostUploadNotifier, UploadState>((ref) {
  return PostUploadNotifier(ref);
});

class PostUploadNotifier extends StateNotifier<UploadState> {
  final Ref ref;

  PostUploadNotifier(this.ref) : super(const UploadState());

  void setUploadStep(String step, {double? progress}) {
    state = state.copyWith(
      isUploading: true,
      currentStep: step,
      progress: progress,
    );
  }

  void clearUploadState() {
    state = const UploadState();
  }

  Future<void> uploadPost({
    required String userId,
    required String caption,
    required String location,
    required BuildContext context,
  }) async {
    final mediaFile = ref.read(singleMediaPickerProvider);
    if (mediaFile == null) {
      Popup.showError(text: "Please select an image or video!", context: context);
      return;
    }

    try {
      // Step 1: Compressing
      setUploadStep('Compressing media...', progress: 0.2);

      final mediaUrl = await MediaUploadService.uploadMedia(
        mediaFile: mediaFile,
        userId: userId,
        bucketName: 'posts',
        folderPath: 'posts',
        compress: true,
        context: context,
      );

      if (mediaUrl == null) throw Exception("Failed to upload media");

      // Step 2: Uploading
      setUploadStep('Uploading to storage...', progress: 0.4);

      String? thumbnailUrl;
      final isVideo = mediaFile.path.endsWith(".mp4") || mediaFile.path.endsWith(".mov");

      if (isVideo) {
        setUploadStep('Generating thumbnail...', progress: 0.5);

        final uint8list = await VideoThumbnail.thumbnailData(
          video: mediaFile.path,
          imageFormat: ImageFormat.PNG,
          maxWidth: 300,
          quality: 75,
        );

        if (uint8list != null) {
          final fileName = 'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final storagePath = 'thumbnails/$userId/$fileName';

          await supabase.storage.from('posts').uploadBinary(
                storagePath,
                uint8list,
                fileOptions: const FileOptions(contentType: 'image/jpg'),
              );

          final publicUrl = supabase.storage.from('posts').getPublicUrl(storagePath);
          thumbnailUrl = publicUrl;
        }
      }

      final String postId = Uuid().v4();
      print("POST ID: $postId");

      // Step 3: Save post to database
      setUploadStep('Saving post...', progress: 0.6);

      await MediaUploadService.savePostToDatabase(
        postId: postId,
        userId: userId,
        mediaUrl: mediaUrl,
        caption: caption,
        location: location,
        videoThumbnail: thumbnailUrl,
      );

      // Step 4: Classification and metadata
      Map<String, dynamic> metadataToInsert = _getDefaultMetadata(postId, caption, mediaUrl, location);
      print("LOCATION: $location");

      if (!isVideo) {
        setUploadStep('Analyzing content...', progress: 0.8);

        try {
          // Check if classification service is available first
          final classifier = ImageClassificationService();

          print('Classification service is healthy, proceeding with analysis...');

          // Perform classification with timeout
          final classificationResult = await classifier
              .classifyImage(
                imageUrl: mediaUrl,
                caption: caption,
              )
              .timeout(
                const Duration(seconds: 60),
                onTimeout: () => throw TimeoutException(),
              );

          // Create combined text description
          final List<String> textParts = [
            if (caption.trim().isNotEmpty) caption.trim(),
            if (classificationResult.blipDescription.trim().isNotEmpty) classificationResult.blipDescription.trim(),
            if (classificationResult.yoloDescription.trim().isNotEmpty) classificationResult.yoloDescription.trim(),
          ];

          final combinedText = textParts.join(', ');
          final conf = 0.6;

          // Update metadata with classification results (matching database schema)
          metadataToInsert = {
            'post_id': postId,
            'romantic': classificationResult.romanticConfidence > conf ? 1 : 0,
            'good_for_kids': classificationResult.goodForKidsConfidence > conf ? 1 : 0,
            'classy': classificationResult.classyConfidence > conf ? 1 : 0,
            'casual': classificationResult.casualConfidence > conf ? 1 : 0,
            'combined_text': combinedText,
            'post_media_url': mediaUrl,
            'location': location,
          };

          print('Classification successful: ${classificationResult.attributes}');
        } on TimeoutException catch (e) {
          print('Classification timed out, using default metadata: $e');
        } on NetworkException catch (e) {
          print('Network error during classification, using default metadata: $e');
        } on ClassificationException catch (e) {
          print('Classification error, using default metadata: $e');
        } catch (e) {
          print('Unexpected error during classification, using default metadata: $e');
        }
      }

      // Step 5: Insert metadata (will always succeed with either classified or default values)
      setUploadStep('Saving photo content...', progress: 0.9);

      try {
        await supabase.from('metadata').insert(metadataToInsert);
        print('Metadata inserted successfully');
      } catch (e) {
        print('Failed to insert metadata, retrying with minimal defaults: $e');

        // If metadata insertion fails, try again with absolute minimal data
        try {
          final minimalMetadata = {
            'post_id': postId,
            'post_media_url': mediaUrl,
            'location': location,
            'combined_text': caption.isNotEmpty ? caption : 'Post from $location',
            'romantic': 0,
            'good_for_kids': 0,
            'classy': 0,
            'casual': 0,
          };

          await supabase.from('metadata').insert(minimalMetadata);
          print('Minimal metadata inserted successfully');
        } catch (finalError) {
          print('Critical error: Failed to insert even minimal metadata: $finalError');
        }
      }

      setUploadStep('Complete!', progress: 1.0);
      await Future.delayed(const Duration(milliseconds: 500));

      Popup.showSuccess(text: "Post uploaded successfully!", context: context);

      clearUploadState();
      ref.read(singleMediaPickerProvider.notifier).clearImage();
    } catch (e) {
      print("Post Upload Error: $e");
      Popup.showError(text: "Failed to upload post. Please try again.", context: context);
      clearUploadState();
    }
  }
}

// Helper function to create default metadata (matching database schema)
Map<String, dynamic> _getDefaultMetadata(String postId, String caption, String mediaUrl, String location) {
  return {
    'post_id': postId,
    'romantic': 0,
    'good_for_kids': 0,
    'classy': 0,
    'casual': 0,
    'combined_text': caption.trim().isNotEmpty ? caption.trim() : "No description available",
    'post_media_url': mediaUrl,
    'location': location,
  };
}

// Chat media upload provider
final chatMediaUploadProvider = StateNotifierProvider<ChatMediaUploadNotifier, bool>((ref) {
  return ChatMediaUploadNotifier(ref);
});

class ChatMediaUploadNotifier extends MediaUploadNotifier {
  ChatMediaUploadNotifier(super.ref);

  Future<String?> uploadChatMedia({
    required String userId,
    required File mediaFile,
    required BuildContext context,
  }) async {
    setLoading(true);

    try {
      final url = await MediaUploadService.uploadMedia(mediaFile: mediaFile, userId: userId, bucketName: 'chatmedia', folderPath: 'TraviaChat', compress: true, context: context);
      return url;
    } finally {
      setLoading(false);
    }
  }
}

final changePictureProvider = StateNotifierProvider<ChangePictureNotifier, bool>((ref) {
  return ChangePictureNotifier(ref);
});

class ChangePictureNotifier extends MediaUploadNotifier {
  ChangePictureNotifier(super.ref);

  Future<String?> uploadChatMedia({
    required String userId,
    required File mediaFile,
    required BuildContext context,
  }) async {
    setLoading(true);

    try {
      final url = await MediaUploadService.uploadMedia(mediaFile: mediaFile, userId: userId, bucketName: 'chatmedia', folderPath: 'ProfilePics', compress: true, context: context);
      return url;
    } finally {
      setLoading(false);
    }
  }
}

// Story media upload provider
final storyMediaUploadProvider = StateNotifierProvider<StoryMediaUploadNotifier, bool>((ref) {
  return StoryMediaUploadNotifier(ref);
});

class StoryMediaUploadNotifier extends MediaUploadNotifier {
  StoryMediaUploadNotifier(super.ref);

  Future<String?> uploadStory({
    required String userId,
    required File mediaFile,
    required BuildContext context,
  }) async {
    setLoading(true);

    try {
      final url = await MediaUploadService.uploadMedia(mediaFile: mediaFile, userId: userId, bucketName: 'stories', folderPath: 'TraviaStories', compress: true, context: context);
      return url;
    } finally {
      setLoading(false);
    }
  }
}

// Audio record upload helper function
Future<String?> uploadRecordToDatabase({required String localPath, required String userId}) async {
  return MediaUploadService.uploadRecord(localPath: localPath, userId: userId);
}

final mediaFileVideoControllerProvider = StateNotifierProvider.family<VideoControllerNotifier, AsyncValue<VideoPlayerController>, File>(
  (ref, file) => VideoControllerNotifier(file),
);

final videoPlayingStateProvider = StateProvider.family<bool, File>((ref, _) => false);

// VideoControllerNotifier manages the video player controller
class VideoControllerNotifier extends StateNotifier<AsyncValue<VideoPlayerController>> {
  final File videoFile;

  VideoControllerNotifier(this.videoFile) : super(const AsyncValue.loading()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final controller = VideoPlayerController.file(videoFile);
      await controller.setLooping(true);
      await controller.initialize();
      state = AsyncValue.data(controller);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void play() {
    if (state.value != null) {
      state.value!.play();
    }
  }

  void pause() {
    if (state.value != null) {
      state.value!.pause();
    }
  }

  void togglePlayPause(WidgetRef ref) {
    if (state.value != null) {
      final isPlaying = ref.read(videoPlayingStateProvider(videoFile));
      if (isPlaying) {
        pause();
        ref.read(videoPlayingStateProvider(videoFile).notifier).state = false;
      } else {
        play();
        ref.read(videoPlayingStateProvider(videoFile).notifier).state = true;
      }
    }
  }

  @override
  void dispose() {
    state.whenData((controller) => controller.dispose());
    super.dispose();
  }
}
