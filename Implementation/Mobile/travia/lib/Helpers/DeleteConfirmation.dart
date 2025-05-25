import 'package:flutter/material.dart';
import 'package:material_dialogs/dialogs.dart';
import 'package:material_dialogs/widgets/buttons/icon_button.dart';
import 'package:material_dialogs/widgets/buttons/icon_outline_button.dart';

import 'AppColors.dart'; // Import your app's colors

Future<void> showCustomDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String actionText,
  required IconData actionIcon,
  required Future<void> Function() onActionPressed,
  String cancelText = 'Cancel',
  IconData cancelIcon = Icons.cancel_outlined,
  Color actionColor = kDeepPink,
  Color dialogColor = kWhite,
  bool isDismissible = true,
}) async {
  return Dialogs.bottomMaterialDialog(
    msg: message,
    title: title,
    color: dialogColor,
    context: context,
    isDismissible: isDismissible,
    actions: [
      IconsOutlineButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        text: cancelText,
        iconData: cancelIcon,
        textStyle: const TextStyle(color: Colors.grey),
        iconColor: Colors.grey,
      ),
      IconsButton(
        onPressed: () async {
          try {
            await onActionPressed();
          } finally {
            if (context.mounted) {
              Navigator.pop(context);
            }
          }
        },
        text: actionText,
        iconData: actionIcon,
        color: actionColor,
        textStyle: const TextStyle(color: kWhite), // Updated to use app theme color
        iconColor: kWhite, // Updated to use app theme color
      ),
    ],
  );
}

Future<void> showCustomDialogWithMultipleActions({
  required BuildContext context,
  required String title,
  required String message,
  required List<DialogAction> actions,
  Color dialogColor = kWhite,
  bool isDismissible = true,
}) async {
  final actionButtons = <Widget>[];

  // Add cancel button
  actionButtons.add(
    IconsOutlineButton(
      onPressed: () {
        Navigator.of(context).pop();
      },
      text: 'Cancel',
      iconData: Icons.cancel_outlined,
      textStyle: const TextStyle(color: Colors.grey),
      iconColor: Colors.grey,
    ),
  );

  // Add all action buttons
  for (final action in actions) {
    actionButtons.add(
      IconsButton(
        onPressed: () async {
          try {
            await action.onPressed();
          } finally {
            if (context.mounted) {
              Navigator.pop(context);
            }
          }
        },
        text: action.text,
        iconData: action.icon,
        color: action.color,
        textStyle: const TextStyle(color: kWhite), // Updated to use app theme color
        iconColor: kWhite, // Updated to use app theme color
      ),
    );
  }

  return Dialogs.bottomMaterialDialog(
    msg: message,
    title: title,
    color: dialogColor,
    context: context,
    isDismissible: isDismissible,
    actions: actionButtons,
  );
}

class DialogAction {
  final String text;
  final IconData icon;
  final Future<void> Function() onPressed;
  final Color color;

  DialogAction({
    required this.text,
    required this.icon,
    required this.onPressed,
    this.color = kDeepPink,
  });
}

Future<void> showDeleteConfirmationDialog({
  required BuildContext context,
  String title = 'Delete',
  required String message,
  String actionText = 'Delete',
  required Future<void> Function() onDeletePressed,
}) async {
  return showCustomDialog(
    context: context,
    title: title,
    message: message,
    actionText: actionText,
    actionIcon: Icons.delete,
    onActionPressed: onDeletePressed,
    actionColor: Colors.red,
  );
}
