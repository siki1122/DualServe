import 'package:flutter/foundation.dart';

/// Logging service for structured application logging
/// Replaces ad-hoc print() statements with configurable levels
class Logger {
  static const String _prefix = '[DUALSERVE]';

  /// Debug level logging (only in development)
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toString().split('.')[0];
      print('$_prefix [$timestamp] DEBUG: $message');
      if (error != null) {
        print('$_prefix Error: $error');
      }
      if (stackTrace != null) {
        print('$_prefix Stack: $stackTrace');
      }
    }
  }

  /// Info level logging
  static void info(String message) {
    final timestamp = DateTime.now().toString().split('.')[0];
    print('$_prefix [$timestamp] INFO: $message');
  }

  /// Warning level logging
  static void warn(String message, [dynamic error]) {
    final timestamp = DateTime.now().toString().split('.')[0];
    print('$_prefix [$timestamp] WARN: $message');
    if (error != null) {
      print('$_prefix Error: $error');
    }
  }

  /// Error level logging
  static void error(String message, dynamic error, [StackTrace? stackTrace]) {
    final timestamp = DateTime.now().toString().split('.')[0];
    print('$_prefix [$timestamp] ERROR: $message');
    print('$_prefix Exception: $error');
    if (stackTrace != null) {
      print('$_prefix Stack: $stackTrace');
    }
  }
}
