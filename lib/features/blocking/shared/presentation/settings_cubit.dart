import 'dart:async';

import 'package:detoxo/features/blocking/plans/domain/entities/session_defaults.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/sessions.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Owns the user's [AppSettings] and drives the Pause / Curious state machines.
/// Every mutation persists locally and pushes the (derived) state to the native
/// engine. While a session contract is live a 1 Hz ticker auto-advances phases
/// (cooldown → idle resume, curious loop) and re-pushes when enforcement flips.
class SettingsCubit extends Cubit<AppSettings> {
  SettingsCubit(this._settings, this._engine) : super(const AppSettings());

  final SettingsRepository _settings;
  final EngineRepository _engine;

  Timer? _ticker;
  BlockingPlan? _lastPushedNativePlan;
  int _lastPushedPauseUntilMs = 0;

  Future<void> bootstrap() async {
    final loaded = await _settings.load();
    emit(loaded);
    await _engine.pushSettings(loaded);
    _rememberPushed(loaded);
    _syncTicker(loaded);
  }

  Future<void> _commit(AppSettings next) async {
    emit(next);
    await _settings.save(next);
    await _engine.pushSettings(next);
    _rememberPushed(next);
    _syncTicker(next);
  }

  /// Snapshot what we just pushed so the ticker only re-pushes on real changes.
  void _rememberPushed(AppSettings s) {
    _lastPushedNativePlan = s.effectiveNativePlan();
    _lastPushedPauseUntilMs = s.nativePauseUntil()?.millisecondsSinceEpoch ?? 0;
  }

  /// Switch the active plan. Ignored while a curious cooldown locks the
  /// switcher; clears any live session (the user is choosing a fresh plan).
  Future<void> setPlan(BlockingPlan plan) {
    if (!state.switcherEnabled()) return Future.value();
    return _commit(state.copyWith(
      activePlan: plan,
      clearPauseSession: true,
      clearCuriousSession: true,
    ));
  }

  Future<void> setDefaultBlockMode(BlockingMode mode) =>
      _commit(state.copyWith(defaultBlockMode: mode));

  Future<void> setMasterEnabled({required bool enabled}) =>
      _commit(state.copyWith(masterEnabled: enabled));

  Future<void> setVibration({required bool enabled}) =>
      _commit(state.copyWith(vibrationEnabled: enabled));

  Future<void> setOnboarded({required bool value}) =>
      _commit(state.copyWith(onboarded: value));

  Future<void> togglePlatform(String platformId, {required bool enabled}) {
    final next = Set<String>.from(state.enabledPlatformIds);
    if (enabled) {
      next.add(platformId);
    } else {
      next.remove(platformId);
    }
    return _commit(state.copyWith(enabledPlatformIds: next));
  }

  Future<void> setEnabledPlatforms(Set<String> ids) =>
      _commit(state.copyWith(enabledPlatformIds: ids));

  // ── Pause ──────────────────────────────────────────────────────────────────

  /// Start a pause contract: an allowed [pause] window, then a mandatory
  /// [cooldown] lockdown, then resume [resumeTo] (defaults to the current plan).
  Future<void> startPause({
    required Duration pause,
    Duration cooldown = SessionDefaults.pauseCooldown,
    BlockingPlan? resumeTo,
    bool allowInCooldown = true, // wind-down still allows content (spec default)
  }) {
    final resume = resumeTo ?? _planToResume();
    final session = PauseSession(
      startedAt: DateTime.now(),
      pauseDuration: pause,
      cooldownDuration: cooldown,
      // Verified invariant: planToResume can never be `paused`.
      planToResume: resume == BlockingPlan.paused ? BlockingPlan.blockAll : resume,
      allowInCooldown: allowInCooldown,
    );
    return _commit(state.copyWith(
      activePlan: BlockingPlan.paused,
      pauseSession: session,
      clearCuriousSession: true,
    ));
  }

  /// "Resume blocking now" — end the whole contract immediately and resume the
  /// underlying plan. (The cooldown still allows content, so resuming early
  /// means blocking right away rather than waiting out the wind-down.)
  Future<void> resumeNow() {
    final ps = state.pauseSession;
    if (ps == null) return Future.value();
    return _commit(state.copyWith(
      activePlan: ps.planToResume,
      clearPauseSession: true,
    ));
  }

  // ── Curious (pomodoro) ──────────────────────────────────────────────────────

  Future<void> startCurious({
    Duration session = SessionDefaults.curiousSession,
    Duration cooldown = SessionDefaults.curiousCooldown,
    bool allowInCooldown = false,
    bool disablePlanSwitchInCooldown = false,
  }) {
    final cs = CuriousSession(
      startedAt: DateTime.now(),
      sessionDuration: session,
      cooldownDuration: cooldown,
      allowInCooldown: allowInCooldown,
      disablePlanSwitchInCooldown: disablePlanSwitchInCooldown,
    );
    return _commit(state.copyWith(
      activePlan: BlockingPlan.curious,
      curiousSession: cs,
      clearPauseSession: true,
    ));
  }

  /// "End session" — collapse the watch window so the contract moves straight
  /// into the cooldown (the pomodoro loop continues afterwards).
  Future<void> endCuriousSessionEarly() {
    final s = state.curiousSession;
    if (s == null) return Future.value();
    final now = DateTime.now();
    if (!now.isBefore(s.sessionEnd)) return Future.value();
    final elapsed = now.difference(s.startedAt);
    return _commit(state.copyWith(
      curiousSession: CuriousSession(
        startedAt: s.startedAt,
        sessionDuration: elapsed.isNegative ? Duration.zero : elapsed,
        cooldownDuration: s.cooldownDuration,
        allowInCooldown: s.allowInCooldown,
        disablePlanSwitchInCooldown: s.disablePlanSwitchInCooldown,
      ),
    ));
  }

  /// Exit the curious loop and fall back to Block-All.
  Future<void> stopCurious() => _commit(state.copyWith(
        activePlan: BlockingPlan.blockAll,
        clearCuriousSession: true,
      ));

  /// The underlying plan a pause should resume into (never `paused`).
  BlockingPlan _planToResume() {
    final cur = state.activePlan;
    if (cur == BlockingPlan.paused) {
      return state.pauseSession?.planToResume ?? BlockingPlan.blockAll;
    }
    return cur;
  }

  // ── Session ticker ──────────────────────────────────────────────────────────

  void _syncTicker(AppSettings s) {
    final live = s.isPauseContractLive() || s.isCuriousContractLive();
    if (live && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    } else if (!live && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  Future<void> _onTick() async {
    final now = DateTime.now();
    final s = state;

    // Pause contract finished → resume the underlying plan.
    if (s.pauseSession != null && s.pausePhase(now) == SessionPhase.idle) {
      await _commit(s.copyWith(
        activePlan: s.pauseSession!.planToResume,
        clearPauseSession: true,
      ));
      return;
    }

    // Curious idle → loop a fresh pomodoro session with the same config.
    if (s.curiousSession != null && s.curiousPhase(now) == SessionPhase.idle) {
      final prev = s.curiousSession!;
      await _commit(s.copyWith(
        curiousSession: CuriousSession(
          startedAt: now,
          sessionDuration: prev.sessionDuration,
          cooldownDuration: prev.cooldownDuration,
          allowInCooldown: prev.allowInCooldown,
          disablePlanSwitchInCooldown: prev.disablePlanSwitchInCooldown,
        ),
      ));
      return;
    }

    // Enforcement flipped (e.g. allowed window → un-allowed cooldown, or curious
    // session → Block-All). The plan and/or the suspension window changes but
    // AppSettings itself doesn't, so push directly without emitting.
    final effective = s.effectiveNativePlan(now);
    final pauseUntilMs = s.nativePauseUntil(now)?.millisecondsSinceEpoch ?? 0;
    if (effective != _lastPushedNativePlan ||
        pauseUntilMs != _lastPushedPauseUntilMs) {
      _lastPushedNativePlan = effective;
      _lastPushedPauseUntilMs = pauseUntilMs;
      await _engine.pushSettings(s);
    }
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    return super.close();
  }
}
