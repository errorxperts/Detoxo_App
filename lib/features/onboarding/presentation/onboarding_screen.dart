import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/di/injector.dart';
import 'package:detoxo/core/navigation/routes.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:detoxo/features/limits/daily_limit/presentation/daily_limit_cubit.dart';
import 'package:detoxo/features/onboarding/presentation/widgets/caught_hero.dart';
import 'package:detoxo/features/onboarding/presentation/widgets/commitment_hero.dart';
import 'package:detoxo/features/onboarding/presentation/widgets/plan_preview.dart';
import 'package:detoxo/features/onboarding/presentation/widgets/screen_time_dial.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Which hero a page renders. Each maps to a coded illustration built from the
/// design system (no bespoke assets) — the limit step keeps its own dial.
enum _HeroKind { welcome, caught, plans, limit, stick }

class _Page {
  const _Page({
    required this.accent,
    required this.kind,
    required this.title,
    required this.body,
  });

  final Color accent;
  final _HeroKind kind;

  /// Headline.
  final String title;

  /// Description — carries the problem→solution beat in one breath.
  final String body;

  bool get isLimitStep => kind == _HeroKind.limit;
}

/// A value-first intro funnel over the ambient gradient. Five problem→solution
/// beats, ending by marking the user onboarded, seeding the daily limit and
/// moving on to the permission flow. Deep per-feature teaching is deferred to
/// the in-context dashboard showcase.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  /// The user's picked daily limit (null until they drag → default is used).
  Duration? _draftLimit;

  /// Seeds the ring's daily max; the user drags the dial from here. Tunable
  /// later in the Daily-limit screen.
  static const _defaultLimit = Duration(minutes: 90);

  static final List<_Page> _pages = [
    const _Page(
      accent: AppColors.seed,
      kind: _HeroKind.welcome,
      title: 'Take your time back',
      body:
          'Short-form video is built to never end. Detoxo is built to help you step out — gently, in the moment.',
    ),
    const _Page(
      accent: AppColors.seed,
      kind: _HeroKind.caught,
      title: 'Caught the moment it starts',
      body:
          'You didn’t decide to watch 80 reels — the feed did. Detoxo spots them the second they play and pulls you back out, right inside the apps you already use.',
    ),
    const _Page(
      accent: AppColors.onbTeal,
      kind: _HeroKind.plans,
      title: 'Not all-or-nothing',
      body:
          'Hard blocks feel like punishment — so you cave. Detoxo gives you five ways to change, so it fits how you actually want to.',
    ),
    const _Page(
      accent: AppColors.onbTeal,
      kind: _HeroKind.limit,
      title: 'See the number, set the line',
      body:
          'Detoxo counts every reel live, on your device — then fills toward the daily limit you set. Change it anytime.',
    ),
    const _Page(
      accent: AppColors.onbViolet,
      kind: _HeroKind.stick,
      title: 'Make it stick',
      body:
          'The urge comes back at 11pm — willpower alone won’t hold. A PIN, uninstall protection and an always-on guard keep future-you honest.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final settings = sl<SettingsRepository>();
    // Seed the dashboard ring's daily limit from the quick-pick (or the default
    // if the step was skipped) through the app-wide cubit, so the dashboard
    // reflects it live — setLimit persists + emits on the shared instance.
    final dailyLimit = context.read<DailyLimitCubit>();
    AppHaptics.success();
    await settings.save((await settings.load()).copyWith(onboarded: true));
    await dailyLimit.setLimit(_draftLimit ?? _defaultLimit);
    if (mounted) context.go(Routes.permissions);
  }

  void _next() {
    if (_index == _pages.length - 1) {
      _finish();
    } else {
      _controller.nextPage(
        duration: AppDurations.medium,
        curve: AppCurves.standard,
      );
    }
  }

  void _back() {
    if (_index == 0) return;
    _controller.previousPage(
      duration: AppDurations.medium,
      curve: AppCurves.standard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;
    return GlassScaffold(
      safeArea: false,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            // The limit step owns its drag gestures (the dial), so suspend the
            // horizontal page swipe there — Back/Next still navigate.
            physics: _pages[_index].isLimitStep
                ? const NeverScrollableScrollPhysics()
                : null,
            onPageChanged: (i) {
              setState(() => _index = i);
              AppHaptics.selection();
            },
            itemBuilder: (context, i) {
              final page = _pages[i];
              return switch (page.kind) {
                _HeroKind.limit => _LimitStep(
                  page: page,
                  value: _draftLimit ?? _defaultLimit,
                  onChanged: (d) => setState(() => _draftLimit = d),
                ),
                _HeroKind.plans => _PlansPage(page: page),
                _ => _PageView(page: page, controller: _controller, index: i),
              };
            },
          ),
          // Skip — fades out on the last page.
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: AnimatedOpacity(
                duration: AppDurations.fast,
                opacity: isLast ? 0 : 1,
                child: GhostButton(
                  label: 'Skip',
                  onPressed: isLast ? null : _finish,
                ),
              ),
            ),
          ),
          // Back — appears from the second page onward (screen readers can't use
          // the PageView swipe to go back).
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: AnimatedOpacity(
                duration: AppDurations.fast,
                opacity: _index == 0 ? 0 : 1,
                child: GhostButton(
                  label: 'Back',
                  onPressed: _index == 0 ? null : _back,
                ),
              ),
            ),
          ),
          // Progress + primary CTA, overlaid at the bottom.
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ProgressBar(
                      count: _pages.length,
                      index: _index,
                      accent: _pages[_index].accent,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: isLast ? 'Get started' : 'Next',
                      tint: _pages[_index].accent,
                      expand: true,
                      onPressed: _next,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Segmented filling progress bar — clearer completion cue than dots. Each
/// segment fills with the current accent as the user advances.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.count,
    required this.index,
    required this.accent,
  });

  final int count;
  final int index;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Step ${index + 1} of $count',
      child: Row(
        children: List.generate(count, (i) {
          final filled = i <= index;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: i == count - 1 ? 0 : AppSpacing.xs,
              ),
              child: AnimatedContainer(
                duration: AppDurations.normal,
                curve: AppCurves.standard,
                height: 6,
                decoration: BoxDecoration(
                  color: filled ? accent : context.glass.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Welcome / caught / stick pages: a coded hero, headline, body and an optional
/// footer, with the hero drifting slower than the swipe (parallax).
class _PageView extends StatelessWidget {
  const _PageView({
    required this.page,
    required this.controller,
    required this.index,
  });

  final _Page page;
  final PageController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 96, AppSpacing.xl, 168),
      child: ListView(
        // mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Parallax: the illustration drifts slower than the swipe.
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final page = controller.positions.isEmpty
                  ? index.toDouble()
                  : (controller.page ?? 0);
              final delta = (page - index) * 60;
              return Transform.translate(
                offset: Offset(delta, 0),
                child: child,
              );
            },
            child: _hero(),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
                page.title,
                textAlign: TextAlign.center,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              )
              .animate(key: ValueKey('t$index'))
              .fadeIn(delay: 80.ms)
              .slideY(begin: 0.15, end: 0),
          const SizedBox(height: AppSpacing.md),
          Text(
                page.body,
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: context.glass.onGlass),
              )
              .animate(key: ValueKey('b$index'))
              .fadeIn(delay: 160.ms)
              .slideY(begin: 0.15, end: 0),
          ?_footer(context),
        ],
      ),
    );
  }

  Widget _hero() => switch (page.kind) {
    _HeroKind.welcome => _WelcomeHero(accent: page.accent),
    _HeroKind.caught => CaughtHero(accent: page.accent),
    _HeroKind.stick => CommitmentHero(accent: page.accent),
    _ => const SizedBox.shrink(),
  };

  Widget? _footer(BuildContext context) => switch (page.kind) {
    _HeroKind.caught => const Padding(
      padding: EdgeInsets.only(top: AppSpacing.lg),
      child: Pill(label: 'Blocks the reels, not the app', tone: AppTone.accent),
    ),
    _HeroKind.stick => const Padding(
      padding: EdgeInsets.only(top: AppSpacing.xl),
      child: EntranceList(
        children: [
          _Benefit(Icons.pin_rounded, 'PIN lock, with fingerprint or face'),
          _Benefit(Icons.shield_moon_outlined, 'Optional uninstall protection'),
          _Benefit(Icons.bolt_rounded, 'Always on — even after a restart'),
        ],
      ),
    ),
    _ => null,
  };
}

/// The welcome hero: the brand mark in a soft accent halo, breathing slowly.
class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Widget logo = SizedBox(
      height: 150,
      child: Assets.images.detoxLogoNoBg.image(fit: BoxFit.contain),
    );
    if (!reduceMotion) {
      logo = logo
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
            begin: 1,
            end: 1.04,
            duration: AppDurations.slow,
            curve: AppCurves.gentle,
          );
    }
    return Container(
      height: 220,
      width: 220,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [accent.withValues(alpha: 0.35), accent.withValues(alpha: 0)],
        ),
      ),
      child: logo,
    );
  }
}

/// A single benefit row on the "make it stick" page.
class _Benefit extends StatelessWidget {
  const _Benefit(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(
            icon: icon,
            size: 32,
            color: AppColors.onbViolet,
            fillAlpha: 0.18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.glass.onGlass),
            ),
          ),
        ],
      ),
    );
  }
}

/// The flexible-plans page: headline, body and the interactive [PlanPreview].
class _PlansPage extends StatelessWidget {
  const _PlansPage({required this.page});

  final _Page page;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 96, AppSpacing.lg, 168),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: context.glass.onGlass),
          ),
          const SizedBox(height: AppSpacing.xl),
          PlanPreview(accent: page.accent),
        ],
      ),
    );
  }
}

/// The one interactive value step: a live reel count-up (the on-device counter,
/// made tangible) above the [ScreenTimeDial] the user drags to set a daily
/// short-form limit. The value seeds the dashboard ring's max in
/// [_OnboardingScreenState._finish].
class _LimitStep extends StatelessWidget {
  const _LimitStep({
    required this.page,
    required this.value,
    required this.onChanged,
  });

  final _Page page;
  final Duration value;
  final ValueChanged<Duration> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 72, AppSpacing.lg, 158),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: context.glass.onGlass),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _ReelCountUp(),
          const SizedBox(height: AppSpacing.lg),
          ScreenTimeDial(
            value: value,
            onChanged: onChanged,
            accent: page.accent,
          ),
        ],
      ),
    );
  }
}

/// A small "reels today" ticker that counts up once — surfacing the on-device
/// counter/bubble/widget as a tangible number. Respects reduce-motion.
class _ReelCountUp extends StatelessWidget {
  const _ReelCountUp();

  static const _sample = 84; // an illustrative daily average, not live data

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const IconBadge(icon: Icons.blur_circular, size: 34),
        const SizedBox(width: AppSpacing.sm),
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: reduceMotion ? _sample : 0, end: _sample),
          duration: AppDurations.slow,
          curve: AppCurves.standard,
          builder: (context, v, _) => ShaderMask(
            shaderCallback: (b) => context.metricGradient.createShader(b),
            blendMode: BlendMode.srcIn,
            child: Text(
              '$v',
              style: text.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'reels a day, typically',
          style: text.bodySmall?.copyWith(color: context.glass.onGlassMuted),
        ),
      ],
    );
  }
}
