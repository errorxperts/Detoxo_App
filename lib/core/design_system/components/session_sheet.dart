import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:detoxo/core/design_system/components/dx_icons.dart';
import 'package:detoxo/core/design_system/components/overlays.dart';
import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/design_system/tokens/app_motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

/// What a [SessionSheet] sets: a reel count (a − / + stepper) or minutes (a
/// 240° ring slider).
enum SessionKind { reels, time }

/// The Session blocker sheet (canvas `SessionBlocker-{Reels,Time}`): pick a
/// value between `min` and `max`, by stepper or ring slider, or by one of the
/// four quick `picks`, read the `note` line, then Start.
///
/// - Both kinds stand 434 tall at 1.0x text, under the static brand glow.
/// - Start awaits `onStart(value)`. True shows "Session started" with a drawn
///   check and holds the sheet (no back, drag or scrim tap) until it closes
///   1.1 s later; false leaves the sheet as it was.
/// - Reduce Motion drops the chip slide, the squish, the number bump and the
///   check draw.
abstract final class SessionSheet {
  @visibleForTesting
  static const Key chipKey = ValueKey('SessionSheet.chip');

  @visibleForTesting
  static const Key dialKey = ValueKey('SessionSheet.dial');

  static Future<void> show(
    BuildContext context, {
    required SessionKind kind,
    required int min,
    required int max,
    required int initial,
    required List<int> picks,
    required String Function(int) note,
    required String Function(int) startLabel,
    required Future<bool> Function(int) onStart,
  }) {
    assert(min < max && picks.length > 1, 'a range and at least two picks');
    return GlassBottomSheet.show<void>(
      context: context,
      glow: context.tokens.brand.main,
      child: _SessionSheet(
        kind: kind,
        min: min,
        max: max,
        initial: initial,
        picks: picks,
        note: note,
        startLabel: startLabel,
        onStart: onStart,
      ),
    );
  }
}

// Canvas measures with no token of their own.
const double _valueHeight = 160;
const double _numberColumn = 112;
const double _startHeight = 52;
const double _closeCircle = 32;

/// The quick-pick card's padding; the chip's radius is the card's minus it.
const double _pickInset = AppSpacing.xxs;

/// 32 between the stepper circles and the number, kept with 48 dp targets.
const double _stepGap =
    AppSpacing.xxl - (AppSizes.minTapTarget - AppSizes.controlHeight) / 2;

/// Hold-to-repeat: the first repeat after 420 ms, each next one ×.78 sooner,
/// never under 60 ms.
const double _holdFirstMs = 420;
const double _holdRate = .78;
const double _holdFloorMs = 60;

/// How long "Session started" shows before the sheet closes.
const Duration _startedHold = Duration(milliseconds: 1100);

/// The check strokes in over 500 ms after a 50 ms delay.
const Duration _checkDraw = Duration(milliseconds: 550);
const Curve _checkCurve = Interval(50 / 550, 1, curve: Cubic(.22, 1, .36, 1));

// Glyphs on the canvas's 24-unit grid.
const List<List<Offset>> _minus = [
  [Offset(6, 12), Offset(18, 12)],
];
const List<List<Offset>> _plus = [
  ..._minus,
  [Offset(12, 6), Offset(12, 18)],
];
const List<List<Offset>> _cross = [
  [Offset(6.5, 6.5), Offset(17.5, 17.5)],
  [Offset(17.5, 6.5), Offset(6.5, 17.5)],
];
const List<List<Offset>> _check = [
  [Offset(5, 12.5), Offset(9.5, 17), Offset(19, 7.5)],
];

class _SessionSheet extends StatefulWidget {
  const _SessionSheet({
    required this.kind,
    required this.min,
    required this.max,
    required this.initial,
    required this.picks,
    required this.note,
    required this.startLabel,
    required this.onStart,
  });

  final SessionKind kind;
  final int min;
  final int max;
  final int initial;
  final List<int> picks;
  final String Function(int) note;
  final String Function(int) startLabel;
  final Future<bool> Function(int) onStart;

  @override
  State<_SessionSheet> createState() => _SessionSheetState();
}

class _SessionSheetState extends State<_SessionSheet> {
  late int _value = widget.initial.clamp(widget.min, widget.max);

  /// Triggers for the number bump and the quick-pick squish.
  int _bumps = 0;
  int _squishes = 0;

  bool _dialFocused = false;
  bool _busy = false;
  bool _started = false;

  Timer? _hold;
  Timer? _close;

  /// A pointer already stepped on down; the tap that follows it must not.
  bool _viaPointer = false;

  /// The slider's last own position, so a dragged handle follows the finger
  /// between whole values; any other change nulls it, snapping to [_value].
  double? _handle;

  bool get _reels => widget.kind == SessionKind.reels;

  String _unit(int n) => switch (widget.kind) {
    SessionKind.reels => n == 1 ? 'reel' : 'reels',
    SessionKind.time => n == 1 ? 'minute' : 'minutes',
  };

  @override
  void dispose() {
    _hold?.cancel();
    _close?.cancel();
    super.dispose();
  }

  void _set(int v, {bool bump = true, bool squish = false}) {
    _handle = null;
    final next = v.clamp(widget.min, widget.max);
    if (next == _value) return;
    AppHaptics.selection();
    setState(() {
      _value = next;
      if (bump) _bumps++;
      if (squish) _squishes++;
    });
  }

  /// Steps by [d]; false at a bound, which also ends a hold.
  bool _step(int d) {
    final before = _value;
    _set(before + d);
    return _value != before;
  }

  void _holdStart(int d) {
    _viaPointer = true;
    _holdStop();
    if (!_step(d)) return;
    void next(double ms) {
      _hold = Timer(Duration(milliseconds: ms.round()), () {
        if (_step(d)) next(math.max(_holdFloorMs, ms * _holdRate));
      });
    }

    next(_holdFirstMs);
  }

  void _holdStop() {
    _hold?.cancel();
    _hold = null;
  }

  void _release() {
    _holdStop();
    // After the tap this pointer-up produces, so keys and TalkBack still step.
    scheduleMicrotask(() => _viaPointer = false);
  }

  Future<void> _start() async {
    _holdStop();
    setState(() => _busy = true);
    var ok = false;
    try {
      ok = await widget.onStart(_value);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _started = ok;
        });
      }
    }
    if (!ok || !mounted) return;
    AppHaptics.success();
    _close = Timer(_startedHold, () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PopScope(
      canPop: !_started,
      // A 434 sheet fits any phone; this only guards a short landscape screen.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The canvas's 44 row, 2 below the grabber with 14 under it, grown
            // to the 48 dp close target: same centre, same value area top.
            _header(t),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: _valueHeight,
              child: _reels ? _stepper(t) : _dial(t),
            ),
            const SizedBox(height: AppSpacing.gap),
            _quickPicks(t),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.note(_value),
              textAlign: TextAlign.center,
              style: AppTypography.subhead.copyWith(color: t.ink2),
            ),
            const SizedBox(height: AppSpacing.gap),
            _startButton(t),
          ],
        ),
      ),
    );
  }

  Widget _header(AppTokens t) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
    child: Row(
      children: [
        Icon3d(
          _reels
              ? Assets.images.icons.iconReelCount
              : Assets.images.icons.iconPause,
          size: 40,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Session blocker',
                  style: AppTypography.headline.copyWith(color: t.ink),
                ),
              ),
              Text(
                _reels ? 'By reel count' : 'By time',
                style: AppTypography.subhead.copyWith(color: t.ink2),
              ),
            ],
          ),
        ),
        AppPressable(
          onTap: () => Navigator.of(context).pop(),
          pressedScale: .95,
          radius: AppRadius.brPill,
          semanticLabel: 'Close',
          minTapTarget: AppSizes.minTapTargetSquare,
          child: _Circle(
            size: _closeCircle,
            color: t.control,
            child: CustomPaint(
              size: const Size.square(12),
              painter: _GlyphPainter(_cross, t.ink2),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _stepper(AppTokens t) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _stepButton(t, -1, 'One fewer reel', _minus),
      const SizedBox(width: _stepGap),
      SizedBox(
        width: _numberColumn,
        child: Semantics(
          container: true,
          liveRegion: true,
          label: '$_value ${_unit(_value)}',
          child: ExcludeSemantics(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Bump(
                    trigger: _bumps,
                    child: Text(
                      '$_value',
                      style: AppTypography.number.copyWith(color: t.ink),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    _unit(_value).toUpperCase(),
                    style: AppTypography.eyebrow.copyWith(color: t.ink2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: _stepGap),
      _stepButton(t, 1, 'One more reel', _plus),
    ],
  );

  /// A − / + circle: a pointer steps on down and repeats while held; keys
  /// and TalkBack step once through the tap.
  Widget _stepButton(
    AppTokens t,
    int d,
    String label,
    List<List<Offset>> glyph,
  ) {
    final enabled = d < 0 ? _value > widget.min : _value < widget.max;
    return Listener(
      onPointerDown: (_) => _holdStart(d),
      onPointerMove: (e) {
        // Sliding off the button ends a hold, as the canvas's pointerleave.
        if (!(Offset.zero & AppSizes.minTapTargetSquare).contains(
          e.localPosition,
        )) {
          _holdStop();
        }
      },
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: AppPressable(
        onTap: () {
          if (!_viaPointer) _step(d);
        },
        enabled: enabled,
        haptic: false,
        pressedScale: .9,
        radius: AppRadius.brPill,
        semanticLabel: label,
        minTapTarget: AppSizes.minTapTargetSquare,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : .35,
          duration: context.motion(AppDurations.fast),
          curve: AppCurves.glide,
          child: _Circle(
            size: AppSizes.controlHeight,
            color: t.control,
            child: CustomPaint(
              size: const Size.square(18),
              painter: _GlyphPainter(glyph, t.accentText(t.brand), stroke: 2.8),
            ),
          ),
        ),
      ),
    );
  }

  /// The time ring slider: a 240° `control` track open at the bottom, the
  /// brand arc up to the value and a white handle, around the number and its
  /// unit. The package has no semantics or keys of its own, so the slider
  /// node and the key map here speak for it.
  Widget _dial(AppTokens t) {
    final p = t.brand;
    final dark = t.brightness == Brightness.dark;
    final range = widget.max - widget.min;
    String say(int v) => '$v ${_unit(v)}';
    return Center(
      child: Semantics(
        slider: true,
        label: 'Session length',
        value: say(_value),
        increasedValue: say(math.min(_value + 1, widget.max)),
        decreasedValue: say(math.max(_value - 1, widget.min)),
        onIncrease: () => _set(_value + 1, bump: false),
        onDecrease: () => _set(_value - 1, bump: false),
        child: FocusableActionDetector(
          onShowFocusHighlight: (v) => setState(() => _dialFocused = v),
          shortcuts: {
            const SingleActivator(LogicalKeyboardKey.arrowLeft): const _Nudge(
              -1,
            ),
            const SingleActivator(LogicalKeyboardKey.arrowDown): const _Nudge(
              -1,
            ),
            const SingleActivator(LogicalKeyboardKey.arrowRight): const _Nudge(
              1,
            ),
            const SingleActivator(LogicalKeyboardKey.arrowUp): const _Nudge(1),
            const SingleActivator(LogicalKeyboardKey.pageUp): const _Nudge(5),
            const SingleActivator(LogicalKeyboardKey.pageDown): const _Nudge(
              -5,
            ),
            const SingleActivator(LogicalKeyboardKey.home): _Nudge(-range),
            const SingleActivator(LogicalKeyboardKey.end): _Nudge(range),
          },
          actions: {
            _Nudge: CallbackAction<_Nudge>(
              onInvoke: (i) {
                _set(_value + i.by, bump: false);
                return null;
              },
            ),
          },
          child: FocusRing(
            visible: _dialFocused,
            radius: const BorderRadius.all(Radius.circular(24)),
            child: ExcludeSemantics(
              child: SleekCircularSlider(
                key: SessionSheet.dialKey,
                min: widget.min.toDouble(),
                max: widget.max.toDouble(),
                initialValue: _handle ?? _value.toDouble(),
                appearance: CircularSliderAppearance(
                  size: _valueHeight,
                  // Tracks the finger without easing.
                  animationEnabled: false,
                  customWidths: CustomSliderWidths(
                    trackWidth: 8,
                    progressBarWidth: 12,
                    handlerSize: 8,
                  ),
                  customColors: CustomSliderColors(
                    trackColor: t.control,
                    // The dial's stops, reversed: the package's sweep meets
                    // them end first, so the arc still starts on the first.
                    progressBarColors:
                        (dark
                                ? [p.light, p.main, p.deep]
                                : [
                                    p.main,
                                    Color.lerp(
                                      p.main,
                                      p.deep,
                                      AppTokens.arcMidMix,
                                    )!,
                                    p.deep,
                                  ])
                            .reversed
                            .toList(),
                    dotColor: Colors.white,
                    hideShadow: true,
                  ),
                ),
                // Also fires when initialValue moves (a pick, a key); _set
                // ignores the same whole value.
                onChange: (v) {
                  _set(v.round(), bump: false);
                  _handle = v;
                },
                innerWidget: (_) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Bump(
                          trigger: _bumps,
                          child: Text(
                            '$_value',
                            style: AppTypography.numberLg.copyWith(
                              color: t.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _unit(_value).toUpperCase(),
                          style: AppTypography.eyebrowLg.copyWith(
                            color: t.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Four picks on a `control` card; the `controlOn` chip slides under the
  /// current one and fades out for a custom value.
  Widget _quickPicks(AppTokens t) {
    final picks = widget.picks;
    final i = picks.indexOf(_value);
    final on = t.brightness == Brightness.dark ? t.ink : t.accentText(t.brand);
    final fade = context.motion(AppDurations.normal);
    final chipRadius = BorderRadius.circular(AppRadius.cardSm - _pickInset);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: ui.SemanticsRole.radioGroup,
      label: 'Quick pick',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.control,
          borderRadius: BorderRadius.circular(AppRadius.cardSm),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(_pickInset),
                child: AnimatedAlign(
                  // A custom value leaves the hidden chip on the first pick.
                  alignment: Alignment(
                    -1 + 2 * math.max(i, 0) / (picks.length - 1),
                    0,
                  ),
                  duration: context.motion(AppDurations.chip),
                  curve: AppCurves.chip,
                  child: FractionallySizedBox(
                    widthFactor: 1 / picks.length,
                    heightFactor: 1,
                    child: AnimatedOpacity(
                      key: SessionSheet.chipKey,
                      opacity: i < 0 ? 0 : 1,
                      duration: fade,
                      curve: AppCurves.glide,
                      child: Squish(
                        trigger: _squishes,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: t.controlOn,
                            borderRadius: chipRadius,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Full-height options: the 52 px card is each one's target.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _pickInset),
              child: Row(
                children: [
                  for (final n in picks)
                    Expanded(
                      child: AppPressable(
                        onTap: () => _set(n, squish: true),
                        haptic: false,
                        pressedScale: .94,
                        radius: chipRadius,
                        semanticLabel: '$n ${_unit(n)}',
                        selected: n == _value,
                        inMutuallyExclusiveGroup: true,
                        child: SizedBox(
                          height: AppSizes.controlHeight + 2 * _pickInset,
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: fade,
                              curve: AppCurves.glide,
                              style: AppTypography.labelStrong.copyWith(
                                color: n == _value ? on : t.ink2,
                              ),
                              child: ExcludeSemantics(
                                child: Text('$n', maxLines: 1),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _startButton(AppTokens t) {
    final done = _started;
    final ink = done ? t.startedInk : t.startInk;
    final label = done ? 'Session started' : widget.startLabel(_value);
    return Semantics(
      // Announces the start; the label tracking the value stays quiet.
      liveRegion: done,
      child: AppPressable(
        onTap: _start,
        enabled: !_busy && !done,
        pressedScale: .95,
        radius: AppRadius.brPill,
        semanticLabel: label,
        child: ExcludeSemantics(
          child: CustomPaint(
            painter: DxSurfacePainter(
              radius: AppRadius.brPill,
              gradient: done
                  ? [t.startedFrom, t.startedTo]
                  : [t.startFrom, t.startTo],
              shadows: done ? t.startedShadow : t.startShadow,
            ),
            child: SizedBox(
              height: _startHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (done) ...[
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: context.motion(_checkDraw),
                        curve: _checkCurve,
                        builder: (_, v, _) => CustomPaint(
                          size: const Size.square(20),
                          painter: _GlyphPainter(_check, ink, progress: v),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.button.copyWith(color: ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A slider key's step: arrows ±1, Page Up / Down ±5, Home / End the range.
class _Nudge extends Intent {
  const _Nudge(this.by);

  final int by;
}

/// A flat circle of [color] holding [child].
class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.color, required this.child});

  final double size;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(child: child),
    ),
  );
}

/// The canvas's number bump: on [trigger], scale .92 → 1.05 (at 60 %) → 1
/// over 380 ms, each leg on the press curve. Still under Reduce Motion.
class _Bump extends StatefulWidget {
  const _Bump({required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<_Bump> createState() => _BumpState();
}

class _BumpState extends State<_Bump> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: 1,
  );

  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(
      tween: Tween(
        begin: .92,
        end: 1.05,
      ).chain(CurveTween(curve: AppCurves.press)),
      weight: 60,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.05,
        end: 1.0,
      ).chain(CurveTween(curve: AppCurves.press)),
      weight: 40,
    ),
  ]).animate(_c);

  @override
  void didUpdateWidget(_Bump old) {
    super.didUpdateWidget(old);
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (old.trigger != widget.trigger && !still) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}

/// Round-capped polylines on the canvas's 24-unit glyph grid, scaled to the
/// paint size; [progress] < 1 draws only the start of the (single) stroke.
class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(
    this.lines,
    this.color, {
    this.stroke = 3,
    this.progress = 1,
  });

  final List<List<Offset>> lines;
  final Color color;
  final double stroke;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path();
    for (final line in lines) {
      path.addPolygon(line, false);
    }
    if (progress < 1) {
      final m = path.computeMetrics().first;
      path = m.extractPath(0, m.length * progress);
    }
    canvas
      ..scale(size.width / 24)
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.lines != lines ||
      old.color != color ||
      old.stroke != stroke ||
      old.progress != progress;
}
