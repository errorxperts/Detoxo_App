import 'package:detoxo/core/design_system/components/badges.dart';
import 'package:detoxo/core/design_system/components/buttons.dart';
import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/tokens/app_colors.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:flutter/material.dart';

/// Generic shell for a permission row: leading icon, title + required/optional
/// pill, a one-line "why", and a trailing grant control or granted check.
/// Feature code (PermissionRow) binds an `AppPermission` to this shell.
class PermissionCard extends StatelessWidget {
  const PermissionCard({
    required this.icon,
    required this.title,
    required this.why,
    required this.granted,
    required this.onGrant,
    this.isRequired = false,
    this.permanentlyDenied = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String why;
  final bool granted;
  final bool isRequired;

  /// When true the OS won't prompt again, so the action label becomes
  /// "Open settings" (its callback should route to the app's system settings).
  final bool permanentlyDenied;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accent = Theme.of(context).colorScheme.secondary;
    return GlassContainer(
      enableBlur: false,
      borderColor: granted ? AppColors.success.withValues(alpha: 0.4) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: AppRadius.brMd,
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (isRequired) ...[
                      const SizedBox(width: AppSpacing.xs),
                      const Pill(label: 'Required', tone: AppTone.danger),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(why, style: text.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                if (granted)
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.success, size: 18),
                      SizedBox(width: AppSpacing.xs),
                      Text('Granted'),
                    ],
                  )
                else
                  SecondaryButton(
                    label: permanentlyDenied ? 'Open settings' : 'Grant',
                    onPressed: onGrant,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
