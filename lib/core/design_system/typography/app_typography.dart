import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type ramp: Inter body + Space Grotesk display. Weights match existing
/// usage (w600 titles/buttons, w700 section titles, w800 stats/headlines).
///
/// Fonts are fetched at runtime by google_fonts and cached to disk on first
/// use. (Bundling the `.ttf` weights for fully offline first-paint is a small
/// follow-up — see plan §1.)
abstract final class AppTypography {
  /// Merge fonts onto an M3 base text theme (preserves M3 sizing/spacing) and
  /// override the display/headline/title slots with Space Grotesk.
  static TextTheme apply(TextTheme base) {
    final body = GoogleFonts.interTextTheme(base);
    return body.copyWith(
      displayLarge:
          GoogleFonts.spaceGrotesk(textStyle: body.displayLarge, fontWeight: FontWeight.w700),
      displayMedium:
          GoogleFonts.spaceGrotesk(textStyle: body.displayMedium, fontWeight: FontWeight.w700),
      displaySmall:
          GoogleFonts.spaceGrotesk(textStyle: body.displaySmall, fontWeight: FontWeight.w700),
      headlineLarge:
          GoogleFonts.spaceGrotesk(textStyle: body.headlineLarge, fontWeight: FontWeight.w700),
      headlineMedium:
          GoogleFonts.spaceGrotesk(textStyle: body.headlineMedium, fontWeight: FontWeight.w800),
      headlineSmall:
          GoogleFonts.spaceGrotesk(textStyle: body.headlineSmall, fontWeight: FontWeight.w800),
      titleLarge:
          GoogleFonts.spaceGrotesk(textStyle: body.titleLarge, fontWeight: FontWeight.w700),
      titleMedium: GoogleFonts.inter(textStyle: body.titleMedium, fontWeight: FontWeight.w600),
      labelLarge: GoogleFonts.inter(textStyle: body.labelLarge, fontWeight: FontWeight.w600),
    );
  }

  /// Tabular figures for countdowns / stats so digits don't jitter.
  static TextStyle mono(TextStyle? base) => GoogleFonts.spaceGrotesk(
        textStyle: base,
        fontWeight: FontWeight.w800,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
