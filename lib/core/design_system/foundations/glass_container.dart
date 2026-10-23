import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:flutter/material.dart';

/// The five Frozen Glass surface roles. Each paints its own fill and shadow
/// recipe from [AppTokens]; only [glass] and [sheet] blur what is behind them.
enum DxSurface {
  /// Floating controls: header buttons, the tab bar, toasts. Blurs.
  glass,

  /// Frosted section panels and list groups. Never blurs.
  panel,

  /// Blocker tiles: the 145° card gradient.
  tile,

  /// Solid choices (mode card, quick picks, segment tracks): no shadow.
  option,

  /// Bottom sheets and dialogs. Blurs.
  sheet,
}

/// The CSS gradient line of a `linear-gradient(<angle>deg, …)` over [rect]:
/// its start and end points (CSS Images 3, so the corners get the end colours
/// at any aspect). 180° runs top to bottom, 145° is the card diagonal.
(Offset, Offset) cssLine(Rect rect, double angle) {
  final a = angle * math.pi / 180;
  final d = Offset(math.sin(a), -math.cos(a));
  final half =
      ((rect.width * math.sin(a)).abs() + (rect.height * math.cos(a)).abs()) /
      2;
  return (rect.center - d * half, rect.center + d * half);
}

/// The CSS `saturate(s)` filter as a 4×5 colour matrix (Filter Effects 1).
List<double> cssSaturate(double s) => [
  0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0, //
  0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0, //
  0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0, //
  0, 0, 0, 1, 0,
];

/// Paints a CSS box: outer `box-shadow` layers, `background-color`, a linear
/// `background-image` and inset layers, exactly as a browser stacks them.
///
/// - Layers keep the recipe's CSS order (the first paints on top), so they
///   are drawn in reverse.
/// - A layer's blur is the CSS blur radius: a Gaussian sigma of blur / 2.
/// - Outer layers are clipped to outside the shape, so a translucent fill is
///   never darkened by its own shadow; inset layers stay inside it.
///
/// [outer] / [inner] split the box in two, so a [BackdropFilter] can sit
/// between the shadows and the fill.
class DxSurfacePainter extends CustomPainter {
  const DxSurfacePainter({
    this.radius = BorderRadius.zero,
    this.color,
    this.gradient,
    this.stops,
    this.angle = 180,
    this.shadows = const [],
    this.outer = true,
    this.inner = true,
  });

  final BorderRadius radius;
  final Color? color;
  final List<Color>? gradient;
  final List<double>? stops;

  /// CSS gradient angle in degrees.
  final double angle;
  final List<DxShadow> shadows;
  final bool outer;
  final bool inner;

  static RRect _grow(RRect r, double d) {
    Radius g(Radius c) =>
        Radius.elliptical(math.max(0, c.x + d), math.max(0, c.y + d));
    return RRect.fromLTRBAndCorners(
      r.left - d,
      r.top - d,
      r.right + d,
      r.bottom + d,
      topLeft: g(r.tlRadius),
      topRight: g(r.trRadius),
      bottomLeft: g(r.blRadius),
      bottomRight: g(r.brRadius),
    );
  }

  static Paint _paint(DxShadow s) {
    final p = Paint()..color = s.color;
    if (s.blur > 0) {
      p.maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur / 2);
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final cap = size.shortestSide / 2;
    Radius clamp(Radius r) =>
        Radius.elliptical(math.min(r.x, cap), math.min(r.y, cap));
    final shape = RRect.fromRectAndCorners(
      rect,
      topLeft: clamp(radius.topLeft),
      topRight: clamp(radius.topRight),
      bottomLeft: clamp(radius.bottomLeft),
      bottomRight: clamp(radius.bottomRight),
    );

    if (outer) {
      final outside = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect.inflate(1e4))
        ..addRRect(shape);
      for (final s in shadows.reversed.where((s) => !s.inset)) {
        canvas
          ..save()
          ..clipPath(outside)
          ..drawRRect(_grow(shape.shift(s.offset), s.spread), _paint(s))
          ..restore();
      }
    }
    if (!inner) return;

    if (color != null) canvas.drawRRect(shape, Paint()..color = color!);
    if (gradient != null) {
      final (from, to) = cssLine(rect, angle);
      canvas.drawRRect(
        shape,
        Paint()..shader = ui.Gradient.linear(from, to, gradient!, stops),
      );
    }
    final insets = shadows.reversed.where((s) => s.inset).toList();
    if (insets.isEmpty) return;
    canvas
      ..save()
      ..clipRRect(shape);
    for (final s in insets) {
      final pad = s.blur + s.offset.distance + s.spread.abs() + 1;
      canvas.drawPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(rect.inflate(pad))
          ..addRRect(_grow(shape.shift(s.offset), -s.spread)),
        _paint(s),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(DxSurfacePainter old) =>
      old.radius != radius ||
      old.color != color ||
      !_same(old.gradient, gradient) ||
      !_same(old.stops, stops) ||
      old.angle != angle ||
      !_same(old.shadows, shadows) ||
      old.outer != outer ||
      old.inner != inner;

  static bool _same<T>(List<T>? a, List<T>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The ONE surface primitive: a Frozen Glass [surface] role around [child].
/// Nothing else calls [BackdropFilter] for a surface.
///
/// The role reaches the subtree through [surfaceOf], so a row inside a panel
/// or a sheet draws no surface of its own (no glass inside glass).
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    required this.child,
    this.surface = DxSurface.panel,
    this.borderRadius,
    this.padding = AppInsets.card,
    this.color,
    this.backdrop = true,
    super.key,
  });

  final Widget child;
  final DxSurface surface;

  /// Corner radius; null takes the role's own (glass pill, panel 22, tile and
  /// option 28, sheet 40). A circle is [AppRadius.pill] on a square.
  final double? borderRadius;
  final EdgeInsetsGeometry padding;

  /// A solid fill in place of the role's own (an [DxSurface.option] colour).
  final Color? color;

  /// Whether a [DxSurface.glass] / [DxSurface.sheet] blurs what is behind it.
  /// Header buttons pass `false`: they sit on the static ground gradient,
  /// where a blur is invisible and only costs a layer. A sheet passes `false`
  /// while it slides. Flipping it keeps the subtree (and its state): the
  /// blur only switches off.
  final bool backdrop;

  /// The role of the nearest enclosing [GlassContainer], or null.
  static DxSurface? surfaceOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SurfaceScope>()?.surface;

  static double _radius(DxSurface s) => switch (s) {
    DxSurface.glass => AppRadius.pill,
    DxSurface.panel => AppRadius.row,
    DxSurface.tile || DxSurface.option => AppRadius.card,
    DxSurface.sheet => AppRadius.sheet,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(borderRadius ?? _radius(surface));
    // ponytail: panels never blur — only the smooth ground gradient sits
    // behind them, where a blur is invisible. Add one if a panel ever floats
    // over imagery.
    final (gradient, angle, shadows, blur, saturate) = switch (surface) {
      DxSurface.glass => (
        [t.glassTop, t.glassBottom],
        180.0,
        t.shadowGlass,
        AppTokens.glassBlur,
        AppTokens.glassSaturate,
      ),
      DxSurface.panel => (
        [t.panelTop, t.panelBottom],
        180.0,
        t.shadowCard,
        null,
        1.0,
      ),
      DxSurface.tile => (
        [t.cardFrom, t.cardTo],
        145.0,
        t.shadowCard,
        null,
        1.0,
      ),
      DxSurface.option => (null, 180.0, const <DxShadow>[], null, 1.0),
      DxSurface.sheet => (
        [t.sheetTop, t.sheetBottom],
        180.0,
        t.shadowSheet,
        AppTokens.sheetBlur,
        AppTokens.sheetSaturate,
      ),
    };
    final fill = color ?? (surface == DxSurface.option ? t.optionBase : null);
    final content = _SurfaceScope(
      surface: surface,
      child: Padding(padding: padding, child: child),
    );

    if (blur == null) {
      return RepaintBoundary(
        child: CustomPaint(
          painter: DxSurfacePainter(
            radius: radius,
            color: fill,
            gradient: color == null ? gradient : null,
            angle: angle,
            shadows: shadows,
          ),
          child: content,
        ),
      );
    }
    return RepaintBoundary(
      child: CustomPaint(
        painter: DxSurfacePainter(
          radius: radius,
          shadows: shadows,
          inner: false,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            enabled: backdrop,
            filter: ui.ImageFilter.compose(
              outer: ui.ColorFilter.matrix(cssSaturate(saturate)),
              inner: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            ),
            child: CustomPaint(
              painter: DxSurfacePainter(
                radius: radius,
                color: fill,
                gradient: color == null ? gradient : null,
                angle: angle,
                shadows: shadows,
                outer: false,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class _SurfaceScope extends InheritedWidget {
  const _SurfaceScope({required this.surface, required super.child});

  final DxSurface surface;

  @override
  bool updateShouldNotify(_SurfaceScope old) => old.surface != surface;
}
