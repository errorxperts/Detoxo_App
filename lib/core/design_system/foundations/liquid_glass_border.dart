import 'dart:math' as math;

import 'package:detoxo/core/design_system/theme/app_theme.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:flutter/material.dart';

/// An ultra-thin specular rim for glass surfaces — the Apple Liquid Glass /
/// visionOS edge, painted as a foreground over any [child].
///
/// Reads as curved glass rather than an outline because the light is *uneven*:
/// a wide, bright key-light arc at the top-left, a tighter and dimmer bounce
/// where that light exits again at the bottom-right, and a plain hairline
/// everywhere else. A second stroke just inside the edge, lit top-down, stands
/// in for the glass's thickness.
///
/// Every colour comes from the [GlassTokens] extension (`context.glass`), so
/// the rim tracks the live theme and the selected background without a single
/// hardcoded value; only the *alphas* belong to this widget, and [intensity]
/// scales all of them at once.
///
/// Shape-agnostic: it strokes `shape.getOuterPath(...)`, so a squircle
/// ([AppRadius.continuous]), a [CircleBorder], a [StadiumBorder] or any radius
/// all work with no separate code path.
///
/// Static and cheap by design — two stroked paths, no animation controller, no
/// `MaskFilter`, no shader asset, no `saveLayer`. Glass surfaces cast no drop
/// shadow, so this rim is what separates them from the background.
class LiquidGlassBorder extends StatelessWidget {
  const LiquidGlassBorder({
    required this.child,
    this.shape,
    this.intensity = 1,
    this.tint,
    super.key,
  });

  final Widget child;

  /// Outline the rim traces. Defaults to the standard card squircle
  /// ([AppRadius.continuous] at [AppRadius.xl]). Pass the *same* shape the host
  /// clips to, or the rim will drift off the edge.
  final ShapeBorder? shape;

  /// Scales every alpha, `0` (invisible) to `1` (full). Values outside the
  /// range are clamped.
  final double intensity;

  /// Specular colour. Defaults to the theme's glass highlight.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return CustomPaint(
      foregroundPainter: _LiquidEdgePainter(
        shape: shape ?? AppRadius.continuous(AppRadius.xl),
        highlight: tint ?? glass.highlight,
        base: glass.border,
        intensity: intensity.clamp(0.0, 1.0),
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      ),
      child: child,
    );
  }
}

/// Paints the two strokes that make up the liquid-glass edge. Two draw calls,
/// no layer, no blur filter.
class _LiquidEdgePainter extends CustomPainter {
  const _LiquidEdgePainter({
    required this.shape,
    required this.highlight,
    required this.base,
    required this.intensity,
    required this.devicePixelRatio,
  });

  final ShapeBorder shape;
  final Color highlight;
  final Color base;
  final double intensity;
  final double devicePixelRatio;

  /// Where the specular arcs sit, as a fraction of a full turn. Flutter's
  /// [SweepGradient] starts at 3 o'clock and runs clockwise in y-down space, so
  /// 0.625 (225°) lands on the top-left corner and 0.125 (45°) on the
  /// bottom-right.
  ///
  /// The two are deliberately *not* symmetric. Top-left is the key light — the
  /// brightest, widest arc. Bottom-right is the light that entered the glass
  /// and bounced back out, so it is tighter and dimmer. Matching arcs read as a
  /// decorative gradient; unequal ones read as a lit object.
  static const double _keyCentre = 0.625;
  static const double _keyFalloff = 0.105;
  static const double _bounceCentre = 0.125;
  static const double _bounceFalloff = 0.055;

  /// Bounce brightness relative to the key light.
  static const double _bounceScale = 0.55;

  /// A 1px rim needs more alpha than a fill to read at all, so the specular is
  /// a multiple of the highlight token rather than the token itself. This
  /// carries all of the surface's depth now that nothing casts a shadow.
  static const double _specularBoost = 2.6;

  /// Ceiling on the boosted specular. A fully opaque hairline stops reading as
  /// light on glass and starts reading as an outline — which is the whole thing
  /// this widget exists to avoid. Matters for callers that pass an already
  /// strong tint.
  static const double _specularCeiling = 0.9;

  /// How far inside the edge the thickness highlight sits, in logical pixels.
  static const double _innerInset = 1.2;

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0 || size.isEmpty) return;

    final rect = Offset.zero & size;

    // 1. Specular rim. The base sits at the full hairline token — with no drop
    // shadow underneath, the unlit part of the edge is the only thing
    // separating the surface from the background, so it can't be faint.
    final key = highlight.withValues(
      alpha: (highlight.a * _specularBoost * intensity).clamp(
        0.0,
        _specularCeiling,
      ),
    );
    final bounce = highlight.withValues(alpha: key.a * _bounceScale);
    final dim = base.withValues(alpha: base.a * intensity);
    canvas.drawPath(
      shape.getOuterPath(rect),
      Paint()
        ..style = PaintingStyle.stroke
        // Hairline, but never thinner than one physical pixel.
        ..strokeWidth = math.max(1, 1 / devicePixelRatio)
        ..shader = SweepGradient(
          colors: [dim, dim, bounce, dim, dim, key, dim, dim],
          stops: const [
            0,
            _bounceCentre - _bounceFalloff,
            _bounceCentre,
            _bounceCentre + _bounceFalloff,
            _keyCentre - _keyFalloff,
            _keyCentre,
            _keyCentre + _keyFalloff,
            1,
          ],
        ).createShader(rect),
    );

    // 2. Thickness highlight, just inside the edge. Lit top-down rather than
    // diagonally — a second, different cue instead of a fainter copy of the
    // corner arcs, which is what actually sells the glass as having depth.
    if (size.shortestSide <= _innerInset * 2) return;
    canvas.drawPath(
      shape.getOuterPath(rect.deflate(_innerInset)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            highlight.withValues(alpha: highlight.a * 0.5 * intensity),
            Colors.transparent,
          ],
          stops: const [0, 0.5],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_LiquidEdgePainter old) =>
      old.shape != shape ||
      old.highlight != highlight ||
      old.base != base ||
      old.intensity != intensity ||
      old.devicePixelRatio != devicePixelRatio;
}
