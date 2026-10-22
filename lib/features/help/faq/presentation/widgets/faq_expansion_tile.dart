import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/help/faq/domain/entities/faq_entry.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';

/// A flat Q/A row for a `PanelGroup`: the question in label / ink with an
/// ink-3 chevron that turns to point up, and the answer in subhead / ink-2
/// opening below it (the spec's `.dx-detail`: .5 s, clipped while it grows).
/// No motion under Reduce Motion.
class FaqExpansionTile extends StatefulWidget {
  const FaqExpansionTile({required this.entry, super.key});

  final FaqEntry entry;

  @override
  State<FaqExpansionTile> createState() => _FaqExpansionTileState();
}

class _FaqExpansionTileState extends State<FaqExpansionTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final duration = context.motion(AppDurations.detail);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // One node: the question, a button, expanded or collapsed.
        MergeSemantics(
          child: Semantics(
            expanded: _open,
            child: AppPressable(
              onTap: () => setState(() => _open = !_open),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.entry.question,
                          style: AppTypography.label.copyWith(color: t.ink),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AnimatedRotation(
                        // A right chevron turned down; open, turned up.
                        turns: _open ? 0.75 : 0.25,
                        duration: duration,
                        curve: AppCurves.detail,
                        child: Glyph(
                          Assets.svg.chevronRight,
                          size: 18,
                          color: t.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween(end: _open ? 1 : 0),
          duration: duration,
          curve: AppCurves.detail,
          // Closed, the answer leaves the tree, so TalkBack skips it too.
          builder: (context, v, answer) => v == 0
              ? const SizedBox.shrink()
              : ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: v,
                    child: answer,
                  ),
                ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Text(
              widget.entry.answer,
              style: AppTypography.subhead.copyWith(color: t.ink2),
            ),
          ),
        ),
      ],
    );
  }
}
