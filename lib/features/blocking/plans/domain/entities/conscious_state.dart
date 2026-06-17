import 'package:equatable/equatable.dart';

/// Live snapshot of the native Conscious "earn-as-you-abstain" bank.
///
/// Conscious lets the user bank allowance while abstaining (reels blocked) and
/// spend it 1:1 while watching. The native engine owns the running balance so it
/// keeps ticking when the Flutter UI is dead; Dart only mirrors it for display.
class ConsciousState extends Equatable {
  const ConsciousState({
    this.bankMs = 0,
    this.maxBankMs = 600000,
    this.watching = false,
    this.blocked = false,
    this.active = false,
  });

  factory ConsciousState.fromMap(Map<String, dynamic> map) => ConsciousState(
        bankMs: (map['bankMs'] as num?)?.toInt() ?? 0,
        maxBankMs: (map['maxBankMs'] as num?)?.toInt() ?? 600000,
        watching: map['watching'] as bool? ?? false,
        blocked: map['blocked'] as bool? ?? false,
        active: map['active'] as bool? ?? false,
      );

  /// Currently banked allowance, in millis.
  final int bankMs;

  /// Cap on the bank, in millis (default 10 min).
  final int maxBankMs;

  /// A reel is on screen right now and the bank is draining.
  final bool watching;

  /// Reels are blocked because the bank is empty.
  final bool blocked;

  /// The Conscious plan is the active plan.
  final bool active;

  Duration get banked => Duration(milliseconds: bankMs);
  Duration get maxBank => Duration(milliseconds: maxBankMs);

  /// 0..1 fill of the bank, for the ring.
  double get progress =>
      maxBankMs <= 0 ? 0 : (bankMs / maxBankMs).clamp(0.0, 1.0);

  bool get hasAllowance => bankMs > 0;

  @override
  List<Object?> get props => [bankMs, maxBankMs, watching, blocked, active];
}
