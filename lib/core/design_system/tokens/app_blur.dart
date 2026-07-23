/// BackdropFilter sigma presets. Capped at ~24 — higher = GPU cost with no
/// visual payoff. `none` is the perf fallback for row-level glass in lists.
abstract final class AppBlur {
  static const double none = 0;
  static const double subtle = 8; // list rows (use sparingly)
  static const double card = 16; // standard glass card (crisper frost)
  static const double hero = 18; // dashboard status card
  static const double bar = 20; // app bar / bottom bar
  static const double sheet = 24; // modal sheets
}
