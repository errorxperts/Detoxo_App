import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';

/// The Plan widget's second source (EVO-073): the engine's plan as native
/// `ConfigStore` holds it. Native reads it live at every draw; in the app it
/// is only [demo] (the editor previews the design, not the live plan). Not
/// part of the IM-02 payload, which stays nine keys. Mirrors Kotlin
/// `PlanState`.
class PlanState {
  const PlanState({
    this.plan = BlockingPlan.blockAll,
    this.pauseUntil = 0,
    this.reelAllowance = 1,
    this.reelsConsumed = 0,
    this.blockingOn = true,
    this.serviceOn = true,
  });

  /// Block All, on: the editor's, picker's and pin dialog's plan.
  static const demo = PlanState();

  /// `ConfigStore.reelAllowance` is 1..[maxAllowance].
  static const maxAllowance = 20;

  final BlockingPlan plan;

  /// Epoch ms a live Pause ends; 0 or past = no pause.
  final int pauseUntil;
  final int reelAllowance;
  final int reelsConsumed;

  /// The "Blocking active" switch (`masterEnabled`).
  final bool blockingOn;

  /// The accessibility service is running.
  final bool serviceOn;
}
