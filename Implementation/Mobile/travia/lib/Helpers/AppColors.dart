import 'package:flutter/material.dart';

const Color kDeepPink = Color(0xffb60f68);
const Color kDeepPinkLight = Color(0xFFe70950);
const Color kBackground = Color(0xFFFAFDFF);
const Color kWhite = Colors.white;

const Color kBlack = Colors.black;
const Color kDeepBlue = Color(0xff1D2860);
const Color kDarkBackground = Color(0xFF121212);
const Color kBlackOpaque = Colors.black54;
const double kBorderRadius = 8.0;
const double kGridSpacing = 3.0;

Color backgroundColor = Color(0x00f3f3f3);

const Color commentSheetColor = Colors.white;
const Color contrastCommentCardColor = Colors.black;

const Color contrastCommentColorGradient1 = Colors.white70;
const Color contrastCommentColorGradient2 = Colors.white24;

const Color commentColorGradient1 = Colors.black54;
const Color commentColorGradient2 = Colors.black87;

final Color commentInputBackground = Colors.white;
final Color commentInputBorder = Colors.grey.shade300;
final Color commentTextColor = Colors.black;
final Color hintTextColor = Colors.grey.shade600;
final Color cancelButtonColor = Colors.red;

class TravelAppTheme {
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      primaryColor: kDeepPink,
      scaffoldBackgroundColor: kDarkBackground,
      colorScheme: const ColorScheme.dark(
        primary: kDeepPink,
        secondary: kDeepPinkLight,
        surface: kDarkBackground,
      ),
    );
  }
}
