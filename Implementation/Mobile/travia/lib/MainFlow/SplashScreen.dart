import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../Helpers/GoogleTexts.dart';
import '../Providers/ConversationProvider.dart';
import '../Providers/NotificationProvider.dart';
import '../Providers/PostsCommentsProviders.dart';
import '../database/DatabaseMethods.dart';
import '../main.dart';

class SplashScreen extends ConsumerStatefulWidget {
  final String? type;
  final String? source_id;
  const SplashScreen({super.key, this.type, this.source_id});

  @override
  ConsumerState<SplashScreen> createState() => SplashScreenState();
}

class SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _preloadAppData();
  }

  Future<void> _preloadAppData() async {
    await Future.delayed(Duration.zero);

    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/signin');
      });
      return;
    }

    // Check if profile exists first
    final supabaseUserId = await getSupabaseUserId(user.uid);
    if (!mounted) return;

    if (supabaseUserId == null) {
      // No profile yet
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/complete-profile');
      });
      return;
    }

    await prefs?.setString('supabase_user_id_${user.uid}', supabaseUserId);

    try {
      await Future.any([
        Future.wait([
          _fetchNotifications(),
          fetchConversationIds(user.uid),
        ]),
        Future.delayed(Duration(seconds: 5), () => throw TimeoutException('Timeout while loading data')),
      ]);

      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.type != null && widget.source_id != null) {
          context.go("/home/${Uri.encodeComponent(widget.type!)}/${Uri.encodeComponent(widget.source_id!)}");
        } else {
          context.go('/home');
        }
      });
    } catch (e) {
      print("Error: $e");
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go("/error-page/${Uri.encodeComponent(e.toString())}/${Uri.encodeComponent("/")}");
          }
        });
      }
    }
  }

  Future<void> _fetchPosts() async {
    final postsAsync = ref.read(postsProvider);
    await postsAsync.when(
      loading: () => Future.value(),
      error: (err, _) => Future.error(err),
      data: (posts) async {
        final recentPosts = posts.take(10).toList();
        for (var post in recentPosts) {
          await precacheImage(NetworkImage(post.mediaUrl), context);
        }
      },
    );
  }

  Future<void> _fetchNotifications() async {
    final notificationsAsync = ref.read(notificationsProvider);
    await notificationsAsync.when(
      loading: () => Future.value(),
      error: (err, _) => Future.error(err),
      data: (_) => Future.value(),
    );
  }

  Future<void> _fetchConversations() async {
    final conversationsAsync = ref.read(conversationDetailsProvider);
    await conversationsAsync.when(
      loading: () => Future.value(),
      error: (err, _) => Future.error(err),
      data: (_) => Future.value(),
    );
  }

  Future<void> _fetchUserData(String uid) async {
    String? cachedUserId = prefs?.getString('supabase_user_id_$uid');
    if (cachedUserId == null) {
      String? supabaseUserId = await getSupabaseUserId(uid);
      if (!mounted) return;
      if (supabaseUserId == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/complete-profile');
        });
        return;
      } else {
        await prefs?.setString('supabase_user_id_$uid', supabaseUserId);
      }
    }
  }

  Future<String?> getSupabaseUserId(String firebaseUserId) async {
    try {
      final response = await supabase.from('users').select('id').eq('id', firebaseUserId).maybeSingle();
      print('User fetch result: $response');

      if (response != null) {
        return response['id'] as String;
      } else {
        return null;
      }
    } catch (e) {
      print('Error getting Supabase user ID: $e');
      return null;
    }
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
              Colors.pinkAccent, // Deep purple
              Colors.purple, // Indigo
              Colors.orangeAccent, // Slate blue
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
                      )),
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
