// Verified defaults & UI options for Pause / Curious sessions.
// Sources: PauseSessionData (pause 60s, lockDown ≈60s, maxPauseDuration 15min),
// CuriousSessionData (session 5min, cooldown 5min). Kept in one place so the
// pickers and the cubit agree.
abstract final class SessionDefaults {
  // ── Pause ────────────────────────────────────────────────────────────────
  static const Duration pauseDuration = Duration(minutes: 1);

  /// Mandatory cooldown ("lockdown") after the allowed window. Always > 0 so the
  /// PAUSED_COOLDOWN phase is real (the chosen product behaviour).
  static const Duration pauseCooldown = Duration(minutes: 1);

  /// Server-tunable cap on selectable pause minutes.
  static const int maxPauseMinutes = 15;

  /// Pause minutes offered by the picker (filtered to <= [maxPauseMinutes]).
  static const List<int> pauseMinuteOptions = [5, 10, 15, 30];

  // ── Curious (pomodoro) ─────────────────────────────────────────────────────
  static const Duration curiousSession = Duration(minutes: 5);
  static const Duration curiousCooldown = Duration(minutes: 5);

  static const List<int> curiousSessionMinuteOptions = [5, 15, 25];
  static const List<int> curiousCooldownMinuteOptions = [5, 10, 15];

  /// Pause minutes the picker should actually show (cap applied).
  static List<int> get pauseOptions =>
      pauseMinuteOptions.where((m) => m <= maxPauseMinutes).toList();
}
