import 'package:flutter/material.dart';
import 'package:flutter_sliding_toast/flutter_sliding_toast.dart';
import 'package:travia/Helpers/GoogleTexts.dart';

class Popup {
  static void showPopUp({
    required String text,
    required BuildContext context,
    Color? color,
    IconData? icon,
    int duration = 3,
    PopupType type = PopupType.info,
  }) {
    // Enhanced color scheme based on type
    Color backgroundColor = _getBackgroundColor(type, color);
    Color textColor = _getTextColor(backgroundColor);
    IconData displayIcon = icon ?? _getDefaultIcon(type);

    InteractiveToast.slide(
      context,
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated icon with subtle glow
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                displayIcon,
                color: textColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Enhanced text with better typography
            Expanded(
              child: RedHatText(
                text: text,
                size: 15,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
      toastStyle: ToastStyle(
        titleLeadingGap: 16,
        backgroundColor: backgroundColor,
        progressBarColor: textColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        // Add shadow for depth
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      toastSetting: SlidingToastSetting(
        maxHeight: 18,
        maxWidth: 90,
        animationDuration: const Duration(milliseconds: 600),
        displayDuration: Duration(seconds: duration),
        // Enhanced animation curve
        curve: Curves.elasticOut,
      ),
    );
  }

  // Success toast with green theme
  static void showSuccess({
    required String text,
    required BuildContext context,
    int duration = 3,
  }) {
    showPopUp(
      text: text,
      context: context,
      type: PopupType.success,
      duration: duration,
    );
  }

  // Error toast with red theme
  static void showError({
    required String text,
    required BuildContext context,
    int duration = 4,
  }) {
    showPopUp(
      text: text,
      context: context,
      type: PopupType.error,
      duration: duration,
    );
  }

  // Warning toast with amber theme
  static void showWarning({
    required String text,
    required BuildContext context,
    int duration = 3,
  }) {
    showPopUp(
      text: text,
      context: context,
      type: PopupType.warning,
      duration: duration,
    );
  }

  // Info toast with blue theme
  static void showInfo({
    required String text,
    required BuildContext context,
    int duration = 3,
  }) {
    showPopUp(
      text: text,
      context: context,
      type: PopupType.info,
      duration: duration,
    );
  }

  // Private helper methods
  static Color _getBackgroundColor(PopupType type, Color? customColor) {
    if (customColor != null) return customColor;

    switch (type) {
      case PopupType.success:
        return const Color(0xFF10B981); // Emerald green
      case PopupType.error:
        return const Color(0xFFEF4444); // Red
      case PopupType.warning:
        return const Color(0xFFF59E0B); // Amber
      case PopupType.info:
        return const Color(0xFF3B82F6); // Blue
    }
  }

  static Color _getTextColor(Color backgroundColor) {
    // Calculate luminance to determine if text should be light or dark
    double luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  static IconData _getDefaultIcon(PopupType type) {
    switch (type) {
      case PopupType.success:
        return Icons.check_circle_outline;
      case PopupType.error:
        return Icons.error_outline;
      case PopupType.warning:
        return Icons.warning_amber_outlined;
      case PopupType.info:
        return Icons.info_outline;
    }
  }
}

// Enum for different popup types
enum PopupType {
  success,
  error,
  warning,
  info,
}
