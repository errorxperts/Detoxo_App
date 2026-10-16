import 'dart:async';
import 'dart:math' as math;

import 'package:detoxo/features/content_counter/content_counter_bubble/domain/bubble_model.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/domain/entities/bubble_style.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_face.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_frame.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_look.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_painter.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_tokens.g.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/brand_tint.dart';
import 'package:detoxo/features/content_counter/content_counter_core/presentation/counter_brand.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// The in-app floating-bubble preview: [style] at [count] reels and [watch]
/// time, drawn by the same [BubblePainter] pass as the native Kotlin
/// `BubbleView` (`overlay/bubble/`) and animated the way it is (BR-02/03/06/07):
/// - a new reel in the same tier pops the count;
/// - a tier up cross-fades the colours, fires one pulse ring and shows the
///   time pill for 3 s; a tier down (midnight) only cross-fades. The pill
///   and the pulse are the live bubble's signals: only an [interactive]
///   preview shows them, so a card or thumbnail never spills over;
/// - [BubblePreviewState.toggleTimer] (a tap when [interactive]) widens the
///   body inward from its docked edge into the timer, and back;
/// - [BubblePreviewState.replayAppear] replays the appear spring and pill;
/// - Liquid, Drop and the open Hourglass loop on one ticker.
///
/// The canvas is [area] wide and [height] (default [area]) tall:
/// - not [interactive] (the hub card, thumbnails; they never open): the
///   bubble is centred, shrunk to fit as `min(style.size, side − 24)` dp
///   (side: the shorter of the two);
///   [dockedRight] only picks the face's docked side;
/// - [interactive] (the style screen's stage): the real size, centred
///   vertically, 12 dp from the docked side, clipped to the area. To show
///   the widest timer unclipped it needs
///   `area ≥ 12 + 176 · (style.size / 68) + 12`.
///
/// It stays still, with no ticker or controller, under the OS's "remove
/// animations" or [animate] false; states then swap instantly, and the pill
/// still shows for 3 s (BR-07: it is information, not motion). [TickerMode]
/// pauses it off screen. A screen reader hears the BR-11 label (without the
/// tap sentence unless [interactive]), unless [excludeFromSemantics].
class BubblePreview extends StatefulWidget {
  const BubblePreview({
    required this.style,
    required this.count,
    this.watch = Duration.zero,
    this.area = 132,
    this.height,
    this.animate = true,
    this.interactive = false,
    this.dockedRight = true,
    this.excludeFromSemantics = false,
    super.key,
  });

  final BubbleStyle style;

  /// Today's reels.
  final int count;

  /// Today's watch time (the pill and the timer).
  final Duration watch;

  /// The canvas width (and height, unless [height] is set).
  final double area;

  /// The canvas height; null is [area]. The bubble sits centred, and the
  /// pill rises 30 · (style.size / 68) dp above it, so the stage needs
  /// `height ≥ style.size · (1 + 60 / 68)`.
  final double? height;

  /// False draws only the settled frame and never starts a ticker.
  final bool animate;

  /// True lets a tap toggle the timer.
  final bool interactive;

  /// Which side the bubble docks to; the timer grows away from it.
  final bool dockedRight;

  /// True inside a card that already names it, where its demo numbers would
  /// otherwise read as fact.
  final bool excludeFromSemantics;

  @override
  State<BubblePreview> createState() => BubblePreviewState();
}

/// Reach it with a `GlobalKey<BubblePreviewState>` to drive the preview.
class BubblePreviewState extends State<BubblePreview>
    with TickerProviderStateMixin {
  // The motion, built on the first dependencies that may animate; never
  // while still.
  late final AnimationController _blend;
  late final AnimationController _pop;
  late final AnimationController _pulse;
  late final AnimationController _expand;
  late final AnimationController _pill;
  late final AnimationController _appear;
  late final CurvedAnimation _expandT;
  late final CurvedAnimation _pillT;
  Listenable? _motion;

  /// The style loop's phase, 0..1, at most [BubbleTokens.loopFps] steps a
  /// second.
  final _loopT = ValueNotifier(0.0);
  Ticker? _loop;

  /// Folds the pill away [BubbleTokens.msPill] after it shows; [_pillUp]
  /// is whether it shows (drawn as is while still).
  Timer? _pillHide;
  var _pillUp = false;

  /// The look and tier the cross-fade comes from (read only mid-fade).
  var _prevTier = 0;
  var _prevLook = BubbleLook.of(0);

  var _open = false;
  var _reduceMotion = false;

  /// The app theme's primary in the device's brightness: native picks the
  /// bubble's hue the same way.
  var _brand = BrandTint.fallback;

  /// Whether the timer is open (or opening).
  bool get isOpen => _open;

  /// The frame as it paints right now.
  @visibleForTesting
  BubbleFrame get frame => _frameAt!();
  BubbleFrame Function()? _frameAt;

  bool get _still => !widget.animate || _reduceMotion;

  /// Replays the appear spring (scale .6 → 1, fade in) and, when
  /// [BubblePreview.interactive], the time pill.
  void replayAppear() {
    if (!_still) _appear.forward(from: 0);
    _showPill();
  }

  /// Opens or folds the timer; the pill hides while it is open.
  void toggleTimer() {
    setState(() => _open = !_open);
    if (_open) {
      _pillHide?.cancel();
      _pillUp = false;
    }
    _syncMotion();
    if (_still) return;
    if (_open) {
      _expand.forward();
      _pill.value = 0;
    } else {
      _expand.reverse();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _brand = counterBrand(context, MediaQuery.platformBrightnessOf(context));
    _syncMotion();
  }

  @override
  void didUpdateWidget(BubblePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
    final from = BubbleModel.tier(oldWidget.count);
    final change = BubbleModel.transition(from, BubbleModel.tier(widget.count));
    if (change == TierChange.up) _showPill();
    if (_still) return;
    switch (change) {
      case TierChange.up:
        _crossfade(from);
        if (widget.interactive) _pulse.forward(from: 0);
      case TierChange.down:
        _crossfade(from);
      case TierChange.none:
        if (oldWidget.count != widget.count) _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pillHide?.cancel();
    _loop?.dispose();
    if (_motion != null) {
      _expandT.dispose();
      _pillT.dispose();
      for (final c in [_blend, _pop, _pulse, _expand, _pill, _appear]) {
        c.dispose();
      }
    }
    _loopT.dispose();
    super.dispose();
  }

  /// Builds the motion once it may run; while still, parks it at rest (the
  /// pill's timer keeps running: it is state, not motion).
  void _syncMotion() {
    if (!_still) {
      _motion ??= _buildMotion();
    } else if (_motion != null) {
      _blend.value = 1;
      _pop.value = 0;
      _pulse.value = 0;
      _pill.value = 0;
      _appear.value = 1;
      _expand.value = _open ? 1 : 0;
    }
    _syncLoop();
  }

  Listenable _buildMotion() {
    AnimationController c(int ms, {double value = 0, int? reverseMs}) =>
        AnimationController(
          vsync: this,
          value: value,
          duration: Duration(milliseconds: ms),
          reverseDuration: reverseMs == null
              ? null
              : Duration(milliseconds: reverseMs),
        );
    _blend = c(BubbleTokens.msCrossfade, value: 1);
    _pop = c(BubbleTokens.msPop);
    _pulse = c(BubbleTokens.msPulse);
    _expand = c(BubbleTokens.msTap, value: _open ? 1 : 0);
    _pill = c(BubbleTokens.msPillIn, reverseMs: BubbleTokens.msPillOut);
    _appear = c(BubbleTokens.msAppear, value: 1);
    // The fold plays the spring forward from the open end, as the board's
    // CSS transition does (it dips below the square before it settles).
    _expandT = CurvedAnimation(
      parent: _expand,
      curve: _spring,
      reverseCurve: _spring.flipped,
    );
    _pillT = CurvedAnimation(
      parent: _pill,
      curve: _spring,
      reverseCurve: Curves.linear,
    );
    return Listenable.merge([
      _blend,
      _pop,
      _pulse,
      _expand,
      _pill,
      _appear,
      _loopT,
    ]);
  }

  /// The loop ticker runs only while the face has something to move.
  void _syncLoop() {
    final face = widget.style.variant.face;
    final run = !_still && face.loops(open: _open) && face.loopPeriodMs > 0;
    if (run == (_loop != null)) return;
    if (run) {
      _loop = createTicker((elapsed) {
        const step = 1000 ~/ BubbleTokens.loopFps;
        final period = widget.style.variant.face.loopPeriodMs;
        _loopT.value = elapsed.inMilliseconds ~/ step * step % period / period;
      })..start();
    } else {
      _loop!.dispose();
      _loop = null;
    }
  }

  /// Starts the cross-fade from whatever shows right now.
  void _crossfade(int from) {
    _prevLook = _lookOf(from);
    _prevTier = from;
    _blend.forward(from: 0);
  }

  BubbleLook _lookOf(int tier) {
    final t = _motion == null ? 1.0 : _blend.value;
    final look = BubbleLook.of(tier, brand: _brand);
    return t < 1 ? BubbleLook.lerp(_prevLook, look, t) : look;
  }

  void _showPill() {
    if (_open || !widget.interactive) return;
    _pillHide?.cancel();
    _pillHide = Timer(const Duration(milliseconds: BubbleTokens.msPill), () {
      setState(() => _pillUp = false);
      if (!_still) _pill.reverse();
    });
    setState(() => _pillUp = true);
    if (!_still) _pill.forward();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final face = style.variant.face;
    final count = widget.count;
    final seconds = widget.watch.inSeconds;
    final tier = BubbleModel.tier(count);
    final pct = BubbleModel.pct(count);
    final countText = BubbleModel.countText(count);
    final clock = BubbleModel.clock(seconds);
    final shortTime = BubbleModel.shortTime(seconds);
    final area = widget.area;
    final height = widget.height ?? area;
    final fit = !widget.interactive;
    final size = fit
        ? math.min(style.size, math.min(area, height) - 24)
        : style.size;
    final s = size / BubbleTokens.size;
    final timerW = BubbleModel.timerWidth(seconds, style.variant) * s;
    final right = widget.dockedRight;
    // The collapsed square's gap to the docked side.
    final edge = fit ? (area - size) / 2 : face.edge;
    final top = (height - size) / 2;
    final motion = _still ? null : _motion;

    // Built per animation frame at paint time; a frame never rebuilds a widget.
    BubbleFrame frameAt() {
      final on = motion != null;
      final blend = on ? _blend.value : 1.0;
      final expand = on ? _expandT.value : (_open ? 1.0 : 0.0);
      // The body widens inward from the docked edge.
      final w = size + (timerW - size) * expand;
      return BubbleFrame(
        body: Rect.fromLTWH(right ? area - edge - w : edge, top, w, size),
        s: s,
        look: _lookOf(tier),
        tier: tier,
        prevTier: blend < 1 ? _prevTier : tier,
        blend: blend,
        count: count,
        pct: pct,
        countText: countText,
        clock: clock,
        shortTime: shortTime,
        expand: expand,
        pop: on ? _pop.value : 0,
        pulse: on && _pulse.isAnimating ? _pulse.value : 0,
        pill: on ? _pillT.value : (_pillUp ? 1 : 0),
        loopT: _loopT.value,
        open: _open,
        dockedRight: right,
      );
    }

    _frameAt = frameAt;
    final Widget bubble = CustomPaint(
      painter: _LivePainter(
        frameAt,
        face: face,
        opacity: style.opacity,
        appear: motion == null ? null : _appear,
        // The appear spring's pivot: the collapsed square's centre.
        pivot: Offset(
          right ? area - edge - size / 2 : edge + size / 2,
          height / 2,
        ),
        repaint: motion,
      ),
    );
    final Widget preview = GestureDetector(
      onTap: widget.interactive ? toggleTimer : null,
      child: RepaintBoundary(
        child: SizedBox(
          width: area,
          height: height,
          // The stage's open timer must never paint outside the area.
          child: fit ? bubble : ClipRect(child: bubble),
        ),
      ),
    );
    if (widget.excludeFromSemantics) return ExcludeSemantics(child: preview);
    return Semantics(
      label: _open
          ? BubbleModel.openLabel(seconds)
          : BubbleModel.collapsedLabel(
              count,
              seconds,
              style.variant,
              tapHint: widget.interactive,
            ),
      button: widget.interactive,
      onTap: widget.interactive ? toggleTimer : null,
      excludeSemantics: true,
      child: preview,
    );
  }
}

/// Paints [frameAt] as it reads at paint time, under the appear spring
/// ([appear] null: settled). The `repaint` motion re-runs it each animation
/// frame, so only this layer repaints; a rebuild means new inputs.
final class _LivePainter extends CustomPainter {
  _LivePainter(
    this.frameAt, {
    required this.face,
    required this.opacity,
    required this.appear,
    required this.pivot,
    super.repaint,
  });

  final BubbleFrame Function() frameAt;
  final BubbleFace face;
  final double opacity;
  final Animation<double>? appear;
  final Offset pivot;

  @override
  void paint(Canvas canvas, Size size) {
    final bubble = BubblePainter(
      frame: frameAt(),
      face: face,
      opacity: opacity,
    );
    final t = appear?.value ?? 1;
    if (t >= 1) return bubble.paint(canvas, size);
    // The appear spring: scale .6 → 1 and fade in, about [pivot].
    final a = _spring.transform(t);
    canvas
      ..save()
      ..translate(pivot.dx, pivot.dy)
      ..scale(0.6 + 0.4 * a)
      ..translate(-pivot.dx, -pivot.dy)
      ..saveLayer(
        null,
        Paint()..color = Color.fromRGBO(0, 0, 0, a.clamp(0, 1)),
      );
    bubble.paint(canvas, size);
    canvas
      ..restore()
      ..restore();
  }

  @override
  bool shouldRepaint(_LivePainter old) => true;
}

/// The board's overshoot spring (`cubic-bezier(.34, 1.36, .64, 1)`) for the
/// timer, the appear and the pill's entry.
const _spring = Cubic(0.34, 1.36, 0.64, 1);
