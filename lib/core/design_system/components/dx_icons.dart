import 'dart:ui' show ImageFilter;

import 'package:detoxo/core/design_system/foundations/accent.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';

/// A spec 3D glass icon (a 192² WebP), shown at 34 (ModeCard), 40 (rules
/// row), 56 (tiles) or 58 (confirm sheet); never cropped or redrawn.
///
/// Only the mode icons pass [accentTint]: [accentIconFilter] turns them
/// to the live accent, vivid when [selected] and soft (saturate
/// [AppTokens.iconSaturateOff] at [AppTokens.iconOpacityOff]) when not. Every
/// other icon keeps its own colour. Decorative unless [semanticLabel] is set.
class Icon3d extends StatelessWidget {
  const Icon3d(
    this.asset, {
    required this.size,
    this.accentTint = false,
    this.selected = true,
    this.semanticLabel,
    super.key,
  });

  final AssetGenImage asset;
  final double size;
  final bool accentTint;
  final bool selected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final image = asset.image(
      width: size,
      height: size,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
    if (!accentTint) return image;
    return ColorFiltered(
      colorFilter: selected
          ? accentIconFilter(context.accent)
          : accentIconFilter(
              context.accent,
              saturate: AppTokens.iconSaturateOff,
              opacity: AppTokens.iconOpacityOff,
            ),
      child: image,
    );
  }
}

/// A spec single-ink glyph (a 24 × 24 SVG) in [color], `ink` by default.
/// Decorative unless [semanticLabel] is set.
class Glyph extends StatelessWidget {
  const Glyph(
    this.asset, {
    this.size = 24,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final SvgGenImage asset;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => asset.svg(
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color ?? context.tokens.ink, BlendMode.srcIn),
    semanticsLabel: semanticLabel,
    excludeFromSemantics: semanticLabel == null,
  );
}

/// The Detoxo mark, a 100 × 192 glass hourglass, at [height]: 60 in a
/// sheet's icon well, 44 beside the name. It is never recoloured and always
/// carries [AppTokens.logoGlow]: each layer is a blurred copy of its alpha in
/// the layer colour, drawn under it like CSS `drop-shadow`. Decorative unless
/// [semanticLabel] is set.
class DetoxoLogo extends StatelessWidget {
  const DetoxoLogo({this.height = 60, this.semanticLabel, super.key});

  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final asset = Assets.images.icons.detoxoLogo;
    final width = height * 100 / 192;
    return Stack(
      children: [
        // The first layer paints on top, so stack them last to first.
        for (final glow in context.tokens.logoGlow.reversed)
          if (glow.color.a > 0)
            Transform.translate(
              offset: glow.offset,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: glow.blur / 2,
                  sigmaY: glow.blur / 2,
                  tileMode: TileMode.decal,
                ),
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(glow.color, BlendMode.srcIn),
                  child: asset.image(
                    width: width,
                    height: height,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
        asset.image(
          width: width,
          height: height,
          semanticLabel: semanticLabel,
          excludeFromSemantics: semanticLabel == null,
        ),
      ],
    );
  }
}
