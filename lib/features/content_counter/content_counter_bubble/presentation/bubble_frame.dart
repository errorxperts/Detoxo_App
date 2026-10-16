import 'dart:ui';

import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_look.dart';
import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_tokens.g.dart';

/// One frame's worth of shell state, handed to every `BubbleFace` draw call.
/// Board numbers are units of the 68-unit square; [at] and [u] turn them into
/// canvas px. Twin of the Kotlin `BubbleFrame` (plus [shortTime], which the
/// Kotlin view reads from its own state).
///
/// Anchoring (the board's `left:0` layers): [at] places the board square at
/// the capsule's LEFT edge, so the count, dials and overlays ride inward with
/// it on a right dock as the timer opens (on a left dock that edge is the
/// docked one). [collapsed] is the square at the DOCKED side and is for the
/// time pill only (the board's `align-self: flex-end`).
final class BubbleFrame {
  const BubbleFrame({
    required this.body,
    required this.s,
    required this.look,
    required this.tier,
    required this.prevTier,
    required this.blend,
    required this.count,
    required this.pct,
    required this.countText,
    required this.clock,
    required this.shortTime,
    required this.expand,
    required this.pop,
    required this.pulse,
    required this.pill,
    required this.loopT,
    required this.open,
    required this.dockedRight,
  });

  /// The (possibly widened) body rect in canvas px; it grows inward from the
  /// docked edge.
  final Rect body;

  /// Canvas px per board unit (`size / 68`).
  final double s;

  /// The tier look, already blended from [prevTier] to [tier] by [blend].
  final BubbleLook look;

  /// The current tier, 0..5.
  final int tier;

  /// The tier the cross-fade comes from (equals [tier] once settled).
  final int prevTier;

  /// The tier cross-fade, 0 = [prevTier]'s look, 1 = [tier]'s look.
  final double blend;

  /// Today's reel count.
  final int count;

  /// Progress to the next colour, 0..100 (100 at tier 5).
  final int pct;

  /// The collapsed count string (`152`, `1.2k`).
  final String countText;

  /// The timer string (`MM:SS` / `H:MM:SS`).
  final String clock;

  /// The pill's watch time (`21m`, `1h 12m`).
  final String shortTime;

  /// The timer capsule, 0 = collapsed square, 1 = open (may overshoot 1).
  final double expand;

  /// The count pop's progress, 0 = at rest, 1 = finished (scale 1 → 1.18 → 1).
  final double pop;

  /// The milestone ring's progress, 0 = none, 0..1 = growing and fading out.
  final double pulse;

  /// The time pill's visibility, 0 = folded away, 1 = fully shown.
  final double pill;

  /// The style loop's phase, 0..1 over the face's `loopPeriodMs`.
  final double loopT;

  /// Whether the timer is open (the target of [expand]).
  final bool open;

  /// Whether the bubble sits on the right edge (the capsule grows leftwards).
  final bool dockedRight;

  /// Board length → px.
  double u(double v) => v * s;

  /// Board point → canvas, from the body's top-left (the capsule's left edge).
  Offset at(double x, double y) => Offset(body.left + x * s, body.top + y * s);

  /// The size × size square at the docked side of the body; the pill's anchor.
  Rect get collapsed {
    final side = u(BubbleTokens.size);
    return Rect.fromLTWH(
      dockedRight ? body.right - side : body.left,
      body.top,
      side,
      side,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BubbleFrame &&
      other.body == body &&
      other.s == s &&
      other.look == look &&
      other.tier == tier &&
      other.prevTier == prevTier &&
      other.blend == blend &&
      other.count == count &&
      other.pct == pct &&
      other.countText == countText &&
      other.clock == clock &&
      other.shortTime == shortTime &&
      other.expand == expand &&
      other.pop == pop &&
      other.pulse == pulse &&
      other.pill == pill &&
      other.loopT == loopT &&
      other.open == open &&
      other.dockedRight == dockedRight;

  @override
  int get hashCode => Object.hash(
    body,
    s,
    look,
    tier,
    prevTier,
    blend,
    count,
    pct,
    countText,
    clock,
    shortTime,
    expand,
    pop,
    pulse,
    pill,
    loopT,
    open,
    dockedRight,
  );
}
