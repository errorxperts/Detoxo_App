import 'dart:ui';

import 'package:detoxo/core/design_system/theme/app_theme.dart';
import 'package:detoxo/core/design_system/tokens/app_blur.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:flutter/material.dart';

/// The ONE blur primitive every glass surface composes — nothing else should
/// call [BackdropFilter] directly.
///
/// [ClipRRect] is mandatory so the blur is clipped to the rounded rect instead
/// of sampling the whole screen. Set [enableBlur] to `false` for rows inside a
/// long [ListView] to skip the per-card `saveLayer` (it falls back to a flat
/// translucent gradient — the ambient mesh behind it still supplies depth).
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    required this.child,
    this.blurSigma = AppBlur.card,
    this.borderRadius = AppRadius.lg,
    this.tintTop,
    this.tintBottom,
    this.borderColor,
    this.borderWidth = 1,
    this.padding = AppInsets.card,
    this.enableBlur = true,
    super.key,
  });

  final Widget child;
  final double blurSigma;
  final double borderRadius;
  final Color? tintTop;
  final Color? tintBottom;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry padding;

  /// Set `false` inside long scrollables to skip the BackdropFilter saveLayer.
  final bool enableBlur;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final radius = BorderRadius.circular(borderRadius);

    final content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tintTop ?? glass.fillTop, tintBottom ?? glass.fillBottom],
        ),
        border: Border.all(color: borderColor ?? glass.border, width: borderWidth),
      ),
      child: Padding(padding: padding, child: child),
    );

    final clipped = ClipRRect(
      borderRadius: radius,
      child: enableBlur && blurSigma > 0
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: content,
            )
          : content,
    );

    // Isolate each glass surface's layer from sibling repaints.
    return RepaintBoundary(child: clipped);
  }
}
