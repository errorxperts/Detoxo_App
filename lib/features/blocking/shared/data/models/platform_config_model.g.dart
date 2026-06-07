// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_config_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlatformConfigModel _$PlatformConfigModelFromJson(Map<String, dynamic> json) =>
    _PlatformConfigModel(
      responseCode: (json['responsecode'] as num?)?.toInt() ?? 200,
      featuredApps:
          (json['featuredApps'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(
              k,
              AppDetailsModel.fromJson(e as Map<String, dynamic>),
            ),
          ) ??
          const <String, AppDetailsModel>{},
    );

Map<String, dynamic> _$PlatformConfigModelToJson(
  _PlatformConfigModel instance,
) => <String, dynamic>{
  'responsecode': instance.responseCode,
  'featuredApps': instance.featuredApps,
};

_AppDetailsModel _$AppDetailsModelFromJson(Map<String, dynamic> json) =>
    _AppDetailsModel(
      packageName: json['packageName'] as String,
      appName: json['appName'] as String? ?? '',
      actionOnLaunch: json['actionOnLaunch'] as String? ?? 'NONE',
      paramsClass: (json['paramsClass'] as num?)?.toInt() ?? -1,
      params: json['params'] as String? ?? '{}',
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      iconUrl: json['iconUrl'] as String? ?? '',
      premiumExclusive: json['premiumExclusive'] as bool? ?? false,
      minAppVersion: (json['minAppVersion'] as num?)?.toInt() ?? -1,
      maxAppVersion: (json['maxAppVersion'] as num?)?.toInt() ?? -1,
      supportInAppYtShorts: json['supportInAppYtShorts'] as bool? ?? false,
      platforms:
          (json['platforms'] as List<dynamic>?)
              ?.map((e) => PlatformModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <PlatformModel>[],
      showInDashboard: json['showInDashboard'] as bool? ?? false,
      showIfNotInstalled: json['showIfNotInstalled'] as bool? ?? false,
      appOpenActions:
          (json['appOpenActions'] as List<dynamic>?)
              ?.map(
                (e) => AppOpenActionModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <AppOpenActionModel>[],
      isBrowser: json['browser'] as bool? ?? false,
    );

Map<String, dynamic> _$AppDetailsModelToJson(_AppDetailsModel instance) =>
    <String, dynamic>{
      'packageName': instance.packageName,
      'appName': instance.appName,
      'actionOnLaunch': instance.actionOnLaunch,
      'paramsClass': instance.paramsClass,
      'params': instance.params,
      'priority': instance.priority,
      'iconUrl': instance.iconUrl,
      'premiumExclusive': instance.premiumExclusive,
      'minAppVersion': instance.minAppVersion,
      'maxAppVersion': instance.maxAppVersion,
      'supportInAppYtShorts': instance.supportInAppYtShorts,
      'platforms': instance.platforms,
      'showInDashboard': instance.showInDashboard,
      'showIfNotInstalled': instance.showIfNotInstalled,
      'appOpenActions': instance.appOpenActions,
      'browser': instance.isBrowser,
    };

_PlatformModel _$PlatformModelFromJson(Map<String, dynamic> json) =>
    _PlatformModel(
      platformId: json['platformId'] as String,
      packageName: json['packageName'] as String? ?? '',
      platformName: json['platformName'] as String? ?? '',
      iconUrl: json['iconUrl'] as String? ?? '',
      detectors:
          (json['detectors'] as Map<String, dynamic>?)?.map(
            (k, e) =>
                MapEntry(k, DetectorModel.fromJson(e as Map<String, dynamic>)),
          ) ??
          const <String, DetectorModel>{},
      detectionType: json['detectionType'] as String? ?? 'LEGACY',
      defaultStatus: json['defaultStatus'] as bool? ?? true,
      customizable: json['customizable'] as bool? ?? true,
      showInDashboard: json['showInDashboard'] as bool? ?? false,
      showAlwaysInBlockList: json['showAlwaysInBlockList'] as bool? ?? false,
      premiumExclusive: json['premiumExclusive'] as bool? ?? false,
    );

Map<String, dynamic> _$PlatformModelToJson(_PlatformModel instance) =>
    <String, dynamic>{
      'platformId': instance.platformId,
      'packageName': instance.packageName,
      'platformName': instance.platformName,
      'iconUrl': instance.iconUrl,
      'detectors': instance.detectors,
      'detectionType': instance.detectionType,
      'defaultStatus': instance.defaultStatus,
      'customizable': instance.customizable,
      'showInDashboard': instance.showInDashboard,
      'showAlwaysInBlockList': instance.showAlwaysInBlockList,
      'premiumExclusive': instance.premiumExclusive,
    };

_DetectorModel _$DetectorModelFromJson(Map<String, dynamic> json) =>
    _DetectorModel(
      supportedBlockModes:
          (json['supportedBlockModes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      defaultBlockMode: json['defaultBlockMode'] as String? ?? 'PRESS_BACK',
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      identifiers:
          (json['identifiers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      childNodeLimit: (json['childNodeLimit'] as num?)?.toInt() ?? -1,
      actionOnLaunch: json['actionOnLaunch'] as String? ?? 'NONE',
      paramsClass: (json['paramsClass'] as num?)?.toInt() ?? 0,
      params: json['params'] as String? ?? '',
      message: json['message'] as String? ?? '',
      haltOnDetect: json['haltOnDetect'] as bool? ?? true,
      coupleWith:
          (json['coupleWith'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$DetectorModelToJson(_DetectorModel instance) =>
    <String, dynamic>{
      'supportedBlockModes': instance.supportedBlockModes,
      'defaultBlockMode': instance.defaultBlockMode,
      'priority': instance.priority,
      'identifiers': instance.identifiers,
      'childNodeLimit': instance.childNodeLimit,
      'actionOnLaunch': instance.actionOnLaunch,
      'paramsClass': instance.paramsClass,
      'params': instance.params,
      'message': instance.message,
      'haltOnDetect': instance.haltOnDetect,
      'coupleWith': instance.coupleWith,
    };

_AppOpenActionModel _$AppOpenActionModelFromJson(Map<String, dynamic> json) =>
    _AppOpenActionModel(
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
    );

Map<String, dynamic> _$AppOpenActionModelToJson(_AppOpenActionModel instance) =>
    <String, dynamic>{'name': instance.name, 'url': instance.url};

_OverlayParamsModel _$OverlayParamsModelFromJson(Map<String, dynamic> json) =>
    _OverlayParamsModel(
      primaryId: json['primary_id'] as String? ?? '',
      config: json['config'] == null
          ? const OverlayConfigModel()
          : OverlayConfigModel.fromJson(json['config'] as Map<String, dynamic>),
      primaryAddons:
          (json['primary_addons'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$OverlayParamsModelToJson(_OverlayParamsModel instance) =>
    <String, dynamic>{
      'primary_id': instance.primaryId,
      'config': instance.config,
      'primary_addons': instance.primaryAddons,
    };

_OverlayConfigModel _$OverlayConfigModelFromJson(Map<String, dynamic> json) =>
    _OverlayConfigModel(
      curiousSupport: json['curious_support'] as bool? ?? false,
      blockAllSupport: json['block_all_support'] as bool? ?? false,
      overlaySupport: json['overlay_support'] as bool? ?? false,
      blackoutMessage: json['blackout_message'] as String? ?? '',
    );

Map<String, dynamic> _$OverlayConfigModelToJson(_OverlayConfigModel instance) =>
    <String, dynamic>{
      'curious_support': instance.curiousSupport,
      'block_all_support': instance.blockAllSupport,
      'overlay_support': instance.overlaySupport,
      'blackout_message': instance.blackoutMessage,
    };
