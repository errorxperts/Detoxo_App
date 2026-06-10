import 'package:freezed_annotation/freezed_annotation.dart';

part 'platform_config_model.freezed.dart';
part 'platform_config_model.g.dart';

/// Data-transfer models for `platforms_config.json` (bundled offline + fetched
/// from the server). This is the contract that drives the whole detection
/// engine. Field names mirror the wire format; richer domain entities are
/// derived from these in the repository layer.

@freezed
abstract class PlatformConfigModel with _$PlatformConfigModel {
  const factory PlatformConfigModel({
    @JsonKey(name: 'responsecode') @Default(200) int responseCode,
    @Default(<String, AppDetailsModel>{})
    Map<String, AppDetailsModel> featuredApps,
  }) = _PlatformConfigModel;

  factory PlatformConfigModel.fromJson(Map<String, dynamic> json) =>
      _$PlatformConfigModelFromJson(json);
}

@freezed
abstract class AppDetailsModel with _$AppDetailsModel {
  const factory AppDetailsModel({
    required String packageName,
    @Default('') String appName,
    @Default('NONE') String actionOnLaunch,
    @Default(-1) int paramsClass,
    @Default('{}') String params,
    @Default(0) int priority,
    @Default('') String iconUrl,
    @Default(false) bool premiumExclusive,
    @Default(-1) int minAppVersion,
    @Default(-1) int maxAppVersion,
    @Default(false) bool supportInAppYtShorts,
    @Default(<PlatformModel>[]) List<PlatformModel> platforms,
    @Default(false) bool showInDashboard,
    @Default(false) bool showIfNotInstalled,
    @Default(<AppOpenActionModel>[]) List<AppOpenActionModel> appOpenActions,
    @JsonKey(name: 'browser') @Default(false) bool isBrowser,
  }) = _AppDetailsModel;

  factory AppDetailsModel.fromJson(Map<String, dynamic> json) =>
      _$AppDetailsModelFromJson(json);
}

@freezed
abstract class PlatformModel with _$PlatformModel {
  const factory PlatformModel({
    required String platformId,
    @Default('') String packageName,
    @Default('') String platformName,
    @Default('') String iconUrl,
    @Default(<String, DetectorModel>{}) Map<String, DetectorModel> detectors,
    @Default('LEGACY') String detectionType,
    @Default(true) bool defaultStatus,
    @Default(true) bool customizable,
    @Default(false) bool showInDashboard,
    @Default(false) bool showAlwaysInBlockList,
    @Default(false) bool premiumExclusive,
  }) = _PlatformModel;

  factory PlatformModel.fromJson(Map<String, dynamic> json) =>
      _$PlatformModelFromJson(json);
}

@freezed
abstract class DetectorModel with _$DetectorModel {
  const factory DetectorModel({
    @Default(<String>[]) List<String> supportedBlockModes,
    @Default('PRESS_BACK') String defaultBlockMode,
    @Default(0) int priority,
    @Default(<String>[]) List<String> identifiers,
    @Default(-1) int childNodeLimit,
    @Default('NONE') String actionOnLaunch,
    @Default(0) int paramsClass,
    @Default('') String params,
    @Default('') String message,
    @Default(true) bool haltOnDetect,
    @Default(<String>[]) List<String> coupleWith,
  }) = _DetectorModel;

  factory DetectorModel.fromJson(Map<String, dynamic> json) =>
      _$DetectorModelFromJson(json);
}

@freezed
abstract class AppOpenActionModel with _$AppOpenActionModel {
  const factory AppOpenActionModel({
    @Default('') String name,
    @Default('') String url,
  }) = _AppOpenActionModel;

  factory AppOpenActionModel.fromJson(Map<String, dynamic> json) =>
      _$AppOpenActionModelFromJson(json);
}

/// The `OVERLAY` detector's `params` field is itself an escaped JSON string.
/// Parse it lazily with `OverlayParamsModel.tryParse`.
@freezed
abstract class OverlayParamsModel with _$OverlayParamsModel {
  const factory OverlayParamsModel({
    @JsonKey(name: 'primary_id') @Default('') String primaryId,
    @Default(OverlayConfigModel()) OverlayConfigModel config,
    @JsonKey(name: 'primary_addons')
    @Default(<String>[])
    List<String> primaryAddons,
  }) = _OverlayParamsModel;

  factory OverlayParamsModel.fromJson(Map<String, dynamic> json) =>
      _$OverlayParamsModelFromJson(json);
}

@freezed
abstract class OverlayConfigModel with _$OverlayConfigModel {
  const factory OverlayConfigModel({
    @JsonKey(name: 'curious_support') @Default(false) bool curiousSupport,
    @JsonKey(name: 'block_all_support') @Default(false) bool blockAllSupport,
    @JsonKey(name: 'overlay_support') @Default(false) bool overlaySupport,
    @JsonKey(name: 'blackout_message') @Default('') String blackoutMessage,
  }) = _OverlayConfigModel;

  factory OverlayConfigModel.fromJson(Map<String, dynamic> json) =>
      _$OverlayConfigModelFromJson(json);
}
