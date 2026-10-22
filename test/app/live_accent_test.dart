import 'package:detoxo/app/live_accent.dart';
import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/blocking/blocking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
