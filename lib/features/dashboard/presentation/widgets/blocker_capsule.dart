import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// A compact, tappable glass capsule for the blocked-apps grid: a glowing icon
/// circle with a pulsing status dot, a title, and a caption (e.g. count).
class BlockerCapsule extends StatelessWidget {
  const BlockerCapsule({
    required this.icon,
    required this.title,
    required this.caption,
    required this.onTap,
    this.accent,
    super.key,
  });

  final AppIcon icon;
  final String title;
  final String caption;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final c = accent ?? scheme.primary;

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.withValues(alpha: 0.12),
                    border: Border.all(color: c.withValues(alpha: 0.25)),
                  ),
                  child: AppAnimatedIcon(
                    icon: icon,
                    color: c,
                    playOnAppear: true,
                  ),
                ),
                Positioned(
                  top: -2,
                  right: -2,
                  child: StatusDot(color: c, size: 8),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            caption.toUpperCase(),
            style: text.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: 9,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
