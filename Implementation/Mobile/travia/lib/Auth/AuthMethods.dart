import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:travia/Helpers/PopUp.dart';

import '../Providers/LoadingProvider.dart';
import '../Services/NotificationService.dart';
import '../main.dart';

// =======================================

Future<bool> checkIfUsernameExists(String username) async {
  try {
    final response = await supabase.from('users').select('username').eq('username', username).limit(1);
    return response.isNotEmpty;
  } catch (e) {
    print('Error checking username existence: $e');
    return false;
  }
}

// =======================================

Future<bool> checkIfProfileExists(String userId) async {
  try {
    final response = await supabase
        .from('users')
        .select('id') // Only select the ID to minimize data transfer
        .eq('id', userId) // Filter by the provided user ID
        .limit(1); // Limit to 1 result, as we only need to know if it exists

    return response.isNotEmpty; // returns true if the user exists
  } catch (e) {
    print('Error checking user existence: $e');
    return false;
  }
}

// =======================================

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
      Popup.showWarning(
        text: "Please verify your email before logging in.",
        context: context,
      );
      return;
    }

    bool userExists = await checkIfProfileExists(user!.uid);
    if (userExists) {
      context.go("/home");
    } else {
      await user.updateDisplayName(null);
      context.go("/complete-profile");
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

    Popup.showError(text: errorMessage, context: context);
  } catch (e) {
    Popup.showError(
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

    print("User created successfully: ${user.uid}");
    print("User email: ${user.email}");
    print("Email verified status: ${user.emailVerified}");

    // Check if email verification is needed
    if (user.emailVerified) {
      print("Email is already verified!");
      Popup.showSuccess(
        text: "Account created and email is already verified!",
        context: context,
        duration: 5,
      );
      context.go("/splash-screen");
      return;
    }

    // Send email verification with detailed error handling
    try {
      print("Attempting to send verification email...");
      await user.sendEmailVerification();
      print("Verification email sent successfully!");

      // Show popup instructing user to verify
      Popup.showSuccess(
        text: "A verification email has been sent to $email. Please check your INBOX and SPAM folder.",
        context: context,
        duration: 10,
      );

      // Start listening for verification
      await _waitForEmailVerification(user, context, ref);
    } on FirebaseAuthException catch (emailError) {
      print("Firebase error sending verification email: ${emailError.code} - ${emailError.message}");

      switch (emailError.code) {
        case "too-many-requests":
          Popup.showError(
            text: "Too many verification emails sent. Please wait before requesting another.",
            context: context,
          );
          break;
        case "network-request-failed":
          Popup.showError(
            text: "Network error. Please check your connection and try again.",
            context: context,
          );
          break;
        case "invalid-email":
          Popup.showError(
            text: "Invalid email address. Please check and try again.",
            context: context,
          );
          break;
        default:
          Popup.showError(
            text: "Failed to send verification email: ${emailError.message}",
            context: context,
          );
      }
    } catch (emailError) {
      print("Unexpected error sending verification email: $emailError");
      Popup.showError(
        text: "Failed to send verification email. Please try again.",
        context: context,
      );
    }
  } on FirebaseAuthException catch (e) {
    print("Firebase Auth Exception: ${e.code} - ${e.message}");
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

    Popup.showError(text: errorMessage, context: context);
  } catch (e) {
    print("Unexpected error: $e");
    Popup.showError(
      text: "An unexpected error occurred. Please try again later.",
      context: context,
    );
  } finally {
    ref.read(loadingProvider.notifier).setLoadingToFalse();
  }
}
// =====================================

Future<void> _waitForEmailVerification(User user, BuildContext context, WidgetRef ref) async {
  final FirebaseAuth auth = FirebaseAuth.instance;
  const int timeoutSeconds = 300; // Set a timeout of 5 minutes
  int elapsedSeconds = 0;
  int refreshPeriod = 3;

  Timer.periodic(Duration(seconds: refreshPeriod), (timer) async {
    if (auth.currentUser == null) {
      timer.cancel();
      return;
    }
    await user.reload(); // Refresh user data
    User? refreshedUser = auth.currentUser; // Get latest user data

    if (refreshedUser != null && refreshedUser.emailVerified) {
      timer.cancel(); // Stop the periodic timer
      context.go("/splash-screen");
    }

    elapsedSeconds += refreshPeriod;
    if (elapsedSeconds >= timeoutSeconds) {
      timer.cancel(); // Stop checking after timeout
      Popup.showError(
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

    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
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
    if (user == null) {
      throw Exception("Error");
    }

    bool userExists = await checkIfProfileExists(user.uid);

    if (userExists) {
      context.go("/home");
    } else {
      await user.updateDisplayName(null);
      context.go("/complete-profile");
    }
  } catch (e) {
    print("Login error: $e");
    Popup.showError(text: "Google sign-in failed. Please check your internet and try again.", context: context);
  } finally {
    ref.read(loadingProvider.notifier).setLoadingToFalse();
  }
}

// =====================================

Future<void> forgotPassword(BuildContext context, WidgetRef ref, String email) async {
  try {
    ref.read(loadingProvider.notifier).setLoadingToTrue();
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    Popup.showSuccess(text: "Password reset email sent. Check your inbox.", context: context);
  } catch (e) {
    print("Password reset error: $e");
    Popup.showError(text: "Failed to send password reset email. Please try again.", context: context);
  } finally {
    ref.read(loadingProvider.notifier).setLoadingToFalse();
  }
}

// =====================================


final firebaseAuthProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// =====================================

Future<void> resendVerificationEmail(BuildContext context, WidgetRef ref) async {
  try {
    ref.read(loadingProvider.notifier).setLoadingToTrue();

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Popup.showError(
        text: "No user found. Please sign up first.",
        context: context,
      );
      return;
    }

    if (user.emailVerified) {
      Popup.showSuccess(
        text: "Your email is already verified! You can proceed to sign in.",
        context: context,
      );
      return;
    }

    await user.sendEmailVerification();
    Popup.showSuccess(
      text: "Verification email sent to ${user.email}. Please check your inbox.",
      context: context,
    );

    // Restart verification listening
    await _waitForEmailVerification(user, context, ref);
  } on FirebaseAuthException catch (e) {
    String errorMessage = "";
    switch (e.code) {
      case "too-many-requests":
        errorMessage = "Too many requests. Please wait before requesting another verification email.";
        break;
      case "network-request-failed":
        errorMessage = "Network error. Please check your connection.";
        break;
      default:
        errorMessage = "Failed to send verification email. Please try again.";
    }
    Popup.showError(text: errorMessage, context: context);
  } catch (e) {
    Popup.showError(
      text: "An unexpected error occurred. Please try again.",
      context: context,
    );
  } finally {
    ref.read(loadingProvider.notifier).setLoadingToFalse();
  }
}

// =====================================

Future<void> deleteAccount(BuildContext context) async {
  try {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    await NotificationService.removeFcmToken();

    await supabase.from("users").delete().eq("id", userId);

    await FirebaseAuth.instance.signOut();

    final googleSignIn = GoogleSignIn(
    );
    if (await googleSignIn.isSignedIn()) {
      await googleSignIn.signOut();
    }
    context.go("/splash-screen");
    Phoenix.rebirth(context);
  } catch (e) {
    Popup.showError(text: "Delete account failed", context: context);
    print('Delete error: $e');
  }
}

// =======================================

Future<void> signOut(BuildContext context, WidgetRef ref) async {
  try {



    // First remove FCM token (NOTIFICATIONS TOKEN)
    await NotificationService.removeFcmToken();

    // Sign out from Firebase authentication
    await FirebaseAuth.instance.signOut();

    final GoogleSignIn googleSignIn = GoogleSignIn();
    if (await googleSignIn.isSignedIn()) {
      await googleSignIn.signOut();
    }

    Phoenix.rebirth(context);


  } catch (e) {
    Popup.showError(text: "Sign-out failed", context: context);
    print(e);
  }
}

