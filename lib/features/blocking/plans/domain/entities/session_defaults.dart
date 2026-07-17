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

  // ── Unblock (allow N reels, then revert to the base mode) ──────────────────
  // Circular count slider: 2–20 reels in steps of 1. One Reel is the count-1
  // special case and needs no picker (it arms directly).
  static const int unblockSliderMin = 2;
  static const int unblockSliderMax = 20;
  static const int unblockSliderStep = 1;
  static const int unblockDefault = 5;

  /// Snaps an arbitrary slider value to the nearest whole reel count, clamped to
  /// the [unblockSliderMin]..[unblockSliderMax] range.
  static int snapUnblockCount(double value) =>
      value.round().clamp(unblockSliderMin, unblockSliderMax);

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
