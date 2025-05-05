import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Classes/Media.dart';

class SelectedMediaNotifier extends StateNotifier<Media?> {
  SelectedMediaNotifier() : super(null);

  void updateSelectedMedias(Media? newMedia) {
    state = newMedia;
  }

  void clear() {
    state = null;
  }
}

final selectedMediaProvider = StateNotifierProvider<SelectedMediaNotifier, Media?>(
  (ref) => SelectedMediaNotifier(),
);

class MultiSelectedMediaNotifier extends StateNotifier<List<Media>> {
  MultiSelectedMediaNotifier() : super([]);

  void addMedia(Media media) {
    if (!state.any((element) => element.assetEntity.id == media.assetEntity.id)) {
      state = [...state, media];
    }
  }

  void removeMedia(Media media) {
    state = state.where((element) => element.assetEntity.id != media.assetEntity.id).toList();
  }

  void toggleMedia(Media media) {
    if (state.any((element) => element.assetEntity.id == media.assetEntity.id)) {
      removeMedia(media);
    } else {
      addMedia(media);
    }
  }

  bool isSelected(Media media) {
    return state.any((element) => element.assetEntity.id == media.assetEntity.id);
  }

  void clear() {
    state = [];
  }
}

final multiSelectedMediaProvider = StateNotifierProvider<MultiSelectedMediaNotifier, List<Media>>(
  (ref) => MultiSelectedMediaNotifier(),
);

class EditedVideoNotifier extends StateNotifier<File?> {
  EditedVideoNotifier() : super(null);

  void updateEditedVideo(File? editedVideo) {
    state = editedVideo;
  }

  void clear() {
    state = null;
  }
}

final editedVideoProvider = StateNotifierProvider<EditedVideoNotifier, File?>(
  (ref) => EditedVideoNotifier(),
);
