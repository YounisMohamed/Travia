import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Providers/ChatDetailsProvider.dart';
import 'audio_player.dart' as ap;
import 'audio_recorder.dart' as ar;

class RecorderPage extends ConsumerWidget {
  const RecorderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recorderState = ref.watch(recorderProvider);

    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: recorderState.showPlayer
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: ap.AudioPlayer(
                    source: recorderState.audioPath!,
                    onDelete: () {
                      ref.read(recorderProvider.notifier).deleteAudio();
                    },
                  ),
                )
              : ar.Recorder(
                  onStop: (path) {
                    ref.read(recorderProvider.notifier).setAudio(path);
                  },
                ),
        ),
      ),
    );
  }
}
