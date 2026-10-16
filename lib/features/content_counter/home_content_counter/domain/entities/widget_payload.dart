import 'dart:convert';
import 'dart:math' as math;

import 'package:detoxo/features/content_counter/home_content_counter/domain/widget_rules.g.dart';
import 'package:equatable/equatable.dart';

/// The IM-02 widget payload: what native `ReelWidgetSync`, the one writer
/// (IM-01), stores as `widget_payload` and answers `contentWidgetPayload`
/// with. Fields mirror the wire keys. Dart only reads it; the previews draw
/// from it through `WidgetModel`.
class WidgetPayload extends Equatable {
  const WidgetPayload({
    this.reelCount = 0,
    this.watchSeconds = 0,
    this.reelTier = 0,
    this.hourlySeconds = _quietDay,
    this.limitMinutes = 0,
    this.theme = 'system',
    this.reduceMotion = false,
    this.updatedAt = 0,
    this.trackingEnabled = true,
  });

  /// 152 reels at tier 2 over 1h 10m: the picker and pin previews pass
  /// `(120, 'system', true, now)`, the in-app preview the real limit, theme
  /// and reduce motion.
  factory WidgetPayload.demo({
    required int limitMinutes,
    required String theme,
    required bool reduceMotion,
    required int nowMs,
  }) => WidgetPayload(
    reelCount: 152,
    watchSeconds: 4256,
    reelTier: 2,
    hourlySeconds: _demoDay,
    limitMinutes: limitMinutes,
    theme: theme,
    reduceMotion: reduceMotion,
    updatedAt: nowMs,
  );

  /// The shared fail-safe reader, pinned with Kotlin `WidgetPayload.parse` by
  /// `test/fixtures/home_widget_payloads.json`. Anything but a JSON object is
  /// [empty]. Each key falls back to its default when missing or of the wrong
  /// type, checked strictly (`"12"` is no number, `1` no bool). Numbers
  /// truncate toward zero and floor at 0, the tier clamps to
  /// 0..[WidgetRules.maxTier], the limit to a day
  /// (0..[WidgetRules.maxLimitMinutes]), and `hourly_seconds` must be exactly
  /// 24 numbers (else all zeros), each clamped to 0..3600.
  static WidgetPayload parse(String? raw) {
    final m = _decode(raw);
    if (m is! Map<String, Object?>) return empty;
    return WidgetPayload(
      reelCount: _count(m['reel_count']),
      watchSeconds: _count(m['watch_seconds']),
      reelTier: math.min(WidgetRules.maxTier, _count(m['reel_tier'])),
      hourlySeconds: _hours(m['hourly_seconds']),
      limitMinutes: math.min(
        WidgetRules.maxLimitMinutes,
        _count(m['limit_minutes']),
      ),
      theme: _theme(m['theme']),
      reduceMotion: _bool(m['reduce_motion'], false),
      updatedAt: _count(m['updated_at']),
      trackingEnabled: _bool(m['tracking_enabled'], true),
    );
  }

  /// No reels, no limit, never updated: what a missing or corrupt payload
  /// reads as (IM-09).
  static const empty = WidgetPayload();

  /// Reels counted today.
  final int reelCount;

  /// Reel watch time today, in seconds.
  final int watchSeconds;

  /// DS-01 tier 0..5, computed only by the native writer (IM-01).
  final int reelTier;

  /// Watch seconds per local hour, index = hour 0..23.
  final List<int> hourlySeconds;

  /// The soonest active reel limit today, in minutes (0..1440 once parsed);
  /// 0 = no limit.
  final int limitMinutes;

  /// `system`, `light` or `dark`.
  final String theme;

  /// The device's "remove animations" setting.
  final bool reduceMotion;

  /// When native built the data (epoch ms); 0 = never.
  final int updatedAt;

  /// The counter is on and the accessibility service is enabled.
  final bool trackingEnabled;

  WidgetPayload copyWith({String? theme, bool? reduceMotion}) => WidgetPayload(
    reelCount: reelCount,
    watchSeconds: watchSeconds,
    reelTier: reelTier,
    hourlySeconds: hourlySeconds,
    limitMinutes: limitMinutes,
    theme: theme ?? this.theme,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    updatedAt: updatedAt,
    trackingEnabled: trackingEnabled,
  );

  @override
  List<Object?> get props => [
    reelCount,
    watchSeconds,
    reelTier,
    hourlySeconds,
    limitMinutes,
    theme,
    reduceMotion,
    updatedAt,
    trackingEnabled,
  ];
}

const List<int> _quietDay = [
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
];

/// Fixture `tier2_152`'s hours: a little all day, most of it late evening.
const List<int> _demoDay = [
  177, 59, 0, 0, 0, 0, 0, 59, 118, 59, 0, 59, //
  296, 118, 59, 0, 59, 118, 118, 177, 355, 355, 650, 1419,
];

Object? _decode(String? raw) {
  if (raw == null) return null;
  try {
    return jsonDecode(raw);
  } on FormatException {
    return null; // Corrupt text reads as Empty, like no payload at all.
  }
}

/// A JSON number truncated toward zero and floored at 0; anything else is 0.
int _count(Object? v) => v is num && v.isFinite ? math.max(0, v.toInt()) : 0;

bool _bool(Object? v, bool fallback) => v is bool ? v : fallback;

List<int> _hours(Object? v) =>
    v is List<Object?> && v.length == 24 && v.every((h) => h is num)
    ? List.unmodifiable([for (final h in v) math.min(3600, _count(h))])
    : _quietDay;

String _theme(Object? v) {
  final t = v is String ? v.toLowerCase() : '';
  return t == 'light' || t == 'dark' ? t : 'system';
}
