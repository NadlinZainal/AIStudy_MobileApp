import 'package:flutter/material.dart';

enum SnackBarType { success, error, info }

class CustomSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    SnackBarType type = SnackBarType.info,
    IconData? icon,
  }) {
    final IconData defaultIcon;
    final Color backgroundColor;

    switch (type) {
      case SnackBarType.success:
        defaultIcon = Icons.check_circle_outline;
        backgroundColor = const Color(0xFF11998E);
        break;
      case SnackBarType.error:
        defaultIcon = Icons.error_outline;
        backgroundColor = const Color(0xFFFF416C);
        break;
      case SnackBarType.info:
        defaultIcon = Icons.info_outline;
        backgroundColor = const Color(0xFF8E2DE2);
        break;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Icon(icon ?? defaultIcon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.25,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        elevation: 8,
        duration: const Duration(seconds: 3),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    );
  }
}
