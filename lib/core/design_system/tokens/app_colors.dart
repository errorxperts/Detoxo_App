import 'package:flutter/material.dart';

/// Brand + dark-first palette. **Brightness-fixed values only** — anything that
/// flips with light/dark goes through [ColorScheme] or the `GlassTokens`
/// theme extension instead.
///
/// A calm, focus-oriented scheme (lavender violet + mint-teal accent) extended
/// for the glassmorphic, dark-first redesign. The full Material 3 dark
/// ColorScheme is built explicitly from these tokens in `app_theme.dart`.
abstract final class AppColors {
  // ── Brand ───────────────────────────────────────────────────────────────
  static const Color seed = Color(0xFF6D3BD7); // violet seed (light theme + gradients)
  static const Color accent = Color(0xFF44E2CD); // mint-teal (secondary)
  static const Color indigoBright = Color(0xFFA078FF); // active violet on dark
  static const Color tealBright = Color(0xFF3CDDC7); // active mint on dark

  // ── Semantic ────────────────────────────────────────────────────────────
  static const Color danger = Color(0xFFE5484D);
  static const Color warning = Color(0xFFF5A623);
  static const Color success = Color(0xFF30A46C);

  // ── Dark surfaces (existing names preserved) ────────────────────────────
  static const Color surfaceDark = Color(0xFF0B1326); // scaffold base / mesh end
  static const Color cardDark = Color(0xFF171F33); // opaque card fallback

  // ── Ambient mesh stops (deep navy → near-black) ─────────────────────────
  static const Color meshTop = Color(0xFF131B2E);
  static const Color meshMid = Color(0xFF0B1326);
  static const Color meshBottom = Color(0xFF060E20);
  static const Color meshGlowIndigo = Color(0xFF6D3BD7);
  static const Color meshGlowTeal = Color(0xFF1E8C7E);

  // ── Onboarding tones (folded in from hardcoded screen consts) ───────────
  static const Color onbTeal = Color(0xFF0F8B7E); // was OnboardingScreen._teal
  static const Color onbViolet = Color(0xFF5B3FB8); // was OnboardingScreen._violet

  // ── Glass fill / border / on-glass text (dark) ──────────────────────────
  // Consumed via the GlassTokens extension; raw values live here.
  static const Color glassFillTopDark = Color(0x1AFFFFFF); // ~10% white
  static const Color glassFillBotDark = Color(0x0AFFFFFF); // ~4% white
  static const Color glassBorderDark = Color(0x1FFFFFFF); // ~12% white hairline
  static const Color glassHighlightDark = Color(0x33FFFFFF);
  static const Color onGlassDark = Color(0xFFF3F4F8);
  static const Color onGlassMutedDark = Color(0xB3F3F4F8); // ~70%

  // ── Glass fill / border / on-glass text (light) ─────────────────────────
  // Deeper tints than a typical glass build so surfaces, borders and secondary
  // text stay clearly visible against the pale light background (the thin ~10%
  // values washed out over the bright shader/aurora backgrounds).
  static const Color glassFillTopLight = Color(0x26101012); // ~15% black
  static const Color glassFillBotLight = Color(0x14101012); // ~8% black
  static const Color glassBorderLight = Color(0x2E101012); // ~18% black hairline
  static const Color glassHighlightLight = Color(0x40FFFFFF);
  static const Color onGlassLight = Color(0xFF14151A);
  static const Color onGlassMutedLight = Color(0xCC14151A); // ~80% black

  // ── Hairline / outline (non-glass dividers) ─────────────────────────────
  static const Color hairlineDark = Color(0x1FFFFFFF);
  static const Color hairlineLight = Color(0x24101012); // ~14% black (was ~8%)

  // ── Soft glow colors for dark-UI shadows ────────────────────────────────
  static const Color glowIndigo = Color(0x55D0BCFF); // lavender glow
  static const Color glowTeal = Color(0x5544E2CD); // mint glow
  static const Color shadowDark = Color(0x66000000);
}
