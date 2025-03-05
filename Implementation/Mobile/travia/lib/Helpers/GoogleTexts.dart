import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RedHatText extends StatelessWidget {
  final String text;
  final Color color;
  final bool isBold;
  final double size;
  final bool underlined;
  final bool center;
  final bool italic;

  const RedHatText({super.key, required this.text, this.color = Colors.black, this.isBold = false, this.size = 16, this.underlined = false, this.center = false, this.italic = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: GoogleFonts.redHatDisplay(
        color: color,
        fontSize: size,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        decoration: underlined ? TextDecoration.underline : TextDecoration.none,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      ),
    );
  }
}

class MontserratText extends StatelessWidget {
  final String text;
  final Color color;
  final bool isBold;
  final double size;
  final bool underlined;
  final bool center;
  final bool italic;

  const MontserratText({super.key, required this.text, this.color = Colors.black, this.isBold = false, this.size = 16, this.underlined = false, this.center = false, this.italic = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: GoogleFonts.montserrat(
        color: color,
        fontSize: size,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        decoration: underlined ? TextDecoration.underline : TextDecoration.none,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      ),
    );
  }
}

class RalewayText extends StatelessWidget {
  final String text;
  final Color color;
  final bool isBold;
  final double size;
  final bool underlined;
  final bool center;
  final bool italic;

  const RalewayText({super.key, required this.text, this.color = Colors.black, this.isBold = false, this.size = 16, this.underlined = false, this.center = false, this.italic = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: GoogleFonts.raleway(
        color: color,
        fontSize: size,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        decoration: underlined ? TextDecoration.underline : TextDecoration.none,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      ),
    );
  }
}
