import 'package:flutter/material.dart';
import 'package:travia/Helpers/DefaultText.dart';

class Confirmemail extends StatelessWidget {
  const Confirmemail({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: DefaultText(text: "Your email is successfully confirmed!"),
      ),
    );
  }
}
