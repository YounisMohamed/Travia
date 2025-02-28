import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ImageCompressor {
  static Future<File?> compressImage(File file) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String targetPath = path.join(tempDir.path, "compressed_${DateTime.now().millisecondsSinceEpoch}.jpg");

      final XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 80,
        minWidth: 1080,
        minHeight: 1080,
      );

      return compressedFile != null ? File(compressedFile.path) : null;
    } catch (e) {
      print("Compression error: $e");
      return null;
    }
  }
}
