import 'package:flutter/material.dart';
import 'package:task_check/core/errors/app_exception.dart';

/// Centralized error handling and user notification utilities
class ErrorHandler {
  /// Converts an error into a user-friendly Spanish message
  static String getErrorMessage(dynamic error) {
    if (error is AppException) {
      return error.message;
    }
    if (error is String) {
      return error;
    }
    return 'Ocurrió un error inesperado: ${error?.toString() ?? "desconocido"}';
  }

  /// Displays an error banner SnackBar in the current Scaffold
  static void showErrorSnackBar(BuildContext context, dynamic error) {
    if (!context.mounted) return;

    final message = getErrorMessage(error);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Displays a success banner SnackBar in the current Scaffold
  static void showSuccessSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
