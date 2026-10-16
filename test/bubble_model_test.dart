import 'dart:convert';
import 'dart:io';

import 'package:detoxo/features/content_counter/content_counter_bubble/domain/bubble_model.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs the shared bubble vectors (`test/fixtures/bubble_cases.json`) that the
/// Kotlin `BubbleModel` test runs too: every case, every `expected` key.
void main() {
  final fixture =
      jsonDecode(File('test/fixtures/bubble_cases.json').readAsStringSync())
          as Map<String, dynamic>;
  final cases = (fixture['cases'] as List).cast<Map<String, dynamic>>();

  for (final c in cases) {
    test(c['name'] as String, () {
      final expected = c['expected'] as Map<String, dynamic>;
      final actual = _fields(
        c['count'] as int,
        c['seconds'] as int,
        BubbleVariant.fromWire(c['variant'] as String),
      );

      expect(actual.keys, unorderedEquals(expected.keys));
      for (final MapEntry(:key, :value) in expected.entries) {
        if (key == 'sandTop' || key == 'sandBottom') {
          expect(actual[key], closeTo(value as num, 1e-6), reason: key);
        } else {
          expect(actual[key], value, reason: key);
        }
      }
    });
  }

  test('transitions', () {
    for (final t
        in (fixture['transitions'] as List).cast<Map<String, dynamic>>()) {
      expect(
        BubbleModel.transition(t['from'] as int, t['to'] as int).name,
        t['expected'],
        reason: '${t['from']}->${t['to']}',
      );
    }
  });
}

Map<String, Object?> _fields(int count, int seconds, BubbleVariant v) {
  final tier = BubbleModel.tier(count);
  final pct = BubbleModel.pct(count);
  return {
    'tier': tier,
    'countText': BubbleModel.countText(count),
    'shortTime': BubbleModel.shortTime(seconds),
    'clock': BubbleModel.clock(seconds),
    'pct': pct,
    'toNext': BubbleModel.toNext(count),
    'nextLine': BubbleModel.nextLine(count),
    'isDial': BubbleModel.isDial(v),
    'timerWidth': BubbleModel.timerWidth(seconds, v),
    'collapsedLabel': BubbleModel.collapsedLabel(count, seconds, v),
    'openLabel': BubbleModel.openLabel(seconds),
    'bezelLit': BubbleModel.bezelLit(count),
    'sandTop': BubbleModel.sandTop(pct),
    'sandBottom': BubbleModel.sandBottom(pct),
    'mascotLine': BubbleModel.mascotLine(tier),
  };
}
