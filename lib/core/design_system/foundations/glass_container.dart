import 'dart:ui';

import 'package:detoxo/core/design_system/theme/app_theme.dart';
import 'package:detoxo/core/design_system/tokens/app_blur.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:flutter/material.dart';

/// The ONE glass primitive every surface composes — nothing else should call
/// [BackdropFilter] directly.
///
/// Built as a liquid-glass stack: a [ContinuousRectangleBorder] squircle
/// ([AppRadius.continuous]) clips a subtle backdrop blur; a top-weighted sheen
/// gives the Fresnel edge light + internal reflection; a crisp hairline border
/// (drawn as a foreground so the blur never softens it) simulates glass
/// thickness; and standalone cards get a soft outer depth shadow. Colours,
/// radii, padding and sizes are unchanged from the flat build.
///
/// Set [enableBlur] to `false` for rows inside a long [ListView] to skip the
/// per-card `saveLayer` (and the depth shadow) — the surface stays flat and
/// fast while keeping the shape, tint, sheen and border.
///
/// [selected] elevates the surface to the premium active state: a faint
/// primary/secondary tint, a brighter fill and edge, a stronger sheen and a
/// soft brand ambient glow — an illuminated card without a heavy fill.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    required this.child,
    this.blurSigma = AppBlur.card,
    this.borderRadius = AppRadius.xl,
    this.tintTop,
    this.tintBottom,
    this.borderColor,
    this.borderWidth = 1,
    this.padding = AppInsets.card,
    this.enableBlur = true,
    this.selected = false,
    this.circle = false,
    super.key,
  });

  final Widget child;
  final double blurSigma;
  final double borderRadius;
  final Color? tintTop;
  final Color? tintBottom;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry padding;

  /// Set `false` inside long scrollables to skip the BackdropFilter saveLayer
  /// and the depth shadow.
  final bool enableBlur;

  /// Elevates the surface to the premium active/illuminated state.
  final bool selected;

  /// Renders a true circle (via [CircleBorder]) instead of the squircle —
  /// [borderRadius] is ignored. For round surfaces like the hero ring's centre
  /// disc, where a [ContinuousRectangleBorder] would read as a rounded square.
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    // Fill — the existing tokens by default; selected blends a faint brand tint
    // in (brighter, slightly more saturated) without a heavy fill.
    var top = tintTop ?? glass.fillTop;
    var bottom = tintBottom ?? glass.fillBottom;
    if (selected) {
      top = Color.alphaBlend(scheme.primary.withValues(alpha: 0.12), top);
      bottom = Color.alphaBlend(
        scheme.secondary.withValues(alpha: 0.06),
        bottom,
      );
    }

    // Hairline edge — simulates glass thickness; selected brightens it with a
    // brand tint (kept 1px, never a thick border).
    final edge =
        borderColor ??
        (selected
            ? Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.45),
                glass.border,
              )
            : glass.border);
    final side = BorderSide(color: edge, width: borderWidth);
    final shape = circle
        ? CircleBorder(side: side)
        : AppRadius.continuous(borderRadius, side: side);
    final clipShape = circle
        ? const CircleBorder()
        : AppRadius.continuous(borderRadius);

    // Inner highlight: a top-weighted sheen = Fresnel edge light + internal
    // reflection. Softer on dense list rows, stronger when selected.
    final sheenAlpha =
        glass.highlight.a * (selected ? 1.0 : (enableBlur ? 0.7 : 0.4));
    final content = DecoratedBox(
      decoration: ShapeDecoration(
        shape: clipShape,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bottom],
        ),
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: clipShape,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              glass.highlight.withValues(alpha: sheenAlpha),
              Colors.transparent,
            ],
          ),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );

    final clipped = ClipPath(
      clipper: ShapeBorderClipper(shape: clipShape),
      child: enableBlur && blurSigma > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: content,
            )
          : content,
    );

    // Depth for standalone cards (skipped on flat list rows): a layered
    // ambient + key shadow (cool, themed via glass.shadow — never flat black)
    // for premium, believable elevation. A soft brand glow whenever selected so
    // an active tile reads as illuminated.
    final shadow = glass.shadow;
    final shadows = <BoxShadow>[
      if (enableBlur) ...[
        // Ambient: large, very soft — the diffuse contact-less lift.
        BoxShadow(
          color: shadow,
          blurRadius: 30,
          offset: const Offset(0, 16),
          spreadRadius: -14,
        ),
        // Key: tighter, closer — grounds the card's near edge.
        BoxShadow(
          color: shadow.withValues(alpha: shadow.a * 0.65),
          blurRadius: 10,
          offset: const Offset(0, 4),
          spreadRadius: -6,
        ),
      ],
      if (selected)
        BoxShadow(
          color: scheme.primary.withValues(alpha: dark ? 0.30 : 0.22),
          blurRadius: 28,
          spreadRadius: -6,
        ),
    ];

    final result = Container(
      decoration: shadows.isEmpty
          ? null
          : ShapeDecoration(shape: clipShape, shadows: shadows),
      // Border stroked over everything (unclipped) so the blur never softens it.
      foregroundDecoration: ShapeDecoration(shape: shape),
      child: clipped,
    );

    // Isolate each glass surface's layer from sibling repaints.
    return RepaintBoundary(child: result);
  }
}
