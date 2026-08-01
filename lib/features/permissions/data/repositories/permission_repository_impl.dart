import 'package:detoxo/core/platform/platform_capabilities.dart';
import 'package:detoxo/core/platform_channels/engine_channel.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/permissions/domain/entities/permission_status.dart';
import 'package:detoxo/features/permissions/domain/repositories/permission_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Resolves permission status via the native channel (accessibility, overlay,
/// usage, battery, device-admin) and permission_handler (notifications).
class PermissionRepositoryImpl implements PermissionRepository {
  PermissionRepositoryImpl(this._channel);

  final EngineChannel _channel;

  @override
  Future<List<PermissionStatus>> statuses() async {
    // The Android permission funnel has no iOS equivalent. Returning an empty
    // list makes PermissionsCubit.allRequiredGranted vacuously true, so the
    // splash gate routes straight to /home on iOS.
    if (!PlatformCapabilities.usesAndroidPermissionFunnel) return const [];
    final result = <PermissionStatus>[];
    for (final p in AppPermission.values) {
      result.add(await status(p));
    }
    return result;
  }

  @override
  Future<PermissionStatus> status(AppPermission permission) async {
    if (!PlatformCapabilities.usesAndroidPermissionFunnel) {
      return PermissionStatus(kind: permission, state: PermissionState.denied);
    }
    // Notifications is the one true runtime permission: it can be
    // permanently denied (don't-ask-again), which the settings-based ones can't.
    if (permission == AppPermission.notifications) {
      final s = await ph.Permission.notification.status;
      return PermissionStatus(
        kind: permission,
        state: s.isGranted
            ? PermissionState.granted
            : s.isPermanentlyDenied
            ? PermissionState.permanentlyDenied
            : PermissionState.denied,
      );
    }
    final granted = switch (permission) {
      AppPermission.accessibility => await _channel.isAccessibilityEnabled(),
      AppPermission.overlay => await _channel.canDrawOverlays(),
      AppPermission.usageAccess => await _channel.hasUsageAccess(),
      AppPermission.batteryOptimization => await _channel.isIgnoringBattery(),
      AppPermission.deviceAdmin => await _channel.isDeviceAdminActive(),
      AppPermission.notifications => false, // handled above
    };
    return PermissionStatus(
      kind: permission,
      state: granted ? PermissionState.granted : PermissionState.denied,
    );
  }

  @override
  Future<void> request(AppPermission permission) async {
    if (!PlatformCapabilities.usesAndroidPermissionFunnel) return;
    switch (permission) {
      case AppPermission.accessibility:
        await _channel.openAccessibilitySettings();
      case AppPermission.overlay:
        await _channel.requestOverlay();
      case AppPermission.usageAccess:
        await _channel.openUsageAccess();
      case AppPermission.batteryOptimization:
        await _channel.requestIgnoreBattery();
      case AppPermission.deviceAdmin:
        await _channel.requestDeviceAdmin();
      case AppPermission.notifications:
        // A plain request() no-ops once permanently denied — send the user to
        // the app's settings screen instead so they have a recovery path.
        if (await ph.Permission.notification.isPermanentlyDenied) {
          await ph.openAppSettings();
        } else {
          await ph.Permission.notification.request();
        }
    }
  }

  @override
  Future<bool> installedOutsidePlay() async {
    if (!PlatformCapabilities.usesAndroidPermissionFunnel) return false;
    try {
      // package_info_plus reads getInstallSourceInfo().initiatingPackageName on
      // API 30+, which — unlike the installing package — cannot be rewritten
      // after install. Play is the only installer exempt from the gate in
      // practice; an adb/debug install reports null, which is also restricted.
      final store = (await PackageInfo.fromPlatform()).installerStore;
      return store != _playStorePackage;
    } catch (_) {
      // Unknown installer: don't guess, don't nag.
      return false;
    }
  }

  @override
  Future<void> openAppSettings() => ph.openAppSettings();

  static const String _playStorePackage = 'com.android.vending';
}
