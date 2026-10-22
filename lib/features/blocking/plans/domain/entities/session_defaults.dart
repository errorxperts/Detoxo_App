// Verified defaults & UI options for the Pause / Conscious modes. Kept in one
// place so the pickers, the cubit, and the native push agree.
abstract final class SessionDefaults {
  // ── Pause ────────────────────────────────────────────────────────────────
  // A Pause allows every app for the chosen window, then blocking returns
  // immediately as Block All (no wind-down).
  static const Duration pauseDuration = Duration(minutes: 1);

  /// Server-tunable cap on selectable pause minutes.
  static const int maxPauseMinutes = 10;

  // The Session sheet "By time": a dial over 1–10 whole minutes, plus
  // [pausePicks] as one-tap presets. [pauseDefaultMinutes] is where it opens.
  static const int pauseMin = 1;
  static const int pauseMax = maxPauseMinutes;
  static const int pauseDefaultMinutes = 5;
  static const List<int> pausePicks = [1, 3, 5, 10];

  // ── Unblock (allow N reels, then revert to the base mode) ──────────────────
  // The Session sheet "By reel count": a −/+ stepper over 1–20 reels (native
  // clamps the allowance to 1..20), plus [unblockPicks] as one-tap presets.
  // One Reel is the count-1 session armed from the ModeCard without a picker.
  static const int unblockMin = 1;
  static const int unblockMax = 20;
  static const int unblockDefault = 10;
  static const List<int> unblockPicks = [5, 10, 15, 20];

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
