/// App-wide identity and asset constants.
///
/// Keep environment-specific values (API base URL, ad unit ids, billing
/// product ids, Firebase) in [core/config] so they can be swapped without
/// touching feature code.
abstract final class AppConstants {
  static const String appName = 'Detoxo';
  static const String packageName = 'com.errorxperts.detoxo';

  /// User-facing version string. Mirrors the `version` field in pubspec.yaml
  /// (build-name only) — bump both together.
  static const String appVersion = '1.0.0';

  // Bundled offline config (fallback when the network/remote config is absent).
  static const String bundledPlatformsConfig = 'assets/config/platforms_config.json';
  static const String bundledInitialConfig = 'assets/config/initial_config.json';

  // Bundled dynamic content (quotes / emoji bands).
  static const String mindfulQuotes = 'assets/content/mindful_timer_quotes.json';
  static const String pauseEmojis = 'assets/content/pause_emojis.json';
  static const String pauseCountdownEmojis = 'assets/content/pause_countdown_pause_emojis.json';
  static const String cooldownEmojis = 'assets/content/pause_countdown_cooldown_emojis.json';
  static const String curiousEmojis = 'assets/content/curious_emojis.json';
  static const String dailyLimitEmojiBands = 'assets/content/daily_limit_emoji_bands.json';
}

/// Support & feedback contact points. The single source of truth for where user
/// feedback and support requests are routed.
abstract final class AppSupport {
  /// Inbox that receives in-app feedback (see the `app_feedback` feature).
  static const String supportEmail = 'errorxperts@gmail.com';

  /// Support phone number (digits only, no country code / formatting).
  static const String supportPhone = '9528293795';

  /// Prefix for the feedback email subject line; the category & rating are
  /// appended by the sender.
  static const String feedbackSubjectPrefix = 'Detoxo Feedback';
}

/// Timing constants for the detection / block engine.
///
/// Values are mirrored on the native side (the hot path runs in Kotlin); these
/// Dart copies drive UI affordances and any Dart-side policy decisions.
/// Source-verified against the original AccessibilityService.
abstract final class EngineTimings {
  /// Per-package event throttle.
  static const Duration eventThrottle = Duration(milliseconds: 150);

  /// Minimum gap between two block actions (debounce).
  static const Duration blockDebounce = Duration(milliseconds: 1200);

  /// Extra rate-limit specifically for simulated Back presses.
  static const Duration backRateLimit = Duration(milliseconds: 1100);

  /// One-reel overlay grace + poll interval.
  static const Duration oneReelOverlayGrace = Duration(milliseconds: 500);
  static const Duration oneReelOverlayPoll = Duration(milliseconds: 500);

  /// Hard-block grace window after a kill/lock action.
  static const Duration hardBlockGrace = Duration(seconds: 10);

  /// Max nodes to walk in a deep view-tree search.
  static const int maxNodeTraversal = 12000;
}
