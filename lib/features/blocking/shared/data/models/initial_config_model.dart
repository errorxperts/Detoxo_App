import 'package:freezed_annotation/freezed_annotation.dart';

part 'initial_config_model.freezed.dart';
part 'initial_config_model.g.dart';

/// Models for `initial_config.json`: feature flags, version gating, ad config,
/// in-app notifications, and premium CTA. Bundled offline + refreshed remotely.

@freezed
abstract class InitialConfigModel with _$InitialConfigModel {
  const factory InitialConfigModel({
    VersionAvailabilityModel? versionAvailability,
    @Default(<InAppNotificationModel>[])
    List<InAppNotificationModel> inappNotification,
    @Default(<InAppNotificationModel>[])
    List<InAppNotificationModel> warningMessages,
    @Default(<String, AdSlotModel>{}) Map<String, AdSlotModel> admobConfig,
    ActivePlanDetailsModel? activePlanDetails,
    PromoCtaModel? premiumPurchaseCTA,
    @Default(<String, FeatureFlagModel>{})
    Map<String, FeatureFlagModel> featuresAvailability,
    @Default(0) int platformConfigVersion,
  }) = _InitialConfigModel;

  factory InitialConfigModel.fromJson(Map<String, dynamic> json) =>
      _$InitialConfigModelFromJson(json);
}

@freezed
abstract class VersionAvailabilityModel with _$VersionAvailabilityModel {
  const factory VersionAvailabilityModel({
    VersionInfoModel? versionInfo,
    @Default('') String warningCode,
    @Default('') String title,
    @Default('') String desc,
    @Default('') String icon,
    @Default(false) bool available,
  }) = _VersionAvailabilityModel;

  factory VersionAvailabilityModel.fromJson(Map<String, dynamic> json) =>
      _$VersionAvailabilityModelFromJson(json);
}

@freezed
abstract class VersionInfoModel with _$VersionInfoModel {
  const factory VersionInfoModel({
    @Default(0) int versionCode,
    @Default('') String versionName,
    @Default(false) bool promptUpdate,
    @Default(false) bool forceUpdate,
    @Default(false) bool beta,
    @Default('') String changelog,
  }) = _VersionInfoModel;

  factory VersionInfoModel.fromJson(Map<String, dynamic> json) =>
      _$VersionInfoModelFromJson(json);
}

@freezed
abstract class InAppNotificationModel with _$InAppNotificationModel {
  const factory InAppNotificationModel({
    required String notificationId,
    @Default('') String title,
    @Default('') String description,
    @Default('') String cta,
    @Default(0) int priority,
    @Default('') String ctaAction,
    @Default('') String ctaUrl,
    @Default('') String metadata,
    @Default(0) int expiry,
    @Default('') String icon,
    @Default(false) bool premiumExclusive,
    @Default(false) bool guestExclusive,
    @Default(true) bool dismissible,
  }) = _InAppNotificationModel;

  factory InAppNotificationModel.fromJson(Map<String, dynamic> json) =>
      _$InAppNotificationModelFromJson(json);
}

@freezed
abstract class AdSlotModel with _$AdSlotModel {
  const factory AdSlotModel({
    @Default('') String adTag,
    @Default('BANNER') String adType,
  }) = _AdSlotModel;

  factory AdSlotModel.fromJson(Map<String, dynamic> json) =>
      _$AdSlotModelFromJson(json);
}

@freezed
abstract class ActivePlanDetailsModel with _$ActivePlanDetailsModel {
  const factory ActivePlanDetailsModel({
    @Default(false) bool aiFeatures,
    @Default(false) bool blockAds,
    @Default(false) bool premiumFeatures,
    @Default(false) bool parentalFeatures,
    @Default(false) bool topTierPlan,
    @Default(true) bool promptUpgrades,
    @Default(<String>[]) List<String> plans,
  }) = _ActivePlanDetailsModel;

  factory ActivePlanDetailsModel.fromJson(Map<String, dynamic> json) =>
      _$ActivePlanDetailsModelFromJson(json);
}

@freezed
abstract class PromoCtaModel with _$PromoCtaModel {
  const factory PromoCtaModel({
    @Default('') String id,
    @Default('') String title,
    @Default('') String desc,
    @Default('') String cta,
    @Default('') String whatsNew,
    @Default(false) bool active,
  }) = _PromoCtaModel;

  factory PromoCtaModel.fromJson(Map<String, dynamic> json) =>
      _$PromoCtaModelFromJson(json);
}

@freezed
abstract class FeatureFlagModel with _$FeatureFlagModel {
  const factory FeatureFlagModel({
    required String featureId,
    @Default(0) int minOSVersion,
    @Default(999) int maxOSVersion,
    @Default('') String params,
    @Default(true) bool enabled,
    @Default(false) bool premiumOnly,
  }) = _FeatureFlagModel;

  factory FeatureFlagModel.fromJson(Map<String, dynamic> json) =>
      _$FeatureFlagModelFromJson(json);
}
