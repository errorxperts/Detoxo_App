import 'package:equatable/equatable.dart';

/// The block screen's on/off switch and the options it shows.
///
/// Persisted natively in `ConfigStore` (`block_screen_style`, as JSON) and
/// pushed over `setBlockScreenStyle`; the native renderer and the Flutter
/// `BlockScreenPreview` both render from these fields. The look is not here:
/// the wall follows the app theme (Face Down when it is light, Spotlight when
/// it is dark) and takes the theme primary as its accent.
class BlockScreenStyle extends Equatable {
  const BlockScreenStyle({
    this.enabled = true,
    this.showCount = true,
    this.showOpens = true,
    this.backDelaySec = 5,
  });

  const BlockScreenStyle.defaults() : this();

  /// Tolerant: a wrong-typed field takes its default rather than throwing —
  /// a malformed persisted style must never leave the wall unconfigurable.
  /// The keys an older build wrote (`theme`, `background`, `design`,
  /// `accentByUsage`) are ignored.
  factory BlockScreenStyle.fromWire(Map<String, dynamic>? m) {
    if (m == null || m.isEmpty) return const BlockScreenStyle.defaults();
    return BlockScreenStyle(
      enabled: _bool(m['enabled'], true),
      showCount: _bool(m['showCount'], true),
      showOpens: _bool(m['showOpens'], true),
      backDelaySec: _int(m['backDelaySec'], 5).clamp(0, 60),
    );
  }

  /// Off → blocks fall back to the toast + Back/Home they always had.
  final bool enabled;

  /// Show "N reels today" on reel blocks.
  final bool showCount;

  /// Show "Instagram opened N times today" from the usage layer (EVO-027).
  final bool showOpens;

  /// Seconds before "Back to {app}" unlocks (EVO-025); 0 = instant.
  final int backDelaySec;

  BlockScreenStyle copyWith({
    bool? enabled,
    bool? showCount,
    bool? showOpens,
    int? backDelaySec,
  }) => BlockScreenStyle(
    enabled: enabled ?? this.enabled,
    showCount: showCount ?? this.showCount,
    showOpens: showOpens ?? this.showOpens,
    backDelaySec: backDelaySec ?? this.backDelaySec,
  );

  Map<String, dynamic> toWire() => {
    'enabled': enabled,
    'showCount': showCount,
    'showOpens': showOpens,
    'backDelaySec': backDelaySec,
  };

  @override
  List<Object?> get props => [enabled, showCount, showOpens, backDelaySec];
}

bool _bool(Object? v, bool fallback) => v is bool ? v : fallback;
int _int(Object? v, int fallback) => v is num ? v.toInt() : fallback;
