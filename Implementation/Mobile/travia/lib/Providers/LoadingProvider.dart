import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoadingNotifier extends StateNotifier<bool> {
  // Initial State
  LoadingNotifier() : super(false);

  // Modify State
  void setLoadingToTrue() {
    state = true;
  }

  void setLoadingToFalse() {
    state = false;
  }
}

final loadingProvider = StateNotifierProvider<LoadingNotifier, bool>((ref) {
  return LoadingNotifier();
});
