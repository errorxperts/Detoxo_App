import 'dart:ui';

import 'package:detoxo/core/design_system/foundations/liquid_glass_border.dart';
import 'package:detoxo/core/design_system/theme/app_theme.dart';
import 'package:detoxo/core/design_system/tokens/app_blur.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:flutter/material.dart';

/// The ONE glass primitive every surface composes — nothing else should call
/// [BackdropFilter] directly.
///
/// Built as a liquid-glass stack: a [ContinuousRectangleBorder] squircle
/// ([AppRadius.continuous]) clips a subtle backdrop blur; a top-weighted sheen
/// gives the Fresnel edge light + internal reflection; and a [LiquidGlassBorder]
/// lights the edge so the surface reads as curved glass.
///
/// **There are no drop shadows.** Depth comes entirely from the glass — the
/// fill gradient, the sheen and the lit rim — so surfaces stay clean over the
/// ambient background instead of sitting on a grey smudge.
///
/// Set [enableBlur] to `false` for rows inside a long [ListView] to skip the
/// per-card `saveLayer` — the surface stays flat and fast while keeping the
/// shape, tint, sheen and border.
///
/// [selected] elevates the surface to the premium active state: a faint
/// primary/secondary tint, a brighter fill, and a brand-lit rim — an
/// illuminated card without a heavy fill.
///
/// [liquidEdge] is on by default. Set it `false` to fall back to the plain
/// 1px hairline (cheaper by one painter, but visibly flatter).
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    required this.child,
    this.blurSigma = AppBlur.card,
    this.borderRadius = AppRadius.lg,
    this.tintTop,
    this.tintBottom,
    this.borderColor,
    this.borderWidth = 1,
    this.padding = AppInsets.card,
    this.enableBlur = true,
    this.selected = false,
    this.circle = false,
    this.liquidEdge = true,
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

  /// Set `false` inside long scrollables to skip the BackdropFilter saveLayer.
  final bool enableBlur;

  /// Elevates the surface to the premium active/illuminated state.
  final bool selected;

  /// Renders a true circle (via [CircleBorder]) instead of the squircle —
  /// [borderRadius] is ignored. For round surfaces like the hero ring's centre
  /// disc, where a [ContinuousRectangleBorder] would read as a rounded square.
  final bool circle;

  /// Lights the edge with a [LiquidGlassBorder] specular rim. `false` falls
  /// back to the plain 1px hairline.
  final bool liquidEdge;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final scheme = Theme.of(context).colorScheme;

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

    // No drop shadows anywhere — depth comes from the glass itself: the fill
    // gradient, the top-weighted sheen, and the lit edge below.
    if (!liquidEdge) {
      // Legacy flat hairline. Stroked over everything (unclipped) so the blur
      // never softens it.
      return RepaintBoundary(
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: ShapeDecoration(shape: shape),
          child: clipped,
        ),
      );
    }

    // Selected surfaces light their rim with the brand instead of a glow
    // shadow, so an active tile still reads as illuminated.
    return RepaintBoundary(
      child: LiquidGlassBorder(
        shape: clipShape,
        tint: borderColor ?? (selected ? scheme.primary : null),
        child: clipped,
      ),
    );
  }
}
