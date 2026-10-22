import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';

export 'package:detoxo/core/design_system/components/feedback.dart'
    show EmptyState;
export 'package:detoxo/core/design_system/components/section_header.dart'
    show SectionHeader;

/// Shared composites kept at their original names/APIs so the screens that
/// already use them keep compiling — now drawn in the Frozen Glass idiom.
/// New screens should prefer the design-system components directly
/// (`PanelGroup`, `GlassListTile`, `SectionHeader`, `PrimaryButton`, …).

// EmptyState and SectionHeader now live in the design system
// (components/feedback.dart, components/section_header.dart) and are re-exported
// above so existing `common_widgets.dart` importers keep compiling.

/// A labelled navigation row: a [GlassListTile] with an ink-2 [icon]. Put a
/// run of them in a `PanelGroup`; [trailing] replaces the row's chevron.
class FeatureTile extends StatelessWidget {
  const FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GlassListTile(
      onTap: onTap,
      leading: Icon(icon, size: 24, color: context.tokens.ink2),
      title: title,
      subtitle: subtitle,
      trailing: trailing,
    );
  }
}

/// Formats a [Duration] as mm:ss (or h:mm:ss).
String formatCountdown(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// A muted inline hint shown when a section is empty.
class InlineHint extends StatelessWidget {
  const InlineHint({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.tokens.ink2),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTypography.subhead.copyWith(color: context.tokens.ink2),
            ),
          ),
        ],
      ),
    );
  }
}
