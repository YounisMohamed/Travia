import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travia/Authentacation/ForgotPassword.dart';
import 'package:travia/Authentacation/SignInPage.dart';
import 'package:travia/Authentacation/SignUpPage.dart';
import 'package:travia/Authentacation/confirmEmail.dart';
import 'package:travia/Authentacation/namePage.dart';
import 'package:travia/MainFlow/HomePage.dart';

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
    storageOptions: const StorageClientOptions(
      retryAttempts: 10,
    ),
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Hive.initFlutter();
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter(
      initialLocation: '/signin', // initial location
      routes: [
        // Define the routes
        GoRoute(
          path: '/signin',
          builder: (context, state) => SignInPage(),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) => SignUpPage(),
        ),
        GoRoute(
          path: '/homepage',
          builder: (context, state) => HomePage(),
        ),
        GoRoute(
          path: '/name',
          builder: (context, state) => displayNamePage(),
        ),
        GoRoute(
          path: '/confirm',
          builder: (context, state) => Confirmemail(),
        ),
        GoRoute(
          path: '/forgotpassword',
          builder: (context, state) => ForgotPassword(),
        ),
      ],
      redirect: (context, state) {
        final isAuthenticated = FirebaseAuth.instance.currentUser != null;
        final isOnSignInPage = state.uri.toString() == "/signin";
        final isOnNamePage = state.uri.toString() == "/name";
        final isOnConfirmPage = state.uri.toString() == "/confirm";
        final isOnForgotPasswordPage = state.uri.toString() == "/forgotpassword";
        final nameMissing = FirebaseAuth.instance.currentUser?.displayName == null || FirebaseAuth.instance.currentUser?.displayName?.isEmpty == true;
        final isVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

        if (isAuthenticated && isVerified && nameMissing) {
          // If authenticated, verified, but no display name, redirect to name page
          return '/name';
        }

        if (isAuthenticated && isVerified && !nameMissing && isOnSignInPage) {
          // If authenticated, verified, and has display name, redirect to homepage if on sign-in page
          return '/homepage';
        }

        return null;
      },
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
