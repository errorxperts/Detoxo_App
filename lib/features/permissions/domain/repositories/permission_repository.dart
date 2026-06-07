import 'package:detoxo/features/permissions/domain/entities/permission_status.dart';

/// Checks/requests the runtime permissions in the onboarding funnel.
abstract interface class PermissionRepository {
  Future<List<PermissionStatus>> statuses();
  Future<PermissionStatus> status(AppPermission permission);
  Future<void> request(AppPermission permission);
}
