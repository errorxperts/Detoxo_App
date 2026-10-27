import 'dart:async';

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/additional_feature/app_feedback/app_feedback.dart';
import 'package:detoxo/features/additional_feature/showcase_view/showcase_view.dart';
import 'package:detoxo/features/blocking/engine/presentation/service_cubit.dart';
import 'package:detoxo/features/blocking/plans/presentation/conscious_cubit.dart';
import 'package:detoxo/features/blocking/plans/presentation/reel_session_cubit.dart';
import 'package:detoxo/features/blocking/plans/presentation/widgets/session_dialogs.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_settings.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/presentation/settings_cubit.dart';
import 'package:detoxo/features/content_counter/content_counter_core/presentation/content_counter_cubit.dart';
import 'package:detoxo/features/dashboard/presentation/today_copy.dart';
import 'package:detoxo/features/dashboard/presentation/widgets/blocker_section.dart';
import 'package:detoxo/features/limits/daily_limit/presentation/daily_limit_cubit.dart';
import 'package:detoxo/features/limits/streak/presentation/streak_cubit.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({this.onMenu, super.key});

  /// Opens the sidebar.
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
        onRefresh: () => Future.wait([
          context.read<ServiceCubit>().refresh(),
          context.read<ContentCounterCubit>().refresh(),
        ]),
        // One short page, built whole: every section mounts once, so each
        // rises in once, and the lights get a box that scrolls with it.
        child: SingleChildScrollView(
          child: Stack(
            children: [
              // V02 measures the lights from the screen top, headerTop above
              // the header; this box starts only `inset` above it.
              const Positioned.fill(
                top: AppSpacing.inset - AppSpacing.headerTop,
                child: AmbientLights(),
              ),
              Padding(
                padding: TabHeader.listPadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TabHeader(
                      title: 'Detoxo',
                      onMenu: widget.onMenu,
                      // Hidden unless the feedback button is switched on.
                      actions: const [FeedbackActionButton()],
                    ),
                    const SizedBox(height: AppSpacing.gap),
                    const _TodayLive().entrance(),
                    const SizedBox(height: AppSpacing.section),
                    const BlockerSection().entrance(delay: AppDurations.stagger),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The modes in tour order: option `i` is feature-tour step `i`.
final _modes = <ModeOption>[
  (icon: Assets.images.icons.iconBlockAll, label: 'Block All'),
  (icon: Assets.images.icons.iconConscious, label: 'Conscious'),
  (icon: Assets.images.icons.iconOneReel, label: 'One Reel'),
  (icon: Assets.images.icons.iconPause, label: 'Pause'),
  (icon: Assets.images.icons.iconReelCount, label: 'Unblock'),
];

/// Today's live half: the [TimeLeftRing] with the reels and streak line, then
/// the [ModeCard]. Every word comes from `today_copy.dart`.
///
/// Stateful for one 1 Hz ticker, run only while a Pause is live: its time
/// left falls every second without a cubit emit. Conscious self-emits each
/// second (the native bank is pushed), so it rides the normal rebuild.
class _TodayLive extends StatefulWidget {
  const _TodayLive();

  @override
  State<_TodayLive> createState() => _TodayLiveState();
}

class _TodayLiveState extends State<_TodayLive> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Usage time advances between counted reels (the event stream only fires on
    // a count), so pull a fresh counter snapshot when the hero first mounts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<ContentCounterCubit>().refresh());
    });
  }

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

  /// Ends a Pause, an N-reel unblock or One Reel now, with no confirm: it
  /// only makes blocking stricter.
  Future<void> _blockNow() {
    final settings = context.read<SettingsCubit>();
    return settings.state.isPauseContractLive()
        ? settings.resumeNow()
        : settings.setPlan(settings.state.baseMode);
  }

  /// Block All and One Reel are direct; Conscious opens its sheet, intro or
  /// live; Pause opens the Session sheet By time; Unblock opens
  /// the Session sheet By reel count. A repeat tap on the lit One Reel, Pause
  /// or Unblock blocks now; on Block All it does nothing.
  Future<void> _select(int i, {required int lit}) async {
    if (i == lit && i != 1) {
      if (i != 0) await _blockNow();
      return;
    }
    await switch (i) {
      0 => context.read<SettingsCubit>().setPlan(BlockingPlan.blockAll),
      1 => SessionDialogs.showConscious(context),
      2 => _oneReel(),
      3 => SessionDialogs.showPause(context),
      _ => SessionDialogs.showReels(context),
    };
  }

  /// One Reel starts at once (the user dropped its confirm): a single reel,
  /// then the base mode returns by itself. The toast offers Undo.
  Future<void> _oneReel() async {
    await context.read<SettingsCubit>().setOneReel(count: 1);
    if (!mounted) return;
    GlassToast.show(
      context,
      'One reel unblocked',
      action: (
        label: 'Undo',
        onPressed: () {
          if (mounted) unawaited(_blockNow());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state;
    final counter = context.watch<ContentCounterCubit>().state;
    final daily = context.watch<DailyLimitCubit>().state;
    final streak = context.watch<StreakCubit>().state;
    final reel = context.watch<ReelSessionCubit>().state;
    final now = DateTime.now();
    final pauseLive = settings.isPauseContractLive(now);
    _syncTicker(pauseLive: pauseLive);

    // Before the first native snapshot (`loaded == false`) `enabled` is only
    // a placeholder: render the ring normally, but commit nothing on it.
    final loaded = counter.loaded;
    final measured = counter.enabled;
    final spent = counter.timeToday;
    final limit = daily.limit;
    final hasLimit = limit > Duration.zero;
    final overLimit = measured && hasLimit && spent >= limit;
    // Advance the "days under your daily limit" streak once today's under/over
    // status is known — post-frame so we don't emit during build. Nothing
    // measured (counting off, or the counter / the limit not read yet) =
    // nothing to observe: an unmeasured day must not count as a day under the
    // limit, and an unloaded limit (`dateSignature` empty — `load()` always
    // stamps today's) reads as "no limit" and would mark today failed.
    final underLimit = hasLimit && !overLimit;
    final limitLoaded = daily.dateSignature.isNotEmpty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && loaded && limitLoaded && measured) {
        context.read<StreakCubit>().observe(now: now, underLimit: underLimit);
      }
    });

    final lit = modeIndex(settings, pauseLive: pauseLive);
    final pause = pauseLive ? settings.pauseSession : null;
    // The native session owns the count; until its first push, the target.
    final reels = lit == 4
        ? reel.active
              ? (left: reel.remaining, total: reel.allowance)
              : (left: settings.reelAllowance, total: settings.reelAllowance)
        : null;
    final face = ringFace(
      loaded: loaded,
      measured: measured,
      spent: spent,
      limit: limit,
      now: now,
      pause: pause,
      reels: reels,
    );
    final copy = modeCopy(
      index: lit,
      masterOn: settings.masterEnabled,
      now: now,
      pause: pause,
      reels: reels,
      // Only Conscious shows the bank, so only it rebuilds on the bank's tick.
      conscious: lit == 1 ? context.select((ConsciousCubit c) => c.state) : null,
    );
    // The stored streak isn't reconciled while counting is off (a resumed
    // gap resets it), so its provisional count would go stale — dash it.
    final off = loaded && !measured;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TimeLeftRing(
          // Remounts once the counter and the limit are read, so the
          // one-time count-up plays on the real numbers.
          key: ValueKey(loaded && limitLoaded),
          eyebrow: face.eyebrow,
          live: face.live,
          value: face.value,
          format: face.format,
          sub: face.sub,
          progress: face.progress,
          reels: off ? null : counter.today,
          streak: off ? null : streak.count,
        ),
        const SizedBox(height: AppSpacing.lg),
        ModeCard(
          options: _modes,
          selectedIndex: lit,
          onSelected: (i) => unawaited(_select(i, lit: lit)),
          title: copy?.title,
          detail: copy?.detail,
          // Spotlights each mode during the feature tour; identity otherwise.
          decorateOption: (i, option) =>
              showcaseTarget(step: featureShowcaseSteps[i], index: i, child: option),
        ),
      ],
    );
  }
}
