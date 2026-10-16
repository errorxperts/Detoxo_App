import 'dart:math' as math;

import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_brush.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_face.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_frame.dart';
import 'package:flutter/painting.dart';

/// Ring: a ring that fills toward the next colour and stays beside the open
/// timer. Twin of the Kotlin `RingFace`.
final class RingFace extends BubbleFace {
  const RingFace();

  @override
  double get countSize => 22;

  @override
  double get timerPaddingLeft => 72;

  @override
  void drawDial(BubbleFrame f, BubbleBrush b) {
    final centre = f.at(34, 34);
    final r = f.u(30);
    Paint pen(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = f.u(4)
      ..strokeCap = StrokeCap.round
      ..color = c;
    b.canvas
      ..drawCircle(centre, r, pen(f.look.faint))
      ..drawArc(
        Rect.fromCircle(center: centre, radius: r),
        -math.pi / 2,
        f.pct * 3.6 * math.pi / 180,
        false,
        pen(f.look.ink),
      );
  }
}
