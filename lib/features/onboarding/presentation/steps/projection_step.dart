import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/onboarding/domain/entities/onboarding_progress.dart';
import 'package:flutter/material.dart';

/// The cost of the answer the user just gave, in the only unit that lands:
/// whole days, counted up rather than stated, inside the same ring the
/// dashboard fills every day. Pure arithmetic on the band's midpoint — nothing
/// here is a projection of *their* data, so the copy says "at this rate" and
/// never claims to have measured anything.
///
/// The horizon (1 / 5 / 10 years) is view state: scrubbing it recounts the
/// number from wherever it stands and is never persisted.
class ProjectionStep extends StatefulWidget {
  const ProjectionStep({required this.progress, super.key});

  final OnboardingProgress progress;

  /// Horizons the headline can be expressed over. Five years is the default —
  /// long enough to be startling, short enough to still feel like your own
  /// life.
  static const horizons = [1, 5, 10];

  @override
  State<ProjectionStep> createState() => _ProjectionStepState();
}

class _ProjectionStepState extends State<ProjectionStep> {
  int _years = 5;

  /// The ring's denominator. Waking hours, not the clock: a 2.5 h band is a
  /// sixth of a day awake, which the arc can show; a tenth of 24 h could not.
  static const _wakingHours = 16;

  /// "about 2.5 hours" — from the band's midpoint, so 'Not sure' reads as the
  /// average it stands for and the chip labels never reach prose.
  static String _hours(ScreenTimeBand band) {
    final h = band.hoursPerDay;
    if (h < 1) return '30 minutes';
    return '${h % 1 == 0 ? h.toInt() : h} hours';
  }

  String get _caption =>
      _years == 1 ? 'of your next year' : 'of your next $_years years';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final band = widget.progress.band;
    final perYear = widget.progress.daysPerYear;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // The band is answered before this step is reachable, but a resumed record
    // written by an older build could arrive without one — render the step
    // without the number rather than throwing on a null.
    final total = perYear == null ? null : perYear * _years;

    return EntranceList(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (band != null && total != null) ...[
          Semantics(
            label: '$total days $_caption',
            excludeSemantics: true,
            child: TweenAnimationBuilder<double>(
              // An explicit `begin`: with none, the first build renders the end
              // state and the arc never grows in.
              tween: Tween(begin: 0, end: band.hoursPerDay / _wakingHours),
              duration: reduce ? Duration.zero : AppDurations.slow,
              curve: AppCurves.standard,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DayCountUp(days: total),
                  Text(
                    'DAYS',
                    style: text.labelSmall?.copyWith(
                      letterSpacing: 2,
                      color: context.glass.onGlassMuted,
                    ),
                  ),
                ],
              ),
              builder: (context, v, child) => ProgressRing(
                size: 200,
                strokeWidth: 16,
                progress: v,
                child: child,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _caption,
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(color: context.glass.onGlass),
          ),
          const SizedBox(height: AppSpacing.md),
          GlassSegmented(
            height: AppSizes.controlHeight,
            expand: false,
            segments: [
              for (final y in ProjectionStep.horizons)
                (label: y == 1 ? '1 year' : '$y years', icon: null),
            ],
            selectedIndex: ProjectionStep.horizons.indexOf(_years),
            onChanged: (i) =>
                setState(() => _years = ProjectionStep.horizons[i]),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        Text(
          'That’s the maths, not a judgement',
          textAlign: TextAlign.center,
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          band == null
              ? 'Short-form feeds are built to never end. The time goes '
                    'somewhere, and it is rarely where you meant it to.'
              : 'At about ${_hours(band)} a day, that is about $perYear full '
                    'days a year — roughly '
                    '${(band.hoursPerDay / _wakingHours * 100).round()}% of '
                    'your waking hours, scrolling. You did not choose that; '
                    'the feed did.',
          textAlign: TextAlign.center,
          style: text.bodyLarge?.copyWith(color: context.glass.onGlass),
        ),
      ],
    );
  }
}

/// Counts to [days]; a new target recounts from the value on screen rather
/// than rewinding. Under reduce-motion it renders the end state — the number
/// is the point, the animation is not.
class _DayCountUp extends StatelessWidget {
  const _DayCountUp({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: reduce ? days : 0, end: days),
      duration: reduce ? Duration.zero : AppDurations.slow,
      curve: AppCurves.decelerate,
      builder: (context, v, _) => ShaderMask(
        shaderCallback: (b) => context.metricGradient.createShader(b),
        blendMode: BlendMode.srcIn,
        child: Text(
          '$v',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
