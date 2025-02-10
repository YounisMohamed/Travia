import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:travia/Helpers/PopUp.dart';

import '../Providers/LoadingProvider.dart';
import '../main.dart';

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

    if (user != null && user.displayName != null) {
      context.go("/homepage");
    }
    if (user != null && user.displayName == null) {
      context.go("/name");
    }
    if (user == null) {
      throw Exception("User Not Found");
    }
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
      case "invalid-credential":
        errorMessage = "Incorrect password. Please try again.";
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
  const int timeoutSeconds = 300; // Set a timeout of 5 minutes
  int elapsedSeconds = 0;
  int refreshPeriod = 2;

  Timer.periodic(Duration(seconds: refreshPeriod), (timer) async {
    if (auth.currentUser == null) {
      timer.cancel();
      return;
    }
    await user.reload(); // Refresh user data
    User? refreshedUser = auth.currentUser; // Get latest user data

    if (refreshedUser != null && refreshedUser.emailVerified) {
      timer.cancel(); // Stop the periodic timer
      context.go("/signin", extra: true);
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

    final GoogleSignInAccount? googleUser = await GoogleSignIn(clientId: "536970171951-k30lmtrdnc348rr806u0lroar3kh5clj.apps.googleusercontent.com").signIn();
    if (googleUser == null) {
      ref.read(loadingProvider.notifier).setLoadingToFalse();
      return; // User canceled the sign-in
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    User? user = userCredential.user;

    if (user != null && user.displayName != null) {
      context.go("/homepage");
    }
    if (user != null && user.displayName == null) {
      context.go("/name");
    }
    if (user == null) {
      throw Exception("User Not Found");
    }
  } catch (e) {
    print("Login error: $e");
    Popup.showPopUp(text: "Google sign-in failed. Please try again.", context: context);
  } finally {
    ref.read(loadingProvider.notifier).setLoadingToFalse();
  }
}

// =====================================

Future<void> forgotPassword(BuildContext context, WidgetRef ref, String email) async {
  try {
    ref.read(loadingProvider.notifier).setLoadingToTrue();
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    Popup.showPopUp(text: "Password reset email sent. Check your inbox.", context: context, color: Colors.greenAccent);
  } catch (e) {
    print("Password reset error: $e");
    Popup.showPopUp(text: "Failed to send password reset email. Please try again.", context: context);
  } finally {
    ref.read(loadingProvider.notifier).setLoadingToFalse();
  }
}

// =====================================

Future<void> signOut(BuildContext context, WidgetRef ref) async {
  try {
    ref.read(loadingProvider.notifier).setLoadingToTrue();

    // Sign out from Firebase authentication
    await FirebaseAuth.instance.signOut();

    // Also sign out from Google if the user signed in with Google
    final GoogleSignIn googleSignIn = GoogleSignIn(clientId: "536970171951-k30lmtrdnc348rr806u0lroar3kh5clj.apps.googleusercontent.com");
    if (await googleSignIn.isSignedIn()) {
      await googleSignIn.signOut();
    }

    final statuses = await supabase.removeAllChannels(); // Remove supabase channels (DATABASE)

    context.go("/signin");
  } catch (e) {
    Popup.showPopUp(text: "Sign-out failed", context: context);
    print(e);
  } finally {
    ref.read(loadingProvider.notifier).setLoadingToFalse();
  }
}

/*
// client ids if needed
GoogleSignIn googleSignInProvider() {
  const webClientId = '1037102746825-51eovbm3p4d244plah5l1uk04oo7vag6.apps.googleusercontent.com';

  const androidClientId = '722459534211-gie50eb2cjspqfndnk0ht7hi3hfktg88.apps.googleusercontent.com';

  const iosClientId = '722459534211-otql03j9vqlasl5jov5orbjmg2l555d5.apps.googleusercontent.com';
  return GoogleSignIn(scopes: ['email'], clientId: Platform.isIOS ? iosClientId : androidClientId, serverClientId: webClientId);
}


 */
