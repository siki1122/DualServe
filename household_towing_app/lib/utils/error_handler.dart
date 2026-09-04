import 'package:flutter/material.dart';
import '../services/logging_service.dart';
import 'package:household_towing_app/utils/app_theme.dart';


/// Centralized error handling and user-friendly error messages
class ErrorHandler {
  /// Get user-friendly error message from exception
  static String getUserMessage(dynamic error) {
    if (error is FirebaseException) {
      return _getFirebaseMessage(error);
    }
    if (error is SocketException) {
      return 'Network connection failed. Please check your internet.';
    }
    if (error is TimeoutException) {
      return 'Request timed out. Please try again.';
    }
    if (error is FormatException) {
      return 'Invalid data format. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  /// Get Firebase-specific error messages
  static String _getFirebaseMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission to perform this action.';
      case 'not-found':
        return 'The requested resource was not found.';
      case 'already-exists':
        return 'This resource already exists.';
      case 'invalid-argument':
        return 'Invalid data provided. Please check your input.';
      case 'unavailable':
        return 'Service is temporarily unavailable. Please try again.';
      case 'unauthenticated':
        return 'Please log in to continue.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  /// Show error snackbar with user-friendly message
  static void showError(BuildContext context, dynamic error, {String? title}) {
    Logger.error(title ?? 'Error', error);

    final message = getUserMessage(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show success snackbar
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.statusCompletedText,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show info snackbar
  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.primaryBlue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Handle and log errors without showing UI
  static void logError(String context, dynamic error) {
    Logger.error('$context: $error', error);
  }
}

/// Alias for Firebase exceptions (if not imported)
class FirebaseException implements Exception {
  final String code;
  final String message;

  FirebaseException({required this.code, required this.message});

  @override
  String toString() => message;
}

/// Socket exception alias
class SocketException implements Exception {
  final String message;
  SocketException(this.message);

  @override
  String toString() => message;
}

/// Timeout exception alias
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
