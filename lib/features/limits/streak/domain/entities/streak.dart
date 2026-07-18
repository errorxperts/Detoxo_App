import 'package:equatable/equatable.dart';

/// "Days under your daily limit" streak, with a device-local midnight rollover
/// keyed by a date signature.
///
/// [base] is the streak length completed **before** today. Today is counted
/// optimistically while still under the limit — [count] adds 1 — and drops that
/// +1 the moment the limit is exceeded ([todayFailed]). A skipped day resets on
/// the next evaluation. The transition mechanics live in `StreakCubit.advance`.
class Streak extends Equatable {
  const Streak({this.base = 0, this.lastDay = '', this.todayFailed = true});

  factory Streak.fromJson(Map<String, dynamic> json) => Streak(
        base: json['base'] as int? ?? 0,
        lastDay: json['lastDay'] as String? ?? '',
        todayFailed: json['todayFailed'] as bool? ?? true,
      );

  /// Consecutive under-limit days completed before today.
  final int base;

  /// Date signature ("dd-MM-yyyy") of the last day the streak was evaluated.
  final String lastDay;

  /// Whether today has already broken the streak (limit exceeded, or no limit
  /// set). Sticky within a day.
  final bool todayFailed;

  /// The user-facing streak: prior days, plus today while it still qualifies.
  int get count => base + (todayFailed ? 0 : 1);

  Streak copyWith({int? base, String? lastDay, bool? todayFailed}) => Streak(
        base: base ?? this.base,
        lastDay: lastDay ?? this.lastDay,
        todayFailed: todayFailed ?? this.todayFailed,
      );

  Map<String, dynamic> toJson() => {
        'base': base,
        'lastDay': lastDay,
        'todayFailed': todayFailed,
      };

  @override
  List<Object?> get props => [base, lastDay, todayFailed];
}
