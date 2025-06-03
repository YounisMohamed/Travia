import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:travia/Helpers/PopUp.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Helpers/AppColors.dart';

class BannedUserPage extends StatelessWidget {
  const BannedUserPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Warning Icon with gradient background
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      kDeepPink,
                      kDeepPinkLight,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kDeepPink.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.block_rounded,
                  color: Colors.white,
                  size: 60,
                ),
              ),

              const SizedBox(height: 40),

              // Title
              Text(
                "Account Suspended",
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Subtitle with gradient text effect
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [kDeepPink, kDeepPinkLight],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ).createShader(bounds),
                child: Text(
                  "Your account is temporarily paused",
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 40),

              // Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: kDeepPink.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: kDeepPink,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Why was I suspended?",
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Your account has been temporarily suspended due to a violation of our community guidelines. This action helps us maintain a safe and positive environment for all travelers.",
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // Contact Support Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black,
                      kDeepPink,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: kDeepPink.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      String? encodeQueryParameters(Map<String, String> params) {
                        return params.entries.map((MapEntry<String, String> e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');
                      }

                      final Uri emailUri = Uri(
                        scheme: 'mailto',
                        path: 'youniesmm9@gmail.com',
                        query: encodeQueryParameters({
                          'subject': 'Account Suspension Appeal - Travia App',
                          'body': 'Hello Travia Support,\n\nI am writing to appeal my account suspension. Please review my case.\n\nThank you.',
                        }),
                      );

                      try {
                        await launchUrl(emailUri);
                      } catch (e) {
                        Popup.showError(text: "Error opening email app. Please contact: youniesmm9@gmail.com", context: context);
                      }
                    },
                    child: Container(
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.support_agent_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Contact Support",
                            style: GoogleFonts.ibmPlexSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Footer text
              Text(
                "We're here to help you get back to exploring",
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  color: Colors.black38,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
