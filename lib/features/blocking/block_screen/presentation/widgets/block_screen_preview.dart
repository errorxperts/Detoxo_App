import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/blocking/block_screen/domain/entities/block_screen_copy.dart';
import 'package:detoxo/features/blocking/block_screen/domain/entities/block_screen_payload.dart';
import 'package:detoxo/features/blocking/block_screen/domain/entities/block_screen_style.dart';
import 'package:detoxo/features/content_counter/content_counter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

/// Flutter mirror of the native block screen (`overlay/QuoteWall.kt` and the
/// button column in `overlay/BlockScreenRenderer.kt` — the declared source of
/// truth): Face Down when the app theme is light, Spotlight when it is dark,
/// on the theme primary. Drawn on a fixed board in native dp — 360 × 780, or
/// the Appearance card's 352 × 220 crop when [compact] (header, quote, button
/// row) — that a [FittedBox] scales to [height], so every size is the native
/// one, as is.
///
/// MIRROR CONTRACT: colours come from [wallPaletteFor], copy from
/// [BlockScreenCopy]; only the layout lives here.
class BlockScreenPreview extends StatelessWidget {
  const BlockScreenPreview({
    required this.style,
    this.payload,
    this.height = 300,
    this.compact = false,
    super.key,
  });

  final BlockScreenStyle style;
  final BlockScreenPayload? payload;
  final double height;
  final bool compact;

  static const _board = Size(360, 780);
  static const _compactBoard = Size(352, 220);

  @override
  Widget build(BuildContext context) {
    final p = (payload ?? BlockScreenPayload.preview()).sanitised();
    // The app theme's brightness and primary (native reads the same values,
    // pushed as themeMode and brandLight / brandDark).
    final b = Theme.of(context).brightness;
    final dark = b == Brightness.dark;
    final accent = brandFor(BackgroundScope.of(context, b), b).primary;
    final palette = wallPaletteFor(dark: dark, accent: accent);
    final copy = BlockScreenCopy.from(p, style);
    final board = compact ? _compactBoard : _board;
    final off = !style.enabled;

    final wall = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.ground,
        borderRadius: AppRadius.brLg,
      ),
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: palette.ink.withValues(alpha: 0.12)),
        borderRadius: AppRadius.brLg,
      ),
      child: FittedBox(
        child: SizedBox.fromSize(
          size: board,
          // A picture of the wall: nothing in it takes a tap or focus, and
          // the reader's text size is already in the scale.
          child: IgnorePointer(
            child: ExcludeFocus(
              child: MediaQuery.withNoTextScaling(
                child: _Wall(
                  copy: copy,
                  palette: palette,
                  accent: accent,
                  dark: dark,
                  compact: compact,
                  still: off,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final ease = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppDurations.normal;
    return Semantics(
      label:
          'Block screen preview${off ? ', off' : ''}. ${copy.semanticsLabel}',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: height * board.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Switched off, the wall eases to a faded grey. The filter is
            // always there (identity while on): adding it only when off would
            // rebuild the wall under it, replaying the quote's fade-up.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: off ? 1 : 0, end: off ? 1 : 0),
              duration: ease,
              curve: AppCurves.standard,
              builder: (_, t, child) => ColorFiltered(
                colorFilter: ColorFilter.matrix(_offMatrix(t)),
                child: child,
              ),
              child: wall,
            ),
            Positioned(
              top: AppSpacing.xs,
              right: AppSpacing.xs,
              child: AnimatedSwitcher(
                duration: ease,
                child: off
                    ? const AppBadge.label('Off')
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Identity at [t] 0; at 1, greyscale (Rec. 709 luma) at 60 % alpha — the
/// switched-off wall.
List<double> _offMatrix(double t) {
  const r = 0.2126;
  const g = 0.7152;
  const b = 0.0722;
  final k = 1 - t;
  return [
    k + t * r, t * g, t * b, 0, 0, //
    t * r, k + t * g, t * b, 0, 0,
    t * r, t * g, k + t * b, 0, 0,
    0, 0, 0, 1 - 0.4 * t, 0,
  ];
}

/// The canvas's own samples — sr 46 and sr 48 of
/// `assets/content/motivational_quotes.json`. The real wall draws one of the
/// hundred at random, natively (`overlay/QuoteBook.kt`).
const _faceDownQuote = (
  text: 'Do not let the behavior of others destroy your inner peace.',
  writer: 'Dalai Lama',
);
const _spotlightQuote = (
  text:
      'Within you, there is a stillness and a sanctuary to which you can '
      'retreat at any time and be yourself.',
  writer: 'Hermann Hesse',
);

/// sr 62: the Appearance card's two lines hold only a short quote at
/// Spotlight's size.
const _shortQuote = (
  text: 'Lost time is never found again.',
  writer: 'Benjamin Franklin',
);

/// Manrope at [size] board dp, through the theme like the app's other widgets
/// — from the slot of the same weight, so the bundled Bold / ExtraBold file is
/// the one drawn rather than a synthesised one.
TextStyle _type(
  BuildContext context,
  double size,
  Color color, {
  FontWeight weight = FontWeight.w400,
  double height = 1.35,
  double spacing = 0,
}) {
  final t = Theme.of(context).textTheme;
  final base = switch (weight) {
    FontWeight.w800 => t.headlineSmall,
    FontWeight.w700 => t.titleLarge,
    _ => t.bodyMedium,
  };
  return (base ?? const TextStyle()).copyWith(
    color: color,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: spacing,
  );
}

/// The wall itself (MIRROR CONTRACT: `QuoteWallView`). Only the full stage
/// moves — a compact card holds still, so the Appearance hub runs no ticker —
/// and nothing moves under "Remove animations". Spotlight's light only drifts
/// here: following a finger would fight the editor's scrolling ("Try it" has
/// the real one).
class _Wall extends StatefulWidget {
  const _Wall({
    required this.copy,
    required this.palette,
    required this.accent,
    required this.dark,
    required this.compact,
    this.still = false,
  });

  final BlockScreenCopy copy;
  final WallPalette palette;
  final Color accent;
  final bool dark;
  final bool compact;

  /// Switched off: the motion holds on its current frame.
  final bool still;

  @override
  State<_Wall> createState() => _WallState();
}

class _WallState extends State<_Wall> with TickerProviderStateMixin {
  final _clock = ValueNotifier<Duration>(Duration.zero);
  Ticker? _ticker;
  ImageStream? _logoStream;
  ImageInfo? _logo;
  late final _onLogo = ImageStreamListener((info, synchronous) {
    void swap() {
      _logo?.dispose();
      _logo = info;
    }

    synchronous ? swap() : setState(swap);
  });

  /// Whether the stage animates at all; [_Wall.still] only pauses it.
  bool get _moving =>
      !widget.compact && !MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
    final stream = _logoImage.resolve(createLocalImageConfiguration(context));
    if (stream.key != _logoStream?.key) {
      _logoStream?.removeListener(_onLogo);
      _logoStream = stream..addListener(_onLogo);
    }
  }

  @override
  void didUpdateWidget(_Wall old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (_moving && !widget.still) {
      // From the frame a pause left it on, not the loop's start.
      final from = _clock.value;
      _ticker ??= createTicker((elapsed) => _clock.value = from + elapsed)
        ..start();
    } else if (_ticker != null) {
      _ticker!.dispose();
      _ticker = null;
      // Paused, the stage holds its frame; with no motion at all it rests.
      if (!_moving) _clock.value = Duration.zero;
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _clock.dispose();
    _logoStream?.removeListener(_onLogo);
    _logo?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final p = w.palette;
    final copy = w.copy;
    final dark = w.dark;
    final moving = _moving;
    final quote = !dark
        ? _faceDownQuote
        : (w.compact ? _shortQuote : _spotlightQuote);
    final align = dark ? TextAlign.start : TextAlign.center;
    final cross = dark ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final gap = dark ? 16.0 : 14.0;
    // The white logo in the theme primary wherever the ground is light.
    final logoTint = legibleOn(w.accent, ground: p.ground, ink: p.ink);
    final header = _Header(
      logo: _logo?.image,
      accent: w.accent,
      ink: p.ink,
      dark: dark,
      tint: logoTint,
    );
    final quoteText = Text(
      quote.text,
      textAlign: align,
      maxLines: w.compact ? 2 : (dark ? 6 : 4),
      overflow: TextOverflow.ellipsis,
      style: _type(context, dark ? 24 : 18, p.ink, height: dark ? 1.25 : 1.35)
          .copyWith(
            fontFamily: 'serif',
            fontStyle: dark ? FontStyle.normal : FontStyle.italic,
          ),
    );
    final buttons = _Buttons(
      copy: copy,
      palette: p,
      accent: w.accent,
      compact: w.compact,
    );

    final Widget body;
    if (w.compact) {
      body = Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          crossAxisAlignment: cross,
          children: [
            header,
            Expanded(
              child: Align(
                alignment: dark ? Alignment.centerLeft : Alignment.center,
                child: quoteText,
              ),
            ),
            buttons,
          ],
        ),
      );
    } else {
      // Both designs fade the quote up; its writer follows 0.3 s later.
      final words = <Widget>[
        _FadeUp(moving: moving, child: quoteText),
        SizedBox(height: dark ? 12 : 6),
        _FadeUp(
          moving: moving,
          delayMs: 300,
          child: Text(
            dark ? quote.writer.toUpperCase() : quote.writer,
            textAlign: align,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _type(
              context,
              dark ? 11 : 13,
              p.muted,
              weight: FontWeight.w700,
              spacing: dark ? 1.1 : 0,
            ),
          ),
        ),
      ];
      final line = dark ? copy.spotlightLine : copy.faceDownLine;
      final ease = moving ? const Duration(milliseconds: 200) : Duration.zero;
      body = Padding(
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 20),
        child: Column(
          crossAxisAlignment: cross,
          children: [
            header,
            SizedBox(height: gap),
            if (dark)
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: cross,
                    children: words,
                  ),
                ),
              )
            else ...[
              Expanded(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _PhonePainter(
                    _clock,
                    _logo?.image,
                    tint: logoTint,
                    moving: moving,
                  ),
                ),
              ),
              Text(
                BlockScreenCopy.faceDownTitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _type(
                  context,
                  24,
                  p.ink,
                  weight: FontWeight.w800,
                  height: 1.15,
                  spacing: -0.48, // −0.02 em
                ),
              ),
              SizedBox(height: gap),
              ...words,
            ],
            SizedBox(height: gap),
            // The sub-line and the meta line: an option flip eases in place.
            AnimatedSize(
              duration: ease,
              curve: AppCurves.standard,
              child: AnimatedSwitcher(
                duration: ease,
                child: SizedBox(
                  key: ValueKey((line, copy.meta)),
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: cross,
                    children: [
                      Text(
                        line,
                        textAlign: align,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        // The system sans, as natively (QuoteWall's line).
                        style: _type(
                          context,
                          13,
                          p.muted,
                        ).copyWith(fontFamily: 'sans-serif'),
                      ),
                      if (copy.meta.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          copy.meta,
                          textAlign: align,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: _type(
                            context,
                            12,
                            p.muted,
                          ).copyWith(fontFamily: 'sans-serif'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            buttons,
          ],
        ),
      );
    }
    if (!dark) return body;
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _SpotlightPainter(
            _clock,
            w.accent,
            _logo?.image,
            moving: moving,
          ),
        ),
        body,
      ],
    );
  }
}

/// The app logo beside the wordmark; Spotlight's carries a soft glow, Face
/// Down's takes [tint].
class _Header extends StatelessWidget {
  const _Header({
    required this.logo,
    required this.accent,
    required this.ink,
    required this.dark,
    required this.tint,
  });

  final ui.Image? logo;
  final Color accent;
  final Color ink;
  final bool dark;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final h = dark ? 22.0 : 20.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: h * _logoAspect,
          height: h,
          child: CustomPaint(
            painter: _LogoPainter(
              logo,
              glow: dark ? accent : null,
              tint: dark ? null : tint,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          'Detoxo',
          style: _type(
            context,
            dark ? 15 : 16,
            ink,
            weight: dark ? FontWeight.w700 : FontWeight.w800,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

/// The exits, top to bottom: [Home | Open Detoxo], then the ghost labels (the
/// full stage only). Each sits in a 48-tall slot, as the native views do. Open
/// Detoxo is the app's own [LiquidPill]; Home is an outlined circle.
class _Buttons extends StatelessWidget {
  const _Buttons({
    required this.copy,
    required this.palette,
    required this.accent,
    required this.compact,
  });

  final BlockScreenCopy copy;
  final WallPalette palette;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = legibleOn(accent, ground: palette.ground, ink: palette.ink);
    final fill = legibleFill(accent);
    final ghosts = compact
        ? const <BlockScreenButton>[]
        : copy.buttons.where((b) => b.ghost).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final b in copy.buttons)
              if (b.icon)
                SizedBox.square(
                  dimension: 48,
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.12),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Icon(Icons.home_rounded, size: 20, color: label),
                    ),
                  ),
                )
              else if (b.primary) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: LiquidPill(
                    tint: fill,
                    onPressed: () {},
                    child: Text(
                      b.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _type(
                        context,
                        15,
                        onColorFor(fill),
                        weight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
          ],
        ),
        if (ghosts.isNotEmpty) const SizedBox(height: 6),
        for (final b in ghosts)
          SizedBox(
            height: 48,
            width: double.infinity,
            child: Center(
              // A locked way back (its countdown running) is dimmed like the
              // real one.
              child: Opacity(
                opacity: b.locked ? 0.55 : 1,
                child: Text(
                  b.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _type(
                    context,
                    14,
                    label,
                    weight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The quote fades up 10 dp over 1.2 s; its writer follows [delayMs] later.
/// Still: drawn as is.
class _FadeUp extends StatelessWidget {
  const _FadeUp({required this.moving, required this.child, this.delayMs = 0});

  final bool moving;
  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    if (!moving) return child;
    final total = 1200 + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delayMs / total, 1, curve: Curves.ease),
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

// MIRROR: `flipDegrees` / `lissajousX` / `lissajousY` in `overlay/QuoteWall.kt`.
const _flipEase = Cubic(0.6, 0, 0.3, 1);

double _flipDegrees(double t) => switch (t) {
  < 0.30 => 0,
  < 0.42 => 180 * _flipEase.transform((t - 0.30) / 0.12),
  < 0.82 => 180,
  < 0.94 => 180 + 180 * _flipEase.transform((t - 0.82) / 0.12),
  _ => 360,
};

double _lissajousX(double t, double w) => w / 2 + 0.31 * w * math.sin(0.8 * t);

double _lissajousY(double t, double h) =>
    0.47 * h + 0.24 * h * math.sin(0.5 * t);

/// The app logo — a 1024² RGBA square with a transparent margin — decoded at
/// 512 px through the image cache, so the editor's previews share one decode.
const _logoImage = ResizeImage(
  AssetImage('assets/images/Detoxo_logo.png'),
  width: 512,
);

/// Where the logo sits in that square, as fractions (MIRROR: `LOGO_CROP` in
/// `overlay/QuoteWall.kt`, pinned against the asset by its JVM test).
const _logoCrop = Rect.fromLTRB(0.297, 0.132, 0.704, 0.888);
const _logoAspect =
    (0.704 - 0.297) / (0.888 - 0.132); // the crop's, the square being square

/// The cropped logo into [dst], recoloured to [tint] when one is given — the
/// logo is white, so the light wall draws it in the theme primary (MIRROR:
/// `logoPaint` / `litLogo` in `QuoteWall.kt`).
void _drawLogo(Canvas canvas, ui.Image logo, Rect dst, {Color? tint}) {
  final w = logo.width.toDouble();
  final h = logo.height.toDouble();
  final paint = Paint()..filterQuality = FilterQuality.medium;
  if (tint != null) paint.colorFilter = ColorFilter.mode(tint, BlendMode.srcIn);
  canvas.drawImageRect(
    logo,
    Rect.fromLTRB(
      _logoCrop.left * w,
      _logoCrop.top * h,
      _logoCrop.right * w,
      _logoCrop.bottom * h,
    ),
    dst,
    paint,
  );
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter(this.logo, {this.glow, this.tint});

  final ui.Image? logo;

  /// Spotlight's soft accent glow behind the logo; null = none.
  final Color? glow;

  /// Face Down's recolour of the white logo; null = as drawn.
  final Color? tint;

  @override
  void paint(Canvas canvas, Size size) {
    final g = glow;
    if (g != null) {
      final c = size.center(Offset.zero);
      final r = size.height * 1.6;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.radial(c, r, [
            g.withValues(alpha: 0.4),
            g.withValues(alpha: 0),
          ]),
      );
    }
    final l = logo;
    if (l != null) _drawLogo(canvas, l, Offset.zero & size, tint: tint);
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.logo != logo || old.glow != glow || old.tint != tint;
}

/// Face Down's card (MIRROR: `QuoteWallView.drawPhone`), in board dp: it turns
/// face down and back on the board's 8 s loop, over a floor shadow that
/// narrows and fades as it lifts. Its 326 dp block (14 above + the 290 card +
/// 22 below) scales to fit its slot, 1 down to 0.5, then hides (MIRROR:
/// `phoneScale`). Repaints off [clock] alone.
class _PhonePainter extends CustomPainter {
  _PhonePainter(
    this.clock,
    this.logo, {
    required this.tint,
    required this.moving,
  }) : super(repaint: clock);

  final ValueNotifier<Duration> clock;
  final ui.Image? logo;

  /// The back's logo colour: the theme primary (the white logo would vanish).
  final Color tint;
  final bool moving;

  @override
  void paint(Canvas canvas, Size size) {
    final k = math.min(1.0, size.height / 326);
    if (k < 0.5) return;
    final card = Rect.fromLTWH(
      (size.width - 150 * k) / 2,
      (size.height - 326 * k) / 2 + 14 * k,
      150 * k,
      290 * k,
    );
    final t = moving ? clock.value.inMicroseconds / 1e6 : 0.0;
    final deg = _flipDegrees((t % 8) / 8);
    final rad = deg * math.pi / 180;
    final away = (1 - math.cos(rad)) / 2;

    final sc = Offset(card.center.dx, card.bottom + 19 * k);
    final ry = 15 * k;
    canvas
      ..save()
      ..translate(sc.dx, sc.dy)
      ..scale(63 * (1 - 0.15 * away) / 15, 1)
      ..drawCircle(
        Offset.zero,
        ry,
        Paint()
          ..shader = ui.Gradient.radial(Offset.zero, ry, [
            const Color(0xFF12151B).withValues(alpha: 0.35 - 0.13 * away),
            const Color(0x0012151B),
          ]),
      )
      ..restore();

    final c = card.center;
    final turn = Matrix4.identity()
      ..setEntry(3, 2, 1 / (900 * k))
      ..rotateY(rad);
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..transform(turn.storage)
      ..translate(-c.dx, -c.dy);
    if (math.cos(rad) < 0) {
      // The far side reads the right way round.
      canvas
        ..translate(c.dx, 0)
        ..scale(-1, 1)
        ..translate(-c.dx, 0);
      _back(canvas, card, k);
    } else {
      _front(canvas, card, k, t);
    }
    canvas.restore();
  }

  void _front(Canvas canvas, Rect card, double k, double t) {
    final r = Radius.circular(30 * k);
    canvas.drawRRect(
      RRect.fromRectAndRadius(card, r),
      Paint()..color = const Color(0xFF1C1F26),
    );
    // Two soft blobs drift (10, −14) dp and back over 4 s, half a cycle apart.
    void blob(Color color, double x, double y, double radius, double d) {
      final o = card.topLeft + Offset((x + 10 * d) * k, (y - 14 * d) * k);
      canvas.drawCircle(
        o,
        radius * k,
        Paint()
          ..shader = ui.Gradient.radial(o, radius * k, [
            color.withValues(alpha: 0.8),
            color.withValues(alpha: 0),
          ]),
      );
    }

    blob(
      const Color(0xFFFF5C8A),
      55,
      85,
      46,
      (1 - math.cos(2 * math.pi * t / 4)) / 2,
    );
    blob(
      const Color(0xFF5C8AFF),
      105,
      185,
      34,
      (1 - math.cos(2 * math.pi * (t + 2) / 4)) / 2,
    );
    for (final (top, right, alpha) in const [
      (24.0, 14.0, 0.14),
      (66.0, 30.0, 0.10),
      (108.0, 14.0, 0.12),
    ]) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          card.left + 14 * k,
          card.top + top * k,
          card.right - right * k,
          card.top + (top + 34) * k,
          Radius.circular(12 * k),
        ),
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(card.deflate(2 * k), r),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * k
        ..color = const Color(0xFF2A2E37),
    );
  }

  void _back(Canvas canvas, Rect card, double k) {
    final r = Radius.circular(30 * k);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(card, r),
        Paint()..color = const Color(0xFFF7F8FA),
      )
      ..drawRRect(
        RRect.fromLTRBR(
          card.left + 14 * k,
          card.top + 14 * k,
          card.left + 56 * k,
          card.top + 56 * k,
          Radius.circular(12 * k),
        ),
        Paint()..color = const Color(0xFFE3E7EE),
      );
    // The logo on the back, as the board draws it: 77 dp tall.
    final l = logo;
    if (l != null) {
      _drawLogo(
        canvas,
        l,
        Rect.fromCenter(
          center: card.center,
          width: 77 * k * _logoAspect,
          height: 77 * k,
        ),
        tint: tint,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(card.deflate(0.5 * k), r),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, k)
        ..color = const Color(0xFFD5DAE3),
    );
  }

  @override
  bool shouldRepaint(_PhonePainter old) =>
      old.logo != logo || old.tint != tint || old.moving != moving;
}

/// Spotlight's light (MIRROR: `QuoteWallView.drawSpotlight`), in board dp: a
/// glow, the big logo and the dot grid, each lit by one radial gradient around
/// the light, which drifts on the board's Lissajous path. Repaints off [clock]
/// alone.
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(this.clock, this.accent, this.logo, {required this.moving})
    : super(repaint: clock);

  final ValueNotifier<Duration> clock;
  final Color accent;
  final ui.Image? logo;
  final bool moving;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = clock.value.inMicroseconds / 1e6;
    final light = moving
        ? Offset(_lissajousX(t, w), _lissajousY(t, h))
        : Offset(w / 2, 0.45 * h);
    Paint lit(double r, double alpha) => Paint()
      ..shader = ui.Gradient.radial(light, r, [
        accent.withValues(alpha: alpha),
        accent.withValues(alpha: 0),
      ]);

    canvas.drawCircle(light, 220, lit(220, 0.14));
    // The big logo in the accent — the board's 240 / 390 of the width, capped
    // at half the height — kept only where the light reaches (natively a
    // ComposeShader), at most α 0x28 (QuoteWall.kt `LIT_LOGO_ALPHA`): over
    // the glow too, the muted writer and meta keep 4.5:1 in every theme.
    final l = logo;
    if (l != null) {
      var lw = 0.615 * w;
      var lh = lw / _logoAspect;
      if (lh > 0.5 * h) {
        lh = 0.5 * h;
        lw = lh * _logoAspect;
      }
      final dst = Rect.fromLTWH((w - lw) / 2, 0.21 * h, lw, lh);
      canvas.saveLayer(dst, Paint());
      _drawLogo(canvas, l, dst, tint: accent);
      canvas
        ..drawRect(dst, lit(180, 0x28 / 255)..blendMode = BlendMode.dstIn)
        ..restore();
    }
    // Only the grid points the light can reach.
    const pitch = 16.0;
    const r = 160.0;
    const half = pitch / 2;
    final dot = lit(r, 0.55);
    for (
      var j = ((light.dy - r - half) / pitch).ceil();
      j <= ((light.dy + r - half) / pitch).floor();
      j++
    ) {
      final y = j * pitch + half;
      for (
        var i = ((light.dx - r - half) / pitch).ceil();
        i <= ((light.dx + r - half) / pitch).floor();
        i++
      ) {
        final x = i * pitch + half;
        final dx = x - light.dx;
        final dy = y - light.dy;
        if (dx * dx + dy * dy <= r * r) {
          canvas.drawCircle(Offset(x, y), 1.2, dot);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.accent != accent || old.logo != logo || old.moving != moving;
}
