import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Helpers/Loading.dart';
import '../ImageServices/ImagePickerProvider.dart';
import '../ImageServices/UploadPostProvider.dart';

class UploadPostPage extends ConsumerStatefulWidget {
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

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text("New Post"),
            SizedBox(width: 10),
            if (isUploading)
              SizedBox(
                width: 20,
                height: 20,
                child: LoadingWidget(),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.upload),
            onPressed: isUploading
                ? null // Disable while uploading
                : () {
                    ref.read(postProvider.notifier).uploadPost(
                          userId,
                          _captionController.text.trim(),
                          _locationController.text.trim(),
                          context,
                        );
                    _captionController.clear();
                    _locationController.clear();
                    ref.read(imagePickerProvider.notifier).clearImage();
                  },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: isUploading
                  ? null // Disable tapping while uploading
                  : () {
                      ref.invalidate(imagePickerProvider);
                      ref.read(imagePickerProvider.notifier).pickAndEditImage(userId, context);
                    },
              child: pickedImage != null
                  ? Image.file(
                      pickedImage,
                      key: ValueKey(pickedImage.path + DateTime.now().toString()),
                      height: 500,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: 500,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: Icon(Icons.add_a_photo, size: 50, color: Colors.grey[700]),
                    ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _captionController,
              enabled: !isUploading,
              decoration: InputDecoration(
                labelText: "Caption",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _locationController,
              enabled: !isUploading,
              decoration: InputDecoration(
                labelText: "Location",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
