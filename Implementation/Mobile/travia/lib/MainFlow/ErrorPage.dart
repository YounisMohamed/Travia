import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:go_router/go_router.dart';

import '../Helpers/GoogleTexts.dart';

class ErrorPage extends StatelessWidget {
  final String error;
  const ErrorPage({super.key, required this.error});

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
              color: Colors.red, // Purple for the error icon
              size: 80,
            ),
            const SizedBox(height: 20), // Spacing

            // Error Title
            RedHatText(
              text: "Oops! Something Went Wrong",
              color: Colors.red, // Purple text
              isBold: true,
              size: 22,
              center: true,
            ),
            const SizedBox(height: 10), // Spacing

            // Error Message
            Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    RedHatText(
                      text: "We're sorry, but an error occurred.\n Kindly check your",
                      color: Colors.grey[600]!, // Slightly darker grey for readability
                      size: 16,
                      center: true,
                      isBold: true,
                    ),
                    RedHatText(
                      text: "internet connection",
                      color: Colors.blue[600]!, // Slightly darker grey for readability
                      size: 16,
                      center: true,
                      isBold: true,
                    ),
                    RedHatText(
                      text: " and please try again.",
                      color: Colors.grey[600]!, // Slightly darker grey for readability
                      size: 16,
                      center: true,
                      isBold: true,
                    ),
                  ],
                )),
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
              child: RedHatText(
                text: "Restart App",
                color: Colors.white, // White text on orange button
                isBold: true,
                size: 18,
              ),
            ),
            RedHatText(
              text: "Hey younis remember to remove this later: $error",
              color: Colors.white, // White text on orange button
              isBold: true,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// Note: Ensure you have your DefaultText widget imported and defined as provided in your message.
