import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:travia/Helpers/PopUp.dart';

import '../Helpers/GoogleTexts.dart';

Future<bool> checkPermissions() async {
  final PermissionState ps = await PhotoManager.requestPermissionExtend();
  return ps.isAuth;
}

class PermissionPage extends StatelessWidget {
  const PermissionPage({super.key});

  Future<void> _requestPermissions(BuildContext context) async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) {
      Popup.showPopUp(
        text: 'Storage permission granted!',
        context: context,
        color: Colors.greenAccent,
      );
      context.go("/splash-screen");
    } else if (ps.hasAccess) {
      Popup.showPopUp(
        text: 'Limited access granted!',
        context: context,
        color: Colors.orangeAccent,
      );
      context.go("/splash-screen");
    } else {
      _showSettingsDialog(context);
    }
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text('Some permissions were permanently denied. Please enable them in the app settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(ctx);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.purple,
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(screenWidth * 0.05), // 5% of screen width
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Fun Header Icon
                Icon(
                  Icons.travel_explore,
                  size: screenHeight * 0.12, // 12% of screen height
                  color: Colors.white.withOpacity(0.9),
                ),
                SizedBox(height: screenHeight * 0.03), // 3% of screen height

                // Title
                const Text(
                  'Unlock Your Journey',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: screenHeight * 0.015), // 1.5% of screen height

                // Subtitle
                const Text(
                  'Grant these permissions to capture and share your travel stories!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: screenHeight * 0.04), // 4% of screen height

                // Permission Cards
                _PermissionCard(
                  icon: Icons.camera_alt,
                  title: 'Camera',
                  subtitle: 'Snap those epic travel moments.',
                  color: Colors.orange.withOpacity(0.8),
                ),
                SizedBox(height: screenHeight * 0.02), // 2% of screen height
                _PermissionCard(
                  icon: Icons.photo_library,
                  title: 'Storage',
                  subtitle: 'Pick pics from your gallery.',
                  color: Colors.purple.withOpacity(0.8),
                ),
                SizedBox(height: screenHeight * 0.05), // 5% of screen height

                // Action Button
                ElevatedButton(
                  onPressed: () => _requestPermissions(context),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.02, // 2% of screen height
                      horizontal: screenWidth * 0.1, // 10% of screen width
                    ),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 8,
                  ),
                  child: RedHatText(
                    text: "Lets Go!",
                    center: true,
                    italic: true,
                    color: Colors.black,
                    size: 22,
                    isBold: true,
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

class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.03), // 3% of screen width
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: screenWidth * 0.05, // 5% of screen width
            backgroundColor: color,
            child: Icon(
              icon,
              size: screenWidth * 0.06, // 6% of screen width
              color: Colors.white,
            ),
          ),
          SizedBox(width: screenWidth * 0.03), // 3% of screen width
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
