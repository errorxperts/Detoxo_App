import 'package:equatable/equatable.dart';

/// Live snapshot of the native One Reel / Unblock session.
///
/// In these modes the user is granted a fixed [allowance] of reels; the native
/// engine owns the running [consumed] count (re-armed on every mode tap) so it
/// keeps enforcing when the Flutter UI is dead. Dart only mirrors it for the
/// "N of M reels left" display.
class ReelSessionState extends Equatable {
  const ReelSessionState({
    this.consumed = 0,
    this.allowance = 1,
    this.blocked = false,
    this.active = false,
  });

  factory ReelSessionState.fromMap(Map<String, dynamic> map) =>
      ReelSessionState(
        consumed: (map['consumed'] as num?)?.toInt() ?? 0,
        allowance: (map['allowance'] as num?)?.toInt() ?? 1,
        blocked: map['blocked'] as bool? ?? false,
        active: map['active'] as bool? ?? false,
      );

  /// Reels consumed so far this session.
  final int consumed;

  /// Reels allowed before it re-blocks (1..20).
  final int allowance;

  /// The allowance is spent — reels are blocked until the mode is re-armed.
  final bool blocked;

  /// A One Reel / Unblock plan is the active plan.
  final bool active;

  /// Reels still available this session.
  int get remaining => (allowance - consumed).clamp(0, allowance);

  /// 0..1 fraction still available, for a gauge.
  double get progress =>
      allowance <= 0 ? 0 : (remaining / allowance).clamp(0.0, 1.0);

  @override
  List<Object?> get props => [consumed, allowance, blocked, active];
}
