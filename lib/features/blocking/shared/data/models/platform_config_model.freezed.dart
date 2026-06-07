// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'platform_config_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PlatformConfigModel {

@JsonKey(name: 'responsecode') int get responseCode; Map<String, AppDetailsModel> get featuredApps;
/// Create a copy of PlatformConfigModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlatformConfigModelCopyWith<PlatformConfigModel> get copyWith => _$PlatformConfigModelCopyWithImpl<PlatformConfigModel>(this as PlatformConfigModel, _$identity);

  /// Serializes this PlatformConfigModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlatformConfigModel&&(identical(other.responseCode, responseCode) || other.responseCode == responseCode)&&const DeepCollectionEquality().equals(other.featuredApps, featuredApps));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,responseCode,const DeepCollectionEquality().hash(featuredApps));

@override
String toString() {
  return 'PlatformConfigModel(responseCode: $responseCode, featuredApps: $featuredApps)';
}


}

/// @nodoc
abstract mixin class $PlatformConfigModelCopyWith<$Res>  {
  factory $PlatformConfigModelCopyWith(PlatformConfigModel value, $Res Function(PlatformConfigModel) _then) = _$PlatformConfigModelCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'responsecode') int responseCode, Map<String, AppDetailsModel> featuredApps
});




}
/// @nodoc
class _$PlatformConfigModelCopyWithImpl<$Res>
    implements $PlatformConfigModelCopyWith<$Res> {
  _$PlatformConfigModelCopyWithImpl(this._self, this._then);

  final PlatformConfigModel _self;
  final $Res Function(PlatformConfigModel) _then;

/// Create a copy of PlatformConfigModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? responseCode = null,Object? featuredApps = null,}) {
  return _then(_self.copyWith(
responseCode: null == responseCode ? _self.responseCode : responseCode // ignore: cast_nullable_to_non_nullable
as int,featuredApps: null == featuredApps ? _self.featuredApps : featuredApps // ignore: cast_nullable_to_non_nullable
as Map<String, AppDetailsModel>,
  ));
}

}


/// Adds pattern-matching-related methods to [PlatformConfigModel].
extension PlatformConfigModelPatterns on PlatformConfigModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlatformConfigModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlatformConfigModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlatformConfigModel value)  $default,){
final _that = this;
switch (_that) {
case _PlatformConfigModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlatformConfigModel value)?  $default,){
final _that = this;
switch (_that) {
case _PlatformConfigModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'responsecode')  int responseCode,  Map<String, AppDetailsModel> featuredApps)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlatformConfigModel() when $default != null:
return $default(_that.responseCode,_that.featuredApps);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'responsecode')  int responseCode,  Map<String, AppDetailsModel> featuredApps)  $default,) {final _that = this;
switch (_that) {
case _PlatformConfigModel():
return $default(_that.responseCode,_that.featuredApps);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'responsecode')  int responseCode,  Map<String, AppDetailsModel> featuredApps)?  $default,) {final _that = this;
switch (_that) {
case _PlatformConfigModel() when $default != null:
return $default(_that.responseCode,_that.featuredApps);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlatformConfigModel implements PlatformConfigModel {
  const _PlatformConfigModel({@JsonKey(name: 'responsecode') this.responseCode = 200, final  Map<String, AppDetailsModel> featuredApps = const <String, AppDetailsModel>{}}): _featuredApps = featuredApps;
  factory _PlatformConfigModel.fromJson(Map<String, dynamic> json) => _$PlatformConfigModelFromJson(json);

@override@JsonKey(name: 'responsecode') final  int responseCode;
 final  Map<String, AppDetailsModel> _featuredApps;
@override@JsonKey() Map<String, AppDetailsModel> get featuredApps {
  if (_featuredApps is EqualUnmodifiableMapView) return _featuredApps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_featuredApps);
}


/// Create a copy of PlatformConfigModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlatformConfigModelCopyWith<_PlatformConfigModel> get copyWith => __$PlatformConfigModelCopyWithImpl<_PlatformConfigModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlatformConfigModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlatformConfigModel&&(identical(other.responseCode, responseCode) || other.responseCode == responseCode)&&const DeepCollectionEquality().equals(other._featuredApps, _featuredApps));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,responseCode,const DeepCollectionEquality().hash(_featuredApps));

@override
String toString() {
  return 'PlatformConfigModel(responseCode: $responseCode, featuredApps: $featuredApps)';
}


}

/// @nodoc
abstract mixin class _$PlatformConfigModelCopyWith<$Res> implements $PlatformConfigModelCopyWith<$Res> {
  factory _$PlatformConfigModelCopyWith(_PlatformConfigModel value, $Res Function(_PlatformConfigModel) _then) = __$PlatformConfigModelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'responsecode') int responseCode, Map<String, AppDetailsModel> featuredApps
});




}
/// @nodoc
class __$PlatformConfigModelCopyWithImpl<$Res>
    implements _$PlatformConfigModelCopyWith<$Res> {
  __$PlatformConfigModelCopyWithImpl(this._self, this._then);

  final _PlatformConfigModel _self;
  final $Res Function(_PlatformConfigModel) _then;

/// Create a copy of PlatformConfigModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? responseCode = null,Object? featuredApps = null,}) {
  return _then(_PlatformConfigModel(
responseCode: null == responseCode ? _self.responseCode : responseCode // ignore: cast_nullable_to_non_nullable
as int,featuredApps: null == featuredApps ? _self._featuredApps : featuredApps // ignore: cast_nullable_to_non_nullable
as Map<String, AppDetailsModel>,
  ));
}


}


/// @nodoc
mixin _$AppDetailsModel {

 String get packageName; String get appName; String get actionOnLaunch; int get paramsClass; String get params; int get priority; String get iconUrl; bool get premiumExclusive; int get minAppVersion; int get maxAppVersion; bool get supportInAppYtShorts; List<PlatformModel> get platforms; bool get showInDashboard; bool get showIfNotInstalled; List<AppOpenActionModel> get appOpenActions;@JsonKey(name: 'browser') bool get isBrowser;
/// Create a copy of AppDetailsModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppDetailsModelCopyWith<AppDetailsModel> get copyWith => _$AppDetailsModelCopyWithImpl<AppDetailsModel>(this as AppDetailsModel, _$identity);

  /// Serializes this AppDetailsModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppDetailsModel&&(identical(other.packageName, packageName) || other.packageName == packageName)&&(identical(other.appName, appName) || other.appName == appName)&&(identical(other.actionOnLaunch, actionOnLaunch) || other.actionOnLaunch == actionOnLaunch)&&(identical(other.paramsClass, paramsClass) || other.paramsClass == paramsClass)&&(identical(other.params, params) || other.params == params)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl)&&(identical(other.premiumExclusive, premiumExclusive) || other.premiumExclusive == premiumExclusive)&&(identical(other.minAppVersion, minAppVersion) || other.minAppVersion == minAppVersion)&&(identical(other.maxAppVersion, maxAppVersion) || other.maxAppVersion == maxAppVersion)&&(identical(other.supportInAppYtShorts, supportInAppYtShorts) || other.supportInAppYtShorts == supportInAppYtShorts)&&const DeepCollectionEquality().equals(other.platforms, platforms)&&(identical(other.showInDashboard, showInDashboard) || other.showInDashboard == showInDashboard)&&(identical(other.showIfNotInstalled, showIfNotInstalled) || other.showIfNotInstalled == showIfNotInstalled)&&const DeepCollectionEquality().equals(other.appOpenActions, appOpenActions)&&(identical(other.isBrowser, isBrowser) || other.isBrowser == isBrowser));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,packageName,appName,actionOnLaunch,paramsClass,params,priority,iconUrl,premiumExclusive,minAppVersion,maxAppVersion,supportInAppYtShorts,const DeepCollectionEquality().hash(platforms),showInDashboard,showIfNotInstalled,const DeepCollectionEquality().hash(appOpenActions),isBrowser);

@override
String toString() {
  return 'AppDetailsModel(packageName: $packageName, appName: $appName, actionOnLaunch: $actionOnLaunch, paramsClass: $paramsClass, params: $params, priority: $priority, iconUrl: $iconUrl, premiumExclusive: $premiumExclusive, minAppVersion: $minAppVersion, maxAppVersion: $maxAppVersion, supportInAppYtShorts: $supportInAppYtShorts, platforms: $platforms, showInDashboard: $showInDashboard, showIfNotInstalled: $showIfNotInstalled, appOpenActions: $appOpenActions, isBrowser: $isBrowser)';
}


}

/// @nodoc
abstract mixin class $AppDetailsModelCopyWith<$Res>  {
  factory $AppDetailsModelCopyWith(AppDetailsModel value, $Res Function(AppDetailsModel) _then) = _$AppDetailsModelCopyWithImpl;
@useResult
$Res call({
 String packageName, String appName, String actionOnLaunch, int paramsClass, String params, int priority, String iconUrl, bool premiumExclusive, int minAppVersion, int maxAppVersion, bool supportInAppYtShorts, List<PlatformModel> platforms, bool showInDashboard, bool showIfNotInstalled, List<AppOpenActionModel> appOpenActions,@JsonKey(name: 'browser') bool isBrowser
});




}
/// @nodoc
class _$AppDetailsModelCopyWithImpl<$Res>
    implements $AppDetailsModelCopyWith<$Res> {
  _$AppDetailsModelCopyWithImpl(this._self, this._then);

  final AppDetailsModel _self;
  final $Res Function(AppDetailsModel) _then;

/// Create a copy of AppDetailsModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? packageName = null,Object? appName = null,Object? actionOnLaunch = null,Object? paramsClass = null,Object? params = null,Object? priority = null,Object? iconUrl = null,Object? premiumExclusive = null,Object? minAppVersion = null,Object? maxAppVersion = null,Object? supportInAppYtShorts = null,Object? platforms = null,Object? showInDashboard = null,Object? showIfNotInstalled = null,Object? appOpenActions = null,Object? isBrowser = null,}) {
  return _then(_self.copyWith(
packageName: null == packageName ? _self.packageName : packageName // ignore: cast_nullable_to_non_nullable
as String,appName: null == appName ? _self.appName : appName // ignore: cast_nullable_to_non_nullable
as String,actionOnLaunch: null == actionOnLaunch ? _self.actionOnLaunch : actionOnLaunch // ignore: cast_nullable_to_non_nullable
as String,paramsClass: null == paramsClass ? _self.paramsClass : paramsClass // ignore: cast_nullable_to_non_nullable
as int,params: null == params ? _self.params : params // ignore: cast_nullable_to_non_nullable
as String,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int,iconUrl: null == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String,premiumExclusive: null == premiumExclusive ? _self.premiumExclusive : premiumExclusive // ignore: cast_nullable_to_non_nullable
as bool,minAppVersion: null == minAppVersion ? _self.minAppVersion : minAppVersion // ignore: cast_nullable_to_non_nullable
as int,maxAppVersion: null == maxAppVersion ? _self.maxAppVersion : maxAppVersion // ignore: cast_nullable_to_non_nullable
as int,supportInAppYtShorts: null == supportInAppYtShorts ? _self.supportInAppYtShorts : supportInAppYtShorts // ignore: cast_nullable_to_non_nullable
as bool,platforms: null == platforms ? _self.platforms : platforms // ignore: cast_nullable_to_non_nullable
as List<PlatformModel>,showInDashboard: null == showInDashboard ? _self.showInDashboard : showInDashboard // ignore: cast_nullable_to_non_nullable
as bool,showIfNotInstalled: null == showIfNotInstalled ? _self.showIfNotInstalled : showIfNotInstalled // ignore: cast_nullable_to_non_nullable
as bool,appOpenActions: null == appOpenActions ? _self.appOpenActions : appOpenActions // ignore: cast_nullable_to_non_nullable
as List<AppOpenActionModel>,isBrowser: null == isBrowser ? _self.isBrowser : isBrowser // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AppDetailsModel].
extension AppDetailsModelPatterns on AppDetailsModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppDetailsModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppDetailsModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppDetailsModel value)  $default,){
final _that = this;
switch (_that) {
case _AppDetailsModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppDetailsModel value)?  $default,){
final _that = this;
switch (_that) {
case _AppDetailsModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String packageName,  String appName,  String actionOnLaunch,  int paramsClass,  String params,  int priority,  String iconUrl,  bool premiumExclusive,  int minAppVersion,  int maxAppVersion,  bool supportInAppYtShorts,  List<PlatformModel> platforms,  bool showInDashboard,  bool showIfNotInstalled,  List<AppOpenActionModel> appOpenActions, @JsonKey(name: 'browser')  bool isBrowser)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppDetailsModel() when $default != null:
return $default(_that.packageName,_that.appName,_that.actionOnLaunch,_that.paramsClass,_that.params,_that.priority,_that.iconUrl,_that.premiumExclusive,_that.minAppVersion,_that.maxAppVersion,_that.supportInAppYtShorts,_that.platforms,_that.showInDashboard,_that.showIfNotInstalled,_that.appOpenActions,_that.isBrowser);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String packageName,  String appName,  String actionOnLaunch,  int paramsClass,  String params,  int priority,  String iconUrl,  bool premiumExclusive,  int minAppVersion,  int maxAppVersion,  bool supportInAppYtShorts,  List<PlatformModel> platforms,  bool showInDashboard,  bool showIfNotInstalled,  List<AppOpenActionModel> appOpenActions, @JsonKey(name: 'browser')  bool isBrowser)  $default,) {final _that = this;
switch (_that) {
case _AppDetailsModel():
return $default(_that.packageName,_that.appName,_that.actionOnLaunch,_that.paramsClass,_that.params,_that.priority,_that.iconUrl,_that.premiumExclusive,_that.minAppVersion,_that.maxAppVersion,_that.supportInAppYtShorts,_that.platforms,_that.showInDashboard,_that.showIfNotInstalled,_that.appOpenActions,_that.isBrowser);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String packageName,  String appName,  String actionOnLaunch,  int paramsClass,  String params,  int priority,  String iconUrl,  bool premiumExclusive,  int minAppVersion,  int maxAppVersion,  bool supportInAppYtShorts,  List<PlatformModel> platforms,  bool showInDashboard,  bool showIfNotInstalled,  List<AppOpenActionModel> appOpenActions, @JsonKey(name: 'browser')  bool isBrowser)?  $default,) {final _that = this;
switch (_that) {
case _AppDetailsModel() when $default != null:
return $default(_that.packageName,_that.appName,_that.actionOnLaunch,_that.paramsClass,_that.params,_that.priority,_that.iconUrl,_that.premiumExclusive,_that.minAppVersion,_that.maxAppVersion,_that.supportInAppYtShorts,_that.platforms,_that.showInDashboard,_that.showIfNotInstalled,_that.appOpenActions,_that.isBrowser);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppDetailsModel implements AppDetailsModel {
  const _AppDetailsModel({required this.packageName, this.appName = '', this.actionOnLaunch = 'NONE', this.paramsClass = -1, this.params = '{}', this.priority = 0, this.iconUrl = '', this.premiumExclusive = false, this.minAppVersion = -1, this.maxAppVersion = -1, this.supportInAppYtShorts = false, final  List<PlatformModel> platforms = const <PlatformModel>[], this.showInDashboard = false, this.showIfNotInstalled = false, final  List<AppOpenActionModel> appOpenActions = const <AppOpenActionModel>[], @JsonKey(name: 'browser') this.isBrowser = false}): _platforms = platforms,_appOpenActions = appOpenActions;
  factory _AppDetailsModel.fromJson(Map<String, dynamic> json) => _$AppDetailsModelFromJson(json);

@override final  String packageName;
@override@JsonKey() final  String appName;
@override@JsonKey() final  String actionOnLaunch;
@override@JsonKey() final  int paramsClass;
@override@JsonKey() final  String params;
@override@JsonKey() final  int priority;
@override@JsonKey() final  String iconUrl;
@override@JsonKey() final  bool premiumExclusive;
@override@JsonKey() final  int minAppVersion;
@override@JsonKey() final  int maxAppVersion;
@override@JsonKey() final  bool supportInAppYtShorts;
 final  List<PlatformModel> _platforms;
@override@JsonKey() List<PlatformModel> get platforms {
  if (_platforms is EqualUnmodifiableListView) return _platforms;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_platforms);
}

@override@JsonKey() final  bool showInDashboard;
@override@JsonKey() final  bool showIfNotInstalled;
 final  List<AppOpenActionModel> _appOpenActions;
@override@JsonKey() List<AppOpenActionModel> get appOpenActions {
  if (_appOpenActions is EqualUnmodifiableListView) return _appOpenActions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_appOpenActions);
}

@override@JsonKey(name: 'browser') final  bool isBrowser;

/// Create a copy of AppDetailsModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppDetailsModelCopyWith<_AppDetailsModel> get copyWith => __$AppDetailsModelCopyWithImpl<_AppDetailsModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppDetailsModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppDetailsModel&&(identical(other.packageName, packageName) || other.packageName == packageName)&&(identical(other.appName, appName) || other.appName == appName)&&(identical(other.actionOnLaunch, actionOnLaunch) || other.actionOnLaunch == actionOnLaunch)&&(identical(other.paramsClass, paramsClass) || other.paramsClass == paramsClass)&&(identical(other.params, params) || other.params == params)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl)&&(identical(other.premiumExclusive, premiumExclusive) || other.premiumExclusive == premiumExclusive)&&(identical(other.minAppVersion, minAppVersion) || other.minAppVersion == minAppVersion)&&(identical(other.maxAppVersion, maxAppVersion) || other.maxAppVersion == maxAppVersion)&&(identical(other.supportInAppYtShorts, supportInAppYtShorts) || other.supportInAppYtShorts == supportInAppYtShorts)&&const DeepCollectionEquality().equals(other._platforms, _platforms)&&(identical(other.showInDashboard, showInDashboard) || other.showInDashboard == showInDashboard)&&(identical(other.showIfNotInstalled, showIfNotInstalled) || other.showIfNotInstalled == showIfNotInstalled)&&const DeepCollectionEquality().equals(other._appOpenActions, _appOpenActions)&&(identical(other.isBrowser, isBrowser) || other.isBrowser == isBrowser));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,packageName,appName,actionOnLaunch,paramsClass,params,priority,iconUrl,premiumExclusive,minAppVersion,maxAppVersion,supportInAppYtShorts,const DeepCollectionEquality().hash(_platforms),showInDashboard,showIfNotInstalled,const DeepCollectionEquality().hash(_appOpenActions),isBrowser);

@override
String toString() {
  return 'AppDetailsModel(packageName: $packageName, appName: $appName, actionOnLaunch: $actionOnLaunch, paramsClass: $paramsClass, params: $params, priority: $priority, iconUrl: $iconUrl, premiumExclusive: $premiumExclusive, minAppVersion: $minAppVersion, maxAppVersion: $maxAppVersion, supportInAppYtShorts: $supportInAppYtShorts, platforms: $platforms, showInDashboard: $showInDashboard, showIfNotInstalled: $showIfNotInstalled, appOpenActions: $appOpenActions, isBrowser: $isBrowser)';
}


}

/// @nodoc
abstract mixin class _$AppDetailsModelCopyWith<$Res> implements $AppDetailsModelCopyWith<$Res> {
  factory _$AppDetailsModelCopyWith(_AppDetailsModel value, $Res Function(_AppDetailsModel) _then) = __$AppDetailsModelCopyWithImpl;
@override @useResult
$Res call({
 String packageName, String appName, String actionOnLaunch, int paramsClass, String params, int priority, String iconUrl, bool premiumExclusive, int minAppVersion, int maxAppVersion, bool supportInAppYtShorts, List<PlatformModel> platforms, bool showInDashboard, bool showIfNotInstalled, List<AppOpenActionModel> appOpenActions,@JsonKey(name: 'browser') bool isBrowser
});




}
/// @nodoc
class __$AppDetailsModelCopyWithImpl<$Res>
    implements _$AppDetailsModelCopyWith<$Res> {
  __$AppDetailsModelCopyWithImpl(this._self, this._then);

  final _AppDetailsModel _self;
  final $Res Function(_AppDetailsModel) _then;

/// Create a copy of AppDetailsModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? packageName = null,Object? appName = null,Object? actionOnLaunch = null,Object? paramsClass = null,Object? params = null,Object? priority = null,Object? iconUrl = null,Object? premiumExclusive = null,Object? minAppVersion = null,Object? maxAppVersion = null,Object? supportInAppYtShorts = null,Object? platforms = null,Object? showInDashboard = null,Object? showIfNotInstalled = null,Object? appOpenActions = null,Object? isBrowser = null,}) {
  return _then(_AppDetailsModel(
packageName: null == packageName ? _self.packageName : packageName // ignore: cast_nullable_to_non_nullable
as String,appName: null == appName ? _self.appName : appName // ignore: cast_nullable_to_non_nullable
as String,actionOnLaunch: null == actionOnLaunch ? _self.actionOnLaunch : actionOnLaunch // ignore: cast_nullable_to_non_nullable
as String,paramsClass: null == paramsClass ? _self.paramsClass : paramsClass // ignore: cast_nullable_to_non_nullable
as int,params: null == params ? _self.params : params // ignore: cast_nullable_to_non_nullable
as String,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int,iconUrl: null == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String,premiumExclusive: null == premiumExclusive ? _self.premiumExclusive : premiumExclusive // ignore: cast_nullable_to_non_nullable
as bool,minAppVersion: null == minAppVersion ? _self.minAppVersion : minAppVersion // ignore: cast_nullable_to_non_nullable
as int,maxAppVersion: null == maxAppVersion ? _self.maxAppVersion : maxAppVersion // ignore: cast_nullable_to_non_nullable
as int,supportInAppYtShorts: null == supportInAppYtShorts ? _self.supportInAppYtShorts : supportInAppYtShorts // ignore: cast_nullable_to_non_nullable
as bool,platforms: null == platforms ? _self._platforms : platforms // ignore: cast_nullable_to_non_nullable
as List<PlatformModel>,showInDashboard: null == showInDashboard ? _self.showInDashboard : showInDashboard // ignore: cast_nullable_to_non_nullable
as bool,showIfNotInstalled: null == showIfNotInstalled ? _self.showIfNotInstalled : showIfNotInstalled // ignore: cast_nullable_to_non_nullable
as bool,appOpenActions: null == appOpenActions ? _self._appOpenActions : appOpenActions // ignore: cast_nullable_to_non_nullable
as List<AppOpenActionModel>,isBrowser: null == isBrowser ? _self.isBrowser : isBrowser // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$PlatformModel {

 String get platformId; String get packageName; String get platformName; String get iconUrl; Map<String, DetectorModel> get detectors; String get detectionType; bool get defaultStatus; bool get customizable; bool get showInDashboard; bool get showAlwaysInBlockList; bool get premiumExclusive;
/// Create a copy of PlatformModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlatformModelCopyWith<PlatformModel> get copyWith => _$PlatformModelCopyWithImpl<PlatformModel>(this as PlatformModel, _$identity);

  /// Serializes this PlatformModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlatformModel&&(identical(other.platformId, platformId) || other.platformId == platformId)&&(identical(other.packageName, packageName) || other.packageName == packageName)&&(identical(other.platformName, platformName) || other.platformName == platformName)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl)&&const DeepCollectionEquality().equals(other.detectors, detectors)&&(identical(other.detectionType, detectionType) || other.detectionType == detectionType)&&(identical(other.defaultStatus, defaultStatus) || other.defaultStatus == defaultStatus)&&(identical(other.customizable, customizable) || other.customizable == customizable)&&(identical(other.showInDashboard, showInDashboard) || other.showInDashboard == showInDashboard)&&(identical(other.showAlwaysInBlockList, showAlwaysInBlockList) || other.showAlwaysInBlockList == showAlwaysInBlockList)&&(identical(other.premiumExclusive, premiumExclusive) || other.premiumExclusive == premiumExclusive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,platformId,packageName,platformName,iconUrl,const DeepCollectionEquality().hash(detectors),detectionType,defaultStatus,customizable,showInDashboard,showAlwaysInBlockList,premiumExclusive);

@override
String toString() {
  return 'PlatformModel(platformId: $platformId, packageName: $packageName, platformName: $platformName, iconUrl: $iconUrl, detectors: $detectors, detectionType: $detectionType, defaultStatus: $defaultStatus, customizable: $customizable, showInDashboard: $showInDashboard, showAlwaysInBlockList: $showAlwaysInBlockList, premiumExclusive: $premiumExclusive)';
}


}

/// @nodoc
abstract mixin class $PlatformModelCopyWith<$Res>  {
  factory $PlatformModelCopyWith(PlatformModel value, $Res Function(PlatformModel) _then) = _$PlatformModelCopyWithImpl;
@useResult
$Res call({
 String platformId, String packageName, String platformName, String iconUrl, Map<String, DetectorModel> detectors, String detectionType, bool defaultStatus, bool customizable, bool showInDashboard, bool showAlwaysInBlockList, bool premiumExclusive
});




}
/// @nodoc
class _$PlatformModelCopyWithImpl<$Res>
    implements $PlatformModelCopyWith<$Res> {
  _$PlatformModelCopyWithImpl(this._self, this._then);

  final PlatformModel _self;
  final $Res Function(PlatformModel) _then;

/// Create a copy of PlatformModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? platformId = null,Object? packageName = null,Object? platformName = null,Object? iconUrl = null,Object? detectors = null,Object? detectionType = null,Object? defaultStatus = null,Object? customizable = null,Object? showInDashboard = null,Object? showAlwaysInBlockList = null,Object? premiumExclusive = null,}) {
  return _then(_self.copyWith(
platformId: null == platformId ? _self.platformId : platformId // ignore: cast_nullable_to_non_nullable
as String,packageName: null == packageName ? _self.packageName : packageName // ignore: cast_nullable_to_non_nullable
as String,platformName: null == platformName ? _self.platformName : platformName // ignore: cast_nullable_to_non_nullable
as String,iconUrl: null == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String,detectors: null == detectors ? _self.detectors : detectors // ignore: cast_nullable_to_non_nullable
as Map<String, DetectorModel>,detectionType: null == detectionType ? _self.detectionType : detectionType // ignore: cast_nullable_to_non_nullable
as String,defaultStatus: null == defaultStatus ? _self.defaultStatus : defaultStatus // ignore: cast_nullable_to_non_nullable
as bool,customizable: null == customizable ? _self.customizable : customizable // ignore: cast_nullable_to_non_nullable
as bool,showInDashboard: null == showInDashboard ? _self.showInDashboard : showInDashboard // ignore: cast_nullable_to_non_nullable
as bool,showAlwaysInBlockList: null == showAlwaysInBlockList ? _self.showAlwaysInBlockList : showAlwaysInBlockList // ignore: cast_nullable_to_non_nullable
as bool,premiumExclusive: null == premiumExclusive ? _self.premiumExclusive : premiumExclusive // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PlatformModel].
extension PlatformModelPatterns on PlatformModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlatformModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlatformModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlatformModel value)  $default,){
final _that = this;
switch (_that) {
case _PlatformModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlatformModel value)?  $default,){
final _that = this;
switch (_that) {
case _PlatformModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String platformId,  String packageName,  String platformName,  String iconUrl,  Map<String, DetectorModel> detectors,  String detectionType,  bool defaultStatus,  bool customizable,  bool showInDashboard,  bool showAlwaysInBlockList,  bool premiumExclusive)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlatformModel() when $default != null:
return $default(_that.platformId,_that.packageName,_that.platformName,_that.iconUrl,_that.detectors,_that.detectionType,_that.defaultStatus,_that.customizable,_that.showInDashboard,_that.showAlwaysInBlockList,_that.premiumExclusive);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String platformId,  String packageName,  String platformName,  String iconUrl,  Map<String, DetectorModel> detectors,  String detectionType,  bool defaultStatus,  bool customizable,  bool showInDashboard,  bool showAlwaysInBlockList,  bool premiumExclusive)  $default,) {final _that = this;
switch (_that) {
case _PlatformModel():
return $default(_that.platformId,_that.packageName,_that.platformName,_that.iconUrl,_that.detectors,_that.detectionType,_that.defaultStatus,_that.customizable,_that.showInDashboard,_that.showAlwaysInBlockList,_that.premiumExclusive);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String platformId,  String packageName,  String platformName,  String iconUrl,  Map<String, DetectorModel> detectors,  String detectionType,  bool defaultStatus,  bool customizable,  bool showInDashboard,  bool showAlwaysInBlockList,  bool premiumExclusive)?  $default,) {final _that = this;
switch (_that) {
case _PlatformModel() when $default != null:
return $default(_that.platformId,_that.packageName,_that.platformName,_that.iconUrl,_that.detectors,_that.detectionType,_that.defaultStatus,_that.customizable,_that.showInDashboard,_that.showAlwaysInBlockList,_that.premiumExclusive);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlatformModel implements PlatformModel {
  const _PlatformModel({required this.platformId, this.packageName = '', this.platformName = '', this.iconUrl = '', final  Map<String, DetectorModel> detectors = const <String, DetectorModel>{}, this.detectionType = 'LEGACY', this.defaultStatus = true, this.customizable = true, this.showInDashboard = false, this.showAlwaysInBlockList = false, this.premiumExclusive = false}): _detectors = detectors;
  factory _PlatformModel.fromJson(Map<String, dynamic> json) => _$PlatformModelFromJson(json);

@override final  String platformId;
@override@JsonKey() final  String packageName;
@override@JsonKey() final  String platformName;
@override@JsonKey() final  String iconUrl;
 final  Map<String, DetectorModel> _detectors;
@override@JsonKey() Map<String, DetectorModel> get detectors {
  if (_detectors is EqualUnmodifiableMapView) return _detectors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_detectors);
}

@override@JsonKey() final  String detectionType;
@override@JsonKey() final  bool defaultStatus;
@override@JsonKey() final  bool customizable;
@override@JsonKey() final  bool showInDashboard;
@override@JsonKey() final  bool showAlwaysInBlockList;
@override@JsonKey() final  bool premiumExclusive;

/// Create a copy of PlatformModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlatformModelCopyWith<_PlatformModel> get copyWith => __$PlatformModelCopyWithImpl<_PlatformModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlatformModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlatformModel&&(identical(other.platformId, platformId) || other.platformId == platformId)&&(identical(other.packageName, packageName) || other.packageName == packageName)&&(identical(other.platformName, platformName) || other.platformName == platformName)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl)&&const DeepCollectionEquality().equals(other._detectors, _detectors)&&(identical(other.detectionType, detectionType) || other.detectionType == detectionType)&&(identical(other.defaultStatus, defaultStatus) || other.defaultStatus == defaultStatus)&&(identical(other.customizable, customizable) || other.customizable == customizable)&&(identical(other.showInDashboard, showInDashboard) || other.showInDashboard == showInDashboard)&&(identical(other.showAlwaysInBlockList, showAlwaysInBlockList) || other.showAlwaysInBlockList == showAlwaysInBlockList)&&(identical(other.premiumExclusive, premiumExclusive) || other.premiumExclusive == premiumExclusive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,platformId,packageName,platformName,iconUrl,const DeepCollectionEquality().hash(_detectors),detectionType,defaultStatus,customizable,showInDashboard,showAlwaysInBlockList,premiumExclusive);

@override
String toString() {
  return 'PlatformModel(platformId: $platformId, packageName: $packageName, platformName: $platformName, iconUrl: $iconUrl, detectors: $detectors, detectionType: $detectionType, defaultStatus: $defaultStatus, customizable: $customizable, showInDashboard: $showInDashboard, showAlwaysInBlockList: $showAlwaysInBlockList, premiumExclusive: $premiumExclusive)';
}


}

/// @nodoc
abstract mixin class _$PlatformModelCopyWith<$Res> implements $PlatformModelCopyWith<$Res> {
  factory _$PlatformModelCopyWith(_PlatformModel value, $Res Function(_PlatformModel) _then) = __$PlatformModelCopyWithImpl;
@override @useResult
$Res call({
 String platformId, String packageName, String platformName, String iconUrl, Map<String, DetectorModel> detectors, String detectionType, bool defaultStatus, bool customizable, bool showInDashboard, bool showAlwaysInBlockList, bool premiumExclusive
});




}
/// @nodoc
class __$PlatformModelCopyWithImpl<$Res>
    implements _$PlatformModelCopyWith<$Res> {
  __$PlatformModelCopyWithImpl(this._self, this._then);

  final _PlatformModel _self;
  final $Res Function(_PlatformModel) _then;

/// Create a copy of PlatformModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? platformId = null,Object? packageName = null,Object? platformName = null,Object? iconUrl = null,Object? detectors = null,Object? detectionType = null,Object? defaultStatus = null,Object? customizable = null,Object? showInDashboard = null,Object? showAlwaysInBlockList = null,Object? premiumExclusive = null,}) {
  return _then(_PlatformModel(
platformId: null == platformId ? _self.platformId : platformId // ignore: cast_nullable_to_non_nullable
as String,packageName: null == packageName ? _self.packageName : packageName // ignore: cast_nullable_to_non_nullable
as String,platformName: null == platformName ? _self.platformName : platformName // ignore: cast_nullable_to_non_nullable
as String,iconUrl: null == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String,detectors: null == detectors ? _self._detectors : detectors // ignore: cast_nullable_to_non_nullable
as Map<String, DetectorModel>,detectionType: null == detectionType ? _self.detectionType : detectionType // ignore: cast_nullable_to_non_nullable
as String,defaultStatus: null == defaultStatus ? _self.defaultStatus : defaultStatus // ignore: cast_nullable_to_non_nullable
as bool,customizable: null == customizable ? _self.customizable : customizable // ignore: cast_nullable_to_non_nullable
as bool,showInDashboard: null == showInDashboard ? _self.showInDashboard : showInDashboard // ignore: cast_nullable_to_non_nullable
as bool,showAlwaysInBlockList: null == showAlwaysInBlockList ? _self.showAlwaysInBlockList : showAlwaysInBlockList // ignore: cast_nullable_to_non_nullable
as bool,premiumExclusive: null == premiumExclusive ? _self.premiumExclusive : premiumExclusive // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$DetectorModel {

 List<String> get supportedBlockModes; String get defaultBlockMode; int get priority; List<String> get identifiers; int get childNodeLimit; String get actionOnLaunch; int get paramsClass; String get params; String get message; bool get haltOnDetect; List<String> get coupleWith;
/// Create a copy of DetectorModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DetectorModelCopyWith<DetectorModel> get copyWith => _$DetectorModelCopyWithImpl<DetectorModel>(this as DetectorModel, _$identity);

  /// Serializes this DetectorModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DetectorModel&&const DeepCollectionEquality().equals(other.supportedBlockModes, supportedBlockModes)&&(identical(other.defaultBlockMode, defaultBlockMode) || other.defaultBlockMode == defaultBlockMode)&&(identical(other.priority, priority) || other.priority == priority)&&const DeepCollectionEquality().equals(other.identifiers, identifiers)&&(identical(other.childNodeLimit, childNodeLimit) || other.childNodeLimit == childNodeLimit)&&(identical(other.actionOnLaunch, actionOnLaunch) || other.actionOnLaunch == actionOnLaunch)&&(identical(other.paramsClass, paramsClass) || other.paramsClass == paramsClass)&&(identical(other.params, params) || other.params == params)&&(identical(other.message, message) || other.message == message)&&(identical(other.haltOnDetect, haltOnDetect) || other.haltOnDetect == haltOnDetect)&&const DeepCollectionEquality().equals(other.coupleWith, coupleWith));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(supportedBlockModes),defaultBlockMode,priority,const DeepCollectionEquality().hash(identifiers),childNodeLimit,actionOnLaunch,paramsClass,params,message,haltOnDetect,const DeepCollectionEquality().hash(coupleWith));

@override
String toString() {
  return 'DetectorModel(supportedBlockModes: $supportedBlockModes, defaultBlockMode: $defaultBlockMode, priority: $priority, identifiers: $identifiers, childNodeLimit: $childNodeLimit, actionOnLaunch: $actionOnLaunch, paramsClass: $paramsClass, params: $params, message: $message, haltOnDetect: $haltOnDetect, coupleWith: $coupleWith)';
}


}

/// @nodoc
abstract mixin class $DetectorModelCopyWith<$Res>  {
  factory $DetectorModelCopyWith(DetectorModel value, $Res Function(DetectorModel) _then) = _$DetectorModelCopyWithImpl;
@useResult
$Res call({
 List<String> supportedBlockModes, String defaultBlockMode, int priority, List<String> identifiers, int childNodeLimit, String actionOnLaunch, int paramsClass, String params, String message, bool haltOnDetect, List<String> coupleWith
});




}
/// @nodoc
class _$DetectorModelCopyWithImpl<$Res>
    implements $DetectorModelCopyWith<$Res> {
  _$DetectorModelCopyWithImpl(this._self, this._then);

  final DetectorModel _self;
  final $Res Function(DetectorModel) _then;

/// Create a copy of DetectorModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? supportedBlockModes = null,Object? defaultBlockMode = null,Object? priority = null,Object? identifiers = null,Object? childNodeLimit = null,Object? actionOnLaunch = null,Object? paramsClass = null,Object? params = null,Object? message = null,Object? haltOnDetect = null,Object? coupleWith = null,}) {
  return _then(_self.copyWith(
supportedBlockModes: null == supportedBlockModes ? _self.supportedBlockModes : supportedBlockModes // ignore: cast_nullable_to_non_nullable
as List<String>,defaultBlockMode: null == defaultBlockMode ? _self.defaultBlockMode : defaultBlockMode // ignore: cast_nullable_to_non_nullable
as String,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int,identifiers: null == identifiers ? _self.identifiers : identifiers // ignore: cast_nullable_to_non_nullable
as List<String>,childNodeLimit: null == childNodeLimit ? _self.childNodeLimit : childNodeLimit // ignore: cast_nullable_to_non_nullable
as int,actionOnLaunch: null == actionOnLaunch ? _self.actionOnLaunch : actionOnLaunch // ignore: cast_nullable_to_non_nullable
as String,paramsClass: null == paramsClass ? _self.paramsClass : paramsClass // ignore: cast_nullable_to_non_nullable
as int,params: null == params ? _self.params : params // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,haltOnDetect: null == haltOnDetect ? _self.haltOnDetect : haltOnDetect // ignore: cast_nullable_to_non_nullable
as bool,coupleWith: null == coupleWith ? _self.coupleWith : coupleWith // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [DetectorModel].
extension DetectorModelPatterns on DetectorModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DetectorModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DetectorModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DetectorModel value)  $default,){
final _that = this;
switch (_that) {
case _DetectorModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DetectorModel value)?  $default,){
final _that = this;
switch (_that) {
case _DetectorModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<String> supportedBlockModes,  String defaultBlockMode,  int priority,  List<String> identifiers,  int childNodeLimit,  String actionOnLaunch,  int paramsClass,  String params,  String message,  bool haltOnDetect,  List<String> coupleWith)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DetectorModel() when $default != null:
return $default(_that.supportedBlockModes,_that.defaultBlockMode,_that.priority,_that.identifiers,_that.childNodeLimit,_that.actionOnLaunch,_that.paramsClass,_that.params,_that.message,_that.haltOnDetect,_that.coupleWith);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<String> supportedBlockModes,  String defaultBlockMode,  int priority,  List<String> identifiers,  int childNodeLimit,  String actionOnLaunch,  int paramsClass,  String params,  String message,  bool haltOnDetect,  List<String> coupleWith)  $default,) {final _that = this;
switch (_that) {
case _DetectorModel():
return $default(_that.supportedBlockModes,_that.defaultBlockMode,_that.priority,_that.identifiers,_that.childNodeLimit,_that.actionOnLaunch,_that.paramsClass,_that.params,_that.message,_that.haltOnDetect,_that.coupleWith);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<String> supportedBlockModes,  String defaultBlockMode,  int priority,  List<String> identifiers,  int childNodeLimit,  String actionOnLaunch,  int paramsClass,  String params,  String message,  bool haltOnDetect,  List<String> coupleWith)?  $default,) {final _that = this;
switch (_that) {
case _DetectorModel() when $default != null:
return $default(_that.supportedBlockModes,_that.defaultBlockMode,_that.priority,_that.identifiers,_that.childNodeLimit,_that.actionOnLaunch,_that.paramsClass,_that.params,_that.message,_that.haltOnDetect,_that.coupleWith);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DetectorModel implements DetectorModel {
  const _DetectorModel({final  List<String> supportedBlockModes = const <String>[], this.defaultBlockMode = 'PRESS_BACK', this.priority = 0, final  List<String> identifiers = const <String>[], this.childNodeLimit = -1, this.actionOnLaunch = 'NONE', this.paramsClass = 0, this.params = '', this.message = '', this.haltOnDetect = true, final  List<String> coupleWith = const <String>[]}): _supportedBlockModes = supportedBlockModes,_identifiers = identifiers,_coupleWith = coupleWith;
  factory _DetectorModel.fromJson(Map<String, dynamic> json) => _$DetectorModelFromJson(json);

 final  List<String> _supportedBlockModes;
@override@JsonKey() List<String> get supportedBlockModes {
  if (_supportedBlockModes is EqualUnmodifiableListView) return _supportedBlockModes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_supportedBlockModes);
}

@override@JsonKey() final  String defaultBlockMode;
@override@JsonKey() final  int priority;
 final  List<String> _identifiers;
@override@JsonKey() List<String> get identifiers {
  if (_identifiers is EqualUnmodifiableListView) return _identifiers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_identifiers);
}

@override@JsonKey() final  int childNodeLimit;
@override@JsonKey() final  String actionOnLaunch;
@override@JsonKey() final  int paramsClass;
@override@JsonKey() final  String params;
@override@JsonKey() final  String message;
@override@JsonKey() final  bool haltOnDetect;
 final  List<String> _coupleWith;
@override@JsonKey() List<String> get coupleWith {
  if (_coupleWith is EqualUnmodifiableListView) return _coupleWith;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_coupleWith);
}


/// Create a copy of DetectorModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DetectorModelCopyWith<_DetectorModel> get copyWith => __$DetectorModelCopyWithImpl<_DetectorModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DetectorModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DetectorModel&&const DeepCollectionEquality().equals(other._supportedBlockModes, _supportedBlockModes)&&(identical(other.defaultBlockMode, defaultBlockMode) || other.defaultBlockMode == defaultBlockMode)&&(identical(other.priority, priority) || other.priority == priority)&&const DeepCollectionEquality().equals(other._identifiers, _identifiers)&&(identical(other.childNodeLimit, childNodeLimit) || other.childNodeLimit == childNodeLimit)&&(identical(other.actionOnLaunch, actionOnLaunch) || other.actionOnLaunch == actionOnLaunch)&&(identical(other.paramsClass, paramsClass) || other.paramsClass == paramsClass)&&(identical(other.params, params) || other.params == params)&&(identical(other.message, message) || other.message == message)&&(identical(other.haltOnDetect, haltOnDetect) || other.haltOnDetect == haltOnDetect)&&const DeepCollectionEquality().equals(other._coupleWith, _coupleWith));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_supportedBlockModes),defaultBlockMode,priority,const DeepCollectionEquality().hash(_identifiers),childNodeLimit,actionOnLaunch,paramsClass,params,message,haltOnDetect,const DeepCollectionEquality().hash(_coupleWith));

@override
String toString() {
  return 'DetectorModel(supportedBlockModes: $supportedBlockModes, defaultBlockMode: $defaultBlockMode, priority: $priority, identifiers: $identifiers, childNodeLimit: $childNodeLimit, actionOnLaunch: $actionOnLaunch, paramsClass: $paramsClass, params: $params, message: $message, haltOnDetect: $haltOnDetect, coupleWith: $coupleWith)';
}


}

/// @nodoc
abstract mixin class _$DetectorModelCopyWith<$Res> implements $DetectorModelCopyWith<$Res> {
  factory _$DetectorModelCopyWith(_DetectorModel value, $Res Function(_DetectorModel) _then) = __$DetectorModelCopyWithImpl;
@override @useResult
$Res call({
 List<String> supportedBlockModes, String defaultBlockMode, int priority, List<String> identifiers, int childNodeLimit, String actionOnLaunch, int paramsClass, String params, String message, bool haltOnDetect, List<String> coupleWith
});




}
/// @nodoc
class __$DetectorModelCopyWithImpl<$Res>
    implements _$DetectorModelCopyWith<$Res> {
  __$DetectorModelCopyWithImpl(this._self, this._then);

  final _DetectorModel _self;
  final $Res Function(_DetectorModel) _then;

/// Create a copy of DetectorModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? supportedBlockModes = null,Object? defaultBlockMode = null,Object? priority = null,Object? identifiers = null,Object? childNodeLimit = null,Object? actionOnLaunch = null,Object? paramsClass = null,Object? params = null,Object? message = null,Object? haltOnDetect = null,Object? coupleWith = null,}) {
  return _then(_DetectorModel(
supportedBlockModes: null == supportedBlockModes ? _self._supportedBlockModes : supportedBlockModes // ignore: cast_nullable_to_non_nullable
as List<String>,defaultBlockMode: null == defaultBlockMode ? _self.defaultBlockMode : defaultBlockMode // ignore: cast_nullable_to_non_nullable
as String,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as int,identifiers: null == identifiers ? _self._identifiers : identifiers // ignore: cast_nullable_to_non_nullable
as List<String>,childNodeLimit: null == childNodeLimit ? _self.childNodeLimit : childNodeLimit // ignore: cast_nullable_to_non_nullable
as int,actionOnLaunch: null == actionOnLaunch ? _self.actionOnLaunch : actionOnLaunch // ignore: cast_nullable_to_non_nullable
as String,paramsClass: null == paramsClass ? _self.paramsClass : paramsClass // ignore: cast_nullable_to_non_nullable
as int,params: null == params ? _self.params : params // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,haltOnDetect: null == haltOnDetect ? _self.haltOnDetect : haltOnDetect // ignore: cast_nullable_to_non_nullable
as bool,coupleWith: null == coupleWith ? _self._coupleWith : coupleWith // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$AppOpenActionModel {

 String get name; String get url;
/// Create a copy of AppOpenActionModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppOpenActionModelCopyWith<AppOpenActionModel> get copyWith => _$AppOpenActionModelCopyWithImpl<AppOpenActionModel>(this as AppOpenActionModel, _$identity);

  /// Serializes this AppOpenActionModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppOpenActionModel&&(identical(other.name, name) || other.name == name)&&(identical(other.url, url) || other.url == url));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,url);

@override
String toString() {
  return 'AppOpenActionModel(name: $name, url: $url)';
}


}

/// @nodoc
abstract mixin class $AppOpenActionModelCopyWith<$Res>  {
  factory $AppOpenActionModelCopyWith(AppOpenActionModel value, $Res Function(AppOpenActionModel) _then) = _$AppOpenActionModelCopyWithImpl;
@useResult
$Res call({
 String name, String url
});




}
/// @nodoc
class _$AppOpenActionModelCopyWithImpl<$Res>
    implements $AppOpenActionModelCopyWith<$Res> {
  _$AppOpenActionModelCopyWithImpl(this._self, this._then);

  final AppOpenActionModel _self;
  final $Res Function(AppOpenActionModel) _then;

/// Create a copy of AppOpenActionModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? url = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AppOpenActionModel].
extension AppOpenActionModelPatterns on AppOpenActionModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppOpenActionModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppOpenActionModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppOpenActionModel value)  $default,){
final _that = this;
switch (_that) {
case _AppOpenActionModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppOpenActionModel value)?  $default,){
final _that = this;
switch (_that) {
case _AppOpenActionModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String url)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppOpenActionModel() when $default != null:
return $default(_that.name,_that.url);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String url)  $default,) {final _that = this;
switch (_that) {
case _AppOpenActionModel():
return $default(_that.name,_that.url);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String url)?  $default,) {final _that = this;
switch (_that) {
case _AppOpenActionModel() when $default != null:
return $default(_that.name,_that.url);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppOpenActionModel implements AppOpenActionModel {
  const _AppOpenActionModel({this.name = '', this.url = ''});
  factory _AppOpenActionModel.fromJson(Map<String, dynamic> json) => _$AppOpenActionModelFromJson(json);

@override@JsonKey() final  String name;
@override@JsonKey() final  String url;

/// Create a copy of AppOpenActionModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppOpenActionModelCopyWith<_AppOpenActionModel> get copyWith => __$AppOpenActionModelCopyWithImpl<_AppOpenActionModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppOpenActionModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppOpenActionModel&&(identical(other.name, name) || other.name == name)&&(identical(other.url, url) || other.url == url));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,url);

@override
String toString() {
  return 'AppOpenActionModel(name: $name, url: $url)';
}


}

/// @nodoc
abstract mixin class _$AppOpenActionModelCopyWith<$Res> implements $AppOpenActionModelCopyWith<$Res> {
  factory _$AppOpenActionModelCopyWith(_AppOpenActionModel value, $Res Function(_AppOpenActionModel) _then) = __$AppOpenActionModelCopyWithImpl;
@override @useResult
$Res call({
 String name, String url
});




}
/// @nodoc
class __$AppOpenActionModelCopyWithImpl<$Res>
    implements _$AppOpenActionModelCopyWith<$Res> {
  __$AppOpenActionModelCopyWithImpl(this._self, this._then);

  final _AppOpenActionModel _self;
  final $Res Function(_AppOpenActionModel) _then;

/// Create a copy of AppOpenActionModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? url = null,}) {
  return _then(_AppOpenActionModel(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$OverlayParamsModel {

@JsonKey(name: 'primary_id') String get primaryId; OverlayConfigModel get config;@JsonKey(name: 'primary_addons') List<String> get primaryAddons;
/// Create a copy of OverlayParamsModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OverlayParamsModelCopyWith<OverlayParamsModel> get copyWith => _$OverlayParamsModelCopyWithImpl<OverlayParamsModel>(this as OverlayParamsModel, _$identity);

  /// Serializes this OverlayParamsModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OverlayParamsModel&&(identical(other.primaryId, primaryId) || other.primaryId == primaryId)&&(identical(other.config, config) || other.config == config)&&const DeepCollectionEquality().equals(other.primaryAddons, primaryAddons));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,primaryId,config,const DeepCollectionEquality().hash(primaryAddons));

@override
String toString() {
  return 'OverlayParamsModel(primaryId: $primaryId, config: $config, primaryAddons: $primaryAddons)';
}


}

/// @nodoc
abstract mixin class $OverlayParamsModelCopyWith<$Res>  {
  factory $OverlayParamsModelCopyWith(OverlayParamsModel value, $Res Function(OverlayParamsModel) _then) = _$OverlayParamsModelCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'primary_id') String primaryId, OverlayConfigModel config,@JsonKey(name: 'primary_addons') List<String> primaryAddons
});


$OverlayConfigModelCopyWith<$Res> get config;

}
/// @nodoc
class _$OverlayParamsModelCopyWithImpl<$Res>
    implements $OverlayParamsModelCopyWith<$Res> {
  _$OverlayParamsModelCopyWithImpl(this._self, this._then);

  final OverlayParamsModel _self;
  final $Res Function(OverlayParamsModel) _then;

/// Create a copy of OverlayParamsModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? primaryId = null,Object? config = null,Object? primaryAddons = null,}) {
  return _then(_self.copyWith(
primaryId: null == primaryId ? _self.primaryId : primaryId // ignore: cast_nullable_to_non_nullable
as String,config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as OverlayConfigModel,primaryAddons: null == primaryAddons ? _self.primaryAddons : primaryAddons // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of OverlayParamsModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OverlayConfigModelCopyWith<$Res> get config {
  
  return $OverlayConfigModelCopyWith<$Res>(_self.config, (value) {
    return _then(_self.copyWith(config: value));
  });
}
}


/// Adds pattern-matching-related methods to [OverlayParamsModel].
extension OverlayParamsModelPatterns on OverlayParamsModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OverlayParamsModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OverlayParamsModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OverlayParamsModel value)  $default,){
final _that = this;
switch (_that) {
case _OverlayParamsModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OverlayParamsModel value)?  $default,){
final _that = this;
switch (_that) {
case _OverlayParamsModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'primary_id')  String primaryId,  OverlayConfigModel config, @JsonKey(name: 'primary_addons')  List<String> primaryAddons)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OverlayParamsModel() when $default != null:
return $default(_that.primaryId,_that.config,_that.primaryAddons);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'primary_id')  String primaryId,  OverlayConfigModel config, @JsonKey(name: 'primary_addons')  List<String> primaryAddons)  $default,) {final _that = this;
switch (_that) {
case _OverlayParamsModel():
return $default(_that.primaryId,_that.config,_that.primaryAddons);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'primary_id')  String primaryId,  OverlayConfigModel config, @JsonKey(name: 'primary_addons')  List<String> primaryAddons)?  $default,) {final _that = this;
switch (_that) {
case _OverlayParamsModel() when $default != null:
return $default(_that.primaryId,_that.config,_that.primaryAddons);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OverlayParamsModel implements OverlayParamsModel {
  const _OverlayParamsModel({@JsonKey(name: 'primary_id') this.primaryId = '', this.config = const OverlayConfigModel(), @JsonKey(name: 'primary_addons') final  List<String> primaryAddons = const <String>[]}): _primaryAddons = primaryAddons;
  factory _OverlayParamsModel.fromJson(Map<String, dynamic> json) => _$OverlayParamsModelFromJson(json);

@override@JsonKey(name: 'primary_id') final  String primaryId;
@override@JsonKey() final  OverlayConfigModel config;
 final  List<String> _primaryAddons;
@override@JsonKey(name: 'primary_addons') List<String> get primaryAddons {
  if (_primaryAddons is EqualUnmodifiableListView) return _primaryAddons;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_primaryAddons);
}


/// Create a copy of OverlayParamsModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OverlayParamsModelCopyWith<_OverlayParamsModel> get copyWith => __$OverlayParamsModelCopyWithImpl<_OverlayParamsModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OverlayParamsModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OverlayParamsModel&&(identical(other.primaryId, primaryId) || other.primaryId == primaryId)&&(identical(other.config, config) || other.config == config)&&const DeepCollectionEquality().equals(other._primaryAddons, _primaryAddons));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,primaryId,config,const DeepCollectionEquality().hash(_primaryAddons));

@override
String toString() {
  return 'OverlayParamsModel(primaryId: $primaryId, config: $config, primaryAddons: $primaryAddons)';
}


}

/// @nodoc
abstract mixin class _$OverlayParamsModelCopyWith<$Res> implements $OverlayParamsModelCopyWith<$Res> {
  factory _$OverlayParamsModelCopyWith(_OverlayParamsModel value, $Res Function(_OverlayParamsModel) _then) = __$OverlayParamsModelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'primary_id') String primaryId, OverlayConfigModel config,@JsonKey(name: 'primary_addons') List<String> primaryAddons
});


@override $OverlayConfigModelCopyWith<$Res> get config;

}
/// @nodoc
class __$OverlayParamsModelCopyWithImpl<$Res>
    implements _$OverlayParamsModelCopyWith<$Res> {
  __$OverlayParamsModelCopyWithImpl(this._self, this._then);

  final _OverlayParamsModel _self;
  final $Res Function(_OverlayParamsModel) _then;

/// Create a copy of OverlayParamsModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? primaryId = null,Object? config = null,Object? primaryAddons = null,}) {
  return _then(_OverlayParamsModel(
primaryId: null == primaryId ? _self.primaryId : primaryId // ignore: cast_nullable_to_non_nullable
as String,config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as OverlayConfigModel,primaryAddons: null == primaryAddons ? _self._primaryAddons : primaryAddons // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of OverlayParamsModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OverlayConfigModelCopyWith<$Res> get config {
  
  return $OverlayConfigModelCopyWith<$Res>(_self.config, (value) {
    return _then(_self.copyWith(config: value));
  });
}
}


/// @nodoc
mixin _$OverlayConfigModel {

@JsonKey(name: 'curious_support') bool get curiousSupport;@JsonKey(name: 'block_all_support') bool get blockAllSupport;@JsonKey(name: 'overlay_support') bool get overlaySupport;@JsonKey(name: 'blackout_message') String get blackoutMessage;
/// Create a copy of OverlayConfigModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OverlayConfigModelCopyWith<OverlayConfigModel> get copyWith => _$OverlayConfigModelCopyWithImpl<OverlayConfigModel>(this as OverlayConfigModel, _$identity);

  /// Serializes this OverlayConfigModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OverlayConfigModel&&(identical(other.curiousSupport, curiousSupport) || other.curiousSupport == curiousSupport)&&(identical(other.blockAllSupport, blockAllSupport) || other.blockAllSupport == blockAllSupport)&&(identical(other.overlaySupport, overlaySupport) || other.overlaySupport == overlaySupport)&&(identical(other.blackoutMessage, blackoutMessage) || other.blackoutMessage == blackoutMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,curiousSupport,blockAllSupport,overlaySupport,blackoutMessage);

@override
String toString() {
  return 'OverlayConfigModel(curiousSupport: $curiousSupport, blockAllSupport: $blockAllSupport, overlaySupport: $overlaySupport, blackoutMessage: $blackoutMessage)';
}


}

/// @nodoc
abstract mixin class $OverlayConfigModelCopyWith<$Res>  {
  factory $OverlayConfigModelCopyWith(OverlayConfigModel value, $Res Function(OverlayConfigModel) _then) = _$OverlayConfigModelCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'curious_support') bool curiousSupport,@JsonKey(name: 'block_all_support') bool blockAllSupport,@JsonKey(name: 'overlay_support') bool overlaySupport,@JsonKey(name: 'blackout_message') String blackoutMessage
});




}
/// @nodoc
class _$OverlayConfigModelCopyWithImpl<$Res>
    implements $OverlayConfigModelCopyWith<$Res> {
  _$OverlayConfigModelCopyWithImpl(this._self, this._then);

  final OverlayConfigModel _self;
  final $Res Function(OverlayConfigModel) _then;

/// Create a copy of OverlayConfigModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? curiousSupport = null,Object? blockAllSupport = null,Object? overlaySupport = null,Object? blackoutMessage = null,}) {
  return _then(_self.copyWith(
curiousSupport: null == curiousSupport ? _self.curiousSupport : curiousSupport // ignore: cast_nullable_to_non_nullable
as bool,blockAllSupport: null == blockAllSupport ? _self.blockAllSupport : blockAllSupport // ignore: cast_nullable_to_non_nullable
as bool,overlaySupport: null == overlaySupport ? _self.overlaySupport : overlaySupport // ignore: cast_nullable_to_non_nullable
as bool,blackoutMessage: null == blackoutMessage ? _self.blackoutMessage : blackoutMessage // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [OverlayConfigModel].
extension OverlayConfigModelPatterns on OverlayConfigModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OverlayConfigModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OverlayConfigModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OverlayConfigModel value)  $default,){
final _that = this;
switch (_that) {
case _OverlayConfigModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OverlayConfigModel value)?  $default,){
final _that = this;
switch (_that) {
case _OverlayConfigModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'curious_support')  bool curiousSupport, @JsonKey(name: 'block_all_support')  bool blockAllSupport, @JsonKey(name: 'overlay_support')  bool overlaySupport, @JsonKey(name: 'blackout_message')  String blackoutMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OverlayConfigModel() when $default != null:
return $default(_that.curiousSupport,_that.blockAllSupport,_that.overlaySupport,_that.blackoutMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'curious_support')  bool curiousSupport, @JsonKey(name: 'block_all_support')  bool blockAllSupport, @JsonKey(name: 'overlay_support')  bool overlaySupport, @JsonKey(name: 'blackout_message')  String blackoutMessage)  $default,) {final _that = this;
switch (_that) {
case _OverlayConfigModel():
return $default(_that.curiousSupport,_that.blockAllSupport,_that.overlaySupport,_that.blackoutMessage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'curious_support')  bool curiousSupport, @JsonKey(name: 'block_all_support')  bool blockAllSupport, @JsonKey(name: 'overlay_support')  bool overlaySupport, @JsonKey(name: 'blackout_message')  String blackoutMessage)?  $default,) {final _that = this;
switch (_that) {
case _OverlayConfigModel() when $default != null:
return $default(_that.curiousSupport,_that.blockAllSupport,_that.overlaySupport,_that.blackoutMessage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OverlayConfigModel implements OverlayConfigModel {
  const _OverlayConfigModel({@JsonKey(name: 'curious_support') this.curiousSupport = false, @JsonKey(name: 'block_all_support') this.blockAllSupport = false, @JsonKey(name: 'overlay_support') this.overlaySupport = false, @JsonKey(name: 'blackout_message') this.blackoutMessage = ''});
  factory _OverlayConfigModel.fromJson(Map<String, dynamic> json) => _$OverlayConfigModelFromJson(json);

@override@JsonKey(name: 'curious_support') final  bool curiousSupport;
@override@JsonKey(name: 'block_all_support') final  bool blockAllSupport;
@override@JsonKey(name: 'overlay_support') final  bool overlaySupport;
@override@JsonKey(name: 'blackout_message') final  String blackoutMessage;

/// Create a copy of OverlayConfigModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OverlayConfigModelCopyWith<_OverlayConfigModel> get copyWith => __$OverlayConfigModelCopyWithImpl<_OverlayConfigModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OverlayConfigModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OverlayConfigModel&&(identical(other.curiousSupport, curiousSupport) || other.curiousSupport == curiousSupport)&&(identical(other.blockAllSupport, blockAllSupport) || other.blockAllSupport == blockAllSupport)&&(identical(other.overlaySupport, overlaySupport) || other.overlaySupport == overlaySupport)&&(identical(other.blackoutMessage, blackoutMessage) || other.blackoutMessage == blackoutMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,curiousSupport,blockAllSupport,overlaySupport,blackoutMessage);

@override
String toString() {
  return 'OverlayConfigModel(curiousSupport: $curiousSupport, blockAllSupport: $blockAllSupport, overlaySupport: $overlaySupport, blackoutMessage: $blackoutMessage)';
}


}

/// @nodoc
abstract mixin class _$OverlayConfigModelCopyWith<$Res> implements $OverlayConfigModelCopyWith<$Res> {
  factory _$OverlayConfigModelCopyWith(_OverlayConfigModel value, $Res Function(_OverlayConfigModel) _then) = __$OverlayConfigModelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'curious_support') bool curiousSupport,@JsonKey(name: 'block_all_support') bool blockAllSupport,@JsonKey(name: 'overlay_support') bool overlaySupport,@JsonKey(name: 'blackout_message') String blackoutMessage
});




}
/// @nodoc
class __$OverlayConfigModelCopyWithImpl<$Res>
    implements _$OverlayConfigModelCopyWith<$Res> {
  __$OverlayConfigModelCopyWithImpl(this._self, this._then);

  final _OverlayConfigModel _self;
  final $Res Function(_OverlayConfigModel) _then;

/// Create a copy of OverlayConfigModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? curiousSupport = null,Object? blockAllSupport = null,Object? overlaySupport = null,Object? blackoutMessage = null,}) {
  return _then(_OverlayConfigModel(
curiousSupport: null == curiousSupport ? _self.curiousSupport : curiousSupport // ignore: cast_nullable_to_non_nullable
as bool,blockAllSupport: null == blockAllSupport ? _self.blockAllSupport : blockAllSupport // ignore: cast_nullable_to_non_nullable
as bool,overlaySupport: null == overlaySupport ? _self.overlaySupport : overlaySupport // ignore: cast_nullable_to_non_nullable
as bool,blackoutMessage: null == blackoutMessage ? _self.blackoutMessage : blackoutMessage // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
