import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/help/faq/domain/entities/faq_entry.dart';
import 'package:flutter/material.dart';

/// A compact glass Q/A row that expands to reveal its answer. The tile's
/// `shape`/`collapsedShape` round the header's ink splash to the card's radius so
/// the ripple never bleeds past the rounded corners, and drop the default
/// top/bottom expansion dividers.
class FaqExpansionTile extends StatelessWidget {
  const FaqExpansionTile({required this.entry, super.key});

  final FaqEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: GlassContainer(
        enableBlur: false,
        borderRadius: AppRadius.md,
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          // Matching shapes clip the ink splash to the card and remove the
          // built-in divider lines, in both states.
          shape: shape,
          collapsedShape: shape,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xxs,
          ),
          minTileHeight: 48,
          expandedAlignment: Alignment.topLeft,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          iconColor: Theme.of(context).colorScheme.secondary,
          collapsedIconColor: context.glass.onGlassMuted,
          title: Text(
            entry.question,
            style: text.bodyMedium?.copyWith(
              color: context.glass.onGlass,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          children: [
            Text(
              entry.answer,
              style: text.bodySmall?.copyWith(
                color: context.glass.onGlassMuted,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
