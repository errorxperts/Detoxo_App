/// Firebase Analytics event and parameter names for Detoxo.
///
/// Centralised so the wire vocabulary lives in one place (no magic strings at
/// call sites) and stays within Firebase's constraints: event/param names must
/// be `[a-zA-Z][a-zA-Z0-9_]*`, at most 40 chars, and must avoid the reserved
/// `firebase_` / `google_` / `ga_` prefixes.
abstract final class AnalyticsEvent {
  static const String planChanged = 'plan_changed';
  static const String blockingToggled = 'blocking_toggled';
  static const String pauseStarted = 'pause_started';
  static const String pauseEnded = 'pause_ended';
  static const String blockTriggered = 'block_triggered';
  static const String reelsCounted = 'reels_counted';
  static const String webBlocked = 'web_blocked';
}

/// Parameter keys for [AnalyticsEvent]s. Firebase only accepts `String` or `num`
/// values — and, by policy, these must never carry PII (no emails, PINs,
/// hostnames or package lists). See the privacy rules in `docs/code_docs`.
abstract final class AnalyticsParam {
  static const String plan = 'plan';
  static const String enabled = 'enabled';
  static const String durationMin = 'duration_min';
  static const String platform = 'platform';
  static const String mode = 'mode';
  static const String count = 'count';
}
