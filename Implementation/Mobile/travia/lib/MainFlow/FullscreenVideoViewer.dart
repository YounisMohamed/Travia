import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class FullscreenVideoPlayerPage extends StatefulWidget {
  final File videoFile;
  final String tag;

  const FullscreenVideoPlayerPage({
    Key? key,
    required this.videoFile,
    required this.tag,
  }) : super(key: key);

  @override
  State<FullscreenVideoPlayerPage> createState() => _FullscreenVideoPlayerPageState();
}

class _FullscreenVideoPlayerPageState extends State<FullscreenVideoPlayerPage> {
  late VideoPlayerController _controller;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
    _controller.setLooping(true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            Center(
              child: Hero(
                tag: widget.tag,
                child: _controller.value.isInitialized
                    ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
                    : const CircularProgressIndicator(),
              ),
            ),

            // Top bar
            if (_showControls)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back button
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      // You can add share later if needed
                    ],
                  ),
                ),
              ),

            // Playback controls (bottom)
            if (_showControls && _controller.value.isInitialized)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  children: [
                    VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      colors: VideoProgressColors(
                        playedColor: Colors.red,
                        backgroundColor: Colors.grey,
                        bufferedColor: Colors.white38,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_controller.value.position),
                          style: const TextStyle(color: Colors.white),
                        ),
                        IconButton(
                          icon: Icon(
                            _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _controller.value.isPlaying ? _controller.pause() : _controller.play();
                            });
                          },
                        ),
                        Text(
                          _formatDuration(_controller.value.duration),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
