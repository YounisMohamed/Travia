import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../Helpers/AppColors.dart';
import '../Providers/ChatDetailsProvider.dart';

class SimpleRecorderButton extends ConsumerStatefulWidget {
  final void Function(String path) onStop;

  const SimpleRecorderButton({super.key, required this.onStop});

  @override
  ConsumerState<SimpleRecorderButton> createState() => _SimpleRecorderButtonState();
}

class _SimpleRecorderButtonState extends ConsumerState<SimpleRecorderButton> {
  final _audioRecorder = AudioRecorder();

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      const config = RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1);
      await _audioRecorder.start(config, path: '${Directory.systemTemp.path}/edited_${const Uuid().v4()}.mp3');
      ref.read(recordingStateProvider.notifier).startRecording();
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    if (path != null) {
      widget.onStop(path);
    }
    ref.read(recordingStateProvider.notifier).stopRecording();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = ref.watch(recordingStateProvider);

    return IconButton(
      icon: Icon(isRecording ? Icons.stop : Icons.mic, color: kDeepPinkLight),
      onPressed: () {
        isRecording ? _stopRecording() : _startRecording();
      },
    );
  }
}
