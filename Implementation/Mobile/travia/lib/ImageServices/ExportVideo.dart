import 'dart:developer';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/statistics.dart';
import 'package:flutter/material.dart';
import 'package:fraction/fraction.dart';
import 'package:path/path.dart' as path;
import 'package:video_editor/video_editor.dart';
import 'package:video_player/video_player.dart';

class ExportService {
  static Future<void> dispose() async {
    final executions = await FFmpegKit.listSessions();
    if (executions.isNotEmpty) await FFmpegKit.cancel();
  }

  static Future<FFmpegSession> runFFmpegCommand(
    FFmpegVideoEditorExecute execute, {
    required void Function(File file) onCompleted,
    void Function(Object, StackTrace)? onError,
    void Function(Statistics)? onProgress,
  }) {
    log('FFmpeg start process with command = ${execute.command}');
    return FFmpegKit.executeAsync(
      execute.command,
      (session) async {
        final state = FFmpegKitConfig.sessionStateToString(await session.getState());
        final code = await session.getReturnCode();

        if (ReturnCode.isSuccess(code)) {
          onCompleted(File(execute.outputPath));
        } else {
          if (onError != null) {
            onError(
              Exception('FFmpeg process exited with state $state and return code $code.\n${await session.getOutput()}'),
              StackTrace.current,
            );
          }
          return;
        }
      },
      null,
      onProgress,
    );
  }
}

Future<void> _getImageDimension(File file, {required Function(Size) onResult}) async {
  var decodedImage = await decodeImageFromList(file.readAsBytesSync());
  onResult(Size(decodedImage.width.toDouble(), decodedImage.height.toDouble()));
}

String _fileMBSize(File file) => ' ${(file.lengthSync() / (1024 * 1024)).toStringAsFixed(1)} MB';

class VideoResultPopup extends StatefulWidget {
  const VideoResultPopup({super.key, required this.video});

  final File video;

  @override
  State<VideoResultPopup> createState() => _VideoResultPopupState();
}

class _VideoResultPopupState extends State<VideoResultPopup> {
  VideoPlayerController? _controller;
  FileImage? _fileImage;
  Size _fileDimension = Size.zero;
  late final bool _isGif = path.extension(widget.video.path).toLowerCase() == ".gif";
  late String _fileMbSize;

  @override
  void initState() {
    super.initState();
    if (_isGif) {
      _getImageDimension(
        widget.video,
        onResult: (d) => setState(() => _fileDimension = d),
      );
    } else {
      _controller = VideoPlayerController.file(widget.video);
      _controller?.initialize().then((_) {
        _fileDimension = _controller?.value.size ?? Size.zero;
        setState(() {});
        _controller?.play();
        _controller?.setLooping(true);
      });
    }
    _fileMbSize = _fileMBSize(widget.video);
  }

  @override
  void dispose() {
    if (_isGif) {
      _fileImage?.evict();
    } else {
      _controller?.pause();
      _controller?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Center(
        child: Stack(
          alignment: Alignment.bottomLeft,
          children: [
            AspectRatio(
              aspectRatio: _fileDimension.aspectRatio == 0 ? 1 : _fileDimension.aspectRatio,
              child: _isGif ? Image.file(widget.video) : VideoPlayer(_controller!),
            ),
            Positioned(
              bottom: 0,
              child: FileDescription(
                description: {
                  'Video path': widget.video.path,
                  if (!_isGif) 'Video duration': '${((_controller?.value.duration.inMilliseconds ?? 0) / 1000).toStringAsFixed(2)}s',
                  'Video ratio': Fraction.fromDouble(_fileDimension.aspectRatio).reduce().toString(),
                  'Video dimension': _fileDimension.toString(),
                  'Video size': _fileMbSize,
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FileDescription extends StatelessWidget {
  const FileDescription({super.key, required this.description});

  final Map<String, String> description;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(fontSize: 11),
      child: Container(
        width: MediaQuery.of(context).size.width - 60,
        padding: const EdgeInsets.all(10),
        color: Colors.black.withOpacity(0.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: description.entries
              .map(
                (entry) => Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${entry.key}: ',
                        style: const TextStyle(fontSize: 11),
                      ),
                      TextSpan(
                        text: entry.value,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
