import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:detoxo/core/design_system/tokens/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The two Frozen Glass themes, built once and only from [AppTokens].
///
/// The scheme carries the static spec `brand` (slider, progress, cursor, time
/// picker) and the neutral ink ramp; the live accent never enters it — it
/// paints only its six spec places through `context.accent`. Screens read the
/// full token set through `context.tokens`.
abstract final class AppTheme {
  static final ThemeData _light = _build(AppTokens.light);
  static final ThemeData _dark = _build(AppTokens.dark);

  static ThemeData light() => _light;

  static ThemeData dark() => _dark;

  /// System bars for a theme: transparent, with dark icons on the Light theme
  /// and light icons on the Dark one.
  static SystemUiOverlayStyle overlay(Brightness b) {
    final icons = b == Brightness.dark ? Brightness.light : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      statusBarIconBrightness: icons,
      statusBarBrightness: b,
      systemNavigationBarIconBrightness: icons,
    );
  }

  /// Every Material text slot on a Frozen Glass named style (Manrope, tabular
  /// figures, even leading). The colour comes from the scheme.
  static const _slots = TextTheme(
    displayLarge: AppTypography.number,
    displayMedium: AppTypography.number,
    displaySmall: AppTypography.titleXl,
    headlineLarge: AppTypography.titleXl,
    headlineMedium: AppTypography.titleXl,
    headlineSmall: AppTypography.titleSheet,
    titleLarge: AppTypography.title,
    titleMedium: AppTypography.headline,
    titleSmall: AppTypography.label,
    bodyLarge: AppTypography.message,
    bodyMedium: AppTypography.body,
    bodySmall: AppTypography.subhead,
    labelLarge: AppTypography.label,
    labelMedium: AppTypography.caption,
    labelSmall: AppTypography.tab,
  );

  static ThemeData _build(AppTokens t) {
    final dark = t.brightness == Brightness.dark;
    Color chip(Color c) => Color.lerp(t.optionBase, c, t.kChip)!;
    final ink = ConfirmTone.neutral.ink;
    final scheme = ColorScheme(
      brightness: t.brightness,
      primary: t.brand.main,
      onPrimary: ink,
      primaryContainer: chip(t.brand.main),
      onPrimaryContainer: t.ink,
      secondary: t.accentText(t.brand),
      onSecondary: t.optionBase,
      secondaryContainer: t.optionBase,
      onSecondaryContainer: t.ink,
      tertiary: t.brand.deep,
      onTertiary: ink,
      tertiaryContainer: chip(t.brand.deep),
      onTertiaryContainer: t.ink,
      error: t.accentText(t.over),
      onError: t.optionBase,
      errorContainer: chip(t.over.main),
      onErrorContainer: t.ink,
      surface: t.bgTop,
      onSurface: t.ink,
      onSurfaceVariant: t.ink2,
      surfaceDim: t.bgBottom,
      surfaceBright: t.optionBase,
      surfaceContainerLowest: dark ? t.bgBottom : t.optionBase,
      surfaceContainerLow: dark ? t.bgTop : t.cardFrom,
      surfaceContainer: dark ? t.cardFrom : t.bgTop,
      surfaceContainerHigh: dark ? t.optionBase : t.bgBottom,
      surfaceContainerHighest: dark ? t.buttonFrom : t.cardTo,
      outline: t.ink3,
      outlineVariant: t.hairline,
      inverseSurface: t.ink,
      onInverseSurface: t.bgTop,
      inversePrimary: t.brand.light,
      surfaceTint: Colors.transparent,
    );
    final sheetShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.sheet),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: t.brightness,
      colorScheme: scheme,
      textTheme: _slots,
      primaryTextTheme: _slots,
      // Raw scaffolds get the ground's end colour; GlassScaffold paints the
      // full gradient under its own transparent Scaffold.
      scaffoldBackgroundColor: t.bgBottom,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: _CalmTransitions()},
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: t.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        titleTextStyle: AppTypography.title.copyWith(color: t.ink),
        systemOverlayStyle: overlay(t.brightness),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppSizes.minTapTarget),
          shape: const StadiumBorder(),
          textStyle: AppTypography.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.ink2,
          minimumSize: AppSizes.minTapTargetSquare,
          shape: const StadiumBorder(),
          textStyle: AppTypography.label,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.ink,
          minimumSize: const Size(64, AppSizes.minTapTarget),
          side: BorderSide(color: t.hairline),
          shape: const StadiumBorder(),
          textStyle: AppTypography.label,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        isDense: true,
        fillColor: t.fillQuiet,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        hintStyle: AppTypography.body.copyWith(color: t.ink2),
        labelStyle: AppTypography.body.copyWith(color: t.ink2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.row),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.row),
          borderSide: BorderSide(color: t.focus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.row),
          borderSide: BorderSide(color: t.accentText(t.over)),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: t.brand.main,
        selectionColor: t.brand.main.withValues(alpha: 0.3),
        selectionHandleColor: t.brand.main,
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: t.fillQuiet,
        selectedColor: t.optionBase,
        labelStyle: AppTypography.label.copyWith(color: t.ink),
        checkmarkColor: t.ink,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: t.brand.main,
        inactiveTrackColor: t.fillQuiet,
        thumbColor: t.brand.main,
        overlayColor: t.brand.main.withValues(alpha: 0.12),
        valueIndicatorColor: t.ink,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.brand.main,
        linearTrackColor: t.fillQuiet,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: t.optionBase,
        shape: sheetShape,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        elevation: 0,
        modalBarrierColor: Colors.black.withValues(alpha: 0.45),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.optionBase,
        shape: sheetShape,
        titleTextStyle: AppTypography.titleSheet.copyWith(color: t.ink),
        contentTextStyle: AppTypography.message.copyWith(color: t.ink2),
        barrierColor: Colors.black.withValues(alpha: 0.45),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.md,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: t.ink,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        textStyle: AppTypography.subhead.copyWith(color: t.bgTop),
      ),
      dividerTheme: DividerThemeData(
        color: t.hairline,
        thickness: 1,
        space: AppSpacing.md,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: AppInsets.listTile,
        titleTextStyle: AppTypography.label.copyWith(color: t.ink),
        subtitleTextStyle: AppTypography.subhead.copyWith(color: t.ink2),
        iconColor: t.ink2,
        minTileHeight: 56,
      ),
    );
  }
}

/// Android page transitions: the platform's predictive-back transition, or no
/// motion at all when the person asked to remove animations.
class _CalmTransitions extends PageTransitionsBuilder {
  const _CalmTransitions();

  static const _platform = PredictiveBackPageTransitionsBuilder();

  @override
  Duration get transitionDuration => _platform.transitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      _platform.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return _platform.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
