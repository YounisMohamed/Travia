import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../Auth/AuthMethods.dart';

class GoogleSignInButton extends StatelessWidget {
  final BuildContext contextOfParent;
  final WidgetRef ref;

  // Constructor to pass context and ref
  const GoogleSignInButton({
    super.key,
    required this.contextOfParent,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    double sizeOfButton = 60;
    double sizeOfGoogleLogo = 50;
    return ElevatedButton(
      onPressed: () async {
        await signInWithGoogle(contextOfParent, ref);
      },
      style: ElevatedButton.styleFrom(
        shape: const CircleBorder(), // Makes the button circular
        padding: EdgeInsets.zero, // Removes default button padding
        minimumSize: Size(sizeOfButton, sizeOfButton), // Sets the button size
        backgroundColor: Colors.white, //Sets the background color of the button
        shadowColor: Colors.black,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        height: sizeOfButton,
        width: sizeOfButton,
        child: Center(
          child: Image.asset(
            'assets/google_logo.webp',
            height: sizeOfGoogleLogo,
            width: sizeOfGoogleLogo,
          ),
        ),
      ),
    );
  }
}
