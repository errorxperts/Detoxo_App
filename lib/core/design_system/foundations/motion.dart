import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:detoxo/core/design_system/tokens/app_motion.dart';

/// Global haptics gate, mirrored from `AppSettings.vibrationEnabled`. Set once
/// from a high-level `BlocListener` so leaf widgets stay context-light.
abstract final class AppHaptics {
  static bool enabled = true;

  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }
}

/// Scale-on-press micro-interaction with optional haptic feedback. Wrap any
/// tappable surface (GlassCard, CTAs, tiles).
class AppPressable extends StatefulWidget {
  const AppPressable({
    required this.child,
    required this.onTap,
    this.pressedScale = 0.96,
    this.haptic = true,
    super.key,
  });

  final Widget child;
  final VoidCallback onTap;
  final double pressedScale;
  final bool haptic;

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppDurations.instant,
    lowerBound: 0,
    upperBound: 1,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down(_) => _c.forward();
  void _up([_]) => _c.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _up,
      onTap: () {
        if (widget.haptic) AppHaptics.light();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.scale(
          scale: 1 - (_c.value * (1 - widget.pressedScale)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Entrance animation helpers (flutter_animate) for a consistent fade + slide-up.
extension EntranceX on Widget {
  /// Single-item entrance: fade + slide-up.
  Widget entrance({Duration delay = Duration.zero}) => animate(delay: delay)
      .fadeIn(duration: AppDurations.normal, curve: AppCurves.decelerate)
      .slideY(begin: 0.12, end: 0, duration: AppDurations.normal, curve: AppCurves.standard);
}

/// Staggered entrance for a list of children (stat tiles, permission cards, rows).
class EntranceList extends StatelessWidget {
  const EntranceList({
    required this.children,
    this.interval = AppDurations.stagger,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    super.key,
  });

  final List<Widget> children;
  final Duration interval;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: children
          .animate(interval: interval)
          .fadeIn(duration: AppDurations.normal, curve: AppCurves.decelerate)
          .slideY(begin: 0.15, end: 0, duration: AppDurations.normal, curve: AppCurves.standard),
    );
  }
}

/// Pulsing / glowing status dot — "blocking active" on dashboard, "resumes in"
/// on pause. Colour encodes state (accent / danger / warning).
class StatusDot extends StatelessWidget {
  const StatusDot({
    required this.color,
    this.size = 12,
    this.pulsing = true,
    super.key,
  });

  final Color color;
  final double size;
  final bool pulsing;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)],
      ),
    );
    if (!pulsing || reduceMotion) return dot;
    return dot
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 1, end: 1.25, duration: AppDurations.pulse, curve: AppCurves.gentle);
  }
}
