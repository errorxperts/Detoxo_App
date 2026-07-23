import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

/// Glass-tinted appearance for the circular duration ring, shared by the
/// interactive Pause picker and the read-only hero countdown so they look
/// identical. [interactive] shows a draggable handle; the countdown hides it.
CircularSliderAppearance pauseSliderAppearance(
  BuildContext context, {
  required bool interactive,
  double size = 200,
}) {
  // startAngle 150° / angleRange 240° (the package defaults) give the open-bottom
  // gauge look we want, so they're left implicit.
  final accent = Theme.of(context).colorScheme.secondary;
  return CircularSliderAppearance(
    size: size,
    // The countdown is value-driven each tick, so let it animate the sweep; the
    // picker is drag-driven and should track the finger without easing.
    animationEnabled: !interactive,
    customWidths: CustomSliderWidths(
      trackWidth: 8,
      progressBarWidth: 12,
      handlerSize: interactive ? 8 : 0,
    ),
    customColors: CustomSliderColors(
      trackColor: context.glass.border,
      progressBarColors: [
        accent,
        AppColors.seed,
        accent,
      ],
      dotColor: interactive ? Colors.white : Colors.transparent,
      hideShadow: true,
    ),
  );
}

/// A read-only [SleekCircularSlider] rendered as a countdown gauge (no drag, no
/// handle). Used by the dashboard hero to show a live Pause / Conscious session
/// with the same ring chrome the picker uses. [center] holds the live digits.
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    required this.progress,
    required this.center,
    this.size = 240,
    super.key,
  });

  /// 0..1 fill (remaining fraction for Pause, banked fraction for Conscious).
  final double progress;
  final Widget center;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SleekCircularSlider(
      max: 1,
      initialValue: progress.clamp(0.0, 1.0),
      appearance: pauseSliderAppearance(context, interactive: false, size: size),
      innerWidget: (_) => Center(child: center),
    );
  }
}
