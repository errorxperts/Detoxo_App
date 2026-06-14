import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:equatable/equatable.dart';

/// A temporary suspension of blocking, followed by a cooldown lockdown.
/// Phase math is verified from the reference app: active -> cooldown -> idle.
class PauseSession extends Equatable {
  const PauseSession({
    required this.startedAt,
    required this.pauseDuration,
    required this.cooldownDuration,
    required this.planToResume,
    this.allowInCooldown = true, // verified: allowInLockDown defaults to true
  });

  factory PauseSession.fromJson(Map<String, dynamic> json) => PauseSession(
        startedAt:
            DateTime.fromMillisecondsSinceEpoch(json['startedAt'] as int? ?? 0),
        pauseDuration: Duration(milliseconds: json['pauseMs'] as int? ?? 0),
        cooldownDuration: Duration(milliseconds: json['cooldownMs'] as int? ?? 0),
        planToResume: BlockingPlan.fromWire(json['planToResume'] as String?),
        allowInCooldown: json['allowInCooldown'] as bool? ?? true,
      );

  final DateTime startedAt;
  final Duration pauseDuration;
  final Duration cooldownDuration;
  final BlockingPlan planToResume;
  final bool allowInCooldown;

  DateTime get pauseEnd => startedAt.add(pauseDuration);
  DateTime get cooldownEnd => pauseEnd.add(cooldownDuration);

  SessionPhase phaseAt(DateTime now) {
    if (now.isBefore(pauseEnd)) return SessionPhase.active;
    if (now.isBefore(cooldownEnd)) return SessionPhase.cooldown;
    return SessionPhase.idle;
  }

  Duration remainingIn(DateTime now) {
    final end = now.isBefore(pauseEnd) ? pauseEnd : cooldownEnd;
    final diff = end.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// The wall-clock duration of the phase active at [now] (for ring progress).
  Duration phaseLengthAt(DateTime now) =>
      now.isBefore(pauseEnd) ? pauseDuration : cooldownDuration;

  /// 0..100 progress through the cooldown window — drives the cooldown emoji
  /// band (`EMOJI_PAUSE_COUNTDOWN_COOLDOWN`).
  int cooldownProgressPct(DateTime now) {
    final total = cooldownDuration.inMilliseconds;
    if (total <= 0) return 100;
    final elapsed = now.difference(pauseEnd).inMilliseconds;
    return ((elapsed / total) * 100).clamp(0, 100).round();
  }

  Map<String, dynamic> toJson() => {
        'startedAt': startedAt.millisecondsSinceEpoch,
        'pauseMs': pauseDuration.inMilliseconds,
        'cooldownMs': cooldownDuration.inMilliseconds,
        'planToResume': planToResume.wire,
        'allowInCooldown': allowInCooldown,
      };

  @override
  List<Object?> get props =>
      [startedAt, pauseDuration, cooldownDuration, planToResume, allowInCooldown];
}

/// Pomodoro-style "curious" allowance: a watch session then a cooldown.
class CuriousSession extends Equatable {
  const CuriousSession({
    required this.startedAt,
    required this.sessionDuration,
    required this.cooldownDuration,
    this.allowInCooldown = false,
    this.disablePlanSwitchInCooldown = false,
  });

  factory CuriousSession.fromJson(Map<String, dynamic> json) => CuriousSession(
        startedAt:
            DateTime.fromMillisecondsSinceEpoch(json['startedAt'] as int? ?? 0),
        sessionDuration: Duration(milliseconds: json['sessionMs'] as int? ?? 0),
        cooldownDuration: Duration(milliseconds: json['cooldownMs'] as int? ?? 0),
        allowInCooldown: json['allowInCooldown'] as bool? ?? false,
        disablePlanSwitchInCooldown:
            json['disablePlanSwitchInCooldown'] as bool? ?? false,
      );

  final DateTime startedAt;
  final Duration sessionDuration;
  final Duration cooldownDuration;
  final bool allowInCooldown;

  /// When true, the plan switcher is locked while this session is in cooldown.
  final bool disablePlanSwitchInCooldown;

  DateTime get sessionEnd => startedAt.add(sessionDuration);
  DateTime get cooldownEnd => sessionEnd.add(cooldownDuration);

  SessionPhase phaseAt(DateTime now) {
    if (now.isBefore(sessionEnd)) return SessionPhase.active;
    if (now.isBefore(cooldownEnd)) return SessionPhase.cooldown;
    return SessionPhase.idle;
  }

  Duration remainingIn(DateTime now) {
    final end = now.isBefore(sessionEnd) ? sessionEnd : cooldownEnd;
    final diff = end.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// The wall-clock duration of the phase active at [now] (for ring progress).
  Duration phaseLengthAt(DateTime now) =>
      now.isBefore(sessionEnd) ? sessionDuration : cooldownDuration;

  /// 0..100 progress through the cooldown window (drives the cooldown band).
  int cooldownProgressPct(DateTime now) {
    final total = cooldownDuration.inMilliseconds;
    if (total <= 0) return 100;
    final elapsed = now.difference(sessionEnd).inMilliseconds;
    return ((elapsed / total) * 100).clamp(0, 100).round();
  }

  /// Whole minutes elapsed in the watch session — drives the curious emoji band
  /// (`EMOJI_CURIOUS_PLAN`, bucketed by minutes elapsed).
  int minutesElapsedInSession(DateTime now) {
    final ms = now.difference(startedAt).inMilliseconds
        .clamp(0, sessionDuration.inMilliseconds);
    return (ms / 60000).floor();
  }

  /// Gray-out the plan switcher when in cooldown with the lock enabled.
  bool planSwitchLockedAt(DateTime now) =>
      disablePlanSwitchInCooldown && phaseAt(now) == SessionPhase.cooldown;

  Map<String, dynamic> toJson() => {
        'startedAt': startedAt.millisecondsSinceEpoch,
        'sessionMs': sessionDuration.inMilliseconds,
        'cooldownMs': cooldownDuration.inMilliseconds,
        'allowInCooldown': allowInCooldown,
        'disablePlanSwitchInCooldown': disablePlanSwitchInCooldown,
      };

  @override
  List<Object?> get props => [
        startedAt,
        sessionDuration,
        cooldownDuration,
        allowInCooldown,
        disablePlanSwitchInCooldown,
      ];
}
