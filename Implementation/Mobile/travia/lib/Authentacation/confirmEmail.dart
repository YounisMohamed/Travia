import 'package:flutter/material.dart';
import 'package:travia/Helpers/PoppinsText.dart';

class Confirmemail extends StatelessWidget {
  const Confirmemail({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: PoppinsText(text: "Your email is successfully confirmed!"),
      ),
    );
  }
}
