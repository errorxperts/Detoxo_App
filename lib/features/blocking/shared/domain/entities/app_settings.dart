import 'package:detoxo/features/blocking/plans/domain/entities/sessions.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:equatable/equatable.dart';

/// The user's blocking configuration. This is the single object Dart persists
/// locally and pushes to the native engine; the service reads from it.
///
/// Pause is modelled as a live [PauseSession]: an allowed window after which
/// blocking resumes as Block All. `activePlan` holds the *enforced* plan
/// (Block All / Conscious / One Reel); while a pause is live we *derive* what we
/// push to native — see [effectiveNativePlan] / [nativePauseUntil] — so the
/// verified phase math drives enforcement over the existing channel.
///
/// Conscious (the `curious` plan) is enforced natively as an earn-as-you-abstain
/// token bucket; Dart holds no live session for it — the running bank lives in
/// the engine so it survives the UI being killed.
class AppSettings extends Equatable {
  const AppSettings({
    this.activePlan = BlockingPlan.blockAll,
    this.defaultBlockMode = BlockingMode.pressBack,
    this.enabledPlatformIds = const {},
    this.vibrationEnabled = true,
    this.masterEnabled = true,
    this.pauseSession,
    this.onboarded = false,
    this.themeMode = AppThemeMode.dark,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    // Legacy migration: the old model stored `paused` as the active plan while a
    // pause ran. The new model keeps activePlan = Block All and tracks the live
    // pause purely via [pauseSession], so collapse any persisted `paused` to
    // Block All — otherwise an upgrade killed mid-pause would surface a phantom
    // "Paused" plan forever (no live window to clear it).
    final plan = BlockingPlan.fromWire(json['activePlan'] as String?);
    return AppSettings(
      activePlan: plan == BlockingPlan.paused ? BlockingPlan.blockAll : plan,
      defaultBlockMode: BlockingMode.fromWire(
        json['defaultBlockMode'] as String?,
      ),
      enabledPlatformIds:
          ((json['enabledPlatformIds'] as List?)?.cast<String>() ?? const [])
              .toSet(),
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
      masterEnabled: json['masterEnabled'] as bool? ?? true,
      pauseSession: json['pauseSession'] == null
          ? null
          : PauseSession.fromJson(json['pauseSession'] as Map<String, dynamic>),
      onboarded: json['onboarded'] as bool? ?? false,
      themeMode: AppThemeMode.fromWire(json['themeMode'] as String?),
    );
  }

  final BlockingPlan activePlan;
  final BlockingMode defaultBlockMode;
  final Set<String> enabledPlatformIds;
  final bool vibrationEnabled;
  final bool masterEnabled;

  /// Live pause contract (an allowed window). Null = none.
  final PauseSession? pauseSession;
  final bool onboarded;

  /// Appearance preference (drives the Flutter `ThemeMode` in the UI layer).
  final AppThemeMode themeMode;

  DateTime _now(DateTime? now) => now ?? DateTime.now();

  // ── Derived session state ─────────────────────────────────────────────────

  SessionPhase pausePhase([DateTime? now]) =>
      pauseSession?.phaseAt(_now(now)) ?? SessionPhase.idle;

  /// A pause contract is live (inside the allowed window) — drives the pause
  /// screen / dashboard banner.
  bool isPauseContractLive([DateTime? now]) {
    final ps = pauseSession;
    return ps != null && _now(now).isBefore(ps.pauseEnd);
  }

  /// Content is currently allowed because we're inside the pause window.
  bool isPaused([DateTime? now]) => isPauseContractLive(now);

  /// The plan the native detector enforces when it is NOT suspended. The pause
  /// window is carved out via [nativePauseUntil]; this value bites once the
  /// pause lapses (always Block All — pauses resume into Block All).
  BlockingPlan effectiveNativePlan([DateTime? now]) {
    final ps = pauseSession;
    if (ps != null && _now(now).isBefore(ps.pauseEnd)) return ps.planToResume;
    return activePlan;
  }

  /// Epoch the native side should treat as "all blocking suspended until" — the
  /// end of the pause window. Null when no pause is live.
  DateTime? nativePauseUntil([DateTime? now]) {
    final ps = pauseSession;
    if (ps != null && _now(now).isBefore(ps.pauseEnd)) return ps.pauseEnd;
    return null;
  }

  AppSettings copyWith({
    BlockingPlan? activePlan,
    BlockingMode? defaultBlockMode,
    Set<String>? enabledPlatformIds,
    bool? vibrationEnabled,
    bool? masterEnabled,
    PauseSession? pauseSession,
    bool clearPauseSession = false,
    bool? onboarded,
    AppThemeMode? themeMode,
  }) {
    return AppSettings(
      activePlan: activePlan ?? this.activePlan,
      defaultBlockMode: defaultBlockMode ?? this.defaultBlockMode,
      enabledPlatformIds: enabledPlatformIds ?? this.enabledPlatformIds,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      masterEnabled: masterEnabled ?? this.masterEnabled,
      pauseSession: clearPauseSession
          ? null
          : (pauseSession ?? this.pauseSession),
      onboarded: onboarded ?? this.onboarded,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'activePlan': activePlan.wire,
    'defaultBlockMode': defaultBlockMode.wire,
    'enabledPlatformIds': enabledPlatformIds.toList(),
    'vibrationEnabled': vibrationEnabled,
    'masterEnabled': masterEnabled,
    'pauseSession': pauseSession?.toJson(),
    'onboarded': onboarded,
    'themeMode': themeMode.wire,
  };

  @override
  List<Object?> get props => [
    activePlan,
    defaultBlockMode,
    enabledPlatformIds,
    vibrationEnabled,
    masterEnabled,
    pauseSession,
    onboarded,
    themeMode,
  ];
}
