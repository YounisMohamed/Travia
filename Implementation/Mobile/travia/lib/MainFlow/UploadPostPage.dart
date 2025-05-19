import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Helpers/Constants.dart';
import '../Helpers/Loading.dart';
import '../Providers/ImagePickerProvider.dart';
import '../Providers/UploadProviders.dart';
import 'MediaPreview.dart';

class UploadPostPage extends ConsumerStatefulWidget {
  const UploadPostPage({super.key});

  @override
  _UploadPostPageState createState() => _UploadPostPageState();
}

class _UploadPostPageState extends ConsumerState<UploadPostPage> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  String? _selectedCountry;

  @override
  void initState() {
    _loadLastSelectedCountry();
    super.initState();
  }

  Future<void> _loadLastSelectedCountry() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCountry = prefs.getString('last_selected_country');
    setState(() {
      _selectedCountry = lastCountry ?? popularCountries.first['name'];
    });
  }

  void _saveSelectedCountry(String country) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_selected_country', country);
  }

  @override
  Widget build(BuildContext context) {
    final pickedImage = ref.watch(singleMediaPickerProvider);
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
                              userId: userId,
                              caption: _captionController.text.trim(),
                              location: _selectedCountry ?? "Egypt",
                              context: context,
                            );
                        _captionController.clear();
                        _locationController.clear();
                        ref.read(singleMediaPickerProvider.notifier).clearImage();
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
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Caption - Location
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _captionController,
                            enabled: !isUploading,
                            maxLines: 3,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(fontSize: 16),
                            decoration: InputDecoration(
                              hintText: "Write a caption...",
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.all(16),
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
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedCountry ?? popularCountries.first['name'],
                                  onChanged: isUploading
                                      ? null
                                      : (newValue) {
                                          if (newValue != null) {
                                            setState(() {
                                              _selectedCountry = newValue;
                                            });
                                            _saveSelectedCountry(newValue);
                                          }
                                        },
                                  decoration: InputDecoration(
                                    labelText: "Select Location",
                                    prefixIcon: Icon(Icons.location_on_outlined, color: theme.primaryColor),
                                    filled: true,
                                    fillColor: Colors.grey[100],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  items: [
                                    if (_selectedCountry != null)
                                      DropdownMenuItem(
                                        value: _selectedCountry,
                                        child: Text(
                                          '${popularCountries.firstWhere((e) => e['name'] == _selectedCountry, orElse: () => {'name': _selectedCountry!, 'emoji': '🌍'})['emoji']} $_selectedCountry',
                                        ),
                                      ),
                                    ...popularCountries
                                        .where((country) => country['name'] != _selectedCountry)
                                        .map((country) => DropdownMenuItem(
                                              value: country['name'],
                                              child: Text('${country['emoji']} ${country['name']}'),
                                            ))
                                        .toList(),
                                  ],
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
              SizedBox(
                height: 16,
              ),
              Stack(
                children: [
                  Container(
                    height: 360,
                    width: 360,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: pickedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: MediaFilePreview(
                              mediaFile: pickedImage,
                              isVideo: pickedImage.path.endsWith(".mp4") || pickedImage.path.endsWith(".mov"),
                            ))
                        : Center(
                            child: Text(
                              "No Media",
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                            ),
                          ),
                  ),

                  /// ⬇️ Add Button Positioned Top Right
                  Positioned(
                    top: -8,
                    right: -8,
                    child: IconButton(
                      icon: Icon(Icons.add_circle, color: theme.primaryColor, size: 32),
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
            ],
          ),
        ),
      ),
    );
  }
}
