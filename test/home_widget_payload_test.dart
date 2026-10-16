import 'dart:convert';
import 'dart:io';

import 'package:detoxo/features/content_counter/home_content_counter/domain/entities/widget_payload.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs the shared IM-02 parse vectors that Kotlin `WidgetPayloadTest` runs
/// too (`test/fixtures/home_widget_payloads.json`): both sides read a stored
/// or corrupt payload the same way.
void main() {
  final fixture = _json('test/fixtures/home_widget_payloads.json');
  final cases = (fixture['cases'] as List).cast<Map<String, dynamic>>();

  test('the fixture has cases', () => expect(cases, isNotEmpty));

  for (final c in cases) {
    test(c['name'] as String, () {
      expect(_wire(WidgetPayload.parse(c['raw'] as String)), c['expected']);
    });
  }

  test('empty is the fixture empty, and what null reads as', () {
    expect(_wire(WidgetPayload.empty), fixture['empty']);
    expect(WidgetPayload.parse(null), WidgetPayload.empty);
  });

  test('a number out of range reads as 0 instead of throwing', () {
    expect(WidgetPayload.parse('{"reel_count": 1e400}').reelCount, 0);
  });

  test('demo is fixture tier2_152 with the given limit, theme and motion', () {
    final tier2 =
        (_json('test/fixtures/home_widget_cases.json')['cases'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((c) => c['name'] == 'tier2_152');
    final demo = WidgetPayload.demo(
      limitMinutes: 30,
      theme: 'dark',
      reduceMotion: true,
      nowMs: 42,
    );

    expect(_wire(demo), {
      ...tier2['payload'] as Map<String, dynamic>,
      'limit_minutes': 30,
      'theme': 'dark',
      'reduce_motion': true,
      'updated_at': 42,
    });
  });

  test('copyWith changes only the theme and reduce motion', () {
    final live = WidgetPayload.parse(
      '{"reel_count": 152, "reel_tier": 2, "theme": "dark", '
      '"updated_at": 1791668400000, "tracking_enabled": false}',
    );

    expect(_wire(live.copyWith(theme: 'light', reduceMotion: true)), {
      ..._wire(live),
      'theme': 'light',
      'reduce_motion': true,
    });
    expect(live.copyWith(), live);
  });
}

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// The payload under its IM-02 wire keys, to compare with the fixture.
Map<String, Object?> _wire(WidgetPayload p) => {
  'reel_count': p.reelCount,
  'watch_seconds': p.watchSeconds,
  'reel_tier': p.reelTier,
  'hourly_seconds': p.hourlySeconds,
  'limit_minutes': p.limitMinutes,
  'theme': p.theme,
  'reduce_motion': p.reduceMotion,
  'updated_at': p.updatedAt,
  'tracking_enabled': p.trackingEnabled,
};
