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
