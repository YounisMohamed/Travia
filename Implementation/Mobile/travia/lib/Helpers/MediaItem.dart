import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../Classes/Media.dart';

class MediaItem extends StatefulWidget {
  final Media media;
  final bool isSelected;
  final Function selectMedia;

  const MediaItem({
    required this.media,
    required this.isSelected,
    required this.selectMedia,
    super.key,
  });

  @override
  _MediaItemState createState() => _MediaItemState();
}

class _MediaItemState extends State<MediaItem> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Keep widget alive

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required when using AutomaticKeepAliveClientMixin

    return InkWell(
      onTap: () => widget.selectMedia(widget.media),
      child: Stack(
        children: [
          _buildMediaWidget(),
          if (widget.media.assetEntity.type == AssetType.video)
            Positioned(
              bottom: 8,
              right: 8,
              child: Icon(Icons.play_arrow_rounded, color: Colors.white),
            ),
          if (widget.isSelected) _buildIsSelectedOverlay(),
        ],
      ),
    );
  }

  Widget _buildMediaWidget() {
    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.all(widget.isSelected ? 10.0 : 0.0),
        child: widget.media.widget, // Uses cached image
      ),
    );
  }

  Widget _buildIsSelectedOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.1),
        child: Center(
          child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}
