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

class IBMPlexSansText extends StatelessWidget {
  final String text;
  final Color color;
  final bool isBold;
  final double size;
  final bool underlined;
  final bool center;
  final bool italic;

  const IBMPlexSansText({super.key, required this.text, this.color = Colors.black, this.isBold = false, this.size = 16, this.underlined = false, this.center = false, this.italic = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: GoogleFonts.ibmPlexSans(
        color: color,
        fontSize: size,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        decoration: underlined ? TextDecoration.underline : TextDecoration.none,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      ),
    );
  }
}

class LexendText extends StatelessWidget {
  final String text;
  final Color color;
  final bool isBold;
  final double size;
  final bool underlined;
  final bool center;
  final bool italic;

  const LexendText({super.key, required this.text, this.color = Colors.black, this.isBold = false, this.size = 16, this.underlined = false, this.center = false, this.italic = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: GoogleFonts.lexendDeca(
        color: color,
        fontSize: size,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        decoration: underlined ? TextDecoration.underline : TextDecoration.none,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      ),
    );
  }
}

class TypewriterAnimatedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration typingSpeed;

  const TypewriterAnimatedText({
    super.key,
    required this.text,
    this.style,
    this.typingSpeed = const Duration(milliseconds: 80),
  });

  @override
  State<TypewriterAnimatedText> createState() => _TypewriterAnimatedTextState();
}

class _TypewriterAnimatedTextState extends State<TypewriterAnimatedText> {
  String _displayText = '';
  bool _isAnimationComplete = false;
  bool _hasStartedAnimation = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    // Start animation after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) {
        _startAnimation();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _startAnimation() {
    if (_hasStartedAnimation) return;
    _hasStartedAnimation = true;

    // Only run animation once per widget lifecycle
    if (!_isAnimationComplete) {
      _animateText();
    }
  }

  Future<void> _animateText() async {
    // Reset to empty string
    if (_isDisposed) return;

    _safeSetState(() {
      _displayText = '';
    });

    // Animate each character one by one
    for (int i = 0; i < widget.text.length; i++) {
      if (_isDisposed) return; // Check if disposed before delay

      await Future.delayed(widget.typingSpeed);

      if (_isDisposed) return; // Check again after delay

      _safeSetState(() {
        _displayText = widget.text.substring(0, i + 1);
      });
    }

    if (_isDisposed) return;

    _safeSetState(() {
      _isAnimationComplete = true;
    });
  }

  // Helper method to safely call setState
  void _safeSetState(VoidCallback fn) {
    if (mounted && !_isDisposed) {
      setState(fn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayText,
      style: widget.style,
    );
  }
}
