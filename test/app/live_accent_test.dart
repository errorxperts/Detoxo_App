import 'dart:convert';
import 'dart:io';

import 'package:detoxo/app/live_accent.dart';
import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/blocking/blocking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every shared modes row maps as natively (AccentResolver.modeOf)', () {
    final fixture =
        jsonDecode(File('test/fixtures/accent_cases.json').readAsStringSync())
            as Map<String, dynamic>;
    final rows = (fixture['modes'] as List).cast<Map<String, dynamic>>();
    expect(rows, isNotEmpty);
    for (final r in rows) {
      // A token Dart cannot hold (fromWire would read it as Block All).
      if (r['dartSkips'] == true) continue;
      final s = AppSettings(
        masterEnabled: r['masterEnabled'] as bool,
        activePlan: BlockingPlan.fromWire(r['plan'] as String),
        reelAllowance: r['allowance'] as int,
      );
      expect(
        accentModeOf(s, pauseLive: r['pauseLive'] as bool).name,
        r['mode'],
        reason: '$r',
      );
    }
  });

  test('blocking off: no mode, whatever the plan', () {
    const s = AppSettings(
      masterEnabled: false,
      activePlan: BlockingPlan.curious,
    );
    expect(accentModeOf(s, pauseLive: true), AccentMode.none);
  });

  test('a live pause lights Pause', () {
    expect(
      accentModeOf(const AppSettings(), pauseLive: true),
      AccentMode.pause,
    );
  });

  test('the base modes and One Reel map one to one', () {
    expect(
      accentModeOf(const AppSettings(), pauseLive: false),
      AccentMode.blockAll,
    );
    expect(
      accentModeOf(
        const AppSettings(activePlan: BlockingPlan.curious),
        pauseLive: false,
      ),
      AccentMode.conscious,
    );
    expect(
      accentModeOf(
        const AppSettings(activePlan: BlockingPlan.oneReel),
        pauseLive: false,
      ),
      AccentMode.oneReel,
    );
  });

  test('an N-reel unblock lights Pause, as the Today screen does', () {
    expect(
      accentModeOf(
        const AppSettings(activePlan: BlockingPlan.oneReel, reelAllowance: 5),
        pauseLive: false,
      ),
      AccentMode.pause,
    );
  });
}
