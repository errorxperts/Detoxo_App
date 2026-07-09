import 'package:detoxo/features/additional_feature/app_upgrader/domain/entities/upgrade_status.dart';

/// Checks whether a newer build is available on the store and drives the
/// upgrade actions. Implemented over the `upgrader` package but exposed as a
/// plain contract so the UI never touches the package directly.
///
/// Every method is best-effort and fails closed: on a non-Android platform, a
/// scrape failure, or when offline, [check] returns `null` and the action
/// methods no-op — the prompt is purely additive and must never block launch.
abstract interface class AppUpgradeService {
  /// Runs a store-version check. Returns a [UpgradeStatus] describing an
  /// available update, or `null` when there is nothing to prompt (up to date,
  /// throttled/ignored, offline, or unsupported platform).
  ///
  /// The automatic (launch) check honors the user's "Later"/"Skip" choices and
  /// the re-prompt throttle. Set [force] for a user-initiated check (the drawer
  /// "Check for updates"), which bypasses the throttle so an available update is
  /// always reported.
  Future<UpgradeStatus?> check({bool force = false});

  /// Opens the app's store listing so the user can update.
  Future<void> openStore();

  /// Records that the user chose "Later"; suppresses the prompt until the next
  /// throttle window elapses.
  Future<void> remindLater();

  /// Records that the user chose to skip the current store version; suppresses
  /// the prompt for that version.
  Future<void> skipThisVersion();
}
