import 'package:detoxo/core/design_system/tokens/app_colors.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';

/// Builds a [FeedbackThemeData] matched to Detoxo's glass palette for the given
/// [brightness]. The sheet colour is transparent so our frosted glass card
/// (`GlassFeedbackForm`) is the visible surface; the package already sizes the
/// sheet above the keyboard and reserves the rest for the screenshot preview.
FeedbackThemeData glassFeedbackTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final onSurface = isDark ? AppColors.onGlassDark : AppColors.onGlassLight;
  return FeedbackThemeData(
    background: isDark ? AppColors.cardDark : const Color(0xFFEEF1FB),
    // Transparent, but the RGB channels are kept dark/light so the package's
    // brightness estimation (which ignores alpha) resolves the right Material
    // theme for the form's text field.
    feedbackSheetColor: isDark ? const Color(0x00000000) : const Color(0x00FFFFFF),
    // A compact collapsed sheet keeps a large screenshot preview above it; it
    // is draggable to expand and grows automatically when the keyboard opens.
    feedbackSheetHeight: 0.42,
    activeFeedbackModeColor: AppColors.accent,
    drawColors: const [
      // AppColors.accent,
      // AppColors.seed,
      // Colors.white,
      AppColors.danger,
      AppColors.warning,
    ],
    bottomSheetDescriptionStyle: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
    bottomSheetTextInputStyle: TextStyle(color: onSurface),
  );
}
