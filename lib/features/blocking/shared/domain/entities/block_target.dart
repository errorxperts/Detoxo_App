import 'package:equatable/equatable.dart';

import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';

/// A user-facing, blockable content surface (e.g. "Instagram Reels"), derived
/// from the platform config. Drives the dashboard blocklist toggles.
class BlockTarget extends Equatable {
  const BlockTarget({
    required this.platformId,
    required this.packageName,
    required this.appName,
    required this.displayName,
    required this.iconUrl,
    required this.detectionType,
    required this.supportedModes,
    required this.premiumExclusive,
    required this.defaultEnabled,
    required this.isBrowser,
  });

  final String platformId;
  final String packageName;
  final String appName;
  final String displayName;
  final String iconUrl;
  final DetectionType detectionType;
  final List<BlockingMode> supportedModes;
  final bool premiumExclusive;
  final bool defaultEnabled;
  final bool isBrowser;

  @override
  List<Object?> get props => [platformId, packageName, displayName];
}
