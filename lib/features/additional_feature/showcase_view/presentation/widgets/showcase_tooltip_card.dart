import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/additional_feature/showcase_view/domain/showcase_step.dart';
import 'package:detoxo/features/additional_feature/showcase_view/presentation/widgets/showcase_lottie_icon.dart';
import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

/// The glass tooltip rendered beside each highlighted target during the tour:
/// the step's Lottie badge, title, body, progress dots, and the Skip / Next
/// (Done) controls. Fixed-width so the package's auto-placement stays stable
/// over narrow targets like the mode cells.
///
/// It drives the tour through the `ShowcaseView` singleton, NOT
/// `ShowCaseWidget.of(context)` — this card is rendered in the root overlay, so
/// it has no `ShowCaseWidget` ancestor and an `.of` lookup would throw.
class ShowcaseTooltipCard extends StatelessWidget {
  const ShowcaseTooltipCard({
    required this.step,
    required this.index,
    required this.total,
    super.key,
  });

  final ShowcaseStep step;
  final int index;
  final int total;

  bool get _isLast => index == total - 1;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accent = toneColor(context, step.tone);

    final card = SizedBox(
      width: 280,
      child: GlassContainer(
        borderRadius: AppRadius.xl,
        blurSigma: AppBlur.sheet,
        tintTop: accent.withValues(alpha: 0.20),
        tintBottom: accent.withValues(alpha: 0.06),
        borderColor: accent.withValues(alpha: 0.40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShowcaseLottieIcon(step: step),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    step.title,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              step.body,
              style: text.bodySmall?.copyWith(
                color: context.glass.onGlassMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StepDots(index: index, total: total, color: accent),
                Row(
                  children: [
                    _SkipButton(onTap: _dismiss),
                    const SizedBox(width: AppSpacing.xs),
                    _NextButton(
                      label: _isLast ? 'Done' : 'Next',
                      isLast: _isLast,
                      onTap: _next,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return card
        .animate()
        .fadeIn(duration: AppDurations.normal)
        .slideY(begin: 0.06, end: 0, curve: AppCurves.standard);
  }

  void _next() {
    AppHaptics.selection();
    ShowcaseView.get().next();
  }

  void _dismiss() {
    AppHaptics.light();
    ShowcaseView.get().dismiss();
  }
}

/// "N of M" progress: a widening accent dot for the active step, muted pills for
/// the rest.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.index, required this.total, required this.color});

  final int index;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          AnimatedContainer(
            duration: AppDurations.fast,
            curve: AppCurves.standard,
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index ? color : context.glass.border,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ],
    );
  }
}

/// Lowest-emphasis "Skip" action — ends the tour via dismiss.
class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      haptic: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          'Skip',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: context.glass.onGlassMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Primary CTA — advances the tour (or finishes it on the last step). Mirrors
/// the brand gradient pill used by the dashboard's selected mode cell.
class _NextButton extends StatelessWidget {
  const _NextButton({
    required this.label,
    required this.isLast,
    required this.onTap,
  });

  final String label;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppPressable(
      onTap: onTap,
      haptic: false,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, scheme.secondary],
          ),
          borderRadius: AppRadius.brPill,
          boxShadow: [
            BoxShadow(
              color: scheme.secondary.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
              size: 16,
              color: scheme.onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
