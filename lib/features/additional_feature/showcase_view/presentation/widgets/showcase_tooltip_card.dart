import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/additional_feature/showcase_view/domain/showcase_step.dart';
import 'package:flutter/material.dart';

/// The tooltip rendered beside each highlighted target during the tour, in
/// the sheet material: the step's badge, title, body, the "Step N of M" dots,
/// and the Skip / Next (Done) controls. Fixed-width so the package's
/// auto-placement stays stable over narrow targets like the mode options.
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
    return SizedBox(
      width: _width,
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
            Semantics(
              label: 'Step ${index + 1} of $total',
              child: _StepDots(index: index, total: total),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                SecondaryButton(label: 'Skip', onPressed: onSkip),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: PrimaryButton(
                    label: index == total - 1 ? 'Done' : 'Next',
                    expand: true,
                    onPressed: onNext,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).entrance();
  }
}

/// The tooltip's feature badge: the step's spec 3D icon at 56, uncropped
/// (accent-tinted for the four modes), or a neutral badge holding its glyph.
class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.step});

  final ShowcaseStep step;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    final image = step.image;
    if (image == null) return IconBadge(icon: step.icon, size: _size);
    return Icon3d(image, size: _size, accentTint: step.accentTint);
  }
}

/// Progress: a wide ink dot for the active step, hairline dots for the rest.
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
              color: i == index ? t.ink : t.hairline,
              borderRadius: AppRadius.brPill,
            ),
          ),
        ],
      ],
    );
  }
}
