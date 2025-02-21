import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:go_router/go_router.dart';

import '../Helpers/DefaultText.dart';

class ErrorPage extends StatelessWidget {
  const ErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White background for contrast
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error Icon or Image (you can replace with your own asset)
            Icon(
              Icons.error_outline,
              color: Colors.deepPurple, // Purple for the error icon
              size: 80,
            ),
            const SizedBox(height: 20), // Spacing

            // Error Title
            DefaultText(
              text: "Oops! Something Went Wrong",
              color: Colors.deepPurple, // Purple text
              isBold: true,
              size: 24,
              center: true,
            ),
            const SizedBox(height: 10), // Spacing

            // Error Message
            DefaultText(
              text: "We're sorry, but an error occurred. Please try again.",
              color: Colors.grey[600]!, // Slightly darker grey for readability
              size: 16,
              center: true,
            ),
            const SizedBox(height: 30), // More spacing before button

            // Restart Button
            ElevatedButton(
              onPressed: () {
                Phoenix.rebirth(context);
                context.go("/signin");
              }, // Empty onPressed for now
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, // Orange button
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: DefaultText(
                text: "Restart App",
                color: Colors.white, // White text on orange button
                isBold: true,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Note: Ensure you have your DefaultText widget imported and defined as provided in your message.
