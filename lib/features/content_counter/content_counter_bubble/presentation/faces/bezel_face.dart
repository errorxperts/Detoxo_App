import 'dart:math' as math;

import 'package:detoxo/features/content_counter/content_counter_bubble/domain/bubble_model.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_brush.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_face.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_frame.dart';
import 'package:flutter/painting.dart';

/// Bezel: ten watch ticks that light up, staying beside the open timer. Twin
/// of the Kotlin `BezelFace`.
final class BezelFace extends BubbleFace {
  const BezelFace();

  @override
  double get countSize => 21;

  @override
  double get timerPaddingLeft => 70;

  @override
  void drawDial(BubbleFrame f, BubbleBrush b) {
    final lit = BubbleModel.bezelLit(f.count);
    final c = b.canvas;
    final centre = f.at(34, 34);
    for (var i = 0; i < 10; i++) {
      c
        ..save()
        ..translate(centre.dx, centre.dy)
        ..rotate(i * 36 * math.pi / 180)
        ..translate(-centre.dx, -centre.dy)
        ..drawLine(
          f.at(34, 6),
          f.at(34, 12),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = f.u(3)
            ..strokeCap = StrokeCap.round
            ..color = i < lit ? f.look.ink : f.look.faint,
        )
        ..restore();
    }
  }
}
