import 'package:detoxo/core/design_system/design_system.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';

/// Builds a [FeedbackThemeData] matched to the Frozen Glass tokens for the
/// given [brightness]. The sheet colour is transparent so our sheet card
/// (`GlassFeedbackForm`) is the visible surface; the package already sizes the
/// sheet above the keyboard and reserves the rest for the screenshot preview.
FeedbackThemeData glassFeedbackTheme(Brightness brightness) {
  final t = AppTokens.forBrightness(brightness);
  return FeedbackThemeData(
    background: t.bgBottom,
    // Transparent, but the RGB channels are kept dark/light so the package's
    // brightness estimation (which ignores alpha) resolves the right Material
    // theme for the form's text field.
    feedbackSheetColor: brightness == Brightness.dark
        ? const Color(0x00000000)
        : const Color(0x00FFFFFF),
    // A compact collapsed sheet keeps a large screenshot preview above it; it
    // is draggable to expand and grows automatically when the keyboard opens.
    feedbackSheetHeight: 0.42,
    activeFeedbackModeColor: t.brand.light,
    drawColors: [t.over.main, t.pause.main],
    bottomSheetDescriptionStyle: TextStyle(
      color: t.ink,
      fontWeight: FontWeight.w600,
    ),
    bottomSheetTextInputStyle: TextStyle(color: t.ink),
  );
}
