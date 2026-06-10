import 'package:detoxo/features/permissions/domain/entities/permission_status.dart';
import 'package:detoxo/features/permissions/domain/repositories/permission_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Drives the permission funnel: loads statuses, requests, and re-checks (e.g.
/// when the app resumes after the user returns from a system settings screen).
class PermissionsCubit extends Cubit<List<PermissionStatus>> {
  PermissionsCubit(this._repo) : super(const []);

  final PermissionRepository _repo;

  Future<void> refresh() async => emit(await _repo.statuses());

  Future<void> request(AppPermission permission) async {
    await _repo.request(permission);
    // Re-check shortly after; system dialogs/settings are async.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await refresh();
  }

  bool get allRequiredGranted => state
      .where((s) => s.kind.required)
      .every((s) => s.granted);
}
