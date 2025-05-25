import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../Helpers/AppColors.dart';
import '../Providers/ChatMediaProvider.dart';
import '../Providers/UploadProviders.dart';
import 'FullscreenPhotoViewer.dart';
import 'FullscreenVideoViewer.dart';

class MediaPreview extends ConsumerStatefulWidget {
  final String mediaUrl;
  final bool isVideo;

  const MediaPreview({
    Key? key,
    required this.mediaUrl,
    required this.isVideo,
  }) : super(key: key);

  @override
  ConsumerState<MediaPreview> createState() => _MediaPreviewState();
}

class _MediaPreviewState extends ConsumerState<MediaPreview> {
  VideoPlayerController? _controller;
  Uint8List? _thumbnail;
  bool _loadingThumbnail = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
    _checkIfMediaAlreadyDownloaded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeVideoIfNeeded();
  }

  Future<void> _checkIfMediaAlreadyDownloaded() async {
    // Check if we already have the file downloaded
    final mediaState = ref.read(mediaStateProvider(widget.mediaUrl));
    if (!mediaState.isDownloaded) {
      final cacheDir = await getTemporaryDirectory();
      final cacheKey = _generateThumbnailCacheKey(widget.mediaUrl);
      final mediaDir = Directory('${cacheDir.path}/media');
      final mediaFile = File('${mediaDir.path}/$cacheKey${widget.isVideo ? ".mp4" : ".jpg"}');
      if (await mediaFile.exists()) {
        ref.read(mediaStateProvider(widget.mediaUrl).notifier).setDownloaded();
      }
    }
  }

  String _generateThumbnailCacheKey(String url) {
    // Create a unique but consistent key for caching
    return Uuid().v4();
  }

  Future<File?> _getThumbnailCacheFile(String url) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final cacheKey = _generateThumbnailCacheKey(url);
      final thumbnailDir = Directory('${cacheDir.path}/thumbnails');

      if (!await thumbnailDir.exists()) {
        await thumbnailDir.create(recursive: true);
      }

      final thumbnailFile = File('${thumbnailDir.path}/$cacheKey.jpg');

      if (await thumbnailFile.exists()) {
        return thumbnailFile;
      }
    } catch (e) {
      print('Error checking thumbnail cache: $e');
    }
    return null;
  }

  Future<void> _cacheThumbnail(String url, Uint8List thumbnailData) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final cacheKey = _generateThumbnailCacheKey(url);
      final thumbnailDir = Directory('${cacheDir.path}/thumbnails');

      if (!await thumbnailDir.exists()) {
        await thumbnailDir.create(recursive: true);
      }

      final thumbnailFile = File('${thumbnailDir.path}/$cacheKey.jpg');
      await thumbnailFile.writeAsBytes(thumbnailData);
    } catch (e) {
      print('Error caching thumbnail: $e');
    }
  }

  Future<void> _loadThumbnail() async {
    if (_loadingThumbnail) return;

    setState(() {
      _loadingThumbnail = true;
    });

    try {
      // First check if we have a cached thumbnail
      final cachedThumbnail = await _getThumbnailCacheFile(widget.mediaUrl);

      if (cachedThumbnail != null) {
        final thumbnailBytes = await cachedThumbnail.readAsBytes();
        setState(() {
          _thumbnail = thumbnailBytes;
          _loadingThumbnail = false;
        });
        return;
      }

      // If no cached thumbnail, generate one
      if (widget.isVideo) {
        final thumbnailBytes = await VideoThumbnail.thumbnailData(
          video: widget.mediaUrl,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 250,
          quality: 50,
        );

        if (thumbnailBytes != null) {
          await _cacheThumbnail(widget.mediaUrl, thumbnailBytes);
          setState(() {
            _thumbnail = thumbnailBytes;
          });
        }
      }
    } catch (e) {
      print('Error loading thumbnail: $e');
    } finally {
      setState(() {
        _loadingThumbnail = false;
      });
    }
  }

  void _initializeVideoIfNeeded() {
    final mediaState = ref.read(mediaStateProvider(widget.mediaUrl));

    if (widget.isVideo && mediaState.isDownloaded && mediaState.localFile != null && _controller == null) {
      _controller = VideoPlayerController.file(mediaState.localFile!)
        ..setLooping(true)
        ..initialize().then((_) {
          ref.read(mediaStateProvider(widget.mediaUrl).notifier).setVideoInitialized(true);
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaState = ref.watch(mediaStateProvider(widget.mediaUrl));

    // Initialize video controller when file is downloaded
    if (widget.isVideo && mediaState.isDownloaded && mediaState.localFile != null && _controller == null) {
      _initializeVideoIfNeeded();
    }

    return Container(
      height: 250,
      width: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withOpacity(0.1),
      ),
      clipBehavior: Clip.hardEdge,
      child: _buildMediaContent(mediaState),
    );
  }

  Widget _buildVideoPlayer(MediaState mediaState) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: () {
            if (_controller != null && _controller!.value.isInitialized) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullscreenVideoPlayerPage(
                    videoFile: mediaState.localFile!,
                    tag: mediaState.localFile!.path,
                  ),
                ),
              );
            }
          },
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
        if (!mediaState.isPlaying)
          Container(
            decoration: BoxDecoration(
              color: Colors.black26,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.play_arrow, color: Colors.white, size: 40),
          ),
      ],
    );
  }

  Widget _buildImage(MediaState mediaState) {
    if (mediaState.localFile != null) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FullscreenImagePage(imageFile: mediaState.localFile!),
            ),
          );
        },
        child: Hero(
          tag: mediaState.localFile!.path,
          child: Image.file(
            mediaState.localFile!,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildMediaContent(MediaState mediaState) {
    if (!mediaState.isDownloaded) {
      return _buildDownloadView(mediaState);
    }

    if (widget.isVideo) {
      return _buildVideoPlayer(mediaState);
    } else {
      return _buildImage(mediaState);
    }
  }

  Widget _buildDownloadView(MediaState mediaState) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Show the thumbnail in the background
        _buildThumbnailPreview(),

        // Add an overlay to dim the thumbnail
        Container(
          color: Colors.black.withOpacity(0.4),
        ),

        // Show the download button or progress indicator
        Center(
          child: mediaState.isDownloading
              ? Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.download_rounded, size: 36, color: Colors.white),
                    onPressed: () => ref.read(mediaStateProvider(widget.mediaUrl).notifier).downloadMedia(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildThumbnailPreview() {
    if (_thumbnail != null) {
      // Show the generated thumbnail
      return Image.memory(
        _thumbnail!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (!widget.isVideo) {
      // For images, show a low-quality cached network image
      return CachedNetworkImage(
        imageUrl: widget.mediaUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(
          color: Colors.grey[300],
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[300],
          child: Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      );
    } else {
      // Fallback for videos without thumbnail yet
      return Container(
        color: Colors.grey[900],
        child: Center(
          child: Icon(Icons.play_circle_outline, size: 50, color: Colors.white54),
        ),
      );
    }
  }
}

class MediaPostPreview extends ConsumerWidget {
  final String mediaUrl;
  final bool isVideo;

  const MediaPostPreview({
    super.key,
    required this.mediaUrl,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    if (!isVideo) {
      return Container(
        width: double.infinity,
        color: colorScheme.surfaceContainerHighest,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Shimmer placeholder that fills the container
            ShimmerLoadingEffect(),

            // Image with proper sizing using CachedNetworkImage
            Center(
              child: CachedNetworkImage(
                imageUrl: mediaUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                fadeInDuration: const Duration(milliseconds: 500),
                fadeInCurve: Curves.easeOut,
                placeholder: (context, url) => const SizedBox.shrink(),
                imageBuilder: (context, imageProvider) => AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) {
                  print("ERROR: $error");
                  return Container(
                    color: colorScheme.errorContainer,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, color: colorScheme.error, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Image could not be loaded',
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }
    final videoState = ref.watch(videoPlayerControllerProvider(mediaUrl));

    return Container(
      height: 300,
      width: double.infinity,
      color: colorScheme.surfaceContainerHighest,
      child: videoState.when(
        data: (controller) {
          final isPlaying = controller.value.isPlaying;

          return Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
              // Animated play/pause button
              AnimatedOpacity(
                opacity: isPlaying ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: GestureDetector(
                  onTap: () {
                    final notifier = ref.read(videoPlayerControllerProvider(mediaUrl).notifier);
                    isPlaying ? notifier.pause() : notifier.play();
                  },
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: kDeepPink,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
              // Video duration indicator
              if (controller.value.isInitialized)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (context, value, child) {
                      final position = value.position;
                      final duration = value.duration;
                      final progress = position.inMilliseconds / (duration.inMilliseconds == 0 ? 1 : duration.inMilliseconds);

                      return LinearProgressIndicator(
                        value: progress,
                        color: colorScheme.primary,
                        backgroundColor: colorScheme.primary.withOpacity(0.3),
                        minHeight: 3,
                      );
                    },
                  ),
                ),
            ],
          );
        },
        loading: () => const FancyLoadingIndicator(),
        error: (e, _) => ErrorDisplay(error: e.toString()),
      ),
    );
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

class MediaFilePreview extends ConsumerWidget {
  final File mediaFile;
  final bool isVideo;

  const MediaFilePreview({
    Key? key,
    required this.mediaFile,
    required this.isVideo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 250,
      width: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withOpacity(0.1),
      ),
      clipBehavior: Clip.hardEdge,
      child: isVideo ? _buildVideoPlayer(ref) : _buildImageViewer(context),
    );
  }

  Widget _buildVideoPlayer(WidgetRef ref) {
    final videoControllerAsync = ref.watch(mediaFileVideoControllerProvider(mediaFile));
    final isPlaying = ref.watch(videoPlayingStateProvider(mediaFile));

    return videoControllerAsync.when(
      data: (controller) {
        return Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () {
                ref.read(mediaFileVideoControllerProvider(mediaFile).notifier).togglePlayPause(ref);
              },
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
            if (!isPlaying)
              Container(
                decoration: const BoxDecoration(
                  color: kDeepPink,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
              ),
            // Video progress indicator
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                colors: const VideoProgressColors(
                  playedColor: Colors.blue,
                  bufferedColor: Colors.grey,
                  backgroundColor: Colors.black45,
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text(
          'Error loading video: $error',
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildImageViewer(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullScreenImage(imageFile: mediaFile),
          ),
        );
      },
      child: Hero(
        tag: mediaFile.path,
        child: Image.file(
          mediaFile,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}

class ExplorePostMediaDisplay extends ConsumerWidget {
  final String mediaUrl;
  final bool isVideo;

  const ExplorePostMediaDisplay({
    Key? key,
    required this.mediaUrl,
    this.isVideo = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!isVideo) {
      // Image content
      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(
          minHeight: 200,
          maxHeight: 300,
        ),
        color: Colors.grey.shade100,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Shimmer placeholder that fills the container
            ShimmerLoadingEffect(),

            // Image with proper sizing using CachedNetworkImage
            Center(
              child: CachedNetworkImage(
                imageUrl: mediaUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                fadeInDuration: const Duration(milliseconds: 500),
                fadeInCurve: Curves.easeOut,
                placeholder: (context, url) => const SizedBox.shrink(),
                imageBuilder: (context, imageProvider) => AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) {
                  print("ERROR: $error");
                  return Container(
                    color: Colors.grey.shade200,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, color: Colors.grey, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Image could not be loaded',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    } else {
      // Video content
      final videoState = ref.watch(videoPlayerControllerProvider(mediaUrl));

      return Container(
        width: double.infinity,
        constraints: const BoxConstraints(
          minHeight: 200,
          maxHeight: 300,
        ),
        color: Colors.grey.shade100,
        child: videoState.when(
          data: (controller) {
            final isPlaying = controller.value.isPlaying;

            return Stack(
              alignment: Alignment.center,
              children: [
                // Video player
                controller.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: VideoPlayer(controller),
                      )
                    : const Center(child: CircularProgressIndicator()),

                // Animated play/pause button
                AnimatedOpacity(
                  opacity: isPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: GestureDetector(
                    onTap: () {
                      final notifier = ref.read(videoPlayerControllerProvider(mediaUrl).notifier);
                      isPlaying ? notifier.pause() : notifier.play();
                    },
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: kDeepPink,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),

                // Video progress indicator
                if (controller.value.isInitialized)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ValueListenableBuilder(
                      valueListenable: controller,
                      builder: (context, value, child) {
                        final position = value.position;
                        final duration = value.duration;
                        final progress = position.inMilliseconds / (duration.inMilliseconds == 0 ? 1 : duration.inMilliseconds);

                        return LinearProgressIndicator(
                          value: progress,
                          color: kDeepPink,
                          backgroundColor: kDeepPink.withOpacity(0.3),
                          minHeight: 3,
                        );
                      },
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(kDeepPink),
            ),
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Video could not be loaded',
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}

// Simple fullscreen image viewer
class FullScreenImage extends StatelessWidget {
  final File imageFile;

  const FullScreenImage({Key? key, required this.imageFile}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Hero(
              tag: imageFile.path,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: Image.file(
                  imageFile,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

// Simple fullscreen video player with Riverpod
class FullScreenVideoPlayer extends ConsumerWidget {
  final File videoFile;

  const FullScreenVideoPlayer({Key? key, required this.videoFile}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoControllerAsync = ref.watch(mediaFileVideoControllerProvider(videoFile));
    final isPlaying = ref.watch(videoPlayingStateProvider(videoFile));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: videoControllerAsync.when(
              data: (controller) => AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (error, _) => Text(
                'Error: $error',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          // Play/pause button
          Center(
            child: GestureDetector(
              onTap: () {
                if (videoControllerAsync.hasValue) {
                  ref.read(mediaFileVideoControllerProvider(videoFile).notifier).togglePlayPause(ref);
                }
              },
              child: AnimatedOpacity(
                opacity: isPlaying ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: kDeepPink,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          ),
          // Video controls
          videoControllerAsync.when(
            data: (controller) => Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                    colors: const VideoProgressColors(
                      playedColor: kDeepPink,
                      bufferedColor: Colors.grey,
                      backgroundColor: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
          // Close button
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class ShimmerLoadingEffect extends StatefulWidget {
  const ShimmerLoadingEffect({super.key});

  @override
  State<ShimmerLoadingEffect> createState() => _ShimmerLoadingEffectState();
}

class _ShimmerLoadingEffectState extends State<ShimmerLoadingEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade100,
                Colors.grey.shade300,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: FractionalOffset(_animation.value, 0.0),
              end: FractionalOffset(_animation.value + 1.0, 1.0),
            ).createShader(bounds);
          },
          child: Container(
            color: Colors.white,
          ),
        );
      },
    );
  }
}

class FancyLoadingIndicator extends StatelessWidget {
  const FancyLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SpinKitPulsingGrid(
            color: kDeepPink,
            size: 50.0,
          ),
        ],
      ),
    );
  }
}

class ErrorDisplay extends StatelessWidget {
  final String error;

  const ErrorDisplay({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              color: colorScheme.error,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Could not load media',
            style: TextStyle(
              color: colorScheme.error,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(color: colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// This is a custom animation widget that you can use if flutter_spinkit is not available
class SpinKitPulsingGrid extends StatefulWidget {
  final Color color;
  final double size;

  const SpinKitPulsingGrid({
    super.key,
    required this.color,
    this.size = 50.0,
  });

  @override
  State<SpinKitPulsingGrid> createState() => _SpinKitPulsingGridState();
}

class _SpinKitPulsingGridState extends State<SpinKitPulsingGrid> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: Size.square(widget.size),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.0,
          crossAxisSpacing: 4.0,
          mainAxisSpacing: 4.0,
        ),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 9,
        itemBuilder: (context, index) {
          final delay = (index / 9) * 400;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final offset = ((_controller.value * 1500) - delay) % 1500 / 1500;
              final scale = offset < 0.5 ? 0.5 + offset : 1.5 - offset;
              final opacity = 0.3 + (offset * 0.7);

              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
