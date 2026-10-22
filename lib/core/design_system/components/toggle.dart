import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/design_system/tokens/app_motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:flutter/material.dart';

/// The on/off switch: a 48×28 track, status-on when on and the quiet fill
/// with a hairline rim when off, with a 20 px thumb (knob on, ink-3 off). No
/// accent and no glow. The track colour and the thumb's side carry the state:
/// the Dark knob on status-on is only 1.55:1, so the thumb alone never does.
class AppToggle extends StatelessWidget {
  const AppToggle({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.label,
    this.semanticLabel,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  /// Optional inline label rendered to the left of the switch.
  final String? label;

  /// Screen-reader name for the switch when no visible [label] is wanted —
  /// e.g. `AppToggleTile` passes its title so TalkBack doesn't announce a
  /// nameless "switch".
  final String? semanticLabel;

  static const double _trackW = 48;
  static const double _trackH = 28;
  static const double _thumb = 20;

  /// Gap between the track's 1 px rim and the thumb.
  static const double _inset = 3;

  @override
  Widget build(BuildContext context) {
    final live = enabled && onChanged != null;
    final t = context.tokens;
    final duration = context.motion(AppDurations.fast);

    // One tween drives the track fill, its rim, the thumb's offset and its
    // colour, so every part of the switch settles together.
    Widget visual = TweenAnimationBuilder<double>(
      tween: Tween(begin: value ? 1 : 0, end: value ? 1 : 0),
      duration: duration,
      curve: AppCurves.standard,
      builder: (context, v, _) => Container(
        width: _trackW,
        height: _trackH,
        padding: const EdgeInsets.all(_inset),
        decoration: BoxDecoration(
          borderRadius: AppRadius.brPill,
          color: Color.lerp(t.fillQuiet, t.statusOn, v),
          border: Border.all(color: Color.lerp(t.hairline, t.statusOn, v)!),
        ),
        child: Align(
          alignment: Alignment(-1 + 2 * v, 0),
          child: Container(
            width: _thumb,
            height: _thumb,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(t.ink3, t.knob, v),
            ),
          ),
        ),
      ),
    );
    // Always wrapped, so going disabled fades rather than snapping.
    visual = AnimatedOpacity(
      opacity: live ? 1 : 0.45,
      duration: duration,
      child: visual,
    );

    final hasLabel = label != null;
    return MergeSemantics(
      child: Semantics(
        toggled: value,
        child: AppPressable(
          onTap: () => _handle(!value),
          enabled: live,
          haptic: false, // selection click, not the default light impact
          pressedScale: hasLabel ? 0.98 : 0.92,
          radius: AppRadius.brPill,
          semanticLabel: semanticLabel ?? label,
          // The labelled row keeps the 48 dp floor too.
          minTapTarget: hasLabel
              ? const Size(0, AppSizes.minTapTarget)
              : AppSizes.minTapTargetSquare,
          child: hasLabel ? _row(context, visual) : visual,
        ),
      ),
    );
  }

  void _handle(bool v) {
    AppHaptics.selection();
    onChanged?.call(v);
  }

  Widget _row(BuildContext context, Widget toggle) => Row(
    children: [
      Expanded(
        child: Text(
          label!,
          style: AppTypography.label.copyWith(color: context.tokens.ink),
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      toggle,
    ],
  );
}
