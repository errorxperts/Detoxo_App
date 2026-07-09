import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/features/additional_feature/app_upgrader/domain/repositories/app_upgrade_service.dart';
import 'package:detoxo/features/additional_feature/app_upgrader/presentation/app_upgrade_dialog.dart';
import 'package:detoxo/features/additional_feature/app_upgrader/presentation/upgrade_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Wraps the app's main surface with the update-check flow: it provides the
/// [UpgradeCubit], runs the automatic check once on mount, and surfaces the
/// glass [AppUpgradeDialog] when an update is available.
///
/// Mounted above the `HomeShell` scaffold, so its subtree (including the drawer)
/// can read the same cubit for the manual "Check for updates" entry, and the
/// dialog is shown from a context under the go_router Navigator (no navigatorKey
/// plumbing needed).
class UpgradeGate extends StatelessWidget {
  const UpgradeGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UpgradeCubit(sl<AppUpgradeService>())..check(),
      child: _UpgradeGateView(child: child),
    );
  }
}

class _UpgradeGateView extends StatefulWidget {
  const _UpgradeGateView({required this.child});

  final Widget child;

  @override
  State<_UpgradeGateView> createState() => _UpgradeGateViewState();
}

class _UpgradeGateViewState extends State<_UpgradeGateView> {
  /// Guards against stacking the dialog while one is already open (HomeShell
  /// rebuilds on tab switches; a manual check can also re-fire).
  bool _dialogOpen = false;

  Future<void> _onState(BuildContext context, UpgradeState state) async {
    switch (state.view) {
      case UpgradeView.updateAvailable:
        final status = state.status;
        if (status == null || _dialogOpen) return;
        _dialogOpen = true;
        final cubit = context.read<UpgradeCubit>();
        await AppUpgradeDialog.show(
          context,
          status,
          onUpdate: cubit.openStore,
          onLater: cubit.remindLater,
          onSkip: cubit.skip,
        );
        _dialogOpen = false;
      case UpgradeView.upToDate:
        // Only confirm "up to date" for a user-initiated (drawer) check; the
        // automatic launch check stays silent when there's nothing to show.
        if (state.manual) {
          GlassToast.show(context, "You're on the latest version");
        }
      case UpgradeView.idle:
      case UpgradeView.checking:
      case UpgradeView.error:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UpgradeCubit, UpgradeState>(
      listenWhen: (prev, next) => prev.view != next.view,
      listener: _onState,
      child: widget.child,
    );
  }
}
