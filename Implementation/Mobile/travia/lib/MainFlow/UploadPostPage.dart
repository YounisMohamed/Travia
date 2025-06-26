import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../Helpers/AppColors.dart';
import '../Helpers/HelperMethods.dart';
import '../Helpers/PopUp.dart';
import '../Providers/GeoLocationProvider.dart';
import '../Providers/ImagePickerProvider.dart';
import '../Providers/UploadProviders.dart';
import '../main.dart';
import 'LocationPickerDropDown.dart';
import 'MediaPreview.dart';

class UploadPostPage extends ConsumerStatefulWidget {
  const UploadPostPage({super.key});

  @override
  _UploadPostPageState createState() => _UploadPostPageState();
}

class _UploadPostPageState extends ConsumerState<UploadPostPage> {
  final TextEditingController _captionController = TextEditingController();

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoDetectLocation();
    });
    super.initState();
  }

  void _autoDetectLocation() {
    ref.refresh(autoDetectLocationProvider);
  }

  Future<bool> _onWillPop() async {
    final uploadState = ref.read(postProvider);

    if (uploadState.isUploading) {
      // Show confirmation dialog if upload is in progress
      final shouldLeave = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(
            'Upload in Progress',
            style: GoogleFonts.lexendDeca(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Your post is still uploading. If you leave now, the upload will be cancelled. Do you want to cancel the upload?',
            style: GoogleFonts.lexendDeca(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Continue Upload',
                style: GoogleFonts.lexendDeca(color: kDeepPink),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Cancel Upload',
                style: GoogleFonts.lexendDeca(color: Colors.red),
              ),
            ),
          ],
        ),
      );

      if (shouldLeave == true) {
        // Cancel the upload
        ref.read(postProvider.notifier).clearUploadState();
        return true;
      }
      return false;
    }

    // Check if there's unsaved content
    final hasContent = _captionController.text.isNotEmpty || ref.read(singleMediaPickerProvider) != null;

    if (hasContent) {
      final shouldLeave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Discard Post?',
            style: GoogleFonts.lexendDeca(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'You have unsaved changes. Do you want to discard this post?',
            style: GoogleFonts.lexendDeca(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Keep Editing',
                style: GoogleFonts.lexendDeca(color: kDeepPink),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Discard',
                style: GoogleFonts.lexendDeca(color: Colors.red),
              ),
            ),
          ],
        ),
      );

      return shouldLeave ?? false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final pickedImage = ref.watch(singleMediaPickerProvider);
    final uploadState = ref.watch(postProvider);
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final selectedCountry = ref.watch(selectedCountryProvider);

    ref.listen(autoDetectLocationProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        ref.read(selectedCountryProvider.notifier).state = next.value;
      }
    });

    // Listen for upload completion
    ref.listen<UploadState>(postProvider, (previous, current) {
      if (previous?.isUploading == true && !current.isUploading && current.currentStep == null) {
        // Upload completed successfully, navigate back
        Navigator.of(context).pop();
      }
    });

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: kBackground,
            appBar: AppBar(
              forceMaterialTransparency: true,
              centerTitle: false,
              leading: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () async {
                  if (await _onWillPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              title: Text(
                "Create Post",
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                AnimatedOpacity(
                  opacity: pickedImage != null && !uploadState.isUploading ? 1.0 : 0.5,
                  duration: Duration(milliseconds: 200),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: TextButton.icon(
                      onPressed: pickedImage != null && selectedCountry != null && !uploadState.isUploading
                          ? () {
                              FocusScope.of(context).unfocus(); // Dismiss keyboard

                              final caption = _captionController.text.trim();
                              if (filter.hasProfanity(caption) || hasArabicProfanity(caption)) {
                                Popup.showWarning(text: "Bad words detected", context: context);
                                return;
                              }

                              ref.read(postProvider.notifier).uploadPost(
                                    userId: userId,
                                    caption: caption,
                                    location: selectedCountry['name'] ?? "No Man's Land",
                                    context: context,
                                  );
                            }
                          : null,
                      icon: Icon(Icons.upload_rounded, color: kDeepPink),
                      label: Text(
                        "Share",
                        style: GoogleFonts.lexendDeca(
                          fontWeight: FontWeight.bold,
                          color: kDeepPink,
                          fontSize: 18,
                        ),
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
                  children: [
                    Center(
                      child: Image.asset(
                        "assets/TraviaLogo.png",
                        height: 120,
                        width: 120,
                      ),
                    ),
                    Text(
                      "Every trip has a story. Tell yours.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lexendDeca(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LocationPicker(
                                  onRetryTap: _autoDetectLocation,
                                ),
                                SizedBox(height: 24),
                                TextField(
                                  controller: _captionController,
                                  enabled: !uploadState.isUploading,
                                  maxLines: 3,
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(fontSize: 16),
                                  decoration: InputDecoration(
                                    hintText: "What's in your mind...",
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.all(16),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: kDeepPink, width: 1),
                                    ),
                                    disabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: Colors.grey, width: 1),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: kDeepPink, width: 1),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: kDeepPink, width: 1),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: kDeepPink, width: 1),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    Stack(
                      children: [
                        Container(
                          height: 360,
                          width: 360,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              width: 1,
                              color: uploadState.isUploading ? Colors.grey : kDeepPink,
                            ),
                          ),
                          child: pickedImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: MediaFilePreview(
                                    mediaFile: pickedImage,
                                    isVideo: isPathVideo(pickedImage.path),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    "No media selected yet",
                                    style: GoogleFonts.lexendDeca(
                                      color: kDeepPink,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                        Positioned(
                          top: -8,
                          right: -8,
                          child: IconButton(
                            icon: Icon(
                              Icons.add_circle,
                              color: uploadState.isUploading ? Colors.grey : kDeepPink,
                              size: 40,
                            ),
                            onPressed: uploadState.isUploading
                                ? null
                                : () {
                                    ref.invalidate(singleMediaPickerProvider);
                                    ref.read(singleMediaPickerProvider.notifier).pickAndEditMediaForUpload(context);
                                  },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),

          // Upload Progress Overlay
          UploadProgressOverlay(uploadState: uploadState),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }
}

class UploadProgressOverlay extends StatelessWidget {
  final UploadState uploadState;

  const UploadProgressOverlay({Key? key, required this.uploadState}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!uploadState.isUploading) return SizedBox.shrink();

    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: uploadState.progress,
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(kDeepPink),
                    backgroundColor: Colors.grey[300],
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  uploadState.currentStep ?? 'Processing...',
                  style: GoogleFonts.lexendDeca(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (uploadState.progress != null)
                  Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      '${(uploadState.progress! * 100).toInt()}%',
                      style: GoogleFonts.lexendDeca(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                SizedBox(height: 24),
                Text(
                  'Please wait while we process your post',
                  style: GoogleFonts.lexendDeca(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
