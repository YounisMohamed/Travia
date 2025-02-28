import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../Authentacation/AuthMethods.dart';
import '../Helpers/DefaultText.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAppState();
  }

  Future<void> _checkAppState() async {
    bool allGranted = await checkPermissions();

    if (!allGranted) {
      if (mounted) context.go('/permissions');
      return;
    }

    // Check Firebase authentication
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) context.go('/signin');
      return;
    }

    // Check if user profile exists in Supabase
    bool profileExists = await checkIfProfileExists(user.uid);
    if (!profileExists) {
      if (mounted) context.go('/complete-profile');
      return;
    }

    // If everything is good, navigate to home
    if (mounted) context.go('/');
  }

  Future<bool> checkPermissions() async {
    return true; // will need later
    /*
    final storageStatus = await Permission.storage.status;

    print('Initial Storage Status: $storageStatus');

    if (storageStatus.isGranted) {
      return true;
    }
    return false;

     */
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.purpleAccent,
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.flight_takeoff,
                color: Colors.white,
                size: 80,
              )
                  .animate()
                  .fade(duration: 200.ms)
                  .scale(
                    begin: const Offset(0.5, 0.5),
                    end: const Offset(1, 1),
                    duration: 200.ms,
                  )
                  .then()
                  .slideX(
                    begin: -0.2,
                    end: 0.2,
                    duration: 400.ms,
                    curve: Curves.easeInOutSine,
                  )
                  .slideY(
                    begin: 0.1,
                    end: -0.1,
                    duration: 400.ms,
                    curve: Curves.easeInOutSine,
                  )
                  .rotate(
                    begin: -0.1,
                    end: 0.1,
                    duration: 400.ms,
                    curve: Curves.easeInOutSine,
                  ),
              const SizedBox(height: 20),
              DefaultText(
                text: "Travia",
                color: Colors.white,
                isBold: true,
                size: 48,
                center: true,
              ).animate().fadeIn(duration: 300.ms).scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1),
                    duration: 300.ms,
                  ),
              const SizedBox(height: 10),
              DefaultText(
                text: "Connect, Explore, Share",
                color: Colors.white70,
                size: 18,
                center: true,
                italic: true,
              )
                  .animate()
                  .fadeIn(
                    delay: 100.ms,
                    duration: 300.ms,
                  )
                  .slideY(
                    begin: 0.2,
                    end: 0,
                    duration: 300.ms,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
