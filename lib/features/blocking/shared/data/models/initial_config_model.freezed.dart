// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'initial_config_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$InitialConfigModel {

 VersionAvailabilityModel? get versionAvailability; List<InAppNotificationModel> get inappNotification; List<InAppNotificationModel> get warningMessages; Map<String, AdSlotModel> get admobConfig; ActivePlanDetailsModel? get activePlanDetails; PromoCtaModel? get premiumPurchaseCTA; Map<String, FeatureFlagModel> get featuresAvailability; int get platformConfigVersion;
/// Create a copy of InitialConfigModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InitialConfigModelCopyWith<InitialConfigModel> get copyWith => _$InitialConfigModelCopyWithImpl<InitialConfigModel>(this as InitialConfigModel, _$identity);

  /// Serializes this InitialConfigModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InitialConfigModel&&(identical(other.versionAvailability, versionAvailability) || other.versionAvailability == versionAvailability)&&const DeepCollectionEquality().equals(other.inappNotification, inappNotification)&&const DeepCollectionEquality().equals(other.warningMessages, warningMessages)&&const DeepCollectionEquality().equals(other.admobConfig, admobConfig)&&(identical(other.activePlanDetails, activePlanDetails) || other.activePlanDetails == activePlanDetails)&&(identical(other.premiumPurchaseCTA, premiumPurchaseCTA) || other.premiumPurchaseCTA == premiumPurchaseCTA)&&const DeepCollectionEquality().equals(other.featuresAvailability, featuresAvailability)&&(identical(other.platformConfigVersion, platformConfigVersion) || other.platformConfigVersion == platformConfigVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,versionAvailability,const DeepCollectionEquality().hash(inappNotification),const DeepCollectionEquality().hash(warningMessages),const DeepCollectionEquality().hash(admobConfig),activePlanDetails,premiumPurchaseCTA,const DeepCollectionEquality().hash(featuresAvailability),platformConfigVersion);

@override
String toString() {
  return 'InitialConfigModel(versionAvailability: $versionAvailability, inappNotification: $inappNotification, warningMessages: $warningMessages, admobConfig: $admobConfig, activePlanDetails: $activePlanDetails, premiumPurchaseCTA: $premiumPurchaseCTA, featuresAvailability: $featuresAvailability, platformConfigVersion: $platformConfigVersion)';
}


}

/// @nodoc
abstract mixin class $InitialConfigModelCopyWith<$Res>  {
  factory $InitialConfigModelCopyWith(InitialConfigModel value, $Res Function(InitialConfigModel) _then) = _$InitialConfigModelCopyWithImpl;
@useResult
$Res call({
 VersionAvailabilityModel? versionAvailability, List<InAppNotificationModel> inappNotification, List<InAppNotificationModel> warningMessages, Map<String, AdSlotModel> admobConfig, ActivePlanDetailsModel? activePlanDetails, PromoCtaModel? premiumPurchaseCTA, Map<String, FeatureFlagModel> featuresAvailability, int platformConfigVersion
});


$VersionAvailabilityModelCopyWith<$Res>? get versionAvailability;$ActivePlanDetailsModelCopyWith<$Res>? get activePlanDetails;$PromoCtaModelCopyWith<$Res>? get premiumPurchaseCTA;

}
/// @nodoc
class _$InitialConfigModelCopyWithImpl<$Res>
    implements $InitialConfigModelCopyWith<$Res> {
  _$InitialConfigModelCopyWithImpl(this._self, this._then);

  final InitialConfigModel _self;
  final $Res Function(InitialConfigModel) _then;

/// Create a copy of InitialConfigModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? versionAvailability = freezed,Object? inappNotification = null,Object? warningMessages = null,Object? admobConfig = null,Object? activePlanDetails = freezed,Object? premiumPurchaseCTA = freezed,Object? featuresAvailability = null,Object? platformConfigVersion = null,}) {
  return _then(_self.copyWith(
versionAvailability: freezed == versionAvailability ? _self.versionAvailability : versionAvailability // ignore: cast_nullable_to_non_nullable
as VersionAvailabilityModel?,inappNotification: null == inappNotification ? _self.inappNotification : inappNotification // ignore: cast_nullable_to_non_nullable
as List<InAppNotificationModel>,warningMessages: null == warningMessages ? _self.warningMessages : warningMessages // ignore: cast_nullable_to_non_nullable
as List<InAppNotificationModel>,admobConfig: null == admobConfig ? _self.admobConfig : admobConfig // ignore: cast_nullable_to_non_nullable
as Map<String, AdSlotModel>,activePlanDetails: freezed == activePlanDetails ? _self.activePlanDetails : activePlanDetails // ignore: cast_nullable_to_non_nullable
as ActivePlanDetailsModel?,premiumPurchaseCTA: freezed == premiumPurchaseCTA ? _self.premiumPurchaseCTA : premiumPurchaseCTA // ignore: cast_nullable_to_non_nullable
as PromoCtaModel?,featuresAvailability: null == featuresAvailability ? _self.featuresAvailability : featuresAvailability // ignore: cast_nullable_to_non_nullable
as Map<String, FeatureFlagModel>,platformConfigVersion: null == platformConfigVersion ? _self.platformConfigVersion : platformConfigVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of InitialConfigModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VersionAvailabilityModelCopyWith<$Res>? get versionAvailability {
    if (_self.versionAvailability == null) {
    return null;
  }

  return $VersionAvailabilityModelCopyWith<$Res>(_self.versionAvailability!, (value) {
    return _then(_self.copyWith(versionAvailability: value));
  });
}/// Create a copy of InitialConfigModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivePlanDetailsModelCopyWith<$Res>? get activePlanDetails {
    if (_self.activePlanDetails == null) {
    return null;
  }

  return $ActivePlanDetailsModelCopyWith<$Res>(_self.activePlanDetails!, (value) {
    return _then(_self.copyWith(activePlanDetails: value));
  });
}/// Create a copy of InitialConfigModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PromoCtaModelCopyWith<$Res>? get premiumPurchaseCTA {
    if (_self.premiumPurchaseCTA == null) {
    return null;
  }

  return $PromoCtaModelCopyWith<$Res>(_self.premiumPurchaseCTA!, (value) {
    return _then(_self.copyWith(premiumPurchaseCTA: value));
  });
}
}


/// Adds pattern-matching-related methods to [InitialConfigModel].
extension InitialConfigModelPatterns on InitialConfigModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InitialConfigModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InitialConfigModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InitialConfigModel value)  $default,){
final _that = this;
switch (_that) {
case _InitialConfigModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InitialConfigModel value)?  $default,){
final _that = this;
switch (_that) {
case _InitialConfigModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( VersionAvailabilityModel? versionAvailability,  List<InAppNotificationModel> inappNotification,  List<InAppNotificationModel> warningMessages,  Map<String, AdSlotModel> admobConfig,  ActivePlanDetailsModel? activePlanDetails,  PromoCtaModel? premiumPurchaseCTA,  Map<String, FeatureFlagModel> featuresAvailability,  int platformConfigVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InitialConfigModel() when $default != null:
return $default(_that.versionAvailability,_that.inappNotification,_that.warningMessages,_that.admobConfig,_that.activePlanDetails,_that.premiumPurchaseCTA,_that.featuresAvailability,_that.platformConfigVersion);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( VersionAvailabilityModel? versionAvailability,  List<InAppNotificationModel> inappNotification,  List<InAppNotificationModel> warningMessages,  Map<String, AdSlotModel> admobConfig,  ActivePlanDetailsModel? activePlanDetails,  PromoCtaModel? premiumPurchaseCTA,  Map<String, FeatureFlagModel> featuresAvailability,  int platformConfigVersion)  $default,) {final _that = this;
switch (_that) {
case _InitialConfigModel():
return $default(_that.versionAvailability,_that.inappNotification,_that.warningMessages,_that.admobConfig,_that.activePlanDetails,_that.premiumPurchaseCTA,_that.featuresAvailability,_that.platformConfigVersion);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( VersionAvailabilityModel? versionAvailability,  List<InAppNotificationModel> inappNotification,  List<InAppNotificationModel> warningMessages,  Map<String, AdSlotModel> admobConfig,  ActivePlanDetailsModel? activePlanDetails,  PromoCtaModel? premiumPurchaseCTA,  Map<String, FeatureFlagModel> featuresAvailability,  int platformConfigVersion)?  $default,) {final _that = this;
switch (_that) {
case _InitialConfigModel() when $default != null:
return $default(_that.versionAvailability,_that.inappNotification,_that.warningMessages,_that.admobConfig,_that.activePlanDetails,_that.premiumPurchaseCTA,_that.featuresAvailability,_that.platformConfigVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InitialConfigModel implements InitialConfigModel {
  const _InitialConfigModel({this.versionAvailability, final  List<InAppNotificationModel> inappNotification = const <InAppNotificationModel>[], final  List<InAppNotificationModel> warningMessages = const <InAppNotificationModel>[], final  Map<String, AdSlotModel> admobConfig = const <String, AdSlotModel>{}, this.activePlanDetails, this.premiumPurchaseCTA, final  Map<String, FeatureFlagModel> featuresAvailability = const <String, FeatureFlagModel>{}, this.platformConfigVersion = 0}): _inappNotification = inappNotification,_warningMessages = warningMessages,_admobConfig = admobConfig,_featuresAvailability = featuresAvailability;
  factory _InitialConfigModel.fromJson(Map<String, dynamic> json) => _$InitialConfigModelFromJson(json);

@override final  VersionAvailabilityModel? versionAvailability;
 final  List<InAppNotificationModel> _inappNotification;
@override@JsonKey() List<InAppNotificationModel> get inappNotification {
  if (_inappNotification is EqualUnmodifiableListView) return _inappNotification;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_inappNotification);
}

 final  List<InAppNotificationModel> _warningMessages;
@override@JsonKey() List<InAppNotificationModel> get warningMessages {
  if (_warningMessages is EqualUnmodifiableListView) return _warningMessages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_warningMessages);
}

 final  Map<String, AdSlotModel> _admobConfig;
@override@JsonKey() Map<String, AdSlotModel> get admobConfig {
  if (_admobConfig is EqualUnmodifiableMapView) return _admobConfig;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_admobConfig);
}

@override final  ActivePlanDetailsModel? activePlanDetails;
@override final  PromoCtaModel? premiumPurchaseCTA;
 final  Map<String, FeatureFlagModel> _featuresAvailability;
@override@JsonKey() Map<String, FeatureFlagModel> get featuresAvailability {
  if (_featuresAvailability is EqualUnmodifiableMapView) return _featuresAvailability;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_featuresAvailability);
}

@override@JsonKey() final  int platformConfigVersion;

/// Create a copy of InitialConfigModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InitialConfigModelCopyWith<_InitialConfigModel> get copyWith => __$InitialConfigModelCopyWithImpl<_InitialConfigModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InitialConfigModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InitialConfigModel&&(identical(other.versionAvailability, versionAvailability) || other.versionAvailability == versionAvailability)&&const DeepCollectionEquality().equals(other._inappNotification, _inappNotification)&&const DeepCollectionEquality().equals(other._warningMessages, _warningMessages)&&const DeepCollectionEquality().equals(other._admobConfig, _admobConfig)&&(identical(other.activePlanDetails, activePlanDetails) || other.activePlanDetails == activePlanDetails)&&(identical(other.premiumPurchaseCTA, premiumPurchaseCTA) || other.premiumPurchaseCTA == premiumPurchaseCTA)&&const DeepCollectionEquality().equals(other._featuresAvailability, _featuresAvailability)&&(identical(other.platformConfigVersion, platformConfigVersion) || other.platformConfigVersion == platformConfigVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,versionAvailability,const DeepCollectionEquality().hash(_inappNotification),const DeepCollectionEquality().hash(_warningMessages),const DeepCollectionEquality().hash(_admobConfig),activePlanDetails,premiumPurchaseCTA,const DeepCollectionEquality().hash(_featuresAvailability),platformConfigVersion);

@override
String toString() {
  return 'InitialConfigModel(versionAvailability: $versionAvailability, inappNotification: $inappNotification, warningMessages: $warningMessages, admobConfig: $admobConfig, activePlanDetails: $activePlanDetails, premiumPurchaseCTA: $premiumPurchaseCTA, featuresAvailability: $featuresAvailability, platformConfigVersion: $platformConfigVersion)';
}


}

/// @nodoc
abstract mixin class _$InitialConfigModelCopyWith<$Res> implements $InitialConfigModelCopyWith<$Res> {
  factory _$InitialConfigModelCopyWith(_InitialConfigModel value, $Res Function(_InitialConfigModel) _then) = __$InitialConfigModelCopyWithImpl;
@override @useResult
$Res call({
 VersionAvailabilityModel? versionAvailability, List<InAppNotificationModel> inappNotification, List<InAppNotificationModel> warningMessages, Map<String, AdSlotModel> admobConfig, ActivePlanDetailsModel? activePlanDetails, PromoCtaModel? premiumPurchaseCTA, Map<String, FeatureFlagModel> featuresAvailability, int platformConfigVersion
});


@override $VersionAvailabilityModelCopyWith<$Res>? get versionAvailability;@override $ActivePlanDetailsModelCopyWith<$Res>? get activePlanDetails;@override $PromoCtaModelCopyWith<$Res>? get premiumPurchaseCTA;

}
/// @nodoc
class __$InitialConfigModelCopyWithImpl<$Res>
    implements _$InitialConfigModelCopyWith<$Res> {
  __$InitialConfigModelCopyWithImpl(this._self, this._then);

  final _InitialConfigModel _self;
  final $Res Function(_InitialConfigModel) _then;

/// Create a copy of InitialConfigModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? versionAvailability = freezed,Object? inappNotification = null,Object? warningMessages = null,Object? admobConfig = null,Object? activePlanDetails = freezed,Object? premiumPurchaseCTA = freezed,Object? featuresAvailability = null,Object? platformConfigVersion = null,}) {
  return _then(_InitialConfigModel(
versionAvailability: freezed == versionAvailability ? _self.versionAvailability : versionAvailability // ignore: cast_nullable_to_non_nullable
as VersionAvailabilityModel?,inappNotification: null == inappNotification ? _self._inappNotification : inappNotification // ignore: cast_nullable_to_non_nullable
as List<InAppNotificationModel>,warningMessages: null == warningMessages ? _self._warningMessages : warningMessages // ignore: cast_nullable_to_non_nullable
as List<InAppNotificationModel>,admobConfig: null == admobConfig ? _self._admobConfig : admobConfig // ignore: cast_nullable_to_non_nullable
as Map<String, AdSlotModel>,activePlanDetails: freezed == activePlanDetails ? _self.activePlanDetails : activePlanDetails // ignore: cast_nullable_to_non_nullable
as ActivePlanDetailsModel?,premiumPurchaseCTA: freezed == premiumPurchaseCTA ? _self.premiumPurchaseCTA : premiumPurchaseCTA // ignore: cast_nullable_to_non_nullable
as PromoCtaModel?,featuresAvailability: null == featuresAvailability ? _self._featuresAvailability : featuresAvailability // ignore: cast_nullable_to_non_nullable
as Map<String, FeatureFlagModel>,platformConfigVersion: null == platformConfigVersion ? _self.platformConfigVersion : platformConfigVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of InitialConfigModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VersionAvailabilityModelCopyWith<$Res>? get versionAvailability {
    if (_self.versionAvailability == null) {
    return null;
  }

  return $VersionAvailabilityModelCopyWith<$Res>(_self.versionAvailability!, (value) {
    return _then(_self.copyWith(versionAvailability: value));
  });
}/// Create a copy of InitialConfigModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ActivePlanDetailsModelCopyWith<$Res>? get activePlanDetails {
    if (_self.activePlanDetails == null) {
    return null;
  }

  return $ActivePlanDetailsModelCopyWith<$Res>(_self.activePlanDetails!, (value) {
    return _then(_self.copyWith(activePlanDetails: value));
  });
}/// Create a copy of InitialConfigModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PromoCtaModelCopyWith<$Res>? get premiumPurchaseCTA {
    if (_self.premiumPurchaseCTA == null) {
    return null;
  }

  return $PromoCtaModelCopyWith<$Res>(_self.premiumPurchaseCTA!, (value) {
    return _then(_self.copyWith(premiumPurchaseCTA: value));
  });
}
}


/// @nodoc
mixin _$VersionAvailabilityModel {

 VersionInfoModel? get versionInfo; String get warningCode; String get title; String get desc; String get icon; bool get available;
/// Create a copy of VersionAvailabilityModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VersionAvailabilityModelCopyWith<VersionAvailabilityModel> get copyWith => _$VersionAvailabilityModelCopyWithImpl<VersionAvailabilityModel>(this as VersionAvailabilityModel, _$identity);

  /// Serializes this VersionAvailabilityModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VersionAvailabilityModel&&(identical(other.versionInfo, versionInfo) || other.versionInfo == versionInfo)&&(identical(other.warningCode, warningCode) || other.warningCode == warningCode)&&(identical(other.title, title) || other.title == title)&&(identical(other.desc, desc) || other.desc == desc)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.available, available) || other.available == available));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,versionInfo,warningCode,title,desc,icon,available);

@override
String toString() {
  return 'VersionAvailabilityModel(versionInfo: $versionInfo, warningCode: $warningCode, title: $title, desc: $desc, icon: $icon, available: $available)';
}


}

/// @nodoc
abstract mixin class $VersionAvailabilityModelCopyWith<$Res>  {
  factory $VersionAvailabilityModelCopyWith(VersionAvailabilityModel value, $Res Function(VersionAvailabilityModel) _then) = _$VersionAvailabilityModelCopyWithImpl;
@useResult
$Res call({
 VersionInfoModel? versionInfo, String warningCode, String title, String desc, String icon, bool available
});


$VersionInfoModelCopyWith<$Res>? get versionInfo;

}
/// @nodoc
class _$VersionAvailabilityModelCopyWithImpl<$Res>
    implements $VersionAvailabilityModelCopyWith<$Res> {
  _$VersionAvailabilityModelCopyWithImpl(this._self, this._then);

  final VersionAvailabilityModel _self;
  final $Res Function(VersionAvailabilityModel) _then;

/// Create a copy of VersionAvailabilityModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? versionInfo = freezed,Object? warningCode = null,Object? title = null,Object? desc = null,Object? icon = null,Object? available = null,}) {
  return _then(_self.copyWith(
versionInfo: freezed == versionInfo ? _self.versionInfo : versionInfo // ignore: cast_nullable_to_non_nullable
as VersionInfoModel?,warningCode: null == warningCode ? _self.warningCode : warningCode // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,desc: null == desc ? _self.desc : desc // ignore: cast_nullable_to_non_nullable
as String,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of VersionAvailabilityModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VersionInfoModelCopyWith<$Res>? get versionInfo {
    if (_self.versionInfo == null) {
    return null;
  }

  return $VersionInfoModelCopyWith<$Res>(_self.versionInfo!, (value) {
    return _then(_self.copyWith(versionInfo: value));
  });
}
}


/// Adds pattern-matching-related methods to [VersionAvailabilityModel].
extension VersionAvailabilityModelPatterns on VersionAvailabilityModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VersionAvailabilityModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VersionAvailabilityModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VersionAvailabilityModel value)  $default,){
final _that = this;
switch (_that) {
case _VersionAvailabilityModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VersionAvailabilityModel value)?  $default,){
final _that = this;
switch (_that) {
case _VersionAvailabilityModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( VersionInfoModel? versionInfo,  String warningCode,  String title,  String desc,  String icon,  bool available)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VersionAvailabilityModel() when $default != null:
return $default(_that.versionInfo,_that.warningCode,_that.title,_that.desc,_that.icon,_that.available);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( VersionInfoModel? versionInfo,  String warningCode,  String title,  String desc,  String icon,  bool available)  $default,) {final _that = this;
switch (_that) {
case _VersionAvailabilityModel():
return $default(_that.versionInfo,_that.warningCode,_that.title,_that.desc,_that.icon,_that.available);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( VersionInfoModel? versionInfo,  String warningCode,  String title,  String desc,  String icon,  bool available)?  $default,) {final _that = this;
switch (_that) {
case _VersionAvailabilityModel() when $default != null:
return $default(_that.versionInfo,_that.warningCode,_that.title,_that.desc,_that.icon,_that.available);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VersionAvailabilityModel implements VersionAvailabilityModel {
  const _VersionAvailabilityModel({this.versionInfo, this.warningCode = '', this.title = '', this.desc = '', this.icon = '', this.available = false});
  factory _VersionAvailabilityModel.fromJson(Map<String, dynamic> json) => _$VersionAvailabilityModelFromJson(json);

@override final  VersionInfoModel? versionInfo;
@override@JsonKey() final  String warningCode;
@override@JsonKey() final  String title;
@override@JsonKey() final  String desc;
@override@JsonKey() final  String icon;
@override@JsonKey() final  bool available;

/// Create a copy of VersionAvailabilityModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VersionAvailabilityModelCopyWith<_VersionAvailabilityModel> get copyWith => __$VersionAvailabilityModelCopyWithImpl<_VersionAvailabilityModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VersionAvailabilityModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VersionAvailabilityModel&&(identical(other.versionInfo, versionInfo) || other.versionInfo == versionInfo)&&(identical(other.warningCode, warningCode) || other.warningCode == warningCode)&&(identical(other.title, title) || other.title == title)&&(identical(other.desc, desc) || other.desc == desc)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.available, available) || other.available == available));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,versionInfo,warningCode,title,desc,icon,available);

@override
String toString() {
  return 'VersionAvailabilityModel(versionInfo: $versionInfo, warningCode: $warningCode, title: $title, desc: $desc, icon: $icon, available: $available)';
}


}

/// @nodoc
abstract mixin class _$VersionAvailabilityModelCopyWith<$Res> implements $VersionAvailabilityModelCopyWith<$Res> {
  factory _$VersionAvailabilityModelCopyWith(_VersionAvailabilityModel value, $Res Function(_VersionAvailabilityModel) _then) = __$VersionAvailabilityModelCopyWithImpl;
@override @useResult
$Res call({
 VersionInfoModel? versionInfo, String warningCode, String title, String desc, String icon, bool available
});


@override $VersionInfoModelCopyWith<$Res>? get versionInfo;

}
/// @nodoc
class __$VersionAvailabilityModelCopyWithImpl<$Res>
    implements _$VersionAvailabilityModelCopyWith<$Res> {
  __$VersionAvailabilityModelCopyWithImpl(this._self, this._then);

  final _VersionAvailabilityModel _self;
  final $Res Function(_VersionAvailabilityModel) _then;

/// Create a copy of VersionAvailabilityModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? versionInfo = freezed,Object? warningCode = null,Object? title = null,Object? desc = null,Object? icon = null,Object? available = null,}) {
  return _then(_VersionAvailabilityModel(
versionInfo: freezed == versionInfo ? _self.versionInfo : versionInfo // ignore: cast_nullable_to_non_nullable
as VersionInfoModel?,warningCode: null == warningCode ? _self.warningCode : warningCode // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,desc: null == desc ? _self.desc : desc // ignore: cast_nullable_to_non_nullable
as String,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,available: null == available ? _self.available : available // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of VersionAvailabilityModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VersionInfoModelCopyWith<$Res>? get versionInfo {
    if (_self.versionInfo == null) {
    return null;
  }

  return $VersionInfoModelCopyWith<$Res>(_self.versionInfo!, (value) {
    return _then(_self.copyWith(versionInfo: value));
  });
}
}


/// @nodoc
mixin _$VersionInfoModel {

 int get versionCode; String get versionName; bool get promptUpdate; bool get forceUpdate; bool get beta; String get changelog;
/// Create a copy of VersionInfoModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VersionInfoModelCopyWith<VersionInfoModel> get copyWith => _$VersionInfoModelCopyWithImpl<VersionInfoModel>(this as VersionInfoModel, _$identity);

  /// Serializes this VersionInfoModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VersionInfoModel&&(identical(other.versionCode, versionCode) || other.versionCode == versionCode)&&(identical(other.versionName, versionName) || other.versionName == versionName)&&(identical(other.promptUpdate, promptUpdate) || other.promptUpdate == promptUpdate)&&(identical(other.forceUpdate, forceUpdate) || other.forceUpdate == forceUpdate)&&(identical(other.beta, beta) || other.beta == beta)&&(identical(other.changelog, changelog) || other.changelog == changelog));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,versionCode,versionName,promptUpdate,forceUpdate,beta,changelog);

@override
String toString() {
  return 'VersionInfoModel(versionCode: $versionCode, versionName: $versionName, promptUpdate: $promptUpdate, forceUpdate: $forceUpdate, beta: $beta, changelog: $changelog)';
}


}

/// @nodoc
abstract mixin class $VersionInfoModelCopyWith<$Res>  {
  factory $VersionInfoModelCopyWith(VersionInfoModel value, $Res Function(VersionInfoModel) _then) = _$VersionInfoModelCopyWithImpl;
@useResult
$Res call({
 int versionCode, String versionName, bool promptUpdate, bool forceUpdate, bool beta, String changelog
});




}
/// @nodoc
class _$VersionInfoModelCopyWithImpl<$Res>
    implements $VersionInfoModelCopyWith<$Res> {
  _$VersionInfoModelCopyWithImpl(this._self, this._then);

  final VersionInfoModel _self;
  final $Res Function(VersionInfoModel) _then;

/// Create a copy of VersionInfoModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? versionCode = null,Object? versionName = null,Object? promptUpdate = null,Object? forceUpdate = null,Object? beta = null,Object? changelog = null,}) {
  return _then(_self.copyWith(
versionCode: null == versionCode ? _self.versionCode : versionCode // ignore: cast_nullable_to_non_nullable
as int,versionName: null == versionName ? _self.versionName : versionName // ignore: cast_nullable_to_non_nullable
as String,promptUpdate: null == promptUpdate ? _self.promptUpdate : promptUpdate // ignore: cast_nullable_to_non_nullable
as bool,forceUpdate: null == forceUpdate ? _self.forceUpdate : forceUpdate // ignore: cast_nullable_to_non_nullable
as bool,beta: null == beta ? _self.beta : beta // ignore: cast_nullable_to_non_nullable
as bool,changelog: null == changelog ? _self.changelog : changelog // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [VersionInfoModel].
extension VersionInfoModelPatterns on VersionInfoModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VersionInfoModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VersionInfoModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VersionInfoModel value)  $default,){
final _that = this;
switch (_that) {
case _VersionInfoModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VersionInfoModel value)?  $default,){
final _that = this;
switch (_that) {
case _VersionInfoModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int versionCode,  String versionName,  bool promptUpdate,  bool forceUpdate,  bool beta,  String changelog)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VersionInfoModel() when $default != null:
return $default(_that.versionCode,_that.versionName,_that.promptUpdate,_that.forceUpdate,_that.beta,_that.changelog);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int versionCode,  String versionName,  bool promptUpdate,  bool forceUpdate,  bool beta,  String changelog)  $default,) {final _that = this;
switch (_that) {
case _VersionInfoModel():
return $default(_that.versionCode,_that.versionName,_that.promptUpdate,_that.forceUpdate,_that.beta,_that.changelog);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int versionCode,  String versionName,  bool promptUpdate,  bool forceUpdate,  bool beta,  String changelog)?  $default,) {final _that = this;
switch (_that) {
case _VersionInfoModel() when $default != null:
return $default(_that.versionCode,_that.versionName,_that.promptUpdate,_that.forceUpdate,_that.beta,_that.changelog);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VersionInfoModel implements VersionInfoModel {
  const _VersionInfoModel({this.versionCode = 0, this.versionName = '', this.promptUpdate = false, this.forceUpdate = false, this.beta = false, this.changelog = ''});
  factory _VersionInfoModel.fromJson(Map<String, dynamic> json) => _$VersionInfoModelFromJson(json);

@override@JsonKey() final  int versionCode;
@override@JsonKey() final  String versionName;
@override@JsonKey() final  bool promptUpdate;
@override@JsonKey() final  bool forceUpdate;
@override@JsonKey() final  bool beta;
@override@JsonKey() final  String changelog;

/// Create a copy of VersionInfoModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VersionInfoModelCopyWith<_VersionInfoModel> get copyWith => __$VersionInfoModelCopyWithImpl<_VersionInfoModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VersionInfoModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VersionInfoModel&&(identical(other.versionCode, versionCode) || other.versionCode == versionCode)&&(identical(other.versionName, versionName) || other.versionName == versionName)&&(identical(other.promptUpdate, promptUpdate) || other.promptUpdate == promptUpdate)&&(identical(other.forceUpdate, forceUpdate) || other.forceUpdate == forceUpdate)&&(identical(other.beta, beta) || other.beta == beta)&&(identical(other.changelog, changelog) || other.changelog == changelog));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,versionCode,versionName,promptUpdate,forceUpdate,beta,changelog);

@override
String toString() {
  return 'VersionInfoModel(versionCode: $versionCode, versionName: $versionName, promptUpdate: $promptUpdate, forceUpdate: $forceUpdate, beta: $beta, changelog: $changelog)';
}


}

/// @nodoc
abstract mixin class _$VersionInfoModelCopyWith<$Res> implements $VersionInfoModelCopyWith<$Res> {
  factory _$VersionInfoModelCopyWith(_VersionInfoModel value, $Res Function(_VersionInfoModel) _then) = __$VersionInfoModelCopyWithImpl;
@override @useResult
$Res call({
 int versionCode, String versionName, bool promptUpdate, bool forceUpdate, bool beta, String changelog
});




}
/// @nodoc
class __$VersionInfoModelCopyWithImpl<$Res>
    implements _$VersionInfoModelCopyWith<$Res> {
  __$VersionInfoModelCopyWithImpl(this._self, this._then);

  final _VersionInfoModel _self;
  final $Res Function(_VersionInfoModel) _then;

/// Create a copy of VersionInfoModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? versionCode = null,Object? versionName = null,Object? promptUpdate = null,Object? forceUpdate = null,Object? beta = null,Object? changelog = null,}) {
  return _then(_VersionInfoModel(
versionCode: null == versionCode ? _self.versionCode : versionCode // ignore: cast_nullable_to_non_nullable
as int,versionName: null == versionName ? _self.versionName : versionName // ignore: cast_nullable_to_non_nullable
as String,promptUpdate: null == promptUpdate ? _self.promptUpdate : promptUpdate // ignore: cast_nullable_to_non_nullable
as bool,forceUpdate: null == forceUpdate ? _self.forceUpdate : forceUpdate // ignore: cast_nullable_to_non_nullable
as bool,beta: null == beta ? _self.beta : beta // ignore: cast_nullable_to_non_nullable
as bool,changelog: null == changelog ? _self.changelog : changelog // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$InAppNotificationModel {

 String get notificationId; String get title; String get description; String get cta; int get priority; String get ctaAction; String get ctaUrl; String get metadata; int get expiry; String get icon; bool get premiumExclusive; bool get guestExclusive; bool get dismissible;
/// Create a copy of InAppNotificationModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InAppNotificationModelCopyWith<InAppNotificationModel> get copyWith => _$InAppNotificationModelCopyWithImpl<InAppNotificationModel>(this as InAppNotificationModel, _$identity);

  /// Serializes this InAppNotificationModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InAppNotificationModel&&(identical(other.notificationId, notificationId) || other.notificationId == notificationId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.cta, cta) || other.cta == cta)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.ctaAction, ctaAction) || other.ctaAction == ctaAction)&&(identical(other.ctaUrl, ctaUrl) || other.ctaUrl == ctaUrl)&&(identical(other.metadata, metadata) || other.metadata == metadata)&&(identical(other.expiry, expiry) || other.expiry == expiry)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.premiumExclusive, premiumExclusive) || other.premiumExclusive == premiumExclusive)&&(identical(other.guestExclusive, guestExclusive) || other.guestExclusive == guestExclusive)&&(identical(other.dismissible, dismissible) || other.dismissible == dismissible));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,notificationId,title,description,cta,priority,ctaAction,ctaUrl,metadata,expiry,icon,premiumExclusive,guestExclusive,dismissible);

@override
String toString() {
  return 'InAppNotificationModel(notificationId: $notificationId, title: $title, description: $description, cta: $cta, priority: $priority, ctaAction: $ctaAction, ctaUrl: $ctaUrl, metadata: $metadata, expiry: $expiry, icon: $icon, premiumExclusive: $premiumExclusive, guestExclusive: $guestExclusive, dismissible: $dismissible)';
}


}

/// @nodoc
abstract mixin class $InAppNotificationModelCopyWith<$Res>  {
  factory $InAppNotificationModelCopyWith(InAppNotificationModel value, $Res Function(InAppNotificationModel) _then) = _$InAppNotificationModelCopyWithImpl;
@useResult
$Res call({
 String notificationId, String title, String description, String cta, int priority, String ctaAction, String ctaUrl, String metadata, int expiry, String icon, bool premiumExclusive, bool guestExclusive, bool dismissible
});




}
/// @nodoc
class _$InAppNotificationModelCopyWithImpl<$Res>
    implements $InAppNotificationModelCopyWith<$Res> {
  _$InAppNotificationModelCopyWithImpl(this._self, this._then);

  final InAppNotificationModel _self;
  final $Res Function(InAppNotificationModel) _then;

/// Create a copy of InAppNotificationModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? notificationId = null,Object? title = null,Object? description = null,Object? cta = null,Object? priority = null,Object? ctaAction = null,Object? ctaUrl = null,Object? metadata = null,Object? expiry = null,Object? icon = null,Object? premiumExclusive = null,Object? guestExclusive = null,Object? dismissible = null,}) {
  return _then(_self.copyWith(
notificationId: null == notificationId ? _self.notificationId : notificationId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,cta: null == cta ? _self.cta : cta // ignore: cast_nullable_to_non_nullable
as String,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int,ctaAction: null == ctaAction ? _self.ctaAction : ctaAction // ignore: cast_nullable_to_non_nullable
as String,ctaUrl: null == ctaUrl ? _self.ctaUrl : ctaUrl // ignore: cast_nullable_to_non_nullable
as String,metadata: null == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as String,expiry: null == expiry ? _self.expiry : expiry // ignore: cast_nullable_to_non_nullable
as int,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,premiumExclusive: null == premiumExclusive ? _self.premiumExclusive : premiumExclusive // ignore: cast_nullable_to_non_nullable
as bool,guestExclusive: null == guestExclusive ? _self.guestExclusive : guestExclusive // ignore: cast_nullable_to_non_nullable
as bool,dismissible: null == dismissible ? _self.dismissible : dismissible // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [InAppNotificationModel].
extension InAppNotificationModelPatterns on InAppNotificationModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InAppNotificationModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InAppNotificationModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InAppNotificationModel value)  $default,){
final _that = this;
switch (_that) {
case _InAppNotificationModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InAppNotificationModel value)?  $default,){
final _that = this;
switch (_that) {
case _InAppNotificationModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String notificationId,  String title,  String description,  String cta,  int priority,  String ctaAction,  String ctaUrl,  String metadata,  int expiry,  String icon,  bool premiumExclusive,  bool guestExclusive,  bool dismissible)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InAppNotificationModel() when $default != null:
return $default(_that.notificationId,_that.title,_that.description,_that.cta,_that.priority,_that.ctaAction,_that.ctaUrl,_that.metadata,_that.expiry,_that.icon,_that.premiumExclusive,_that.guestExclusive,_that.dismissible);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String notificationId,  String title,  String description,  String cta,  int priority,  String ctaAction,  String ctaUrl,  String metadata,  int expiry,  String icon,  bool premiumExclusive,  bool guestExclusive,  bool dismissible)  $default,) {final _that = this;
switch (_that) {
case _InAppNotificationModel():
return $default(_that.notificationId,_that.title,_that.description,_that.cta,_that.priority,_that.ctaAction,_that.ctaUrl,_that.metadata,_that.expiry,_that.icon,_that.premiumExclusive,_that.guestExclusive,_that.dismissible);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String notificationId,  String title,  String description,  String cta,  int priority,  String ctaAction,  String ctaUrl,  String metadata,  int expiry,  String icon,  bool premiumExclusive,  bool guestExclusive,  bool dismissible)?  $default,) {final _that = this;
switch (_that) {
case _InAppNotificationModel() when $default != null:
return $default(_that.notificationId,_that.title,_that.description,_that.cta,_that.priority,_that.ctaAction,_that.ctaUrl,_that.metadata,_that.expiry,_that.icon,_that.premiumExclusive,_that.guestExclusive,_that.dismissible);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InAppNotificationModel implements InAppNotificationModel {
  const _InAppNotificationModel({required this.notificationId, this.title = '', this.description = '', this.cta = '', this.priority = 0, this.ctaAction = '', this.ctaUrl = '', this.metadata = '', this.expiry = 0, this.icon = '', this.premiumExclusive = false, this.guestExclusive = false, this.dismissible = true});
  factory _InAppNotificationModel.fromJson(Map<String, dynamic> json) => _$InAppNotificationModelFromJson(json);

@override final  String notificationId;
@override@JsonKey() final  String title;
@override@JsonKey() final  String description;
@override@JsonKey() final  String cta;
@override@JsonKey() final  int priority;
@override@JsonKey() final  String ctaAction;
@override@JsonKey() final  String ctaUrl;
@override@JsonKey() final  String metadata;
@override@JsonKey() final  int expiry;
@override@JsonKey() final  String icon;
@override@JsonKey() final  bool premiumExclusive;
@override@JsonKey() final  bool guestExclusive;
@override@JsonKey() final  bool dismissible;

/// Create a copy of InAppNotificationModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InAppNotificationModelCopyWith<_InAppNotificationModel> get copyWith => __$InAppNotificationModelCopyWithImpl<_InAppNotificationModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InAppNotificationModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InAppNotificationModel&&(identical(other.notificationId, notificationId) || other.notificationId == notificationId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.cta, cta) || other.cta == cta)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.ctaAction, ctaAction) || other.ctaAction == ctaAction)&&(identical(other.ctaUrl, ctaUrl) || other.ctaUrl == ctaUrl)&&(identical(other.metadata, metadata) || other.metadata == metadata)&&(identical(other.expiry, expiry) || other.expiry == expiry)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.premiumExclusive, premiumExclusive) || other.premiumExclusive == premiumExclusive)&&(identical(other.guestExclusive, guestExclusive) || other.guestExclusive == guestExclusive)&&(identical(other.dismissible, dismissible) || other.dismissible == dismissible));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,notificationId,title,description,cta,priority,ctaAction,ctaUrl,metadata,expiry,icon,premiumExclusive,guestExclusive,dismissible);

@override
String toString() {
  return 'InAppNotificationModel(notificationId: $notificationId, title: $title, description: $description, cta: $cta, priority: $priority, ctaAction: $ctaAction, ctaUrl: $ctaUrl, metadata: $metadata, expiry: $expiry, icon: $icon, premiumExclusive: $premiumExclusive, guestExclusive: $guestExclusive, dismissible: $dismissible)';
}


}

/// @nodoc
abstract mixin class _$InAppNotificationModelCopyWith<$Res> implements $InAppNotificationModelCopyWith<$Res> {
  factory _$InAppNotificationModelCopyWith(_InAppNotificationModel value, $Res Function(_InAppNotificationModel) _then) = __$InAppNotificationModelCopyWithImpl;
@override @useResult
$Res call({
 String notificationId, String title, String description, String cta, int priority, String ctaAction, String ctaUrl, String metadata, int expiry, String icon, bool premiumExclusive, bool guestExclusive, bool dismissible
});




}
/// @nodoc
class __$InAppNotificationModelCopyWithImpl<$Res>
    implements _$InAppNotificationModelCopyWith<$Res> {
  __$InAppNotificationModelCopyWithImpl(this._self, this._then);

  final _InAppNotificationModel _self;
  final $Res Function(_InAppNotificationModel) _then;

/// Create a copy of InAppNotificationModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? notificationId = null,Object? title = null,Object? description = null,Object? cta = null,Object? priority = null,Object? ctaAction = null,Object? ctaUrl = null,Object? metadata = null,Object? expiry = null,Object? icon = null,Object? premiumExclusive = null,Object? guestExclusive = null,Object? dismissible = null,}) {
  return _then(_InAppNotificationModel(
notificationId: null == notificationId ? _self.notificationId : notificationId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,cta: null == cta ? _self.cta : cta // ignore: cast_nullable_to_non_nullable
as String,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int,ctaAction: null == ctaAction ? _self.ctaAction : ctaAction // ignore: cast_nullable_to_non_nullable
as String,ctaUrl: null == ctaUrl ? _self.ctaUrl : ctaUrl // ignore: cast_nullable_to_non_nullable
as String,metadata: null == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as String,expiry: null == expiry ? _self.expiry : expiry // ignore: cast_nullable_to_non_nullable
as int,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String,premiumExclusive: null == premiumExclusive ? _self.premiumExclusive : premiumExclusive // ignore: cast_nullable_to_non_nullable
as bool,guestExclusive: null == guestExclusive ? _self.guestExclusive : guestExclusive // ignore: cast_nullable_to_non_nullable
as bool,dismissible: null == dismissible ? _self.dismissible : dismissible // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$AdSlotModel {

 String get adTag; String get adType;
/// Create a copy of AdSlotModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AdSlotModelCopyWith<AdSlotModel> get copyWith => _$AdSlotModelCopyWithImpl<AdSlotModel>(this as AdSlotModel, _$identity);

  /// Serializes this AdSlotModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AdSlotModel&&(identical(other.adTag, adTag) || other.adTag == adTag)&&(identical(other.adType, adType) || other.adType == adType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,adTag,adType);

@override
String toString() {
  return 'AdSlotModel(adTag: $adTag, adType: $adType)';
}


}

/// @nodoc
abstract mixin class $AdSlotModelCopyWith<$Res>  {
  factory $AdSlotModelCopyWith(AdSlotModel value, $Res Function(AdSlotModel) _then) = _$AdSlotModelCopyWithImpl;
@useResult
$Res call({
 String adTag, String adType
});




}
/// @nodoc
class _$AdSlotModelCopyWithImpl<$Res>
    implements $AdSlotModelCopyWith<$Res> {
  _$AdSlotModelCopyWithImpl(this._self, this._then);

  final AdSlotModel _self;
  final $Res Function(AdSlotModel) _then;

/// Create a copy of AdSlotModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? adTag = null,Object? adType = null,}) {
  return _then(_self.copyWith(
adTag: null == adTag ? _self.adTag : adTag // ignore: cast_nullable_to_non_nullable
as String,adType: null == adType ? _self.adType : adType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AdSlotModel].
extension AdSlotModelPatterns on AdSlotModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AdSlotModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AdSlotModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AdSlotModel value)  $default,){
final _that = this;
switch (_that) {
case _AdSlotModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AdSlotModel value)?  $default,){
final _that = this;
switch (_that) {
case _AdSlotModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String adTag,  String adType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AdSlotModel() when $default != null:
return $default(_that.adTag,_that.adType);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String adTag,  String adType)  $default,) {final _that = this;
switch (_that) {
case _AdSlotModel():
return $default(_that.adTag,_that.adType);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String adTag,  String adType)?  $default,) {final _that = this;
switch (_that) {
case _AdSlotModel() when $default != null:
return $default(_that.adTag,_that.adType);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AdSlotModel implements AdSlotModel {
  const _AdSlotModel({this.adTag = '', this.adType = 'BANNER'});
  factory _AdSlotModel.fromJson(Map<String, dynamic> json) => _$AdSlotModelFromJson(json);

@override@JsonKey() final  String adTag;
@override@JsonKey() final  String adType;

/// Create a copy of AdSlotModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AdSlotModelCopyWith<_AdSlotModel> get copyWith => __$AdSlotModelCopyWithImpl<_AdSlotModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AdSlotModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AdSlotModel&&(identical(other.adTag, adTag) || other.adTag == adTag)&&(identical(other.adType, adType) || other.adType == adType));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,adTag,adType);

@override
String toString() {
  return 'AdSlotModel(adTag: $adTag, adType: $adType)';
}


}

/// @nodoc
abstract mixin class _$AdSlotModelCopyWith<$Res> implements $AdSlotModelCopyWith<$Res> {
  factory _$AdSlotModelCopyWith(_AdSlotModel value, $Res Function(_AdSlotModel) _then) = __$AdSlotModelCopyWithImpl;
@override @useResult
$Res call({
 String adTag, String adType
});




}
/// @nodoc
class __$AdSlotModelCopyWithImpl<$Res>
    implements _$AdSlotModelCopyWith<$Res> {
  __$AdSlotModelCopyWithImpl(this._self, this._then);

  final _AdSlotModel _self;
  final $Res Function(_AdSlotModel) _then;

/// Create a copy of AdSlotModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? adTag = null,Object? adType = null,}) {
  return _then(_AdSlotModel(
adTag: null == adTag ? _self.adTag : adTag // ignore: cast_nullable_to_non_nullable
as String,adType: null == adType ? _self.adType : adType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ActivePlanDetailsModel {

 bool get aiFeatures; bool get blockAds; bool get premiumFeatures; bool get parentalFeatures; bool get topTierPlan; bool get promptUpgrades; List<String> get plans;
/// Create a copy of ActivePlanDetailsModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActivePlanDetailsModelCopyWith<ActivePlanDetailsModel> get copyWith => _$ActivePlanDetailsModelCopyWithImpl<ActivePlanDetailsModel>(this as ActivePlanDetailsModel, _$identity);

  /// Serializes this ActivePlanDetailsModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActivePlanDetailsModel&&(identical(other.aiFeatures, aiFeatures) || other.aiFeatures == aiFeatures)&&(identical(other.blockAds, blockAds) || other.blockAds == blockAds)&&(identical(other.premiumFeatures, premiumFeatures) || other.premiumFeatures == premiumFeatures)&&(identical(other.parentalFeatures, parentalFeatures) || other.parentalFeatures == parentalFeatures)&&(identical(other.topTierPlan, topTierPlan) || other.topTierPlan == topTierPlan)&&(identical(other.promptUpgrades, promptUpgrades) || other.promptUpgrades == promptUpgrades)&&const DeepCollectionEquality().equals(other.plans, plans));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,aiFeatures,blockAds,premiumFeatures,parentalFeatures,topTierPlan,promptUpgrades,const DeepCollectionEquality().hash(plans));

@override
String toString() {
  return 'ActivePlanDetailsModel(aiFeatures: $aiFeatures, blockAds: $blockAds, premiumFeatures: $premiumFeatures, parentalFeatures: $parentalFeatures, topTierPlan: $topTierPlan, promptUpgrades: $promptUpgrades, plans: $plans)';
}


}

/// @nodoc
abstract mixin class $ActivePlanDetailsModelCopyWith<$Res>  {
  factory $ActivePlanDetailsModelCopyWith(ActivePlanDetailsModel value, $Res Function(ActivePlanDetailsModel) _then) = _$ActivePlanDetailsModelCopyWithImpl;
@useResult
$Res call({
 bool aiFeatures, bool blockAds, bool premiumFeatures, bool parentalFeatures, bool topTierPlan, bool promptUpgrades, List<String> plans
});




}
/// @nodoc
class _$ActivePlanDetailsModelCopyWithImpl<$Res>
    implements $ActivePlanDetailsModelCopyWith<$Res> {
  _$ActivePlanDetailsModelCopyWithImpl(this._self, this._then);

  final ActivePlanDetailsModel _self;
  final $Res Function(ActivePlanDetailsModel) _then;

/// Create a copy of ActivePlanDetailsModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? aiFeatures = null,Object? blockAds = null,Object? premiumFeatures = null,Object? parentalFeatures = null,Object? topTierPlan = null,Object? promptUpgrades = null,Object? plans = null,}) {
  return _then(_self.copyWith(
aiFeatures: null == aiFeatures ? _self.aiFeatures : aiFeatures // ignore: cast_nullable_to_non_nullable
as bool,blockAds: null == blockAds ? _self.blockAds : blockAds // ignore: cast_nullable_to_non_nullable
as bool,premiumFeatures: null == premiumFeatures ? _self.premiumFeatures : premiumFeatures // ignore: cast_nullable_to_non_nullable
as bool,parentalFeatures: null == parentalFeatures ? _self.parentalFeatures : parentalFeatures // ignore: cast_nullable_to_non_nullable
as bool,topTierPlan: null == topTierPlan ? _self.topTierPlan : topTierPlan // ignore: cast_nullable_to_non_nullable
as bool,promptUpgrades: null == promptUpgrades ? _self.promptUpgrades : promptUpgrades // ignore: cast_nullable_to_non_nullable
as bool,plans: null == plans ? _self.plans : plans // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [ActivePlanDetailsModel].
extension ActivePlanDetailsModelPatterns on ActivePlanDetailsModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActivePlanDetailsModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActivePlanDetailsModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActivePlanDetailsModel value)  $default,){
final _that = this;
switch (_that) {
case _ActivePlanDetailsModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActivePlanDetailsModel value)?  $default,){
final _that = this;
switch (_that) {
case _ActivePlanDetailsModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool aiFeatures,  bool blockAds,  bool premiumFeatures,  bool parentalFeatures,  bool topTierPlan,  bool promptUpgrades,  List<String> plans)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActivePlanDetailsModel() when $default != null:
return $default(_that.aiFeatures,_that.blockAds,_that.premiumFeatures,_that.parentalFeatures,_that.topTierPlan,_that.promptUpgrades,_that.plans);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool aiFeatures,  bool blockAds,  bool premiumFeatures,  bool parentalFeatures,  bool topTierPlan,  bool promptUpgrades,  List<String> plans)  $default,) {final _that = this;
switch (_that) {
case _ActivePlanDetailsModel():
return $default(_that.aiFeatures,_that.blockAds,_that.premiumFeatures,_that.parentalFeatures,_that.topTierPlan,_that.promptUpgrades,_that.plans);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool aiFeatures,  bool blockAds,  bool premiumFeatures,  bool parentalFeatures,  bool topTierPlan,  bool promptUpgrades,  List<String> plans)?  $default,) {final _that = this;
switch (_that) {
case _ActivePlanDetailsModel() when $default != null:
return $default(_that.aiFeatures,_that.blockAds,_that.premiumFeatures,_that.parentalFeatures,_that.topTierPlan,_that.promptUpgrades,_that.plans);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ActivePlanDetailsModel implements ActivePlanDetailsModel {
  const _ActivePlanDetailsModel({this.aiFeatures = false, this.blockAds = false, this.premiumFeatures = false, this.parentalFeatures = false, this.topTierPlan = false, this.promptUpgrades = true, final  List<String> plans = const <String>[]}): _plans = plans;
  factory _ActivePlanDetailsModel.fromJson(Map<String, dynamic> json) => _$ActivePlanDetailsModelFromJson(json);

@override@JsonKey() final  bool aiFeatures;
@override@JsonKey() final  bool blockAds;
@override@JsonKey() final  bool premiumFeatures;
@override@JsonKey() final  bool parentalFeatures;
@override@JsonKey() final  bool topTierPlan;
@override@JsonKey() final  bool promptUpgrades;
 final  List<String> _plans;
@override@JsonKey() List<String> get plans {
  if (_plans is EqualUnmodifiableListView) return _plans;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_plans);
}


/// Create a copy of ActivePlanDetailsModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActivePlanDetailsModelCopyWith<_ActivePlanDetailsModel> get copyWith => __$ActivePlanDetailsModelCopyWithImpl<_ActivePlanDetailsModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ActivePlanDetailsModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActivePlanDetailsModel&&(identical(other.aiFeatures, aiFeatures) || other.aiFeatures == aiFeatures)&&(identical(other.blockAds, blockAds) || other.blockAds == blockAds)&&(identical(other.premiumFeatures, premiumFeatures) || other.premiumFeatures == premiumFeatures)&&(identical(other.parentalFeatures, parentalFeatures) || other.parentalFeatures == parentalFeatures)&&(identical(other.topTierPlan, topTierPlan) || other.topTierPlan == topTierPlan)&&(identical(other.promptUpgrades, promptUpgrades) || other.promptUpgrades == promptUpgrades)&&const DeepCollectionEquality().equals(other._plans, _plans));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,aiFeatures,blockAds,premiumFeatures,parentalFeatures,topTierPlan,promptUpgrades,const DeepCollectionEquality().hash(_plans));

@override
String toString() {
  return 'ActivePlanDetailsModel(aiFeatures: $aiFeatures, blockAds: $blockAds, premiumFeatures: $premiumFeatures, parentalFeatures: $parentalFeatures, topTierPlan: $topTierPlan, promptUpgrades: $promptUpgrades, plans: $plans)';
}


}

/// @nodoc
abstract mixin class _$ActivePlanDetailsModelCopyWith<$Res> implements $ActivePlanDetailsModelCopyWith<$Res> {
  factory _$ActivePlanDetailsModelCopyWith(_ActivePlanDetailsModel value, $Res Function(_ActivePlanDetailsModel) _then) = __$ActivePlanDetailsModelCopyWithImpl;
@override @useResult
$Res call({
 bool aiFeatures, bool blockAds, bool premiumFeatures, bool parentalFeatures, bool topTierPlan, bool promptUpgrades, List<String> plans
});




}
/// @nodoc
class __$ActivePlanDetailsModelCopyWithImpl<$Res>
    implements _$ActivePlanDetailsModelCopyWith<$Res> {
  __$ActivePlanDetailsModelCopyWithImpl(this._self, this._then);

  final _ActivePlanDetailsModel _self;
  final $Res Function(_ActivePlanDetailsModel) _then;

/// Create a copy of ActivePlanDetailsModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? aiFeatures = null,Object? blockAds = null,Object? premiumFeatures = null,Object? parentalFeatures = null,Object? topTierPlan = null,Object? promptUpgrades = null,Object? plans = null,}) {
  return _then(_ActivePlanDetailsModel(
aiFeatures: null == aiFeatures ? _self.aiFeatures : aiFeatures // ignore: cast_nullable_to_non_nullable
as bool,blockAds: null == blockAds ? _self.blockAds : blockAds // ignore: cast_nullable_to_non_nullable
as bool,premiumFeatures: null == premiumFeatures ? _self.premiumFeatures : premiumFeatures // ignore: cast_nullable_to_non_nullable
as bool,parentalFeatures: null == parentalFeatures ? _self.parentalFeatures : parentalFeatures // ignore: cast_nullable_to_non_nullable
as bool,topTierPlan: null == topTierPlan ? _self.topTierPlan : topTierPlan // ignore: cast_nullable_to_non_nullable
as bool,promptUpgrades: null == promptUpgrades ? _self.promptUpgrades : promptUpgrades // ignore: cast_nullable_to_non_nullable
as bool,plans: null == plans ? _self._plans : plans // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$PromoCtaModel {

 String get id; String get title; String get desc; String get cta; String get whatsNew; bool get active;
/// Create a copy of PromoCtaModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PromoCtaModelCopyWith<PromoCtaModel> get copyWith => _$PromoCtaModelCopyWithImpl<PromoCtaModel>(this as PromoCtaModel, _$identity);

  /// Serializes this PromoCtaModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PromoCtaModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.desc, desc) || other.desc == desc)&&(identical(other.cta, cta) || other.cta == cta)&&(identical(other.whatsNew, whatsNew) || other.whatsNew == whatsNew)&&(identical(other.active, active) || other.active == active));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,desc,cta,whatsNew,active);

@override
String toString() {
  return 'PromoCtaModel(id: $id, title: $title, desc: $desc, cta: $cta, whatsNew: $whatsNew, active: $active)';
}


}

/// @nodoc
abstract mixin class $PromoCtaModelCopyWith<$Res>  {
  factory $PromoCtaModelCopyWith(PromoCtaModel value, $Res Function(PromoCtaModel) _then) = _$PromoCtaModelCopyWithImpl;
@useResult
$Res call({
 String id, String title, String desc, String cta, String whatsNew, bool active
});




}
/// @nodoc
class _$PromoCtaModelCopyWithImpl<$Res>
    implements $PromoCtaModelCopyWith<$Res> {
  _$PromoCtaModelCopyWithImpl(this._self, this._then);

  final PromoCtaModel _self;
  final $Res Function(PromoCtaModel) _then;

/// Create a copy of PromoCtaModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? desc = null,Object? cta = null,Object? whatsNew = null,Object? active = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,desc: null == desc ? _self.desc : desc // ignore: cast_nullable_to_non_nullable
as String,cta: null == cta ? _self.cta : cta // ignore: cast_nullable_to_non_nullable
as String,whatsNew: null == whatsNew ? _self.whatsNew : whatsNew // ignore: cast_nullable_to_non_nullable
as String,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PromoCtaModel].
extension PromoCtaModelPatterns on PromoCtaModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PromoCtaModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PromoCtaModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PromoCtaModel value)  $default,){
final _that = this;
switch (_that) {
case _PromoCtaModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PromoCtaModel value)?  $default,){
final _that = this;
switch (_that) {
case _PromoCtaModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String desc,  String cta,  String whatsNew,  bool active)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PromoCtaModel() when $default != null:
return $default(_that.id,_that.title,_that.desc,_that.cta,_that.whatsNew,_that.active);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String desc,  String cta,  String whatsNew,  bool active)  $default,) {final _that = this;
switch (_that) {
case _PromoCtaModel():
return $default(_that.id,_that.title,_that.desc,_that.cta,_that.whatsNew,_that.active);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String desc,  String cta,  String whatsNew,  bool active)?  $default,) {final _that = this;
switch (_that) {
case _PromoCtaModel() when $default != null:
return $default(_that.id,_that.title,_that.desc,_that.cta,_that.whatsNew,_that.active);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PromoCtaModel implements PromoCtaModel {
  const _PromoCtaModel({this.id = '', this.title = '', this.desc = '', this.cta = '', this.whatsNew = '', this.active = false});
  factory _PromoCtaModel.fromJson(Map<String, dynamic> json) => _$PromoCtaModelFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey() final  String title;
@override@JsonKey() final  String desc;
@override@JsonKey() final  String cta;
@override@JsonKey() final  String whatsNew;
@override@JsonKey() final  bool active;

/// Create a copy of PromoCtaModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PromoCtaModelCopyWith<_PromoCtaModel> get copyWith => __$PromoCtaModelCopyWithImpl<_PromoCtaModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PromoCtaModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PromoCtaModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.desc, desc) || other.desc == desc)&&(identical(other.cta, cta) || other.cta == cta)&&(identical(other.whatsNew, whatsNew) || other.whatsNew == whatsNew)&&(identical(other.active, active) || other.active == active));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,desc,cta,whatsNew,active);

@override
String toString() {
  return 'PromoCtaModel(id: $id, title: $title, desc: $desc, cta: $cta, whatsNew: $whatsNew, active: $active)';
}


}

/// @nodoc
abstract mixin class _$PromoCtaModelCopyWith<$Res> implements $PromoCtaModelCopyWith<$Res> {
  factory _$PromoCtaModelCopyWith(_PromoCtaModel value, $Res Function(_PromoCtaModel) _then) = __$PromoCtaModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String desc, String cta, String whatsNew, bool active
});




}
/// @nodoc
class __$PromoCtaModelCopyWithImpl<$Res>
    implements _$PromoCtaModelCopyWith<$Res> {
  __$PromoCtaModelCopyWithImpl(this._self, this._then);

  final _PromoCtaModel _self;
  final $Res Function(_PromoCtaModel) _then;

/// Create a copy of PromoCtaModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? desc = null,Object? cta = null,Object? whatsNew = null,Object? active = null,}) {
  return _then(_PromoCtaModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,desc: null == desc ? _self.desc : desc // ignore: cast_nullable_to_non_nullable
as String,cta: null == cta ? _self.cta : cta // ignore: cast_nullable_to_non_nullable
as String,whatsNew: null == whatsNew ? _self.whatsNew : whatsNew // ignore: cast_nullable_to_non_nullable
as String,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$FeatureFlagModel {

 String get featureId; int get minOSVersion; int get maxOSVersion; String get params; bool get enabled; bool get premiumOnly;
/// Create a copy of FeatureFlagModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FeatureFlagModelCopyWith<FeatureFlagModel> get copyWith => _$FeatureFlagModelCopyWithImpl<FeatureFlagModel>(this as FeatureFlagModel, _$identity);

  /// Serializes this FeatureFlagModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FeatureFlagModel&&(identical(other.featureId, featureId) || other.featureId == featureId)&&(identical(other.minOSVersion, minOSVersion) || other.minOSVersion == minOSVersion)&&(identical(other.maxOSVersion, maxOSVersion) || other.maxOSVersion == maxOSVersion)&&(identical(other.params, params) || other.params == params)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.premiumOnly, premiumOnly) || other.premiumOnly == premiumOnly));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,featureId,minOSVersion,maxOSVersion,params,enabled,premiumOnly);

@override
String toString() {
  return 'FeatureFlagModel(featureId: $featureId, minOSVersion: $minOSVersion, maxOSVersion: $maxOSVersion, params: $params, enabled: $enabled, premiumOnly: $premiumOnly)';
}


}

/// @nodoc
abstract mixin class $FeatureFlagModelCopyWith<$Res>  {
  factory $FeatureFlagModelCopyWith(FeatureFlagModel value, $Res Function(FeatureFlagModel) _then) = _$FeatureFlagModelCopyWithImpl;
@useResult
$Res call({
 String featureId, int minOSVersion, int maxOSVersion, String params, bool enabled, bool premiumOnly
});




}
/// @nodoc
class _$FeatureFlagModelCopyWithImpl<$Res>
    implements $FeatureFlagModelCopyWith<$Res> {
  _$FeatureFlagModelCopyWithImpl(this._self, this._then);

  final FeatureFlagModel _self;
  final $Res Function(FeatureFlagModel) _then;

/// Create a copy of FeatureFlagModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? featureId = null,Object? minOSVersion = null,Object? maxOSVersion = null,Object? params = null,Object? enabled = null,Object? premiumOnly = null,}) {
  return _then(_self.copyWith(
featureId: null == featureId ? _self.featureId : featureId // ignore: cast_nullable_to_non_nullable
as String,minOSVersion: null == minOSVersion ? _self.minOSVersion : minOSVersion // ignore: cast_nullable_to_non_nullable
as int,maxOSVersion: null == maxOSVersion ? _self.maxOSVersion : maxOSVersion // ignore: cast_nullable_to_non_nullable
as int,params: null == params ? _self.params : params // ignore: cast_nullable_to_non_nullable
as String,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,premiumOnly: null == premiumOnly ? _self.premiumOnly : premiumOnly // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [FeatureFlagModel].
extension FeatureFlagModelPatterns on FeatureFlagModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FeatureFlagModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FeatureFlagModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FeatureFlagModel value)  $default,){
final _that = this;
switch (_that) {
case _FeatureFlagModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FeatureFlagModel value)?  $default,){
final _that = this;
switch (_that) {
case _FeatureFlagModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String featureId,  int minOSVersion,  int maxOSVersion,  String params,  bool enabled,  bool premiumOnly)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FeatureFlagModel() when $default != null:
return $default(_that.featureId,_that.minOSVersion,_that.maxOSVersion,_that.params,_that.enabled,_that.premiumOnly);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String featureId,  int minOSVersion,  int maxOSVersion,  String params,  bool enabled,  bool premiumOnly)  $default,) {final _that = this;
switch (_that) {
case _FeatureFlagModel():
return $default(_that.featureId,_that.minOSVersion,_that.maxOSVersion,_that.params,_that.enabled,_that.premiumOnly);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String featureId,  int minOSVersion,  int maxOSVersion,  String params,  bool enabled,  bool premiumOnly)?  $default,) {final _that = this;
switch (_that) {
case _FeatureFlagModel() when $default != null:
return $default(_that.featureId,_that.minOSVersion,_that.maxOSVersion,_that.params,_that.enabled,_that.premiumOnly);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FeatureFlagModel implements FeatureFlagModel {
  const _FeatureFlagModel({required this.featureId, this.minOSVersion = 0, this.maxOSVersion = 999, this.params = '', this.enabled = true, this.premiumOnly = false});
  factory _FeatureFlagModel.fromJson(Map<String, dynamic> json) => _$FeatureFlagModelFromJson(json);

@override final  String featureId;
@override@JsonKey() final  int minOSVersion;
@override@JsonKey() final  int maxOSVersion;
@override@JsonKey() final  String params;
@override@JsonKey() final  bool enabled;
@override@JsonKey() final  bool premiumOnly;

/// Create a copy of FeatureFlagModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FeatureFlagModelCopyWith<_FeatureFlagModel> get copyWith => __$FeatureFlagModelCopyWithImpl<_FeatureFlagModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FeatureFlagModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FeatureFlagModel&&(identical(other.featureId, featureId) || other.featureId == featureId)&&(identical(other.minOSVersion, minOSVersion) || other.minOSVersion == minOSVersion)&&(identical(other.maxOSVersion, maxOSVersion) || other.maxOSVersion == maxOSVersion)&&(identical(other.params, params) || other.params == params)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.premiumOnly, premiumOnly) || other.premiumOnly == premiumOnly));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,featureId,minOSVersion,maxOSVersion,params,enabled,premiumOnly);

@override
String toString() {
  return 'FeatureFlagModel(featureId: $featureId, minOSVersion: $minOSVersion, maxOSVersion: $maxOSVersion, params: $params, enabled: $enabled, premiumOnly: $premiumOnly)';
}


}

/// @nodoc
abstract mixin class _$FeatureFlagModelCopyWith<$Res> implements $FeatureFlagModelCopyWith<$Res> {
  factory _$FeatureFlagModelCopyWith(_FeatureFlagModel value, $Res Function(_FeatureFlagModel) _then) = __$FeatureFlagModelCopyWithImpl;
@override @useResult
$Res call({
 String featureId, int minOSVersion, int maxOSVersion, String params, bool enabled, bool premiumOnly
});




}
/// @nodoc
class __$FeatureFlagModelCopyWithImpl<$Res>
    implements _$FeatureFlagModelCopyWith<$Res> {
  __$FeatureFlagModelCopyWithImpl(this._self, this._then);

  final _FeatureFlagModel _self;
  final $Res Function(_FeatureFlagModel) _then;

/// Create a copy of FeatureFlagModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? featureId = null,Object? minOSVersion = null,Object? maxOSVersion = null,Object? params = null,Object? enabled = null,Object? premiumOnly = null,}) {
  return _then(_FeatureFlagModel(
featureId: null == featureId ? _self.featureId : featureId // ignore: cast_nullable_to_non_nullable
as String,minOSVersion: null == minOSVersion ? _self.minOSVersion : minOSVersion // ignore: cast_nullable_to_non_nullable
as int,maxOSVersion: null == maxOSVersion ? _self.maxOSVersion : maxOSVersion // ignore: cast_nullable_to_non_nullable
as int,params: null == params ? _self.params : params // ignore: cast_nullable_to_non_nullable
as String,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,premiumOnly: null == premiumOnly ? _self.premiumOnly : premiumOnly // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
