import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/permissions/domain/entities/permission_status.dart';
import 'package:detoxo/features/permissions/presentation/permissions_cubit.dart';
import 'package:detoxo/features/blocking/engine/presentation/service_cubit.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  static const _planLabels = {
    BlockingPlan.blockAll: 'Block all',
    BlockingPlan.curious: 'Curious',
    BlockingPlan.oneReel: 'One reel',
    BlockingPlan.paused: 'Paused',
  };

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<ServiceCubit>().refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Detoxo',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          const _StatusCard(),
          const SizedBox(height: 16),
          const _StatsRow(),
          const SizedBox(height: 16),
          const _PlanSelector(planLabels: _planLabels),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Quick actions',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.pause_circle_outline),
                  title: const Text('Take a mindful pause'),
                  subtitle: const Text('Temporarily allow, then cool down'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.pause),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.tune),
                  title: const Text('Choose what to block'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.blocklist),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    final running =
        context.watch<ServiceCubit>().state.status == ServiceStatus.running;
    final scheme = Theme.of(context).colorScheme;
    return Card(
          color: running
              ? scheme.primaryContainer
              : scheme.errorContainer.withValues(alpha: 0.6),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  running ? Icons.verified_user : Icons.gpp_bad,
                  size: 40,
                  color: running ? scheme.primary : scheme.error,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        running ? 'Protection active' : 'Protection off',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        running
                            ? 'Detoxo is watching for reels & shorts.'
                            : 'Enable the accessibility service to start blocking.',
                      ),
                      if (!running) ...[
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => context
                              .read<PermissionsCubit>()
                              .request(AppPermission.accessibility),
                          child: const Text('Enable now'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    final snapshot = context.watch<ServiceCubit>().state;
    return Row(
      children: [
        StatTile(
          label: 'Blocked today',
          value: '${snapshot.blocksToday}',
          icon: Icons.today,
        ),
        const SizedBox(width: 12),
        StatTile(
          label: 'Blocked all-time',
          value: '${snapshot.blocksTotal}',
          icon: Icons.shield_moon,
        ),
      ],
    );
  }
}

class _PlanSelector extends StatelessWidget {
  const _PlanSelector({required this.planLabels});

  final Map<BlockingPlan, String> planLabels;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state;
    return SectionCard(
      title: 'Blocking plan',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in planLabels.entries)
            ChoiceChip(
              label: Text(entry.value),
              selected: settings.activePlan == entry.key,
              onSelected: (_) => _onPlan(context, entry.key, settings),
            ),
        ],
      ),
    );
  }

  void _onPlan(BuildContext context, BlockingPlan plan, AppSettings settings) {
    if (plan == BlockingPlan.paused) {
      context.push(Routes.pause);
      return;
    }
    context.read<SettingsCubit>().setPlan(plan);
  }
}
