import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AppTheme's type: every Material text slot, in textTheme and primaryTextTheme
// alike, is the generated named style the slot map gives it (Manrope, tabular
// figures, w600–w800), and the FilledButton theme keeps the family (a bare
// TextStyle there used to drop it).

/// The 15 slots of [t], each beside the named style it maps to.
List<(String, TextStyle?, TextStyle)> _slots(TextTheme t) => [
  ('displayLarge', t.displayLarge, AppTypography.number),
  ('displayMedium', t.displayMedium, AppTypography.number),
  ('displaySmall', t.displaySmall, AppTypography.titleXl),
  ('headlineLarge', t.headlineLarge, AppTypography.titleXl),
  ('headlineMedium', t.headlineMedium, AppTypography.titleXl),
  ('headlineSmall', t.headlineSmall, AppTypography.titleSheet),
  ('titleLarge', t.titleLarge, AppTypography.title),
  ('titleMedium', t.titleMedium, AppTypography.headline),
  ('titleSmall', t.titleSmall, AppTypography.label),
  ('bodyLarge', t.bodyLarge, AppTypography.message),
  ('bodyMedium', t.bodyMedium, AppTypography.body),
  ('bodySmall', t.bodySmall, AppTypography.subhead),
  ('labelLarge', t.labelLarge, AppTypography.label),
  ('labelMedium', t.labelMedium, AppTypography.caption),
  ('labelSmall', t.labelSmall, AppTypography.tab),
];

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    group('$name theme', () {
      test('every text slot is its named style: Manrope, tabular, w600+', () {
        for (final (textTheme, t) in [
          ('textTheme', theme.textTheme),
          ('primaryTextTheme', theme.primaryTextTheme),
        ]) {
          for (final (slot, style, named) in _slots(t)) {
            final reason = '$textTheme.$slot';
            expect(style, isNotNull, reason: reason);
            expect(style!.fontFamily, 'Manrope', reason: reason);
            expect(
              style.fontFeatures,
              contains(const FontFeature.tabularFigures()),
              reason: reason,
            );
            expect(
              style.fontWeight!.value,
              greaterThanOrEqualTo(600),
              reason: reason,
            );
            expect(
              (
                style.fontSize,
                style.height,
                style.fontWeight,
                style.letterSpacing,
              ),
              (
                named.fontSize,
                named.height,
                named.fontWeight,
                named.letterSpacing,
              ),
              reason: reason,
            );
          }
        }
      });

      test('FilledButton text is Manrope', () {
        final style = theme.filledButtonTheme.style!.textStyle!.resolve({});
        expect(style?.fontFamily, 'Manrope');
      });
    });
  }
}
