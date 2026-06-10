import 'dart:convert';

import 'package:detoxo/core/constants/app_constants.dart';
import 'package:detoxo/features/blocking/shared/data/models/initial_config_model.dart';
import 'package:detoxo/features/blocking/shared/data/models/platform_config_model.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/app_notice.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/block_target.dart';
import 'package:detoxo/features/blocking/shared/domain/entities/enums.dart';
import 'package:detoxo/features/blocking/shared/domain/repositories/blocking_repositories.dart';
import 'package:flutter/services.dart';

/// Offline-first config: reads the bundled JSON assets. A remote refresh can be
/// layered in later behind the same interface (see networking doc) — the rest of
/// the app is unaffected.
class ConfigRepositoryImpl implements ConfigRepository {
  ConfigRepositoryImpl({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  String? _cachedRaw;
  PlatformConfigModel? _cachedConfig;

  Future<PlatformConfigModel> _config() async {
    if (_cachedConfig != null) return _cachedConfig!;
    final raw = await rawConfigJson();
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return _cachedConfig = PlatformConfigModel.fromJson(map);
  }

  @override
  Future<String> rawConfigJson() async =>
      _cachedRaw ??= await _bundle.loadString(AppConstants.bundledPlatformsConfig);

  @override
  Future<List<BlockTarget>> loadBlockTargets() async {
    final config = await _config();
    final targets = <BlockTarget>[];
    for (final app in config.featuredApps.values) {
      for (final platform in app.platforms) {
        if (!platform.showInDashboard && !platform.showAlwaysInBlockList) continue;
        targets.add(_toTarget(app, platform));
      }
    }
    targets.sort((a, b) => a.appName.compareTo(b.appName));
    return targets;
  }

  BlockTarget _toTarget(AppDetailsModel app, PlatformModel platform) {
    final modes = <BlockingMode>{};
    for (final detector in platform.detectors.values) {
      for (final m in detector.supportedBlockModes) {
        modes.add(BlockingMode.fromWire(m));
      }
    }
    if (modes.isEmpty) modes.add(BlockingMode.pressBack);
    return BlockTarget(
      platformId: platform.platformId,
      packageName: platform.packageName.isNotEmpty
          ? platform.packageName
          : app.packageName,
      appName: app.appName,
      displayName: platform.platformName.isNotEmpty
          ? platform.platformName
          : app.appName,
      iconUrl: platform.iconUrl.isNotEmpty ? platform.iconUrl : app.iconUrl,
      detectionType: DetectionType.fromWire(platform.detectionType),
      supportedModes: modes.toList(),
      premiumExclusive: platform.premiumExclusive,
      defaultEnabled: platform.defaultStatus,
      isBrowser: app.isBrowser,
    );
  }

  @override
  Future<List<AppNotice>> loadNotices() async {
    try {
      final raw = await _bundle.loadString(AppConstants.bundledInitialConfig);
      final model = InitialConfigModel.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      return model.inappNotification
          .map(
            (n) => AppNotice(
              id: n.notificationId,
              title: n.title,
              description: n.description,
              cta: n.cta,
              action: n.ctaAction,
              url: n.ctaUrl,
              dismissible: n.dismissible,
            ),
          )
          .toList();
    } on Exception {
      return const [];
    }
  }
}
