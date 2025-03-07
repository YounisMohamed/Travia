import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../Helpers/GoogleTexts.dart';
import '../main.dart';

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
    await Future.delayed(Duration(milliseconds: 1200));
    if (!mounted) return; // Exit if widget is already disposed

    bool allGranted = checkPermissions();
    if (!mounted) return;
    if (!allGranted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/permissions');
      });
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/signin');
      });
      return;
    }

    String? cachedUserId = prefs?.getString('supabase_user_id_${user.uid}');
    if (cachedUserId == null) {
      String? supabaseUserId = await getSupabaseUserId(user.uid);
      if (!mounted) return;
      if (supabaseUserId == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/complete-profile');
        });
        return;
      } else {
        await prefs?.setString('supabase_user_id_${user.uid}', supabaseUserId);
      }
    } else {
      if (cachedUserId != user.uid) {
        String? supabaseUserId = await getSupabaseUserId(user.uid);
        if (!mounted) return;
        if (supabaseUserId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/complete-profile');
          });
          return;
        } else {
          await prefs?.setString('supabase_user_id_${user.uid}', supabaseUserId);
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/');
    });
  }

  Future<String?> getSupabaseUserId(String firebaseUserId) async {
    try {
      final response = await supabase.from('users').select('id').eq('id', firebaseUserId).limit(1);

      if (response.isNotEmpty) {
        return response.first['id'] as String;
      } else {
        return null;
      }
    } catch (e) {
      print('Error getting Supabase user ID: $e');
      return null;
    }
  }

  bool checkPermissions() {
    return true; // will need later
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
              Color(0xFF8A2BE2), // Deep purple
              Color(0xFF4B0082), // Indigo
              Color(0xFF6A5ACD), // Slate blue
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background decorative elements
            Positioned(
              top: -50,
              right: -50,
              child: Opacity(
                opacity: 0.1,
                child: Icon(
                  Icons.map_outlined,
                  size: 200,
                  color: Colors.white,
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Opacity(
                opacity: 0.1,
                child: Icon(
                  Icons.camera_alt_outlined,
                  size: 150,
                  color: Colors.white,
                ),
              ),
            ),
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.flight_takeoff,
                      color: Colors.white,
                      size: 80,
                    )
                        .animate()
                        .fade(duration: 300.ms)
                        .scale(
                          begin: const Offset(0.5, 0.5),
                          end: const Offset(1, 1),
                          duration: 400.ms,
                          curve: Curves.elasticOut,
                        )
                        .then()
                        .slideX(
                          begin: -0.2,
                          end: 0.2,
                          duration: 1000.ms,
                          curve: Curves.easeInOutSine,
                        )
                        .slideY(
                          begin: 0.1,
                          end: -0.1,
                          duration: 1000.ms,
                          curve: Curves.easeInOutSine,
                        )
                        .rotate(
                          begin: -0.1,
                          end: 0.1,
                          duration: 1000.ms,
                          curve: Curves.easeInOutSine,
                        ),
                  ),
                  const SizedBox(height: 30),
                  RedHatText(
                    text: "Travia",
                    color: Colors.white,
                    isBold: true,
                    size: 56,
                    center: true,
                  ).animate().fadeIn(duration: 400.ms).scale(
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1, 1),
                        duration: 500.ms,
                        curve: Curves.easeOutBack,
                      ),
                  const SizedBox(height: 15),
                  RedHatText(
                    text: "Connect • Explore • Share",
                    color: Colors.white.withOpacity(0.9),
                    size: 20,
                    center: true,
                    italic: true,
                  )
                      .animate()
                      .fadeIn(
                        delay: 300.ms,
                        duration: 400.ms,
                      )
                      .slideY(
                        begin: 0.2,
                        end: 0,
                        duration: 400.ms,
                        curve: Curves.easeOutCubic,
                      ),
                  const SizedBox(height: 40),
                  Container(
                    width: 180,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Center(
                      child: RedHatText(
                        text: "Your journey awaits",
                        color: Colors.white,
                        size: 16,
                        center: true,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(
                        delay: 600.ms,
                        duration: 400.ms,
                      )
                      .scale(
                        delay: 600.ms,
                        begin: const Offset(0.9, 0.9),
                        end: const Offset(1, 1),
                        duration: 300.ms,
                      ),
                ],
              ),
            ),
            // Loading indicator at bottom
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    color: Colors.white.withOpacity(0.7),
                    strokeWidth: 2,
                  ),
                ).animate().fadeIn(delay: 800.ms, duration: 400.ms),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
