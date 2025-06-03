import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../Helpers/AppColors.dart';
import '../Helpers/HelperMethods.dart';
import '../Helpers/Loading.dart';
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

  @override
  Widget build(BuildContext context) {
    final pickedImage = ref.watch(singleMediaPickerProvider);
    final isUploading = ref.watch(postProvider);
    final userId = FirebaseAuth.instance.currentUser!.uid;

    final selectedCountry = ref.watch(selectedCountryProvider);
    // Auto-select detected country
    ref.listen(autoDetectLocationProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        ref.read(selectedCountryProvider.notifier).state = next.value;
      }
    });

    return Scaffold(
      backgroundColor: kDeepGrey,
      appBar: AppBar(
        forceMaterialTransparency: true,
        centerTitle: false,
        title: Text(
          "Create Post",
          style: GoogleFonts.ibmPlexSans(
            fontSize: 21,
            fontWeight: FontWeight.bold,
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
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: TextButton.icon(
                  onPressed: pickedImage != null && selectedCountry != null
                      ? () {
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
                          _captionController.clear();
                          ref.read(singleMediaPickerProvider.notifier).clearImage();
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
              SizedBox(
                height: 32,
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    //Caption - Location
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LocationPicker(
                            onRetryTap: _autoDetectLocation,
                          ),
                          SizedBox(
                            height: 24,
                          ),
                          // Caption TextField
                          TextField(
                            controller: _captionController,
                            enabled: !isUploading,
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
                                borderSide: BorderSide(color: kDeepPink, width: 1),
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
              SizedBox(
                height: 16,
              ),
              Stack(
                children: [
                  Container(
                    height: 360,
                    width: 360,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(width: 1, color: kDeepPink)),
                    child: pickedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: MediaFilePreview(
                              mediaFile: pickedImage,
                              isVideo: isPathVideo(pickedImage.path),
                            ))
                        : Center(
                            child: Text(
                              "No media selected yet",
                              style: GoogleFonts.lexendDeca(color: kDeepPink, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                  ),

                  /// ⬇️ Add Button Positioned Top Right
                  Positioned(
                    top: -8,
                    right: -8,
                    child: IconButton(
                      icon: Icon(Icons.add_circle, color: kDeepPink, size: 40),
                      onPressed: isUploading
                          ? null
                          : () {
                              ref.invalidate(singleMediaPickerProvider);
                              ref.read(singleMediaPickerProvider.notifier).pickAndEditMediaForUpload(context);
                            },
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 32,
              )
            ],
          ),
        ),
      ),
    );
  }
}
