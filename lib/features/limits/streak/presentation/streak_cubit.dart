import 'package:detoxo/features/limits/streak/domain/entities/streak.dart';
import 'package:detoxo/features/limits/streak/domain/repositories/streak_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Tracks the "days under your daily limit" streak with a device-local midnight
/// rollover. [observe] is fed today's under-limit status by the dashboard hero
/// (which already computes usage vs. limit); the streak advances once per day
/// and resets when a day is skipped or the limit is exceeded.
class StreakCubit extends Cubit<Streak> {
  StreakCubit(this._repo) : super(const Streak());

  final StreakRepository _repo;

  static final DateFormat _fmt = DateFormat('dd-MM-yyyy');
  static String _sig(DateTime d) => _fmt.format(d);

  Future<void> load() async => emit(await _repo.load());

  /// Reconciles the streak for [now] given whether today is under the limit.
  /// A cheap no-op when nothing changes (bloc skips equal states).
  Future<void> observe({required DateTime now, required bool underLimit}) async {
    final today = DateTime(now.year, now.month, now.day);
    final next = advance(
      state,
      today: _sig(today),
      yesterday: _sig(today.subtract(const Duration(days: 1))),
      underLimit: underLimit,
    );
    if (next == state) return;
    await _repo.save(next);
    emit(next);
  }

  /// Pure streak transition (extracted for tests): same-day makes a failure
  /// sticky; a consecutive under-limit day carries yesterday's committed streak
  /// forward; any gap — or a day where yesterday failed — starts fresh.
  @visibleForTesting
  static Streak advance(
    Streak s, {
    required String today,
    required String yesterday,
    required bool underLimit,
  }) {
    if (s.lastDay == today) {
      return s.copyWith(todayFailed: s.todayFailed || !underLimit);
    }
    final base = s.lastDay == yesterday && !s.todayFailed ? s.count : 0;
    return Streak(base: base, lastDay: today, todayFailed: !underLimit);
  }
}
