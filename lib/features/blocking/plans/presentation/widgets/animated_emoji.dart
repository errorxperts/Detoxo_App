import 'dart:math' as math;

import 'package:detoxo/core/design_system/tokens/app_motion.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/emoji_band.dart';
import 'package:flutter/material.dart';

/// Renders an emoji glyph with one of the 14 [EmojiAnimation] styles, driven by
/// a single repeating [AnimationController]. Respects reduce-motion (renders a
/// still glyph). The motion table mirrors `docs/05-plans-pause-curious.md` §6.3.
class AnimatedEmoji extends StatefulWidget {
  const AnimatedEmoji({
    required this.emoji,
    required this.animation,
    this.size = 72,
    super.key,
  });

  final String emoji;
  final EmojiAnimation animation;
  final double size;

  @override
  State<AnimatedEmoji> createState() => _AnimatedEmojiState();
}

class _AnimatedEmojiState extends State<AnimatedEmoji>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _durationFor(widget.animation),
  );

  static Duration _durationFor(EmojiAnimation a) => switch (a) {
        EmojiAnimation.shake || EmojiAnimation.quaking => const Duration(milliseconds: 650),
        EmojiAnimation.flash || EmojiAnimation.chaos => const Duration(milliseconds: 900),
        EmojiAnimation.lumber => const Duration(milliseconds: 3200),
        EmojiAnimation.fly || EmojiAnimation.slide => const Duration(milliseconds: 2400),
        _ => const Duration(milliseconds: 1800),
      };

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Smooth 0→1→0 (eased ping-pong) for "breathing"-style motions.
  double _pingPong(double t) => 0.5 - 0.5 * math.cos(t * 2 * math.pi);

  /// Symmetric -1..1 wave for side-to-side / rotation motions.
  double _wave(double t) => math.sin(t * 2 * math.pi);

  /// Crossfades to the new glyph (keyed by the emoji itself) so a band change
  /// dissolves smoothly instead of snapping mid-motion.
  Widget _glyph() => AnimatedSwitcher(
        duration: AppDurations.normal,
        switchInCurve: AppCurves.standard,
        switchOutCurve: AppCurves.standard,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1).animate(anim),
            child: child,
          ),
        ),
        child: Text(
          widget.emoji,
          key: ValueKey(widget.emoji),
          style: TextStyle(fontSize: widget.size, height: 1.1),
        ),
      );

  Widget _animated(double t, Widget child) {
    final s = widget.size;
    switch (widget.animation) {
      case EmojiAnimation.breathing:
        return Transform.scale(scale: 1 + 0.08 * _pingPong(t), child: child);
      case EmojiAnimation.scanning:
        return Transform.translate(offset: Offset(0.10 * s * _wave(t), 0), child: child);
      case EmojiAnimation.melting:
        return Opacity(
          opacity: 1 - 0.22 * _pingPong(t),
          child: Transform.scale(
            scaleX: 1,
            scaleY: 1 - 0.20 * _pingPong(t),
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      case EmojiAnimation.bouncing:
        return Transform.translate(
          offset: Offset(0, -0.22 * s * math.sin(t * 2 * math.pi).abs()),
          child: child,
        );
      case EmojiAnimation.waving:
        return Transform.rotate(angle: (10 * math.pi / 180) * _wave(t), child: child);
      case EmojiAnimation.quaking:
        return Transform.translate(
          offset: Offset(
            2.5 * math.sin(t * 2 * math.pi * 13),
            2.5 * math.cos(t * 2 * math.pi * 11),
          ),
          child: child,
        );
      case EmojiAnimation.chaos:
        return Transform.rotate(
          angle: (8 * math.pi / 180) * math.sin(t * 2 * math.pi * 3),
          child: Transform.translate(
            offset: Offset(0.12 * s * math.sin(t * 2 * math.pi * 2),
                0.08 * s * math.cos(t * 2 * math.pi * 2.5)),
            child: child,
          ),
        );
      case EmojiAnimation.slide:
        return Transform.translate(
          offset: Offset(-0.18 * s * (1 - Curves.easeOut.transform(t)), 0),
          child: child,
        );
      case EmojiAnimation.lumber:
        return Transform.translate(
          offset: Offset(0, 0.04 * s * _pingPong(t)),
          child: Transform.scale(scale: 1 + 0.05 * _pingPong(t), child: child),
        );
      case EmojiAnimation.sinking:
        return Opacity(
          opacity: 1 - 0.3 * _pingPong(t),
          child: Transform.translate(offset: Offset(0, 0.16 * s * _pingPong(t)), child: child),
        );
      case EmojiAnimation.glow:
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context)
                    .colorScheme
                    .secondary
                    .withValues(alpha: 0.25 + 0.45 * _pingPong(t)),
                blurRadius: 8 + 22 * _pingPong(t),
                spreadRadius: 2 * _pingPong(t),
              ),
            ],
          ),
          child: child,
        );
      case EmojiAnimation.flash:
        return Opacity(opacity: 0.3 + 0.7 * (0.5 + 0.5 * _wave(t)), child: child);
      case EmojiAnimation.fly:
        return Transform.translate(
          offset: Offset(0.20 * s * _wave(t), -0.05 * s * _pingPong(t)),
          child: child,
        );
      case EmojiAnimation.shake:
        return Transform.translate(
          offset: Offset(3.0 * math.sin(t * 2 * math.pi * 16), 0),
          child: child,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final glyph = _glyph();
    if (reduceMotion) {
      if (_c.isAnimating) _c.stop();
      return glyph;
    }
    // Only retune + restart the loop when the motion (and thus its duration)
    // actually changes — reassigning every frame would reset the repeat
    // mid-cycle and read as a glitch.
    final duration = _durationFor(widget.animation);
    if (_c.duration != duration) {
      _c.duration = duration;
      _c.repeat();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => _animated(_c.value, child!),
      child: glyph,
    );
  }
}
