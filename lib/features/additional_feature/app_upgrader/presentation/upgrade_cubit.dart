import 'package:detoxo/features/additional_feature/app_upgrader/domain/entities/upgrade_status.dart';
import 'package:detoxo/features/additional_feature/app_upgrader/domain/repositories/app_upgrade_service.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Where an [UpgradeState] is in the check lifecycle.
enum UpgradeView { idle, checking, updateAvailable, upToDate, error }

class UpgradeState extends Equatable {
  const UpgradeState({
    this.view = UpgradeView.idle,
    this.status,
    this.manual = false,
  });

  final UpgradeView view;

  /// The available update, populated only when [view] is
  /// [UpgradeView.updateAvailable].
  final UpgradeStatus? status;

  /// Whether the current check was user-initiated (drawer "Check for updates").
  /// Lets the UI show an "up to date" confirmation only when the user asked.
  final bool manual;

  @override
  List<Object?> get props => [view, status, manual];
}

/// Orchestrates the update check and the user's response over
/// [AppUpgradeService]. Created inline via `BlocProvider` (not registered in
/// get_it), mirroring the app's other cubits.
class UpgradeCubit extends Cubit<UpgradeState> {
  UpgradeCubit(this._service) : super(const UpgradeState());

  final AppUpgradeService _service;

  /// Runs a store-version check. [manual] is set for the drawer entry so an
  /// "up to date" result can be surfaced to the user (the automatic launch
  /// check stays silent when there's nothing to show).
  Future<void> check({bool manual = false}) async {
    emit(UpgradeState(view: UpgradeView.checking, manual: manual));
    try {
      final status = await _service.check(force: manual);
      if (status != null && status.isUpdateAvailable) {
        emit(
          UpgradeState(
            view: UpgradeView.updateAvailable,
            status: status,
            manual: manual,
          ),
        );
      } else {
        emit(UpgradeState(view: UpgradeView.upToDate, manual: manual));
      }
    } catch (_) {
      emit(UpgradeState(view: UpgradeView.error, manual: manual));
    }
  }

  /// Launches the store listing so the user can update.
  Future<void> openStore() => _service.openStore();

  /// "Later": defer until the next throttle window.
  Future<void> remindLater() async {
    await _service.remindLater();
    emit(const UpgradeState());
  }

  /// "Skip this version": suppress the prompt for the current store version.
  Future<void> skip() async {
    await _service.skipThisVersion();
    emit(const UpgradeState());
  }
}
