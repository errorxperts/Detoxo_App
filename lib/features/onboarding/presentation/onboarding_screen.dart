import 'dart:math' as math;

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/core/services/firebase/firebase.dart';
import 'package:detoxo/features/blocking/blocking.dart';
import 'package:detoxo/features/limits/limits.dart';
import 'package:detoxo/features/onboarding/domain/entities/onboarding_progress.dart';
import 'package:detoxo/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:detoxo/features/onboarding/domain/starter_rule.dart';
import 'package:detoxo/features/onboarding/presentation/onboarding_cubit.dart';
import 'package:detoxo/features/onboarding/presentation/steps/projection_step.dart';
import 'package:detoxo/features/onboarding/presentation/steps/selection_step.dart';
import 'package:detoxo/features/onboarding/presentation/steps/survey_step.dart';
import 'package:detoxo/features/onboarding/presentation/widgets/caught_hero.dart';
import 'package:detoxo/features/onboarding/presentation/widgets/screen_time_dial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The first run: a linear, persisted step machine over the ambient gradient.
///
/// The machine itself is [OnboardingCubit]; this screen is the walker that
/// renders whatever step the cubit is on. Because every step lives inside this
/// one route, resuming is a single read — there is no partial navigation stack
/// to rebuild, and a kill at any point comes back exactly where it left off.
///
/// The last step hands off to the real [Routes.permissions] screen rather than
/// re-implementing it: that screen already owns the Play prominent-disclosure
/// dialogs, the restricted-settings recovery sheet and the unknown-state
/// handling. The starter rule is written later still, by `StarterRuleSync`,
/// when accessibility is actually granted.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OnboardingCubit(
        sl<OnboardingRepository>(),
        onStep: (step, direction) => sl<AnalyticsService>().logOnboardingStep(
          step.wire,
          direction: direction.wire,
        ),
      )..load(),
      child: const _OnboardingWalker(),
    );
  }
}

class _OnboardingWalker extends StatelessWidget {
  const _OnboardingWalker();

  /// Accent per step — the existing three-colour arc, kept.
  static Color _accent(OnboardingStepId step) => switch (step) {
    OnboardingStepId.welcome || OnboardingStepId.survey => AppColors.seed,
    OnboardingStepId.projection ||
    OnboardingStepId.selection => AppColors.onbTeal,
    _ => AppColors.onbViolet,
  };

  /// Whether Next is available. Only two steps gate: the survey needs its
  /// required answers, and the selection needs at least one feed — unless there
  /// is nothing to pick, which must not be a dead end (a device with none of
  /// the supported apps installed could otherwise never finish onboarding, and
  /// so could never leave this screen on any future launch either).
  static bool _canAdvance(OnboardingProgress p, TargetsState targets) =>
      switch (p.step) {
        OnboardingStepId.survey => SurveyStep.isComplete(p),
        OnboardingStepId.selection =>
          p.platforms.isNotEmpty || SelectionStep.nothingToPick(targets),
        _ => true,
      };

  /// Skip jumps to the selection — the first step that produces something.
  /// It disappears from there on: neither the picks nor the permissions are
  /// skippable, because without them onboarding has protected nothing.
  static bool _canSkip(OnboardingStepId step) =>
      step.index < OnboardingStepId.selection.index;

  /// Where the header bar stands. The permissions step is walked on its own
  /// screen and `completed` is terminal; both mean "the last rendered step".
  /// `indexOf(completed)` is -1, which a bare clamp would report as "Step 1 of
  /// 5" while the last step is on screen.
  static ({int index, int count}) _position(OnboardingStepId step) {
    const steps = OnboardingStepId.visible;
    final count = steps.length - 1;
    final index = switch (step) {
      OnboardingStepId.permissions || OnboardingStepId.completed => count - 1,
      _ => steps.indexOf(step).clamp(0, count - 1),
    };
    return (index: index, count: count);
  }

  Future<void> _next(BuildContext context, OnboardingProgress p) async {
    // The survey's keyboard must be down before the switcher fades a
    // soon-disposed field out from under it.
    FocusManager.instance.primaryFocus?.unfocus();
    final cubit = context.read<OnboardingCubit>();
    AppHaptics.selection();

    // Leaving the selection: push the picks into the real enabled set so the
    // native engine enforces exactly what the user just chose.
    if (p.step == OnboardingStepId.selection) {
      await context.read<SettingsCubit>().setEnabledPlatforms(p.platforms);
    }

    // `permissions` is where the walker ends. Reaching it — or RESUMING onto it
    // after a crash between `advance` and `setOnboarded` — means re-running the
    // hand-off. Without this the resumed state renders an enabled button that
    // does nothing, on a screen the user cannot tell they already passed.
    if (p.step.index >= OnboardingStepId.permissions.index ||
        cubit.nextStep == OnboardingStepId.permissions) {
      if (context.mounted) await _handOff(context, p);
      return;
    }
    final next = cubit.nextStep;
    if (next == null) return;
    await cubit.advance(next);
  }

  /// The commitment → permissions hand-off, in an order that matters.
  ///
  /// `onboarded` flips HERE, not at grant time: a user who quits on the
  /// permission screen has already answered everything, and making them replay
  /// the whole funnel to get back to a system settings toggle is the worst
  /// version of this flow. The progress record keeps `step: permissions`, which
  /// is what still arms the starter rule for the moment accessibility is
  /// granted.
  ///
  /// So the record is advanced BEFORE the flag: flipping `onboarded` notifies
  /// `AppGate` and the router redirects away on the spot, and a crash in the
  /// gap must leave an armed record rather than a user who is onboarded with
  /// nothing waiting to be created.
  Future<void> _handOff(BuildContext context, OnboardingProgress p) async {
    final cubit = context.read<OnboardingCubit>();
    final settings = context.read<SettingsCubit>();
    final dailyLimit = context.read<DailyLimitCubit>();
    final router = GoRouter.of(context);
    AppHaptics.success();
    await dailyLimit.setLimit(Duration(minutes: p.dailyLimitMinutes));
    await cubit.advance(OnboardingStepId.permissions);
    // Through the cubit, not the repository: the barrel now exports it, so the
    // old raw-repo write (and the splash round-trip that stopped a stale cubit
    // state from clobbering the flag on the next commit) is gone.
    await settings.setOnboarded(value: true);
    // Belt and braces: the gate's redirect lands on the same place by itself,
    // but this keeps the hand-off working on its own if the listener is ever
    // rewired.
    router.go(Routes.permissions);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingProgress>(
      builder: (context, p) {
        final cubit = context.read<OnboardingCubit>();
        final accent = _accent(p.step);
        final back = cubit.previousStep;
        // Watched, not read: the selection step's Next unlocks when the target
        // scan comes back empty, so the CTA has to rebuild when it lands.
        final targets = context.watch<TargetsCubit>().state;
        final isLast = p.step.index >= OnboardingStepId.commitment.index;
        final canSkip = _canSkip(p.step);
        final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
        final fade = reduce ? Duration.zero : AppDurations.fast;
        final (:index, :count) = _position(p.step);
        return PopScope(
          // Back at the first step must not drop the user out of the app
          // mid-onboarding; elsewhere it walks the machine backwards.
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && back != null) cubit.advance(back);
          },
          child: GlassScaffold(
            // Chrome is layout, not overlay: a header row and a pinned CTA
            // bound the body, so no step carries an inset to dodge them.
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Back | progress | Skip. Both ghost buttons stay mounted at
                // opacity 0/1 so the bar never jumps — and so the walker shows
                // exactly one 'Skip' (the on-device tests' finder) at a time.
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      AnimatedOpacity(
                        duration: fade,
                        opacity: back == null ? 0 : 1,
                        child: GhostButton(
                          label: 'Back',
                          onPressed: back == null
                              ? null
                              : () => cubit.advance(back),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                          child: ProgressBar(
                            progress: (index + 1) / count,
                            height: 6,
                            animate: true,
                            semanticLabel: 'Step ${index + 1} of $count',
                          ),
                        ),
                      ),
                      AnimatedOpacity(
                        duration: fade,
                        opacity: canSkip ? 1 : 0,
                        child: GhostButton(
                          label: 'Skip',
                          onPressed: canSkip
                              ? () => cubit.advance(OnboardingStepId.selection)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  // A cross-fade only: each step carries its own staggered
                  // rise (`EntranceList`), so a second axis here would fight it.
                  child: AnimatedSwitcher(
                    duration: reduce ? Duration.zero : AppDurations.normal,
                    switchInCurve: AppCurves.decelerate,
                    switchOutCurve: AppCurves.standard,
                    child: KeyedSubtree(
                      key: ValueKey(p.step),
                      child: _StepBody(
                        center:
                            p.step == OnboardingStepId.welcome ||
                            p.step == OnboardingStepId.projection,
                        child: _step(p, accent),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: PrimaryButton(
                    label: isLast ? 'Get started' : 'Next',
                    tint: accent,
                    expand: true,
                    onPressed: _canAdvance(p, targets)
                        ? () => _next(context, p)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _step(OnboardingProgress p, Color accent) => switch (p.step) {
    OnboardingStepId.welcome => _WelcomeStep(accent: accent),
    OnboardingStepId.survey => SurveyStep(progress: p),
    OnboardingStepId.projection => ProjectionStep(progress: p),
    OnboardingStepId.selection => SelectionStep(progress: p),
    // `permissions` and `completed` are hand-off states, not screens — but the
    // record advances to `permissions` a beat before the redirect fires, so
    // holding the last real step here keeps that beat from flashing blank.
    _ => _CommitmentStep(progress: p, accent: accent),
  };
}

/// The scroll frame every step renders inside. Short content sits centred
/// ([center]) or at the top; long content — large text, many apps, a keyboard
/// — scrolls. The padding lives here, so no step carries an inset of its own.
class _StepBody extends StatelessWidget {
  const _StepBody({required this.child, this.center = false});

  final Widget child;
  final bool center;

  static const _pad = EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.sm,
    AppSpacing.lg,
    AppSpacing.md,
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: _pad,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: c.hasBoundedHeight
                ? math.max(0, c.maxHeight - _pad.vertical)
                : 0,
          ),
          child: center ? Center(child: child) : child,
        ),
      ),
    );
  }
}

/// The first step: the coded hero, the headline and one line of promise.
class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return EntranceList(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CaughtHero(accent: accent),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Take your time back',
          textAlign: TextAlign.center,
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'You didn’t decide to watch 80 reels — the feed did. Detoxo spots '
          'them the second they play and pulls you back out, right inside the '
          'apps you already use.',
          textAlign: TextAlign.center,
          style: text.bodyLarge?.copyWith(color: context.glass.onGlass),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Pill(
          label: 'Blocks the reels, not the app',
          tone: AppTone.accent,
        ),
      ],
    );
  }
}

/// The last walked step: what the user is committing to, in their own terms
/// (one header + one panel), and the daily-limit dial under its own header.
class _CommitmentStep extends StatelessWidget {
  const _CommitmentStep({required this.progress, required this.accent});

  final OnboardingProgress progress;
  final Color accent;

  /// The promise, rendered FROM the preset that `starterRule` will actually
  /// stamp — not restated in prose. The hours already live in `RulePreset`, and
  /// `starter_rule.dart` exists precisely so there is one copy of them; writing
  /// "22:00" here again would be a third, in the one place no test asserts it.
  /// The icon is keyed off the same shape, so the card reads at a glance.
  ({IconData icon, String text}) get _rule {
    final template = starterPreset(progress.mattersMost).template;
    final schedule = template.schedule;
    if (schedule == null) {
      final minutes = template.thresholdMs ~/ 60000;
      return (
        icon: Icons.hourglass_bottom_rounded,
        text:
            '$minutes minutes of feed a day. After that the feeds you picked '
            'stop opening until tomorrow.',
      );
    }
    final daily = schedule.days.length == 7;
    return (
      icon: daily ? Icons.bedtime_rounded : Icons.work_rounded,
      text:
          '${daily ? 'Every day' : 'Weekdays'} from '
          '${RuleSchedule.formatHHmm(schedule.startMin)}, the feeds you picked '
          'stop opening — until ${RuleSchedule.formatHHmm(schedule.endMin)}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = progress.name;
    final rule = _rule;
    return EntranceList(
      children: [
        Text(
          name == null ? 'Here’s the deal' : 'Here’s the deal, $name',
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SectionHeader('Your first rule'),
        GlassCard(
          child: Row(
            children: [
              IconBadge(
                icon: rule.icon,
                color: accent,
                bordered: true,
                fillAlpha: 0.20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  rule.text,
                  style: text.bodyMedium?.copyWith(
                    color: context.glass.onGlass,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SectionHeader('Daily ceiling'),
        Center(
          child: ScreenTimeDial(
            value: Duration(minutes: progress.dailyLimitMinutes),
            onChanged: context.read<OnboardingCubit>().setDailyLimit,
            accent: accent,
            size: 240,
          ),
        ),
      ],
    );
  }
}
