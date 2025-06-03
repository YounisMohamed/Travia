import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentIndexProvider = StateProvider<int>((ref) => 2); // Bottom bar baby // 2 for home
final horizontalPageProvider = StateProvider<int>((ref) => 0); // 0=Home, 1=DMs
