import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The block screen's colours, for its in-app preview. MIRROR CONTRACT: every
/// literal reproduces the native `Palette` / `wallPalette` in
/// `overlay/BlockScreenPalette.kt`, the source of truth. Edit the Kotlin
/// first, then mirror here. Kotlin's `blend(a, b, t)` is `Color.lerp(b, a, t)`.
///
/// The ground is flat. The accent is not here: it is the static spec
/// `brand.main` of the theme, a fill and a tint only; [legibleOn] makes it readable as a
/// label.
class WallPalette {
  const WallPalette({
    required this.ground,
    required this.ink,
    required this.muted,
  });

  final Color ground;
  final Color ink;
  final Color muted;
}

/// Face Down (light) is the board's `#ECEFF4`, with ink at 15.9:1 and muted at
/// 5.4:1. Spotlight (dark) carries a breath of [accent], as the board's
/// mint-black `#0B1510` does, and keeps ink ≥ 17:1 and muted ≥ 7.8:1 for every
/// theme primary.
WallPalette wallPaletteFor({required bool dark, required Color accent}) => dark
    ? WallPalette(
        ground: Color.lerp(const Color(0xFF07090E), accent, 0.07)!,
        ink: Color.lerp(const Color(0xFFFFFFFF), accent, 0.06)!,
        muted: Color.lerp(const Color(0xFFAEB6C6), accent, 0.14)!,
      )
    : const WallPalette(
        ground: Color(0xFFECEFF4),
        ink: Color(0xFF12151B),
        muted: Color(0xFF5A6170),
      );

/// [color], blended toward [ink] in 3 % steps (at most 40) until it reads at
/// ≥ 4.5:1 on [ground] — the accent as a label (Home's icon, the ghost exits).
/// On the light wall it deepens Sky, Teal and Rose a little; on the dark one
/// it lifts only the never-pushed fallback navy. A colour that already reads
/// comes back unchanged. Mirrors `legibleOn` in
/// `overlay/BlockScreenRenderer.kt`.
Color legibleOn(Color color, {required Color ground, required Color ink}) {
  var c = color;
  for (var i = 0; i < 40 && _contrast(c, ground) < 4.5; i++) {
    c = Color.lerp(c, ink, 0.03)!;
  }
  return c;
}

const _navy = Color(0xFF0B1326);

/// Text colour for a control filled with [fill]: navy where it reads best,
/// white otherwise — the theme's deep primaries (Magenta, Rose, Indigo) take
/// white. Mirrors `onColorFor` in `overlay/BlockScreenRenderer.kt`.
Color onColorFor(Color fill) =>
    _contrast(_navy, fill) >= _contrast(Colors.white, fill)
    ? _navy
    : Colors.white;

/// [fill], darkened toward navy in 3 % steps until [onColorFor] reads at
/// ≥ 4.5:1 — the primary button's fill. Only one theme primary needs it (Sky,
/// whose white text sits at 4.499:1); every other one comes back unchanged.
/// Mirrors `legibleFill` in `overlay/BlockScreenRenderer.kt`.
Color legibleFill(Color fill) {
  var f = fill;
  for (var i = 0; i < 40 && _contrast(onColorFor(f), f) < 4.5; i++) {
    f = Color.lerp(f, _navy, 0.03)!;
  }
  return f;
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
