import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:flutter/material.dart';

/// A section eyebrow (spec `.dx-eyebrow`): the uppercase [label] in caption
/// with 1.6 px tracking, ink-2, above the one panel of its section, with an
/// optional right-aligned [note] in subhead. A heading to a screen reader, so
/// TalkBack can jump group to group down a long scroll.
///
/// Carries the list's vertical rhythm itself — `section` 32 above, 12 below —
/// so a screen places nothing between one section and the next.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.label, {this.note, super.key});

  final String label;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final ink2 = context.tokens.ink2;
    return Padding(
      padding: const EdgeInsets.only(
        left: 4,
        top: AppSpacing.section,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                label.toUpperCase(),
                style: AppTypography.eyebrow.copyWith(color: ink2),
              ),
            ),
          ),
          if (note != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                note!,
                textAlign: TextAlign.end,
                style: AppTypography.subhead.copyWith(color: ink2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
