import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fraction/fraction.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:pro_image_editor/pro_image_editor.dart' as pe;
import 'package:uuid/uuid.dart';
import 'package:video_editor/video_editor.dart';

import '../Classes/Media.dart';
import '../Helpers/PopUp.dart';
import '../MainFlow/PickerScreen.dart';
import 'ExportVideo.dart';

final imagePickerProvider = StateNotifierProvider<ImagePickerNotifier, File?>((ref) {
  return ImagePickerNotifier();
});

class ImagePickerNotifier extends StateNotifier<File?> {
  ImagePickerNotifier() : super(null);

  final _cropEditorKey = GlobalKey<pe.CropRotateEditorState>();

  Future<void> pickAndEditImage(BuildContext context) async {
    final selectedMedia = await Navigator.push<Media?>(
      context,
      MaterialPageRoute(
        builder: (context) => const PickerScreen(selectedMedia: null),
      ),
    );
    if (selectedMedia == null) return;

    final file = await selectedMedia.assetEntity.file;
    if (file == null) return;

    if (selectedMedia.assetEntity.type == AssetType.image) {
      final result = await _openCropperFirst(context, file);
      if (result == null) return;
      final editedImage = result['file'] as File?;

      if (editedImage != null) {
        state = editedImage;
        print("New image picked and cropped: \${editedImage.path}");
      }
    } else if (selectedMedia.assetEntity.type == AssetType.video) {
      final editedVideo = await Navigator.push<File?>(
        context,
        MaterialPageRoute(
          builder: (context) => VideoEditor(file: file),
        ),
      );

      if (editedVideo != null) {
        state = File(editedVideo.path);
        print("New video picked and edited: ${editedVideo.path}");
      }
    }
  }

  Future<Map<String, dynamic>?> _openCropperFirst(BuildContext context, File imageFile) async {
    final cropEditorConfigs = pe.ProImageEditorConfigs(
      cropRotateEditor: const pe.CropRotateEditorConfigs(initAspectRatio: 3 / 4, canChangeAspectRatio: false),
    );

    pe.TransformConfigs? transformations;
    pe.ImageInfos? imageInfos;

    final cropResult = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => pe.CropRotateEditor.file(
          imageFile,
          key: _cropEditorKey,
          initConfigs: pe.CropRotateEditorInitConfigs(
            theme: ThemeData(
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
            ),
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

    if (cropResult == null) return null;

    transformations = cropResult['transforms'] as pe.TransformConfigs;
    imageInfos = cropResult['imageInfos'] as pe.ImageInfos;

    return await _openMainEditor(context, imageFile, transformations, imageInfos);
  }

  Future<Map<String, dynamic>?> _openMainEditor(
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

    final result = await Navigator.push<Uint8List>(
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

    if (result == null) return null;

    final String newPath = '${Directory.systemTemp.path}/edited_${const Uuid().v4()}.jpg';
    final File newFile = File(newPath);
    await newFile.writeAsBytes(result);

    return {
      'file': newFile,
      'imageInfos': imageInfos,
    };
  }

  void clearImage() {
    state = null;
  }
}

class VideoEditor extends ConsumerStatefulWidget {
  const VideoEditor({super.key, required this.file});

  final File file;

  @override
  ConsumerState<VideoEditor> createState() => _VideoEditorState();
}

class _VideoEditorState extends ConsumerState<VideoEditor> {
  final _exportingProgress = ValueNotifier<double>(0.0);
  final _isExporting = ValueNotifier<bool>(false);
  final double height = 60;

  /// On the web, when multiple VideoPlayers reuse the same VideoController,
  /// only the last one can show the frames.
  /// Therefore, when CropScreen is popped, the CropGridViewer should be given a
  /// new key to refresh itself.
  ///
  /// https://github.com/flutter/flutter/issues/124210
  int cropGridViewerKey = 0;

  late final _controller = VideoEditorController.file(
    widget.file,
    minDuration: const Duration(seconds: 1),
    maxDuration: const Duration(seconds: 60),
  );

  void _exportVideo() async {
    _exportingProgress.value = 0;
    _isExporting.value = true;

    final config = VideoFFmpegVideoEditorConfig(
      _controller,
    );

    await ExportService.runFFmpegCommand(
      await config.getExecuteConfig(),
      onProgress: (stats) {
        _exportingProgress.value = config.getFFmpegProgress(stats.getTime() as int);
      },
      onError: (e, s) {
        print("Error exporting video!");
        print(e);
        print(s);
        Popup.showPopUp(text: "Error exporting: $e", context: context);
      },
      onCompleted: (file) {
        _isExporting.value = false;
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => VideoResultPopup(video: file),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _controller.initialize(aspectRatio: 3 / 4).then((_) {
      if (mounted) {
        setState(() {});
      }
    }).catchError((error) {
      if (mounted) {
        Navigator.pop(context);
      }
    }, test: (e) => e is VideoMinDurationError);
  }

  @override
  void dispose() {
    _exportingProgress.dispose();
    _isExporting.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _controller.initialized
            ? SafeArea(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        _topNavBar(),
                        Expanded(
                          child: DefaultTabController(
                            length: 2,
                            child: Column(
                              children: [
                                Expanded(
                                  child: TabBarView(
                                    physics: const NeverScrollableScrollPhysics(),
                                    children: [
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          CropGridViewer.preview(
                                            key: ValueKey(cropGridViewerKey),
                                            controller: _controller,
                                          ),
                                          AnimatedBuilder(
                                            animation: _controller.video,
                                            builder: (_, __) => AnimatedOpacity(
                                              opacity: !_controller.isPlaying ? 1.0 : 0.0,
                                              duration: const Duration(seconds: 1),
                                              child: GestureDetector(
                                                onTap: _controller.video.play,
                                                child: Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: const BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.play_arrow,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  height: 200,
                                  margin: const EdgeInsets.only(top: 10),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: _trimSlider(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ValueListenableBuilder(
                                  valueListenable: _isExporting,
                                  builder: (_, bool export, __) => AnimatedOpacity(
                                    opacity: export ? 1.0 : 0.0,
                                    duration: const Duration(seconds: 1),
                                    child: AlertDialog(
                                      title: ValueListenableBuilder(
                                        valueListenable: _exportingProgress,
                                        builder: (_, double value, __) => Text(
                                          "Exporting video ${(value * 100).ceil()}%",
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _topNavBar() {
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.exit_to_app),
                tooltip: 'Leave editor',
                color: Colors.white,
              ),
            ),
            const VerticalDivider(endIndent: 22, indent: 22),
            Expanded(
              child: IconButton(
                onPressed: () => _controller.rotate90Degrees(RotateDirection.left),
                icon: const Icon(Icons.rotate_left),
                tooltip: 'Rotate unclockwise',
                color: Colors.white,
              ),
            ),
            Expanded(
              child: IconButton(
                onPressed: () => _controller.rotate90Degrees(RotateDirection.right),
                icon: const Icon(Icons.rotate_right),
                tooltip: 'Rotate clockwise',
                color: Colors.white,
              ),
            ),
            Expanded(
              child: IconButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => CropScreen(controller: _controller),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.crop,
                  color: Colors.white,
                ),
                tooltip: 'Open crop screen',
              ),
            ),
            const VerticalDivider(endIndent: 22, indent: 22),
            Expanded(
              child: IconButton(
                onPressed: () async {
                  _exportVideo();
                },
                icon: const Icon(Icons.check),
                tooltip: 'Export',
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String formatter(Duration duration) => [duration.inMinutes.remainder(60).toString().padLeft(2, '0'), duration.inSeconds.remainder(60).toString().padLeft(2, '0')].join(":");

  List<Widget> _trimSlider() {
    return [
      AnimatedBuilder(
        animation: Listenable.merge([
          _controller,
          _controller.video,
        ]),
        builder: (_, __) {
          final duration = _controller.videoDuration.inSeconds;
          final pos = _controller.trimPosition * duration;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: height / 4),
            child: Row(children: [
              if (pos.isFinite)
                Text(
                  formatter(Duration(seconds: pos.toInt())),
                  style: TextStyle(color: Colors.white),
                ),
              const Expanded(child: SizedBox()),
              AnimatedOpacity(
                opacity: _controller.isTrimming ? 1.0 : 0.0,
                duration: const Duration(seconds: 1),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    formatter(_controller.startTrim),
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    formatter(_controller.endTrim),
                    style: TextStyle(color: Colors.white),
                  ),
                ]),
              ),
            ]),
          );
        },
      ),
      Container(
        width: MediaQuery.of(context).size.width,
        margin: EdgeInsets.symmetric(vertical: height / 4),
        child: TrimSlider(
          controller: _controller,
          height: height,
          horizontalMargin: height / 4,
          child: TrimTimeline(
            controller: _controller,
            padding: const EdgeInsets.only(top: 10),
          ),
        ),
      )
    ];
  }
}

class CropScreen extends StatelessWidget {
  const CropScreen({super.key, required this.controller});

  final VideoEditorController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: IconButton(
                  onPressed: () => controller.rotate90Degrees(RotateDirection.left),
                  icon: const Icon(Icons.rotate_left),
                ),
              ),
              Expanded(
                child: IconButton(
                  onPressed: () => controller.rotate90Degrees(RotateDirection.right),
                  icon: const Icon(Icons.rotate_right),
                ),
              )
            ]),
            const SizedBox(height: 15),
            Expanded(
              child: CropGridViewer.edit(
                controller: controller,
                rotateCropArea: false,
                margin: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
            const SizedBox(height: 15),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                flex: 2,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Center(
                    child: Text(
                      "cancel",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (_, __) => Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () => controller.preferredCropAspectRatio = controller.preferredCropAspectRatio?.toFraction().inverse().toDouble(),
                            icon: controller.preferredCropAspectRatio != null && controller.preferredCropAspectRatio! < 1
                                ? const Icon(Icons.panorama_vertical_select_rounded)
                                : const Icon(Icons.panorama_vertical_rounded),
                          ),
                          IconButton(
                            onPressed: () => controller.preferredCropAspectRatio = controller.preferredCropAspectRatio?.toFraction().inverse().toDouble(),
                            icon: controller.preferredCropAspectRatio != null && controller.preferredCropAspectRatio! > 1
                                ? const Icon(Icons.panorama_horizontal_select_rounded)
                                : const Icon(Icons.panorama_horizontal_rounded),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _buildCropButton(context, Fraction.fromString("3/4")),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: IconButton(
                  onPressed: () {
                    // WAY 1: validate crop parameters set in the crop view
                    controller.applyCacheCrop();
                    // WAY 2: update manually with Offset values
                    // controller.updateCrop(const Offset(0.2, 0.2), const Offset(0.8, 0.8));
                    Navigator.pop(context);
                  },
                  icon: Center(
                    child: Text(
                      "done",
                      style: TextStyle(
                        color: const CropGridStyle().selectedBoundariesColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildCropButton(BuildContext context, Fraction? f) {
    if (controller.preferredCropAspectRatio != null && controller.preferredCropAspectRatio! > 1) f = f?.inverse();

    return Flexible(
      child: TextButton(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: controller.preferredCropAspectRatio == f?.toDouble() ? Colors.grey.shade800 : null,
          foregroundColor: controller.preferredCropAspectRatio == f?.toDouble() ? Colors.white : null,
          textStyle: Theme.of(context).textTheme.bodySmall,
        ),
        onPressed: () => controller.preferredCropAspectRatio = f?.toDouble(),
        child: Text(f == null ? 'free' : '${f.numerator}:${f.denominator}'),
      ),
    );
  }
}
