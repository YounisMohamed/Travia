import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class MediaPreview extends StatefulWidget {
  final String? mediaUrl;
  final File? image;
  final bool isVideo;

  const MediaPreview({
    Key? key,
    this.mediaUrl,
    this.image,
    required this.isVideo,
  }) : super(key: key);

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
      _controller = VideoPlayerController.networkUrl(Uri(path: widget.mediaUrl))
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
    if (!widget.isVideo && widget.image != null) {
      return Image(
        image: FileImage(widget.image!),
        fit: BoxFit.contain,
        width: double.infinity,
        height: 300,
      );
    }

    return Stack(
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
    );
  }
}

class MediaPostPreview extends StatefulWidget {
  final String mediaUrl;
  final bool isVideo;

  const MediaPostPreview({
    super.key,
    required this.mediaUrl,
    required this.isVideo,
  });

  @override
  _MediaPostPreviewState createState() => _MediaPostPreviewState();
}

class _MediaPostPreviewState extends State<MediaPostPreview> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _controller = VideoPlayerController.networkUrl(Uri(path: widget.mediaUrl))
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
        height: 300,
      );
    }

    return Stack(
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
    );
  }
}
