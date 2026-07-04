import 'package:flutter/foundation.dart';

/// Minimal logging facade. Avoids `print` lint and is a single seam where a
/// real logger (or Crashlytics) can be wired later.
abstract final class AppLogger {
  /// Optional sink for error reports, wired to Crashlytics at startup (see
  /// `FirebaseServices.start`). A bare callback so this core utility keeps no
  /// dependency on Firebase; null until wired (and in tests).
  static void Function(String message, Object? error, StackTrace? stack)?
      onError;

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
    onError?.call(message, error, stack);
  }
}
