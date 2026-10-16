import 'dart:math' as math;

import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_brush.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_face.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_frame.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_tokens.g.dart';
import 'package:flutter/painting.dart';

/// Drop: a breathing drop that clings to the screen edge. Twin of the Kotlin
/// `DropFace`.
final class DropFace extends BubbleFace {
  const DropFace();

  @override
  double get edge => 0;

  /// The docked side points into the edge.
  @override
  double get radiusEdge => 10;

  @override
  bool loops({required bool open}) => true;

  @override
  int get loopPeriodMs => BubbleTokens.msBreath;

  @override
  double breathScale(double loopT) => 1 + 0.06 * math.sin(math.pi * loopT);

  /// The sheen sits on the free side: x 23, mirrored to 45 when docked left.
  @override
  void drawOverlay(BubbleFrame f, BubbleBrush b) {
    b.canvas.drawOval(
      Rect.fromCenter(
        center: f.at(f.dockedRight ? 23 : 45, 15),
        width: f.u(22),
        height: f.u(10),
      ),
      Paint()..color = BubbleTokens.sheen,
    );
  }
}
