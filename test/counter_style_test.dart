import 'package:detoxo/features/content_counter/content_counter_bubble/domain/entities/bubble_style.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/entities/widget_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BubbleStyle', () {
    test('defaults', () {
      const s = BubbleStyle.defaults();
      expect(s.variant, BubbleVariant.glassOrb);
      expect(s.size, BubbleStyle.sizeDefault);
      expect(s.textScale, BubbleStyle.textScaleDefault);
      expect(s.opacity, BubbleStyle.opacityDefault);
      expect(s.showLabel, false);
    });

    test('toWire serializes the enum wire token', () {
      final s = const BubbleStyle.defaults().copyWith(
        variant: BubbleVariant.emojiMood,
      );
      expect(s.toWire()['variant'], 'EMOJI_MOOD');
    });

    test('survives a full wire round-trip', () {
      final original = const BubbleStyle.defaults().copyWith(
        variant: BubbleVariant.minimalPill,
        size: 60,
        textScale: 1.2,
        spacing: 1.1,
        opacity: 0.7,
        showLabel: true,
      );
      final restored = BubbleStyle.fromWire(original.toWire());
      expect(restored, original);
    });

    test('fromWire defaults on null and clamps out-of-range values', () {
      expect(BubbleStyle.fromWire(null), const BubbleStyle.defaults());
      final clamped = BubbleStyle.fromWire(const {
        'variant': 'NOPE',
        'size': 999.0,
        'textScale': 0.1,
        'opacity': 5.0,
      });
      expect(clamped.variant, BubbleVariant.glassOrb); // unknown → default
      expect(clamped.size, BubbleStyle.sizeMax);
      expect(clamped.textScale, BubbleStyle.textScaleMin);
      expect(clamped.opacity, BubbleStyle.opacityMax);
    });
  });

  group('WidgetStyle', () {
    test('defaults', () {
      const s = WidgetStyle.defaults();
      expect(s.background, WidgetBackground.glassDark);
      expect(s.theme, WidgetTheme.system);
      expect(s.density, WidgetDensity.cozy);
      expect(s.showToday, true);
      expect(s.showTotal, true);
      expect(s.accentByUsage, false);
    });

    test('survives a full wire round-trip', () {
      final original = const WidgetStyle.defaults().copyWith(
        background: WidgetBackground.usageTint,
        theme: WidgetTheme.dark,
        density: WidgetDensity.compact,
        showLabel: false,
        accentByUsage: true,
      );
      final restored = WidgetStyle.fromWire(original.toWire());
      expect(restored, original);
    });

    test('fromWire coerces an all-lines-off payload to show today', () {
      final s = WidgetStyle.fromWire(const {
        'showToday': false,
        'showTotal': false,
      });
      expect(s.showToday, true);
    });

    test('fromWire falls back to enum defaults on unknown tokens', () {
      final s = WidgetStyle.fromWire(const {
        'background': 'NOPE',
        'theme': 'NOPE',
        'density': 'NOPE',
      });
      expect(s.background, WidgetBackground.glassDark);
      expect(s.theme, WidgetTheme.system);
      expect(s.density, WidgetDensity.cozy);
    });
  });
}
