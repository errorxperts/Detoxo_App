import 'package:flutter/material.dart';

import 'package:detoxo/core/design_system/adaptive/adaptive_controls.dart';
import 'package:detoxo/core/design_system/components/badges.dart';
import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';

/// A glass row used in lists (feature entries, quick actions). Flat translucent
/// fill (no per-row blur) so a long list stays smooth.
class GlassListTile extends StatelessWidget {
  const GlassListTile({
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    super.key,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final row = GlassContainer(
      enableBlur: false,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.md)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (subtitle != null)
                  Text(subtitle!, style: text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: AppSpacing.sm), trailing!],
        ],
      ),
    );
    if (onTap == null) return row;
    return AppPressable(onTap: onTap!, child: row);
  }
}

/// A labelled row with a trailing adaptive switch. When [locked], shows a
/// "Premium" pill in the same trailing slot instead of the switch — keeping
/// every row in a list visually consistent (fixes the blocklist inconsistency).
class AdaptiveSwitchTile extends StatelessWidget {
  const AdaptiveSwitchTile({
    required this.title,
    this.subtitle,
    this.leading,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.locked = false,
    this.onLockedTap,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final bool locked;
  final VoidCallback? onLockedTap;

  @override
  Widget build(BuildContext context) {
    final trailing = locked
        ? const Pill(label: 'Premium', tone: AppTone.warning, icon: Icons.lock_outline)
        : AdaptiveSwitch(value: value, onChanged: onChanged, enabled: enabled);
    return GlassListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: locked ? onLockedTap : null,
    );
  }
}
