import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MediaPreview extends StatefulWidget {
  final String mediaUrl;
  final bool isVideo;

  const MediaPreview({
    super.key,
    required this.mediaUrl,
    required this.isVideo,
  });

  @override
  _MediaPreviewState createState() => _MediaPreviewState();
}

class _MediaPreviewState extends State<MediaPreview> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl))
        ..setLooping(true)
        ..initialize().then((_) {
          setState(() {}); // Update UI after initialization
        });
    }
  }

  @override
  void dispose() {
    if (widget.isVideo) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _togglePlayback() {
    if (_controller.value.isPlaying) {
      _controller.pause();
      setState(() => _isPlaying = false);
    } else {
      _controller.play();
      setState(() => _isPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVideo) {
      return Image.network(
        widget.mediaUrl,
        fit: BoxFit.contain,
        width: double.infinity,
      );
    }

    return SizedBox(
      height: 200,
      width: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _controller.value.isInitialized
              ? GestureDetector(
                  onTap: _togglePlayback,
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                )
              : const Center(
                  child: CircularProgressIndicator(),
                ),
          if (!_isPlaying)
            Positioned(
              child: IconButton(
                icon: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
                onPressed: _togglePlayback,
              ),
            ),
        ],
      ),
    );
  }
}
