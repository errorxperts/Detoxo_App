import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_brush.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_face.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_frame.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_look.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_tokens.g.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_tokens.g.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/painting.dart';

/// Liquid: the tier colour fills the glass to `pct` under a moving crest.
/// Twin of the Kotlin `LiquidFace`.
final class LiquidFace extends BubbleFace {
  const LiquidFace();

  @override
  bool loops({required bool open}) => true;

  @override
  int get loopPeriodMs => BubbleTokens.msWave;

  /// White once a dark tier's liquid rises past the count.
  @override
  Color countColor(BubbleFrame f) => f.tier >= 4 && f.pct > 55
      ? WidgetTokens.widgetInkInverse
      : BubbleTokens.pillInk;

  @override
  Color? markFill(BubbleLook l) => Colors.white.withValues(alpha: 0.5);

  @override
  void drawBackground(BubbleFrame f, BubbleBrush b) {
    b.shell(
      f,
      fillFrom: BubbleTokens.liquidGlass,
      fillTo: BubbleTokens.liquidGlass,
      shadow: BubbleTokens.liquidShadow,
      radiusEdge: radiusEdge,
    );
    final c = b.canvas;
    final level = f.at(0, 68 * (1 - f.pct.clamp(0, 100) / 100)).dy;
    final area = f.body;
    c
      ..save()
      ..clipRRect(b.body(f, radiusEdge: radiusEdge))
      ..drawRect(
        Rect.fromLTRB(area.left, level, area.right, area.bottom),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(area.left, level),
            Offset(area.left, area.bottom),
            [f.look.fillFrom, f.look.fillTo],
          ),
      )
      // Crest: half-ellipses rx 14 ry 8 every 28 along the level, clipped to
      // the 12 units above it.
      ..clipRect(Rect.fromLTRB(area.left, level - f.u(12), area.right, level));
    final rx = f.u(14);
    final ry = f.u(8);
    final crest = Paint()..color = Colors.white.withValues(alpha: 0.55);
    var cx = area.left - f.u(14) * math.sin(math.pi * f.loopT) - rx;
    while (cx - rx < area.right) {
      c.drawPath(
        Path()
          ..addArc(
            Rect.fromLTRB(cx - rx, level - ry, cx + rx, level + ry),
            math.pi,
            math.pi,
          )
          ..close(),
        crest,
      );
      cx += f.u(28);
    }
    c.restore();
  }
}
