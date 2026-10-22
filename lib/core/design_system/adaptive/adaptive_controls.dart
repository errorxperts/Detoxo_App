import 'package:cupertino_native/cupertino_native.dart';
import 'package:detoxo/core/design_system/adaptive/platform_adaptive.dart';
import 'package:detoxo/core/design_system/foundations/motion.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
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

/// Visual emphasis for [AdaptiveButton].
enum AdaptiveButtonVariant { filled, tinted, plain }

/// Native `CNButton` on iOS, Material button on Android. Higher-level CTAs use
/// the `PrimaryButton` / `SecondaryButton` / `GhostButton` wrappers.
class AdaptiveButton extends StatelessWidget {
  const AdaptiveButton({
    required this.label,
    required this.onPressed,
    this.variant = AdaptiveButtonVariant.filled,
    this.tint,
    this.expand = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AdaptiveButtonVariant variant;

  /// Defaults to the spec `brand.main`.
  final Color? tint;
  final bool expand;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tint = this.tint ?? context.tokens.brand.main;
    Widget button;
    if (PlatformAdaptive.useCupertino) {
      button = CNButton(
        label: label,
        tint: tint,
        height: AppSizes.controlHeight,
        shrinkWrap: !expand,
        style: switch (variant) {
          AdaptiveButtonVariant.filled => CNButtonStyle.glass,
          AdaptiveButtonVariant.tinted => CNButtonStyle.tinted,
          AdaptiveButtonVariant.plain => CNButtonStyle.plain,
        },
        onPressed: onPressed,
      );
    } else {
      final child = icon == null ? Text(label) : null;
      // Min HEIGHT of 44 for a comfortable tap target, with Material's default
      // min width (64). NB: `Size.fromHeight(44)` is `Size(infinity, 44)` —
      // its infinite min width crashes in any unbounded-width parent (e.g. a
      // dialog actions Row). Full-width is expressed via `expand` below, not here.
      const minSize = Size(64, AppSizes.controlHeight);
      button = switch (variant) {
        AdaptiveButtonVariant.filled =>
          icon == null
              ? FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: tint,
                    minimumSize: minSize,
                  ),
                  child: Text(label),
                )
              : FilledButton.icon(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: tint,
                    minimumSize: minSize,
                  ),
                  icon: Icon(icon),
                  label: Text(label),
                ),
        AdaptiveButtonVariant.tinted => FilledButton.tonal(
          onPressed: onPressed,
          style: FilledButton.styleFrom(minimumSize: minSize),
          child: child ?? Text(label),
        ),
        AdaptiveButtonVariant.plain => TextButton(
          onPressed: onPressed,
          child: child ?? Text(label),
        ),
      };
    }
    final sized = expand
        ? SizedBox(width: double.infinity, child: button)
        : button;
    // iOS CNButton animates natively; add a Material press-squish on Android.
    return PlatformAdaptive.useCupertino ? sized : PressScale(child: sized);
  }
}
