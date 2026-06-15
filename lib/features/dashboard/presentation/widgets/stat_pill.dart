import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// A compact glass capsule showing an icon + value + label, used for the hero's
/// secondary stats (e.g. blocked count, streak).
class StatPill extends StatelessWidget {
  const StatPill({
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
    super.key,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return GlassContainer(
      borderRadius: AppRadius.pill,
      blurSigma: AppBlur.subtle,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor ?? scheme.primary),
          const SizedBox(width: AppSpacing.xs),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label.toUpperCase(),
                style: text.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 9,
                  letterSpacing: 0.5,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
