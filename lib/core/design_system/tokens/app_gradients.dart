import 'package:flutter/material.dart';

import 'package:detoxo/core/design_system/tokens/app_colors.dart';

/// Reusable gradients. The ambient mesh is the app-wide backdrop that the
/// transparent scaffolds sit on top of.
abstract final class AppGradients {
  /// Base diagonal: deep indigo → near-black. Painted on the root background.
  static const LinearGradient ambient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.meshTop, AppColors.meshMid, AppColors.meshBottom],
    stops: [0.0, 0.45, 1.0],
  );

  /// Soft indigo glow blob (top-left) — layered as a radial over [ambient].
  static const RadialGradient glowIndigo = RadialGradient(
    center: Alignment(-0.8, -0.9),
    radius: 1.1,
    colors: [AppColors.meshGlowIndigo, Color(0x00000000)],
  );

  /// Soft teal glow blob (bottom-right).
  static const RadialGradient glowTeal = RadialGradient(
    center: Alignment(0.9, 0.95),
    radius: 1.0,
    colors: [AppColors.meshGlowTeal, Color(0x00000000)],
  );

  /// Brand CTA gradient (indigo → teal) for primary hero surfaces.
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.seed, AppColors.accent],
  );
}
