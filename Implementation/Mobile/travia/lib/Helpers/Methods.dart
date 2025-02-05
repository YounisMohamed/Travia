import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travia/Helpers/popUp.dart';

import '../Providers/LoadingProvider.dart';

Future<void> signInWithEmailAndPassword(
  BuildContext context,
  WidgetRef ref, {
  required String email,
  required String password,
}) async {
  try {
    ref.read(loadingProvider.notifier).setLoadingToTrue();

    UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    User? user = userCredential.user;

    // Check if email is verified
    if (user != null && !user.emailVerified) {
      await FirebaseAuth.instance.signOut(); // Prevent login if not verified
      Popup.showPopUp(
        text: "Please verify your email before logging in.",
        context: context,
      );
      return;
    }

    // If verified, navigate to homepage
    context.go("/homepage");
  } on FirebaseAuthException catch (e) {
    print(e);
    String errorMessage = "";

    switch (e.code) {
      case "invalid-email":
        errorMessage = "The email address is not a valid email.";
        break;
      case "user-not-found":
        errorMessage = "No account found for this email. Please sign up first.";
        break;
      case "wrong-password":
        errorMessage = "Incorrect password. Please try again.";
        break;
      case "user-disabled":
        errorMessage = "This account has been disabled. Contact support.";
        break;
      case "too-many-requests":
        errorMessage = "Too many login attempts. Please try again later.";
        break;
      case "network-request-failed":
        errorMessage = "Network error. Please check your connection.";
        break;
      default:
        errorMessage = "Something went wrong. Please try again later.";
    }

    Popup.showPopUp(text: errorMessage, context: context);
  } catch (e) {
    Popup.showPopUp(
      text: "An unexpected error occurred. Please try again later.",
      context: context,
    );
  } finally {
    ref.read(loadingProvider.notifier).setLoadingToFalse();
  }
}

// =====================================

Future<void> signUpWithEmailAndPassword(
  BuildContext context,
  WidgetRef ref, {
  required String email,
  required String password,
}) async {
  try {
    ref.read(loadingProvider.notifier).setLoadingToTrue();

    // Create user
    UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    User? user = userCredential.user;
    if (user == null) throw Exception("User creation failed");

    // Send email verification
    await user.sendEmailVerification();

    // Show popup instructing user to verify
    Popup.showPopUp(
      text: "A verification email has been sent to $email. Please verify before logging in.",
      context: context,
      color: Colors.greenAccent,
    );

    // Start listening for verification
    await _waitForEmailVerification(user, context);
  } on FirebaseAuthException catch (e) {
    print(e);
    String errorMessage = "";

    switch (e.code) {
      case "email-already-in-use":
        errorMessage = "This email is already in use. Try logging in instead.";
        break;
      case "invalid-email":
        errorMessage = "The email address is not a valid email.";
        break;
      case "weak-password":
        errorMessage = "The password must be:\nAt least 6 characters long\nHas a capital letter\nHas a number\nHas a special character";
        break;
      case "operation-not-allowed":
        errorMessage = "Sign-up is currently disabled. Contact support.";
        break;
      case "network-request-failed":
        errorMessage = "Network error. Please check your connection.";
        break;
      default:
        errorMessage = "Something went wrong. Please try again.";
    }

    Popup.showPopUp(text: errorMessage, context: context);
  } catch (e) {
    Popup.showPopUp(
      text: "An unexpected error occurred. Please try again later.",
      context: context,
    );
  } finally {
    ref.read(loadingProvider.notifier).setLoadingToFalse();
  }
}

// =====================================

Future<void> _waitForEmailVerification(User user, BuildContext context) async {
  final FirebaseAuth auth = FirebaseAuth.instance;
  const int timeoutSeconds = 120; // Set a timeout of 2 minutes
  int elapsedSeconds = 0;
  int refreshPeriod = 2;

  Timer.periodic(Duration(seconds: refreshPeriod), (timer) async {
    await user.reload(); // Refresh user data
    User? refreshedUser = auth.currentUser; // Get latest user data

    if (refreshedUser != null && refreshedUser.emailVerified) {
      timer.cancel(); // Stop the periodic timer
      context.go("/signin");
    }

    elapsedSeconds += refreshPeriod;
    if (elapsedSeconds >= timeoutSeconds) {
      timer.cancel(); // Stop checking after timeout
      Popup.showPopUp(
        text: "Email verification timed out. Please verify manually and try again.",
        context: context,
      );
    }
  });
}

// =====================================

Future<void> signInWithGoogle(BuildContext context, WidgetRef ref) async {
  try {
    ref.read(loadingProvider.notifier).setLoadingToTrue();
    // implement signing in with google
    ref.read(loadingProvider.notifier).setLoadingToFalse();
    print("SUCCESS");
  } catch (e) {
    print("Login error: $e");
    Popup.showPopUp(text: e.toString(), context: context);
  }
}

/*
// client ids if needed
GoogleSignIn googleSignInProvider() {
  const webClientId = '722459534211-4dqe3fhikb9v69esaa1lcpbkdiaqjlhk.apps.googleusercontent.com';

  const androidClientId = '722459534211-gie50eb2cjspqfndnk0ht7hi3hfktg88.apps.googleusercontent.com';

  const iosClientId = '722459534211-otql03j9vqlasl5jov5orbjmg2l555d5.apps.googleusercontent.com';
  return GoogleSignIn(scopes: ['email'], clientId: Platform.isIOS ? iosClientId : androidClientId, serverClientId: webClientId);
}


 */
