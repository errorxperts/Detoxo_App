// Verified defaults & UI options for the Pause / Conscious modes. Kept in one
// place so the pickers, the cubit, and the native push agree.
abstract final class SessionDefaults {
  // ── Pause ────────────────────────────────────────────────────────────────
  // A Pause allows every app for the chosen window, then blocking returns
  // immediately as Block All (no wind-down).
  static const Duration pauseDuration = Duration(minutes: 1);

  /// Server-tunable cap on selectable pause minutes.
  static const int maxPauseMinutes = 10;

  // Circular pause-duration slider: 2–10 min in 2-min steps (snaps to
  // 2/4/6/8/10). [pauseDefaultMinutes] is the value the slider opens on.
  static const int pauseSliderMin = 2;
  static const int pauseSliderMax = maxPauseMinutes;
  static const int pauseSliderStep = 2;
  static const int pauseDefaultMinutes = 4;

  /// Snaps an arbitrary slider value to the nearest [pauseSliderStep] minute,
  /// clamped to the [pauseSliderMin]..[pauseSliderMax] range.
  static int snapPauseMinutes(double value) {
    final stepped = (value / pauseSliderStep).round() * pauseSliderStep;
    return stepped.clamp(pauseSliderMin, pauseSliderMax);
  }

  // ── Conscious (earn-as-you-abstain token bucket) ───────────────────────────
  // While abstaining the bank fills at 1 / [consciousEarnDivisor] of elapsed
  // time (10 → +1 min per 10 min); while watching it drains 1:1. Capped at
  // [consciousMaxBank]. The running balance lives natively so it survives the
  // UI being killed.
  static const int consciousEarnDivisor = 10;
  static const Duration consciousMaxBank = Duration(minutes: 10);

  /// Human-readable earn rate, e.g. "1 min every 10 min".
  static String get consciousEarnLabel =>
      '1 min every $consciousEarnDivisor min';
}
