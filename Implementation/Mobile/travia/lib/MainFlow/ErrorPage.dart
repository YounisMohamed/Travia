import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:go_router/go_router.dart';

import '../Helpers/GoogleTexts.dart';

class ErrorPage extends StatelessWidget {
  final String error;
  final String path;
  const ErrorPage({super.key, required this.error, required this.path});

  @override
  Widget build(BuildContext context) {
    // STUPID DUMBASS ERROR MAN
    if (error.contains('RealtimeSubscribeException(status: RealtimeSubscribeStatus.channelError, details: null)')) {
      Future.microtask(() => Phoenix.rebirth(context));
      return const SizedBox.shrink();
    }
    return Scaffold(
      backgroundColor: Colors.white, // White background for contrast
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 80,
            ),
            const SizedBox(height: 20),
            RedHatText(
              text: "Oops! Something Went Wrong",
              color: Colors.red,
              isBold: true,
              size: 22,
              center: true,
            ),
            const SizedBox(height: 10),

            Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    RedHatText(
                      text: "We're sorry, but an error occurred.\n Kindly check your",
                      color: Colors.grey[600]!,
                      size: 16,
                      center: true,
                      isBold: true,
                    ),
                    RedHatText(
                      text: "internet connection",
                      color: Colors.blue[600]!,
                      size: 16,
                      center: true,
                      isBold: true,
                    ),
                    RedHatText(
                      text: "Hey younis remember to remove this later: $error",
                      color: Colors.grey[600]!,
                      size: 16,
                      center: true,
                      isBold: true,
                    ),
                  ],
                )),
            const SizedBox(height: 30),

            // Restart Button
            ElevatedButton(
              onPressed: () {
                Phoenix.rebirth(context);
                context.go(path);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: RedHatText(
                text: "Try again",
                color: Colors.white,
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
