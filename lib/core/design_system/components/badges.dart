import 'package:flutter/material.dart';

import 'package:detoxo/core/design_system/tokens/app_colors.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';

/// Semantic tone shared by pills, badges and toasts.
enum AppTone { neutral, accent, success, warning, danger }

/// Resolves a tone to its accent colour (context needed for `neutral`).
Color toneColor(BuildContext context, AppTone tone) => switch (tone) {
      AppTone.neutral => Theme.of(context).colorScheme.onSurfaceVariant,
      AppTone.accent => AppColors.accent,
      AppTone.success => AppColors.success,
      AppTone.warning => AppColors.warning,
      AppTone.danger => AppColors.danger,
    };

/// A small rounded status chip — "Required", "Premium", "Active". Replaces the
/// ad-hoc inline chips that were scattered across screens.
class Pill extends StatelessWidget {
  const Pill({required this.label, this.tone = AppTone.neutral, this.icon, super.key});

  final String label;
  final AppTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = toneColor(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: AppRadius.brPill,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

/// A tiny label/dot marker (e.g. a stat trend). Named to avoid clashing with
/// Material's own `Badge`.
class AppBadge extends StatelessWidget {
  const AppBadge.label(this.label, {this.tone = AppTone.neutral, super.key});

  final String label;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final color = toneColor(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: AppRadius.brSm,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
