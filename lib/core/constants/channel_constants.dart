/// Names of the platform channels bridging Dart and native Android.
///
/// The native `AccessibilityService` hosts the hot detection/block path; Dart
/// drives configuration and reads a live event/status stream.
abstract final class Channels {
  /// MethodChannel: Dart → native commands (push config, set plan, query
  /// permissions, kill/lock, overlay control).
  static const String commands = 'com.errorxperts.detoxo/commands';

  /// EventChannel: native → Dart stream (service status, detections, foreground
  /// app changes).
  static const String events = 'com.errorxperts.detoxo/events';
}

/// Command method names invoked on [Channels.commands].
abstract final class ChannelMethods {
  // Config / settings push (cross-process persisted on the native side).
  static const String pushConfig = 'pushConfig';
  static const String pushSettings = 'pushSettings';

  // Permission + service status queries.
  static const String isAccessibilityEnabled = 'isAccessibilityEnabled';
  static const String openAccessibilitySettings = 'openAccessibilitySettings';
  static const String canDrawOverlays = 'canDrawOverlays';
  static const String requestOverlayPermission = 'requestOverlayPermission';
  static const String hasUsageAccess = 'hasUsageAccess';
  static const String openUsageAccessSettings = 'openUsageAccessSettings';
  static const String isIgnoringBatteryOptimizations = 'isIgnoringBatteryOptimizations';
  static const String requestIgnoreBatteryOptimizations = 'requestIgnoreBatteryOptimizations';
  static const String isDeviceAdminActive = 'isDeviceAdminActive';
  static const String requestDeviceAdmin = 'requestDeviceAdmin';
  static const String removeDeviceAdmin = 'removeDeviceAdmin';

  // Block actions / overlay (used for testing the engine and PIN/one-reel UI).
  static const String performBack = 'performBack';
  static const String killApp = 'killApp';
  static const String lockScreen = 'lockScreen';
  static const String showOverlay = 'showOverlay';
  static const String hideOverlay = 'hideOverlay';

  // Device / foreground info.
  static const String foregroundPackage = 'foregroundPackage';
  static const String deviceInfo = 'deviceInfo';
  static const String blockStats = 'blockStats';

  // Installed user-launchable apps (drives the install-aware blocklist).
  static const String installedPackages = 'installedPackages';

  // Conscious (earn-as-you-abstain) bank snapshot.
  static const String consciousState = 'consciousState';
}

/// Event `type` values streamed over [Channels.events].
abstract final class ChannelEvents {
  static const String serviceStatus = 'serviceStatus';
  static const String detection = 'detection';
  static const String blocked = 'blocked';
  static const String foregroundChanged = 'foregroundChanged';

  /// Live Conscious bank update (bankMs / maxBankMs / watching / blocked).
  static const String consciousState = 'consciousState';
}
