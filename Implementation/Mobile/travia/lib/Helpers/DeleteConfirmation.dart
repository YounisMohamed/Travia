import 'package:flutter/material.dart';
import 'package:material_dialogs/dialogs.dart';
import 'package:material_dialogs/widgets/buttons/icon_button.dart';
import 'package:material_dialogs/widgets/buttons/icon_outline_button.dart';

import 'AppColors.dart'; // Import your app's colors

/// A reusable dialog function that creates a bottom material dialog with customizable actions.
///
/// The dialog includes a title, message, and two buttons - a cancel button and an action button.
/// The action button can be customized with different colors, icons, and text.
///
/// Parameters:
/// - `context`: Required. The BuildContext for showing the dialog.
/// - `title`: Required. The title of the dialog.
/// - `message`: Required. The message content of the dialog.
/// - `actionText`: Required. The text for the action button.
/// - `actionIcon`: Required. The icon for the action button.
/// - `onActionPressed`: Required. The callback when the action button is pressed.
/// - `cancelText`: Optional. The text for the cancel button. Defaults to 'Cancel'.
/// - `cancelIcon`: Optional. The icon for the cancel button. Defaults to Icons.cancel_outlined.
/// - `actionColor`: Optional. The background color of the action button. Defaults to kDeepPurple.
/// - `dialogColor`: Optional. The background color of the dialog. Defaults to kWhite.
/// - `isDismissible`: Optional. Whether the dialog can be dismissed by tapping outside. Defaults to true.
Future<void> showCustomDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String actionText,
  required IconData actionIcon,
  required Future<void> Function() onActionPressed,
  String cancelText = 'Cancel',
  IconData cancelIcon = Icons.cancel_outlined,
  Color actionColor = kDeepPurple, // Updated to use app theme color
  Color dialogColor = kWhite, // Updated to use app theme color
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

/// A variant of showCustomDialog that allows multiple action buttons.
///
/// Parameters:
/// - `context`: Required. The BuildContext for showing the dialog.
/// - `title`: Required. The title of the dialog.
/// - `message`: Required. The message content of the dialog.
/// - `actions`: Required. List of DialogAction objects representing action buttons.
/// - `dialogColor`: Optional. The background color of the dialog. Defaults to kWhite.
/// - `isDismissible`: Optional. Whether the dialog can be dismissed by tapping outside. Defaults to true.
Future<void> showCustomDialogWithMultipleActions({
  required BuildContext context,
  required String title,
  required String message,
  required List<DialogAction> actions,
  Color dialogColor = kWhite, // Updated to use app theme color
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

/// Represents an action button in the custom dialog.
///
/// Parameters:
/// - `text`: Required. The text to display on the button.
/// - `icon`: Required. The icon to display on the button.
/// - `onPressed`: Required. The callback when the button is pressed.
/// - `color`: Optional. The background color of the button. Defaults to kDeepPurple.
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

/// A specialized method for showing delete confirmation dialogs.
///
/// This is a convenience wrapper around showCustomDialog that
/// pre-configures the dialog with delete-specific styling.
///
/// Parameters:
/// - `context`: Required. The BuildContext for showing the dialog.
/// - `title`: Optional. The title of the dialog. Defaults to 'Delete'.
/// - `message`: Required. The message content of the dialog.
/// - `actionText`: Optional. The text for the delete button. Defaults to 'Delete'.
/// - `onDeletePressed`: Required. The callback when the delete button is pressed.
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
