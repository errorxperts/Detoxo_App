import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Single source of truth for the iOS-vs-Material rendering branch.
///
/// `cupertino_native` ships a plugin only on iOS/macOS; on every other target
/// its platform views would fail. Adaptive controls render native `CN*` widgets
/// only when [useCupertino] is true, and hand-built Material widgets otherwise.
/// Flip this one getter to kill native rendering everywhere.
abstract final class PlatformAdaptive {
  static bool get useCupertino {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isMacOS;
  }
}
