import 'package:flutter/material.dart';

/// Brand + dark-first palette. **Brightness-fixed values only** — anything that
/// flips with light/dark goes through [ColorScheme] or the `GlassTokens`
/// theme extension instead.
///
/// A calm, focus-oriented scheme (deep indigo + teal accent) extended for the
/// glassmorphic, dark-first redesign.
abstract final class AppColors {
  // ── Brand ───────────────────────────────────────────────────────────────
  static const Color seed = Color(0xFF4C5BD4); // indigo (primary)
  static const Color accent = Color(0xFF1FB6A6); // teal (secondary)
  static const Color indigoBright = Color(0xFF6B79F0); // active indigo on dark
  static const Color tealBright = Color(0xFF2BD4C0); // active teal on dark

  // ── Semantic ────────────────────────────────────────────────────────────
  static const Color danger = Color(0xFFE5484D);
  static const Color warning = Color(0xFFF5A623);
  static const Color success = Color(0xFF30A46C);

  // ── Dark surfaces (existing names preserved) ────────────────────────────
  static const Color surfaceDark = Color(0xFF14151A); // scaffold base / mesh end
  static const Color cardDark = Color(0xFF1E2026); // opaque card fallback

  // ── Ambient mesh stops (deep indigo → near-black) ───────────────────────
  static const Color meshTop = Color(0xFF1B1E3A);
  static const Color meshMid = Color(0xFF15131F);
  static const Color meshBottom = Color(0xFF0C0D12);
  static const Color meshGlowIndigo = Color(0xFF3A3DA8);
  static const Color meshGlowTeal = Color(0xFF14695F);

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
  static const Color glassFillTopLight = Color(0x1A101012);
  static const Color glassFillBotLight = Color(0x0A101012);
  static const Color glassBorderLight = Color(0x1A101012);
  static const Color glassHighlightLight = Color(0x40FFFFFF);
  static const Color onGlassLight = Color(0xFF14151A);
  static const Color onGlassMutedLight = Color(0xB314151A);

  // ── Hairline / outline (non-glass dividers) ─────────────────────────────
  static const Color hairlineDark = Color(0x1FFFFFFF);
  static const Color hairlineLight = Color(0x14101012);

  // ── Soft glow colors for dark-UI shadows ────────────────────────────────
  static const Color glowIndigo = Color(0x554C5BD4);
  static const Color glowTeal = Color(0x551FB6A6);
  static const Color shadowDark = Color(0x66000000);
}
