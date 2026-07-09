/// App upgrader: an offline-first "update available" prompt.
///
/// Uses the `upgrader` package purely as the engine — it scrapes the Play Store
/// listing for the latest version, compares it to the installed build, persists
/// the user's "later"/"skip" choices, and launches the store — while the prompt
/// itself is rendered as the app's own glass `AppUpgradeDialog`. Supports a
/// non-dismissible variant for critical / below-minimum-version updates.
///
/// Wiring: register `AppUpgradeService` in the DI cascade, mount `UpgradeGate`
/// above the main scaffold, and (optionally) trigger `UpgradeCubit.check` from a
/// manual "Check for updates" affordance. The check is Android-only and fails
/// closed, so it never blocks launch.
library;

export 'data/repositories/upgrader_app_upgrade_service.dart';
export 'domain/entities/upgrade_status.dart';
export 'domain/repositories/app_upgrade_service.dart';
export 'presentation/app_upgrade_dialog.dart';
export 'presentation/upgrade_cubit.dart';
export 'presentation/upgrade_gate.dart';
