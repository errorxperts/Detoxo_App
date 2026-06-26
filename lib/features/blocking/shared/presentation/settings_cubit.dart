import 'dart:async';

import 'package:detoxo/features/blocking/plans/domain/entities/sessions.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Owns the user's [AppSettings] and drives the Pause state machine. Every
/// mutation persists locally and pushes the (derived) state to the native
/// engine. While a pause is live a 1 Hz ticker flips the UI/state back to Block
/// All the instant the window ends (native already enforces this via pauseUntil,
/// so the flip survives even if the app is asleep — this just keeps the UI true).
class SettingsCubit extends Cubit<AppSettings> {
  SettingsCubit(this._settings, this._engine) : super(const AppSettings());

  final SettingsRepository _settings;
  final EngineRepository _engine;

  Timer? _ticker;

  Future<void> bootstrap() async {
    final loaded = await _settings.load();
    emit(loaded);
    await _engine.pushSettings(loaded);
    _syncTicker(loaded);
  }

  Future<void> _commit(AppSettings next) async {
    emit(next);
    await _settings.save(next);
    await _engine.pushSettings(next);
    _syncTicker(next);
  }

  /// Switch the active plan. Clears any live pause (the user is choosing a fresh
  /// plan). Entering Conscious resets the native bank (handled engine-side).
  Future<void> setPlan(BlockingPlan plan) =>
      _commit(state.copyWith(activePlan: plan, clearPauseSession: true));

  Future<void> setDefaultBlockMode(BlockingMode mode) =>
      _commit(state.copyWith(defaultBlockMode: mode));

  Future<void> setMasterEnabled({required bool enabled}) =>
      _commit(state.copyWith(masterEnabled: enabled));

  Future<void> setVibration({required bool enabled}) =>
      _commit(state.copyWith(vibrationEnabled: enabled));

  /// Appearance preference. UI-only; pushing to native is harmless (the engine
  /// ignores the field) and keeps a single persistence path.
  Future<void> setThemeMode(AppThemeMode mode) =>
      _commit(state.copyWith(themeMode: mode));

  /// Animated background choice. UI-only (like [setThemeMode]); the native
  /// engine ignores it and persistence flows through the single [_commit] path.
  Future<void> setBackground(AppBackground background) =>
      _commit(state.copyWith(backgroundId: background));

  Future<void> setOnboarded({required bool value}) =>
      _commit(state.copyWith(onboarded: value));

  /// Marks the one-time feature showcase as seen (true) or queues a replay
  /// (false). The Dashboard's coordinator starts the tour on the true→false edge
  /// and writes `true` back once the tour finishes or is dismissed.
  Future<void> setShowcaseSeen({required bool value}) =>
      _commit(state.copyWith(hasSeenFeatureShowcase: value));

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

  /// Start a pause: every app is allowed for the [pause] window, after which
  /// blocking returns immediately as Block All. The plan is set to Block All up
  /// front so when the window lapses (even while the app is dead) the state is
  /// already correct; the live pause is tracked purely by the pause session.
  Future<void> startPause({required Duration pause}) {
    final session = PauseSession(
      startedAt: DateTime.now(),
      pauseDuration: pause,
      cooldownDuration: Duration.zero, // no wind-down: straight to Block All
      planToResume: BlockingPlan.blockAll,
    );
    return _commit(
      state.copyWith(activePlan: BlockingPlan.blockAll, pauseSession: session),
    );
  }

  /// "Resume blocking now" — end the pause immediately and block as Block All.
  Future<void> resumeNow() {
    if (state.pauseSession == null) return Future.value();
    return _commit(
      state.copyWith(
        activePlan: BlockingPlan.blockAll,
        clearPauseSession: true,
      ),
    );
  }

  // ── Conscious ───────────────────────────────────────────────────────────────

  /// Turn on Conscious (earn-as-you-abstain). The native engine starts a fresh,
  /// empty bank; Dart only flips the plan.
  Future<void> enterConscious() => setPlan(BlockingPlan.curious);

  /// Exit Conscious and fall back to Block All.
  Future<void> stopConscious() => setPlan(BlockingPlan.blockAll);

  // ── Pause ticker ────────────────────────────────────────────────────────────

  void _syncTicker(AppSettings s) {
    final live = s.isPauseContractLive();
    if (live && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    } else if (!live && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  Future<void> _onTick() async {
    final s = state;
    // Pause window finished → settle the state to Block All and drop the
    // session. (activePlan is already Block All; this just clears the banner.)
    if (s.pauseSession != null && !s.isPauseContractLive()) {
      await _commit(
        s.copyWith(activePlan: BlockingPlan.blockAll, clearPauseSession: true),
      );
    }
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    return super.close();
  }
}
