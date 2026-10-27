import 'package:detoxo/features/content_counter/content_counter_bubble/domain/entities/bubble_style.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/entities/widget_style.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/entities/widget_tap.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/repositories/home_widget_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BubbleStyle', () {
    test('defaults: the Ring at the smallest size, opaque', () {
      const s = BubbleStyle.defaults();
      expect(s.variant, BubbleVariant.ring);
      expect(s.size, BubbleStyle.sizeMin);
      expect(s.opacity, 1);
    });

    test('wire tokens and labels are pinned in board order', () {
      expect(BubbleVariant.values.map((v) => v.wire), [
        'MASCOT',
        'RING',
        'LIQUID',
        'HOURGLASS',
        'BEZEL',
        'DROP',
      ]);
      expect(BubbleVariant.values.map((v) => v.label), [
        'Mascot',
        'Ring',
        'Liquid',
        'Hourglass',
        'Bezel',
        'Drop',
      ]);
    });

    test('toWire has exactly variant, size, opacity', () {
      expect(
        const BubbleStyle.defaults().toWire().keys,
        unorderedEquals(['variant', 'size', 'opacity']),
      );
    });

    test('survives a wire round-trip', () {
      final original = const BubbleStyle.defaults().copyWith(
        variant: BubbleVariant.ring,
        size: 60,
        opacity: 0.6,
      );
      expect(BubbleStyle.fromWire(original.toWire()), original);
    });

    test('legacy keys are ignored and old variants fall back', () {
      expect(
        BubbleStyle.fromWire(const {
          'variant': 'GLASS_ORB',
          'textScale': 1.2,
          'spacing': 1.1,
          'showLabel': true,
          'showTime': false,
        }),
        const BubbleStyle.defaults(),
      );
    });

    test('retired styles read back as Ring', () {
      for (final w in ['NEON', 'STEPS', 'WEATHER', 'OUTLINE']) {
        expect(
          BubbleStyle.fromWire({'variant': w, 'size': 72.0}).variant,
          BubbleVariant.ring,
          reason: w,
        );
      }
    });

    test('fromWire clamps and defaults', () {
      expect(BubbleStyle.fromWire(null), const BubbleStyle.defaults());
      expect(BubbleStyle.fromWire(const {'size': 999.0}).size, 64);
      expect(BubbleStyle.fromWire(const {'size': 10.0}).size, 38.4);
      expect(BubbleStyle.fromWire(const {'opacity': 5.0}).opacity, 1);
      expect(BubbleStyle.fromWire(const {'opacity': 0.1}).opacity, 0.5);
      expect(
        BubbleStyle.fromWire(const {'variant': 'NOPE'}).variant,
        BubbleVariant.ring,
      );
      expect(BubbleStyle.fromWire(const {'size': 'big'}).size, 38.4);
    });

    test('a wrong-typed variant falls back to ring without throwing', () {
      expect(
        BubbleStyle.fromWire(const {'variant': 5}).variant,
        BubbleVariant.ring,
      );
    });
  });

  group('WidgetStyle', () {
    test('defaults to the system theme', () {
      expect(const WidgetStyle.defaults().theme, WidgetTheme.system);
    });

    test('survives a wire round-trip, carrying only the theme', () {
      const original = WidgetStyle(theme: WidgetTheme.dark);
      expect(original.toWire(), {'theme': 'DARK'});
      expect(WidgetStyle.fromWire(original.toWire()), original);
    });

    test('a legacy style keeps its theme and drops the rest', () {
      final s = WidgetStyle.fromWire(const {
        'background': 'USAGE_TINT',
        'theme': 'LIGHT',
        'density': 'COMPACT',
        'showToday': false,
        'showLabel': false,
        'showTotal': false,
        'accentByUsage': true,
      });
      expect(s, const WidgetStyle(theme: WidgetTheme.light));
    });

    test('fromWire falls back to system on null, unknown or wrong type', () {
      expect(WidgetStyle.fromWire(null), const WidgetStyle.defaults());
      expect(
        WidgetStyle.fromWire(const {'theme': 'NOPE'}).theme,
        WidgetTheme.system,
      );
      expect(
        WidgetStyle.fromWire(const {'theme': 7}).theme,
        WidgetTheme.system,
      );
    });
  });

  // Native, the widget tap intent and analytics all speak these tokens.
  group('home widget wire tokens', () {
    test('families and sizes are pinned', () {
      expect(WidgetFamily.values.map((f) => f.wire), [
        'COUNT',
        'NEXT_COLOUR',
        'TIME_LIMIT',
        'RHYTHM',
        'BONSAI',
        'BENTO',
        'PLAN',
      ]);
      expect(WidgetFamily.values.map((f) => f.label), [
        'Count',
        'Next colour',
        'Time limit',
        'Rhythm',
        'Bonsai',
        'Bento',
        'Plan',
      ]);
      expect(WidgetSize.values.map((s) => s.wire), [
        'SMALL',
        'MEDIUM',
        'LARGE',
      ]);
      expect(WidgetTapTarget.values.map((t) => t.wire), [
        'ACTIVITY',
        'APPEARANCE',
        'PERMISSIONS',
        'SETTINGS',
      ]);
      expect(WidgetPushReason.values.map((r) => r.wire), [
        'refresh',
        'background',
      ]);
    });

    test('fromWire round-trips and falls back to Count / Small', () {
      for (final f in WidgetFamily.values) {
        expect(WidgetFamily.fromWire(f.wire), f);
      }
      for (final s in WidgetSize.values) {
        expect(WidgetSize.fromWire(s.wire), s);
      }
      expect(WidgetFamily.fromWire('NOPE'), WidgetFamily.count);
      expect(WidgetSize.fromWire(null), WidgetSize.small);
    });

    test('a widget tap parses "FAMILY|SIZE|TARGET" and nothing else', () {
      expect(
        WidgetTap.parse('BONSAI|LARGE|PERMISSIONS'),
        const WidgetTap(
          WidgetFamily.bonsai,
          WidgetSize.large,
          WidgetTapTarget.permissions,
        ),
      );
      for (final bad in [
        null,
        '',
        'COUNT|SMALL',
        'COUNT|SMALL|ACTIVITY|X',
        'NOPE|SMALL|ACTIVITY',
        'COUNT|HUGE|ACTIVITY',
        'COUNT|SMALL|HOME',
      ]) {
        expect(WidgetTap.parse(bad), isNull, reason: '$bad');
      }
    });
  });
}
