import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:equatable/equatable.dart';

/// A single runtime permission's status in the onboarding funnel.
class PermissionStatus extends Equatable {
  const PermissionStatus({required this.kind, this.state = PermissionState.unknown});

  final AppPermission kind;
  final PermissionState state;

  bool get granted => state == PermissionState.granted;

  /// OS won't prompt again — the only recovery is the app's system settings.
  bool get permanentlyDenied => state == PermissionState.permanentlyDenied;

  PermissionStatus copyWith({PermissionState? state}) =>
      PermissionStatus(kind: kind, state: state ?? this.state);

  @override
  List<Object?> get props => [kind, state];
}

/// Runtime permissions the app guides the user through.
enum AppPermission {
  accessibility('Accessibility', required: true),
  overlay('Display over apps', required: true),
  notifications('Notifications', required: false),
  usageAccess('Usage access', required: false),
  batteryOptimization('Unrestricted battery', required: false),
  deviceAdmin('Uninstall protection', required: false);

  const AppPermission(this.label, {required this.required});
  final String label;
  final bool required;
}
