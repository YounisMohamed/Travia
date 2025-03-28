import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Helpers/Loading.dart';
import '../Helpers/MediaPreview.dart';
import '../ImageServices/ImagePickerProvider.dart';
import '../ImageServices/UploadPostProvider.dart';

class UploadPostPage extends ConsumerStatefulWidget {
  const UploadPostPage({super.key});

  @override
  _UploadPostPageState createState() => _UploadPostPageState();
}

class _UploadPostPageState extends ConsumerState<UploadPostPage> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final pickedImage = ref.watch(imagePickerProvider);
    final isUploading = ref.watch(postProvider);
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        centerTitle: false,
        title: Text(
          "Create Post",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: theme.primaryColor,
          ),
        ),
        actions: [
          if (isUploading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: LoadingWidget(),
              ),
            )
          else
            AnimatedOpacity(
              opacity: pickedImage != null ? 1.0 : 0.5,
              duration: Duration(milliseconds: 200),
              child: TextButton.icon(
                onPressed: pickedImage != null
                    ? () {
                        ref.read(postProvider.notifier).uploadPost(
                              userId,
                              _captionController.text.trim(),
                              _locationController.text.trim(),
                              context,
                            );
                        _captionController.clear();
                        _locationController.clear();
                        ref.read(imagePickerProvider.notifier).clearImage();
                      }
                    : null,
                icon: Icon(Icons.upload_rounded, color: theme.primaryColor),
                label: Text(
                  "Share",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          SizedBox(width: 8),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: isUploading
                      ? null
                      : () {
                          ref.invalidate(imagePickerProvider);
                          ref.read(imagePickerProvider.notifier).pickAndEditImage(context);
                        },
                  child: Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: pickedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: pickedImage.path.endsWith(".mp4") || pickedImage.path.endsWith(".mov")
                                ? MediaPreview(
                                    mediaUrl: pickedImage.path,
                                    isVideo: true,
                                  )
                                : MediaPreview(
                                    image: pickedImage,
                                    isVideo: false,
                                  ))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_rounded,
                                size: 48,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Add Media",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _captionController,
                        enabled: !isUploading,
                        maxLines: 3,
                        textInputAction: TextInputAction.next,
                        style: TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: "Write a caption...",
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: EdgeInsets.all(16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: theme.primaryColor, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, color: theme.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _locationController,
                              enabled: !isUploading,
                              textInputAction: TextInputAction.done,
                              style: TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                hintText: "Add location",
                                hintStyle: TextStyle(color: Colors.grey[500]),
                                border: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: theme.primaryColor, width: 2),
                                ),
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
