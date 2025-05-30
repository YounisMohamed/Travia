import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../Classes/Media.dart';
import '../Helpers/AppColors.dart';
import '../Providers/MediaProviders.dart';

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
      padding: const EdgeInsets.all(kGridSpacing),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: kGridSpacing,
        mainAxisSpacing: kGridSpacing,
      ),
      itemCount: medias.length,
      itemBuilder: (context, index) {
        final media = medias[index];
        final bool isSelected = selectedMedia?.assetEntity.id == media.assetEntity.id;
        final bool isVideo = media.assetEntity.type == AssetType.video;

        return GestureDetector(
          onTap: () => selectMedia(media),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kBorderRadius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Media thumbnail with subtle animation
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    border: isSelected ? Border.all(color: kDeepPink, width: 3) : null,
                    borderRadius: BorderRadius.circular(kBorderRadius),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isSelected ? kBorderRadius - 2 : kBorderRadius),
                    child: media.widget,
                  ),
                ),

                // Gradient overlay for better visibility of icons/text
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(isVideo ? 0.5 : 0.2),
                        ],
                        stops: const [0.7, 1.0],
                      ),
                    ),
                  ),
                ),

                // Video info (duration + icon)
                if (isVideo)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Video Duration
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatDuration(media.assetEntity.videoDuration),
                            style: const TextStyle(
                              color: kWhite,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        // Video Icon with purple tint
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_circle_fill_rounded,
                            color: kDeepPinkLight,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Selection overlay
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: kDeepPink.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(kBorderRadius),
                      ),
                      child: Stack(
                        children: [
                          // Purple gradient background
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    kDeepPink.withOpacity(0.3),
                                    kDeepPinkLight.withOpacity(0.5),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Checkmark icon
                          Center(
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: kDeepPink,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.check,
                                  color: kWhite,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
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
      padding: const EdgeInsets.all(kGridSpacing),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: kGridSpacing,
        mainAxisSpacing: kGridSpacing,
      ),
      itemCount: medias.length,
      itemBuilder: (context, index) {
        final media = medias[index];
        final bool isSelected = selectedMedias.any((m) => m.assetEntity.id == media.assetEntity.id);
        final bool isVideo = media.assetEntity.type == AssetType.video;
        final selectionIndex = isSelected ? selectedMedias.indexWhere((m) => m.assetEntity.id == media.assetEntity.id) + 1 : null;
        final bool isMaxReached = selectedMedias.length >= 5 && !isSelected;

        return GestureDetector(
          onTap: () {
            if (isMaxReached) return;
            toggleMediaSelection(media);
          },
          child: Opacity(
            opacity: isMaxReached ? 0.6 : 1.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(kBorderRadius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Media thumbnail with subtle animation
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      border: isSelected ? Border.all(color: kDeepPink, width: 3) : null,
                      borderRadius: BorderRadius.circular(kBorderRadius),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isSelected ? kBorderRadius - 2 : kBorderRadius),
                      child: media.widget,
                    ),
                  ),

                  // Gradient overlay for better visibility
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(isVideo ? 0.5 : 0.2),
                          ],
                          stops: const [0.7, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Video info (duration + icon)
                  if (isVideo)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Video Duration
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatDuration(media.assetEntity.videoDuration),
                              style: const TextStyle(
                                color: kWhite,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          // Video Icon
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_circle_fill_rounded,
                              color: kDeepPinkLight,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Selection overlay with index number
                  if (isSelected)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              kDeepPink.withOpacity(0.3),
                              kDeepPinkLight.withOpacity(0.5),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(kBorderRadius),
                        ),
                        child: Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [kDeepPink, kDeepPinkLight],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                "$selectionIndex",
                                style: const TextStyle(
                                  color: kWhite,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // "Max Limit" visual indicator
                  if (isMaxReached)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.5),
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "5 max",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: kWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
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

class MediaPickerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBackPressed;
  final VoidCallback? onDonePressed;
  final int? selectedCount;
  final int maxSelections;
  final WidgetRef ref;

  const MediaPickerAppBar({
    Key? key,
    required this.title,
    required this.ref,
    this.onBackPressed,
    this.onDonePressed,
    this.selectedCount,
    this.maxSelections = 5,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: kDarkBackground,
      elevation: 0,
      title: Text(
        title,
        style: const TextStyle(
          color: kWhite,
          fontWeight: FontWeight.w600,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: kWhite),
        onPressed: onBackPressed ??
            () {
              ref.read(multiSelectedMediaProvider.notifier).clear();
              Navigator.of(context).pop();
            },
      ),
      actions: [
        if (selectedCount != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton(
              onPressed: onDonePressed,
              style: TextButton.styleFrom(
                backgroundColor: kDeepPink,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Done",
                    style: TextStyle(
                      color: kWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (selectedCount! > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: kWhite,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        "$selectedCount",
                        style: const TextStyle(
                          color: kDeepPink,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

class AlbumSelector extends StatelessWidget {
  final String currentAlbumName;
  final List<AssetPathEntity> albums;
  final Function(AssetPathEntity) onAlbumSelected;

  const AlbumSelector({
    Key? key,
    required this.currentAlbumName,
    required this.albums,
    required this.onAlbumSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: kDarkBackground,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (context) => _buildAlbumsSheet(context),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentAlbumName,
              style: const TextStyle(
                color: kWhite,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              color: kWhite,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumsSheet(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              "Albums",
              style: TextStyle(
                color: kWhite,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(color: Colors.grey),
          Expanded(
            child: ListView.builder(
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final album = albums[index];
                return ListTile(
                  title: Text(
                    album.name,
                    style: TextStyle(
                      color: kWhite,
                      fontWeight: album.name == currentAlbumName ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: FutureBuilder<int>(
                    future: album.assetCountAsync,
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.data != null ? "${snapshot.data} items" : "Loading...",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                  trailing: album.name == currentAlbumName ? const Icon(Icons.check_circle, color: kDeepPink) : null,
                  onTap: () {
                    onAlbumSelected(album);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CameraPreviewButton extends StatelessWidget {
  final VoidCallback onPressed;

  const CameraPreviewButton({
    Key? key,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: kDeepPink.withOpacity(0.8),
          borderRadius: BorderRadius.circular(kBorderRadius),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Camera gradient background
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kDeepPink, kDeepPinkLight],
                ),
                borderRadius: BorderRadius.circular(kBorderRadius),
              ),
            ),
            // Camera icon and text
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.camera_alt_rounded,
                  color: kWhite,
                  size: 36,
                ),
                SizedBox(height: 8),
                Text(
                  "Camera",
                  style: TextStyle(
                    color: kWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PicturesOnlyGridView extends StatelessWidget {
  final List<Media> medias;
  final Media? selectedMedia;
  final Function(Media) selectMedia;
  final ScrollController scrollController;

  const PicturesOnlyGridView({
    super.key,
    required this.medias,
    required this.selectedMedia,
    required this.selectMedia,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    // Filter to only show images, excluding videos
    final List<Media> imageMedias = medias.where((media) => media.assetEntity.type == AssetType.image).toList();

    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(kGridSpacing),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: kGridSpacing,
        mainAxisSpacing: kGridSpacing,
      ),
      itemCount: imageMedias.length,
      itemBuilder: (context, index) {
        final media = imageMedias[index];
        final bool isSelected = selectedMedia?.assetEntity.id == media.assetEntity.id;

        return GestureDetector(
          onTap: () => selectMedia(media),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kBorderRadius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Media thumbnail with subtle animation
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    border: isSelected ? Border.all(color: kDeepPink, width: 3) : null,
                    borderRadius: BorderRadius.circular(kBorderRadius),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isSelected ? kBorderRadius - 2 : kBorderRadius),
                    child: media.widget,
                  ),
                ),

                // Subtle gradient overlay for better visibility
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.2),
                        ],
                        stops: const [0.7, 1.0],
                      ),
                    ),
                  ),
                ),

                // Selection overlay
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: kDeepPink.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(kBorderRadius),
                      ),
                      child: Stack(
                        children: [
                          // Purple gradient background
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    kDeepPink.withOpacity(0.3),
                                    kDeepPinkLight.withOpacity(0.5),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Checkmark icon
                          Center(
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: kDeepPink,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.check,
                                  color: kWhite,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ImagesOnlyGridView extends MediasGridView {
  const ImagesOnlyGridView({
    super.key,
    required super.medias,
    required super.selectedMedia,
    required super.selectMedia,
    required super.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    // Filter to only show images, excluding videos
    final List<Media> imageMedias = medias.where((media) => media.assetEntity.type == AssetType.image).toList();

    // Use the filtered list but call the parent class build with modified medias
    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(kGridSpacing),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: kGridSpacing,
        mainAxisSpacing: kGridSpacing,
      ),
      itemCount: imageMedias.length,
      itemBuilder: (context, index) {
        final media = imageMedias[index];
        final bool isSelected = selectedMedia?.assetEntity.id == media.assetEntity.id;

        return GestureDetector(
          onTap: () => selectMedia(media),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kBorderRadius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Media thumbnail with subtle animation
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    border: isSelected ? Border.all(color: kDeepPink, width: 3) : null,
                    borderRadius: BorderRadius.circular(kBorderRadius),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isSelected ? kBorderRadius - 2 : kBorderRadius),
                    child: media.widget,
                  ),
                ),

                // Subtle gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.2),
                        ],
                        stops: const [0.7, 1.0],
                      ),
                    ),
                  ),
                ),

                // Selection overlay
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: kDeepPink.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(kBorderRadius),
                      ),
                      child: Stack(
                        children: [
                          // Purple gradient background
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    kDeepPink.withOpacity(0.3),
                                    kDeepPinkLight.withOpacity(0.5),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Checkmark icon
                          Center(
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: kDeepPink,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.check,
                                  color: kWhite,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MediaSelectorWithImageFilter extends StatelessWidget {
  final List<Media> allMedias;
  final Media? selectedMedia;
  final Function(Media) selectMedia;
  final ScrollController scrollController;
  final MediaTypeFilter filterType;

  const MediaSelectorWithImageFilter({
    super.key,
    required this.allMedias,
    required this.selectedMedia,
    required this.selectMedia,
    required this.scrollController,
    this.filterType = MediaTypeFilter.imagesOnly,
  });

  @override
  Widget build(BuildContext context) {
    final List<Media> filteredMedias = _filterMedias(allMedias, filterType);

    return MediasGridView(
      medias: filteredMedias,
      selectedMedia: selectedMedia,
      selectMedia: selectMedia,
      scrollController: scrollController,
    );
  }

  List<Media> _filterMedias(List<Media> medias, MediaTypeFilter filter) {
    switch (filter) {
      case MediaTypeFilter.all:
        return medias;
      case MediaTypeFilter.imagesOnly:
        return medias.where((media) => media.assetEntity.type == AssetType.image).toList();
      case MediaTypeFilter.videosOnly:
        return medias.where((media) => media.assetEntity.type == AssetType.video).toList();
    }
  }
}

enum MediaTypeFilter {
  all,
  imagesOnly,
  videosOnly,
}
