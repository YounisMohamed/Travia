import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:travia/Helpers/PopUp.dart';
import 'package:uuid/uuid.dart';

import '../Classes/Media.dart';
import '../Helpers/AppColors.dart';
import '../Helpers/Loading.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isRearCameraSelected = true;
  bool _cameraInitialized = false;
  bool _takingPicture = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCameras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes to properly manage camera resources
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupCamera();
    }
  }

  // Initialize camera list first, separately from controller setup
  Future<void> _initializeCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        await _setupCamera();
      } else {
        _showError('No cameras found on this device');
      }
    } catch (e) {
      _showError('Failed to find any cameras: $e');
    }
  }

  // Setup the camera controller with appropriate settings
  Future<void> _setupCamera() async {
    if (_cameras == null || _cameras!.isEmpty) {
      return;
    }

    try {
      // Select camera based on user preference
      final camera = _isRearCameraSelected
          ? _cameras!.firstWhere(
              (cam) => cam.lensDirection == CameraLensDirection.back,
              orElse: () => _cameras!.first,
            )
          : _cameras!.firstWhere(
              (cam) => cam.lensDirection == CameraLensDirection.front,
              orElse: () => _cameras!.first,
            );

      // Create a new controller with higher resolution
      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      // Initialize the controller
      await _controller!.initialize();

      // If available, set auto focus mode for better quality
      if (_controller!.value.isInitialized) {
        try {
          await _controller!.setFocusMode(FocusMode.auto);
          await _controller!.setExposureMode(ExposureMode.auto);
        } catch (e) {
          // Ignore if focus or exposure modes aren't supported
        }
      }

      if (mounted) {
        setState(() {
          _cameraInitialized = true;
        });
      }
    } catch (e) {
      _showError('Error initializing camera: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      Popup.showError(text: "Sorry, an error happened", context: context);
    }
  }

  Future<void> _switchCamera() async {
    if (_controller?.value?.isRecordingVideo ?? false) {
      return;
    }

    setState(() {
      _cameraInitialized = false;
      _isRearCameraSelected = !_isRearCameraSelected;
    });

    await _controller?.dispose();
    await _setupCamera();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _takingPicture) {
      return;
    }

    setState(() {
      _takingPicture = true;
    });

    try {
      // Lock exposure and focus for better quality
      try {
        await _controller!.setFocusMode(FocusMode.locked);
        await _controller!.setExposureMode(ExposureMode.locked);
      } catch (e) {
        // Ignore if locking isn't supported
      }

      // Take the picture with maximum quality
      final XFile file = await _controller!.takePicture();

      // Reset focus and exposure modes
      try {
        await _controller!.setFocusMode(FocusMode.auto);
        await _controller!.setExposureMode(ExposureMode.auto);
      } catch (e) {
        // Ignore if resetting isn't supported
      }

      // Create a directory for saving the image
      final Directory tempDir = await getTemporaryDirectory();
      final String uniqueId = const Uuid().v4();
      final String targetPath = '${tempDir.path}/$uniqueId.jpg';

      // Copy to a permanent path
      final File newFile = await File(file.path).copy(targetPath);

      // Create AssetEntity and Media object
      final AssetEntity asset = await PhotoManager.editor.saveImageWithPath(
        newFile.path,
        title: 'Camera Photo',
      );

      final media = Media(
        assetEntity: asset,
        widget: Image.file(newFile, fit: BoxFit.cover),
      );

      // Return to previous screen
      if (mounted) {
        Navigator.pop(context, media);
      }
    } catch (e) {
      setState(() {
        _takingPicture = false;
      });
      _showError('Failed to take picture: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kWhite),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _cameraInitialized && _controller != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                // Camera Preview - Better camera preview handling
                Center(
                  child: _controller!.value.isInitialized ? CameraPreview(_controller!) : const Text('Initializing camera...', style: TextStyle(color: kWhite)),
                ),

                // Bottom controls
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Switch camera button
                        FloatingActionButton(
                          heroTag: 'switchCamera',
                          backgroundColor: kDeepPink.withOpacity(0.8),
                          mini: true,
                          onPressed: _switchCamera,
                          child: const Icon(Icons.flip_camera_ios, color: kWhite),
                        ),

                        // Capture button - larger, more visually prominent
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: kWhite, width: 3),
                          ),
                          child: FloatingActionButton(
                            heroTag: 'takePhoto',
                            backgroundColor: kWhite,
                            onPressed: _takingPicture ? null : _takePicture,
                            child: Icon(
                              Icons.camera_alt,
                              color: _takingPicture ? Colors.grey : kDeepPink,
                              size: 30,
                            ),
                          ),
                        ),

                        // Empty spacer to balance layout
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),

                // Loading indicator while taking picture
                if (_takingPicture)
                  Center(
                    child: LoadingWidget(
                      size: 60,
                      colors: const [kDeepPink, kDeepPinkLight, Colors.white],
                    ),
                  ),
              ],
            )
          : Center(
              child: LoadingWidget(
                size: 60,
                colors: const [kDeepPink, kDeepPinkLight],
              ),
            ),
    );
  }
}
