import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:equatable/equatable.dart';

/// A website blocklist entry. Matching logic lives in the web-blocker use case.
class WebBlockEntry extends Equatable {
  const WebBlockEntry({
    required this.pattern,
    this.matchType = WebMatchType.domain,
    this.enabled = true,
    this.blockMode = BlockingMode.pressBack,
    this.pausedUntil,
  });

  factory WebBlockEntry.fromJson(Map<String, dynamic> json) => WebBlockEntry(
        pattern: json['pattern'] as String? ?? '',
        matchType: WebMatchType.fromWire(json['matchType'] as String?),
        enabled: json['enabled'] as bool? ?? true,
        blockMode: BlockingMode.fromWire(json['blockMode'] as String?),
        pausedUntil: json['pausedUntil'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(json['pausedUntil'] as int),
      );

  final String pattern;
  final WebMatchType matchType;
  final bool enabled;
  final BlockingMode blockMode;
  final DateTime? pausedUntil;

  bool get isActive =>
      enabled && (pausedUntil == null || pausedUntil!.isBefore(DateTime.now()));

  WebBlockEntry copyWith({
    String? pattern,
    WebMatchType? matchType,
    bool? enabled,
    BlockingMode? blockMode,
    DateTime? pausedUntil,
    bool clearPause = false,
  }) =>
      WebBlockEntry(
        pattern: pattern ?? this.pattern,
        matchType: matchType ?? this.matchType,
        enabled: enabled ?? this.enabled,
        blockMode: blockMode ?? this.blockMode,
        pausedUntil: clearPause ? null : (pausedUntil ?? this.pausedUntil),
      );

  Map<String, dynamic> toJson() => {
        'pattern': pattern,
        'matchType': matchType.wire,
        'enabled': enabled,
        'blockMode': blockMode.wire,
        'pausedUntil': pausedUntil?.millisecondsSinceEpoch,
      };

  @override
  List<Object?> get props => [pattern, matchType, enabled, blockMode, pausedUntil];
}
