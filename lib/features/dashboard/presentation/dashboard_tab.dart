import 'dart:async';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/platform/platform_capabilities.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/blocking/engine/presentation/service_cubit.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:detoxo/features/permissions/domain/entities/permission_status.dart';
import 'package:detoxo/features/permissions/presentation/permissions_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.floatingNavClearance + MediaQuery.viewPaddingOf(context).bottom,
        ),
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
          const _SessionBanners(),
          const _PlanSelector(plans: _plans, labels: _planLabels),
          const SizedBox(height: AppSpacing.md),
          SectionCard(
            title: 'Quick actions',
            child: Column(
              children: [
                _AnimatedActionTile(
                  icon: AppIcon.pause,
                  title: 'Take a mindful pause',
                  subtitle: 'Temporarily allow, then cool down',
                  onTap: () => context.push(Routes.pause),
                ),
                const SizedBox(height: AppSpacing.xs),
                _AnimatedActionTile(
                  icon: AppIcon.tune,
                  title: 'Choose what to block',
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
            const AppAnimatedIcon(
              icon: AppIcon.info,
              size: 28,
              color: AppColors.warning,
              playOnAppear: true,
            ),
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
            const AppAnimatedIcon(
              icon: AppIcon.statusOff,
              size: 28,
              color: AppColors.danger,
              playOnAppear: true,
            ),
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
                  AnimatedIconButton(
                    label: 'Enable now',
                    icon: AppIcon.shieldCheck,
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

/// Shown above the plan selector while a Pause or Curious contract is live.
/// Owns a 1 Hz ticker so the remaining time actually counts down (the cubit
/// only emits on phase changes, not every second).
class _SessionBanners extends StatefulWidget {
  const _SessionBanners();

  @override
  State<_SessionBanners> createState() => _SessionBannersState();
}

class _SessionBannersState extends State<_SessionBanners> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state;
    final now = DateTime.now();
    final banners = <Widget>[];

    if (settings.isPauseContractLive(now)) {
      final cooling = settings.pausePhase(now) == SessionPhase.cooldown;
      final remaining = settings.pauseSession!.remainingIn(now);
      banners.add(_AnimatedActionTile(
        icon: AppIcon.pause,
        iconColor: AppColors.warning,
        title: cooling ? 'Winding down' : 'Paused',
        subtitle: cooling
            ? 'Reels still allowed • ${formatCountdown(remaining)} left'
            : 'Reels allowed • ${formatCountdown(remaining)} left',
        onTap: () => context.push(Routes.pause),
      ));
    }

    if (settings.isCuriousContractLive(now)) {
      final session = settings.curiousSession!;
      final cooling = settings.curiousPhase(now) == SessionPhase.cooldown;
      final remaining = session.remainingIn(now);
      final coolingSub = session.allowInCooldown
          ? 'Videos allowed • ${formatCountdown(remaining)} left'
          : 'Reels paused • ${formatCountdown(remaining)} left';
      banners.add(_AnimatedActionTile(
        icon: AppIcon.tune,
        title: cooling ? 'Curious — cooling down' : 'Curious — watching',
        subtitle: cooling
            ? coolingSub
            : 'Reels allowed • ${formatCountdown(remaining)} left',
        onTap: () => context.push(Routes.curious),
      ));
    }

    if (banners.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        children: [
          for (var i = 0; i < banners.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.xs),
            banners[i],
          ],
        ],
      ),
    );
  }
}

/// A [GlassListTile] whose leading glyph morphs on appear and replays on every
/// tap. The tile (via `AppPressable`) owns the gesture, so the icon is
/// controller-driven (`interactive: false`).
class _AnimatedActionTile extends StatefulWidget {
  const _AnimatedActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor = AppColors.accent,
  });

  final AppIcon icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  State<_AnimatedActionTile> createState() => _AnimatedActionTileState();
}

class _AnimatedActionTileState extends State<_AnimatedActionTile> {
  final AnimatedIconController _controller = AnimatedIconController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _controller
        ..reset()
        ..animate();
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GlassListTile(
      leading: AppAnimatedIcon(
        icon: widget.icon,
        size: 24,
        color: widget.iconColor,
        controller: _controller,
        playOnAppear: true,
      ),
      title: widget.title,
      subtitle: widget.subtitle,
      trailing: const Icon(Icons.chevron_right),
      onTap: _onTap,
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
    final locked = !settings.switcherEnabled();
    return SectionCard(
      title: 'Blocking plan',
      trailing: locked
          ? const Pill(label: 'Locked in cooldown', tone: AppTone.warning)
          : null,
      child: AdaptiveSegmentedControl(
        labels: labels,
        selectedIndex: selected < 0 ? 0 : selected,
        enabled: !locked,
        // Curious opens its configurable session screen; the others switch
        // the plan directly.
        onChanged: (i) {
          final plan = plans[i];
          if (plan == BlockingPlan.curious) {
            context.push(Routes.curious);
          } else {
            context.read<SettingsCubit>().setPlan(plan);
          }
        },
      ),
    );
  }
}
