import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Single source of truth for the iOS-vs-Material rendering branch.
///
/// `cupertino_native` ships a plugin only on iOS/macOS; on every other target
/// its platform views would fail. Adaptive controls render native `CN*` widgets
/// only when [useCupertino] is true, and hand-built Material widgets otherwise.
/// Flip this one getter to kill native rendering everywhere.
abstract final class PlatformAdaptive {
  /// Forces the branch in tests. Widget tests otherwise follow the *host* OS,
  /// so an adaptive widget would take the Material path on Linux CI and the
  /// Cupertino path on a Mac. Reset to `null` in `tearDown`.
  @visibleForTesting
  static bool? debugUseCupertino;

  static bool get useCupertino {
    if (debugUseCupertino != null) return debugUseCupertino!;
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isMacOS;
  }
}
