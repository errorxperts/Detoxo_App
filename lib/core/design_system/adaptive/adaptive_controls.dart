import 'package:cupertino_native/cupertino_native.dart';
import 'package:detoxo/core/design_system/adaptive/platform_adaptive.dart';
import 'package:flutter/material.dart';

/// This is the ONLY file that imports `cupertino_native`. Every adaptive
/// control renders a native `CN*` widget on iOS/macOS and a hand-built Material
/// widget on Android (true Material, not the package's Cupertino fallback).
/// Native controls do NOT inherit `ColorScheme`, so we always feed a token
/// colour into their `color`/`tint`.

/// Native slider on iOS, Material `Slider` on Android.
class AdaptiveSlider extends StatelessWidget {
  const AdaptiveSlider({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.enabled = true,
    this.color,
    this.semanticFormatter,
    super.key,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final bool enabled;

  /// Active-track tint. Defaults to the live (background-adaptive) brand accent.
  final Color? color;

  /// What a screen reader announces for a value — pass the same formatter the
  /// visible value label uses ("56 dp", "120%"), else TalkBack reads a bare
  /// percentage of the track that matches nothing on screen.
  final String Function(double value)? semanticFormatter;

  @override
  Widget build(BuildContext context) {
    final on = enabled && onChanged != null;
    final tint = color ?? Theme.of(context).colorScheme.secondary;
    if (PlatformAdaptive.useCupertino) {
      final step = divisions != null && divisions! > 0
          ? (max - min) / divisions!
          : null;
      return CNSlider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        step: step,
        enabled: on,
        color: tint,
        onChanged: on ? onChanged! : (_) {},
      );
    }
    return Slider(
      value: value.clamp(min, max),
      min: min,
      max: max,
      divisions: divisions,
      activeColor: tint,
      semanticFormatterCallback: semanticFormatter,
      onChanged: on ? onChanged : null,
    );
  }
}
