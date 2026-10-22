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

/// The spec MODE CARD: one solid card holding every blocking mode, in the
/// live accent.
///
/// - Card: `optionBase` mixed with the accent at `kOption` (Dark's base is
///   the ring's centre colour); no shadow, gradient or border.
/// - Chip: behind the pick, the accent at `kChip`; it slides on the chip
///   curve with a [Squish] and fades out when [selectedIndex] is null.
/// - Options: a 34 px accent-tinted [Icon3d] (vivid and 1.08 when picked,
///   soft and .94 otherwise, .88 while pressed) over a verbatim `caption`
///   label, ink-2 idle and accent text (Light) or ink (Dark) when picked.
/// - Description: with a pick and a [title], a hairline and one row (accent
///   dot, [title], [detail]) open under the options.
///
/// Every option reports its tap, the picked one too: the caller decides what
/// a repeat tap means. Each is one focusable radio in a "Blocking mode"
/// group. Every motion is zero under Reduce Motion.
class ModeCard extends StatelessWidget {
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

  static const double _row = 72;

  Widget _decorate(int i, Widget option) =>
      decorateOption?.call(i, option) ?? option;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accent = context.accent;
    final n = options.length;
    final picked = selectedIndex;
    final title = this.title;

    return GlassContainer(
      surface: DxSurface.option,
      color: Color.lerp(t.optionBase, accent.main, t.kOption),
      padding: const EdgeInsets.all(AppSpacing.inset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            explicitChildNodes: true,
            label: 'Blocking mode',
            child: SizedBox(
              height: _row,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedAlign(
                    duration: context.motion(AppDurations.chip),
                    curve: AppCurves.chip,
                    alignment: Alignment(
                      n > 1 ? -1 + 2 * (picked ?? 0) / (n - 1) : 0,
                      0,
                    ),
                    child: AnimatedOpacity(
                      opacity: picked == null ? 0 : 1,
                      // `.dx-chip` fades over .3 s ease.
                      duration: context.motion(AppDurations.normal),
                      curve: AppCurves.glide,
                      child: Squish(
                        trigger: picked,
                        child: FractionallySizedBox(
                          widthFactor: 1 / n,
                          heightFactor: 1,
                          child: GlassContainer(
                            surface: DxSurface.option,
                            color: Color.lerp(
                              t.optionBase,
                              accent.main,
                              t.kChip,
                            ),
                            borderRadius: AppRadius.chip,
                            padding: EdgeInsets.zero,
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < n; i++)
                        Expanded(
                          child: _decorate(
                            i,
                            _ModeOptionButton(
                              option: options[i],
                              on: i == picked,
                              onTap: () => onSelected(i),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: context.motion(AppDurations.detail),
            curve: AppCurves.detail,
            alignment: Alignment.topCenter,
            child: picked == null || title == null
                ? const SizedBox(width: double.infinity)
                : _Description(title: title, detail: detail),
          ),
        ],
      ),
    );
  }
}

/// One option: the tinted icon over its label, as one radio.
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
              // ponytail: the vivid/soft filter snaps while the scale pops;
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
