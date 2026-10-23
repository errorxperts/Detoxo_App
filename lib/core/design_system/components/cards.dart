import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/design_system/tokens/app_motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:flutter/material.dart';

/// A frosted panel, optionally tappable. For a titled section put a
/// `SectionHeader` above it. [flat] drops its drop shadow (the Insights tab).
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.onTap,
    this.padding = AppInsets.card,
    this.flat = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final card = GlassContainer(padding: padding, flat: flat, child: child);
    if (onTap == null) return card;
    return AppPressable(onTap: onTap!, child: card);
  }
}

/// A metric tile that animates its value when it changes — making a live
/// refresh visible. The first paint counts up from zero; a later change tweens
/// from the value on screen, never back through zero (a tile fed by a live
/// stream — the Insights tab's block counts — would otherwise rewind on every
/// event). Sits in a `Row` (caller wraps in `Expanded`); uses a flat
/// translucent glass (cheap, no per-frame saveLayer), or no surface at all
/// with [contained] false.
class StatCard extends StatelessWidget {
  const StatCard({
    required this.label,
    required this.icon,
    this.value,
    this.text,
    this.unit,
    this.caption,
    this.compact = false,
    this.contained = true,
    super.key,
  }) : assert(value != null || text != null, 'Provide a value or text');

  final String label;

  /// A count, animated up on first paint.
  final int? value;

  /// A verbatim figure ("3h 12m") shown instead of [value], never animated.
  final String? text;
  final IconData icon;
  final String? unit;

  /// A muted line under the label — a neutral reference for the number
  /// ("Yesterday: 52"), never a verdict on it.
  final String? caption;

  /// A denser tile for a 2×2 grid: icon inline with the label, a smaller
  /// figure and tighter padding. The default suits a two-up row.
  final bool compact;

  /// Whether the tile paints its own glass. Set `false` inside a panel that
  /// already supplies the surface (the Activity grids): the tile keeps its
  /// padding and layout but is glass-on-glass no longer. A tappable tile
  /// (EVO-062) has to choose its own affordance — keep the surface, or add one.
  final bool contained;

  String get _figure => text ?? '$value${unit == null ? '' : ' $unit'}';

  /// What a screen reader hears: one sentence, not the three loose nodes the
  /// visual layout happens to produce.
  String _semanticLabel() {
    // A visual "·" separator is silence to TalkBack, so the clauses would run
    // together; spoken, it is a comma.
    final tail = caption == null ? '' : ', ${caption!.replaceAll(' · ', ', ')}';
    return '$label: $_figure$tail';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // The count-up is decoration. Honour the OS "remove animations" setting,
    // and keep the per-frame tween churn out of the semantics tree entirely —
    // otherwise TalkBack reads every intermediate number.
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final figureStyle = (compact ? text.titleLarge : text.headlineSmall)
        ?.copyWith(
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    final verbatim = this.text;
    final figure = verbatim != null
        ? Text(verbatim, style: figureStyle)
        : TweenAnimationBuilder<int>(
            // No key on the value: re-keying rebuilt the tween from `begin`
            // on every change, so a live tile rewound to 0 on each event.
            tween: IntTween(begin: 0, end: value),
            duration: reduce ? Duration.zero : AppDurations.slow,
            curve: AppCurves.standard,
            builder: (context, v, _) =>
                Text(unit == null ? '$v' : '$v $unit', style: figureStyle),
          );
    final captionText = caption == null
        ? null
        : Text(
            caption!,
            style: text.bodySmall?.copyWith(color: context.tokens.ink2),
          );
    final padding = EdgeInsets.all(compact ? AppSpacing.sm : 14);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: compact
          ? [
              Row(
                children: [
                  Icon(icon, size: 18, color: context.tokens.ink2),
                  const SizedBox(width: AppSpacing.xxs),
                  // Wraps rather than clips: "Distracting opens" beside
                  // an icon overflows a half-width tile from ~1.3× text
                  // scale, and [StatCardPair] stretches the neighbour.
                  Expanded(child: Text(label, style: text.bodySmall)),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              figure,
              ?captionText,
            ]
          : [
              Icon(icon, color: context.tokens.ink2),
              const SizedBox(height: AppSpacing.xs),
              figure,
              Text(label, style: text.bodySmall),
              ?captionText,
            ],
    );
    return Semantics(
      label: _semanticLabel(),
      excludeSemantics: true,
      child: contained
          ? GlassContainer(padding: padding, child: body)
          : Padding(padding: padding, child: body),
    );
  }
}

/// Two [StatCard]s side by side. `IntrinsicHeight` so a wrapped label or
/// caption at a large text scale stretches both tiles, not one — the shorter
/// tile would otherwise float beside its neighbour.
class StatCardPair extends StatelessWidget {
  const StatCardPair(this.first, this.second, {super.key});

  final StatCard first;
  final StatCard second;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: first),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: second),
        ],
      ),
    );
  }
}

/// A small tinted icon container — the circular/rounded badge repeated across the
/// app (drawer rows, feature tiles, blocker capsules, list avatars). Pass [icon]
/// for a default Material glyph, or [child] for anything (initials, …). Use
/// [gradient] for a filled brand badge.
class IconBadge extends StatelessWidget {
  const IconBadge({
    this.icon,
    this.child,
    this.size = 40,
    this.color,
    this.gradient,
    this.shape = BoxShape.circle,
    this.radius,
    this.fillAlpha = 0.14,
    this.bordered = false,
    this.borderWidth = 1,
    this.semanticLabel,
    super.key,
  }) : assert(icon != null || child != null, 'Provide an icon or a child');

  final IconData? icon;
  final Widget? child;
  final double size;

  /// Accessibility label for the default [icon]. Leave null when the badge is
  /// decorative or paired with adjacent descriptive text.
  final String? semanticLabel;

  /// Tints the fill (at [fillAlpha]), the border, and the default icon.
  /// Defaults to ink-2: a neutral badge.
  final Color? color;

  /// When set, fills with this gradient instead of the tinted [color]; the
  /// default icon then renders white.
  final Gradient? gradient;
  final BoxShape shape;

  /// Corner radius when [shape] is [BoxShape.rectangle] (defaults to [AppRadius.md]).
  final double? radius;
  final double fillAlpha;
  final bool bordered;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final isCircle = shape == BoxShape.circle;
    final tint = color ?? context.tokens.ink2;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: shape,
        gradient: gradient,
        color: gradient == null ? tint.withValues(alpha: fillAlpha) : null,
        borderRadius: isCircle
            ? null
            : BorderRadius.circular(radius ?? AppRadius.md),
        border: bordered
            ? Border.all(
                color: tint.withValues(alpha: 0.25),
                width: borderWidth,
              )
            : null,
      ),
      child:
          child ??
          Icon(
            icon,
            size: size * 0.5,
            color: gradient != null ? Colors.white : tint,
            semanticLabel: semanticLabel,
          ),
    );
  }
}
