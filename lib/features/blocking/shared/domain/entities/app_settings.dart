import 'package:equatable/equatable.dart';

import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';

/// The user's blocking configuration. This is the single object Dart persists
/// locally and pushes to the native engine; the service reads from it.
class AppSettings extends Equatable {
  const AppSettings({
    this.activePlan = BlockingPlan.blockAll,
    this.defaultBlockMode = BlockingMode.pressBack,
    this.enabledPlatformIds = const {},
    this.vibrationEnabled = true,
    this.masterEnabled = true,
    this.pauseUntil,
    this.onboarded = false,
  });

  final BlockingPlan activePlan;
  final BlockingMode defaultBlockMode;
  final Set<String> enabledPlatformIds;
  final bool vibrationEnabled;
  final bool masterEnabled;

  /// When set and in the future, blocking is suspended (a live pause window).
  final DateTime? pauseUntil;
  final bool onboarded;

  bool get isPaused =>
      pauseUntil != null && pauseUntil!.isAfter(DateTime.now());

  AppSettings copyWith({
    BlockingPlan? activePlan,
    BlockingMode? defaultBlockMode,
    Set<String>? enabledPlatformIds,
    bool? vibrationEnabled,
    bool? masterEnabled,
    DateTime? pauseUntil,
    bool clearPause = false,
    bool? onboarded,
  }) {
    return AppSettings(
      activePlan: activePlan ?? this.activePlan,
      defaultBlockMode: defaultBlockMode ?? this.defaultBlockMode,
      enabledPlatformIds: enabledPlatformIds ?? this.enabledPlatformIds,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      masterEnabled: masterEnabled ?? this.masterEnabled,
      pauseUntil: clearPause ? null : (pauseUntil ?? this.pauseUntil),
      onboarded: onboarded ?? this.onboarded,
    );
  }

  Map<String, dynamic> toJson() => {
        'activePlan': activePlan.wire,
        'defaultBlockMode': defaultBlockMode.wire,
        'enabledPlatformIds': enabledPlatformIds.toList(),
        'vibrationEnabled': vibrationEnabled,
        'masterEnabled': masterEnabled,
        'pauseUntil': pauseUntil?.millisecondsSinceEpoch,
        'onboarded': onboarded,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        activePlan: BlockingPlan.fromWire(json['activePlan'] as String?),
        defaultBlockMode: BlockingMode.fromWire(json['defaultBlockMode'] as String?),
        enabledPlatformIds:
            ((json['enabledPlatformIds'] as List?)?.cast<String>() ?? const [])
                .toSet(),
        vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
        masterEnabled: json['masterEnabled'] as bool? ?? true,
        pauseUntil: json['pauseUntil'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(json['pauseUntil'] as int),
        onboarded: json['onboarded'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [
        activePlan,
        defaultBlockMode,
        enabledPlatformIds,
        vibrationEnabled,
        masterEnabled,
        pauseUntil,
        onboarded,
      ];
}
