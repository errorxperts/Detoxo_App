import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Screen 5 hero: a shield with a lock that "clicks" shut and an always-on
/// pulse — the commitment device, built from design-system primitives. Under
/// reduce-motion it renders the sealed end-state.
class CommitmentHero extends StatelessWidget {
  const CommitmentHero({required this.accent, super.key});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    Widget lock = IconBadge(
      icon: Icons.lock_rounded,
      size: 96,
      color: accent,
      bordered: true,
      fillAlpha: 0.20,
      semanticLabel: 'Locked and protected',
    );
    if (!reduceMotion) {
      // The lock settles shut once when the hero builds.
      lock = lock
          .animate()
          .scaleXY(begin: 1.35, end: 1, duration: AppDurations.medium, curve: AppCurves.emphasized)
          .fadeIn(duration: AppDurations.normal);
    }

    return SizedBox(
      height: 220,
      width: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft accent halo, matching the other screens' illustration bloom.
          Container(
            height: 190,
            width: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [accent.withValues(alpha: 0.30), accent.withValues(alpha: 0)],
              ),
            ),
          ),
          lock,
          // "Always-on" pulse badge pinned to the shield's corner.
          Align(
            alignment: const Alignment(0.42, -0.42),
            child: StatusDot(color: AppColors.success, pulsing: !reduceMotion),
          ),
        ],
      ),
    );
  }
}
