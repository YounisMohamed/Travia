import 'package:flutter/material.dart';
import 'package:flutter_sliding_toast/flutter_sliding_toast.dart';

class Popup {
  static void showPopUp({required String text, required BuildContext context, Color? color, int duration = 3}) {
    InteractiveToast.pop(
      context,
      title: Text(text),
      toastStyle: ToastStyle(
        titleLeadingGap: 10,
        backgroundColor: color ?? Colors.orangeAccent,
        progressBarColor: Colors.grey[500],
      ),
      toastSetting: PopupToastSetting(
        animationDuration: Duration(seconds: 1),
        displayDuration: Duration(seconds: duration),
        toastAlignment: Alignment.bottomCenter,
      ),
    );
  }
}
