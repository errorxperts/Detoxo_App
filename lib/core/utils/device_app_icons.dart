import 'package:flutter/foundation.dart';

/// The phone's own app icons (PNG bytes) by package name, from the native
/// engine's installed-app scan. `EngineRepositoryImpl.installedApps` replaces
/// it on every scan that lands (the bootstrap starts the first one), and
/// `AppIconAvatar` listens, so a row drawn before the scan updates in place.
/// Empty until then, or when the scan fails: rows show their letter tile.
final ValueNotifier<Map<String, Uint8List>> deviceAppIcons = ValueNotifier(
  const {},
);
