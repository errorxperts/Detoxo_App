import 'dart:convert';
import 'dart:io';

import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/entities/plan_state.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/entities/widget_payload.dart';
import 'package:detoxo/features/content_counter/home_content_counter/domain/widget_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs the shared model vectors that Kotlin `WidgetModelTest` runs too
/// (`test/fixtures/home_widget_cases.json`, written by
/// `tool/home_widget/ref_model.py`):
/// every case, every `expected` key, so the two widget sides cannot drift.
void main() {
  final fixture =
      jsonDecode(
            File('test/fixtures/home_widget_cases.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final cases = (fixture['cases'] as List).cast<Map<String, dynamic>>();

  test('the fixture has cases', () => expect(cases, isNotEmpty));

  for (final c in cases) {
    test(c['name'] as String, () {
      final m = WidgetModel(
        WidgetPayload.parse(jsonEncode(c['payload'])),
        nowMs: c['nowMs'] as int,
        zoneOffsetMin: c['zoneOffsetMin'] as int,
        use24h: c['use24h'] as bool,
        updatedZoneOffsetMin: c['updatedZoneOffsetMin'] as int,
      );
      final expected = c['expected'] as Map<String, dynamic>;
      final actual = _fields(m);

      expect(actual.keys, unorderedEquals(expected.keys));
      for (final MapEntry(:key, :value) in expected.entries) {
        if (key != 'bars') {
          expect(actual[key], value, reason: key);
          continue;
        }
        final bars = (value as List).cast<num>();
        expect(m.bars, hasLength(bars.length));
        for (var i = 0; i < bars.length; i++) {
          expect(m.bars[i], closeTo(bars[i], 1e-9), reason: 'bars[$i]');
        }
      }
    });
  }

  test('a limit built in code past a day reads as the day, not wrapped', () {
    // 2^62 minutes × 60 wraps to 0 in a 64-bit int: no limit at all.
    final m = WidgetModel(
      const WidgetPayload(limitMinutes: 1 << 62, watchSeconds: 60),
      nowMs: 0,
      zoneOffsetMin: 0,
      use24h: false,
    );

    expect(m.hasLimit, isTrue);
    expect(m.limitLabel, 'Left of 24h');
  });

  test('updatedZoneOffsetMin defaults to zoneOffsetMin', () {
    final spring = cases.firstWhere(
      (c) => c['name'] == 'dst_spring_yesterday_is_empty',
    );
    WidgetModel model({int? updatedZoneOffsetMin}) => WidgetModel(
      WidgetPayload.parse(jsonEncode(spring['payload'])),
      nowMs: spring['nowMs'] as int,
      zoneOffsetMin: 60,
      use24h: false,
      updatedZoneOffsetMin: updatedZoneOffsetMin,
    );

    // The now-offset reads the 23:30 GMT payload as 00:30 BST: today.
    expect(model().empty, isFalse);
    expect(model().note, model(updatedZoneOffsetMin: 60).note);
    expect(model(updatedZoneOffsetMin: 0).empty, isTrue);
  });

  // ── Plan (EVO-073): test/fixtures/home_widget_plan_cases.json ──────────
  final planFixture =
      jsonDecode(
            File(
              'test/fixtures/home_widget_plan_cases.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final planCases = (planFixture['cases'] as List).cast<Map<String, dynamic>>();

  test(
    'the plan fixture has its 18 cases',
    () => expect(planCases, hasLength(18)),
  );

  for (final c in planCases) {
    test('plan ${c['name']}', () {
      final s = c['state'] as Map<String, dynamic>;
      final m = WidgetModel(
        WidgetPayload.empty,
        nowMs: c['nowMs'] as int,
        zoneOffsetMin: c['zoneOffsetMin'] as int,
        use24h: c['use24h'] as bool,
        plan: PlanState(
          plan: BlockingPlan.fromWire(s['plan'] as String),
          pauseUntil: s['pauseUntil'] as int,
          reelAllowance: s['reelAllowance'] as int,
          reelsConsumed: s['reelsConsumed'] as int,
          blockingOn: s['blockingOn'] as bool,
          serviceOn: s['serviceOn'] as bool,
        ),
      );
      final actual = <String, Object?>{
        'planTitle': m.planTitle,
        'planLabelShort': m.planLabelShort,
        'planLabelLong': m.planLabelLong,
        'planValueShort': m.planValueShort,
        'planValueLong': m.planValueLong,
        'planClock': m.planClock,
        'planRingPct': m.planRingPct,
        'planRingText': m.planRingText,
        'planDescription': m.planDescription,
      };
      expect(actual, c['expected']);
      for (final size in WidgetSize.values) {
        expect(
          m.describe(WidgetFamily.plan, size),
          (c['expected'] as Map)['planDescription'],
        );
      }
    });
  }

  test('the plan line takes no tracking or stale note', () {
    final m = WidgetModel(
      const WidgetPayload(updatedAt: 1, trackingEnabled: false),
      nowMs: 36000000,
      zoneOffsetMin: 0,
      use24h: false,
    );
    expect(m.note, 'Turn on tracking');
    expect(
      m.describe(WidgetFamily.plan, WidgetSize.large),
      'Block All is on, every reel is blocked',
    );
  });

  test('the Conscious plan reads "Conscious", never its wire token', () {
    // `curious` is the wire token only; every Plan string a user sees or
    // hears says "Conscious".
    final m = WidgetModel(
      WidgetPayload.empty,
      nowMs: 0,
      zoneOffsetMin: 0,
      use24h: false,
      plan: const PlanState(plan: BlockingPlan.curious),
    );
    expect(m.planTitle, 'Conscious');
    expect(m.planDescription, 'Conscious is on, earn reel time by staying off');
    for (final text in [
      m.planTitle,
      m.planLabelShort,
      m.planLabelLong,
      m.planValueShort,
      m.planValueLong,
      m.planRingText,
      m.planDescription,
      for (final size in WidgetSize.values) m.describe(WidgetFamily.plan, size),
    ]) {
      expect(text.toLowerCase(), isNot(contains('curious')), reason: text);
    }
  });
}

/// The model as the fixture spells it: `final` is [WidgetModel.isFinal], and
/// `describe` covers every `FAMILY:SIZE` (18 keys).
Map<String, Object?> _fields(WidgetModel m) => {
  'tier': m.tier,
  'empty': m.empty,
  'final': m.isFinal,
  'over': m.over,
  'stale': m.stale,
  'trackingOff': m.trackingOff,
  'hasLimit': m.hasLimit,
  'countText': m.countText,
  'time': m.time,
  'toNext': m.toNext,
  'ringPct': m.ringPct,
  'segmentsOn': m.segmentsOn,
  'bars': m.bars,
  'peakHour': m.peakHour,
  'peakLabel': m.peakLabel,
  'peakValue': m.peakValue,
  'tierChip': m.tierChip,
  'reelsChip': m.reelsChip,
  'todayShort': m.todayShort,
  'todayLong': m.todayLong,
  'nextShort': m.nextShort,
  'nextLong': m.nextLong,
  'nextLabel': m.nextLabel,
  'nextValue': m.nextValue,
  'leftBig': m.leftBig,
  'limitLabel': m.limitLabel,
  'bonsaiStage': m.bonsaiStage,
  'bonsaiHealth': m.bonsaiHealth,
  'stageHealth': m.stageHealth,
  'bentoNextLabel': m.bentoNextLabel,
  'bentoNextValue': m.bentoNextValue,
  'note': m.note,
  'describe': {
    for (final f in WidgetFamily.values)
      // Plan reads no payload: home_widget_plan_cases.json pins its line.
      if (f != WidgetFamily.plan)
        for (final s in WidgetSize.values)
          '${f.wire}:${s.wire}': m.describe(f, s),
  },
};
