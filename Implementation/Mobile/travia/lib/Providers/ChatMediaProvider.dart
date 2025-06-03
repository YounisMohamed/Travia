import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../Helpers/HelperMethods.dart';

class MediaState {
  final bool isDownloaded;
  final bool isDownloading;
  final bool isPlaying;
  final File? localFile;
  final bool isVideoInitialized;

  const MediaState({
    this.isDownloaded = false,
    this.isDownloading = false,
    this.isPlaying = false,
    this.localFile,
    this.isVideoInitialized = false,
  });

  MediaState copyWith({
    bool? isDownloaded,
    bool? isDownloading,
    bool? isPlaying,
    File? localFile,
    bool? isVideoInitialized,
  }) {
    return MediaState(
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isDownloading: isDownloading ?? this.isDownloading,
      isPlaying: isPlaying ?? this.isPlaying,
      localFile: localFile ?? this.localFile,
      isVideoInitialized: isVideoInitialized ?? this.isVideoInitialized,
    );
  }
}

// State notifier to manage media state
class MediaStateNotifier extends StateNotifier<MediaState> {
  final String mediaUrl;
  final bool isVideo;

  static final CacheManager _cacheManager = CacheManager(
    Config(
      'media_cache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 100,
    ),
  );

  MediaStateNotifier({
    required this.mediaUrl,
    required this.isVideo,
  }) : super(const MediaState()) {
    checkIfFileExists();
  }

  Future<void> checkIfFileExists() async {
    try {
      final fileInfo = await _cacheManager.getFileFromCache(mediaUrl);
      if (fileInfo != null) {
        state = state.copyWith(
          isDownloaded: true,
          localFile: fileInfo.file,
        );
      }
    } catch (e) {
      print('Error checking cached file: $e');
    }
  }

  Future<void> downloadMedia() async {
    state = state.copyWith(isDownloading: true);

    try {
      final fileInfo = await _cacheManager.downloadFile(mediaUrl);
      state = state.copyWith(
        isDownloaded: true,
        isDownloading: false,
        localFile: fileInfo.file,
      );
    } catch (e) {
      state = state.copyWith(isDownloading: false);
      print('Error downloading media: $e');
    }
  }

  void setVideoInitialized(bool isInitialized) {
    state = state.copyWith(isVideoInitialized: isInitialized);
  }

  void setDownloaded() {
    state = state.copyWith(isDownloaded: true);
  }

  void togglePlayback() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }
}

final mediaStateProvider = StateNotifierProvider.family<MediaStateNotifier, MediaState, String>(
  (ref, mediaUrl) {
    final isVideo = isPathVideo(mediaUrl);
    return MediaStateNotifier(mediaUrl: mediaUrl, isVideo: isVideo);
  },
);

final videoPlayerControllerProvider = StateNotifierProvider.autoDispose.family<VideoControllerNotifier, AsyncValue<VideoPlayerController>, String>((ref, url) {
  final notifier = VideoControllerNotifier(url);

  // Ensure disposal when provider is disposed
  ref.onDispose(() {
    notifier.dispose();
  });

  return notifier;
});

class VideoControllerNotifier extends StateNotifier<AsyncValue<VideoPlayerController>> {
  final String mediaUrl;
  VideoPlayerController? _controller;
  bool _isDisposed = false;

  VideoControllerNotifier(this.mediaUrl) : super(const AsyncLoading()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(mediaUrl));
      await _controller!.initialize();
      _controller!.setLooping(true);

      _controller!.addListener(() {
        if (!_isDisposed) {
          state = AsyncData(_controller!);
        }
      });

      if (!_isDisposed) {
        state = AsyncData(_controller!);
      }
    } catch (e, st) {
      if (!_isDisposed) {
        state = AsyncError(e, st);
      }
    }
  }

  void play() => _controller?.play();
  void pause() => _controller?.pause();

  @override
  void dispose() {
    _isDisposed = true;
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }
}
