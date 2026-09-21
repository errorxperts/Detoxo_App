import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/design_system/theme/app_theme.dart';
import 'package:detoxo/core/design_system/tokens/app_motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:flutter/material.dart';

/// One option in a [GlassSegmented] — a label with an optional leading icon.
typedef GlassSegment = ({String label, IconData? icon});

/// The liquid-glass segmented control: a frosted stadium track lifted by a soft
/// depth shadow, with an accent-lit pill that glides between options.
///
/// Both the track and the sliding pill are [GlassContainer]s, so the frost, the
/// sheen and the specular liquid-glass rim are the same ones every other
/// surface uses — the only thing this widget adds is the outer shadow (glass is
/// otherwise shadowless) that lifts a control off the background, and the pill's
/// motion. The pill blurs nothing: the track's backdrop filter already frosts
/// what's behind it, so a nested filter would cost a `saveLayer` for nothing.
///
/// Interaction: a tap selects on release; a horizontal drag anywhere on the
/// track scrubs the selection live under the finger (iOS-style); while a finger
/// is down the pill swells and brightens. Labels light up on the same clock as
/// the pill's slide, and every motion collapses to zero under reduce-motion.
///
/// Segments are always equal width — [expand] fills the parent, otherwise the
/// control hugs its widest label (for headers and toolbars).
class GlassSegmented extends StatefulWidget {
  const GlassSegmented({
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    this.height = 52,
    this.expand = true,
    super.key,
  });

  final List<GlassSegment> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Track height. The default suits a full-width control; ~44 fits a card
  /// header.
  final double height;

  /// Stretch to the parent's width. `false` sizes to the widest segment.
  final bool expand;

  /// Gap between the track's edge and the sliding pill.
  static const double _inset = 4;

  @override
  State<GlassSegmented> createState() => _GlassSegmentedState();
}

class _GlassSegmentedState extends State<GlassSegmented> {
  /// Finger down anywhere on the control: the pill swells and brightens.
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  /// Live selection while a finger slides along the track. [dx] is local to
  /// this widget's box — the same box `context.size` reports, hugging or not.
  void _scrub(double dx) {
    final n = widget.segments.length;
    final width = context.size?.width ?? 0;
    if (width <= 0) return;
    final i = (dx / width * n).floor().clamp(0, n - 1);
    if (i == widget.selectedIndex) return;
    AppHaptics.selection();
    widget.onChanged(i);
  }

  @override
  Widget build(BuildContext context) {
    final segments = widget.segments;
    final height = widget.height;
    final glass = context.glass;
    final accent = Theme.of(context).colorScheme.secondary;
    final text = Theme.of(context).textTheme;
    final selected = widget.selectedIndex.clamp(0, segments.length - 1);
    final compact = height < 48;
    // A card-header control is 44 tall by design, but its touch target still
    // has to reach the 48 dp floor (`AppSizes.minTapTarget`): the visual track
    // keeps [height] and the hit layer spans the box padded up to the floor.
    final reach = (AppSizes.minTapTarget - height).clamp(0.0, height) / 2;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final slide = reduceMotion ? Duration.zero : AppDurations.normal;
    final press = reduceMotion ? Duration.zero : AppDurations.fast;

    final track = DecoratedBox(
      // The one place glass carries a drop shadow: a control needs to read as
      // lifted off the background, not printed onto it.
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        shadows: [
          BoxShadow(
            color: glass.shadow,
            blurRadius: 20,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: GlassContainer(
        borderRadius: AppRadius.pill,
        padding: const EdgeInsets.all(GlassSegmented._inset),
        child: SizedBox(
          height: height - GlassSegmented._inset * 2,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedAlign(
                duration: slide,
                curve: AppCurves.fluid,
                alignment: segments.length > 1
                    ? Alignment(-1 + 2 * selected / (segments.length - 1), 0)
                    : Alignment.center,
                // Swells under a finger, like a key lifting to meet it.
                child: AnimatedScale(
                  scale: _pressed ? 1.04 : 1,
                  duration: press,
                  curve: AppCurves.standard,
                  child: FractionallySizedBox(
                    widthFactor: 1 / segments.length,
                    heightFactor: 1,
                    child: GlassContainer(
                      enableBlur: false,
                      borderRadius: AppRadius.pill,
                      padding: EdgeInsets.zero,
                      tintTop: accent.withValues(alpha: _pressed ? 0.42 : 0.30),
                      tintBottom: accent.withValues(alpha: 0.12),
                      borderColor: accent.withValues(alpha: 0.55),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              // Labels only — the taps and the semantics live on the hit layer
              // below, which is the one that reaches the 48 dp floor. Colour
              // and weight tween on the pill's clock, so a label lights up as
              // the pill arrives instead of snapping ahead of it.
              Row(
                children: [
                  for (var i = 0; i < segments.length; i++)
                    Expanded(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: i == selected ? 1.0 : 0.0),
                        duration: slide,
                        curve: AppCurves.fluid,
                        builder: (_, t, _) {
                          final color = Color.lerp(
                            glass.onGlassMuted,
                            accent,
                            t,
                          );
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (segments[i].icon != null) ...[
                                Icon(segments[i].icon, size: 18, color: color),
                                const SizedBox(width: AppSpacing.xs),
                              ],
                              Padding(
                                // Breathing room so a label never touches the
                                // pill's rim when the control hugs its content.
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                ),
                                child: Text(
                                  segments[i].label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      (compact
                                              ? text.labelMedium
                                              : text.labelLarge)
                                          ?.copyWith(
                                            fontWeight: t > 0.5
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: color,
                                          ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final control = Listener(
      // Raw pointer events, like [PressScale]: no recognizer, so the pressed
      // state never enters the gesture arena.
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: GestureDetector(
        // Taps still land on the per-segment detectors below. A horizontal
        // drag anywhere on the track wins the arena past the touch slop and
        // scrubs the selection live; vertical moves still scroll the list.
        onHorizontalDragUpdate: (d) => _scrub(d.localPosition.dx),
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
                  for (var i = 0; i < segments.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == selected,
                        // One choice among several, not independent toggles.
                        inMutuallyExclusiveGroup: true,
                        label: segments[i].label,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            AppHaptics.selection();
                            widget.onChanged(i);
                          },
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Equal-width segments either way: inside IntrinsicWidth the flex children
    // all settle on the widest segment's intrinsic width.
    return widget.expand ? control : IntrinsicWidth(child: control);
  }
}

/// A selectable glass chip (e.g. small option pickers). For 2–4 segment
/// pickers prefer `AdaptiveSegmentedControl`.
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
  /// selected state to announce. Without this a duration picker reads as
  /// "5 min, **not selected**, button" — a state the user can never change, on
  /// a chip that dismisses the sheet the moment it is tapped.
  final bool momentary;

  /// What a screen reader announces instead of [label]. Needed wherever the
  /// visible text is an abbreviation ("Mon") or where the chip is really a
  /// destructive action — a selected chip with a close icon reads as
  /// "Instagram, selected" but activating it REMOVES Instagram.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accent = Theme.of(context).colorScheme.secondary;
    return AppPressable(
      onTap: onSelected,
      pressedScale: 0.94,
      selected: momentary ? null : selected,
      semanticLabel: semanticLabel,
      minTapTarget: const Size(0, AppSizes.minTapTarget),
      child: GlassContainer(
        enableBlur: false,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        borderRadius: AppRadius.pill,
        tintTop: selected ? accent.withValues(alpha: 0.28) : null,
        tintBottom: selected ? accent.withValues(alpha: 0.14) : null,
        borderColor: selected ? accent.withValues(alpha: 0.6) : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16),
              const SizedBox(width: AppSpacing.xxs),
            ],
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
