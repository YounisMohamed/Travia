import 'package:flutter_riverpod/flutter_riverpod.dart';

class VisibleNotifier extends StateNotifier<bool> {
  // Initial State
  VisibleNotifier() : super(false);

  void toggleVisible(bool newValue) {
    state = newValue;
  }
}

final visibleProvider = StateNotifierProvider<VisibleNotifier, bool>((ref) {
  return VisibleNotifier();
});
