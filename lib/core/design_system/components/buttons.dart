import 'package:flutter/material.dart';

import 'package:detoxo/core/design_system/adaptive/adaptive_controls.dart';
import 'package:detoxo/core/design_system/tokens/app_colors.dart';

/// Primary call-to-action. Filled & brand-tinted (native CNButton on iOS).
/// `expand: true` makes it full-width (the old `FullWidthButton` behaviour).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.expand = false,
    this.icon,
    this.tint = AppColors.seed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final IconData? icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => AdaptiveButton(
        label: label,
        onPressed: onPressed,
        variant: AdaptiveButtonVariant.filled,
        tint: tint,
        expand: expand,
        icon: icon,
      );
}

/// Lower-emphasis tonal button (e.g. "Restore purchases", "Resume now").
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.expand = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => AdaptiveButton(
        label: label,
        onPressed: onPressed,
        variant: AdaptiveButtonVariant.tinted,
        expand: expand,
        icon: icon,
      );
}

/// Text-only, lowest emphasis (e.g. "Skip", "Maybe later").
class GhostButton extends StatelessWidget {
  const GhostButton({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => AdaptiveButton(
        label: label,
        onPressed: onPressed,
        variant: AdaptiveButtonVariant.plain,
      );
}
