import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// One stat in a [StatStrip]: an icon, a value, and a short label.
class StatPill {
  const StatPill({
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final String value;
  final String label;

  /// Accent for the icon (defaults to the scheme primary).
  final Color? iconColor;
}

/// The hero's secondary stats as a minimal, uncontained row — no glass box, just
/// two `icon value label` indicators separated by a faint dot. A light-touch
/// readout of today's reels + blocks, sitting directly under the hero ring.
class StatStrip extends StatelessWidget {
  const StatStrip({required this.stats, super.key});

  final List<StatPill> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                '·',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.5),
                ),
              ),
            ),
          _Indicator(stat: stats[i]),
        ],
      ],
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.stat});

  final StatPill stat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final accent = stat.iconColor ?? scheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(stat.icon, size: 16, color: accent),
        const SizedBox(width: AppSpacing.xs),
        Text(
          stat.value,
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 4),
        Text(
          stat.label,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
