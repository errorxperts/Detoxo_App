import 'dart:async';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/blocking/engine/presentation/service_cubit.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:detoxo/features/dashboard/presentation/widgets/blocker_capsule.dart';
import 'package:detoxo/features/dashboard/presentation/widgets/command_center_card.dart';
import 'package:detoxo/features/dashboard/presentation/widgets/dashboard_top_bar.dart';
import 'package:detoxo/features/dashboard/presentation/widgets/mode_toggle.dart';
import 'package:detoxo/features/dashboard/presentation/widgets/protection_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// Placeholder constants for metrics the app doesn't track yet. Time Saved is
// derived from real block counts at a rough per-block estimate; Streak and the
// ring's daily goal are stand-ins until proper tracking lands.
// TODO(metrics): replace with measured time-saved + a real streak + a
// user-configurable daily goal.
const int _secondsSavedPerBlock = 30;
const int _dailyBlockGoal = 50;
const int _placeholderStreak = 12;

/// The three hero modes. "Conscious" relabels the existing `curious` plan;
/// "Pause" routes into the dedicated mindful-pause flow.
const _modeOptions = [
  ModeOption(icon: AppIcon.ban, label: 'Block All'),
  ModeOption(icon: AppIcon.shieldCheck, label: 'Conscious'),
  ModeOption(icon: AppIcon.pause, label: 'Pause'),
];

class DashboardTab extends StatelessWidget {
  const DashboardTab({this.scrollController, super.key});

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final snapshot = context.watch<ServiceCubit>().state;
    final settings = context.watch<SettingsCubit>().state;
    final now = DateTime.now();
    final pauseLive = settings.isPauseContractLive(now);

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
          const DashboardTopBar(),
          const SizedBox(height: AppSpacing.lg),
          CommandCenterCard(
            timeSaved: _formatTimeSaved(snapshot.blocksTotal),
            progress: (snapshot.blocksToday / _dailyBlockGoal).clamp(0.0, 1.0),
            statusLabel: _statusLabel(settings.activePlan, pauseLive: pauseLive),
            blockedValue: '${snapshot.blocksToday}',
            streakValue: '$_placeholderStreak',
            modeOptions: _modeOptions,
            selectedMode: _selectedMode(settings.activePlan, pauseLive: pauseLive),
            modeEnabled: settings.switcherEnabled(now),
            onModeChanged: (i) => _onModeChanged(context, i),
          ).animate().fadeIn(duration: AppDurations.normal).slideY(begin: 0.08, end: 0),
          const SizedBox(height: AppSpacing.md),
          const _SessionBanners(),
          const ProtectionStatusCard(),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: BlockerCapsule(
                  icon: AppIcon.appBlocker,
                  title: 'App Blocker',
                  caption: 'Restricted',
                  onTap: () => context.push(Routes.appBlock),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: BlockerCapsule(
                  icon: AppIcon.websiteBlocker,
                  title: 'Web Blocker',
                  caption: 'Active',
                  accent: Theme.of(context).colorScheme.secondary,
                  onTap: () => context.push(Routes.webBlock),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Block All / Conscious switch the plan directly; Conscious opens its
  /// configurable session screen and Pause opens the mindful-pause flow —
  /// mirroring the old plan selector's routing.
  static void _onModeChanged(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.read<SettingsCubit>().setPlan(BlockingPlan.blockAll);
      case 1:
        context.push(Routes.curious);
      case 2:
        context.push(Routes.pause);
    }
  }

  static int _selectedMode(BlockingPlan plan, {required bool pauseLive}) {
    if (pauseLive) return 2;
    return switch (plan) {
      BlockingPlan.blockAll => 0,
      BlockingPlan.curious => 1,
      BlockingPlan.paused => 2,
      BlockingPlan.oneReel => -1, // not represented in the hero toggle
    };
  }

  static String _statusLabel(BlockingPlan plan, {required bool pauseLive}) {
    if (pauseLive) return 'PAUSED';
    return switch (plan) {
      BlockingPlan.blockAll => 'BLOCK ALL',
      BlockingPlan.curious => 'CONSCIOUS',
      BlockingPlan.oneReel => 'ONE REEL',
      BlockingPlan.paused => 'PAUSED',
    };
  }

  static String _formatTimeSaved(int blocks) {
    final totalMinutes = (blocks * _secondsSavedPerBlock / 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return h == 0 ? '${m}m' : '${h}h ${m}m';
  }
}

/// Shown beneath the hero while a Pause or Curious contract is live. Owns a
/// 1 Hz ticker so the remaining time counts down (the cubit only emits on phase
/// changes, not every second).
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
      banners.add(
        _AnimatedActionTile(
          icon: AppIcon.pause,
          iconColor: AppColors.warning,
          title: cooling ? 'Winding down' : 'Paused',
          subtitle: 'Reels allowed • ${formatCountdown(remaining)} left',
          onTap: () => context.push(Routes.pause),
        ),
      );
    }

    if (settings.isCuriousContractLive(now)) {
      final session = settings.curiousSession!;
      final cooling = settings.curiousPhase(now) == SessionPhase.cooldown;
      final remaining = session.remainingIn(now);
      final coolingSub = session.allowInCooldown
          ? 'Videos allowed • ${formatCountdown(remaining)} left'
          : 'Reels paused • ${formatCountdown(remaining)} left';
      banners.add(
        _AnimatedActionTile(
          icon: AppIcon.shieldCheck,
          title: cooling ? 'Conscious — cooling down' : 'Conscious — watching',
          subtitle: cooling ? coolingSub : 'Reels allowed • ${formatCountdown(remaining)} left',
          onTap: () => context.push(Routes.curious),
        ),
      );
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
/// controller-driven.
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
