import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/permissions/domain/entities/permission_status.dart';
import 'package:detoxo/features/permissions/domain/repositories/permission_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Drives the permission funnel: loads statuses, requests, and re-checks (e.g.
/// when the app resumes after the user returns from a system settings screen).
///
/// Also detects Android's restricted-settings (13/14) / Enhanced Confirmation
/// Mode (15+) gate, which silently refuses the Accessibility, overlay and
/// device-admin toggles for apps installed outside the Play Store. Android
/// exposes no way to ask whether the gate is active — the appop behind it is
/// `@hide`, read-restricted, and defaults to `MODE_DEFAULT` under ECM — so this
/// is inferred from behaviour: the grant was attempted, the user came back, and
/// nothing changed.
class PermissionsCubit extends Cubit<List<PermissionStatus>> {
  PermissionsCubit(this._repo) : super(const []);

  final PermissionRepository _repo;

  /// Attempts that returned with the permission still denied, per permission.
  final Map<AppPermission, int> _attempts = {};

  /// Cached for the session; the installer cannot change while we're running.
  bool? _outsidePlay;

  /// One failed attempt is noise — users back out, get distracted, or tap Grant
  /// just to look. Two round-trips with no change is a stuck user.
  static const int _attemptsBeforeHelp = 2;

  /// Whether [status] looks blocked by the restricted-settings gate rather than
  /// simply not granted yet.
  bool needsRestrictedFix(PermissionStatus status) =>
      (_outsidePlay ?? false) &&
      !status.granted &&
      status.kind.restrictedWhenSideloaded &&
      (_attempts[status.kind] ?? 0) >= _attemptsBeforeHelp;

  Future<void> refresh() async {
    _outsidePlay ??= await _repo.installedOutsidePlay();
    final statuses = await _repo.statuses();
    for (final s in statuses) {
      // Self-heal: once it lands, forget the failed attempts.
      if (s.granted) _attempts.remove(s.kind);
    }
    emit([
      for (final s in statuses)
        needsRestrictedFix(s)
            ? s.copyWith(state: PermissionState.permanentlyDenied)
            : s,
    ]);
  }

  Future<void> request(AppPermission permission) async {
    _attempts.update(permission, (n) => n + 1, ifAbsent: () => 1);
    await _repo.request(permission);
    // Re-check shortly after; system dialogs/settings are async.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await refresh();
  }

  /// Opens Detoxo's system settings page so the user can lift the
  /// restricted-settings block. Clears the attempt counts so the cards read
  /// "Grant" again when they come back.
  Future<void> openAppSettings() async {
    _attempts.clear();
    await _repo.openAppSettings();
  }

  bool get allRequiredGranted =>
      state.where((s) => s.kind.required).every((s) => s.granted);
}
