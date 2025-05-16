import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentIndexProvider = StateProvider<int>((ref) => 2); // Bottom bar baby
final horizontalPageProvider = StateProvider<int>((ref) => 1); // 0=UploadPost, 1=Home, 2=DMs
