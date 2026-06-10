import 'package:detoxo/core/design_system/tokens/app_colors.dart';
import 'package:flutter/material.dart';

/// On a dark mesh, "elevation" reads as a soft colored glow, not a drop shadow.
abstract final class AppShadows {
  /// Ambient lift under glass cards on dark.
  static const List<BoxShadow> card = [
    BoxShadow(color: AppColors.shadowDark, blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// Indigo glow for the active/primary CTA or "blocking active" hero.
  static const List<BoxShadow> glowIndigo = [
    BoxShadow(color: AppColors.glowIndigo, blurRadius: 32, spreadRadius: -4),
  ];

  /// Teal glow for accent / success states (e.g. pause active).
  static const List<BoxShadow> glowTeal = [
    BoxShadow(color: AppColors.glowTeal, blurRadius: 32, spreadRadius: -4),
  ];
}
