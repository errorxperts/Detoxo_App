import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:detoxo/features/content_counter/content_counter_core/domain/brand_tint.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/widget_model.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_tokens.g.dart';
import 'package:flutter/painting.dart';

/// One family's face, drawn at every size from a [FaceFrame] (DS-10: a new
/// family is one face, one [WidgetFamily] value and one native provider).
/// Kotlin `WidgetFace` draws the same board for the home screen.
abstract interface class WidgetFace {
  void paint(FaceCanvas c, WidgetSize size, FaceFrame f);
}

/// One frame of a face: the model's copy, the values it draws (eased while
/// they change, DS-07) and the look it is drawn in. A cross-fade draws the
/// same frame once per look.
final class FaceFrame {
  const FaceFrame({
    required this.model,
    required this.tier,
    required this.dark,
    required this.brand,
    required this.ring,
    required this.segments,
    required this.bars,
    required this.health,
    this.sway = 0,
    this.leaf,
  });

  /// The copy and states; its count and time may be mid-roll.
  final WidgetModel model;

  /// The look: this tier's palette (and bonsai stage) in the dark or light
  /// theme.
  final int tier;
  final bool dark;

  /// The app theme's primary (ARGB): tier 0 takes its hue ([BrandTint]).
  final int brand;

  /// Next colour's ring, 0..100 %.
  final double ring;

  /// Lit Time limit segments, 0..12; a fraction blends the next one in.
  final double segments;

  /// Rhythm's 24 bars, as fractions of the bar box.
  final List<double> bars;

  /// The bonsai's health bar, 0..100 %.
  final double health;

  /// The bonsai's sway in degrees, about (50, 70) in tree units.
  final double sway;

  /// The falling leaf's eased travel (0..1) and opacity; null when none falls.
  final ({double travel, double opacity})? leaf;
}

/// A board text style: CSS `font-size`, `font-weight` and `letter-spacing`,
/// in px. Always Manrope with tabular figures (DS-03).
final class FaceFont {
  const FaceFont(this.size, {this.weight = FontWeight.w700, this.spacing = 0});

  final double size;
  final FontWeight weight;
  final double spacing;
}

/// The board's shared text classes (Library.dc.html L26-31).
abstract final class FaceFonts {
  /// `.lblS`: small labels and chips.
  static const lblS = FaceFont(WidgetTokens.labelS);

  /// `.lbl`: Large band labels.
  static const lbl = FaceFont(WidgetTokens.labelL);

  /// `.valS`: small values.
  static const valS = FaceFont(WidgetTokens.valueS);

  /// `.val`: large values.
  static const val = FaceFont(WidgetTokens.valueL, spacing: -0.4);
}

/// The clock icon beside a value: its side, its stroke on the 24-unit grid,
/// and the gap before the text.
typedef FaceClock = ({double size, double stroke, double gap});

/// The clock beside a `.valS` value, on Small bands and in panels.
const FaceClock clockS = (size: 14, stroke: 2.4, gap: 5);

/// One size's bottom band (DS-04): height, side padding, its label and value
/// type, and the clock beside the value.
enum FaceBand {
  small(
    WidgetTokens.bandS,
    WidgetTokens.insetS,
    FaceFonts.lblS,
    FaceFonts.valS,
    clockS,
  ),
  medium(
    WidgetTokens.bandM,
    WidgetTokens.insetM,
    FaceFont(WidgetTokens.labelM),
    FaceFont(WidgetTokens.valueM),
    (size: 16, stroke: 2.4, gap: 5),
  ),
  large(WidgetTokens.bandL, WidgetTokens.insetL, FaceFonts.lbl, FaceFonts.val, (
    size: 18,
    stroke: 2.2,
    gap: 6,
  ));

  const FaceBand(this.height, this.pad, this.label, this.value, this.clock);

  static FaceBand of(WidgetSize size) => switch (size) {
    WidgetSize.small => small,
    WidgetSize.medium => medium,
    WidgetSize.large => large,
  };

  final double height;
  final double pad;
  final FaceFont label;
  final FaceFont value;
  final FaceClock clock;
}

/// A tier tile's colours (the board's `widget()`): the background, hairline
/// and inks of one tier in one theme (DS-02 / DS-06).
typedef TileLook = ({
  // Light: the 135° gradient's ends. Dark: the surface (from == to).
  Color from,
  Color to,
  // Dark tiers 1-5: the accent glowing from the top-left.
  Color? glow,
  Color? hairline,
  Color ink,
  Color muted,
  Color band,
  Color faint,
  Color fill,
  Color count,
});

/// Every tier is in [brand]'s hue, the app theme's primary: tier 0 the empty
/// tile ([BrandTint.at]), 1–5 the usage ramp ([BrandTint.ramp]).
TileLook tileLook(int tier, {required bool dark, required int brand}) {
  if (dark) {
    final accent = darkAccent(tier, brand);
    final surface = tier == 0
        ? WidgetTokens.darkEmpty
        : WidgetTokens.darkSurface;
    return (
      from: surface,
      to: surface,
      glow: accent,
      hairline: WidgetTokens.darkHairline,
      ink: WidgetTokens.darkInk,
      muted: WidgetTokens.darkMuted,
      band: WidgetTokens.darkBand,
      faint: WidgetTokens.darkFaint,
      fill: accent,
      count: accent,
    );
  }
  // Tiers 4-5 turn to white ink on the dark band (DS-05).
  final inverse = tier >= 4;
  final ink = inverse ? WidgetTokens.widgetInkInverse : WidgetTokens.widgetInk;
  final empty = Color(BrandTint.at(brand, BrandTint.tileLight));
  return (
    from: tier == 0
        ? empty
        : Color(BrandTint.ramp(brand, BrandTint.tileFrom[tier - 1])),
    to: tier == 0
        ? empty
        : Color(BrandTint.ramp(brand, BrandTint.tileTo[tier - 1])),
    glow: null,
    hairline: tier == 0 ? WidgetTokens.hairlineEmpty : null,
    ink: ink,
    muted: inverse
        ? WidgetTokens.widgetInkInverse
        : WidgetTokens.widgetInkMuted,
    band: inverse ? WidgetTokens.bandDark : WidgetTokens.bandLight,
    faint: inverse ? WidgetTokens.faintInverse : WidgetTokens.faintLight,
    fill: ink,
    count: tier == 0 ? Color(BrandTint.at(brand, BrandTint.countLight)) : ink,
  );
}

/// The dark theme's accent for [tier], in [brand]'s hue, calm → vivid.
Color darkAccent(int tier, int brand) => Color(
  BrandTint.ramp(
    brand,
    BrandTint.accentDarkY[tier],
    BrandTint.accentDarkS[tier],
  ),
);

/// Bento's dot and Bonsai's health bar for [tier]: on a light module the
/// ramp's [BrandTint.dotLight], on a dark one the [darkAccent].
Color tierDot(int tier, {required bool dark, required int brand}) => dark
    ? darkAccent(tier, brand)
    : Color(BrandTint.ramp(brand, BrandTint.dotLight[tier]));

/// Bento's neutral shell and calm modules; only `dot` (its status dot and
/// mini ring) carries the tier.
typedef BentoLook = ({
  Color shell,
  Color module,
  Color ink,
  Color muted,
  Color faint,
  Color dot,
  Color? hairline,
});

/// The dot is [tierDot].
BentoLook bentoLook(int tier, {required bool dark, required int brand}) => dark
    ? (
        shell: WidgetTokens.bentoShellDark,
        module: WidgetTokens.bentoModuleDark,
        ink: WidgetTokens.bentoInkDark,
        muted: WidgetTokens.bentoMutedDark,
        faint: WidgetTokens.bentoFaintDark,
        dot: tierDot(tier, dark: true, brand: brand),
        hairline: WidgetTokens.darkHairline,
      )
    : (
        shell: WidgetTokens.bentoShellLight,
        module: WidgetTokens.bentoModuleLight,
        ink: WidgetTokens.bentoInkLight,
        muted: WidgetTokens.bentoMutedLight,
        faint: WidgetTokens.bentoFaintLight,
        dot: tierDot(tier, dark: false, brand: brand),
        hairline: null,
      );

/// Bonsai's neutral tile, its tree in the stage of one tier (natural
/// colours), and the health `bar` in the theme's ramp ([tierDot]).
typedef BonsaiLook = ({
  Color bg,
  Color ink,
  Color muted,
  Color band,
  Color track,
  Color ground,
  Color hairline,
  Color leaf,
  Color highlight,
  Color bark,
  Color bar,
});

BonsaiLook bonsaiLook(int tier, {required bool dark, required int brand}) => (
  bg: dark ? WidgetTokens.bonsaiBgDark : WidgetTokens.bonsaiBgLight,
  ink: dark ? WidgetTokens.bonsaiInkDark : WidgetTokens.bonsaiInkLight,
  muted: dark ? WidgetTokens.bonsaiMutedDark : WidgetTokens.bonsaiMutedLight,
  band: dark ? WidgetTokens.bonsaiBandDark : WidgetTokens.bonsaiBandLight,
  track: dark ? WidgetTokens.bonsaiTrackDark : WidgetTokens.bonsaiTrackLight,
  ground: dark ? WidgetTokens.bonsaiGroundDark : WidgetTokens.bonsaiGroundLight,
  hairline: dark
      ? WidgetTokens.bonsaiHairlineDark
      : WidgetTokens.bonsaiHairlineLight,
  leaf: WidgetTokens.bonsaiLeaf[tier],
  highlight: WidgetTokens.bonsaiHighlight[tier],
  bark: WidgetTokens.bonsaiBark[tier],
  bar: tierDot(tier, dark: dark, brand: brand),
);

/// Laid-out text kept across frames, so a swaying bonsai does not re-shape
/// its labels on every frame. The preview owns one and clears it on dispose.
final class FaceTextCache {
  final _painters =
      <(String, double, FontWeight, double, Color), TextPainter>{};

  TextPainter layout(String text, FaceFont font, Color color) {
    final key = (text, font.size, font.weight, font.spacing, color);
    final hit = _painters[key];
    if (hit != null) return hit;
    // ponytail: wholesale eviction, since a rolling count churns a new string
    // per frame for 800 ms; an LRU if a profile ever shows the re-layouts.
    if (_painters.length >= 64) clear();
    return _painters[key] = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontFamily: 'Manrope',
          fontSize: font.size,
          fontWeight: font.weight,
          letterSpacing: font.spacing,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  void clear() {
    for (final p in _painters.values) {
      p.dispose();
    }
    _painters.clear();
  }
}

/// The board's parts (Library.dc.html CSS L16-35), drawn in design units:
/// [canvas] is already scaled to the preview, [box] is the face's `W x H`.
final class FaceCanvas {
  FaceCanvas(this.canvas, this.box, this._texts);

  final Canvas canvas;
  final Size box;
  final FaceTextCache _texts;

  double get w => box.width;
  double get h => box.height;

  /// The whole box at [size]'s corner radius.
  RRect shape(WidgetSize size) => RRect.fromRectAndRadius(
    Offset.zero & box,
    Radius.circular(switch (size) {
      WidgetSize.small => WidgetTokens.radiusS,
      WidgetSize.medium => WidgetTokens.radiusM,
      WidgetSize.large => WidgetTokens.radiusL,
    }),
  );

  /// The tier tile over the whole box; returns its shape for the band.
  RRect tile(WidgetSize size, TileLook look) {
    final tile = shape(size);
    tierFill(tile, look);
    hairline(tile, look.hairline);
    return tile;
  }

  /// A tier background in [shape] (a tile or Bento's count module): the
  /// light 135° gradient between its CSS end points, or the dark surface with
  /// its tier glow; then the sheen.
  void tierFill(RRect shape, TileLook look) {
    final r = shape.outerRect;
    final paint = Paint()..color = look.from;
    if (look.from != look.to) {
      final d = Offset(r.width + r.height, r.width + r.height) / 4;
      paint.shader = ui.Gradient.linear(r.center - d, r.center + d, [
        look.from,
        look.to,
      ]);
    }
    canvas.drawRRect(shape, paint);
    final glow = look.glow;
    if (glow != null) {
      // radial-gradient(130% 100% at 0% 0%, accent 47 0%, accent 00 62%)
      _radial(
        shape,
        r.topLeft,
        Size(1.3 * r.width, r.height),
        glow.withAlpha(WidgetTokens.darkGlowAlpha),
        0.62,
      );
    }
    // .sheen: radial-gradient(90% 70% at 12% 0%, sheen 0%, transparent 60%)
    _radial(
      shape,
      Offset(r.left + 0.12 * r.width, r.top),
      Size(0.9 * r.width, 0.7 * r.height),
      WidgetTokens.sheen,
      0.6,
    );
  }

  /// An elliptical CSS radial gradient in [shape]: [color] at [centre], gone
  /// at [stop] of the [radii].
  void _radial(
    RRect shape,
    Offset centre,
    Size radii,
    Color color,
    double stop,
  ) {
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          1,
          [color, color.withAlpha(0)],
          [0, stop],
          TileMode.clamp,
          Float64List.fromList([
            radii.width, 0, 0, 0, //
            0, radii.height, 0, 0,
            0, 0, 1, 0,
            centre.dx, centre.dy, 0, 1,
          ]),
        ),
    );
  }

  /// A flat fill (Bonsai's tile, Bento's shell and modules), then [hairline].
  void surface(RRect shape, Color fill, [Color? hairline]) {
    canvas.drawRRect(shape, Paint()..color = fill);
    this.hairline(shape, hairline);
  }

  /// CSS `inset 0 0 0 1px`: a one-unit line just inside [shape]'s edge.
  void hairline(RRect shape, Color? color) {
    if (color == null) return;
    canvas.drawRRect(
      shape.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color,
    );
  }

  /// The bottom band of [tile] tinted [fill], with a [row] of [label] and
  /// [value] (after a clock when [clock]).
  void band(
    RRect tile,
    FaceBand band, {
    required String label,
    required String value,
    required bool clock,
    required Color fill,
    required Color labelInk,
    required Color valueInk,
  }) {
    final r = Rect.fromLTRB(
      tile.left,
      tile.bottom - band.height,
      tile.right,
      tile.bottom,
    );
    // Taller than the corner radius, so its rounded bottom corners trace the
    // tile's exactly; no clip needed.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        r,
        bottomLeft: tile.blRadius,
        bottomRight: tile.brRadius,
      ),
      Paint()..color = fill,
    );
    row(
      r,
      band.pad,
      band,
      label: label,
      value: value,
      clock: clock,
      labelInk: labelInk,
      valueInk: valueInk,
    );
  }

  /// A `label | value` line centred in [area], [pad] in from each side (a
  /// band, or Bento's bottom module): the value keeps its size and the label
  /// shrinks into what is left. An empty [value] leaves the line to [label].
  void row(
    Rect area,
    double pad,
    FaceBand type, {
    required String label,
    required String value,
    required Color labelInk,
    required Color valueInk,
    bool clock = false,
  }) {
    final cy = area.center.dy;
    final inner = area.width - 2 * pad;
    final valueWidth = value.isEmpty
        ? 0.0
        : text(
                value,
                type.value,
                valueInk,
                x: area.right - pad,
                cy: cy,
                align: TextAlign.right,
                maxWidth: inner,
                clock: clock ? type.clock : null,
              ) +
              WidgetTokens.bandGap;
    text(
      label,
      type.label,
      labelInk,
      x: area.left + pad,
      cy: cy,
      maxWidth: inner - valueWidth,
    );
  }

  /// A pill chip (`.chip`: 24 high, padded 10, `.lblS`) whose [align] edge
  /// sits at [x]. Returns its rect so a hero can stop short of it.
  Rect chip(
    String label, {
    required double x,
    required double top,
    required Color fill,
    required Color ink,
    TextAlign align = TextAlign.left,
  }) {
    final width =
        _texts.layout(label, FaceFonts.lblS, ink).width +
        2 * WidgetTokens.chipPad;
    final r = Rect.fromLTWH(
      _start(x, width, align),
      top,
      width,
      WidgetTokens.chipHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(r.height / 2)),
      Paint()..color = fill,
    );
    text(
      label,
      FaceFonts.lblS,
      ink,
      x: r.left + WidgetTokens.chipPad,
      cy: r.center.dy,
    );
    return r;
  }

  /// A `.panel` (radius 22) tinted [fill]; returns its content box.
  Rect panel(Rect r, Color fill) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        r,
        const Radius.circular(WidgetTokens.panelRadius),
      ),
      Paint()..color = fill,
    );
    return _panelPadding.deflateRect(r);
  }

  static const _panelPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 14,
  );

  /// The centre lines of a column of lines [heights] high in [content]:
  /// grouped in the middle 6 apart (a `.panel`), or with [spread] the first
  /// at the top and the last at the bottom (`space-between`).
  List<double> column(
    Rect content,
    List<double> heights, {
    bool spread = false,
  }) {
    final lines = heights.fold(0.0, (sum, h) => sum + h);
    final gap = spread ? (content.height - lines) / (heights.length - 1) : 6.0;
    var y = spread
        ? content.top
        : content.center.dy - (lines + gap * (heights.length - 1)) / 2;
    final centres = <double>[];
    for (final h in heights) {
      centres.add(y + h / 2);
      y += h + gap;
    }
    return centres;
  }

  /// A `.cnt` hero: one line (line-height 1) whose box tops out at [top]
  /// from [left], shrunk to end by [end].
  void hero(
    String s,
    FaceFont font,
    Color color, {
    required double left,
    required double top,
    required double end,
  }) => text(
    s,
    font,
    color,
    x: left,
    cy: top + font.size / 2,
    maxWidth: end - left,
  );

  /// One line of [s] whose [align] edge sits at [x], its CSS line box centred
  /// on [cy] (the glyph box is centred in it, as with Manrope's zero line
  /// gap), after a [clock] when given. Text wider than [maxWidth] shrinks to
  /// fit. Returns the drawn width.
  double text(
    String s,
    FaceFont font,
    Color color, {
    required double x,
    required double cy,
    TextAlign align = TextAlign.left,
    double? maxWidth,
    FaceClock? clock,
  }) {
    final tp = _texts.layout(s, font, color);
    final lead = clock == null ? 0.0 : clock.size + clock.gap;
    final natural = lead + tp.width;
    final k = maxWidth != null && natural > maxWidth
        ? math.max(0.0, maxWidth) / natural
        : 1.0;
    canvas
      ..save()
      ..translate(_start(x, natural * k, align), cy)
      ..scale(k);
    if (clock != null) _clock(clock, color);
    tp.paint(canvas, Offset(lead, -tp.height / 2));
    canvas.restore();
    return natural * k;
  }

  static double _start(double x, double width, TextAlign align) =>
      switch (align) {
        TextAlign.right => x - width,
        TextAlign.center => x - width / 2,
        _ => x,
      };

  /// The board's clock (24-unit grid: circle r9 plus `M12 7v5l3 2`), its
  /// left edge at the origin, centred on the line.
  void _clock(FaceClock clock, Color color) {
    canvas
      ..save()
      ..translate(0, -clock.size / 2)
      ..scale(clock.size / 24);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = clock.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas
      ..drawCircle(const Offset(12, 12), 9, stroke)
      ..drawPath(_hands, stroke)
      ..restore();
  }

  static final _hands = Path()
    ..moveTo(12, 7)
    ..lineTo(12, 12)
    ..lineTo(15, 14);

  /// A progress ring: the [track], then [pct] % of it in [fill] from twelve
  /// o'clock with round caps; nothing at 0 %.
  void ring(
    Offset centre,
    double radius,
    double stroke,
    double pct, {
    required Color track,
    required Color fill,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(centre, radius, paint);
    if (pct <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      2 * math.pi * math.min(pct, 100) / 100,
      false,
      paint
        ..strokeCap = StrokeCap.round
        ..color = fill,
    );
  }

  /// Time limit's 12 segments across [r]: the first [on] in [fill], the rest
  /// [faint], a fractional one blended.
  void segments(
    Rect r, {
    required double gap,
    required double radius,
    required double on,
    required Color fill,
    required Color faint,
  }) {
    const n = WidgetModel.segmentCount;
    final width = (r.width - gap * (n - 1)) / n;
    final paint = Paint();
    for (var i = 0; i < n; i++) {
      final left = r.left + i * (width + gap);
      paint.color = Color.lerp(faint, fill, (on - i).clamp(0.0, 1.0))!;
      canvas.drawRRect(
        RRect.fromLTRBR(
          left,
          r.top,
          left + width,
          r.bottom,
          Radius.circular(radius),
        ),
        paint,
      );
    }
  }

  /// Rhythm's bars across [r], bottom-aligned at [values] of its height; the
  /// [peak] bar in [fill], the rest [faint].
  void bars(
    Rect r, {
    required double gap,
    required double radius,
    required List<double> values,
    required int peak,
    required Color fill,
    required Color faint,
  }) {
    final width = (r.width - gap * (values.length - 1)) / values.length;
    for (var i = 0; i < values.length; i++) {
      final left = r.left + i * (width + gap);
      canvas.drawRRect(
        RRect.fromLTRBR(
          left,
          r.bottom - r.height * values[i],
          left + width,
          r.bottom,
          Radius.circular(radius),
        ),
        Paint()..color = i == peak ? fill : faint,
      );
    }
  }

  /// The bonsai in its 100-unit box, scaled into [box], at [tier]'s stage:
  /// Library.dc.html `bonsai()` (L608-649) over the SVG at L301-328, drawn
  /// in SVG order.
  void bonsai(
    Rect box,
    int tier,
    BonsaiLook look, {
    double sway = 0,
    ({double travel, double opacity})? leaf,
  }) {
    canvas
      ..save()
      ..translate(box.left, box.top)
      ..scale(box.width / 100)
      ..drawOval(_ground, Paint()..color = look.ground);
    final fill = Paint()..color = look.leaf;
    for (final fallen in _fallen.take(_fallenCount[tier])) {
      canvas.drawOval(fallen, fill);
    }

    canvas
      ..save()
      ..translate(50, 70)
      ..rotate(sway * math.pi / 180)
      ..translate(-50, -70);
    final bark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = look.bark;
    canvas
      ..drawPath(_trunk, bark..strokeWidth = 4.6)
      ..drawPath(_branchLeft, bark..strokeWidth = 2.6)
      ..drawPath(_branchRight, bark..strokeWidth = 2.4);
    final cracks = _cracksOpacity[tier];
    if (cracks > 0) {
      canvas.drawPath(
        _cracks,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = WidgetTokens.bonsaiCrack.withValues(alpha: cracks),
      );
    }
    for (final i in _keep[tier]) {
      final (centre, radius, highlight) = _pads[i];
      final r = radius * _padSize[tier];
      canvas
        ..drawCircle(centre, r, fill)
        ..drawCircle(highlight, r / 2, Paint()..color = look.highlight);
    }
    if (tier == 0) {
      final blossom = Paint()..color = WidgetTokens.bonsaiBlossom;
      for (final (centre, radius) in _blossoms) {
        canvas.drawCircle(centre, radius, blossom);
      }
    }
    canvas.restore();

    if (leaf != null) {
      canvas
        ..save()
        ..translate(64 - 8 * leaf.travel, 46 + 46 * leaf.travel)
        ..rotate(200 * leaf.travel * math.pi / 180)
        ..drawOval(
          Rect.fromCenter(center: Offset.zero, width: 4, height: 2),
          Paint()..color = look.leaf.withValues(alpha: leaf.opacity),
        )
        ..restore();
    }

    canvas
      ..drawPath(_pot, Paint()..color = WidgetTokens.bonsaiPot)
      ..drawRRect(_rim, Paint()..color = WidgetTokens.bonsaiRim);
    if (tier <= 1) {
      final cheek = Paint()
        ..color = WidgetTokens.bonsaiCheek.withValues(alpha: 0.55);
      canvas
        ..drawCircle(const Offset(39.5, 82), 2, cheek)
        ..drawCircle(const Offset(60.5, 82), 2, cheek);
    }
    final face = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = WidgetTokens.bonsaiFace;
    canvas
      ..drawPath(
        tier == 0
            ? _eyesClosed
            : tier >= 4
            ? _eyesWorried
            : _eyesOpen,
        face..strokeWidth = 1.8,
      )
      ..drawPath(_mouths[tier], face..strokeWidth = 1.6);
    if (tier == 5) {
      canvas.drawCircle(
        const Offset(57.6, 81.4),
        1,
        Paint()..color = WidgetTokens.bonsaiTear,
      );
    }
    canvas.restore();
  }

  // The bonsai's tables, Library.dc.html L610-623: the pads each stage keeps
  // and their scale, the fallen leaves showing, and the cracks' opacity.
  static const _keep = [
    [0, 1, 2, 3, 4],
    [0, 1, 2, 3, 4],
    [0, 1, 2, 4],
    [1, 2, 4],
    [0, 2],
    <int>[],
  ];
  static const _padSize = <double>[1, 1, 0.92, 0.82, 0.62, 0];
  static const _fallenCount = [0, 0, 1, 3, 5, 6];
  static const _cracksOpacity = <double>[0, 0, 0, 0, 0.45, 1];

  // The SVG's shapes, in tree units (L302-328).
  static const _ground = Rect.fromLTRB(26, 88.4, 74, 93.6);
  static const _fallen = [
    Rect.fromLTRB(26.7, 88.6, 31.3, 90.6),
    Rect.fromLTRB(67.7, 88.8, 72.3, 90.8),
    Rect.fromLTRB(31.9, 89.5, 36.1, 91.3),
    Rect.fromLTRB(62.9, 89.7, 67.1, 91.5),
    Rect.fromLTRB(22, 89.7, 26, 91.5),
    Rect.fromLTRB(73, 89.3, 77, 91.1),
  ];
  static const _pads = [
    (Offset(33, 41), 10.0, Offset(30.5, 38.5)),
    (Offset(66, 34), 11.0, Offset(63.5, 31.5)),
    (Offset(51, 25), 13.0, Offset(48, 22)),
    (Offset(40, 30), 9.0, Offset(38, 28)),
    (Offset(60, 45), 8.5, Offset(58, 43)),
  ];
  static const _blossoms = [
    (Offset(29, 37), 1.6),
    (Offset(37, 44), 1.4),
    (Offset(47, 20), 1.6),
    (Offset(56, 27), 1.4),
    (Offset(69, 31), 1.6),
    (Offset(62, 47), 1.4),
  ];
  static final _rim = RRect.fromLTRBR(27, 67, 73, 72, const Radius.circular(2));

  // M50 70 C49 62 46 58 47 50 C48 44 53 41 52 32
  static final _trunk = Path()
    ..moveTo(50, 70)
    ..cubicTo(49, 62, 46, 58, 47, 50)
    ..cubicTo(48, 44, 53, 41, 52, 32);
  // M47.5 52 C42 50 38 47 34 43
  static final _branchLeft = Path()
    ..moveTo(47.5, 52)
    ..cubicTo(42, 50, 38, 47, 34, 43);
  // M51 43 C56 41 60 39 65 36
  static final _branchRight = Path()
    ..moveTo(51, 43)
    ..cubicTo(56, 41, 60, 39, 65, 36);
  // M48.5 60 L46.5 63 M52 46 L54.2 48.4 M40 48 L38.6 46
  static final _cracks = Path()
    ..moveTo(48.5, 60)
    ..lineTo(46.5, 63)
    ..moveTo(52, 46)
    ..lineTo(54.2, 48.4)
    ..moveTo(40, 48)
    ..lineTo(38.6, 46);
  // M29 70 H71 L66.5 90 H33.5 Z
  static final _pot = Path()
    ..moveTo(29, 70)
    ..lineTo(71, 70)
    ..lineTo(66.5, 90)
    ..lineTo(33.5, 90)
    ..close();
  // EYES.closed: M42 78.6 Q44 76.6 46 78.6 M54 78.6 Q56 76.6 58 78.6
  static final _eyesClosed = Path()
    ..moveTo(42, 78.6)
    ..quadraticBezierTo(44, 76.6, 46, 78.6)
    ..moveTo(54, 78.6)
    ..quadraticBezierTo(56, 76.6, 58, 78.6);
  // EYES.open: M44 78 L44 78.4 M56 78 L56 78.4
  static final _eyesOpen = Path()
    ..moveTo(44, 78)
    ..lineTo(44, 78.4)
    ..moveTo(56, 78)
    ..lineTo(56, 78.4);
  // EYES.worried: M44 78.4 L44 78.8 M56 78.4 L56 78.8
  //   M41.6 75.6 L45.6 74.4 M58.4 75.6 L54.4 74.4
  static final _eyesWorried = Path()
    ..moveTo(44, 78.4)
    ..lineTo(44, 78.8)
    ..moveTo(56, 78.4)
    ..lineTo(56, 78.8)
    ..moveTo(41.6, 75.6)
    ..lineTo(45.6, 74.4)
    ..moveTo(58.4, 75.6)
    ..lineTo(54.4, 74.4);
  // MOUTH[0..5]
  static final _mouths = [
    // M45 82.5 Q50 87.5 55 82.5
    Path()
      ..moveTo(45, 82.5)
      ..quadraticBezierTo(50, 87.5, 55, 82.5),
    // M46 83 Q50 86.5 54 83
    Path()
      ..moveTo(46, 83)
      ..quadraticBezierTo(50, 86.5, 54, 83),
    // M47 83.5 Q50 85.2 53 83.5
    Path()
      ..moveTo(47, 83.5)
      ..quadraticBezierTo(50, 85.2, 53, 83.5),
    // M46.5 84.2 L53.5 84.2
    Path()
      ..moveTo(46.5, 84.2)
      ..lineTo(53.5, 84.2),
    // M46.5 85.5 Q50 82.8 53.5 85.5
    Path()
      ..moveTo(46.5, 85.5)
      ..quadraticBezierTo(50, 82.8, 53.5, 85.5),
    // M46 86 Q50 82.3 54 86
    Path()
      ..moveTo(46, 86)
      ..quadraticBezierTo(50, 82.3, 54, 86),
  ];
}
