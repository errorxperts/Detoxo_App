import 'package:detoxo/core/design_system/components/badges.dart';
import 'package:detoxo/core/design_system/components/toggle.dart';
import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:flutter/material.dart';

/// A flat list row: [leading], the [title] in label / ink over a two-line
/// [subtitle] in subhead / ink-2, and [trailing]. On a panel or a sheet it
/// draws no surface of its own; standalone it is its own panel (no glass
/// inside glass, see [GlassContainer.surfaceOf]). Group rows with
/// [PanelGroup].
///
/// With no [trailing], a selected row shows a check and a plain tappable row
/// a chevron in ink-3.
class GlassListTile extends StatelessWidget {
  const GlassListTile({
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.selected,
    super.key,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Whether the row is the picked one in a selection list. Null (the
  /// default) means the row is not a selection row, so a tappable one
  /// navigates and shows the chevron.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final trailing =
        this.trailing ??
        (selected ?? false
            ? Icon(Icons.check_rounded, size: 18, color: t.ink)
            : selected == null && onTap != null
            ? Icon(Icons.chevron_right_rounded, size: 18, color: t.ink3)
            : null);
    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.label.copyWith(color: t.ink),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppTypography.subhead.copyWith(color: t.ink2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing,
            ],
          ],
        ),
      ),
    );
    if (GlassContainer.surfaceOf(context) == null) {
      row = GlassContainer(padding: EdgeInsets.zero, child: row);
    }
    if (onTap == null) return row;
    return AppPressable(
      onTap: onTap!,
      // Forward to Semantics so screen readers announce the picked state.
      selected: selected,
      child: row,
    );
  }
}

/// Rows in one panel (the spec section idiom: one panel per section), split
/// by inset hairlines. On a surface already it adds no panel of its own.
class PanelGroup extends StatelessWidget {
  const PanelGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            const Divider(
              height: 1,
              indent: AppSpacing.md,
              endIndent: AppSpacing.md,
            ),
          children[i],
        ],
      ],
    );
    if (GlassContainer.surfaceOf(context) != null) return rows;
    return GlassContainer(padding: EdgeInsets.zero, child: rows);
  }
}

/// A labelled row with a trailing [AppToggle]. When [locked], shows a
/// "Premium" label in the same trailing slot instead of the switch — keeping
/// every row in a list visually consistent (fixes the blocklist inconsistency).
class AppToggleTile extends StatelessWidget {
  const AppToggleTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.leading,
    this.enabled = true,
    this.locked = false,
    this.onLockedTap,
    this.selected,
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

  /// Marks the row as picked (see [GlassListTile.selected]).
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final trailing = locked
        ? const Pill(
            label: 'Premium',
            tone: AppTone.warning,
            icon: Icons.lock_outline,
          )
        : AppToggle(
            value: value,
            onChanged: onChanged,
            enabled: enabled,
            semanticLabel: title,
          );
    return GlassListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      selected: selected,
      onTap: locked ? onLockedTap : null,
    );
  }
}
