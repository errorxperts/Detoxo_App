import 'package:detoxo/features/limits/streak/domain/entities/streak.dart';
import 'package:detoxo/features/limits/streak/presentation/streak_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two consecutive device-local days used across the transition cases.
const _d1 = '01-01-2026';
const _d2 = '02-01-2026';
const _d3 = '03-01-2026';
const _d10 = '10-01-2026';

Streak _advance(Streak s, {required String today, required String yesterday, required bool underLimit}) =>
    StreakCubit.advance(s, today: today, yesterday: yesterday, underLimit: underLimit);

void main() {
  group('Streak entity', () {
    test('empty streak shows 0', () {
      expect(const Streak().count, 0);
    });

    test('today counts optimistically while under limit', () {
      expect(const Streak(base: 4, lastDay: _d2, todayFailed: false).count, 5);
    });

    test('a failed today drops the optimistic +1', () {
      // todayFailed defaults to true — the day has not (yet) qualified.
      expect(const Streak(base: 4, lastDay: _d2).count, 4);
    });

    test('survives a JSON round-trip', () {
      const original = Streak(base: 7, lastDay: _d2, todayFailed: false);
      expect(Streak.fromJson(original.toJson()), original);
    });
  });

  group('StreakCubit.advance', () {
    test('first under-limit day starts the streak at 1', () {
      final s = _advance(const Streak(), today: _d2, yesterday: _d1, underLimit: true);
      expect(s.count, 1);
    });

    test('exceeding the limit is sticky within the day (streak drops)', () {
      var s = _advance(const Streak(), today: _d2, yesterday: _d1, underLimit: true);
      expect(s.count, 1);
      s = _advance(s, today: _d2, yesterday: _d1, underLimit: false); // blew it
      expect(s.count, 0);
      s = _advance(s, today: _d2, yesterday: _d1, underLimit: true); // usage can't un-happen
      expect(s.count, 0, reason: 'once failed, today stays failed');
    });

    test('a consecutive under-limit day increments', () {
      var s = _advance(const Streak(), today: _d2, yesterday: _d1, underLimit: true); // 1
      s = _advance(s, today: _d3, yesterday: _d2, underLimit: true); // 2
      expect(s.count, 2);
    });

    test('a skipped day resets the streak', () {
      const built = Streak(base: 4, lastDay: _d2, todayFailed: false); // count 5
      final s = _advance(built, today: _d10, yesterday: '09-01-2026', underLimit: true);
      expect(s.count, 1);
    });

    test('a consecutive day after a failed day resets', () {
      const failedYesterday = Streak(base: 3, lastDay: _d2); // todayFailed defaults true
      final s = _advance(failedYesterday, today: _d3, yesterday: _d2, underLimit: true);
      expect(s.count, 1);
    });

    test('exceeding today holds yesterday, then the next day resets', () {
      var s = const Streak(base: 4, lastDay: _d2, todayFailed: false); // count 5
      s = _advance(s, today: _d3, yesterday: _d2, underLimit: false); // over today
      expect(s.count, 5, reason: 'yesterday committed streak is retained');
      s = _advance(s, today: '04-01-2026', yesterday: _d3, underLimit: true);
      expect(s.count, 1, reason: 'the failed day breaks the chain');
    });
  });
}
