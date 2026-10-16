import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_tokens.g.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/brand_tint.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_tokens.g.dart';
import 'package:flutter/painting.dart';

/// The shell colours for one tier (BR-04 / BR-05): the 160° body fill
/// [fillFrom] → [fillTo], the [ring] / outline / glow colour, the count [ink],
/// the [faint] track and [mark] tick colours (light or dark by tier), and the
/// [halo] / [shadow] around the body. Every tier is in the app theme's hue:
/// tier 0 the glass look ([BrandTint.at]), 1–5 the usage ramp the widgets'
/// tiles share ([BrandTint.ramp]). Twin of the Kotlin `BubbleLook`.
final class BubbleLook {
  const BubbleLook({
    required this.fillFrom,
    required this.fillTo,
    required this.ring,
    required this.ink,
    required this.faint,
    required this.mark,
    required this.halo,
    required this.shadow,
  });

  final Color fillFrom;
  final Color fillTo;
  final Color ring;
  final Color ink;
  final Color faint;
  final Color mark;
  final Color halo;
  final Color shadow;

  /// The six looks of the last brand asked for (the theme rarely changes).
  static (int, List<BubbleLook>)? _cache;

  /// The look for [tier], clamped to 0..5, in [brand]'s hue (the app theme's
  /// primary); all six are built once per brand.
  static BubbleLook of(int tier, {int brand = BrandTint.fallback}) {
    final hit = _cache;
    final looks = hit != null && hit.$1 == brand
        ? hit.$2
        : (_cache = (
            brand,
            [_glassOf(brand), for (var n = 1; n <= 5; n++) _tierOf(n, brand)],
          )).$2;
    return looks[tier.clamp(0, 5)];
  }

  static BubbleLook _glassOf(int brand) {
    Color tint(double l, [int alpha = 0xFF]) =>
        Color(BrandTint.withAlpha(BrandTint.at(brand, l), alpha));
    return BubbleLook(
      fillFrom: BubbleTokens.glassFrom,
      fillTo: tint(BrandTint.glassTo),
      ring: tint(BrandTint.glassRing),
      ink: tint(BrandTint.glassInk),
      faint: BubbleTokens.faintLight,
      mark: BubbleTokens.markLight,
      halo: tint(BrandTint.glassHalo, 0x29),
      shadow: tint(BrandTint.glassShadow, 0x61),
    );
  }

  /// Per-field blend: [t] 0 → [a], 1 → [b] (the 700 ms tier cross-fade).
  static BubbleLook lerp(BubbleLook a, BubbleLook b, double t) {
    Color m(Color x, Color y) => Color.lerp(x, y, t)!;
    return BubbleLook(
      fillFrom: m(a.fillFrom, b.fillFrom),
      fillTo: m(a.fillTo, b.fillTo),
      ring: m(a.ring, b.ring),
      ink: m(a.ink, b.ink),
      faint: m(a.faint, b.faint),
      mark: m(a.mark, b.mark),
      halo: m(a.halo, b.halo),
      shadow: m(a.shadow, b.shadow),
    );
  }

  /// Usage tier [n] (1..5) in [brand]'s ramp.
  static BubbleLook _tierOf(int n, int brand) {
    final to = Color(BrandTint.ramp(brand, BrandTint.tileTo[n - 1]));
    return BubbleLook(
      fillFrom: Color(BrandTint.ramp(brand, BrandTint.tileFrom[n - 1])),
      fillTo: to,
      ring: to,
      ink: n <= 3 ? WidgetTokens.widgetInk : WidgetTokens.widgetInkInverse,
      faint: n >= 4 ? BubbleTokens.faintDark : BubbleTokens.faintLight,
      mark: n >= 4 ? BubbleTokens.markDark : BubbleTokens.markLight,
      halo: to.withValues(alpha: 0x2E / 255),
      shadow: to.withValues(alpha: 0x73 / 255),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BubbleLook &&
      other.fillFrom == fillFrom &&
      other.fillTo == fillTo &&
      other.ring == ring &&
      other.ink == ink &&
      other.faint == faint &&
      other.mark == mark &&
      other.halo == halo &&
      other.shadow == shadow;

  @override
  int get hashCode =>
      Object.hash(fillFrom, fillTo, ring, ink, faint, mark, halo, shadow);
}
