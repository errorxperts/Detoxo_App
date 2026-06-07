import 'package:flutter/foundation.dart';

/// Minimal logging facade. Avoids `print` lint and is a single seam where a
/// real logger (or Crashlytics) can be wired later.
abstract final class AppLogger {
  static void d(String message, [String tag = 'Detoxo']) {
    if (kDebugMode) debugPrint('[$tag] $message');
  }

  static void w(String message, [String tag = 'Detoxo']) {
    if (kDebugMode) debugPrint('[$tag][WARN] $message');
  }

  static void e(String message, [Object? error, StackTrace? stack]) {
    if (kDebugMode) {
      debugPrint('[Detoxo][ERROR] $message ${error ?? ''}');
      if (stack != null) debugPrint(stack.toString());
    }
  }
}
