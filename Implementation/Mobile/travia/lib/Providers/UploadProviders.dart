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
        quality: 20,
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

  static Future<void> savePostToDatabase(String userId, String mediaUrl, String caption, String location, {String? videoThumbnail}) async {
    try {
      await supabase.from('posts').insert({
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
    final mediaFile = ref.read(singleMediaPickerProvider);
    if (mediaFile == null) {
      Popup.showError(text: "Please select an image or video!", context: context);
      return;
    }

    setLoading(true);

    try {
      final mediaUrl = await MediaUploadService.uploadMedia(mediaFile: mediaFile, userId: userId, bucketName: 'posts', folderPath: 'posts', compress: true, context: context);

      if (mediaUrl == null) throw Exception("Failed to upload media");

      String? thumbnailUrl;

      final isVideo = mediaFile.path.endsWith(".mp4") || mediaFile.path.endsWith(".mov");
      if (isVideo) {
        final uint8list = await VideoThumbnail.thumbnailData(
          video: mediaFile.path,
          imageFormat: ImageFormat.PNG,
          maxWidth: 300,
          quality: 75,
        );

        if (uint8list != null) {
          final fileName = 'thumb_${DateTime.now().millisecondsSinceEpoch}.png';
          final storagePath = 'thumbnails/$userId/$fileName';

          final uploadRes = await supabase.storage.from('posts').uploadBinary(storagePath, uint8list, fileOptions: const FileOptions(contentType: 'image/png'));

          final publicUrl = supabase.storage.from('posts').getPublicUrl(storagePath);
          thumbnailUrl = publicUrl;
        }
      }

      await MediaUploadService.savePostToDatabase(
        userId,
        mediaUrl,
        caption,
        location,
        videoThumbnail: thumbnailUrl,
      );

      Popup.showSuccess(text: "Post uploaded successfully!", context: context);
    } catch (e) {
      print("Post Upload Error: $e");
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
