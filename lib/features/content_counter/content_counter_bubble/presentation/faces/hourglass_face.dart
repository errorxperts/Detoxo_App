import 'package:detoxo/features/content_counter/content_counter_bubble/domain/bubble_model.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_brush.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_face.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_frame.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_look.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_tokens.g.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/painting.dart';

/// Hourglass: the logo behind a softly glowing count, with sand that runs
/// out; the grain falls while the timer is open. Twin of the Kotlin
/// `HourglassFace`.
final class HourglassFace extends BubbleFace {
  const HourglassFace();

  @override
  double get countSize => 20;

  @override
  double get timerPaddingLeft => 70;

  @override
  bool loops({required bool open}) => open;

  @override
  int get loopPeriodMs => BubbleTokens.msSand;

  @override
  bool get timerGrain => true;

  /// The board's `text-shadow: 0 0 8px rgba(255,255,255,.6)`.
  @override
  double get countGlow => 8;

  @override
  Color? glowColor(BubbleLook l) => Colors.white.withValues(alpha: 0.6);

  @override
  void drawDial(BubbleFrame f, BubbleBrush b) {
    final c = b.canvas;
    final shape = b.svg(BubblePaths.hourglassBig);
    final origin = f.at(0, 0);
    c
      ..save()
      ..translate(origin.dx, origin.dy)
      ..scale(f.s)
      ..drawPath(
        shape,
        Paint()..color = Colors.white.withValues(alpha: 0.35 * 0.55),
      )
      ..drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = f.look.ink.fade(0.55),
      );
    final sand = Paint()..color = f.look.ink.fade(0.5);
    c
      ..save()
      ..clipPath(b.svg(BubblePaths.clipTop))
      ..drawRect(Rect.fromLTWH(23, BubbleModel.sandTop(f.pct), 22, 20), sand)
      ..restore()
      ..save()
      ..clipPath(b.svg(BubblePaths.clipBottom))
      ..drawRect(Rect.fromLTWH(23, BubbleModel.sandBottom(f.pct), 22, 22), sand)
      ..restore()
      ..restore();
  }
}
