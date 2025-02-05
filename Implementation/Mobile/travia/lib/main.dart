import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:travia/Authentacation/SignInPage.dart';
import 'package:travia/Authentacation/SignInWithOtp.dart';
import 'package:travia/Authentacation/SignUpPage.dart';
import 'package:travia/Authentacation/confirmEmail.dart';
import 'package:travia/Authentacation/namePage.dart';
import 'package:travia/MainFlow/HomePage.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    final GoRouter _router = GoRouter(
      initialLocation: '/signup', // initial location
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
          path: '/signinotp',
          builder: (context, state) => SignInWithOtp(),
        ),
      ],
      /*
      redirect: (context, state) {
        final isAuthenticated = FirebaseAuth.instance.currentUser != null;
        final isOnSignInPage = state.uri.toString() == "/signin";
        final nameMissing = FirebaseAuth.instance.currentUser?.displayName != null;
        if(nameMissing && isAuthenticated){
          return '/name';
        }
        if (isAuthenticated && isOnSignInPage) {
          return '/homepage';
        }
        return null;
      },
       */
    );

    return MaterialApp.router(
      title: 'Travia App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: _router, // GoRouter configuration
    );
  }
}
