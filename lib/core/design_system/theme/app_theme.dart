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
  });

  final Color fillTop;
  final Color fillBottom;
  final Color border;
  final Color highlight;
  final Color onGlass;
  final Color onGlassMuted;

  static const dark = GlassTokens(
    fillTop: AppColors.glassFillTopDark,
    fillBottom: AppColors.glassFillBotDark,
    border: AppColors.glassBorderDark,
    highlight: AppColors.glassHighlightDark,
    onGlass: AppColors.onGlassDark,
    onGlassMuted: AppColors.onGlassMutedDark,
  );

  static const light = GlassTokens(
    fillTop: AppColors.glassFillTopLight,
    fillBottom: AppColors.glassFillBotLight,
    border: AppColors.glassBorderLight,
    highlight: AppColors.glassHighlightLight,
    onGlass: AppColors.onGlassLight,
    onGlassMuted: AppColors.onGlassMutedLight,
  );

  @override
  GlassTokens copyWith({
    Color? fillTop,
    Color? fillBottom,
    Color? border,
    Color? highlight,
    Color? onGlass,
    Color? onGlassMuted,
  }) {
    return GlassTokens(
      fillTop: fillTop ?? this.fillTop,
      fillBottom: fillBottom ?? this.fillBottom,
      border: border ?? this.border,
      highlight: highlight ?? this.highlight,
      onGlass: onGlass ?? this.onGlass,
      onGlassMuted: onGlassMuted ?? this.onGlassMuted,
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
    );
  }
}

/// `context.glass.onGlass` shortcut for the [GlassTokens] extension.
extension GlassThemeX on BuildContext {
  GlassTokens get glass =>
      Theme.of(this).extension<GlassTokens>() ?? GlassTokens.dark;
}

/// Centralised, dark-first themes built from a single seed colour (Material 3),
/// with surfaces overridden for the glassmorphic aesthetic and transparent
/// scaffolds so the ambient mesh shows through.
abstract final class AppTheme {
  /// Dark is the primary theme.
  static ThemeData dark() => _base(Brightness.dark);
  static ThemeData light() => _base(Brightness.light);

  /// The flagship dark scheme — a full Material 3 token set (lavender primary,
  /// mint-teal secondary, deep-navy surfaces). Surfaces are overridden again in
  /// [_base] for the glass aesthetic, but the scheme is the source of truth for
  /// `colorScheme.*` reads across the app.
  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFD0BCFF),
    onPrimary: Color(0xFF3C0091),
    primaryContainer: Color(0xFFA078FF),
    onPrimaryContainer: Color(0xFF340080),
    secondary: Color(0xFF44E2CD),
    onSecondary: Color(0xFF003731),
    secondaryContainer: Color(0xFF03C6B2),
    onSecondaryContainer: Color(0xFF004D44),
    tertiary: Color(0xFFC0C1FF),
    onTertiary: Color(0xFF1000A9),
    tertiaryContainer: Color(0xFF8083FF),
    onTertiaryContainer: Color(0xFF0D0096),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF0B1326),
    onSurface: Color(0xFFDAE2FD),
    onSurfaceVariant: Color(0xFFCBC3D7),
    surfaceDim: Color(0xFF0B1326),
    surfaceBright: Color(0xFF31394D),
    surfaceContainerLowest: Color(0xFF060E20),
    surfaceContainerLow: Color(0xFF131B2E),
    surfaceContainer: Color(0xFF171F33),
    surfaceContainerHigh: Color(0xFF222A3D),
    surfaceContainerHighest: Color(0xFF2D3449),
    outline: Color(0xFF958EA0),
    outlineVariant: Color(0xFF494454),
    inverseSurface: Color(0xFFDAE2FD),
    onInverseSurface: Color(0xFF283044),
    inversePrimary: Color(0xFF6D3BD7),
    surfaceTint: Color(0xFFD0BCFF),
  );

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Dark is the flagship: build the M3 scheme explicitly from the design
    // tokens (a light-lavender primary can't be reproduced via `fromSeed`).
    // Light stays seed-derived — the app is dark-first (`themeMode: dark`).
    final scheme = isDark
        ? _darkScheme
        : ColorScheme.fromSeed(
            seedColor: AppColors.seed,
            secondary: AppColors.accent,
            error: AppColors.danger,
          ).copyWith(
            outline: AppColors.hairlineLight,
          );

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
        color: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.45 : 0.6),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 44),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 44),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        fillColor: isDark ? AppColors.glassFillTopDark : null,
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
