import 'dart:io';

import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

class CropRect {
  final double x; // Left position (0.0 - 1.0)
  final double y; // Top position (0.0 - 1.0)
  final double width; // Width (0.0 - 1.0)
  final double height; // Height (0.0 - 1.0)

  const CropRect({
    this.x = 0.0,
    this.y = 0.0,
    this.width = 1.0,
    this.height = 1.0,
  });

  CropRect copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return CropRect(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

class VideoCropState {
  final bool isLoading;
  final bool isPlaying;
  final bool isCropping;
  final VideoPlayerController? controller;
  final File? finalVideo;
  final int? videoWidth;
  final int? videoHeight;
  final CropRect cropRect;
  final bool showCropOverlay;

  VideoCropState({
    this.isLoading = true,
    this.isPlaying = false,
    this.isCropping = false,
    this.controller,
    this.finalVideo,
    this.videoWidth,
    this.videoHeight,
    this.cropRect = const CropRect(), // Changed to const constructor
    this.showCropOverlay = true,
  });

  VideoCropState copyWith({
    bool? isLoading,
    bool? isPlaying,
    bool? isCropping,
    VideoPlayerController? controller,
    File? finalVideo,
    int? videoWidth,
    int? videoHeight,
    CropRect? cropRect,
    bool? showCropOverlay,
  }) {
    return VideoCropState(
      isLoading: isLoading ?? this.isLoading,
      isPlaying: isPlaying ?? this.isPlaying,
      isCropping: isCropping ?? this.isCropping,
      controller: controller ?? this.controller,
      finalVideo: finalVideo ?? this.finalVideo,
      videoWidth: videoWidth ?? this.videoWidth,
      videoHeight: videoHeight ?? this.videoHeight,
      cropRect: cropRect ?? this.cropRect,
      showCropOverlay: showCropOverlay ?? this.showCropOverlay,
    );
  }
}

class VideoCropController extends StateNotifier<VideoCropState> {
  final File originalVideo;
  final double targetAspectRatio;

  VideoCropController({
    required this.originalVideo,
    this.targetAspectRatio = 1, // Parameter name changed to match usage in provider
  }) : super(VideoCropState()) {
    _init();
  }

  Future<void> _init() async {
    // Load video player without cropping
    final controller = VideoPlayerController.file(originalVideo);
    await controller.initialize();
    controller.setLooping(true);
    controller.play();

    // Get video dimensions
    final probeResult = await FFprobeKit.getMediaInformation(originalVideo.path);
    final info = probeResult.getMediaInformation();

    int? width, height;
    if (info != null) {
      final stream = info.getStreams().firstWhere((s) => s.getType() == 'video');
      width = stream.getWidth();
      height = stream.getHeight();
      String? rotationStr = stream.getAllProperties()?['rotation']?.toString();

      // Handle video rotation
      if (rotationStr == '90' || rotationStr == '270' || rotationStr == '-90') {
        final temp = width;
        width = height;
        height = temp;
      }
    }

    // Calculate initial crop rect based on target aspect ratio
    CropRect initialCropRect = _calculateInitialCropRect(width, height);

    state = state.copyWith(
      isLoading: false,
      isPlaying: true,
      controller: controller,
      videoWidth: width,
      videoHeight: height,
      cropRect: initialCropRect,
    );
  }

  CropRect _calculateInitialCropRect(int? width, int? height) {
    if (width == null || height == null) return const CropRect();

    double currentRatio = width / height;

    // If current ratio is already close to target ratio, use full frame
    if ((currentRatio - targetAspectRatio).abs() < 0.01) {
      return const CropRect();
    }

    // Calculate dimensions that preserve as much content as possible
    double cropWidth, cropHeight;

    // If current video is wider than target aspect ratio
    if (currentRatio > targetAspectRatio) {
      // We'll use full height and adjust width
      cropHeight = 1.0;
      cropWidth = (height * targetAspectRatio) / width;
    } else {
      // We'll use full width and adjust height
      cropWidth = 1.0;
      cropHeight = (width / targetAspectRatio) / height;
    }

    // Center the crop
    double x = (1 - cropWidth) / 2;
    double y = (1 - cropHeight) / 2;

    return CropRect(
      x: x,
      y: y,
      width: cropWidth,
      height: cropHeight,
    );
  }

  void togglePlay() {
    final controller = state.controller;
    if (controller == null) return;

    if (controller.value.isPlaying) {
      controller.pause();
      state = state.copyWith(isPlaying: false);
    } else {
      controller.play();
      state = state.copyWith(isPlaying: true);
    }
  }

  void toggleCropOverlay() {
    state = state.copyWith(showCropOverlay: !state.showCropOverlay);
  }

  void updateCropRect(CropRect newRect) {
    // Ensure crop rect maintains the target aspect ratio
    double width = newRect.width;
    double height = newRect.height;

    if (state.videoWidth != null && state.videoHeight != null) {
      double pixelWidth = width * state.videoWidth!;
      double pixelHeight = height * state.videoHeight!;
      double currentRatio = pixelWidth / pixelHeight;

      if ((currentRatio - targetAspectRatio).abs() > 0.01) {
        // Adjust height to match width based on aspect ratio
        height = width * state.videoWidth! / (targetAspectRatio * state.videoHeight!);

        // Ensure we stay in bounds
        if (newRect.y + height > 1.0) {
          height = 1.0 - newRect.y;
          width = height * targetAspectRatio * state.videoHeight! / state.videoWidth!;
        }
      }
    }

    state = state.copyWith(
      cropRect: newRect.copyWith(
        width: width,
        height: height,
      ),
    );
  }

  Future<void> cropVideo() async {
    if (state.isCropping) return;

    state = state.copyWith(isCropping: true);

    try {
      final croppedFile = await _performCrop(originalVideo, state.cropRect);

      // Dispose old controller
      await state.controller?.dispose();

      // Create new controller with cropped video
      final controller = VideoPlayerController.file(croppedFile);
      await controller.initialize();
      controller.setLooping(true);
      controller.play();

      state = state.copyWith(
        isCropping: false,
        controller: controller,
        finalVideo: croppedFile,
        isPlaying: true,
        showCropOverlay: false,
      );
    } catch (e) {
      state = state.copyWith(isCropping: false);
      print('Error cropping video: $e');
    }
  }

  Future<File> _performCrop(File file, CropRect cropRect) async {
    final inputPath = file.path;
    final dir = p.dirname(inputPath);
    final outputPath = '$dir/cropped_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final width = state.videoWidth;
    final height = state.videoHeight;

    if (width == null || height == null) return file;

    // Convert normalized coordinates to pixel values
    int pixelX = (cropRect.x * width).round();
    int pixelY = (cropRect.y * height).round();
    int pixelWidth = (cropRect.width * width).round();
    int pixelHeight = (cropRect.height * height).round();

    // Safety check
    if (pixelWidth <= 0 || pixelHeight <= 0 || pixelX < 0 || pixelY < 0 || pixelX + pixelWidth > width || pixelY + pixelHeight > height) {
      return file;
    }

    final filter = 'crop=$pixelWidth:$pixelHeight:$pixelX:$pixelY';
    final cmd = '-y -i "$inputPath" -vf "$filter" -c:v libx264 -preset ultrafast -crf 23 -c:a copy "$outputPath"';

    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return File(outputPath);
    } else {
      print('FFmpeg command failed: ${await session.getLogsAsString()}');
      return file;
    }
  }

  @override
  void dispose() {
    state.controller?.dispose();
    super.dispose();
  }
}

// Custom crop overlay widget
class VideoCropOverlay extends StatefulWidget {
  final CropRect cropRect;
  final bool visible;
  final Function(CropRect) onCropRectChanged;
  final double aspectRatio;

  const VideoCropOverlay({
    Key? key,
    required this.cropRect,
    required this.visible,
    required this.onCropRectChanged,
    required this.aspectRatio,
  }) : super(key: key);

  @override
  _VideoCropOverlayState createState() => _VideoCropOverlayState();
}

class _VideoCropOverlayState extends State<VideoCropOverlay> {
  late CropRect _localCropRect;
  bool _isDragging = false;
  bool _isResizing = false;
  int _activeBorder = -1; // -1=none, 0=top, 1=right, 2=bottom, 3=left
  int _activeCorner = -1; // -1=none, 0=topLeft, 1=topRight, 2=bottomRight, 3=bottomLeft

  @override
  void initState() {
    super.initState();
    _localCropRect = widget.cropRect;
  }

  @override
  void didUpdateWidget(VideoCropOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cropRect != widget.cropRect) {
      _localCropRect = widget.cropRect;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        // Calculate display rect based on container dimensions
        final displayRect = Rect.fromLTWH(
          _localCropRect.x * width,
          _localCropRect.y * height,
          _localCropRect.width * width,
          _localCropRect.height * height,
        );

        final handleSize = 20.0;

        return Stack(
          children: [
            // Semi-transparent overlay for areas outside crop rect
            CustomPaint(
              size: Size(width, height),
              painter: CropOverlayPainter(displayRect),
            ),

            // Draggable crop rect area
            Positioned(
              left: displayRect.left,
              top: displayRect.top,
              width: displayRect.width,
              height: displayRect.height,
              child: GestureDetector(
                onPanStart: (_) {
                  setState(() {
                    _isDragging = true;
                  });
                },
                onPanUpdate: (details) {
                  if (!_isDragging) return;

                  final dx = details.delta.dx / width;
                  final dy = details.delta.dy / height;

                  var newX = _localCropRect.x + dx;
                  var newY = _localCropRect.y + dy;

                  // Constrain to video boundaries
                  newX = newX.clamp(0.0, 1.0 - _localCropRect.width);
                  newY = newY.clamp(0.0, 1.0 - _localCropRect.height);

                  setState(() {
                    _localCropRect = _localCropRect.copyWith(x: newX, y: newY);
                  });
                  widget.onCropRectChanged(_localCropRect);
                },
                onPanEnd: (_) {
                  setState(() {
                    _isDragging = false;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),

            // Corner handles
            ..._buildCornerHandles(displayRect, width, height, handleSize),

            // Edge handles (for non-aspect constrained mode)
            if (widget.aspectRatio == null) ..._buildEdgeHandles(displayRect, width, height, handleSize),
          ],
        );
      },
    );
  }

  List<Widget> _buildCornerHandles(Rect displayRect, double containerWidth, double containerHeight, double handleSize) {
    final handlePadding = handleSize / 2;

    // Define the four corners
    final List<Offset> corners = [
      displayRect.topLeft,
      displayRect.topRight,
      displayRect.bottomRight,
      displayRect.bottomLeft,
    ];

    return List.generate(4, (index) {
      return Positioned(
        left: corners[index].dx - handlePadding,
        top: corners[index].dy - handlePadding,
        child: GestureDetector(
          onPanStart: (_) {
            setState(() {
              _isResizing = true;
              _activeCorner = index;
            });
          },
          onPanUpdate: (details) {
            if (!_isResizing || _activeCorner != index) return;

            // Get delta movements
            double dx = details.delta.dx / containerWidth;
            double dy = details.delta.dy / containerHeight;

            // Calculate new values based on corner
            var newRect = _applyCornerResize(index, dx, dy);

            // Apply aspect ratio constraint if needed
            if (widget.aspectRatio != null) {
              newRect = _applyAspectRatioConstraint(newRect, index);
            }

            // Validate and apply changes
            if (_isValidCropRect(newRect)) {
              setState(() {
                _localCropRect = newRect;
              });
              widget.onCropRectChanged(newRect);
            }
          },
          onPanEnd: (_) {
            setState(() {
              _isResizing = false;
              _activeCorner = -1;
            });
          },
          child: Container(
            width: handleSize,
            height: handleSize,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      );
    });
  }

  List<Widget> _buildEdgeHandles(Rect displayRect, double containerWidth, double containerHeight, double handleSize) {
    final handlePadding = handleSize / 2;

    // Define the four edges: top, right, bottom, left
    final List<Offset> centers = [
      Offset(displayRect.left + displayRect.width / 2, displayRect.top),
      Offset(displayRect.right, displayRect.top + displayRect.height / 2),
      Offset(displayRect.left + displayRect.width / 2, displayRect.bottom),
      Offset(displayRect.left, displayRect.top + displayRect.height / 2),
    ];

    return List.generate(4, (index) {
      // Cursor and icon direction based on edge
      MouseCursor cursor = index % 2 == 0 ? SystemMouseCursors.resizeUpDown : SystemMouseCursors.resizeLeftRight;

      return Positioned(
        left: centers[index].dx - handlePadding,
        top: centers[index].dy - handlePadding,
        child: MouseRegion(
          cursor: cursor,
          child: GestureDetector(
            onPanStart: (_) {
              setState(() {
                _isResizing = true;
                _activeBorder = index;
              });
            },
            onPanUpdate: (details) {
              if (!_isResizing || _activeBorder != index) return;

              // Get delta movements
              double dx = details.delta.dx / containerWidth;
              double dy = details.delta.dy / containerHeight;

              // Calculate new values based on edge
              var newRect = _applyEdgeResize(index, dx, dy);

              // Validate and apply changes
              if (_isValidCropRect(newRect)) {
                setState(() {
                  _localCropRect = newRect;
                });
                widget.onCropRectChanged(newRect);
              }
            },
            onPanEnd: (_) {
              setState(() {
                _isResizing = false;
                _activeBorder = -1;
              });
            },
            child: Container(
              width: handleSize,
              height: handleSize,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ),
      );
    });
  }

  CropRect _applyCornerResize(int cornerIndex, double dx, double dy) {
    switch (cornerIndex) {
      case 0: // Top-left
        return _localCropRect.copyWith(
          x: _localCropRect.x + dx,
          y: _localCropRect.y + dy,
          width: _localCropRect.width - dx,
          height: _localCropRect.height - dy,
        );
      case 1: // Top-right
        return _localCropRect.copyWith(
          y: _localCropRect.y + dy,
          width: _localCropRect.width + dx,
          height: _localCropRect.height - dy,
        );
      case 2: // Bottom-right
        return _localCropRect.copyWith(
          width: _localCropRect.width + dx,
          height: _localCropRect.height + dy,
        );
      case 3: // Bottom-left
        return _localCropRect.copyWith(
          x: _localCropRect.x + dx,
          width: _localCropRect.width - dx,
          height: _localCropRect.height + dy,
        );
      default:
        return _localCropRect;
    }
  }

  CropRect _applyEdgeResize(int edgeIndex, double dx, double dy) {
    switch (edgeIndex) {
      case 0: // Top edge
        return _localCropRect.copyWith(
          y: _localCropRect.y + dy,
          height: _localCropRect.height - dy,
        );
      case 1: // Right edge
        return _localCropRect.copyWith(
          width: _localCropRect.width + dx,
        );
      case 2: // Bottom edge
        return _localCropRect.copyWith(
          height: _localCropRect.height + dy,
        );
      case 3: // Left edge
        return _localCropRect.copyWith(
          x: _localCropRect.x + dx,
          width: _localCropRect.width - dx,
        );
      default:
        return _localCropRect;
    }
  }

  CropRect _applyAspectRatioConstraint(CropRect rect, int cornerIndex) {
    final aspectRatio = widget.aspectRatio!;

    // Calculate target height from width to maintain aspect ratio
    final targetHeight = rect.width / aspectRatio;

    // Apply the constraint based on which corner is being dragged
    switch (cornerIndex) {
      case 0: // Top-left
        return rect.copyWith(height: rect.width / aspectRatio);
      case 1: // Top-right
        return rect.copyWith(height: rect.width / aspectRatio);
      case 2: // Bottom-right
        return rect.copyWith(height: rect.width / aspectRatio);
      case 3: // Bottom-left
        return rect.copyWith(height: rect.width / aspectRatio);
      default:
        return rect;
    }
  }

  bool _isValidCropRect(CropRect rect) {
    // Minimum size check
    const minSize = 0.05; // 5% of container size
    if (rect.width < minSize || rect.height < minSize) {
      return false;
    }

    // Boundary check
    if (rect.x < 0 || rect.y < 0 || rect.x + rect.width > 1.0 || rect.y + rect.height > 1.0) {
      return false;
    }

    return true;
  }
}

class CropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  CropOverlayPainter(this.cropRect);

  @override
  void paint(Canvas canvas, Size size) {
    // Create semi-transparent overlay
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // Draw four rectangles to create the darkened areas outside crop rect
    // Top
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, cropRect.top),
      paint,
    );

    // Left
    canvas.drawRect(
      Rect.fromLTWH(0, cropRect.top, cropRect.left, cropRect.height),
      paint,
    );

    // Right
    canvas.drawRect(
      Rect.fromLTWH(cropRect.right, cropRect.top, size.width - cropRect.right, cropRect.height),
      paint,
    );

    // Bottom
    canvas.drawRect(
      Rect.fromLTWH(0, cropRect.bottom, size.width, size.height - cropRect.bottom),
      paint,
    );

    // Draw rule of thirds grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1;

    // Vertical lines
    final thirdWidth = cropRect.width / 3;
    canvas.drawLine(
      Offset(cropRect.left + thirdWidth, cropRect.top),
      Offset(cropRect.left + thirdWidth, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + thirdWidth * 2, cropRect.top),
      Offset(cropRect.left + thirdWidth * 2, cropRect.bottom),
      gridPaint,
    );

    // Horizontal lines
    final thirdHeight = cropRect.height / 3;
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + thirdHeight),
      Offset(cropRect.right, cropRect.top + thirdHeight),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + thirdHeight * 2),
      Offset(cropRect.right, cropRect.top + thirdHeight * 2),
      gridPaint,
    );

    // Draw border around crop rect
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(cropRect, borderPaint);
  }

  @override
  bool shouldRepaint(CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect;
  }
}

// Video crop UI widget that combines everything
class VideoCropScreen extends ConsumerWidget {
  final File videoFile;
  final double aspectRatio;

  const VideoCropScreen({
    required this.videoFile,
    this.aspectRatio = 1.0,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(videoCropProvider((videoFile, aspectRatio)));
    final controller = ref.read(videoCropProvider((videoFile, aspectRatio)).notifier);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Video'),
        actions: [
          IconButton(
            icon: Icon(state.showCropOverlay ? Icons.grid_off : Icons.grid_on),
            onPressed: controller.toggleCropOverlay,
            tooltip: state.showCropOverlay ? 'Hide Crop Overlay' : 'Show Crop Overlay',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Video player
                Center(
                  child: AspectRatio(
                    aspectRatio: state.controller!.value.aspectRatio,
                    child: VideoPlayer(state.controller!),
                  ),
                ),

                // Crop overlay
                if (state.controller != null)
                  Positioned.fill(
                    child: VideoCropOverlay(
                      cropRect: state.cropRect,
                      onCropRectChanged: controller.updateCropRect,
                      aspectRatio: 4 / 5,
                      visible: state.showCropOverlay,
                    ),
                  ),

                // Loading indicator while cropping
                if (state.isCropping)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Processing video...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: controller.togglePlay,
                  iconSize: 36,
                ),
                ElevatedButton(
                  onPressed: state.isCropping ? null : controller.cropVideo,
                  child: Text(state.finalVideo != null ? 'Re-crop Video' : 'Crop Video'),
                ),
                if (state.finalVideo != null)
                  ElevatedButton(
                    onPressed: () {
                      // Return the cropped video to previous screen
                      Navigator.of(context).pop(state.finalVideo);
                    },
                    child: const Text('Confirm'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final videoCropProvider = StateNotifierProvider.autoDispose.family<VideoCropController, VideoCropState, (File, double)>((ref, args) {
  return VideoCropController(
    originalVideo: args.$1,
    targetAspectRatio: args.$2, // Parameter name changed to match constructor
  );
});
