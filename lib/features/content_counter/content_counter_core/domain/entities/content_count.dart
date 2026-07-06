import 'package:detoxo/features/content_counter/content_counter_core/domain/entities/app_content_count.dart';
import 'package:equatable/equatable.dart';

/// Snapshot of the short-video / reel counter: today + all-time totals and the
/// per-app breakdowns (each list sorted by count, descending).
class ContentCount extends Equatable {
  const ContentCount({
    this.today = 0,
    this.total = 0,
    this.enabled = true,
    this.bubbleEnabled = true,
    this.perAppToday = const [],
    this.perAppTotal = const [],
  });

  /// A safe zero-state used before the first pull and off-Android.
  const ContentCount.empty()
      : today = 0,
        total = 0,
        enabled = true,
        bubbleEnabled = true,
        perAppToday = const [],
        perAppTotal = const [];

  final int today;
  final int total;
  final bool enabled;
  final bool bubbleEnabled;
  final List<AppContentCount> perAppToday;
  final List<AppContentCount> perAppTotal;

  bool get isEmpty => today == 0 && total == 0;

  @override
  List<Object?> get props =>
      [today, total, enabled, bubbleEnabled, perAppToday, perAppTotal];
}
