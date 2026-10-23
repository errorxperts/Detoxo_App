import 'dart:async';
import 'dart:math' as math;

import 'package:detoxo/core/design_system/components/dx_icons.dart';
import 'package:detoxo/core/design_system/foundations/accent.dart';
import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/design_system/tokens/app_motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';

/// One [ModeCard] option: a spec 3D mode icon and its Title Case label.
typedef ModeOption = ({AssetGenImage icon, String label});

/// The spec MODE CARD: one solid card holding every blocking mode; only the
/// pick wears the live accent.
///
/// - Card: plain `optionBase` (Dark's base is the ring's centre colour); no
///   shadow, gradient or border.
/// - Options: 76 wide (wider when the card has room for all), 8 apart, in a
///   horizontal scroll clipped to the card's inner radius. A new pick
///   scrolls into view, as does one past the edge once mounted.
/// - Chip: behind the pick, the accent at `kChip`; it slides on the chip
///   curve with a [Squish] and fades out when [selectedIndex] is null.
/// - Each option: a 34 px [Icon3d] (accent and vivid at 1.08 when picked,
///   neutral grey at .94 otherwise, .88 while pressed) over a verbatim
///   `caption` label, ink-2 idle and accent text (Light) or ink (Dark) when
///   picked.
/// - Description: with a pick and a [title], a hairline and one row (accent
///   dot, [title], [detail]) open under the options.
///
/// Every option reports its tap, the picked one too: the caller decides what
/// a repeat tap means. Each is one focusable radio in a "Blocking mode"
/// group. Every motion is zero under Reduce Motion.
class ModeCard extends StatefulWidget {
  const ModeCard({
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    this.title,
    this.detail,
    this.decorateOption,
    super.key,
  });

  final List<ModeOption> options;

  /// The picked option, or null for none (chip and description hidden).
  final int? selectedIndex;
  final ValueChanged<int> onSelected;
  final String? title;
  final String? detail;

  /// Wraps each option, e.g. in a tour showcase target.
  final Widget Function(int index, Widget option)? decorateOption;

  @override
  State<ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<ModeCard> {
  static const double _row = 72;
  static const double _option = 76;
  static const double _gap = AppSpacing.inset;

  final _scroll = ScrollController();

  /// [_option], or wider to fill a card with room for all [n].
  static double _width(double viewport, int n) =>
      math.max(_option, (viewport - (n - 1) * _gap) / n);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(jump: true));
  }

  @override
  void didUpdateWidget(ModeCard old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls the least that shows the whole pick.
  void _reveal({bool jump = false}) {
    final i = widget.selectedIndex;
    if (!mounted || i == null || !_scroll.hasClients) return;
    final p = _scroll.position;
    final view = p.viewportDimension;
    final w = _width(view, widget.options.length);
    final left = i * (w + _gap);
    final to = math
        .min(left, math.max(p.pixels, left + w - view))
        .clamp(p.minScrollExtent, p.maxScrollExtent);
    if (to == p.pixels) return;
    final d = context.motion(AppDurations.chip);
    if (jump || d == Duration.zero) {
      _scroll.jumpTo(to);
    } else {
      unawaited(_scroll.animateTo(to, duration: d, curve: AppCurves.detail));
    }
  }

  Widget _decorate(int i, Widget option) =>
      widget.decorateOption?.call(i, option) ?? option;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final n = widget.options.length;
    final picked = widget.selectedIndex;
    final title = widget.title;

    return GlassContainer(
      surface: DxSurface.option,
      padding: const EdgeInsets.all(AppSpacing.inset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            explicitChildNodes: true,
            label: 'Blocking mode',
            child: ClipRRect(
              clipper: const _InnerClip(),
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = _width(box.maxWidth, n);
                  return SingleChildScrollView(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    // [_InnerClip] clips, a focus ring's reach wider.
                    clipBehavior: Clip.none,
                    child: SizedBox(
                      width: n * w + (n - 1) * _gap,
                      height: _row,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AnimatedPositioned(
                            duration: context.motion(AppDurations.chip),
                            curve: AppCurves.chip,
                            left: (picked ?? 0) * (w + _gap),
                            top: 0,
                            bottom: 0,
                            width: w,
                            child: AnimatedOpacity(
                              opacity: picked == null ? 0 : 1,
                              // `.dx-chip` fades over .3 s ease.
                              duration: context.motion(AppDurations.normal),
                              curve: AppCurves.glide,
                              child: Squish(
                                trigger: picked,
                                child: GlassContainer(
                                  surface: DxSurface.option,
                                  color: Color.lerp(
                                    t.optionBase,
                                    context.accent.main,
                                    t.kChip,
                                  ),
                                  borderRadius: AppRadius.chip,
                                  padding: EdgeInsets.zero,
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
                          Row(
                            spacing: _gap,
                            children: [
                              for (var i = 0; i < n; i++)
                                SizedBox(
                                  width: w,
                                  child: _decorate(
                                    i,
                                    _ModeOptionButton(
                                      option: widget.options[i],
                                      on: i == picked,
                                      onTap: () => widget.onSelected(i),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          AnimatedSize(
            duration: context.motion(AppDurations.detail),
            curve: AppCurves.detail,
            alignment: Alignment.topCenter,
            child: picked == null || title == null
                ? const SizedBox(width: double.infinity)
                : _Description(title: title, detail: widget.detail),
          ),
        ],
      ),
    );
  }
}

/// The options' clip: the card's inner radius (the chip's), grown by the
/// reach of an option's focus ring so no ring is cut.
class _InnerClip extends CustomClipper<RRect> {
  const _InnerClip();

  /// [FocusRing]'s 2 px stroke centred 4 px out.
  static const double _ringReach = 5;

  @override
  RRect getClip(Size size) => RRect.fromRectAndRadius(
    Offset.zero & size,
    const Radius.circular(AppRadius.chip),
  ).inflate(_ringReach);

  @override
  bool shouldReclip(_InnerClip old) => false;
}

/// One option: the icon over its label, as one radio.
class _ModeOptionButton extends StatelessWidget {
  const _ModeOptionButton({
    required this.option,
    required this.on,
    required this.onTap,
  });

  final ModeOption option;
  final bool on;
  final VoidCallback onTap;

  static const double _icon = 34;

  /// Icon to label (`.dx-opt` gap).
  static const double _gap = 5;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final picked = t.brightness == Brightness.dark
        ? t.ink
        : t.accentText(context.accent);
    return AppPressable(
      onTap: onTap,
      // Only the icon reacts to a press.
      pressedScale: 1,
      radius: const BorderRadius.all(Radius.circular(AppRadius.chip)),
      selected: on,
      inMutuallyExclusiveGroup: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PressScale(
            pressedScale: 0.88,
            child: AnimatedScale(
              scale: on ? 1.08 : 0.94,
              duration: context.motion(AppDurations.chip),
              curve: AppCurves.press,
              // ponytail: the vivid/grey filter snaps while the scale pops;
              // tween it once Icon3d takes a fractional `selected`.
              child: Icon3d(
                option.icon,
                size: _icon,
                accentTint: true,
                selected: on,
              ),
            ),
          ),
          const SizedBox(height: _gap),
          TweenAnimationBuilder<double>(
            tween: Tween(end: on ? 1.0 : 0.0),
            // `.dx-opt` colour: .3 s ease.
            duration: context.motion(AppDurations.normal),
            curve: AppCurves.glide,
            builder: (_, v, _) => FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                option.label,
                maxLines: 1,
                style: AppTypography.caption.copyWith(
                  color: Color.lerp(t.ink2, picked, v),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The open description: a hairline, then the accent dot beside the title
/// and detail.
class _Description extends StatelessWidget {
  const _Description({required this.title, this.detail});

  final String title;
  final String? detail;

  /// Hairline above (`.dx-rule` margin-top) and title to detail.
  static const double _ruleTop = 6;
  static const double _lineGap = 1;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final detail = this.detail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: _ruleTop),
          child: Divider(
            height: 1,
            indent: AppSpacing.sm,
            endIndent: AppSpacing.sm,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              StatusDot(color: context.accent.main),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.label.copyWith(color: t.ink),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: _lineGap),
                      Text(
                        detail,
                        style: AppTypography.subhead.copyWith(color: t.ink2),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
