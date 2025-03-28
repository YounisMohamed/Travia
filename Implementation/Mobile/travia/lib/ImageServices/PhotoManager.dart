import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../Classes/Media.dart';

Future<List<AssetPathEntity>> fetchAlbums() async {
  try {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) {
      throw Exception();
    }

    // Fetch the list of asset paths (albums)
    List<AssetPathEntity> albums = await PhotoManager.getAssetPathList();

    return albums;
  } catch (e) {
    debugPrint('Error fetching albums: $e');
    return [];
  }
}

final Map<String, ImageProvider> _imageCache = {};

Future<List<Media>> fetchMedias({
  required AssetPathEntity album,
  required int page,
}) async {
  List<Media> medias = [];

  try {
    final List<AssetEntity> entities = await album.getAssetListPaged(page: page, size: 30);

    for (AssetEntity entity in entities) {
      String id = entity.id;

      if (!_imageCache.containsKey(id)) {
        _imageCache[id] = AssetEntityImageProvider(
          entity,
          thumbnailSize: const ThumbnailSize.square(500),
        );
      }

      medias.add(Media(
        assetEntity: entity,
        widget: Image(
          image: _imageCache[id]!,
          fit: BoxFit.cover,
        ),
      ));
    }
  } catch (e) {
    debugPrint('Error fetching media: $e');
  }

  return medias;
}
