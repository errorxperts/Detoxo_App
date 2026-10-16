import 'dart:math' as math;

/// The app theme's primary carried onto the counter's surfaces: the bubble's
/// glass and the widgets' empty tile at 0 reels ([at], a fixed lightness per
/// role), and the usage ramp at every tier ([ramp], a fixed brightness per
/// tier). Either way only the brand's hue (and its saturation, capped) is
/// kept, so every role keeps its contrast whichever theme is picked. ARGB
/// ints, as on the wire.
///
/// MIRROR CONTRACT: Kotlin `widget/BrandTint.kt` computes the same ints; both
/// are pinned by `test/fixtures/brand_tints.json`. Change one, change the
/// other and the fixture.
abstract final class BrandTint {
  /// Until the app first pushes its theme: the original glass navy.
  static const fallback = 0xFF1C3D78;

  static const maxSaturation = 0.75;

  // Lightness per role, 0..1.
  /// Bubble glass: the gradient's end (it starts white).
  static const glassTo = 0.945;
  static const glassRing = 0.83;
  static const glassInk = 0.29;

  /// Bubble glass: the halo and shadow, drawn at their own alpha.
  static const glassHalo = 0.676;
  static const glassShadow = 0.49;

  /// Widget, light theme: the empty tile and its count.
  static const tileLight = 0.94;
  static const countLight = 0.34;

  // The usage ramp: a target brightness per tier for [ramp], pale → deep, so
  // every hue's ramp reads alike (`test/counter_ramp_test.dart` holds each
  // one to its contrast).

  /// The light tile's 135° gradient (and the bubble's body), tiers 1..5 at
  /// index 0..4. Tiers 1–3 take dark ink, 4–5 white.
  static const tileFrom = [0.82, 0.66, 0.53, 0.17, 0.09];
  static const tileTo = [0.71, 0.54, 0.42, 0.11, 0.045];

  /// The dark theme's accent (count, fill, glow), tiers 0..5: its brightness
  /// and saturation cap, calm → vivid.
  static const accentDarkY = [0.50, 0.52, 0.47, 0.43, 0.40, 0.37];
  static const accentDarkS = [0.18, 0.36, 0.50, 0.62, 0.72, 0.80];

  /// Bento's status dot and Bonsai's health bar on a light module, tiers
  /// 0..5 (dark uses [accentDarkY]).
  static const dotLight = [0.40, 0.28, 0.22, 0.17, 0.12, 0.07];

  /// Bisection steps in [ramp]: the lightness lands within 2⁻²⁴.
  static const _steps = 24;

  /// [brand]'s hue at [lightness], opaque.
  static int at(int brand, double lightness) {
    final (h, s) = _hueSat(brand);
    return _pack(h, math.min(s, maxSaturation), lightness);
  }

  /// [brand]'s hue, its saturation capped at [saturation], at the lightness
  /// whose [brightness] (0..1, `.2126 r² + .7152 g² + .0722 b²`, a squared
  /// gamma: plain arithmetic, so Kotlin lands on the same ints) it reaches.
  static int ramp(
    int brand,
    double brightness, [
    double saturation = maxSaturation,
  ]) {
    final (h, s0) = _hueSat(brand);
    final s = math.min(s0, saturation);
    var lo = 0.0;
    var hi = 1.0;
    for (var i = 0; i < _steps; i++) {
      final mid = (lo + hi) / 2;
      final (r, g, b) = _rgb(h, s, mid);
      if (0.2126 * r * r + 0.7152 * g * g + 0.0722 * b * b < brightness) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return _pack(h, s, (lo + hi) / 2);
  }

  /// [argb] at [alpha] (0..255).
  static int withAlpha(int argb, int alpha) => alpha << 24 | argb & 0xFFFFFF;

  /// [brand]'s HSL hue and saturation, 0..1.
  static (double, double) _hueSat(int brand) {
    final r = (brand >> 16 & 0xFF) / 255;
    final g = (brand >> 8 & 0xFF) / 255;
    final b = (brand & 0xFF) / 255;
    final hi = math.max(r, math.max(g, b));
    final lo = math.min(r, math.min(g, b));
    final d = hi - lo;
    var h = 0.0;
    var s = 0.0;
    if (d > 0) {
      s = (hi + lo) / 2 > 0.5 ? d / (2 - hi - lo) : d / (hi + lo);
      h = hi == r
          ? (g - b) / d + (g < b ? 6 : 0)
          : hi == g
          ? (b - r) / d + 2
          : (r - g) / d + 4;
      h /= 6;
    }
    return (h, s);
  }

  /// HSL → RGB channels, 0..1, unrounded.
  static (double, double, double) _rgb(double h, double s, double l) {
    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;
    double channel(double t) {
      final u = t < 0 ? t + 1 : (t > 1 ? t - 1 : t);
      return u < 1 / 6
          ? p + (q - p) * 6 * u
          : u < 1 / 2
          ? q
          : u < 2 / 3
          ? p + (q - p) * (2 / 3 - u) * 6
          : p;
    }

    return (channel(h + 1 / 3), channel(h), channel(h - 1 / 3));
  }

  static int _pack(double h, double s, double l) {
    final (r, g, b) = _rgb(h, s, l);
    return 0xFF000000 |
        (r * 255).round() << 16 |
        (g * 255).round() << 8 |
        (b * 255).round();
  }
}
