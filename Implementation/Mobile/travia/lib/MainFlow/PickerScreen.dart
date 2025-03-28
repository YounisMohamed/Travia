import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../Classes/Media.dart';
import '../Helpers/MediaGridView.dart';
import '../ImageServices/PhotoManager.dart';
import '../Providers/MediaProviders.dart';

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

/// **Picker Screen**
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
    selectedMedia == media ? ref.read(selectedMediaProvider.notifier).updateSelectedMedias(null) : ref.read(selectedMediaProvider.notifier).updateSelectedMedias(media);
  }

  @override
  Widget build(BuildContext context) {
    final selectedMedia = ref.watch(selectedMediaProvider);
    final albums = ref.watch(albumsProvider);
    final currentAlbum = ref.watch(currentAlbumProvider);
    final medias = ref.watch(mediaProvider);

    return Scaffold(
      appBar: AppBar(
        title: DropdownButton<AssetPathEntity>(
          borderRadius: BorderRadius.circular(16.0),
          value: currentAlbum,
          items: albums
              .map(
                (e) => DropdownMenuItem<AssetPathEntity>(
                  value: e,
                  child: Text(e.name.isEmpty ? "0" : e.name),
                ),
              )
              .toList(),
          onChanged: (AssetPathEntity? value) {
            ref.read(currentAlbumProvider.notifier).state = value;
            ref.read(paginationProvider.notifier).state = 0;
            ref.read(mediaProvider.notifier).clearMedias();
            ref.read(mediaProvider.notifier).loadMedias(value, 0);
            _scrollController.jumpTo(0.0);
          },
        ),
      ),
      body: MediasGridView(
        medias: medias,
        selectedMedia: selectedMedia,
        selectMedia: _selectMedia,
        scrollController: _scrollController,
      ),
      floatingActionButton: selectedMedia == null
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.pop(context, selectedMedia),
              child: const Icon(Icons.check_rounded),
            ),
    );
  }
}
