import 'package:flutter/material.dart';
import 'package:flutter_sliding_toast/flutter_sliding_toast.dart';

class Popup {
  static void showPopUp({required String text, required BuildContext context, Color? color}) {
    InteractiveToast.slide(
      context,
      title: Text(text),
      toastStyle: ToastStyle(
        titleLeadingGap: 10,
        backgroundColor: color ?? Colors.orangeAccent,
        progressBarColor: Colors.grey[500],
      ),
      toastSetting: SlidingToastSetting(
        animationDuration: Duration(seconds: 1),
        displayDuration: Duration(seconds: 3),
        toastAlignment: Alignment.bottomCenter,
      ),
    );
  }
}
