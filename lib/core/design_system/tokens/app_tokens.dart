import 'package:flutter/material.dart';

part 'app_tokens.g.dart';

/// One accent of the Frozen Glass design system: a spec `<p>-main` /
/// `-light` / `-deep` stop set. `AppTokens.palettes` lists all six.
@immutable
class AccentPalette {
  const AccentPalette(this.main, this.light, this.deep);

  final Color main;
  final Color light;
  final Color deep;

  /// Stop-by-stop [Color.lerp]: CSS `color-mix(in srgb, …)` of each stop.
  static AccentPalette lerp(AccentPalette a, AccentPalette b, double t) =>
      AccentPalette(
        Color.lerp(a.main, b.main, t)!,
        Color.lerp(a.light, b.light, t)!,
        Color.lerp(a.deep, b.deep, t)!,
      );

  @override
  bool operator ==(Object other) =>
      other is AccentPalette &&
      other.main == main &&
      other.light == light &&
      other.deep == deep;

  @override
  int get hashCode => Object.hash(main, light, deep);

  @override
  String toString() => 'AccentPalette($main, $light, $deep)';
}

/// One CSS `box-shadow` layer. Recipes keep the CSS layer order, where the
/// first layer paints on top. [blur] is the CSS blur radius, which is a
/// Gaussian sigma of `blur / 2` (not `BoxShadow.blurRadius`).
@immutable
class DxShadow {
  const DxShadow({
    required this.color,
    this.offset = Offset.zero,
    this.blur = 0,
    this.spread = 0,
    this.inset = false,
  });

  final Color color;
  final Offset offset;
  final double blur;
  final double spread;
  final bool inset;

  @override
  bool operator ==(Object other) =>
      other is DxShadow &&
      other.color == color &&
      other.offset == offset &&
      other.blur == blur &&
      other.spread == spread &&
      other.inset == inset;

  @override
  int get hashCode => Object.hash(color, offset, blur, spread, inset);

  @override
  String toString() =>
      'DxShadow($color, $offset, blur: $blur, spread: $spread, inset: $inset)';
}

extension AppTokensX on BuildContext {
  /// The Frozen Glass tokens for the current theme's brightness.
  AppTokens get tokens => AppTokens.forBrightness(Theme.of(this).brightness);
}

extension AppTokenText on AppTokens {
  /// Coloured text in a palette (bundle.css `--accent-text`): Light mixes
  /// `main` toward [AppTokens.accentTextInk]; Dark uses the `light` stop.
  Color accentText(AccentPalette p) => brightness == Brightness.dark
      ? p.light
      : Color.lerp(p.main, AppTokens.accentTextInk, AppTokens.accentTextMix)!;

  /// Status text beside a status dot of colour [c]: the same Light darkening
  /// as [accentText] (the raw Light dots are below 3:1); Dark keeps [c].
  Color statusText(Color c) => brightness == Brightness.dark
      ? c
      : Color.lerp(c, AppTokens.accentTextInk, AppTokens.accentTextMix)!;
}
