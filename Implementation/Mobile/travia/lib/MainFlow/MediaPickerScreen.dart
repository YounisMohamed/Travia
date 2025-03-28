import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Classes/Media.dart';
import '../Providers/MediaProviders.dart';
import 'PickerScreen.dart';

class MediaPickerScreen extends ConsumerWidget {
  const MediaPickerScreen({super.key});

  Future<void> _handleFloatingActionButton(BuildContext context, WidgetRef ref) async {
    final Media? result = await Navigator.push<Media>(
      context,
      MaterialPageRoute(
        builder: (context) => PickerScreen(selectedMedia: ref.read(selectedMediaProvider)),
      ),
    );

    if (result != null) {
      ref.read(selectedMediaProvider.notifier).updateSelectedMedias(result);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMedia = ref.watch(selectedMediaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Media Picker"),
      ),
      body: selectedMedia == null
          ? const Center(child: Text("No media selected"))
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: selectedMedia.widget,
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _handleFloatingActionButton(context, ref),
        child: const Icon(Icons.image_rounded),
      ),
    );
  }
}
