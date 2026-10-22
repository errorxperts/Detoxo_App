import 'dart:math' as math;

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/core/utils/duration_format.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

/// An interactive radial gauge for picking a daily short-form-video limit —
/// drag (or tap) anywhere on the 270° arc to set the value, which animates in
/// the centre. Drawn in the dashboard ring's materials (`ProgressRing`: groove,
/// track, three-stop brand arc with its blurred copy, white knob and halo,
/// raised disc) so the number the user sets here reads as "the ring you'll
/// fill each day". Every measure is the spec's 300 px ring scaled to [size].
///
/// Controlled: it renders [value] and reports drags via [onChanged]; the parent
/// owns the state. Accessible via a Semantics slider (increase/decrease step).
class ScreenTimeDial extends StatefulWidget {
  const ScreenTimeDial({
    required this.value,
    required this.onChanged,
    this.min = const Duration(minutes: 15),
    this.max = const Duration(hours: 5),
    this.step = const Duration(minutes: 15),
    this.size = 260,
    super.key,
  });

  final Duration value;
  final ValueChanged<Duration> onChanged;
  final Duration min;
  final Duration max;
  final Duration step;
  final double size;

  @override
  State<ScreenTimeDial> createState() => _ScreenTimeDialState();
}

class _ScreenTimeDialState extends State<ScreenTimeDial> {
  // 270° gauge with a gap at the bottom (canvas convention: 0 rad = 3 o'clock,
  // angle increases clockwise because y grows downward).
  static const double _startAngle = math.pi * 3 / 4; // down-left
  static const double _sweepAngle = math.pi * 3 / 2; // 270°

  bool _interacted = false;

  int get _minM => widget.min.inMinutes;
  int get _maxM => widget.max.inMinutes;

  double get _fraction => _fractionOf(widget.value).clamp(0.0, 1.0);

  /// Maps a touch point to a 0..1 position along the arc and commits it.
  void _handle(Offset local) {
    final c = widget.size / 2;
    final v = Offset(local.dx - c, local.dy - c);
    if (v.distance < widget.size * 0.22) return; // ignore the dead centre
    var a = (math.atan2(v.dy, v.dx) - _startAngle) % (2 * math.pi);
    if (a < 0) a += 2 * math.pi;
    final double fraction;
    if (a <= _sweepAngle) {
      fraction = a / _sweepAngle;
    } else {
      // In the bottom gap — snap to whichever end is nearer.
      fraction = (a - _sweepAngle) < (2 * math.pi - a) ? 1.0 : 0.0;
    }
    _commit(fraction);
  }

  void _commit(double fraction) {
    final stepM = widget.step.inMinutes;
    final raw = _minM + fraction.clamp(0.0, 1.0) * (_maxM - _minM);
    final snapped = ((raw / stepM).round() * stepM).clamp(_minM, _maxM);
    final next = Duration(minutes: snapped);
    if (next != widget.value) {
      AppHaptics.selection();
      widget.onChanged(next);
    }
  }

  void _nudge(int steps) => _commit(_fractionOf(_stepped(steps)));

  /// The value [steps] steps away, clamped to the range.
  Duration _stepped(int steps) => Duration(
    minutes: (widget.value.inMinutes + steps * widget.step.inMinutes).clamp(
      _minM,
      _maxM,
    ),
  );

  double _fractionOf(Duration d) => (d.inMinutes - _minM) / (_maxM - _minM);

  static List<DxShadow> _scale(List<DxShadow> shadows, double k) => [
    for (final s in shadows)
      DxShadow(
        color: s.color,
        offset: s.offset * k,
        blur: s.blur * k,
        spread: s.spread * k,
        inset: s.inset,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = t.brand;
    final dark = t.brightness == Brightness.dark;
    final size = widget.size;
    final k = size / 300;
    final disc = 224 * k;
    return Semantics(
      slider: true,
      label: 'Daily limit',
      value: formatHm(widget.value),
      // Both or neither: a slider announcing its value must announce the
      // step either way too (the framework asserts on it).
      increasedValue: formatHm(_stepped(1)),
      decreasedValue: formatHm(_stepped(-1)),
      onIncrease: () => _nudge(1),
      onDecrease: () => _nudge(-1),
      child: GestureDetector(
        onTapDown: (d) {
          setState(() => _interacted = true);
          _handle(d.localPosition);
        },
        onPanStart: (d) {
          setState(() => _interacted = true);
          _handle(d.localPosition);
        },
        onPanUpdate: (d) => _handle(d.localPosition),
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: DxSurfacePainter(
                  radius: BorderRadius.circular(size / 2),
                  gradient: [t.ringGrooveFrom, t.ringGrooveTo],
                  angle: 145,
                  shadows: _scale(t.shadowGroove, k),
                ),
              ),
              // The arc glides to the snapped position on its own layer; the
              // centre text updates immediately.
              RepaintBoundary(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: _fraction),
                  duration: context.motion(AppDurations.fast),
                  curve: AppCurves.standard,
                  builder: (context, f, _) => CustomPaint(
                    size: Size.square(size),
                    painter: _DialPainter(
                      fraction: f,
                      k: k,
                      track: t.ringTrack,
                      arc: dark
                          ? [p.light, p.main, p.deep]
                          : [
                              p.main,
                              Color.lerp(p.main, p.deep, AppTokens.arcMidMix)!,
                              p.deep,
                            ],
                      glow: t.kArcGlow,
                      halo: (dark ? p.light : p.main).withValues(
                        alpha: t.kHalo,
                      ),
                      knobShadow: t.knobShadow,
                    ),
                  ),
                ),
              ),
              SizedBox.square(
                dimension: disc,
                child: CustomPaint(
                  painter: DxSurfacePainter(
                    radius: BorderRadius.circular(disc / 2),
                    gradient: [t.ringDiscFrom, t.ringDiscTo],
                    angle: 145,
                    shadows: _scale(t.shadowDisc, k),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.main.withValues(alpha: AppTokens.discWash),
                    ),
                    child: Center(
                      // The disc less its spec 10 px margin; scales down
                      // rather than overflowing at large text sizes.
                      child: SizedBox.square(
                        dimension: (224 - 20) * k,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _center(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _center(BuildContext context) {
    final t = context.tokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('PER DAY', style: AppTypography.eyebrow.copyWith(color: t.ink2)),
        const SizedBox(height: 6),
        Text(
          formatHm(widget.value),
          style: AppTypography.number.copyWith(color: t.ink),
        ),
        const SizedBox(height: AppSpacing.xs),
        AnimatedOpacity(
          duration: context.motion(AppDurations.normal),
          opacity: _interacted ? 0 : 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_outlined, size: 14, color: t.ink2),
              const SizedBox(width: 4),
              Text(
                'Drag to set',
                style: AppTypography.caption.copyWith(color: t.ink2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The 270° track, the arc with its blurred copy, and the knob. The ring
/// measures of `ProgressRing` (radius 131, stroke 24, halo 17, knob 9), on the
/// gauge's span instead of the full circle.
class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.fraction,
    required this.k,
    required this.track,
    required this.arc,
    required this.glow,
    required this.halo,
    required this.knobShadow,
  });

  final double fraction;
  final double k;
  final Color track;
  final List<Color> arc;
  final double glow;
  final Color halo;
  final Color knobShadow;

  static const double _start = math.pi * 3 / 4;
  static const double _sweep = math.pi * 3 / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = 131 * k;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24 * k
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      _start,
      _sweep,
      false,
      Paint.from(stroke)..color = track,
    );

    final sweep = _sweep * fraction.clamp(0.0, 1.0);
    if (sweep > 0) {
      // Left to right: the gauge is symmetric about the vertical, so the arc
      // runs main → deep from its start at 7:30 to its end at 4:30.
      Shader shader(List<Color> colors) =>
          LinearGradient(colors: colors).createShader(rect);
      canvas
        ..drawArc(
          rect,
          _start,
          sweep,
          false,
          Paint.from(stroke)
            ..shader = shader([
              for (final c in arc) c.withValues(alpha: c.a * glow),
            ])
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 9 * k),
        )
        ..drawArc(
          rect,
          _start,
          sweep,
          false,
          Paint.from(stroke)..shader = shader(arc),
        );
    }

    // The knob in the arc's rotated frame (as `ProgressRing` draws it), so its
    // shadow keeps the spec offset: +1.5 along the travel, +2 toward the centre.
    final top = Offset(0, -radius);
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(_start + sweep + math.pi / 2)
      ..drawCircle(top, 17 * k, Paint()..color = halo)
      ..drawCircle(
        top + Offset(1.5 * k, 2 * k),
        9.5 * k,
        Paint()..color = knobShadow,
      )
      ..drawCircle(top, 9 * k, Paint()..color = Colors.white)
      ..restore();
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.fraction != fraction ||
      old.k != k ||
      old.track != track ||
      !listEquals(old.arc, arc) ||
      old.glow != glow ||
      old.halo != halo ||
      old.knobShadow != knobShadow;
}
