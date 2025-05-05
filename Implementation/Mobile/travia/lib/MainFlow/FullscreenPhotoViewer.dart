import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';

class FullscreenImagePage extends StatelessWidget {
  final File imageFile;

  const FullscreenImagePage({Key? key, required this.imageFile}) : super(key: key);

  void _shareImage(BuildContext context) {
    Share.shareXFiles([XFile(imageFile.path)], text: 'Check this out!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: imageFile.path,
              child: PhotoView(
                imageProvider: FileImage(imageFile),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Share Button (Left)
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: () => _shareImage(context),
                  ),
                  // Close Button (Right)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
