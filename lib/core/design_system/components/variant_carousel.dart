import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/design_system/tokens/app_motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:flutter/material.dart';

/// One selectable option in a [VariantCarousel]: a short label, a mini preview,
/// its selected state, and a tap handler. Kept self-contained (no generics) so
/// the carousel stays a simple, reusable, variance-clean widget.
class VariantOption {
  const VariantOption({
    required this.label,
    required this.preview,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Widget preview;
  final bool selected;
  final VoidCallback onTap;
}

/// A compact, horizontally-scrolling picker of style variants — a live preview
/// per OPTION card with the label beneath; the selected card turns the solid
/// option base and wears an ink check badge. Used by the counter's bubble /
/// widget editors.
class VariantCarousel extends StatelessWidget {
  const VariantCarousel({
    required this.options,
    this.height = 104,
    this.cardWidth = 96,
    this.inset = 0,
    super.key,
  });

  final List<VariantOption> options;
  final double height;
  final double cardWidth;

  /// Space before the first card and after the last. A carousel laid edge to
  /// edge passes the page gutter, so it rests aligned with the page and
  /// scrolls out to the screen edge.
  final double inset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: EdgeInsets.symmetric(
          horizontal: inset,
          vertical: AppSpacing.xxs,
        ),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final option = options[i];
          return _VariantCard(
            label: option.label,
            selected: option.selected,
            width: cardWidth,
            onTap: option.onTap,
            child: option.preview,
          );
        },
      ),
    );
  }
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({
    required this.label,
    required this.selected,
    required this.width,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final double width;
  final VoidCallback onTap;
  final Widget child;

  /// The selection check badge.
  static const double _badge = 18;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(AppRadius.chip);
    return AppPressable(
      onTap: onTap,
      selected: selected,
      radius: radius,
      // The OPTION card: a solid fill, no border or glow. It stays an
      // AnimatedContainer, the card the home_widget tests find around the
      // check.
      child: AnimatedContainer(
        duration: context.motion(AppDurations.fast),
        curve: AppCurves.standard,
        width: width,
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          borderRadius: radius,
          color: selected ? t.optionBase : t.fillQuiet,
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(child: FittedBox(child: child)),
                  if (selected)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: _badge,
                        height: _badge,
                        decoration: BoxDecoration(
                          color: t.ink,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check, size: 12, color: t.bgTop),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.tab.copyWith(
                color: selected ? t.ink : t.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
