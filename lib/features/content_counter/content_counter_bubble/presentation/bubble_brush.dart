import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_frame.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/svg_path.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/painting.dart';

/// The board's vector shapes, verbatim, in their own view boxes (board units).
abstract final class BubblePaths {
  /// The hourglass mark (40×64 box).
  static const mark =
      'M9 3 H31 Q37 3 37 9 V17 Q37 23 30 29 L27 32 L30 35 Q37 41 37 47 V55 '
      'Q37 61 31 61 H9 Q3 61 3 55 V47 Q3 41 10 35 L13 32 L10 29 Q3 23 3 17 V9 '
      'Q3 3 9 3 Z';

  /// The mark's grains (40×64 box), each a rounded square turned 45° about
  /// its centre: the top bulb's, the falling one's, the bottom bulb's.
  static const grainTop = (rect: Rect.fromLTWH(15.5, 12, 9, 9), r: 2.2);
  static const grainFalling = (
    rect: Rect.fromLTWH(17.8, 27.8, 4.4, 4.4),
    r: 1.1,
  );
  static const grainBottom = (rect: Rect.fromLTWH(14.5, 44, 11, 11), r: 2.6);

  /// Hourglass's large mark behind the count (68 box).
  static const hourglassBig =
      'M26 12 H42 Q46 12 46 16 V22 Q46 26 41 30 L39 32 L41 34 Q46 38 46 42 '
      'V50 Q46 54 42 54 H26 Q22 54 22 50 V42 Q22 38 27 34 L29 32 L27 30 '
      'Q22 26 22 22 V16 Q22 12 26 12 Z';

  /// Hourglass's top bulb, the clip for its sand (68 box).
  static const clipTop =
      'M23 13 H45 V24 Q45 27 40 31 L34 32 L28 31 Q23 27 23 24 Z';

  /// Hourglass's bottom bulb, the clip for its sand (68 box).
  static const clipBottom =
      'M23 53 H45 V40 Q45 37 40 33 L34 32 L28 33 Q23 37 23 40 Z';

  /// Mascot: the raised palm of the last tier (68 box).
  static const hand =
      'M48 54 v-10 q0-2 2-2 q2 0 2 2 v6 v-9 q0-2 2-2 q2 0 2 2 v9 v-8 q0-2 2-2 '
      'q2 0 2 2 v8 v-5 q0-2 2-2 q2 0 2 2 v9 q0 8-8 8 h-2 q-6 0-6-6z';

  /// Mascot: the sweat drop (68 box).
  static const sweat = 'M52 20 q3 5 0 8 q-3 -3 0 -8z';

  /// Mascot: the two tear lines (68 box).
  static const tears = 'M21 38 q-1 6 0 10 M47 38 q1 6 0 10';

  /// Mascot brows per mood (= tier 0..5), 68 box.
  static const brows = [
    _browsCalm,
    _browsCalm,
    'M19 20 q6 -5 12 -2 M37 18 q6 -3 12 2',
    'M19 20 q6 2 12 3 M37 23 q6 -1 12 -3',
    _browsDistressed,
    _browsDistressed,
  ];
  static const _browsCalm = 'M19 22 q6 -4 12 -1 M37 21 q6 -3 12 1';
  static const _browsDistressed = 'M19 19 q6 3 12 5 M37 24 q6 -2 12 -5';

  /// Mascot mouths per mood, 68 box; mood 2 is an oval the face draws, hence ''.
  static const mouths = [
    'M26 42 q8 8 16 0',
    'M25 41 q9 10 18 0',
    '',
    'M27 44 h14',
    'M26 46 q8 -7 16 0',
    'M26 47 q8 -8 16 0',
  ];
}

/// [Color] scaled in alpha.
extension ColorFade on Color {
  Color fade(double k) => withValues(alpha: a * k.clamp(0.0, 1.0));
}

/// The shell's drawing kit over one [Canvas]: the body shape, the shared
/// shell, Manrope text, the hourglass mark and board paths. Every length is in
/// canvas px unless it says board units. [opacity] (the user's 0.5–1) applies
/// to the body fill only. Twin of the Kotlin `BubblePaints`.
final class BubbleBrush {
  BubbleBrush(this.canvas, this.opacity);

  final Canvas canvas;
  final double opacity;

  static final _parsed = <String, Path>{};

  /// The body's rounded rect: the outer corners take [radiusOuter], the
  /// docked side's corners [radiusEdge] (board units).
  RRect body(BubbleFrame f, {double radiusOuter = 34, double radiusEdge = 34}) {
    final outer = Radius.circular(f.u(radiusOuter));
    final edge = Radius.circular(f.u(radiusEdge));
    final right = f.dockedRight ? edge : outer;
    final left = f.dockedRight ? outer : edge;
    return RRect.fromRectAndCorners(
      f.body,
      topLeft: left,
      bottomLeft: left,
      topRight: right,
      bottomRight: right,
    );
  }

  /// The shared shell (BR-04): soft shadow, 7 halo band, 1.5 ring outside the
  /// body, the 160° fill, then the 1.5 inner hairline. Each colour defaults to
  /// the frame's look; a transparent one is skipped.
  void shell(
    BubbleFrame f, {
    Color? fillFrom,
    Color? fillTo,
    double radiusOuter = 34,
    double radiusEdge = 34,
    Color? ring,
    Color? halo,
    Color? shadow,
  }) {
    final shape = body(f, radiusOuter: radiusOuter, radiusEdge: radiusEdge);
    final shadowColor = shadow ?? f.look.shadow;
    if (shadowColor.a > 0) {
      // An outer box-shadow never shows through the body (CSS), so clip it out.
      canvas
        ..save()
        ..clipPath(
          Path()
            ..fillType = PathFillType.evenOdd
            ..addRect(shape.outerRect.inflate(f.u(30)))
            ..addRRect(shape),
        )
        ..drawRRect(
          shape.shift(Offset(0, f.u(3))),
          Paint()
            ..color = shadowColor
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, f.u(6)),
        )
        ..restore();
    }
    _band(shape.inflate(f.u(3.5)), f.u(7), halo ?? f.look.halo);
    _band(shape.inflate(f.u(0.75)), f.u(1.5), ring ?? f.look.ring);
    final from = fillFrom ?? f.look.fillFrom;
    final to = fillTo ?? f.look.fillTo;
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = linear(shape.outerRect, 160, [
          from.withValues(alpha: from.a * opacity),
          to.withValues(alpha: to.a * opacity),
        ]),
    );
    double hairline(int tier) => tier == 0 ? 0.95 : 0.55;
    final alpha = ui.lerpDouble(
      hairline(f.prevTier),
      hairline(f.tier),
      f.blend,
    )!;
    _band(
      shape.deflate(f.u(0.75)),
      f.u(1.5),
      Colors.white.withValues(alpha: alpha),
    );
  }

  /// [s] in Manrope with tabular figures, centred on [center], scaled by
  /// [scale] about it and faded by [alpha]. [glow] > 0 first draws the same
  /// text blurred by that sigma in [glowColor] (default [color]).
  void text(
    String s,
    Offset center, {
    required double size,
    required Color color,
    double scale = 1,
    double letterSpacing = 0,
    double alpha = 1,
    FontWeight weight = FontWeight.w800,
    double glow = 0,
    Color? glowColor,
  }) {
    final a = alpha.clamp(0.0, 1.0);
    if (a == 0) return;
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(scale);
    if (glow > 0) {
      final g = glowColor ?? color;
      _drawCentered(
        _layout(
          s,
          size,
          letterSpacing,
          weight,
          Paint()
            ..color = g.withValues(alpha: g.a * a)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow),
        ),
      );
    }
    _drawCentered(
      _layout(
        s,
        size,
        letterSpacing,
        weight,
        Paint()..color = color.withValues(alpha: color.a * a),
      ),
    );
    canvas.restore();
  }

  /// The laid-out width of [s] as [text] would draw it (unscaled).
  double textWidth(
    String s, {
    required double size,
    double letterSpacing = 0,
    FontWeight weight = FontWeight.w800,
  }) {
    final tp = _layout(s, size, letterSpacing, weight, Paint());
    final w = tp.width;
    tp.dispose();
    return w;
  }

  /// The hourglass mark ([BubblePaths.mark] and its grains) in the [w]×[h] box
  /// at [topLeft]: [fill] inside (null = none), [stroke] for the outline (4
  /// box units, round joins) and the grains. A non-null [grainT] (0..1) drops
  /// the middle grain from −6 to +10 box units, fading in and out.
  void mark(
    BubbleFrame f,
    Offset topLeft,
    double w,
    double h, {
    required Color? fill,
    required Color stroke,
    double? grainT,
    double alpha = 1,
  }) {
    Color fade(Color c, double k) => c.withValues(alpha: c.a * alpha * k);
    canvas
      ..save()
      ..translate(topLeft.dx, topLeft.dy)
      ..scale(w / 40, h / 64);
    final outline = _path(BubblePaths.mark);
    if (fill != null) canvas.drawPath(outline, Paint()..color = fade(fill, 1));
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round
        ..color = fade(stroke, 1),
    );
    final grain = Paint()..color = fade(stroke, 1);
    _grain(BubblePaths.grainTop, grain);
    _grain(BubblePaths.grainBottom, grain);
    if (grainT != null) {
      canvas
        ..save()
        ..translate(0, -6 + 16 * grainT);
      _grain(
        BubblePaths.grainFalling,
        Paint()..color = fade(stroke, math.sin(math.pi * grainT).abs()),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  /// Board path [d], scaled by [scale] from its own units and placed at
  /// [origin], drawn with [paint].
  void path(String d, Offset origin, double scale, Paint paint) {
    canvas
      ..save()
      ..translate(origin.dx, origin.dy)
      ..scale(scale)
      ..drawPath(_path(d), paint)
      ..restore();
  }

  /// The parsed (cached) board path [d], in its own units.
  Path svg(String d) => _path(d);

  /// The user opacity applied to a body fill colour.
  Color fade(Color c) => c.fade(opacity);

  static Path _path(String d) => _parsed.putIfAbsent(d, () => parseSvgPath(d));

  void _band(RRect shape, double width, Color color) {
    if (color.a == 0) return;
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  void _grain(({Rect rect, double r}) g, Paint paint) {
    final c = g.rect.center;
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(math.pi / 4)
      ..drawRRect(
        RRect.fromRectAndRadius(g.rect.shift(-c), Radius.circular(g.r)),
        paint,
      )
      ..restore();
  }

  void _drawCentered(TextPainter tp) {
    tp
      ..paint(canvas, Offset(-tp.width / 2, -tp.height / 2))
      ..dispose();
  }

  static TextPainter _layout(
    String s,
    double size,
    double letterSpacing,
    FontWeight weight,
    Paint paint,
  ) => TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontFamily: 'Manrope',
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        fontFeatures: const [FontFeature.tabularFigures()],
        foreground: paint,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  /// A CSS `linear-gradient(<deg>deg, …)` over [r]: the gradient line runs
  /// through the centre and reaches the corners, as CSS draws it.
  static Shader linear(Rect r, double deg, List<Color> colors) {
    final a = deg * math.pi / 180;
    final dir = Offset(math.sin(a), -math.cos(a));
    final half =
        (r.width * math.sin(a).abs() + r.height * math.cos(a).abs()) / 2;
    return ui.Gradient.linear(
      r.center - dir * half,
      r.center + dir * half,
      colors,
    );
  }
}
