# Networking & Remote Config Sync

This document is the blueprint for the **data layer** of the Flutter short-form-content blocker: how the app talks to its backend over a small REST API, how it wraps every call in a `Resource<T>` state machine, and how it downloads, caches, and version-gates its three core JSON configs (initial/feature config, platform detection rules, and per-device calibration). The original is a Retrofit 2 interface of **9 POST endpoints** with Kotlin `suspend` functions; the entire detection engine is data-driven by configs fetched here and cached to DataStore, with a bundled `res/raw/platforms_config.json` fallback when the network fails. We re-build this cleanly with `dio` + `retrofit` (codegen) + `json_serializable`, a sealed `Resource<T>`, a Dio interceptor for device headers + retry/backoff, and `firebase_remote_config` as an alternative transport for the JSON blobs.

---

## 1. Legend

| Symbol | Meaning |
|---|---|
| ✅ | A pub.dev package fully handles this; no native code needed |
| ⚠️ | Needs a native MethodChannel/EventChannel (device-form-factor probe, install time) |
| ❌ | Not possible on iOS, or no clean equivalent |

The networking layer itself is **100% pure Dart** ✅ — no AccessibilityService boundary here. The only ⚠️ items are *inputs* to the requests (tablet/folding-phone probe, first-install timestamp, install source), which come from device plugins or a tiny native channel.

---

## 2. API surface (full)

**Source of truth:** `network/retrofit/IRetrofitApis.java` — every endpoint is `@POST`, every method is a Kotlin `suspend` returning `retrofit2.Response<T>`. Base URL is **not** present in the decompiled interface (defined in the Retrofit builder / `BuildConfig`, per analysis notes). All paths below are relative to that base URL.

| # | Our Dart method | HTTP | Path | Request (body/header) | Response model | Notes |
|---|---|---|---|---|---|---|
| 1 | `fetchInitialConfig` | POST | `initialConfig` | `@Body InitialConfigRequest` | `InitialConfigResponse` | Central config: feature flags, version gating, premium entitlements, ads, in-app notifications, `platformConfigVersion`. Sent on cold start. |
| 2 | `fetchPlatformConfig` | POST | `platformsConfig` | Headers: `isTablet:bool`, `isFoldingPhone:bool`, `configVersion:int` | `PlatformConfigResponse` | Detection rules per app/platform. `configVersion` lets server return 304-like empty payload if unchanged. **No body** — form factor + version are headers. |
| 3 | `fetchCalibrationConfig` | POST | `getCalibrationConfig` | Headers: `isTablet:bool`, `isFoldingPhone:bool` + `@Body CalibrationConfigRequest` | `CalibrationConfigResponse` | Per-device pixel-zone tuning for in-app/webview content. |
| 4 | `fetchUpgradablePlans` | POST | `upgradablePlans` | `@Body UpgradablePlansRequest` | `UpgradablePlansResponse` | Premium tier comparison data for the paywall. |
| 5 | `sendOtp` | POST | `communication/sendOtp` | `@Body OTPRequest` | `OTPResponse` | OTP send for PIN recovery / app unlock. |
| 6 | `validateOtp` | POST | `communication/validateOtp` | `@Body ValidateOTPRequest` | `ValidateOTPResponse` | Verify the OTP code. |
| 7 | `recoverPin` | POST | `communication/pinRecovery` | `@Body PINRecoveryRequest` | `PinRecoveryResponse` | PIN reset after OTP validated. |
| 8 | `fetchSupportConfig` | POST | `supportConfig` | *(no body)* | `SupportConfigResponse` | In-app help articles (`quickGuides`). |
| 9 | `fetchContent` | POST | `fetchContent` | *(no body)* | `FetchContentResponse` | Dynamic UI content (emoji sets, mindfulness quotes). |

> **Why every call is POST** (even bodiless `supportConfig`/`fetchContent`): verified in the interface — `@POST` is used uniformly, likely for backend analytics/client-validation consistency. Replicate this in Dart so backend logging stays intact.

### 2.1 Verified request/response field maps

These are the exact field names to model (from the decompiled DTOs / analysis cache). Use them as JSON keys.

**InitialConfigRequest**
| Field | Type | Purpose |
|---|---|---|
| `planDetails` | `List<PlanDetail>` | Active subscriptions (`planId`, `purchaseToken`) reported on startup |

**InitialConfigResponse** (10 top-level fields)
| Field | Type | Purpose |
|---|---|---|
| `inappNotification` | `List<InappNotification>` | Standard in-app messages |
| `warningMessages` | `List<InappNotification>` | Breaking/critical alerts (separate channel) |
| `featuresAvailability` | `Map<String, FeatureConfig>` | Feature flags, keyed by featureId |
| `activePlanDetails` | `ActivePlanDetails` | User's current entitlements |
| `versionAvailability` | `VersionAvailability` | Update gating (see §6) |
| `inhouseNativeAdConfig` | `InhouseNativeAdConfig` | House-ad config |
| `premiumPurchaseCTA` | `PremiumPurchaseCTA` | Paywall CTA text/icon/deeplink |
| `videoConfig` | `Map<String, String>` | placement → promo video URL |
| `platformConfigVersion` | `int` | Drives the `configVersion` header of call #2 |
| `admobConfig` | `Map<String, AdmobAdLoader>` | placement → ad unit config |

**FeatureConfig** — `featureId:String`, `params:String`, `premiumOnly:bool`, `minOSVersion:int`, `maxOSVersion:int`, `enabled:bool`. (OS-range gating lets the server roll features out per Android API level.)

**VersionAvailability / VersionInfo** — `forceUpdate:bool`, `promptUpdate:bool`, `beta:bool`, `versionCode:int`, `versionName:String`, `changelog:String`.

**ActivePlanDetails** — 6 boolean entitlement flags `aiFeatures`, `blockAds`, `premiumFeatures`, `parentalFeatures`, `topTierPlan`, `promptUpgrades` + `plans:List<ActiveClientPlan>`.

**PlatformConfigResponse** — `configVersion:int`, `message:String`, `featuredApps:Map<String, AppDetails>` (key = package name), `responsecode:int` (note lowercase `c` in original), `updateIcon:String`, `updateMessage:String`. *(The `AppDetails` → `Platform` → `Detectors` shape is documented in the detection-engine doc; here we only own transport + caching.)*

**CalibrationConfigRequest** — `width:int`, `height:int`, `deviceConfig:String` (serialized `EnumDeviceConfig`: `MOBILE`/`TABLET`/`LANDSCAPE`/`LANDSCAPE_TABLET`), `platforms:Map<String, InstalledPlatformConfig>` where `InstalledPlatformConfig` = `platformVersion:long`, `version:int`.

**CalibrationConfigResponse** — `message:String`, `platforms:Map<String, PlatformConfigMetaData>`, `responseCode:int` (**200 = success**). `PlatformConfigMetaData` = `supportStatusEnum:SupportStatusEnum` (`UPDATE_REQUIRED`/`NOT_SUPPORTED`/`FRESH`/`SUPPORTED`), `configVersion:int`, `config:Map<String, Map<String, PlatformHolder>>`.

**UpgradablePlansRequest** — `activeClientPlans:List<PlanDetail>`, `installSources:Map<String,String>` (e.g. `com.android.vending` → Play, or `sideload`), `firstInstallMillis:long`.

**UpgradablePlansResponse** — `headerText`, `subText`, `premiumAppIcons:List<String>`, `freeAppIcons:List<String>`, `exclusiveFeatures:List<String>`, `categories:List<Category>`, `features:List<PlanFeatureSetTable>`, `clientActivePlans:List<ActiveClientPlan>`, `plans:List<Plan>`.

**OTPRequest** — `email:String`, `emailType:EmailTypeEnum` (inferred values `RECOVERY`/`UNLOCK`/`SUPPORT`), `lockedAppName:String`. **ValidateOTPRequest** — `email`, `otp`, `token` *(inferred)*. **PINRecoveryRequest** — fields obfuscated *(inferred: email + new PIN + server token)*.

**SupportConfigResponse** — `quickGuides:List<QuickGuide>`. **FetchContentResponse** — emoji/quote sections *(inferred; body obfuscated)*.

---

## 3. The `Resource<T>` wrapper

**Verified in** `network/retrofit/Resource.java`: an abstract class with three concrete subclasses.

| Subclass | Fields (verified) |
|---|---|
| `Resource.Success` | `Object data` (non-null; constructor calls `obj.getClass()` to NPE-guard) |
| `Resource.Error` | `String message`, `int errorCode` |
| `Resource.Loading` | `boolean showLoadingScreen` |

Dart re-build as a sealed class (Dart 3) so `switch` is exhaustive:

```dart
/// Mirrors network/retrofit/Resource.java (Success / Error / Loading).
sealed class Resource<T> {
  const Resource();
}

final class ResourceLoading<T> extends Resource<T> {
  /// true => show a blocking full-screen spinner; false => silent refresh.
  final bool showLoadingScreen;
  const ResourceLoading({this.showLoadingScreen = false});
}

final class ResourceSuccess<T> extends Resource<T> {
  final T data;
  const ResourceSuccess(this.data);
}

final class ResourceError<T> extends Resource<T> {
  final String message;
  final int errorCode;
  const ResourceError(this.message, {this.errorCode = -1});
}
```

Alternative ✅: generate this with `freezed` (`@freezed sealed class Resource<T>`) if you prefer copyWith/equality for free. The hand-written sealed class above has zero codegen cost.

### 3.1 `executeApiCall` pattern

**Verified in** `RetrofitHelper$executeApiCall$1.java`: a `SuspendLambda` `Function2<FlowCollector, Continuation, ...>` taking `(boolean showLoading, Function1 apiCall)`. The exact body is `Method dump skipped, instruction units count: 254` **(inferred)**, but the bytecode shows two `r0.emit(r9, r8)` calls inside a `try { ... } catch (Exception)` — i.e. it **emits into a Flow**: first `Loading`, then `Success` (on `Response.isSuccessful()`) or `Error` (HTTP non-2xx or thrown exception). This is the classic "emit Loading → run suspend call → emit Success/Error, catch and emit Error" cold-flow helper.

Dart equivalent returns a `Stream<Resource<T>>` (one Loading, one terminal) so a Bloc can `emitForEach`:

```dart
/// Re-build of RetrofitHelper.executeApiCall(showLoading, apiCall).
/// Emits exactly: Loading -> (Success | Error).
Stream<Resource<T>> executeApiCall<T>(
  Future<T> Function() apiCall, {
  bool showLoading = false,
}) async* {
  yield ResourceLoading<T>(showLoadingScreen: showLoading);
  try {
    yield ResourceSuccess<T>(await apiCall());
  } on DioException catch (e) {
    yield ResourceError<T>(
      e.message ?? 'Network error',
      errorCode: e.response?.statusCode ?? -1,
    );
  } catch (e) {
    yield ResourceError<T>(e.toString());
  }
}
```

> If you prefer a single terminal value over a stream (e.g. for use-cases), expose `Future<Resource<T>>` instead and let the Bloc inject its own `ResourceLoading` before awaiting.

---

## 4. Dio + Retrofit API client

We use `retrofit` (with `retrofit_generator`) so the interface stays declarative like the original, and `dio` as the HTTP engine.

```yaml
# pubspec.yaml (versions illustrative — pin latest at build time)
dependencies:
  dio: ^5.7.0
  retrofit: ^4.4.0
  json_annotation: ^4.9.0
  firebase_remote_config: ^5.1.0   # optional alt transport (§7)
  device_info_plus: ^11.1.0         # SDK level / model
  package_info_plus: ^8.1.0         # app versionCode/versionName
dev_dependencies:
  retrofit_generator: ^9.1.0
  json_serializable: ^6.8.0
  build_runner: ^2.4.0
```

```dart
// data/datasources/remote/blocker_api.dart
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

part 'blocker_api.g.dart';

@RestApi() // base URL injected at construction (Dio.options.baseUrl)
abstract class BlockerApi {
  factory BlockerApi(Dio dio, {String? baseUrl}) = _BlockerApi;

  @POST('initialConfig')
  Future<InitialConfigResponse> fetchInitialConfig(
    @Body() InitialConfigRequest request,
  );

  @POST('platformsConfig')
  Future<HttpResponse<PlatformConfigResponse>> fetchPlatformConfig(
    @Header('isTablet') bool isTablet,
    @Header('isFoldingPhone') bool isFoldingPhone,
    @Header('configVersion') int configVersion,
  ); // HttpResponse keeps the 304/empty-body status visible (see §5)

  @POST('getCalibrationConfig')
  Future<CalibrationConfigResponse> fetchCalibrationConfig(
    @Header('isTablet') bool isTablet,
    @Header('isFoldingPhone') bool isFoldingPhone,
    @Body() CalibrationConfigRequest request,
  );

  @POST('upgradablePlans')
  Future<UpgradablePlansResponse> fetchUpgradablePlans(
    @Body() UpgradablePlansRequest request,
  );

  @POST('communication/sendOtp')
  Future<OtpResponse> sendOtp(@Body() OtpRequest request);

  @POST('communication/validateOtp')
  Future<ValidateOtpResponse> validateOtp(@Body() ValidateOtpRequest request);

  @POST('communication/pinRecovery')
  Future<PinRecoveryResponse> recoverPin(@Body() PinRecoveryRequest request);

  @POST('supportConfig')
  Future<SupportConfigResponse> fetchSupportConfig();

  @POST('fetchContent')
  Future<FetchContentResponse> fetchContent();
}
```

### 4.1 Dio setup with interceptors

```dart
// data/datasources/remote/dio_factory.dart
Dio buildDio({
  required String baseUrl,
  required DeviceFormFactor formFactor, // isTablet / isFoldingPhone (⚠️ probe)
  required ConfigVersionStore versions, // cached configVersion values
}) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    // Treat only 2xx as success; let interceptor map the rest to Resource.Error.
    validateStatus: (s) => s != null && s >= 200 && s < 300,
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      // Device-form-factor headers required by platformsConfig/getCalibrationConfig.
      options.headers.putIfAbsent('isTablet', () => formFactor.isTablet);
      options.headers.putIfAbsent('isFoldingPhone', () => formFactor.isFoldingPhone);
      // Send cached configVersion so the server can skip unchanged payloads.
      if (options.path == 'platformsConfig') {
        options.headers['configVersion'] = versions.platformConfigVersion;
      }
      handler.next(options);
    },
  ));

  // Retry with exponential backoff for transient failures.
  dio.interceptors.add(RetryInterceptor(
    dio: dio,
    retries: 3,
    retryDelays: const [
      Duration(milliseconds: 400),
      Duration(milliseconds: 1200),
      Duration(milliseconds: 3000),
    ],
    retryEvaluator: (err, attempt) =>
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response?.statusCode ?? 0) >= 500,
  ));
  return dio;
}
```

> `RetryInterceptor` ships in `dio_smart_retry` ✅ — prefer it over hand-rolling backoff. Add `pretty_dio_logger` ✅ in debug builds.

### 4.2 Device-form-factor probe (the only native bit)

The headers `isTablet` and `isFoldingPhone` map to original lazy delegates in `HomeRepository`: `isTablet` ← `R.string.is_tablet` resource, `isFoldingPhone` ← `Build.VERSION.SDK_INT >= 30 && PackageManager.hasSystemFeature("android.hardware.sensor.hinge_angle")`.

| Probe | Flutter source |
|---|---|
| `isTablet` | ✅ derive from `MediaQuery` shortest-side ≥ 600dp, or `device_info_plus` + a `bool/is_tablet` resource value. iOS: `UIDevice.userInterfaceIdiom == .pad`. |
| `isFoldingPhone` | ⚠️ MethodChannel calling `hasSystemFeature("android.hardware.sensor.hinge_angle")` (no pub package exposes the hinge feature flag). iOS: ❌ (no foldables; send `false`). |

---

## 5. Caching strategy & version skip

**Verified flow:** each config is persisted to DataStore (`CALIBRATION_CONFIG` key confirmed in calibration analysis; `platformConfigVersion` / `premiumPlan` keys in networking analysis) and re-emitted via `StateFlow`. The `configVersion` header lets the server return an unchanged/empty payload to avoid re-downloading. On network failure the app falls back to the **bundled** `res/raw/platforms_config.json`.

**Rules to replicate:**

1. **Persist on success.** Every successful response is written to local storage keyed by config name. Store the `configVersion`/`platformConfigVersion` alongside it.
2. **Send version to skip.** On the next `platformsConfig` call, send the cached `configVersion` header. If the server replies with HTTP `304` (or `responsecode`/`configVersion` indicating "no change"), keep the cached copy. (We expose `HttpResponse<PlatformConfigResponse>` for exactly this — inspect `response.statusCode`.)
3. **Bundled fallback.** Ship `assets/config/platforms_config.json` (a copy of the decompiled `res/raw/platforms_config.json`). If the network call errors *and* there is no cache, parse the asset.
4. **Calibration `responseCode` gating.** Apply `CalibrationConfigResponse` only when `responseCode == 200`. Per platform, honor `SupportStatusEnum`: `SUPPORTED`/`FRESH` → apply; `UPDATE_REQUIRED` → warn user to update the social app; `NOT_SUPPORTED` → disable that platform's calibration.

Storage choice: ✅ `shared_preferences` for the small scalar keys (`configVersion`, premium booleans) and `hive`/`drift` for the larger JSON blobs. Wrap both behind a `LocalConfigStore` so the repository never touches a plugin directly.

```dart
// data/datasources/local/local_config_store.dart
abstract interface class LocalConfigStore {
  Future<void> savePlatformConfig(PlatformConfigResponse cfg);
  Future<PlatformConfigResponse?> readPlatformConfig();
  int get platformConfigVersion;          // 0 if never fetched
  Future<void> setPlatformConfigVersion(int v);

  Future<void> saveCalibrationConfig(CalibrationConfigResponse cfg);
  Future<CalibrationConfigResponse?> readCalibrationConfig();

  Future<void> saveInitialConfig(InitialConfigResponse cfg);
  Future<InitialConfigResponse?> readInitialConfig();
}

/// Bundled fallback: assets/config/platforms_config.json
class BundledConfigProvider {
  Future<PlatformConfigResponse> loadBundledPlatformConfig() async {
    final raw = await rootBundle.loadString('assets/config/platforms_config.json');
    return PlatformConfigResponse.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
```

---

## 6. Version / update gating

**Verified gating semantics** (from `versionAvailability` usage):

| Flag | Behavior | Flutter |
|---|---|---|
| `forceUpdate == true` | Block the whole UI; show a mandatory, non-dismissible update screen | Bloc emits `AppGateState.forceUpdate`; root widget renders a blocking screen. ✅ `in_app_update` (Android Flexible/Immediate). iOS: link to App Store. |
| `promptUpdate == true` | Show a dismissible "update available" banner | Dismissible dialog/banner; remember dismissal per `versionCode`. |
| `beta == true` | Indicates a test/hidden-from-store build | Show a beta ribbon; gate beta-only features. |
| `versionCode` | Compare to local build's version code | ✅ `package_info_plus` → `buildNumber` (parse to int). |

```dart
// domain/usecases/evaluate_update_gate.dart
enum UpdateGate { none, prompt, force }

UpdateGate evaluateUpdateGate(VersionAvailability v, int localVersionCode) {
  if (v.forceUpdate && v.versionCode > localVersionCode) return UpdateGate.force;
  if (v.promptUpdate && v.versionCode > localVersionCode) return UpdateGate.prompt;
  return UpdateGate.none;
}
```

Per-feature gating uses `FeatureConfig`: a feature is live only if `enabled && minOSVersion <= SDK_INT <= maxOSVersion && (!premiumOnly || userHasPremium)`.

```dart
bool isFeatureEnabled(FeatureConfig f, int sdkInt, bool userHasPremium) =>
    f.enabled &&
    sdkInt >= f.minOSVersion &&
    sdkInt <= f.maxOSVersion &&
    (!f.premiumOnly || userHasPremium);
```

---

## 7. `firebase_remote_config` as an alternative transport

The three JSON configs (initial/feature flags, platform rules, calibration) are pure data — they can be served from **Firebase Remote Config** instead of (or as a failover to) the custom backend. ✅ `firebase_remote_config`.

| Aspect | Custom REST (`dio`+`retrofit`) | `firebase_remote_config` |
|---|---|---|
| Per-device targeting | Headers `isTablet`/`isFoldingPhone`/`configVersion` → server logic | RC conditions on app version / audience; **no per-request device dimensions** ❌ for calibration |
| Caching/version skip | Manual (`configVersion` + DataStore) | Built-in `minimumFetchInterval` + `getString` cache |
| Calibration (needs `width`/`height` body) | ✅ supported | ❌ RC can't take a request body; calibration must stay on REST |
| Feature flags / version gating | ✅ | ✅ ideal use case |
| Bundled defaults | manual asset | ✅ `setDefaults(...)` |

**Recommended split:** keep `getCalibrationConfig` (needs request body) and OTP/PIN/plans on REST; serve `featuresAvailability`, `versionAvailability`, and even the bundled `platforms_config.json` blob via Remote Config keys for instant, no-backend rollout.

```dart
// data/datasources/remote/remote_config_source.dart
class RemoteConfigSource {
  final FirebaseRemoteConfig _rc;
  RemoteConfigSource(this._rc);

  Future<void> init() async {
    await _rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    await _rc.setDefaults({
      'platforms_config': await rootBundle
          .loadString('assets/config/platforms_config.json'),
    });
    await _rc.fetchAndActivate();
  }

  PlatformConfigResponse platformConfig() => PlatformConfigResponse.fromJson(
      jsonDecode(_rc.getString('platforms_config')) as Map<String, dynamic>);
}
```

---

## 8. Models (json_serializable sketches)

```dart
// data/models/initial_config_request.dart
@JsonSerializable()
class PlanDetail {
  final String planId;
  final String purchaseToken;
  const PlanDetail({required this.planId, required this.purchaseToken});
  factory PlanDetail.fromJson(Map<String, dynamic> j) => _$PlanDetailFromJson(j);
  Map<String, dynamic> toJson() => _$PlanDetailToJson(this);
}

@JsonSerializable()
class InitialConfigRequest {
  final List<PlanDetail> planDetails;
  const InitialConfigRequest({required this.planDetails});
  factory InitialConfigRequest.fromJson(Map<String, dynamic> j) =>
      _$InitialConfigRequestFromJson(j);
  Map<String, dynamic> toJson() => _$InitialConfigRequestToJson(this);
}
```

```dart
// data/models/feature_config.dart
@JsonSerializable()
class FeatureConfig {
  final String featureId;
  final String params;
  final bool premiumOnly;
  final int minOSVersion;
  final int maxOSVersion;
  final bool enabled;
  const FeatureConfig({
    required this.featureId,
    this.params = '',
    this.premiumOnly = false,
    this.minOSVersion = 0,
    this.maxOSVersion = 1 << 30,
    this.enabled = true,
  });
  factory FeatureConfig.fromJson(Map<String, dynamic> j) =>
      _$FeatureConfigFromJson(j);
  Map<String, dynamic> toJson() => _$FeatureConfigToJson(this);
}

// data/models/version_availability.dart
@JsonSerializable()
class VersionAvailability {
  final bool forceUpdate;
  final bool promptUpdate;
  final bool beta;
  final int versionCode;
  final String versionName;
  final String changelog;
  const VersionAvailability({
    this.forceUpdate = false,
    this.promptUpdate = false,
    this.beta = false,
    this.versionCode = 0,
    this.versionName = '',
    this.changelog = '',
  });
  factory VersionAvailability.fromJson(Map<String, dynamic> j) =>
      _$VersionAvailabilityFromJson(j);
  Map<String, dynamic> toJson() => _$VersionAvailabilityToJson(this);
}
```

```dart
// data/models/calibration_config_request.dart
@JsonSerializable()
class InstalledPlatformConfig {
  final int platformVersion; // long in original
  final int version;
  const InstalledPlatformConfig({
    required this.platformVersion,
    required this.version,
  });
  factory InstalledPlatformConfig.fromJson(Map<String, dynamic> j) =>
      _$InstalledPlatformConfigFromJson(j);
  Map<String, dynamic> toJson() => _$InstalledPlatformConfigToJson(this);
}

@JsonSerializable()
class CalibrationConfigRequest {
  final int width;
  final int height;
  final String deviceConfig; // EnumDeviceConfig: MOBILE/TABLET/LANDSCAPE/LANDSCAPE_TABLET
  final Map<String, InstalledPlatformConfig> platforms;
  const CalibrationConfigRequest({
    required this.width,
    required this.height,
    required this.deviceConfig,
    required this.platforms,
  });
  factory CalibrationConfigRequest.fromJson(Map<String, dynamic> j) =>
      _$CalibrationConfigRequestFromJson(j);
  Map<String, dynamic> toJson() => _$CalibrationConfigRequestToJson(this);
}
```

```dart
// data/models/calibration_config_response.dart
enum SupportStatus { updateRequired, notSupported, fresh, supported }

@JsonSerializable()
class CalibrationConfigResponse {
  final String message;
  final Map<String, PlatformConfigMetaData> platforms;
  final int responseCode; // 200 == success (verified)
  const CalibrationConfigResponse({
    this.message = '',
    this.platforms = const {},
    this.responseCode = 0,
  });
  bool get isSuccess => responseCode == 200;
  factory CalibrationConfigResponse.fromJson(Map<String, dynamic> j) =>
      _$CalibrationConfigResponseFromJson(j);
  Map<String, dynamic> toJson() => _$CalibrationConfigResponseToJson(this);
}
```

> `PlatformConfigResponse`/`AppDetails`/`Platform`/`Detectors` and the calibration `PlatformHolder`/`PlatformCalibrationConfig` models are owned by the detection-engine and calibration docs (see Related docs) — keep their JSON keys identical (note `responsecode` is lowercase in `PlatformConfigResponse`).

---

## 9. Repository sketch (Clean Architecture)

The repository wraps the API + local store + bundled fallback, and exposes domain entities (not raw DTOs). It implements the cache-then-network + version-skip policy from §5.

```dart
// domain/repositories/config_repository.dart
abstract interface class ConfigRepository {
  Stream<Resource<InitialConfig>> syncInitialConfig(List<PlanRef> activePlans);
  Stream<Resource<PlatformRuleSet>> syncPlatformConfig();
  Stream<Resource<CalibrationSet>> syncCalibrationConfig(DeviceProfile device);
  Stream<Resource<PlanCatalog>> loadUpgradablePlans(UpgradeQuery q);
}
```

```dart
// data/repositories/config_repository_impl.dart
class ConfigRepositoryImpl implements ConfigRepository {
  final BlockerApi _api;
  final LocalConfigStore _store;
  final BundledConfigProvider _bundled;
  final DeviceFormFactor _formFactor;

  ConfigRepositoryImpl(this._api, this._store, this._bundled, this._formFactor);

  @override
  Stream<Resource<PlatformRuleSet>> syncPlatformConfig() async* {
    yield const ResourceLoading();
    try {
      final http = await _api.fetchPlatformConfig(
        _formFactor.isTablet,
        _formFactor.isFoldingPhone,
        _store.platformConfigVersion, // skip-if-unchanged header
      );
      // 304/empty => server says "nothing changed" => serve cache.
      if (http.response.statusCode == 304 || http.data == null) {
        final cached = await _store.readPlatformConfig();
        if (cached != null) {
          yield ResourceSuccess(cached.toEntity());
          return;
        }
      }
      final dto = http.data!;
      await _store.savePlatformConfig(dto);
      await _store.setPlatformConfigVersion(dto.configVersion);
      yield ResourceSuccess(dto.toEntity());
    } on DioException catch (e) {
      // Fallback chain: cache -> bundled res/raw asset.
      final cached = await _store.readPlatformConfig();
      if (cached != null) {
        yield ResourceSuccess(cached.toEntity());
      } else {
        final bundled = await _bundled.loadBundledPlatformConfig();
        yield ResourceSuccess(bundled.toEntity());
      }
      // Optionally surface a soft error for telemetry:
      // yield ResourceError(e.message ?? 'offline', errorCode: -1);
    }
  }

  @override
  Stream<Resource<CalibrationSet>> syncCalibrationConfig(DeviceProfile d) async* {
    yield const ResourceLoading();
    try {
      final dto = await _api.fetchCalibrationConfig(
        _formFactor.isTablet,
        _formFactor.isFoldingPhone,
        CalibrationConfigRequest(
          width: d.widthPx,
          height: d.heightPx,
          deviceConfig: d.deviceConfig.name.toUpperCase(),
          platforms: d.installedPlatforms,
        ),
      );
      if (!dto.isSuccess) {            // responseCode != 200 => keep last good
        final cached = await _store.readCalibrationConfig();
        if (cached != null) { yield ResourceSuccess(cached.toEntity()); return; }
      }
      await _store.saveCalibrationConfig(dto);
      yield ResourceSuccess(dto.toEntity()); // SupportStatus filtering in mapper
    } on DioException catch (e) {
      final cached = await _store.readCalibrationConfig();
      yield cached != null
          ? ResourceSuccess(cached.toEntity())
          : ResourceError(e.message ?? 'calibration offline');
    }
  }
}
```

### 9.1 Bloc wiring

```dart
// presentation/bloc/config_sync_bloc.dart
class ConfigSyncBloc extends Bloc<ConfigSyncEvent, ConfigSyncState> {
  final ConfigRepository _repo;
  ConfigSyncBloc(this._repo) : super(const ConfigSyncInitial()) {
    on<ConfigSyncRequested>((event, emit) async {
      await emit.forEach<Resource<PlatformRuleSet>>(
        _repo.syncPlatformConfig(),
        onData: (r) => switch (r) {
          ResourceLoading() => const ConfigSyncLoading(),
          ResourceSuccess(:final data) => ConfigSyncReady(data),
          ResourceError(:final message) => ConfigSyncFailure(message),
        },
      );
    });
  }
}
```

---

## 10. Endpoint → Flutter mechanism summary

| Endpoint | Mechanism | Legend |
|---|---|---|
| All 9 REST calls | `dio` + `retrofit` codegen, pure Dart | ✅ |
| `Resource<T>` state | hand-written sealed class (or `freezed`) | ✅ |
| Retry/backoff | `dio_smart_retry` | ✅ |
| Config caching | `shared_preferences` (scalars) + `hive`/`drift` (blobs) | ✅ |
| Bundled fallback | `rootBundle` asset (`platforms_config.json`) | ✅ |
| Feature flags / version gate | REST `initialConfig` **or** `firebase_remote_config` | ✅ |
| `isTablet` header | `MediaQuery`/`device_info_plus` | ✅ |
| `isFoldingPhone` header | MethodChannel → `hasSystemFeature("...hinge_angle")` | ⚠️ |
| `firstInstallMillis` (UpgradablePlans) | MethodChannel → `PackageManager.firstInstallTime` | ⚠️ |
| `installSources` map | MethodChannel → `getInstallSourceInfo` | ⚠️ |
| In-app update on force-gate | `in_app_update` (Android) | ✅ / iOS store link |
| Calibration per-device body | REST only (can't use Remote Config) | ✅ REST / ❌ RC |

**iOS note:** All networking/config sync is fully cross-platform ✅. The ⚠️ device probes degrade gracefully on iOS: `isFoldingPhone` → `false`, install-source/first-install from `package_info_plus` install-time where available, otherwise omit. The *consumers* of this config (the AccessibilityService detection engine) are Android-only — on iOS the closest analog is Apple `FamilyControls`/`DeviceActivity`/`ManagedSettings`, which is restricted parental-control API and does not consume this JSON.

---

## Source evidence

- `network/retrofit/IRetrofitApis.java` — verified all 9 `@POST` endpoints, paths, `@Header`/`@Body` annotations, `Response<T>` return types.
- `network/retrofit/Resource.java` — verified `Success(data)`, `Error(message, errorCode)`, `Loading(showLoadingScreen)`.
- `network/retrofit/RetrofitHelper$executeApiCall$1.java` — verified the `(showLoading, apiCall)` Flow-emitting helper; body `Method dump skipped` (Loading→Success/Error emit pattern **inferred** from two `emit()` calls in a try/catch).
- `/tmp/ns_analysis/networking-and-config-sync.json` — request/response field maps, caching to DataStore, version gating, OTP/plan flows.
- `/tmp/ns_analysis/platform-config.json` — `PlatformConfigResponse` shape (`configVersion`, `featuredApps`, `responsecode`, `updateIcon`/`updateMessage`); bundled `res/raw/platforms_config.json` fallback.
- `/tmp/ns_analysis/calibration.json` — `CalibrationConfigRequest`/`Response` fields, `responseCode == 200`, `SupportStatusEnum`, `EnumDeviceConfig`, DataStore `CALIBRATION_CONFIG` key.

## Related docs

- `01-architecture-overview.md`
- `02-accessibility-detection-engine.md`
- `03-platform-config-schema.md`
- `04-calibration-engine.md`
- `05-blocking-actions.md`
- `08-premium-billing.md`
- `11-local-storage-datastore.md`
