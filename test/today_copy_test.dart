import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/blocking/blocking.dart';
import 'package:detoxo/features/blocking/plans/domain/entities/conscious_state.dart';
import 'package:detoxo/features/dashboard/dashboard.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 23, 18);

/// A 10 min break with 9:42 left at [_now].
final _pause = PauseSession(
  startedAt: _now.subtract(const Duration(seconds: 18)),
  pauseDuration: const Duration(minutes: 10),
  cooldownDuration: Duration.zero,
  planToResume: BlockingPlan.blockAll,
);

RingFace _ring({
  bool loaded = true,
  bool measured = true,
  Duration spent = const Duration(minutes: 45),
  Duration limit = const Duration(hours: 3),
  PauseSession? pause,
  ({int left, int total})? reels,
}) => ringFace(
  loaded: loaded,
  measured: measured,
  spent: spent,
  limit: limit,
  now: _now,
  pause: pause,
  reels: reels,
);

String? _value(RingFace f) => f.value == null ? null : f.format(f.value!);

ModeCopy _copy(
  int index, {
  bool masterOn = true,
  PauseSession? pause,
  ({int left, int total})? reels,
  ConsciousState? conscious,
}) => modeCopy(
  index: index,
  masterOn: masterOn,
  now: _now,
  pause: pause,
  reels: reels,
  conscious: conscious,
);

void main() {
  group('ringFace', () {
    test('normal: time left of the limit', () {
      final f = _ring();
      expect(f.eyebrow, 'Time left');
      expect(f.accentEyebrow, isFalse);
      expect(_value(f), '2h 15m');
      expect(f.sub, '45m of 3h used');
      expect(f.progress, 0.75);
    });

    test('over: 0m and how far over, an empty arc', () {
      final f = _ring(spent: const Duration(hours: 3, minutes: 45));
      expect(_value(f), '0m');
      expect(f.sub, '45m over your 3h limit');
      expect(f.progress, 0);
    });

    test('no limit: today so far, no arc', () {
      final f = _ring(limit: Duration.zero);
      expect(f.eyebrow, 'Today');
      expect(_value(f), '45m');
      expect(f.sub, 'No daily limit');
      expect(f.progress, isNull);
    });

    test('counting off: no number, no arc', () {
      final f = _ring(measured: false);
      expect(f.value, isNull);
      expect(f.sub, 'Counting is off');
      expect(f.progress, isNull);
    });

    test('not yet loaded: the placeholder reads normally', () {
      final f = _ring(loaded: false, measured: false);
      expect(f.eyebrow, 'Time left');
      expect(_value(f), '2h 15m');
      expect(f.progress, 0.75);
    });

    test('a live Pause: reels allowed in accent, mm:ss left', () {
      final f = _ring(pause: _pause);
      expect(f.eyebrow, 'Reels allowed');
      expect(f.accentEyebrow, isTrue);
      expect(_value(f), '09:42');
      expect(f.sub, 'of a 10 min break');
      expect(f.progress, closeTo(582 / 600, 1e-9));
    });

    test('an N-reel unblock: reels left of N', () {
      final f = _ring(reels: (left: 3, total: 5));
      expect(f.eyebrow, 'Reels allowed');
      expect(f.accentEyebrow, isTrue);
      expect(_value(f), '3');
      expect(f.sub, 'of 5 reels');
      expect(f.progress, 0.6);
    });

    test('a session wins over counting off', () {
      expect(_ring(measured: false, pause: _pause).sub, 'of a 10 min break');
    });
  });

  test('modeIndex: blockAll 0, curious 1, live pause 2, oneReel(1) 3, '
      'oneReel(5) 4', () {
    int index(AppSettings s, {bool pauseLive = false}) =>
        modeIndex(s, pauseLive: pauseLive);
    expect(index(const AppSettings()), 0);
    expect(index(const AppSettings(activePlan: BlockingPlan.curious)), 1);
    expect(index(const AppSettings(), pauseLive: true), 2);
    expect(index(const AppSettings(activePlan: BlockingPlan.oneReel)), 3);
    expect(
      index(
        const AppSettings(activePlan: BlockingPlan.oneReel, reelAllowance: 5),
      ),
      4,
    );
  });

  group('modeCopy', () {
    test('master off overrides every mode', () {
      expect(_copy(3, masterOn: false), (
        title: 'Blocking is off',
        detail: 'Turn it on in Settings',
      ));
    });

    test('Block All and One Reel', () {
      expect(_copy(0), (
        title: 'All reels blocked',
        detail: 'Across every app on your list',
      ));
      expect(_copy(3), (
        title: 'One reel left',
        detail: 'Blocked again once it ends',
      ));
    });

    test('Pause: when blocking resumes; N reels: how many are left', () {
      expect(_copy(2, pause: _pause), (
        title: 'Reels allowed',
        detail: 'Blocking resumes in 09:42',
      ));
      expect(
        _copy(4, reels: (left: 3, total: 5)).detail,
        '3 reels left, then blocked again',
      );
      expect(
        _copy(4, reels: (left: 1, total: 5)).detail,
        '1 reel left, then blocked again',
      );
    });

    test('Conscious: spending, banked, else earning', () {
      const bank = 4 * 60000 + 12000;
      expect(
        _copy(
          1,
          conscious: const ConsciousState(bankMs: bank, watching: true),
        ).detail,
        'Spending banked time, 04:12 left',
      );
      expect(
        _copy(1, conscious: const ConsciousState(bankMs: bank)).detail,
        '04:12 banked to spend',
      );
      expect(
        _copy(1, conscious: const ConsciousState()).detail,
        'Earning 1 min for every 10 min away',
      );
      expect(_copy(1).title, 'Conscious mode');
    });
  });

  test('blockerStatus: empty is Not set up, off is Paused, else On', () {
    expect(
      blockerStatus(total: 0, enabled: 0, masterOn: true),
      BlockerStatus.notSetUp,
    );
    expect(
      blockerStatus(total: 3, enabled: 3, masterOn: false),
      BlockerStatus.paused,
    );
    expect(
      blockerStatus(total: 3, enabled: 0, masterOn: true),
      BlockerStatus.paused,
    );
    expect(
      blockerStatus(total: 3, enabled: 1, masterOn: true),
      BlockerStatus.on,
    );
  });
}
