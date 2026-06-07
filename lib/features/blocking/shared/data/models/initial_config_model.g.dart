// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'initial_config_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_InitialConfigModel _$InitialConfigModelFromJson(
  Map<String, dynamic> json,
) => _InitialConfigModel(
  versionAvailability: json['versionAvailability'] == null
      ? null
      : VersionAvailabilityModel.fromJson(
          json['versionAvailability'] as Map<String, dynamic>,
        ),
  inappNotification:
      (json['inappNotification'] as List<dynamic>?)
          ?.map(
            (e) => InAppNotificationModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const <InAppNotificationModel>[],
  warningMessages:
      (json['warningMessages'] as List<dynamic>?)
          ?.map(
            (e) => InAppNotificationModel.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const <InAppNotificationModel>[],
  admobConfig:
      (json['admobConfig'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, AdSlotModel.fromJson(e as Map<String, dynamic>)),
      ) ??
      const <String, AdSlotModel>{},
  activePlanDetails: json['activePlanDetails'] == null
      ? null
      : ActivePlanDetailsModel.fromJson(
          json['activePlanDetails'] as Map<String, dynamic>,
        ),
  premiumPurchaseCTA: json['premiumPurchaseCTA'] == null
      ? null
      : PromoCtaModel.fromJson(
          json['premiumPurchaseCTA'] as Map<String, dynamic>,
        ),
  featuresAvailability:
      (json['featuresAvailability'] as Map<String, dynamic>?)?.map(
        (k, e) =>
            MapEntry(k, FeatureFlagModel.fromJson(e as Map<String, dynamic>)),
      ) ??
      const <String, FeatureFlagModel>{},
  platformConfigVersion: (json['platformConfigVersion'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$InitialConfigModelToJson(_InitialConfigModel instance) =>
    <String, dynamic>{
      'versionAvailability': instance.versionAvailability,
      'inappNotification': instance.inappNotification,
      'warningMessages': instance.warningMessages,
      'admobConfig': instance.admobConfig,
      'activePlanDetails': instance.activePlanDetails,
      'premiumPurchaseCTA': instance.premiumPurchaseCTA,
      'featuresAvailability': instance.featuresAvailability,
      'platformConfigVersion': instance.platformConfigVersion,
    };

_VersionAvailabilityModel _$VersionAvailabilityModelFromJson(
  Map<String, dynamic> json,
) => _VersionAvailabilityModel(
  versionInfo: json['versionInfo'] == null
      ? null
      : VersionInfoModel.fromJson(json['versionInfo'] as Map<String, dynamic>),
  warningCode: json['warningCode'] as String? ?? '',
  title: json['title'] as String? ?? '',
  desc: json['desc'] as String? ?? '',
  icon: json['icon'] as String? ?? '',
  available: json['available'] as bool? ?? false,
);

Map<String, dynamic> _$VersionAvailabilityModelToJson(
  _VersionAvailabilityModel instance,
) => <String, dynamic>{
  'versionInfo': instance.versionInfo,
  'warningCode': instance.warningCode,
  'title': instance.title,
  'desc': instance.desc,
  'icon': instance.icon,
  'available': instance.available,
};

_VersionInfoModel _$VersionInfoModelFromJson(Map<String, dynamic> json) =>
    _VersionInfoModel(
      versionCode: (json['versionCode'] as num?)?.toInt() ?? 0,
      versionName: json['versionName'] as String? ?? '',
      promptUpdate: json['promptUpdate'] as bool? ?? false,
      forceUpdate: json['forceUpdate'] as bool? ?? false,
      beta: json['beta'] as bool? ?? false,
      changelog: json['changelog'] as String? ?? '',
    );

Map<String, dynamic> _$VersionInfoModelToJson(_VersionInfoModel instance) =>
    <String, dynamic>{
      'versionCode': instance.versionCode,
      'versionName': instance.versionName,
      'promptUpdate': instance.promptUpdate,
      'forceUpdate': instance.forceUpdate,
      'beta': instance.beta,
      'changelog': instance.changelog,
    };

_InAppNotificationModel _$InAppNotificationModelFromJson(
  Map<String, dynamic> json,
) => _InAppNotificationModel(
  notificationId: json['notificationId'] as String,
  title: json['title'] as String? ?? '',
  description: json['description'] as String? ?? '',
  cta: json['cta'] as String? ?? '',
  priority: (json['priority'] as num?)?.toInt() ?? 0,
  ctaAction: json['ctaAction'] as String? ?? '',
  ctaUrl: json['ctaUrl'] as String? ?? '',
  metadata: json['metadata'] as String? ?? '',
  expiry: (json['expiry'] as num?)?.toInt() ?? 0,
  icon: json['icon'] as String? ?? '',
  premiumExclusive: json['premiumExclusive'] as bool? ?? false,
  guestExclusive: json['guestExclusive'] as bool? ?? false,
  dismissible: json['dismissible'] as bool? ?? true,
);

Map<String, dynamic> _$InAppNotificationModelToJson(
  _InAppNotificationModel instance,
) => <String, dynamic>{
  'notificationId': instance.notificationId,
  'title': instance.title,
  'description': instance.description,
  'cta': instance.cta,
  'priority': instance.priority,
  'ctaAction': instance.ctaAction,
  'ctaUrl': instance.ctaUrl,
  'metadata': instance.metadata,
  'expiry': instance.expiry,
  'icon': instance.icon,
  'premiumExclusive': instance.premiumExclusive,
  'guestExclusive': instance.guestExclusive,
  'dismissible': instance.dismissible,
};

_AdSlotModel _$AdSlotModelFromJson(Map<String, dynamic> json) => _AdSlotModel(
  adTag: json['adTag'] as String? ?? '',
  adType: json['adType'] as String? ?? 'BANNER',
);

Map<String, dynamic> _$AdSlotModelToJson(_AdSlotModel instance) =>
    <String, dynamic>{'adTag': instance.adTag, 'adType': instance.adType};

_ActivePlanDetailsModel _$ActivePlanDetailsModelFromJson(
  Map<String, dynamic> json,
) => _ActivePlanDetailsModel(
  aiFeatures: json['aiFeatures'] as bool? ?? false,
  blockAds: json['blockAds'] as bool? ?? false,
  premiumFeatures: json['premiumFeatures'] as bool? ?? false,
  parentalFeatures: json['parentalFeatures'] as bool? ?? false,
  topTierPlan: json['topTierPlan'] as bool? ?? false,
  promptUpgrades: json['promptUpgrades'] as bool? ?? true,
  plans:
      (json['plans'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
);

Map<String, dynamic> _$ActivePlanDetailsModelToJson(
  _ActivePlanDetailsModel instance,
) => <String, dynamic>{
  'aiFeatures': instance.aiFeatures,
  'blockAds': instance.blockAds,
  'premiumFeatures': instance.premiumFeatures,
  'parentalFeatures': instance.parentalFeatures,
  'topTierPlan': instance.topTierPlan,
  'promptUpgrades': instance.promptUpgrades,
  'plans': instance.plans,
};

_PromoCtaModel _$PromoCtaModelFromJson(Map<String, dynamic> json) =>
    _PromoCtaModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      desc: json['desc'] as String? ?? '',
      cta: json['cta'] as String? ?? '',
      whatsNew: json['whatsNew'] as String? ?? '',
      active: json['active'] as bool? ?? false,
    );

Map<String, dynamic> _$PromoCtaModelToJson(_PromoCtaModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'desc': instance.desc,
      'cta': instance.cta,
      'whatsNew': instance.whatsNew,
      'active': instance.active,
    };

_FeatureFlagModel _$FeatureFlagModelFromJson(Map<String, dynamic> json) =>
    _FeatureFlagModel(
      featureId: json['featureId'] as String,
      minOSVersion: (json['minOSVersion'] as num?)?.toInt() ?? 0,
      maxOSVersion: (json['maxOSVersion'] as num?)?.toInt() ?? 999,
      params: json['params'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      premiumOnly: json['premiumOnly'] as bool? ?? false,
    );

Map<String, dynamic> _$FeatureFlagModelToJson(_FeatureFlagModel instance) =>
    <String, dynamic>{
      'featureId': instance.featureId,
      'minOSVersion': instance.minOSVersion,
      'maxOSVersion': instance.maxOSVersion,
      'params': instance.params,
      'enabled': instance.enabled,
      'premiumOnly': instance.premiumOnly,
    };
