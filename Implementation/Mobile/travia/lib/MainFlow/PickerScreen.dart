import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../Classes/Media.dart';
import '../Helpers/AppColors.dart';
import '../Helpers/MediaGridView.dart';
import '../ImageServices/PhotoManager.dart';
import '../Providers/MediaProviders.dart';
import 'Camera.dart';

final albumsProvider = StateProvider<List<AssetPathEntity>>((ref) => []);
final currentAlbumProvider = StateProvider<AssetPathEntity?>((ref) => null);

final mediaProvider = StateNotifierProvider<MediaNotifier, List<Media>>(
  (ref) => MediaNotifier(),
);

final paginationProvider = StateProvider<int>((ref) => 0);

/// **Media Notifier for Managing the Media List**
class MediaNotifier extends StateNotifier<List<Media>> {
  MediaNotifier() : super([]);

  Future<void> loadMedias(AssetPathEntity? album, int page) async {
    if (album == null) return;
    List<Media> newMedias = await fetchMedias(album: album, page: page);
    state = [...state, ...newMedias];
  }

  void clearMedias() {
    state = [];
  }
}

class PickerScreen extends ConsumerStatefulWidget {
  final Media? selectedMedia;

  const PickerScreen({super.key, required this.selectedMedia});

  @override
  ConsumerState<PickerScreen> createState() => _PickerScreenState();
}

class _PickerScreenState extends ConsumerState<PickerScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreMedias);
    _initialize();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_loadMoreMedias);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final albums = await fetchAlbums();
    if (albums.isNotEmpty) {
      ref.read(albumsProvider.notifier).state = albums;
      ref.read(currentAlbumProvider.notifier).state = albums.first;
      ref.read(mediaProvider.notifier).loadMedias(albums.first, 0);
    }
  }

  void _loadMoreMedias() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.75) {
      final currentPage = ref.read(paginationProvider);
      final currentAlbum = ref.read(currentAlbumProvider);
      ref.read(paginationProvider.notifier).state = currentPage + 1;
      ref.read(mediaProvider.notifier).loadMedias(currentAlbum, currentPage + 1);
    }
  }

  void _selectMedia(Media media) {
    final selectedMedia = ref.read(selectedMediaProvider);
    if (selectedMedia?.assetEntity.id == media.assetEntity.id) {
      // If the same media is selected, deselect it
      ref.read(selectedMediaProvider.notifier).updateSelectedMedias(null);
    } else {
      // Otherwise select the new media
      ref.read(selectedMediaProvider.notifier).updateSelectedMedias(media);
    }
  }

  void _clearSelection() {
    ref.read(selectedMediaProvider.notifier).clear();
  }

  Future<void> _handleCameraNavigation() async {
    final capturedMedia = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CameraScreen()),
    );

    if (capturedMedia != null) {
      ref.read(selectedMediaProvider.notifier).updateSelectedMedias(capturedMedia);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedMedia = ref.watch(selectedMediaProvider);
    final albums = ref.watch(albumsProvider);
    final currentAlbum = ref.watch(currentAlbumProvider);
    final medias = ref.watch(mediaProvider);

    return Theme(
      data: TravelAppTheme.darkTheme,
      child: Scaffold(
        backgroundColor: kDarkBackground,
        appBar: AppBar(
          backgroundColor: kDarkBackground,
          elevation: 0,
          title: const Text(
            "Select Media",
            style: TextStyle(
              color: kWhite,
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: kWhite),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextButton(
                onPressed: selectedMedia == null
                    ? null
                    : () {
                        _clearSelection();
                        Navigator.pop(context, selectedMedia);
                      },
                style: TextButton.styleFrom(
                  backgroundColor: selectedMedia == null ? kDeepPink.withOpacity(0.3) : kDeepPink,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  "Done",
                  style: TextStyle(
                    color: kWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Album selector
            if (albums.isNotEmpty && currentAlbum != null)
              AlbumSelector(
                currentAlbumName: currentAlbum.name.isEmpty ? "Recent" : currentAlbum.name,
                albums: albums,
                onAlbumSelected: (album) {
                  ref.read(currentAlbumProvider.notifier).state = album;
                  ref.read(paginationProvider.notifier).state = 0;
                  ref.read(mediaProvider.notifier).clearMedias();
                  ref.read(mediaProvider.notifier).loadMedias(album, 0);
                  _scrollController.jumpTo(0.0);
                },
              ),

            // Divider
            const Divider(height: 1, color: Colors.grey),

            // Selected Media Preview Section (New)
            if (selectedMedia != null)
              Container(
                height: 100,
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                color: kDeepPink.withOpacity(0.8),
                child: Row(
                  children: [
                    // Selected Media Thumbnail
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(color: kDeepPink, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: selectedMedia.widget,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Media Type Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            selectedMedia.assetEntity.type == AssetType.image ? "Image Selected" : "Video Selected",
                            style: const TextStyle(
                              color: kWhite,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (selectedMedia.assetEntity.type == AssetType.video)
                            Text(
                              "Duration: ${_formatDuration(selectedMedia.assetEntity.videoDuration)}",
                              style: TextStyle(
                                color: kWhite.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Clear Selection Button
                    TextButton.icon(
                      onPressed: _clearSelection,
                      icon: const Icon(Icons.close, color: kDeepPinkLight, size: 18),
                      label: const Text(
                        "Clear",
                        style: TextStyle(
                          color: kDeepPinkLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        backgroundColor: kDeepPink.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Camera preview button
            Padding(
              padding: const EdgeInsets.all(kGridSpacing),
              child: SizedBox(
                height: 100,
                child: CameraPreviewButton(
                  onPressed: _handleCameraNavigation,
                ),
              ),
            ),

            // Media grid
            Expanded(
              child: MediasGridView(
                medias: medias,
                selectedMedia: selectedMedia,
                selectMedia: _selectMedia,
                scrollController: _scrollController,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }
}

class ImagesOnlyPickerScreen extends ConsumerStatefulWidget {
  final Media? selectedMedia;

  const ImagesOnlyPickerScreen({super.key, required this.selectedMedia});

  @override
  ConsumerState<ImagesOnlyPickerScreen> createState() => _ImagesOnlyPickerScreenState();
}

class _ImagesOnlyPickerScreenState extends ConsumerState<ImagesOnlyPickerScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreMedias);
    _initialize();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_loadMoreMedias);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final albums = await fetchAlbums();
    if (albums.isNotEmpty) {
      ref.read(albumsProvider.notifier).state = albums;
      ref.read(currentAlbumProvider.notifier).state = albums.first;
      ref.read(mediaProvider.notifier).loadMedias(albums.first, 0);
    }
  }

  void _loadMoreMedias() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.75) {
      final currentPage = ref.read(paginationProvider);
      final currentAlbum = ref.read(currentAlbumProvider);
      ref.read(paginationProvider.notifier).state = currentPage + 1;
      ref.read(mediaProvider.notifier).loadMedias(currentAlbum, currentPage + 1);
    }
  }

  void _selectMedia(Media media) {
    final selectedMedia = ref.read(selectedMediaProvider);
    if (selectedMedia?.assetEntity.id == media.assetEntity.id) {
      // If the same media is selected, deselect it
      ref.read(selectedMediaProvider.notifier).updateSelectedMedias(null);
    } else {
      // Otherwise select the new media
      ref.read(selectedMediaProvider.notifier).updateSelectedMedias(media);
    }
  }

  void _clearSelection() {
    ref.read(selectedMediaProvider.notifier).clear();
  }

  Future<void> _handleCameraNavigation() async {
    final capturedMedia = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CameraScreen()),
    );

    if (capturedMedia != null) {
      ref.read(selectedMediaProvider.notifier).updateSelectedMedias(capturedMedia);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedMedia = ref.watch(selectedMediaProvider);
    final albums = ref.watch(albumsProvider);
    final currentAlbum = ref.watch(currentAlbumProvider);
    final medias = ref.watch(mediaProvider);

    return Theme(
      data: TravelAppTheme.darkTheme,
      child: Scaffold(
        backgroundColor: kDarkBackground,
        appBar: AppBar(
          backgroundColor: kDarkBackground,
          elevation: 0,
          title: const Text(
            "Select Media",
            style: TextStyle(
              color: kWhite,
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: kWhite),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextButton(
                onPressed: selectedMedia == null
                    ? null
                    : () {
                        _clearSelection();
                        Navigator.pop(context, selectedMedia);
                      },
                style: TextButton.styleFrom(
                  backgroundColor: selectedMedia == null ? kDeepPink.withOpacity(0.3) : kDeepPink,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  "Done",
                  style: TextStyle(
                    color: kWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Album selector
            if (albums.isNotEmpty && currentAlbum != null)
              AlbumSelector(
                currentAlbumName: currentAlbum.name.isEmpty ? "Recent" : currentAlbum.name,
                albums: albums,
                onAlbumSelected: (album) {
                  ref.read(currentAlbumProvider.notifier).state = album;
                  ref.read(paginationProvider.notifier).state = 0;
                  ref.read(mediaProvider.notifier).clearMedias();
                  ref.read(mediaProvider.notifier).loadMedias(album, 0);
                  _scrollController.jumpTo(0.0);
                },
              ),

            // Divider
            const Divider(height: 1, color: Colors.grey),

            // Selected Media Preview Section (New)
            if (selectedMedia != null)
              Container(
                height: 100,
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                color: kDeepPink.withOpacity(0.8),
                child: Row(
                  children: [
                    // Selected Media Thumbnail
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(color: kDeepPink, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: selectedMedia.widget,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Media Type Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            selectedMedia.assetEntity.type == AssetType.image ? "Image Selected" : "Video Selected",
                            style: const TextStyle(
                              color: kWhite,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (selectedMedia.assetEntity.type == AssetType.video)
                            Text(
                              "Duration: ${_formatDuration(selectedMedia.assetEntity.videoDuration)}",
                              style: TextStyle(
                                color: kWhite.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Clear Selection Button
                    TextButton.icon(
                      onPressed: _clearSelection,
                      icon: const Icon(Icons.close, color: kDeepPinkLight, size: 18),
                      label: const Text(
                        "Clear",
                        style: TextStyle(
                          color: kDeepPinkLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        backgroundColor: kDeepPink.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Camera preview button
            Padding(
              padding: const EdgeInsets.all(kGridSpacing),
              child: SizedBox(
                height: 100,
                child: CameraPreviewButton(
                  onPressed: _handleCameraNavigation,
                ),
              ),
            ),

            // Media grid
            Expanded(
              child: MediaSelectorWithImageFilter(
                allMedias: medias,
                selectedMedia: selectedMedia,
                selectMedia: _selectMedia,
                scrollController: _scrollController,
                filterType: MediaTypeFilter.imagesOnly,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }
}

class MultiPickerScreen extends ConsumerStatefulWidget {
  const MultiPickerScreen({Key? key}) : super(key: key);

  @override
  MultiPickerScreenState createState() => MultiPickerScreenState();
}

class MultiPickerScreenState extends ConsumerState<MultiPickerScreen> {
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_loadMoreMedias);
    _initialize();
  }

  @override
  void dispose() {
    scrollController.removeListener(_loadMoreMedias);
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final albums = await fetchAlbums();
    if (albums.isNotEmpty) {
      ref.read(albumsProvider.notifier).state = albums;
      ref.read(currentAlbumProvider.notifier).state = albums.first;
      ref.read(mediaProvider.notifier).loadMedias(albums.first, 0);
    }
  }

  void _loadMoreMedias() {
    if (scrollController.position.pixels >= scrollController.position.maxScrollExtent * 0.75) {
      final currentPage = ref.read(paginationProvider);
      final currentAlbum = ref.read(currentAlbumProvider);
      ref.read(paginationProvider.notifier).state = currentPage + 1;
      ref.read(mediaProvider.notifier).loadMedias(currentAlbum, currentPage + 1);
    }
  }

  void _toggleMediaSelection(Media media) {
    ref.read(multiSelectedMediaProvider.notifier).toggleMedia(media);
  }

  Future<void> _handleCameraNavigation() async {
    final capturedMedia = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CameraScreen()),
    );

    if (capturedMedia != null) {
      ref.read(multiSelectedMediaProvider.notifier).toggleMedia(capturedMedia);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedMedias = ref.watch(multiSelectedMediaProvider);
    final albums = ref.watch(albumsProvider);
    final currentAlbum = ref.watch(currentAlbumProvider);
    final medias = ref.watch(mediaProvider);

    return Theme(
      data: TravelAppTheme.darkTheme,
      child: Scaffold(
        backgroundColor: kDarkBackground,
        appBar: MediaPickerAppBar(
          title: "Select Media",
          ref: ref,
          selectedCount: selectedMedias.length,
          onDonePressed: selectedMedias.isEmpty ? null : () => Navigator.pop(context, selectedMedias),
        ),
        body: Column(
          children: [
            // Album selector
            if (albums.isNotEmpty && currentAlbum != null)
              AlbumSelector(
                currentAlbumName: currentAlbum.name.isEmpty ? "Recent" : currentAlbum.name,
                albums: albums,
                onAlbumSelected: (album) {
                  ref.read(currentAlbumProvider.notifier).state = album;
                  ref.read(paginationProvider.notifier).state = 0;
                  ref.read(mediaProvider.notifier).clearMedias();
                  ref.read(mediaProvider.notifier).loadMedias(album, 0);
                  scrollController.jumpTo(0.0);
                },
              ),

            // Optional: Clear selection button
            if (selectedMedias.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.clear_all, color: kWhite),
                      label: const Text(
                        "Clear Selection",
                        style: TextStyle(color: kWhite),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.black38,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => ref.read(multiSelectedMediaProvider.notifier).clear(),
                    ),
                  ],
                ),
              ),

            // Divider
            const Divider(height: 1, color: Colors.grey),

            // Camera preview button
            Padding(
              padding: const EdgeInsets.all(kGridSpacing),
              child: SizedBox(
                height: 100,
                child: CameraPreviewButton(
                  onPressed: _handleCameraNavigation,
                ),
              ),
            ),

            // Media grid
            Expanded(
              child: MultiMediasGridView(
                medias: medias,
                selectedMedias: selectedMedias,
                toggleMediaSelection: _toggleMediaSelection,
                scrollController: scrollController,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
