import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/design_system/tokens/app_motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:flutter/material.dart';

/// One option in a [GlassSegmented] — a label with an optional leading icon.
typedef GlassSegment = ({String label, IconData? icon});

/// The segmented control, an OPTION picker: a quiet pill track with a solid
/// option-base chip that slides to the pick (a short overshoot plus the spec
/// squish). No accent and no shadow.
///
/// State is never colour alone: besides the chip's shape, the picked label
/// goes ink-2 → ink and leads with a check.
///
/// Interaction: a tap selects; a horizontal drag anywhere on the track scrubs
/// the selection live under the finger (iOS-style). Each segment is one
/// focusable radio (focus ring, Enter/Space). Every motion is zero under
/// Reduce Motion.
///
/// Segments are always equal width — [expand] fills the parent, otherwise the
/// control hugs its widest label (for headers and toolbars).
class GlassSegmented extends StatelessWidget {
  const GlassSegmented({
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    this.height = 52,
    this.expand = true,
    super.key,
  });

  final List<GlassSegment> segments;

  /// The picked segment, or -1 for none (the chip fades out) — e.g. a
  /// quick-pick row whose value was set by another control.
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Track height. The default suits a full-width control; ~44 fits a card
  /// header.
  final double height;

  /// Stretch to the parent's width. `false` sizes to the widest segment.
  final bool expand;

  /// Gap between the track's edge and the chip.
  static const double _inset = 4;

  /// The picked segment's check glyph.
  static const double _check = 16;

  /// Live selection while a finger slides along the track. [dx] is local to
  /// this widget's box — the same box `context.size` reports, hugging or not.
  void _scrub(BuildContext context, double dx) {
    final n = segments.length;
    final width = context.size?.width ?? 0;
    if (width <= 0) return;
    final i = (dx / width * n).floor().clamp(0, n - 1);
    if (i == selectedIndex) return;
    AppHaptics.selection();
    onChanged(i);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final n = segments.length;
    final picked = selectedIndex.clamp(0, n - 1);
    final none = selectedIndex < 0;
    final style = height < 48 ? AppTypography.caption : AppTypography.label;
    // A card-header control is 44 tall by design, but its touch target still
    // has to reach the 48 dp floor (`AppSizes.minTapTarget`): the visual track
    // keeps [height] and the hit layer spans the box padded up to the floor.
    final reach = (AppSizes.minTapTarget - height).clamp(0.0, height) / 2;
    final slide = context.motion(AppDurations.chip);
    // Labels and the chip's fade follow the spec's `.dx-opt` (.3 s ease).
    final fade = context.motion(AppDurations.normal);

    final track = GlassContainer(
      surface: DxSurface.option,
      color: t.fillQuiet,
      borderRadius: AppRadius.pill,
      padding: const EdgeInsets.all(_inset),
      child: SizedBox(
        height: height - _inset * 2,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedAlign(
              duration: slide,
              curve: AppCurves.chip,
              alignment: n > 1
                  ? Alignment(-1 + 2 * picked / (n - 1), 0)
                  : Alignment.center,
              child: AnimatedOpacity(
                opacity: none ? 0 : 1,
                duration: fade,
                curve: AppCurves.glide,
                child: Squish(
                  trigger: selectedIndex,
                  child: FractionallySizedBox(
                    widthFactor: 1 / n,
                    heightFactor: 1,
                    child: const GlassContainer(
                      surface: DxSurface.option,
                      borderRadius: AppRadius.pill,
                      padding: EdgeInsets.zero,
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
            // Labels only — the taps and the semantics live on the hit layer
            // below, which is the one that reaches the 48 dp floor.
            Row(
              children: [
                for (var i = 0; i < n; i++)
                  Expanded(
                    child: _SegmentLabel(
                      segment: segments[i],
                      on: !none && i == picked,
                      style: style,
                      duration: fade,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    final control = GestureDetector(
      // Taps still land on the per-segment pressables below. A horizontal
      // drag anywhere on the track wins the arena past the touch slop and
      // scrubs the selection live; vertical moves still scroll the list.
      onHorizontalDragUpdate: (d) => _scrub(context, d.localPosition.dx),
      // A pointer-only convenience: without this the drag handler would
      // publish scrollLeft/scrollRight actions that merge into the enclosing
      // list item's node. Screen readers select via the segment buttons.
      excludeFromSemantics: true,
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: reach),
            child: ExcludeSemantics(child: track),
          ),
          // The hit layer: one full-height, opaque target per segment, so a
          // 44 dp header control still takes a 48 dp tap. Column edges differ
          // from the label columns by the track's 4 dp inset at most.
          Positioned.fill(
            child: Row(
              children: [
                for (var i = 0; i < n; i++)
                  Expanded(
                    child: AppPressable(
                      onTap: () {
                        AppHaptics.selection();
                        onChanged(i);
                      },
                      haptic: false,
                      pressedScale: 1,
                      radius: AppRadius.brPill,
                      semanticLabel: segments[i].label,
                      selected: !none && i == picked,
                      // One choice among several, not independent toggles.
                      inMutuallyExclusiveGroup: true,
                      child: const SizedBox.expand(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    // Equal-width segments either way: inside IntrinsicWidth the flex children
    // all settle on the widest segment's intrinsic width.
    return expand ? control : IntrinsicWidth(child: control);
  }
}

/// One segment's label: [GlassSegmented._check] (when [on]), the optional
/// icon and the text, tweening ink-2 → ink.
class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel({
    required this.segment,
    required this.on,
    required this.style,
    required this.duration,
  });

  final GlassSegment segment;
  final bool on;
  final TextStyle style;
  final Duration duration;

  /// What the check and its gap take; an unpicked label pads by half of it
  /// each side, so a hugging control keeps one width whichever is picked.
  static const double _checkRoom = GlassSegmented._check + AppSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: on ? 1.0 : 0.0),
      duration: duration,
      curve: AppCurves.glide,
      builder: (_, v, _) {
        final color = Color.lerp(t.ink2, t.ink, v);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (on) ...[
              Icon(
                Icons.check_rounded,
                size: GlassSegmented._check,
                color: color,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (segment.icon != null) ...[
              Icon(segment.icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.xs),
            ],
            // Flexible, so the ellipsis below can engage: at 2.0x text a
            // 360 dp screen's third of the track is narrower than "Medium".
            Flexible(
              child: Padding(
                // Breathing room so a label never touches the chip's rim
                // when the control hugs its content; kept to 8 so a third of
                // a 360 dp track still fits "System".
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs + (on ? 0 : _checkRoom / 2),
                ),
                child: Text(
                  segment.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style.copyWith(color: color),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A selectable OPTION chip (small option pickers, toggled categories, days):
/// quiet fill and an ink-2 label at rest; picked, the solid option base, a
/// leading check and an ink label. For 2–4 segment pickers prefer
/// [GlassSegmented].
class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.semanticLabel,
    this.momentary = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;

  /// True when the chip is a one-shot action rather than a toggle, so it has no
  /// selected state to announce or check to show. Without this a duration
  /// picker reads as "5 min, **not selected**, button" — a state the user can
  /// never change, on a chip that dismisses the sheet the moment it is tapped.
  final bool momentary;

  /// What a screen reader announces instead of [label]. Needed wherever the
  /// visible text is an abbreviation ("Mon") or where the chip is really a
  /// destructive action — a selected chip with a close icon reads as
  /// "Instagram, selected" but activating it REMOVES Instagram.
  final String? semanticLabel;

  static const double _check = 16;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final checked = selected && !momentary;
    // An unpicked toggle reserves the check's room (half each side), so
    // picking one never reflows its row.
    final reserve = momentary || checked ? 0.0 : (_check + AppSpacing.xxs) / 2;
    return AppPressable(
      onTap: onSelected,
      radius: AppRadius.brPill,
      selected: momentary ? null : selected,
      semanticLabel: semanticLabel,
      minTapTarget: AppSizes.minTapTargetSquare,
      // Selection cross-fades on the same clock as `AppToggle` instead of
      // snapping. The tween has no `begin`, so a chip mounted already-selected
      // renders its end state with no first-frame fade.
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: selected ? 1.0 : 0.0),
        duration: context.motion(AppDurations.fast),
        curve: AppCurves.standard,
        builder: (context, v, _) {
          final ink = Color.lerp(t.ink2, t.ink, v);
          return GlassContainer(
            surface: DxSurface.option,
            color: Color.lerp(t.fillQuiet, t.optionBase, v),
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md + reserve,
              vertical: AppSpacing.xs,
            ),
            borderRadius: AppRadius.pill,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (checked) ...[
                  Icon(Icons.check_rounded, size: _check, color: t.ink),
                  const SizedBox(width: AppSpacing.xxs),
                ],
                if (icon != null) ...[
                  Icon(icon, size: 16, color: ink),
                  const SizedBox(width: AppSpacing.xxs),
                ],
                Text(label, style: AppTypography.label.copyWith(color: ink)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Two rows of chips that scroll together as one horizontal rail. [leading]
/// opens the first row (a quick-pick, a header pill) and [trailing] closes the
/// second (an "add" action); [chips] split evenly, first half on top, so a
/// behaviour-ordered list reads top row = the usual suspects. Used by the rule
/// editor's categories and the web blocker's popular sites.
class ChipRail extends StatelessWidget {
  const ChipRail({
    required this.chips,
    this.leading,
    this.trailing,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final List<Widget> chips;
  final Widget? leading;
  final Widget? trailing;

  /// Inset of the scrolling content. A list that lets the rail bleed off the
  /// screen edge passes its trailing gutter here; one that already pads its
  /// children has a gutter and passes nothing — the widget must not bake one
  /// caller's edge into every rail.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final half = chips.length ~/ 2;
    Widget pad(Widget chip) => Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: chip,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) pad(leading!),
              for (final c in chips.take(half)) pad(c),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            children: [
              for (final c in chips.skip(half)) pad(c),
              if (trailing != null) pad(trailing!),
            ],
          ),
        ],
      ),
    );
  }
}
