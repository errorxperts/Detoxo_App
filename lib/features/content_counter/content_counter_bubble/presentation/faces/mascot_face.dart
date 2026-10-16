import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_brush.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_face.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_frame.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_tokens.g.dart';
import 'package:flutter/painting.dart';

/// Mascot: the bubble is the mascot's face, its mood stepping down every
/// hundred; it draws its own count in a chin chip. Twin of the Kotlin
/// `MascotFace`.
final class MascotFace extends BubbleFace {
  const MascotFace();

  @override
  bool get shellCount => false;

  // Per mood (= tier): blush, sweat, tears and hand alpha; pupil dx, dy.
  static const _blush = [.7, .7, 0.0, 0.0, 0.0, 0.0];
  static const _sweat = [0.0, 0.0, 0.0, .9, .9, 0.0];
  static const _tears = [0.0, 0.0, 0.0, 0.0, .8, 1.0];
  static const _hand = [0.0, 0.0, 0.0, 0.0, 0.0, 1.0];
  static const _pupilDx = [0.0, 0.0, 0.0, 1.0, 0.0, 0.0];
  static const _pupilDy = [0.0, 0.0, -1.0, 0.0, 1.0, 1.0];

  @override
  void drawOverlay(BubbleFrame f, BubbleBrush b) {
    final a = 1 - f.expand;
    if (a <= 0) return;
    final m = f.tier.clamp(0, 5);
    final c = b.canvas;
    Paint fill(Color color, [double k = 1]) =>
        Paint()..color = color.fade(a * k);
    Paint pen(Color color, double w, [double k = 1]) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.fade(a * k);
    void dot(double x, double y, double r, Paint p) =>
        c.drawCircle(Offset(x, y), r, p);

    const white = Color(0xFFFFFFFF);
    c
      ..save()
      ..translate(f.at(0, 0).dx, f.at(0, 0).dy)
      ..scale(f.s)
      ..drawOval(
        Rect.fromCenter(center: const Offset(22, 18), width: 18, height: 8),
        fill(white, .55),
      );
    final eye = fill(BubbleTokens.mascotEye);
    dot(25, 30, 7, eye);
    dot(43, 30, 7, eye);
    final pupil = fill(BubbleTokens.mascotPupil);
    dot(26 + _pupilDx[m], 31 + _pupilDy[m], 3.6, pupil);
    dot(44 + _pupilDx[m], 31 + _pupilDy[m], 3.6, pupil);
    final glint = fill(white);
    dot(27.2, 29.6, 1.1, glint);
    dot(45.2, 29.6, 1.1, glint);

    final ink = f.look.ink;
    c.drawPath(b.svg(BubblePaths.brows[m]), pen(ink, 2.2));
    // Moods 1 and 2 are filled open mouths; mood 2's is an oval (no arcs).
    final mouth = m == 2
        ? (Path()..addOval(
            Rect.fromCenter(center: const Offset(34, 41), width: 8, height: 10),
          ))
        : b.svg(BubblePaths.mouths[m]);
    if (m == 1 || m == 2) {
      c.drawPath(mouth, fill(BubbleTokens.mascotPupil, .9));
    }
    c.drawPath(mouth, pen(ink, 2.4));

    if (_blush[m] > 0) {
      final blush = fill(BubbleTokens.mascotBlush, _blush[m]);
      dot(16, 40, 3, blush);
      dot(52, 40, 3, blush);
    }
    if (_sweat[m] > 0) {
      c.drawPath(
        b.svg(BubblePaths.sweat),
        fill(BubbleTokens.mascotWater, _sweat[m]),
      );
    }
    if (_tears[m] > 0) {
      c.drawPath(
        b.svg(BubblePaths.tears),
        pen(BubbleTokens.mascotWater, 2, _tears[m]),
      );
    }
    if (_hand[m] > 0) {
      final hand = b.svg(BubblePaths.hand);
      c
        ..drawPath(hand, fill(white, _hand[m]))
        ..drawPath(hand, pen(BubbleTokens.mascotPupil, 1.6, _hand[m]));
    }
    c.restore();

    // The count chip, in px: the chin, h18 r9, sized to the number.
    final size = f.u(11.5);
    final w = b.textWidth(f.countText, size: size) + f.u(14);
    final centre = f.at(34, 56);
    final chip = RRect.fromRectAndRadius(
      Rect.fromCenter(center: centre, width: w, height: f.u(18)),
      Radius.circular(f.u(9)),
    );
    c
      ..drawRRect(
        chip.shift(Offset(0, f.u(1))),
        Paint()
          ..color = BubbleTokens.chipShadow.fade(a)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, f.u(2)),
      )
      ..drawRRect(chip, fill(BubbleTokens.badgeBg));
    b.text(
      f.countText,
      centre,
      size: size,
      color: BubbleTokens.pillInk,
      alpha: a,
    );
  }
}
