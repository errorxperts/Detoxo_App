import 'dart:async';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/widgets/common_widgets.dart';
import 'package:detoxo/features/additional_feature/showcase_view/showcase_view.dart';
import 'package:detoxo/features/blocking/engine/presentation/service_cubit.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/session_defaults.dart';
import 'package:detoxo/features/blocking/plans/presentation/conscious_cubit.dart';
import 'package:detoxo/features/blocking/plans/presentation/widgets/session_dialogs.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
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

class DashboardTab extends StatefulWidget {
  const DashboardTab({this.scrollController, this.onMenu, super.key});

  final ScrollController? scrollController;

  /// Opens the right-side app drawer (former "More" tab).
  final VoidCallback? onMenu;

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  /// The one-time feature tour runs as soon as the dashboard is front-most and
  /// `hasSeenFeatureShowcase` is false. We keep it "pending" and poll for the
  /// dashboard becoming current, so a replay requested from Settings reliably
  /// starts once we navigate back here — without depending on this widget
  /// rebuilding (go_router may reuse the existing element).
  bool _tourPending = false;
  bool _tourRunning = false;
  int _startAttempts = 0;

  /// Frame budget to wait for the dashboard to become front-most (~2s at 60fps)
  /// before giving up; a fresh dashboard mount retries from scratch.
  static const _maxStartAttempts = 120;

  @override
  void initState() {
    super.initState();
    _queueTour();
  }

  /// (Re)arms the tour and kicks off the first start attempt.
  void _queueTour() {
    _tourPending = true;
    _tourRunning = false;
    _startAttempts = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryStartTour());
  }

  void _tryStartTour() {
    if (!mounted || !_tourPending || _tourRunning) return;
    if (context.read<SettingsCubit>().state.hasSeenFeatureShowcase) {
      _tourPending = false;
      return;
    }
    // Defer until the dashboard is the front-most route (e.g. after returning
    // from Settings for a replay), retrying each frame within the budget.
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) {
      if (_startAttempts++ < _maxStartAttempts) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _tryStartTour());
      } else {
        _tourPending = false; // give up; a fresh mount will retry next time
      }
      return;
    }
    _tourPending = false;
    _tourRunning = true;
    startFeatureTour();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SettingsCubit, AppSettings>(
      // Replay edge: Settings flips the flag true→false to request a fresh run.
      listenWhen: (p, c) => p.hasSeenFeatureShowcase && !c.hasSeenFeatureShowcase,
      listener: (_, _) => _queueTour(),
      child: RefreshIndicator(
        onRefresh: () => context.read<ServiceCubit>().refresh(),
        child: ListView(
          controller: widget.scrollController,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.floatingNavClearance +
                MediaQuery.viewPaddingOf(context).bottom,
          ),
          children: [
            DashboardTopBar(onMenu: widget.onMenu),
            const SizedBox(height: AppSpacing.lg),
            const _Hero()
                .animate()
                .fadeIn(duration: AppDurations.normal)
                .slideY(begin: 0.08, end: 0),
            const SizedBox(height: AppSpacing.md),
            const _SessionBanners(),
            const ProtectionStatusCard(),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: showcaseTarget(
                    step: featureShowcaseSteps[3],
                    index: 3,
                    child: BlockerCapsule(
                      icon: AppIcon.appBlocker,
                      title: 'App Blocker',
                      caption: 'Restricted',
                      onTap: () => context.push(Routes.appBlock),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: showcaseTarget(
                    step: featureShowcaseSteps[4],
                    index: 4,
                    child: BlockerCapsule(
                      icon: AppIcon.websiteBlocker,
                      title: 'Web Blocker',
                      caption: 'Active',
                      accent: Theme.of(context).colorScheme.secondary,
                      onTap: () => context.push(Routes.webBlock),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The Command Center hero. Stateful so it can run a 1 Hz ticker while a Pause
/// session is live — the pause's remaining time decrements every second without
/// a cubit emit, so the card must tick itself. Conscious self-emits each second
/// (the native bank is pushed), so it rides the normal rebuild.
class _Hero extends StatefulWidget {
  const _Hero();

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  Timer? _ticker;

  void _syncTicker({required bool pauseLive}) {
    if (pauseLive && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!pauseLive && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = context.watch<ServiceCubit>().state;
    final settings = context.watch<SettingsCubit>().state;
    final now = DateTime.now();
    final pauseLive = settings.isPauseContractLive(now);
    _syncTicker(pauseLive: pauseLive);

    SessionCountdown? countdown;
    if (pauseLive) {
      final session = settings.pauseSession!;
      final remaining = session.remainingIn(now);
      final total = session.phaseLengthAt(now).inMilliseconds;
      countdown = SessionCountdown(
        progress: total <= 0
            ? 0.0
            : (remaining.inMilliseconds / total).clamp(0.0, 1.0),
        remaining: remaining,
        caption: 'apps allowed',
        tone: AppTone.warning,
        icon: AppIcon.pause,
      );
    } else if (settings.activePlan == BlockingPlan.curious) {
      final c = context.watch<ConsciousCubit>().state;
      countdown = SessionCountdown(
        progress: c.progress,
        remaining: c.banked,
        caption: c.watching
            ? 'spending'
            : (c.hasAllowance ? 'banked' : 'earning'),
      );
    }

    return CommandCenterCard(
      timeSaved: _formatTimeSaved(snapshot.blocksTotal),
      progress: (snapshot.blocksToday / _dailyBlockGoal).clamp(0.0, 1.0),
      statusLabel: _statusLabel(settings.activePlan, pauseLive: pauseLive),
      blockedValue: '${snapshot.blocksToday}',
      streakValue: '$_placeholderStreak',
      modeOptions: _modeOptions,
      selectedMode: _selectedMode(settings.activePlan, pauseLive: pauseLive),
      onModeChanged: (i) => unawaited(_onModeChanged(context, i)),
      // Spotlight each mode cell (Block All / Conscious / Pause) during the
      // feature tour; identity when the tour isn't running.
      modeCellBuilder: (i, cell) =>
          showcaseTarget(step: featureShowcaseSteps[i], index: i, child: cell),
      countdown: countdown,
    );
  }
}

/// Block All switches the plan directly; Conscious and Pause open their global
/// glass dialogs (the dedicated screens were retired).
Future<void> _onModeChanged(BuildContext context, int index) async {
  switch (index) {
    case 0:
      await context.read<SettingsCubit>().setPlan(BlockingPlan.blockAll);
    case 1:
      await SessionDialogs.showConscious(context);
    case 2:
      await SessionDialogs.showPause(context);
  }
}

int _selectedMode(BlockingPlan plan, {required bool pauseLive}) {
  if (pauseLive) return 2;
  return switch (plan) {
    BlockingPlan.blockAll => 0,
    BlockingPlan.curious => 1,
    BlockingPlan.paused => 2,
    BlockingPlan.oneReel => -1, // not represented in the hero toggle
  };
}

String _statusLabel(BlockingPlan plan, {required bool pauseLive}) {
  if (pauseLive) return 'PAUSED';
  return switch (plan) {
    BlockingPlan.blockAll => 'BLOCK ALL',
    BlockingPlan.curious => 'CONSCIOUS',
    BlockingPlan.oneReel => 'ONE REEL',
    BlockingPlan.paused => 'PAUSED',
  };
}

String _formatTimeSaved(int blocks) {
  final totalMinutes = (blocks * _secondsSavedPerBlock / 60).round();
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  return h == 0 ? '${m}m' : '${h}h ${m}m';
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
      final remaining = settings.pauseSession!.remainingIn(now);
      banners.add(
        _AnimatedActionTile(
          icon: AppIcon.pause,
          iconColor: AppColors.warning,
          title: 'Paused',
          subtitle: 'All apps allowed • ${formatCountdown(remaining)} left',
          onTap: () => unawaited(SessionDialogs.showPause(context)),
        ),
      );
    }

    if (settings.activePlan == BlockingPlan.curious) {
      final c = context.watch<ConsciousCubit>().state;
      final String title;
      final String subtitle;
      if (c.watching) {
        title = 'Conscious — spending';
        subtitle = 'Watching • ${formatCountdown(c.banked)} left';
      } else if (c.hasAllowance) {
        title = 'Conscious — ready';
        subtitle = '${formatCountdown(c.banked)} banked • open reels to spend';
      } else {
        title = 'Conscious — earning';
        subtitle = 'Reels blocked • earn ${SessionDefaults.consciousEarnLabel}';
      }
      banners.add(
        _AnimatedActionTile(
          icon: AppIcon.shieldCheck,
          title: title,
          subtitle: subtitle,
          onTap: () => unawaited(SessionDialogs.showConscious(context)),
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
