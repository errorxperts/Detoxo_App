import 'package:equatable/equatable.dart';

/// Per-day usage quota with midnight reset keyed by a date signature.
class DailyLimit extends Equatable {
  const DailyLimit({
    this.limit = Duration.zero,
    this.consumed = Duration.zero,
    this.dateSignature = '',
  });

  factory DailyLimit.fromJson(Map<String, dynamic> json) => DailyLimit(
        limit: Duration(milliseconds: json['limitMs'] as int? ?? 0),
        consumed: Duration(milliseconds: json['consumedMs'] as int? ?? 0),
        dateSignature: json['dateSignature'] as String? ?? '',
      );

  final Duration limit;
  final Duration consumed;
  final String dateSignature;

  bool get isExceeded => limit > Duration.zero && consumed >= limit;
  Duration get remaining {
    final r = limit - consumed;
    return r.isNegative ? Duration.zero : r;
  }

  /// Returns a reset copy if the date changed, else this.
  DailyLimit refreshed(String todaySignature) {
    if (dateSignature == todaySignature) return this;
    return DailyLimit(
      limit: limit,
      dateSignature: todaySignature,
    );
  }

  DailyLimit copyWith({Duration? limit, Duration? consumed, String? dateSignature}) =>
      DailyLimit(
        limit: limit ?? this.limit,
        consumed: consumed ?? this.consumed,
        dateSignature: dateSignature ?? this.dateSignature,
      );

  Map<String, dynamic> toJson() => {
        'limitMs': limit.inMilliseconds,
        'consumedMs': consumed.inMilliseconds,
        'dateSignature': dateSignature,
      };

  @override
  List<Object?> get props => [limit, consumed, dateSignature];
}
