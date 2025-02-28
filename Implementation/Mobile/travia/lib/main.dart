import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travia/Authentacation/ForgotPassword.dart';
import 'package:travia/Authentacation/SignInPage.dart';
import 'package:travia/Authentacation/SignUpPage.dart';
import 'package:travia/Authentacation/completeProfilePage.dart';
import 'package:travia/MainFlow/ErrorPage.dart';
import 'package:travia/MainFlow/HomePage.dart';
import 'package:travia/MainFlow/NotificationsPage.dart';
import 'package:travia/MainFlow/SplashScreen.dart';
import 'package:travia/MainFlow/UploadPost.dart';

import 'MainFlow/PermissionsPage.dart';
import 'MainFlow/PostDetails.dart';
import 'firebase_options.dart';

final supabase = Supabase.instance.client;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://cqcsgwlskhuylgbqegnz.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNxY3Nnd2xza2h1eWxnYnFlZ256Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzkwMjE0MTMsImV4cCI6MjA1NDU5NzQxM30.j-sQL5Ez7hOt9YbwevWe77ac8w0Y9eJ-4vIb7n6YqGc',
    realtimeClientOptions: const RealtimeClientOptions(
      logLevel: RealtimeLogLevel.info,
    ),
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(Phoenix(child: ProviderScope(child: Directionality(textDirection: TextDirection.ltr, child: MyApp()))));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    print(user?.uid);
    print(user?.email);
    print(user?.photoURL);
    print(user?.displayName);
    print("------------");
    final GoRouter router = GoRouter(
      initialLocation: '/splash-screen', // initial location
      routes: [
        // ======================
        // AUTH ROUTES
        GoRoute(
          path: '/signin',
          builder: (context, state) => SignInPage(),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) => SignUpPage(),
        ),
        GoRoute(
          path: '/forgotpassword',
          builder: (context, state) => ForgotPassword(),
        ),
        // ======================
        // MAIN FLOW ROUTES
        GoRoute(
          path: '/',
          builder: (context, state) => HomePage(),
        ),
        GoRoute(
          path: '/complete-profile',
          builder: (context, state) => CompleteProfilePage(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => NotificationsPage(),
        ),
        GoRoute(
          path: '/permissions',
          builder: (context, state) => PermissionPage(),
        ),
        GoRoute(
          path: '/error-page',
          builder: (context, state) => ErrorPage(),
        ),
        GoRoute(
          path: '/splash-screen',
          builder: (context, state) => SplashScreen(),
        ),
        GoRoute(
          path: '/post/:postId',
          builder: (context, state) {
            final postId = state.pathParameters['postId']!;
            return PostDetailsPage(postId: postId);
          },
        ),
        GoRoute(
          path: '/upload-post',
          builder: (context, state) => UploadPostPage(),
        ),
      ],
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
        ),
      ),
      title: 'Travia App',
      routerConfig: router, // GoRouter configuration
    );
  }
}
