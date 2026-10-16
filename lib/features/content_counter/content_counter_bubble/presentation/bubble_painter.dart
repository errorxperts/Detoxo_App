import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_brush.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_face.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_frame.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_tokens.g.dart';
import 'package:flutter/rendering.dart';

/// The bubble's shell painter, the Flutter mirror of the Kotlin `BubbleView`
/// draw pass (spec §6.2): face background → face dial → count (or the
/// [remaining] override) → timer → face overlay → pulse ring → time pill.
/// [opacity] is the user's fill opacity. With [remaining] set the face keeps
/// its background but skips its dial and overlay, and the count reads
/// `N left`.
class BubblePainter extends CustomPainter {
  BubblePainter({
    required this.frame,
    required this.face,
    required this.opacity,
    this.remaining,
  });

  final BubbleFrame frame;
  final BubbleFace face;
  final double opacity;
  final int? remaining;

  /// The time pill shows while it is up and the timer is folded (BR-02).
  static bool showsPill(BubbleFrame f) => f.pill > 0 && !f.open;

  @override
  void paint(Canvas canvas, Size size) {
    final f = frame;
    final b = BubbleBrush(canvas, opacity);
    final breathes = face.loops(open: f.open);
    if (breathes) {
      final k = face.breathScale(f.loopT);
      final pivot = Offset(
        f.dockedRight ? f.body.right : f.body.left,
        f.body.center.dy,
      );
      canvas
        ..save()
        ..translate(pivot.dx, pivot.dy)
        ..scale(k)
        ..translate(-pivot.dx, -pivot.dy);
    }
    face.drawBackground(f, b);
    if (remaining == null) face.drawDial(f, b);

    final countAlpha = 1 - f.expand;
    final countScale = _popScale(f.pop) * (1 - 0.4 * f.expand);
    // countGlow is a CSS blur radius; the Flutter blur takes sigma = r / 2.
    final glow = face.countGlow * f.s / 2;
    final glowColor = face.glowColor(f.look);
    if (remaining case final n?) {
      b
        ..text(
          '$n',
          f.at(34, 29),
          size: f.u(face.countSize),
          color: face.countColor(f),
          letterSpacing: f.u(-0.6),
          scale: countScale,
          alpha: countAlpha,
          glow: glow,
          glowColor: glowColor,
        )
        ..text(
          'left',
          f.at(34, 52),
          size: f.u(11),
          color: face.countColor(f),
          weight: FontWeight.w700,
          alpha: countAlpha,
        );
    } else if (face.shellCount) {
      b.text(
        f.countText,
        f.at(34, 34),
        size: f.u(face.countSize),
        color: face.countColor(f),
        letterSpacing: f.u(-0.6),
        scale: countScale,
        alpha: countAlpha,
        glow: glow,
        glowColor: glowColor,
      );
    }

    _timer(f, b, face);
    if (remaining == null) face.drawOverlay(f, b);
    _pulse(f, b, face);
    _pill(f, b);
    if (breathes) canvas.restore();
  }

  /// The mark (20 × 31) then the clock, from the body's left, fading in over
  /// the last 70 % of the expand.
  void _timer(BubbleFrame f, BubbleBrush b, BubbleFace face) {
    final alpha = ((f.expand - 0.3) / 0.7).clamp(0.0, 1.0);
    if (alpha == 0) return;
    final left = f.body.left + f.u(face.timerPaddingLeft);
    final cy = f.body.center.dy;
    b.mark(
      f,
      Offset(left, cy - f.u(31) / 2),
      f.u(20),
      f.u(31),
      fill: face.markFill(f.look),
      stroke: f.look.ink,
      grainT: face.timerGrain && f.open ? f.loopT : null,
      alpha: alpha,
    );
    final size = f.u(BubbleTokens.timerText);
    final spacing = f.u(-0.4);
    final w = b.textWidth(f.clock, size: size, letterSpacing: spacing);
    b.text(
      f.clock,
      Offset(left + f.u(20 + 8) + w / 2, cy),
      size: size,
      color: f.look.ink,
      letterSpacing: spacing,
      alpha: alpha,
      glow: face.countGlow * f.s / 2,
      glowColor: face.glowColor(f.look),
    );
  }

  /// The milestone ring (BR-06): the body growing to 1.7× while fading out.
  void _pulse(BubbleFrame f, BubbleBrush b, BubbleFace face) {
    if (f.pulse <= 0) return;
    final c = f.look.ring;
    b.canvas.drawRRect(
      b.body(f, radiusEdge: face.radiusEdge).inflate(f.u(23.8) * f.pulse),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = f.u(2.5)
        ..color = c.withValues(
          alpha: c.a * 0.9 * (1 - f.pulse).clamp(0.0, 1.0),
        ),
    );
  }

  /// The time pill (BR-02) above the docked square, folding down as it
  /// hides; never while the timer is open.
  void _pill(BubbleFrame f, BubbleBrush b) {
    if (!showsPill(f)) return;
    final alpha = f.pill.clamp(0.0, 1.0);
    final size = f.u(BubbleTokens.pillText);
    final h = f.u(BubbleTokens.pillH);
    final w = b.textWidth(f.shortTime, size: size) + 2 * f.u(9);
    final square = f.collapsed;
    final center = Offset(
      square.center.dx,
      square.top - f.u(BubbleTokens.pillGap) - h / 2 + f.u(28) * (1 - f.pill),
    );
    final chip = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: w, height: h),
      Radius.circular(h / 2),
    );
    Color fade(Color c) => c.withValues(alpha: c.a * alpha);
    b.canvas
      ..drawRRect(chip, Paint()..color = fade(BubbleTokens.pillBg))
      ..drawRRect(
        chip.inflate(f.u(0.5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = f.u(1)
          ..color = fade(f.look.ring),
      );
    b.text(
      f.shortTime,
      center,
      size: size,
      color: BubbleTokens.pillInk,
      alpha: alpha,
    );
  }

  /// The count pop (BR-07): 1 → 1.18 by 40 %, back to 1 at the end.
  static double _popScale(double pop) =>
      1 + 0.18 * (pop < 0.4 ? pop / 0.4 : 1 - (pop - 0.4) / 0.6);

  @override
  bool shouldRepaint(BubblePainter old) =>
      old.frame != frame ||
      old.face != face ||
      old.opacity != opacity ||
      old.remaining != remaining;
}
