import 'dart:ui';

import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_brush.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_frame.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_look.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_tokens.g.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/faces/bezel_face.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/faces/drop_face.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/faces/hourglass_face.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/faces/liquid_face.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/faces/mascot_face.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/faces/ring_face.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';

/// One style's ability over the shared shell (spec §6.4). The defaults are
/// the plain shell; a face overrides only what its style changes. Sizes are
/// board units at size 68. Twin of the Kotlin `BubbleFace`.
abstract class BubbleFace {
  const BubbleFace();

  /// The collapsed count's text size.
  double get countSize => BubbleTokens.countText;

  /// The open timer's left padding before the mark.
  double get timerPaddingLeft => 15;

  /// Gap to the screen edge when docked.
  double get edge => BubbleTokens.edge;

  /// Whether the shell draws the count (false: the face draws its own).
  bool get shellCount => true;

  /// Whether the face animates on its own loop while [open] is as given.
  bool loops({required bool open}) => false;

  /// One loop's length; `loopT` runs 0..1 over it.
  int get loopPeriodMs => 0;

  /// The whole bubble's scale about the docked edge at [loopT] (0..1), 1 =
  /// none. Only Drop breathes; Liquid loops without it.
  double breathScale(double loopT) => 1;

  /// Whether the open timer's mark drops its middle grain on `loopT`.
  bool get timerGrain => false;

  /// The body's docked-side corner radius (the outer corners stay 34); the
  /// pulse ring follows the same shape.
  double get radiusEdge => 34;

  /// The count's and timer's text glow, none at 0: the board's CSS
  /// `text-shadow` blur radius in board units. Dart sigma = radius / 2;
  /// Kotlin `BlurMaskFilter` radius = radius.
  double get countGlow => 0;

  /// The glow's colour; null glows in the count / timer colour.
  Color? glowColor(BubbleLook l) => null;

  Color countColor(BubbleFrame f) => f.look.ink;

  /// The timer mark's fill; null draws the outline only.
  Color? markFill(BubbleLook l) => l.mark;

  /// Under everything: the shell by default. Also drawn while "reels left"
  /// shows, so the style's base look survives.
  void drawBackground(BubbleFrame f, BubbleBrush b) =>
      b.shell(f, radiusEdge: radiusEdge);

  /// Between the background and the count; skipped while "reels left" shows.
  void drawDial(BubbleFrame f, BubbleBrush b) {}

  /// Over the count and timer, under the pulse ring and pill; skipped while
  /// "reels left" shows.
  void drawOverlay(BubbleFrame f, BubbleBrush b) {}
}

/// Each style's face; a new [BubbleVariant] will not compile without one.
extension BubbleVariantFace on BubbleVariant {
  BubbleFace get face => switch (this) {
    BubbleVariant.mascot => const MascotFace(),
    BubbleVariant.ring => const RingFace(),
    BubbleVariant.liquid => const LiquidFace(),
    BubbleVariant.hourglass => const HourglassFace(),
    BubbleVariant.bezel => const BezelFace(),
    BubbleVariant.drop => const DropFace(),
  };
}
