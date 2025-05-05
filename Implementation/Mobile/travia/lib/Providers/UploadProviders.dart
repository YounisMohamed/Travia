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

import '../Helpers/Popup.dart';
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
        quality: 25,
        minWidth: 720,
        minHeight: 720,
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
    bool compress = true,
  }) async {
    try {
      File fileToUpload = mediaFile;

      // Compress media if enabled
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

      final fileExt = compress ? 'jpg' : mediaFile.path.split('.').last; // Force jpg for compressed images
      final fileName = '$folderPath/$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage.from(bucketName).upload(
            fileName,
            fileToUpload,
            fileOptions: FileOptions(
              cacheControl: '3600', // Cache for 1 hour to save bandwidth
              contentType: _getContentType(fileExt),
            ),
          );

      return supabase.storage.from(bucketName).getPublicUrl(fileName);
    } catch (e) {
      print('Error uploading media: $e');
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

  static Future<void> savePostToDatabase(String userId, String imageUrl, String caption, String location) async {
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
}

// Base notifier class for all media uploads
abstract class MediaUploadNotifier extends StateNotifier<bool> {
  final Ref ref;

  MediaUploadNotifier(this.ref) : super(false);

  void setLoading(bool isLoading) {
    state = isLoading;
  }
}

// Post upload provider
final postProvider = StateNotifierProvider<PostUploadNotifier, bool>((ref) {
  return PostUploadNotifier(ref);
});

class PostUploadNotifier extends MediaUploadNotifier {
  PostUploadNotifier(super.ref);

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

    setLoading(true);

    try {
      final imageUrl = await MediaUploadService.uploadMedia(
        mediaFile: image,
        userId: userId,
        bucketName: 'posts',
        folderPath: 'posts',
        compress: true, // Enable compression
      );

      if (imageUrl == null) {
        throw Exception("Failed to upload image");
      }

      await MediaUploadService.savePostToDatabase(userId, imageUrl, caption, location);
      Popup.showPopUp(text: "Post uploaded successfully!", context: context, color: Colors.green);
    } catch (e) {
      print("Post Upload Error: $e");
      Popup.showPopUp(text: "Post upload failed!", context: context, color: Colors.red);
    } finally {
      setLoading(false);
    }
  }
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
  }) async {
    setLoading(true);

    try {
      final url = await MediaUploadService.uploadMedia(
        mediaFile: mediaFile,
        userId: userId,
        bucketName: 'chatmedia',
        folderPath: 'TraviaChat',
        compress: true, // Enable compression
      );
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
  }) async {
    setLoading(true);

    try {
      final url = await MediaUploadService.uploadMedia(
        mediaFile: mediaFile,
        userId: userId,
        bucketName: 'stories',
        folderPath: 'TraviaStories',
        compress: true, // Enable compression
      );
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
