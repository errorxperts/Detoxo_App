import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/additional_feature/showcase_view/domain/showcase_step.dart';
import 'package:flutter/material.dart';

/// The tooltip rendered beside each highlighted target during the tour, on
/// the pre-migration tour's layout in Frozen Glass materials, in the step's
/// own colour ([ShowcaseStep.palette], a mode's palette): a sheet card washed
/// and edged in it, the step's badge beside its title, the body, then one row
/// with the progress dots and the controls (a quiet **Skip** and a compact
/// **Next** / **Done** pill). Fixed-width so the package's auto-placement
/// stays stable over narrow targets like the mode options.
///
/// Each step arrives smoothly: the card fades, rises and settles from 94 %,
/// the badge pops in on the press overshoot, the title, body and controls
/// follow a beat apart, and the active dot grows. Reduce Motion shows it
/// still. It is presentational: [onNext] and [onSkip] drive the tour.
class ShowcaseTooltipCard extends StatelessWidget {
  const ShowcaseTooltipCard({
    required this.step,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onSkip,
    super.key,
  });

  final ShowcaseStep step;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  static const double _width = 280;

  @override
  Widget build(BuildContext context) {
    final palette = step.palette;
    final card = _Card(
      step: step,
      index: index,
      total: total,
      onNext: onNext,
      onSkip: onSkip,
    );
    if (palette == null) return card;
    return AccentScope(
      light: palette(AppTokens.light),
      dark: palette(AppTokens.dark),
      child: card,
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.step,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onSkip,
  });

  final ShowcaseStep step;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accent = context.accent;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final last = index == total - 1;
    final radius = BorderRadius.circular(AppRadius.card);

    // One beat of the stagger: fade and lift [child] in after [beat] steps.
    Widget beat(int beat, Widget child) => still
        ? child
        : child
              .animate(delay: AppDurations.stagger * beat)
              .fadeIn(
                duration: AppDurations.normal,
                curve: AppCurves.decelerate,
              )
              .slideY(
                begin: 0.25,
                end: 0,
                duration: AppDurations.medium,
                curve: AppCurves.standard,
              );

    final card = SizedBox(
      width: ShowcaseTooltipCard._width,
      // The old tour's tint: the step colour washing down the card at
      // 20 → 6 %, and a 40 % edge.
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: accent.main.withValues(alpha: 0.40)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              accent.main.withValues(alpha: 0.20),
              accent.main.withValues(alpha: 0.06),
            ],
          ),
        ),
        child: GlassContainer(
          surface: DxSurface.sheet,
          borderRadius: AppRadius.card,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StepBadge(step: step, still: still),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: beat(
                      1,
                      Text(
                        step.title,
                        style: AppTypography.headline.copyWith(color: t.ink),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              beat(
                2,
                Text(
                  step.body,
                  style: AppTypography.subhead.copyWith(color: t.ink2),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // One row when it fits; at large text the controls wrap below
              // the dots.
              beat(
                3,
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Semantics(
                      label: 'Step ${index + 1} of $total',
                      child: _StepDots(
                        index: index,
                        total: total,
                        still: still,
                      ),
                    ),
                    // Side by side; stacked, still at the end, when they
                    // don't fit.
                    OverflowBar(
                      alignment: MainAxisAlignment.end,
                      overflowAlignment: OverflowBarAlignment.end,
                      overflowSpacing: AppSpacing.xs,
                      children: [
                        SecondaryButton(label: 'Skip', onPressed: onSkip),
                        LiquidPill(
                          tint: accent.main,
                          semanticLabel: last ? 'Done' : 'Next',
                          onPressed: onNext,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(last ? 'Done' : 'Next'),
                              const SizedBox(width: AppSpacing.xxs),
                              Icon(
                                last
                                    ? Icons.check_rounded
                                    : Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (still) return card;
    return card
        .animate()
        .fadeIn(duration: AppDurations.normal, curve: AppCurves.decelerate)
        .scale(
          begin: const Offset(0.94, 0.94),
          end: const Offset(1, 1),
          duration: AppDurations.medium,
          curve: AppCurves.standard,
        )
        .slideY(
          begin: 0.06,
          end: 0,
          duration: AppDurations.medium,
          curve: AppCurves.standard,
        );
  }
}

/// The tooltip's feature badge: a 52 circle lit in the step colour (as the old
/// tour's) holding the step's spec 3D icon (tinted for the five modes), or its
/// glyph when it has none. It pops in on the press overshoot.
class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.step, required this.still});

  final ShowcaseStep step;
  final bool still;

  static const double _size = 52;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    final image = step.image;
    final badge = IconBadge(
      size: _size,
      color: accent.main,
      fillAlpha: 0.16,
      bordered: true,
      icon: image == null ? step.icon : null,
      child: image == null
          ? null
          : Icon3d(image, size: _size * 0.7, accentTint: step.accentTint),
    );
    if (still) return badge;
    return badge
        .animate(delay: AppDurations.stagger)
        .fadeIn(duration: AppDurations.fast)
        .scale(
          begin: const Offset(0.6, 0.6),
          end: const Offset(1, 1),
          duration: AppDurations.press,
          curve: AppCurves.press,
        );
  }
}

/// Progress: a wide step-colour dot for the active step (it grows in), hairline
/// dots for the rest.
class _StepDots extends StatelessWidget {
  const _StepDots({
    required this.index,
    required this.total,
    required this.still,
  });

  final int index;
  final int total;
  final bool still;

  static const double _dot = 6;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accent = context.accent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xxs),
          if (i == index)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: still ? _dot * 3 : _dot, end: _dot * 3),
              duration: still ? Duration.zero : AppDurations.medium,
              curve: AppCurves.press,
              builder: (_, width, _) => _pill(width, accent.main),
            )
          else
            _pill(_dot, t.hairline),
        ],
      ],
    );
  }

  static Widget _pill(double width, Color color) => Container(
    width: width,
    height: _dot,
    decoration: BoxDecoration(color: color, borderRadius: AppRadius.brPill),
  );
}
