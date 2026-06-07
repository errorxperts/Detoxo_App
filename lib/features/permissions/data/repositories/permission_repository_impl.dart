import 'package:permission_handler/permission_handler.dart' as ph;

import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/permissions/domain/entities/permission_status.dart';
import 'package:detoxo/features/permissions/domain/repositories/permission_repository.dart';
import 'package:detoxo/core/platform_channels/engine_channel.dart';

/// Resolves permission status via the native channel (accessibility, overlay,
/// usage, battery, device-admin) and permission_handler (notifications).
class PermissionRepositoryImpl implements PermissionRepository {
  PermissionRepositoryImpl(this._channel);

  final EngineChannel _channel;

  @override
  Future<List<PermissionStatus>> statuses() async {
    final result = <PermissionStatus>[];
    for (final p in AppPermission.values) {
      result.add(await status(p));
    }
    return result;
  }

  @override
  Future<PermissionStatus> status(AppPermission permission) async {
    final granted = switch (permission) {
      AppPermission.accessibility => await _channel.isAccessibilityEnabled(),
      AppPermission.overlay => await _channel.canDrawOverlays(),
      AppPermission.usageAccess => await _channel.hasUsageAccess(),
      AppPermission.batteryOptimization => await _channel.isIgnoringBattery(),
      AppPermission.deviceAdmin => await _channel.isDeviceAdminActive(),
      AppPermission.notifications =>
        await ph.Permission.notification.isGranted,
    };
    return PermissionStatus(
      kind: permission,
      state: granted ? PermissionState.granted : PermissionState.denied,
    );
  }

  @override
  Future<void> request(AppPermission permission) async {
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
        await ph.Permission.notification.request();
    }
  }
}
