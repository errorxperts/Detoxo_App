import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/platform/platform_capabilities.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/blocking/engine/presentation/service_cubit.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:detoxo/features/permissions/domain/entities/permission_status.dart';
import 'package:detoxo/features/permissions/presentation/permissions_cubit.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({this.scrollController, super.key});

  final ScrollController? scrollController;

  // Only the three "real" blocking styles — pause is handled separately.
  static const _plans = [BlockingPlan.blockAll, BlockingPlan.curious, BlockingPlan.oneReel];
  static const _planLabels = ['Block all', 'Curious', 'One reel'];

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<ServiceCubit>().refresh(),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xxxl + AppSpacing.xl),
        children: [
          Text(
            'Detoxo',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ).animate().fadeIn(duration: AppDurations.normal),
          const SizedBox(height: AppSpacing.md),
          const _StatusCard(),
          const SizedBox(height: AppSpacing.md),
          const _StatsRow(),
          const SizedBox(height: AppSpacing.md),
          const _PausedBanner(),
          const _PlanSelector(plans: _plans, labels: _planLabels),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Quick actions',
            child: Column(
              children: [
                GlassListTile(
                  leading: const Icon(Icons.pause_circle_outline, color: AppColors.accent),
                  title: 'Take a mindful pause',
                  subtitle: 'Temporarily allow, then cool down',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.pause),
                ),
                const SizedBox(height: AppSpacing.xs),
                GlassListTile(
                  leading: const Icon(Icons.tune, color: AppColors.accent),
                  title: 'Choose what to block',
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
    final text = Theme.of(context).textTheme;

    // iOS / non-Android: blocking is Android-only — be honest, don't offer a
    // dead "Enable now" CTA.
    if (PlatformCapabilities.isBlockingPreviewOnly) {
      return GlassCard(
        accent: AppColors.warning,
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 36, color: AppColors.warning),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Preview mode',
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('Blocking runs on Android. iOS support is coming soon.'),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: AppDurations.normal).slideY(begin: 0.08, end: 0);
    }

    final running = context.watch<ServiceCubit>().state.status == ServiceStatus.running;
    return GlassCard(
      accent: running ? AppColors.accent : AppColors.danger,
      child: Row(
        children: [
          if (running)
            const StatusDot(color: AppColors.accent, size: 16)
          else
            const Icon(Icons.gpp_bad, size: 36, color: AppColors.danger),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  running ? 'Protection active' : 'Protection off',
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  running
                      ? 'Detoxo is watching for reels & shorts.'
                      : 'Enable the accessibility service to start blocking.',
                ),
                if (!running) ...[
                  const SizedBox(height: AppSpacing.sm),
                  PrimaryButton(
                    label: 'Enable now',
                    tint: AppColors.danger,
                    onPressed: () =>
                        context.read<PermissionsCubit>().request(AppPermission.accessibility),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: AppDurations.normal).slideY(begin: 0.08, end: 0);
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    final snapshot = context.watch<ServiceCubit>().state;
    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: 'Blocked today',
            value: snapshot.blocksToday,
            icon: Icons.today,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: StatCard(
            label: 'Blocked all-time',
            value: snapshot.blocksTotal,
            icon: Icons.shield_moon,
          ),
        ),
      ],
    );
  }
}

/// Shown above the plan selector when blocking is paused — keeps the paused
/// state visible without making it a fourth segment (de-dups the old chip).
class _PausedBanner extends StatelessWidget {
  const _PausedBanner();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state;
    if (!settings.isPaused) return const SizedBox.shrink();
    final remaining = settings.pauseUntil!.difference(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GlassListTile(
        leading: const Icon(Icons.pause_circle_filled, color: AppColors.warning),
        title: 'Paused',
        subtitle: 'Blocking resumes in ${formatCountdown(remaining)}',
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(Routes.pause),
      ),
    );
  }
}

class _PlanSelector extends StatelessWidget {
  const _PlanSelector({required this.plans, required this.labels});

  final List<BlockingPlan> plans;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state;
    final selected = plans.indexOf(settings.activePlan);
    return SectionCard(
      title: 'Blocking plan',
      child: AdaptiveSegmentedControl(
        labels: labels,
        selectedIndex: selected < 0 ? 0 : selected,
        onChanged: (i) => context.read<SettingsCubit>().setPlan(plans[i]),
      ),
    );
  }
}
