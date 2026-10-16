import 'dart:convert';
import 'dart:io';

import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/bubble_look.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/brand_tint.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_face_painter.dart';
import 'package:detoxo/features/content_counter/home_content_counter/presentation/widget_tokens.g.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs `test/fixtures/brand_tints.json`, the vectors the Kotlin `BrandTint`
/// test shares.
void main() {
  final fixture =
      jsonDecode(File('test/fixtures/brand_tints.json').readAsStringSync())
          as Map<String, dynamic>;
  const roles = {
    'glassTo': BrandTint.glassTo,
    'glassRing': BrandTint.glassRing,
    'glassInk': BrandTint.glassInk,
    'glassHalo': BrandTint.glassHalo,
    'glassShadow': BrandTint.glassShadow,
    'tileLight': BrandTint.tileLight,
    'countLight': BrandTint.countLight,
  };
  final ramp = fixture['ramp'] as Map<String, dynamic>;
  String hex(int argb) => argb.toRadixString(16);

  test('roles, saturation and ramp targets match the fixture', () {
    expect(fixture['maxSaturation'], BrandTint.maxSaturation);
    expect(fixture['roles'], roles);
    expect(ramp['tileFrom'], BrandTint.tileFrom);
    expect(ramp['tileTo'], BrandTint.tileTo);
    expect(ramp['accentDarkY'], BrandTint.accentDarkY);
    expect(ramp['accentDarkS'], BrandTint.accentDarkS);
    expect(ramp['dotLight'], BrandTint.dotLight);
  });

  for (final c in (fixture['cases'] as List).cast<Map<String, dynamic>>()) {
    final brand = c['brand'] as int;
    test('${c['hex']} tints every role', () {
      final tints = c['tints'] as Map<String, dynamic>;
      for (final MapEntry(:key, :value) in roles.entries) {
        expect(
          hex(BrandTint.at(brand, value)),
          hex(tints[key] as int),
          reason: key,
        );
      }
    });

    test('${c['hex']} ramps every tier', () {
      final want = (c['ramp'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as List).cast<int>().map(hex).toList()),
      );
      expect(
        BrandTint.tileFrom.map((y) => hex(BrandTint.ramp(brand, y))),
        want['tileFrom'],
      );
      expect(
        BrandTint.tileTo.map((y) => hex(BrandTint.ramp(brand, y))),
        want['tileTo'],
      );
      expect([
        for (var t = 0; t < 6; t++)
          hex(
            BrandTint.ramp(
              brand,
              BrandTint.accentDarkY[t],
              BrandTint.accentDarkS[t],
            ),
          ),
      ], want['accentDark']);
      expect(
        BrandTint.dotLight.map((y) => hex(BrandTint.ramp(brand, y))),
        want['dotLight'],
      );
    });
  }

  test('the fallback keeps the original glass ink', () {
    expect(BrandTint.at(BrandTint.fallback, BrandTint.glassInk), 0xFF1C3D78);
  });

  group('the surfaces take the brand at every tier', () {
    const brand = 0xFF37DFA0;
    Color tint(double l) => Color(BrandTint.at(brand, l));
    Color ramped(double y, [double s = BrandTint.maxSaturation]) =>
        Color(BrandTint.ramp(brand, y, s));

    test('the bubble: glass at 0, the ramp after', () {
      final glass = BubbleLook.of(0, brand: brand);
      expect(glass.fillTo, tint(BrandTint.glassTo));
      expect(glass.ring, tint(BrandTint.glassRing));
      expect(glass.ink, tint(BrandTint.glassInk));
      expect(BubbleLook.of(0, brand: brand), same(glass)); // cached
      for (var t = 1; t <= 5; t++) {
        final look = BubbleLook.of(t, brand: brand);
        expect(look.fillFrom, ramped(BrandTint.tileFrom[t - 1]), reason: '$t');
        expect(look.fillTo, ramped(BrandTint.tileTo[t - 1]), reason: '$t');
        expect(look, isNot(BubbleLook.of(t)), reason: 'the hue is the brand');
      }
    });

    test('the widget tile, accent, Bento dot and Bonsai bar', () {
      final empty = tileLook(0, dark: false, brand: brand);
      expect(empty.from, tint(BrandTint.tileLight));
      expect(empty.count, tint(BrandTint.countLight));
      final tile = tileLook(2, dark: false, brand: brand);
      expect(tile.from, ramped(BrandTint.tileFrom[1]));
      expect(tile.to, ramped(BrandTint.tileTo[1]));
      for (var t = 0; t <= 5; t++) {
        final accent = ramped(
          BrandTint.accentDarkY[t],
          BrandTint.accentDarkS[t],
        );
        final dark = tileLook(t, dark: true, brand: brand);
        expect(dark.count, accent, reason: '$t');
        expect(dark.glow, accent, reason: '$t');
        expect(bentoLook(t, dark: true, brand: brand).dot, accent);
        final dot = ramped(BrandTint.dotLight[t]);
        expect(bentoLook(t, dark: false, brand: brand).dot, dot, reason: '$t');
        expect(bonsaiLook(t, dark: false, brand: brand).bar, dot, reason: '$t');
        expect(
          bonsaiLook(t, dark: false, brand: brand).leaf,
          WidgetTokens.bonsaiLeaf[t],
          reason: 'the tree keeps its own colours',
        );
      }
    });
  });
}
