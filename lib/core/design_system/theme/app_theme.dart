import 'package:detoxo/core/design_system/foundations/background_scope.dart';
import 'package:detoxo/core/design_system/tokens/app_colors.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/typography/app_typography.dart';
import 'package:flutter/material.dart';

/// Brightness-dependent glass values, read via
/// `Theme.of(context).extension<GlassTokens>()` or the `context.glass` shortcut.
@immutable
class GlassTokens extends ThemeExtension<GlassTokens> {
  const GlassTokens({
    required this.fillTop,
    required this.fillBottom,
    required this.border,
    required this.highlight,
    required this.onGlass,
    required this.onGlassMuted,
    required this.shadow,
  });

  final Color fillTop;
  final Color fillBottom;
  final Color border;
  final Color highlight;
  final Color onGlass;
  final Color onGlassMuted;

  /// Outer depth-shadow colour for elevated glass (a cool near-black on dark, a
  /// soft cool tint on light) — replaces the old hardcoded `Colors.black`.
  final Color shadow;

  static const dark = GlassTokens(
    fillTop: AppColors.glassFillTopDark,
    fillBottom: AppColors.glassFillBotDark,
    border: AppColors.glassBorderDark,
    highlight: AppColors.glassHighlightDark,
    onGlass: AppColors.onGlassDark,
    onGlassMuted: AppColors.onGlassMutedDark,
    shadow: AppColors.glassShadowDark,
  );

  static const light = GlassTokens(
    fillTop: AppColors.glassFillTopLight,
    fillBottom: AppColors.glassFillBotLight,
    border: AppColors.glassBorderLight,
    highlight: AppColors.glassHighlightLight,
    onGlass: AppColors.onGlassLight,
    onGlassMuted: AppColors.onGlassMutedLight,
    shadow: AppColors.glassShadowLight,
  );

  @override
  GlassTokens copyWith({
    Color? fillTop,
    Color? fillBottom,
    Color? border,
    Color? highlight,
    Color? onGlass,
    Color? onGlassMuted,
    Color? shadow,
  }) {
    return GlassTokens(
      fillTop: fillTop ?? this.fillTop,
      fillBottom: fillBottom ?? this.fillBottom,
      border: border ?? this.border,
      highlight: highlight ?? this.highlight,
      onGlass: onGlass ?? this.onGlass,
      onGlassMuted: onGlassMuted ?? this.onGlassMuted,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  GlassTokens lerp(GlassTokens? other, double t) {
    if (other == null) return this;
    return GlassTokens(
      fillTop: Color.lerp(fillTop, other.fillTop, t)!,
      fillBottom: Color.lerp(fillBottom, other.fillBottom, t)!,
      border: Color.lerp(border, other.border, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      onGlass: Color.lerp(onGlass, other.onGlass, t)!,
      onGlassMuted: Color.lerp(onGlassMuted, other.onGlassMuted, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

/// Glass + brand shortcuts on [BuildContext].
///
/// - `context.glass` → the [GlassTokens] extension.
/// - `context.accent` / `context.onAccent` → the live, **background-adaptive**
///   brand accent (routed through `colorScheme.secondary`/`onSecondary`), the
///   single source of truth so accent tints shift with the selected background.
/// - `context.shadow` → the glass depth-shadow colour.
extension GlassThemeX on BuildContext {
  GlassTokens get glass =>
      Theme.of(this).extension<GlassTokens>() ?? GlassTokens.dark;
  Color get accent => Theme.of(this).colorScheme.secondary;
  Color get onAccent => Theme.of(this).colorScheme.onSecondary;
  Color get shadow =>
      Theme.of(this).extension<GlassTokens>()?.shadow ?? GlassTokens.dark.shadow;

  /// Background-adaptive hero-metric gradient for ShaderMask numbers. Built from
  /// the live brand roles, so it's bright on dark and deep on light — legible in
  /// both themes (unlike a fixed light-on-light gradient).
  LinearGradient get metricGradient {
    final s = Theme.of(this).colorScheme;
    return LinearGradient(colors: [s.secondary, s.primary]);
  }
}

/// Per-background brand pairing. The selected background drives the app's live
/// primary + accent so the whole UI harmonises with what's behind the glass —
/// each pair is sampled from that background's own palette. [aurora] (the
/// asset-less default) uses the signature pairing, resolved per brightness.
///
/// Keyed by the design-system [AppBackgroundStyle] (dark* only appear in dark
/// mode, light* only in light mode); [brightness] disambiguates [aurora].
({Color primary, Color accent}) brandFor(
  AppBackgroundStyle style,
  Brightness brightness,
) {
  final dark = brightness == Brightness.dark;
  return switch (style) {
    AppBackgroundStyle.aurora => dark
        ? (primary: Color(0xFF8B93FF), accent: Color(0xFF35DCE8))
        : (primary: Color(0xFF4F46E5), accent: Color(0xFF0B7E8C)),
    AppBackgroundStyle.dark1 => (
      primary: Color(0xFF5B8CFF),
      accent: Color(0xFF38E0F0),
    ),
    AppBackgroundStyle.dark2 => (
      primary: Color(0xFFA78BFF),
      accent: Color(0xFF66D0FF),
    ),
    AppBackgroundStyle.dark3 => (
      primary: Color(0xFF9B7CFF),
      accent: Color(0xFF3AE0FF),
    ),
    AppBackgroundStyle.dark4 => (
      primary: Color(0xFFFF6FB0),
      accent: Color(0xFFC489FF),
    ),
    AppBackgroundStyle.dark5 => (
      primary: Color(0xFF5AA0FF),
      accent: Color(0xFF39E6F2),
    ),
    AppBackgroundStyle.dark6 => (
      primary: Color(0xFF37DFA0),
      accent: Color(0xFF7C9BFF),
    ),
    AppBackgroundStyle.light1 => (
      primary: Color(0xFF2F6BFF),
      accent: Color(0xFF0E7FA8),
    ),
    AppBackgroundStyle.light2 => (
      primary: Color(0xFF0B7E8C),
      accent: Color(0xFF3B5FD0),
    ),
    AppBackgroundStyle.light3 => (
      primary: Color(0xFFC21D9E),
      accent: Color(0xFF5A4FD0),
    ),
    AppBackgroundStyle.light4 => (
      primary: Color(0xFFC0367A),
      accent: Color(0xFF2F6FC0),
    ),
    AppBackgroundStyle.light5 => (
      primary: Color(0xFF5257DB),
      accent: Color(0xFF7E36C8),
    ),
  };
}

/// Centralised, dark-first themes with a **background-adaptive brand** layered
/// over hand-authored, contrast-audited neutral surfaces. Scaffolds are
/// transparent so the ambient mesh shows through; brand roles come from the
/// selected background via [brandFor], neutrals/semantics stay fixed per theme.
abstract final class AppTheme {
  // Signature pairing (the asset-less Aurora default), per brightness.
  static const Color _sigDarkPrimary = Color(0xFF8B93FF);
  static const Color _sigDarkAccent = Color(0xFF35DCE8);
  static const Color _sigLightPrimary = Color(0xFF4F46E5);
  static const Color _sigLightAccent = Color(0xFF0B7E8C);

  static ThemeData dark({
    Color brandPrimary = _sigDarkPrimary,
    Color brandAccent = _sigDarkAccent,
  }) => _base(Brightness.dark, brandPrimary, brandAccent);

  static ThemeData light({
    Color brandPrimary = _sigLightPrimary,
    Color brandAccent = _sigLightAccent,
  }) => _base(Brightness.light, brandPrimary, brandAccent);

  // ── Colour helpers ────────────────────────────────────────────────────────

  /// WCAG contrast ratio between two opaque colours.
  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Best readable on-colour (near-black ink or white) for a brand fill.
  static Color _ink(Color c) {
    const ink = Color(0xFF0A0E17);
    return _contrast(c, Colors.white) >= _contrast(c, ink) ? Colors.white : ink;
  }

  /// A tonal variant of [c] at a target lightness (for containers / tints).
  static Color _tone(Color c, double lightness) =>
      HSLColor.fromColor(c).withLightness(lightness.clamp(0.0, 1.0)).toColor();

  // ── Schemes ───────────────────────────────────────────────────────────────

  static ColorScheme _darkScheme(Color primary, Color accent) => ColorScheme(
    brightness: Brightness.dark,
    primary: primary,
    onPrimary: _ink(primary),
    primaryContainer: _tone(primary, 0.30),
    onPrimaryContainer: _tone(primary, 0.92),
    secondary: accent,
    onSecondary: _ink(accent),
    secondaryContainer: _tone(accent, 0.28),
    onSecondaryContainer: _tone(accent, 0.92),
    tertiary: _tone(primary, 0.80),
    onTertiary: const Color(0xFF11162A),
    tertiaryContainer: _tone(primary, 0.34),
    onTertiaryContainer: _tone(primary, 0.94),
    error: const Color(0xFFFFB4AB),
    onError: const Color(0xFF690005),
    errorContainer: const Color(0xFF93000A),
    onErrorContainer: const Color(0xFFFFDAD6),
    surface: const Color(0xFF0B1120),
    onSurface: const Color(0xFFE7ECF6),
    onSurfaceVariant: const Color(0xFFB7C0D4),
    surfaceDim: const Color(0xFF0A0F1C),
    surfaceBright: const Color(0xFF2A3350),
    surfaceContainerLowest: const Color(0xFF070C18),
    surfaceContainerLow: const Color(0xFF111827),
    surfaceContainer: const Color(0xFF151D30),
    surfaceContainerHigh: const Color(0xFF1C2438),
    surfaceContainerHighest: const Color(0xFF28304A),
    outline: const Color(0xFF8A93A8),
    outlineVariant: const Color(0xFF3A4256),
    inverseSurface: const Color(0xFFE7ECF6),
    onInverseSurface: const Color(0xFF283044),
    inversePrimary: _tone(primary, 0.45),
    surfaceTint: primary,
  );

  static ColorScheme _lightScheme(Color primary, Color accent) => ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: _ink(primary),
    primaryContainer: _tone(primary, 0.90),
    onPrimaryContainer: _tone(primary, 0.24),
    secondary: accent,
    onSecondary: _ink(accent),
    secondaryContainer: _tone(accent, 0.88),
    onSecondaryContainer: _tone(accent, 0.22),
    tertiary: _tone(primary, 0.42),
    onTertiary: Colors.white,
    tertiaryContainer: _tone(primary, 0.90),
    onTertiaryContainer: _tone(primary, 0.24),
    error: AppColors.danger,
    onError: Colors.white,
    errorContainer: const Color(0xFFFFDAD6),
    onErrorContainer: const Color(0xFF410002),
    surface: const Color(0xFFF7F8FC),
    onSurface: const Color(0xFF12151F),
    onSurfaceVariant: const Color(0xFF454B5A),
    surfaceDim: const Color(0xFFDCE0EC),
    surfaceBright: Colors.white,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFF1F3FA),
    surfaceContainer: const Color(0xFFECEFF8),
    surfaceContainerHigh: const Color(0xFFE5E9F4),
    surfaceContainerHighest: const Color(0xFFDEE3F1),
    outline: const Color(0xFFC3C9D6),
    outlineVariant: const Color(0xFFD8DCE7),
    inverseSurface: const Color(0xFF1B2030),
    onInverseSurface: const Color(0xFFF0F2F9),
    inversePrimary: _tone(primary, 0.78),
    surfaceTint: primary,
  );

  static ThemeData _base(
    Brightness brightness,
    Color brandPrimary,
    Color brandAccent,
  ) {
    final isDark = brightness == Brightness.dark;
    final scheme = isDark
        ? _darkScheme(brandPrimary, brandAccent)
        : _lightScheme(brandPrimary, brandAccent);

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      // Opaque base for raw scaffolds; flagship screens use GlassScaffold,
      // which sets its own transparent scaffold over the ambient mesh.
      scaffoldBackgroundColor: scheme.surface,
      extensions: [if (isDark) GlassTokens.dark else GlassTokens.light],
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        color: scheme.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.45 : 0.6,
        ),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppSizes.controlHeight),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppSizes.controlHeight),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        fillColor: isDark
            ? AppColors.glassFillTopDark
            : AppColors.glassFillTopLight,
        border: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brPill),
        side: BorderSide(color: scheme.outline),
        selectedColor: scheme.secondaryContainer,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.secondaryContainer.withValues(alpha: 0.5),
      ),
      listTileTheme: const ListTileThemeData(contentPadding: AppInsets.listTile),
      dividerTheme: DividerThemeData(
        color: scheme.outline,
        thickness: 1,
        space: AppSpacing.md,
      ),
    );

    return base.copyWith(
      textTheme: AppTypography.apply(base.textTheme),
      primaryTextTheme: AppTypography.apply(base.primaryTextTheme),
    );
  }
}
