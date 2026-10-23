import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/additional_feature/showcase_view/domain/showcase_step.dart';
import 'package:flutter/material.dart';

/// The tooltip rendered beside each highlighted target during the tour, on
/// the pre-migration tour's layout in Frozen Glass materials: a sheet card
/// washed and edged in the live accent, the step's badge beside its title,
/// the body, then one row with the progress dots and the controls (a quiet
/// **Skip** and a compact accent **Next** / **Done** pill). Fixed-width so the
/// package's auto-placement stays stable over narrow targets like the mode
/// options.
///
/// It is presentational: [onNext] and [onSkip] drive the tour controller.
/// It fades in once through `entrance()` and is otherwise still.
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
    final t = context.tokens;
    final accent = context.accent;
    final last = index == total - 1;
    final radius = BorderRadius.circular(AppRadius.card);
    return SizedBox(
      width: _width,
      // The old tour's tint: the accent washing down the card at 20 → 6 %,
      // and a 40 % accent edge.
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
                  _StepBadge(step: step),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      step.title,
                      style: AppTypography.headline.copyWith(color: t.ink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                step.body,
                style: AppTypography.subhead.copyWith(color: t.ink2),
              ),
              const SizedBox(height: AppSpacing.md),
              // One row when it fits; at large text the controls wrap below
              // the dots.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: AppSpacing.xs,
                children: [
                  Semantics(
                    label: 'Step ${index + 1} of $total',
                    child: _StepDots(index: index, total: total),
                  ),
                  // Side by side; stacked, still at the end, when they don't fit.
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
            ],
          ),
        ),
      ),
    ).entrance();
  }
}

/// The tooltip's feature badge: a 52 accent-lit circle (as the old tour's)
/// holding the step's spec 3D icon (accent-tinted for the five modes), or its
/// glyph when it has none.
class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.step});

  final ShowcaseStep step;

  static const double _size = 52;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    final image = step.image;
    return IconBadge(
      size: _size,
      color: accent.main,
      fillAlpha: 0.16,
      bordered: true,
      icon: image == null ? step.icon : null,
      child: image == null
          ? null
          : Icon3d(image, size: _size * 0.7, accentTint: step.accentTint),
    );
  }
}

/// Progress: a wide accent dot for the active step, hairline dots for the
/// rest.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.index, required this.total});

  final int index;
  final int total;

  static const double _dot = 6;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xxs),
          Container(
            width: i == index ? _dot * 3 : _dot,
            height: _dot,
            decoration: BoxDecoration(
              color: i == index ? context.accent.main : t.hairline,
              borderRadius: AppRadius.brPill,
            ),
          ),
        ],
      ],
    );
  }
}
