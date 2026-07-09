import 'package:detoxo/core/platform/platform_capabilities.dart';
import 'package:detoxo/features/additional_feature/app_upgrader/domain/entities/upgrade_status.dart';
import 'package:detoxo/features/additional_feature/app_upgrader/domain/repositories/app_upgrade_service.dart';
import 'package:flutter/foundation.dart';
import 'package:upgrader/upgrader.dart';

/// [AppUpgradeService] backed by the `upgrader` package.
///
/// `upgrader` is used purely as the engine: it scrapes the Play Store listing
/// for the latest version, compares it to the installed build, persists the
/// user's "later"/"skip" choices (in its own SharedPreferences — the app's Hive
/// `LocalStore` is untouched), and launches the store. The prompt UI is our own
/// glass dialog, so we never mount `UpgradeAlert`.
///
/// Everything is guarded: the check is Android-only (iOS is preview-only, see
/// [PlatformCapabilities]) and any failure resolves to `null` so a flaky scrape
/// or offline state never blocks the app.
class UpgraderAppUpgradeService implements AppUpgradeService {
  UpgraderAppUpgradeService();

  /// Dev-only preview switch: flip to `true` to force the automatic dialog on an
  /// unpublished build (Play scraping returns no version until the app is live,
  /// so the dialog never appears otherwise). Left `false` so debug builds behave
  /// like production and the prompt doesn't pop on every launch during unrelated
  /// work. Also reset persisted "Later"/"Skip" state with
  /// `Upgrader.clearSavedSettings()` when previewing.
  /// Lazily built so no store work happens on unsupported platforms or before
  /// the first [check]. `durationUntilAlertAgain` throttles re-prompting after a
  /// "Later"; `debugLogging` traces the scrape/compare in dev.
  ///
  /// The prompt stays off on unpublished builds (Play scraping returns no
  /// version until the app is live), so debug builds behave like production. To
  /// preview the dialog locally, temporarily add `debugDisplayAlways: true` here
  /// and reset saved "Later"/"Skip" state with `Upgrader.clearSavedSettings()`.
  Upgrader? _upgrader;
  Upgrader get _engine => _upgrader ??= Upgrader(
    storeController: UpgraderStoreController(onAndroid: UpgraderPlayStore.new),
    durationUntilAlertAgain: const Duration(days: 1),
    debugLogging: kDebugMode,
  );

  @override
  Future<UpgradeStatus?> check({bool force = false}) async {
    // Android-only: iOS/web have no Play listing and would scrape spuriously.
    if (!PlatformCapabilities.supportsBlockingEngine) return null;
    try {
      await _engine.initialize();
      // A manual check bypasses the throttle/ignore state and reports any
      // available update; the automatic check honors "Later"/"Skip" and the
      // re-prompt window (and `debugDisplayAlways` in dev).
      final show = force
          ? _engine.isUpdateAvailable()
          : _engine.shouldDisplayUpgrade();
      if (!show) return null;
      return UpgradeStatus(
        isUpdateAvailable: true,
        installedVersion: _engine.currentInstalledVersion,
        storeVersion: _engine.currentAppStoreVersion,
        releaseNotes: _engine.releaseNotes,
        isCritical: _engine.versionInfo?.isCriticalUpdate ?? false,
        isBelowMinVersion: _engine.belowMinAppVersion(),
      );
    } catch (_) {
      // Fail closed: the update prompt is additive and must never break launch.
      return null;
    }
  }

  @override
  Future<void> openStore() async {
    try {
      await _engine.sendUserToAppStore();
    } catch (_) {
      // No-op: launching the store is best-effort.
    }
  }

  @override
  Future<void> remindLater() async {
    try {
      await _engine.saveLastAlerted();
    } catch (_) {
      // No-op.
    }
  }

  @override
  Future<void> skipThisVersion() async {
    try {
      await _engine.saveIgnored();
    } catch (_) {
      // No-op.
    }
  }
}
