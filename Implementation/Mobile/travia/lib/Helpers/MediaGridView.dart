import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../Classes/Media.dart';

class MediasGridView extends StatelessWidget {
  final List<Media> medias;
  final Media? selectedMedia;
  final Function(Media) selectMedia;
  final ScrollController scrollController;

  const MediasGridView({
    super.key,
    required this.medias,
    required this.selectedMedia,
    required this.selectMedia,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: scrollController,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: medias.length,
      itemBuilder: (context, index) {
        final media = medias[index];
        final bool isSelected = selectedMedia?.assetEntity.id == media.assetEntity.id;
        final bool isVideo = media.assetEntity.type == AssetType.video;

        return GestureDetector(
          onTap: () => selectMedia(media),
          child: Stack(
            fit: StackFit.expand,
            children: [
              media.widget,
              if (isVideo)
                Positioned(
                  bottom: 4,
                  left: 4,
                  right: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Video Duration
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatDuration(media.assetEntity.videoDuration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      // Video Icon
                      const Icon(
                        Icons.videocam,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              if (isSelected)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: Icon(Icons.check_circle, color: Colors.white, size: 30),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }
}

class MultiMediasGridView extends StatelessWidget {
  final List<Media> medias;
  final List<Media> selectedMedias;
  final Function(Media) toggleMediaSelection;
  final ScrollController scrollController;

  const MultiMediasGridView({
    super.key,
    required this.medias,
    required this.selectedMedias,
    required this.toggleMediaSelection,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: scrollController,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: medias.length,
      itemBuilder: (context, index) {
        final media = medias[index];
        final bool isSelected = selectedMedias.any((m) => m.assetEntity.id == media.assetEntity.id);
        final bool isVideo = media.assetEntity.type == AssetType.video;
        final selectionIndex = isSelected ? selectedMedias.indexWhere((m) => m.assetEntity.id == media.assetEntity.id) + 1 : null;

        return GestureDetector(
          onTap: () {
            if (selectedMedias.length >= 5) return;
            toggleMediaSelection(media);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              media.widget,
              if (isVideo)
                Positioned(
                  bottom: 4,
                  left: 4,
                  right: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Video Duration
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatDuration(media.assetEntity.videoDuration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      // Video Icon
                      const Icon(
                        Icons.videocam,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              if (isSelected)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          "$selectionIndex",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }
}
