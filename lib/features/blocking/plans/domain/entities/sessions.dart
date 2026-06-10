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
    this.allowInCooldown = false,
  });

  factory PauseSession.fromJson(Map<String, dynamic> json) => PauseSession(
        startedAt:
            DateTime.fromMillisecondsSinceEpoch(json['startedAt'] as int? ?? 0),
        pauseDuration: Duration(milliseconds: json['pauseMs'] as int? ?? 0),
        cooldownDuration: Duration(milliseconds: json['cooldownMs'] as int? ?? 0),
        planToResume: BlockingPlan.fromWire(json['planToResume'] as String?),
        allowInCooldown: json['allowInCooldown'] as bool? ?? false,
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
  });

  final DateTime startedAt;
  final Duration sessionDuration;
  final Duration cooldownDuration;
  final bool allowInCooldown;

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

  @override
  List<Object?> get props =>
      [startedAt, sessionDuration, cooldownDuration, allowInCooldown];
}
