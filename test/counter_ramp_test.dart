import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/brand_tint.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_face_painter.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_tokens.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

/// The usage ramp holds its contrast in every theme the app can pick: every
/// background's primary in both brightnesses, plus the pre-push fallback.
/// `BrandTint`'s tables are tuned against exactly these checks.
void main() {
  final brands = {
    BrandTint.fallback,
    for (final style in AppBackgroundStyle.values)
      for (final b in Brightness.values) brandFor(style, b).primary.toARGB32(),
  };

  for (final brand in brands) {
    final name = '#${brand.toRadixString(16).substring(2).toUpperCase()}';

    test('$name: light tiles keep their ink at both gradient ends', () {
      for (var t = 1; t <= 5; t++) {
        final look = tileLook(t, dark: false, brand: brand);
        for (final end in [look.from, look.to]) {
          expect(
            _contrast(look.count, end),
            greaterThanOrEqualTo(4.5),
            reason: 'tier $t count',
          );
          final muted = Color.alphaBlend(look.muted, end);
          expect(
            _contrast(muted, end),
            greaterThanOrEqualTo(4.5),
            reason: 'tier $t muted',
          );
        }
      }
    });

    test('$name: each light tier is a visible step deeper', () {
      for (var t = 2; t <= 5; t++) {
        final before = tileLook(t - 1, dark: false, brand: brand).to;
        final now = tileLook(t, dark: false, brand: brand).to;
        expect(now.computeLuminance(), lessThan(before.computeLuminance()));
        expect(
          _contrast(before, now),
          greaterThanOrEqualTo(1.25),
          reason: 'tier ${t - 1} → $t',
        );
      }
    });

    test('$name: dark accents read on the dark surfaces', () {
      for (var t = 0; t <= 5; t++) {
        final accent = darkAccent(t, brand);
        for (final surface in [
          WidgetTokens.darkSurface,
          WidgetTokens.darkEmpty,
          WidgetTokens.bentoModuleDark,
        ]) {
          expect(
            _contrast(accent, surface),
            greaterThanOrEqualTo(4.5),
            reason: 'tier $t',
          );
        }
      }
    });

    test('$name: the light dot and bar show on a white module', () {
      for (var t = 1; t <= 5; t++) {
        expect(
          _contrast(
            tierDot(t, dark: false, brand: brand),
            WidgetTokens.bentoModuleLight,
          ),
          greaterThanOrEqualTo(3),
          reason: 'tier $t',
        );
      }
    });
  }
}
