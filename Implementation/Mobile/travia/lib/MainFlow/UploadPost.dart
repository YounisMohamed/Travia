import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Helpers/Loading.dart';
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
              opacity: (pickedImage != null && _captionController.text.trim().isNotEmpty) ? 1.0 : 0.5,
              duration: Duration(milliseconds: 200),
              child: TextButton.icon(
                onPressed: (pickedImage != null && _captionController.text.trim().isNotEmpty)
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  GestureDetector(
                    onTap: isUploading
                        ? null
                        : () {
                            ref.invalidate(imagePickerProvider);
                            ref.read(imagePickerProvider.notifier).pickAndEditImage(userId, context);
                          },
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.5,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: pickedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(24),
                              ),
                              child: Image.file(
                                pickedImage,
                                key: ValueKey(pickedImage.path + DateTime.now().toString()),
                                height: double.infinity,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_rounded,
                                  size: 80,
                                  color: Colors.grey[500],
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "Tap to add a photo",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (pickedImage != null)
                    Positioned(
                      right: 16,
                      top: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.edit, color: Colors.white),
                          onPressed: isUploading
                              ? null
                              : () {
                                  ref.invalidate(imagePickerProvider);
                                  ref.read(imagePickerProvider.notifier).pickAndEditImage(userId, context);
                                },
                        ),
                      ),
                    ),
                  if (pickedImage != null)
                    Positioned(
                      left: 16,
                      top: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.close, color: Colors.white),
                          onPressed: isUploading
                              ? null
                              : () {
                                  ref.read(imagePickerProvider.notifier).clearImage();
                                },
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Caption",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: theme.primaryColor,
                      ),
                    ),
                    SizedBox(height: 12),
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
                    SizedBox(height: 24),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, color: theme.primaryColor, size: 24),
                        SizedBox(width: 12),
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
              if (isUploading)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        LoadingWidget(),
                        SizedBox(height: 16),
                        Text(
                          "Uploading your post...",
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
