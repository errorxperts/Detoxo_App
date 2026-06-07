import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/features/permissions/domain/entities/permission_status.dart';
import 'package:detoxo/features/permissions/presentation/permissions_cubit.dart';

/// Guided permission funnel. Re-checks statuses whenever the app resumes (the
/// user typically grants from a system settings screen and returns).
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<PermissionsCubit>().refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<PermissionsCubit>().refresh();
    }
  }

  IconData _iconFor(AppPermission p) => switch (p) {
        AppPermission.accessibility => Icons.accessibility_new,
        AppPermission.overlay => Icons.layers,
        AppPermission.notifications => Icons.notifications,
        AppPermission.usageAccess => Icons.bar_chart,
        AppPermission.batteryOptimization => Icons.battery_charging_full,
        AppPermission.deviceAdmin => Icons.shield,
      };

  String _descFor(AppPermission p) => switch (p) {
        AppPermission.accessibility =>
          'Lets Detoxo detect and block reels & shorts. Required.',
        AppPermission.overlay =>
          'Shows the block / PIN screen over other apps. Required.',
        AppPermission.notifications =>
          'Alerts you if protection stops.',
        AppPermission.usageAccess =>
          'Powers app usage limits.',
        AppPermission.batteryOptimization =>
          'Keeps the blocker alive in the background.',
        AppPermission.deviceAdmin =>
          'Optional uninstall protection.',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up protection')),
      body: BlocBuilder<PermissionsCubit, List<PermissionStatus>>(
        builder: (context, statuses) {
          final allRequired = context.read<PermissionsCubit>().allRequiredGranted;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Grant a few permissions so Detoxo can do its job. '
                      'Required ones are marked.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    for (final status in statuses)
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Icon(_iconFor(status.kind)),
                          title: Row(
                            children: [
                              Flexible(child: Text(status.kind.label)),
                              if (status.kind.required) ...[
                                const SizedBox(width: 6),
                                const _RequiredChip(),
                              ],
                            ],
                          ),
                          subtitle: Text(_descFor(status.kind)),
                          trailing: status.granted
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                              : FilledButton.tonal(
                                  onPressed: () => context
                                      .read<PermissionsCubit>()
                                      .request(status.kind),
                                  child: const Text('Grant'),
                                ),
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      onPressed: allRequired
                          ? () => context.go(Routes.home)
                          : null,
                      child: Text(
                        allRequired ? 'Continue' : 'Grant required permissions',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RequiredChip extends StatelessWidget {
  const _RequiredChip();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Required',
        style: TextStyle(fontSize: 11, color: scheme.onErrorContainer),
      ),
    );
  }
}
