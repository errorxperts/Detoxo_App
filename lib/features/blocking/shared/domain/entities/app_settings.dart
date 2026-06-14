import 'package:detoxo/features/blocking/plans/domain/entities/sessions.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:equatable/equatable.dart';

/// The user's blocking configuration. This is the single object Dart persists
/// locally and pushes to the native engine; the service reads from it.
///
/// Pause / Curious are modelled as live [PauseSession] / [CuriousSession]
/// contracts. `activePlan` holds the user's *selected* plan (`paused` while a
/// pause contract is live, `curious` while a curious contract is live); what we
/// actually push to native is *derived* — see [effectiveNativePlan] /
/// [nativePauseUntil] — so the verified phase math drives enforcement over the
/// existing (unchanged) channel.
class AppSettings extends Equatable {
  const AppSettings({
    this.activePlan = BlockingPlan.blockAll,
    this.defaultBlockMode = BlockingMode.pressBack,
    this.enabledPlatformIds = const {},
    this.vibrationEnabled = true,
    this.masterEnabled = true,
    this.pauseSession,
    this.curiousSession,
    this.onboarded = false,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        activePlan: BlockingPlan.fromWire(json['activePlan'] as String?),
        defaultBlockMode: BlockingMode.fromWire(json['defaultBlockMode'] as String?),
        enabledPlatformIds:
            ((json['enabledPlatformIds'] as List?)?.cast<String>() ?? const [])
                .toSet(),
        vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
        masterEnabled: json['masterEnabled'] as bool? ?? true,
        pauseSession: json['pauseSession'] == null
            ? null
            : PauseSession.fromJson(json['pauseSession'] as Map<String, dynamic>),
        curiousSession: json['curiousSession'] == null
            ? null
            : CuriousSession.fromJson(
                json['curiousSession'] as Map<String, dynamic>),
        onboarded: json['onboarded'] as bool? ?? false,
      );

  final BlockingPlan activePlan;
  final BlockingMode defaultBlockMode;
  final Set<String> enabledPlatformIds;
  final bool vibrationEnabled;
  final bool masterEnabled;

  /// Live pause contract (allowed window → mandatory cooldown). Null = none.
  final PauseSession? pauseSession;

  /// Live curious (pomodoro) contract. Null = none.
  final CuriousSession? curiousSession;
  final bool onboarded;

  DateTime _now(DateTime? now) => now ?? DateTime.now();

  // ── Derived session state ─────────────────────────────────────────────────

  SessionPhase pausePhase([DateTime? now]) =>
      pauseSession?.phaseAt(_now(now)) ?? SessionPhase.idle;

  SessionPhase curiousPhase([DateTime? now]) =>
      curiousSession?.phaseAt(_now(now)) ?? SessionPhase.idle;

  /// A pause contract is live (allowed window **or** cooldown) — drives the
  /// pause screen / dashboard banner.
  bool isPauseContractLive([DateTime? now]) =>
      pauseSession != null && pausePhase(now) != SessionPhase.idle;

  bool isCuriousContractLive([DateTime? now]) =>
      curiousSession != null && curiousPhase(now) != SessionPhase.idle;

  /// Content is currently allowed because we're inside the pause window.
  bool isPaused([DateTime? now]) => pausePhase(now) == SessionPhase.active;

  /// The plan the native detector enforces when it is NOT suspended. Allowed
  /// phases (pause window, allowed pause cooldown, curious session, allowed
  /// curious cooldown) are carved out via [nativePauseUntil]; this value only
  /// bites once suspension lapses.
  BlockingPlan effectiveNativePlan([DateTime? now]) {
    final t = _now(now);
    final ps = pauseSession;
    if (ps != null && ps.phaseAt(t) != SessionPhase.idle) {
      // Window/allowed-cooldown are suspended; an un-allowed cooldown blocks
      // with the plan the pause will resume into (One-Reel stays One-Reel, …).
      return ps.planToResume;
    }
    final cs = curiousSession;
    if (cs != null) {
      switch (cs.phaseAt(t)) {
        case SessionPhase.active:
          return BlockingPlan.curious; // suspended anyway
        case SessionPhase.cooldown:
          // Allowed cooldown is suspended; otherwise hard-block the reels.
          return cs.allowInCooldown ? BlockingPlan.curious : BlockingPlan.blockAll;
        case SessionPhase.idle:
          break;
      }
    }
    return activePlan;
  }

  /// Epoch the native side should treat as "content suspended until". Covers
  /// every phase where content is *allowed*: the pause window (always), the
  /// pause cooldown when [PauseSession.allowInCooldown], the curious watch
  /// session (always), and the curious cooldown when allowed. Null otherwise →
  /// [effectiveNativePlan] blocks.
  DateTime? nativePauseUntil([DateTime? now]) {
    final t = _now(now);
    final ps = pauseSession;
    if (ps != null) {
      final until = ps.allowInCooldown ? ps.cooldownEnd : ps.pauseEnd;
      if (t.isBefore(until)) return until;
    }
    final cs = curiousSession;
    if (cs != null) {
      final phase = cs.phaseAt(t);
      if (phase == SessionPhase.active) return cs.sessionEnd;
      if (phase == SessionPhase.cooldown && cs.allowInCooldown) return cs.cooldownEnd;
    }
    return null;
  }

  /// False when a curious cooldown locks plan switching.
  bool switcherEnabled([DateTime? now]) =>
      !(curiousSession?.planSwitchLockedAt(_now(now)) ?? false);

  AppSettings copyWith({
    BlockingPlan? activePlan,
    BlockingMode? defaultBlockMode,
    Set<String>? enabledPlatformIds,
    bool? vibrationEnabled,
    bool? masterEnabled,
    PauseSession? pauseSession,
    bool clearPauseSession = false,
    CuriousSession? curiousSession,
    bool clearCuriousSession = false,
    bool? onboarded,
  }) {
    return AppSettings(
      activePlan: activePlan ?? this.activePlan,
      defaultBlockMode: defaultBlockMode ?? this.defaultBlockMode,
      enabledPlatformIds: enabledPlatformIds ?? this.enabledPlatformIds,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      masterEnabled: masterEnabled ?? this.masterEnabled,
      pauseSession: clearPauseSession ? null : (pauseSession ?? this.pauseSession),
      curiousSession:
          clearCuriousSession ? null : (curiousSession ?? this.curiousSession),
      onboarded: onboarded ?? this.onboarded,
    );
  }

  Map<String, dynamic> toJson() => {
        'activePlan': activePlan.wire,
        'defaultBlockMode': defaultBlockMode.wire,
        'enabledPlatformIds': enabledPlatformIds.toList(),
        'vibrationEnabled': vibrationEnabled,
        'masterEnabled': masterEnabled,
        'pauseSession': pauseSession?.toJson(),
        'curiousSession': curiousSession?.toJson(),
        'onboarded': onboarded,
      };

  @override
  List<Object?> get props => [
        activePlan,
        defaultBlockMode,
        enabledPlatformIds,
        vibrationEnabled,
        masterEnabled,
        pauseSession,
        curiousSession,
        onboarded,
      ];
}
