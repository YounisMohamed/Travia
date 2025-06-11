import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:go_router/go_router.dart';
import 'package:travia/Helpers/AppColors.dart';

import '../Helpers/GoogleTexts.dart';

class ErrorPage extends StatelessWidget {
  final String error;
  final String path;
  const ErrorPage({super.key, required this.error, required this.path});

  @override
  Widget build(BuildContext context) {
    // STUPID DUMBASS ERROR MAN
    if (error.contains('RealtimeSubscribeStatus.channelError') || error.contains('RealtimeSubscribeStatus.timedOut')) {
      Future.microtask(() => Phoenix.rebirth(context));
      return const SizedBox.shrink();
    }
    return Scaffold(
        body: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kDeepPink,
            Colors.black, // Indigo
            kDeepPinkLight, // Slate blue
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 80,
            ),
            const SizedBox(height: 20),
            RedHatText(
              text: "Oops! Something Went Wrong",
              color: Colors.white,
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
                      text: "This could be to a real time error or a bug\n Kindly check your",
                      color: kBackground,
                      size: 16,
                      center: true,
                      isBold: true,
                    ),
                    RedHatText(
                      text: "\nInternet connection\n",
                      color: Colors.blue[600]!,
                      size: 18,
                      center: true,
                      isBold: true,
                    ),
                    RedHatText(
                      text: "If this keeps happening, Close the app and open again.",
                      color: kBackground,
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
                context.push(path);
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
    ));
  }
}

// Note: Ensure you have your DefaultText widget imported and defined as provided in your message.
