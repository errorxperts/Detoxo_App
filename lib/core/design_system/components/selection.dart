import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/design_system/tokens/app_colors.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:flutter/material.dart';

/// A selectable glass chip (e.g. small option pickers). For 2–4 segment
/// pickers prefer `AdaptiveSegmentedControl`.
class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppPressable(
      onTap: onSelected,
      pressedScale: 0.94,
      child: GlassContainer(
        enableBlur: false,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        borderRadius: AppRadius.pill,
        tintTop: selected ? AppColors.accent.withValues(alpha: 0.28) : null,
        tintBottom: selected ? AppColors.accent.withValues(alpha: 0.14) : null,
        borderColor: selected ? AppColors.accent.withValues(alpha: 0.6) : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: AppSpacing.xxs)],
            Text(
              label,
              style: text.labelLarge?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
