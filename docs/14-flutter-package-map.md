# Flutter Package Map & pubspec

> **Purpose.** This is the single, curated source-of-truth that maps **every Android mechanism** used by the decompiled short-form-content blocker to its **Flutter implementation**: an exact pub.dev package, a `⚠️` native MethodChannel/EventChannel bridge, or a `❌` impossible-on-iOS note. It de-duplicates and corrects the rougher draft in `/tmp/synth_flutterPlan.md`, pins realistic versions (as of mid-2026), and ends with a ready-to-paste `pubspec.yaml`, code-generation commands, and a `get_it` + `go_router` bootstrap sketch. Use this doc to fill `pubspec.yaml` and to decide, per feature, whether you can stay in Dart or must write Kotlin.

---

## Legend

| Symbol | Meaning |
|---|---|
| ✅ | A real pub.dev package fully handles it in Dart (no app-specific Kotlin needed). |
| ✅⚙️ | A pub.dev package handles it, but it itself contains a platform plugin (you still configure Android manifest/Gradle). |
| ⚠️ | No adequate package — you must write your own Kotlin behind a **MethodChannel** (request/response) or **EventChannel** (native → Dart stream). |
| ❌ | Not possible on iOS at all; Android-only mechanism. Apple alternative noted where one exists (FamilyControls / DeviceActivity / ManagedSettings, all parental-control-restricted). |

> **iOS reality (applies to the whole detection core):** iOS has **no equivalent to `AccessibilityService`**, no third-party view-tree traversal, no `performGlobalAction`, no app-killing, and no system overlays over other apps. The only Apple analogue is the **Screen Time / FamilyControls** stack (`FamilyControls`, `DeviceActivity`, `ManagedSettings`), which is entitlement-gated, parental-control-shaped, and cannot read in-app content or web frames. Treat this app as **Android-first**; an iOS build would be a different product (shield apps/categories via `ManagedSettings`, not reel-level detection).

---

## 1. Master mapping table

### 1.1 Detection core (the native boundary — mostly `⚠️`)

These are the pieces that make the app what it is. None of them are pure Dart.

| Android mechanism | Flutter approach | pub package (+typical version) | Legend |
|---|---|---|---|
| `AccessibilityService` binding (`BIND_ACCESSIBILITY_SERVICE`), `onAccessibilityEvent` loop | Custom Kotlin service in the `:as_process` isolated process; stream events to Dart via **EventChannel**. The detection/blocking decision logic ideally stays native for latency (Dart round-trip is too slow per event). | `flutter_accessibility_service: ^0.4.5` exists but is **insufficient for production** (no per-resource-id deep search, no `performGlobalAction` control). Use it only for the *enable/disable* status check; write the service yourself. | ⚠️ ❌(iOS: not possible; FamilyControls cannot observe other apps' UI) |
| View-tree traversal: `findAccessibilityNodeInfosByViewId(pkg+identifier)`, DFS via `ArrayDeque.removeLast()` (max 12000 iters), `getViewIdResourceName()`, focusable/visible checks, node recycling | **Native Kotlin only.** Reproduce the verified `LegacyDetector.findViewByIdWithId` stages (Stage1 source-id check, Stage2 `[FIND]`, Stage3 `[DEEP]`). Return a serialized result map over MethodChannel/EventChannel. | none — no Dart API touches `AccessibilityNodeInfo`. | ⚠️ ❌ |
| Web URL detection: strip unicode directional marks `{65279,8206,8207,8234,8235,8236,8294,8295,8296,8297}`, drop scheme + `www.`/`m.`, canonical host, `*.domain` wildcard, path-prefix scope | **Pure Dart.** Re-implement `parseWebUrlParts` / `matchesSubdomainWildcard` / `pathMatchesDomainScope` with `Uri` + `RegExp`. The *URL string itself* still arrives from the native accessibility node (browser address bar), so the **capture** is `⚠️` but the **matching** is `✅`. | `Uri` (dart:core) + optional `basic_utils: ^5.7.0` or `public_suffix: ^4.1.0` for eTLD+1 if you want PSL-correct apex detection. | ⚠️ capture / ✅ match |
| `performGlobalAction(GLOBAL_ACTION_BACK)` (PRESS_BACK, the default block) | Native Kotlin call inside the service. Expose a `block(mode)` MethodChannel method, or keep entirely native. | none. | ⚠️ ❌ |
| Kill app (`ActivityManager.killBackgroundProcesses` / `forceStopPackage`-style) — `KILL_APP` mode | Native Kotlin MethodChannel. | none. | ⚠️ ❌ |
| Lock screen — `LOCK_SCREEN` mode via `DevicePolicyManager.lockNow()` | Native Kotlin + Device Admin (see below). | none reliable; `device_policy_manager` plugins exist but are stale. | ⚠️ ❌ |
| System overlays — `WindowManager.addView(...)` with `TYPE_APPLICATION_OVERLAY` (PIN gate, one-reel-overlay, hard-block screen) | `flutter_overlay_window` for a Flutter-rendered overlay engine; **or** native Kotlin if you need the original Compose-style animated overlay (the app ships `OverlayUIRenderer`). | `flutter_overlay_window: ^0.4.5` | ✅⚙️ / ⚠️(advanced) ❌(iOS: `ManagedSettings` shield UI only, not custom) |

### 1.2 Device & OS integration (`⚠️` native or specialized packages)

| Android mechanism | Flutter approach | pub package (+typical version) | Legend |
|---|---|---|---|
| Device Admin — `DeviceAdminReceiver`, policy `<disable-uninstall/>` (verified `res/xml/device_admin_policies.xml`), `lockNow()` | Native Kotlin `DeviceAdminReceiver` declared in manifest + MethodChannel to enable/query; EventChannel for admin enable/disable callbacks. | none mature. | ⚠️ ❌ |
| Boot resurrection — `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED` receivers (restart foreground service) | Native Kotlin `BroadcastReceiver` declared in manifest (receivers can't be Dart). Optionally notify Dart via EventChannel after boot. | none (manifest-declared). | ⚠️ ❌ |
| Screen on/off — `ACTION_SCREEN_ON` / `ACTION_SCREEN_OFF` (drives one-reel polling, locks) | Package wraps these intents. | `screen_state: ^2.0.0` | ✅⚙️ ❌(iOS partial) |
| Usage stats — `UsageStatsManager` (`PACKAGE_USAGE_STATS`) for periodic app-foreground checks / daily-limit fallback | Periodic polling via WorkManager; real-time foreground still comes from the AccessibilityService. | `app_usage: ^3.0.0` (preferred, maintained) or `usage_stats: ^1.3.1` | ✅⚙️ ❌(iOS: `DeviceActivity` only, restricted) |
| Installed apps list — `PackageManager.getInstalledPackages` (block-list picker, dashboard) | Query package list + icons. | `installed_apps: ^1.5.2` (icons + names) or `device_apps: ^2.2.0` (less maintained) | ✅⚙️ ❌(iOS: not allowed) |
| Foreground service — `startForegroundService`, notification id `1125`, channel `noscroll_protection_channel` (LOW), FGS `specialUse` on API 34+, `onTaskRemoved` restart | `flutter_foreground_task` covers most cases; the **AccessibilityService** itself is its own foreground service in `:as_process` and is native regardless. | `flutter_foreground_task: ^8.17.0` | ✅⚙️ (companion) / ⚠️ (the AS process) ❌ |
| Battery-optimization exemption — `PowerManager.isIgnoringBatteryOptimizations()` / `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | `permission_handler` requests it; a tiny native call reads the current state. | `permission_handler: ^11.3.1` (`Permission.ignoreBatteryOptimizations`) | ✅⚙️ / ⚠️(state read) ❌ |
| Open system settings — `ACTION_ACCESSIBILITY_SETTINGS`, `ACTION_USAGE_ACCESS_SETTINGS`, overlay settings, etc. | Package opens standard settings screens. | `app_settings: ^5.1.1` | ✅⚙️ ❌ |
| Status broadcast `...ACCESSIBILITY_SERVICE_STATUS_CHANGED` (extra `extra_accessibility_service_enabled`) + command broadcast `com.noscroll.action.APP_COMMAND` (`RECEIVER_NOT_EXPORTED`, `EnumCommandToService`) | Native Kotlin `BroadcastReceiver`/sender; surface to Dart via EventChannel/MethodChannel. | none (custom IPC). | ⚠️ ❌ |
| Vibration / haptics — `Vibrator` (e.g. `VIDEO_BLOCKED` pattern) | Package wraps `Vibrator` + amplitude/patterns. | `vibration: ^2.0.0` | ✅⚙️ (iOS: limited haptics) |
| Device info — `Build.BRAND`, `Build.MANUFACTURER`, `Build.VERSION.SDK_INT` (OEM-specific permission flows) | Package exposes all build fields. | `device_info_plus: ^10.1.2` | ✅ |
| App version — `PackageInfo` (min/max app-version gating in config) | Package exposes version/build. | `package_info_plus: ^8.0.2` | ✅ |
| Install referrer — Play Install Referrer (verified used in `HomeActivity`) | Package wraps `InstallReferrerClient`. | `android_play_install_referrer: ^0.4.0` | ✅⚙️ ❌ |

### 1.3 Data, storage & networking (`✅` packages)

| Android mechanism | Flutter approach | pub package (+typical version) | Legend |
|---|---|---|---|
| Jetpack **DataStore** (encrypted prefs: PIN hash, email, plan, tokens) | Secrets in `flutter_secure_storage` (Keystore-backed AES); structured objects in Hive boxes. | `flutter_secure_storage: ^9.2.2` + `hive_ce: ^2.10.0` + `hive_ce_flutter: ^2.2.0` | ✅ |
| Legacy `SharedPreferences` (non-sensitive flags) | Optional simple KV. | `shared_preferences: ^2.3.2` | ✅ |
| **Room** database (block-event analytics / history) | Type-safe SQL ORM with codegen + migrations. | `drift: ^2.20.3` + `sqlite3_flutter_libs: ^0.5.24` | ✅ |
| **Retrofit + OkHttp** (config & analytics REST API) | Dio client; optional Retrofit-style typed client via codegen. | `dio: ^5.7.0` (+ `retrofit: ^4.4.1` if you want annotated endpoints) | ✅ |
| **Gson** JSON ↔ models | Immutable models with generated `fromJson`/`toJson`. | `freezed_annotation: ^2.4.4` + `json_annotation: ^4.9.0` (generators in dev-deps) | ✅ |
| Firebase **Remote Config** (server `platforms_config.json`, `initial_config.json`) | Fetch + cache remote JSON config. | `firebase_remote_config: ^5.1.3` | ✅⚙️ |
| Firebase **Cloud Firestore** (cloud sync, if used) | Cloud document store. | `cloud_firestore: ^5.4.4` | ✅⚙️ |
| Image cache — Coil/Picasso (platform icons, emoji art) | Network image cache widget. | `cached_network_image: ^3.4.1` | ✅ |

### 1.4 Monetization, messaging & UX services (`✅` packages)

| Android mechanism | Flutter approach | pub package (+typical version) | Legend |
|---|---|---|---|
| **Google Play Billing** (`NoScrollBillingService`, subs) | Cross-platform IAP; pin Android backend for v8 billing features. | `in_app_purchase: ^3.2.0` (+ `in_app_purchase_android: ^0.3.6+15`) | ✅⚙️ ❌(iOS uses StoreKit via same plugin) |
| **Google Mobile Ads** + UMP consent | AdMob banners/native/interstitial + GDPR consent form. | `google_mobile_ads: ^5.1.0` (UMP bundled) | ✅⚙️ |
| **Firebase Cloud Messaging** (`FirebaseNotificationReceiver`) | Push receive + token. | `firebase_messaging: ^15.1.3` (+ `firebase_core: ^3.6.0`) | ✅⚙️ |
| **Firebase Analytics** (block/unlock events) | Event logging. | `firebase_analytics: ^11.3.3` | ✅⚙️ |
| **Crashlytics** (verified present) | Crash reporting. | `firebase_crashlytics: ^4.1.3` | ✅⚙️ |
| **BiometricPrompt** (`BiometricHelper` — PIN-recovery unlock) | Fingerprint/face unlock. | `local_auth: ^2.3.0` | ✅⚙️ |
| **NotificationManager** channels (protection notif, etc.) | Local notifications + channels. | `flutter_local_notifications: ^17.2.3` | ✅⚙️ |
| **WorkManager** (daily quota reset at midnight, config sync) | Periodic + one-off background tasks. | `workmanager: ^0.5.2` | ✅⚙️ |
| **Play In-App Review** (`ReviewManager`, verified in `HomeActivity`) | Trigger in-app review flow. | `in_app_review: ^2.0.10` | ✅⚙️ |
| Runtime permissions (overlay, notifications, usage, battery) | Unified request API. | `permission_handler: ^11.3.1` | ✅⚙️ |

### 1.5 App-internal architecture (`✅` packages)

| Concern | Android counterpart | Flutter approach | pub package (+typical version) | Legend |
|---|---|---|---|---|
| State management | Kotlin `Flow` / `StateFlow` | BLoC pattern | `flutter_bloc: ^8.1.6` (+ `bloc: ^8.1.4`) | ✅ |
| Dependency injection | Hilt | Service locator (optionally codegen) | `get_it: ^8.0.0` (+ `injectable: ^2.5.0` for codegen) | ✅ |
| Navigation / deep links | Compose Navigation + intent filters | Declarative router | `go_router: ^14.2.7` | ✅ |
| Value equality / immutables | Kotlin `data class` | Generated unions/copyWith **or** lightweight equality | `freezed: ^2.5.7` (codegen) **or** `equatable: ^2.0.5` | ✅ |
| i18n & date formatting (`dd-MM-yyyy`, plurals) | Compose strings / `DateFormat` | Intl + formatters | `intl: ^0.19.0` | ✅ |
| IDs (event/session uuids) | `UUID` | UUID generator | `uuid: ^4.5.1` | ✅ |
| Logging | `android.util.Log` | Structured logger | `logger: ^2.4.0` | ✅ |

> **Corrections vs. the draft plan in `/tmp/synth_flutterPlan.md`:**
> - Dropped `uni_links` (unmaintained) — `go_router` handles app/deep links; use `app_links: ^6.3.1` only if you need raw stream access.
> - Replaced `google_app_review` with the canonical `in_app_review`.
> - `hive` → `hive_ce` (the maintained community fork; original `hive` is abandoned).
> - `install_referrer` → `android_play_install_referrer` (correct package id).
> - `usage_stats` → prefer `app_usage` (maintained).
> - Removed Riverpod/Isar "alternatives" noise — this blueprint standardizes on **flutter_bloc + drift + hive_ce**.
> - Do **not** rely on `flutter_accessibility_service` for detection; it is listed only for the enable-state check.

---

## 2. Complete `pubspec.yaml` (ready to paste)

```yaml
name: no_scroll
description: Short-form content blocker (Reels/Shorts/TikTok) — AccessibilityService + PIN lock.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ">=3.5.0 <4.0.0"
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter

  # ---------- State / DI / Routing ----------
  flutter_bloc: ^8.1.6
  bloc: ^8.1.4
  get_it: ^8.0.0
  injectable: ^2.5.0
  go_router: ^14.2.7

  # ---------- Networking ----------
  dio: ^5.7.0
  retrofit: ^4.4.1

  # ---------- Models / serialization ----------
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  equatable: ^2.0.5

  # ---------- Local storage ----------
  flutter_secure_storage: ^9.2.2
  hive_ce: ^2.10.0
  hive_ce_flutter: ^2.2.0
  shared_preferences: ^2.3.2

  # ---------- Analytics DB (Room -> drift) ----------
  drift: ^2.20.3
  sqlite3_flutter_libs: ^0.5.24
  path_provider: ^2.1.4
  path: ^1.9.0

  # ---------- Firebase ----------
  firebase_core: ^3.6.0
  firebase_analytics: ^11.3.3
  firebase_messaging: ^15.1.3
  firebase_remote_config: ^5.1.3
  firebase_crashlytics: ^4.1.3
  cloud_firestore: ^5.4.4

  # ---------- Monetization ----------
  in_app_purchase: ^3.2.0
  in_app_purchase_android: ^0.3.6+15
  google_mobile_ads: ^5.1.0
  in_app_review: ^2.0.10

  # ---------- Device / system integration ----------
  flutter_overlay_window: ^0.4.5      # system overlays (PIN / one-reel / hard-block)
  flutter_foreground_task: ^8.17.0    # companion foreground service
  workmanager: ^0.5.2                 # midnight quota reset, config sync
  flutter_accessibility_service: ^0.4.5  # enable-state check ONLY (detection is native)
  permission_handler: ^11.3.1
  app_settings: ^5.1.1
  local_auth: ^2.3.0
  flutter_local_notifications: ^17.2.3
  vibration: ^2.0.0
  device_info_plus: ^10.1.2
  package_info_plus: ^8.0.2
  installed_apps: ^1.5.2
  app_usage: ^3.0.0
  screen_state: ^2.0.0
  android_play_install_referrer: ^0.4.0

  # ---------- UI / utils ----------
  cached_network_image: ^3.4.1
  intl: ^0.19.0
  uuid: ^4.5.1
  logger: ^2.4.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

  # ---------- Code generation ----------
  build_runner: ^2.4.13
  freezed: ^2.5.7
  json_serializable: ^6.8.0
  injectable_generator: ^2.6.2
  retrofit_generator: ^9.1.2
  hive_ce_generator: ^1.7.0
  drift_dev: ^2.20.3

  # ---------- Testing ----------
  mocktail: ^1.0.4
  bloc_test: ^9.1.7

flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/animations/
    - assets/json/platforms_config.json   # local fallback for remote config
    - assets/json/initial_config.json
    - assets/json/emoji_sets/
  fonts:
    - family: Roboto
      fonts:
        - asset: assets/fonts/Roboto-Regular.ttf
        - asset: assets/fonts/Roboto-Bold.ttf
          weight: 700
```

> **Native plugins that still need Gradle/manifest work (not just `pubspec`):** the AccessibilityService, its `:as_process` declaration, `site_manager_service.xml`, the Device Admin receiver + `device_admin_policies.xml`, boot/screen/command receivers, foreground-service `specialUse` type, and the overlay permission. Those live in `android/app/src/main/` and behind your own MethodChannels — see `14`'s sibling `04-native-android-layer.md`.

---

## 3. Code generation

Several packages above are codegen-driven (`freezed`, `json_serializable`, `injectable`, `retrofit`, `hive_ce`, `drift`). After editing any annotated source:

```bash
# one-shot build (use this in CI and after pulling)
dart run build_runner build --delete-conflicting-outputs

# watch mode during development
dart run build_runner watch --delete-conflicting-outputs

# nuke generated outputs if the graph gets stuck
dart run build_runner clean
```

What gets generated:

| Input annotation | Generated file(s) | Produced by |
|---|---|---|
| `@freezed` | `*.freezed.dart` (immutability, `==`, `copyWith`, unions) | `freezed` |
| `@JsonSerializable` / freezed `fromJson` | `*.g.dart` (`fromJson`/`toJson`) | `json_serializable` |
| `@injectable` / `@module` | `*.config.dart` (DI graph) | `injectable_generator` |
| `@RestApi` | `*.g.dart` (Dio-backed client impl) | `retrofit_generator` |
| `@HiveType` | `*.g.dart` (TypeAdapters) | `hive_ce_generator` |
| `@DriftDatabase` / `.drift` tables | `*.g.dart` (DB classes) | `drift_dev` |

> Keep generated files out of code review but **in** version control if your CI does not run codegen; otherwise `.gitignore` them and generate in CI. Pick one and document it in the repo README.

---

## 4. Bootstrap sketch — `get_it` (+ `injectable`) and `go_router`

Illustrative blueprint, written cleanly from scratch (not copied from the decompiled app).

### 4.1 DI container (`lib/config/di_container.dart`)

```dart
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'di_container.config.dart'; // generated by injectable_generator

final GetIt getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
)
Future<void> configureDependencies() async => getIt.init();
```

```dart
// Example annotated registrations (collected by injectable codegen).

@module
abstract class StorageModule {
  @singleton
  FlutterSecureStorage get secureStorage => const FlutterSecureStorage();
}

@LazySingleton(as: PlatformConfigRepository)
class PlatformConfigRepositoryImpl implements PlatformConfigRepository {
  PlatformConfigRepositoryImpl(this._remote, this._local);
  final ConfigRemoteDataSource _remote;
  final ConfigLocalDataSource _local;
  // ...
}

// BLoCs are factories (fresh instance per route/screen):
@injectable
class BlockingBloc extends Bloc<BlockingEvent, BlockingState> {
  BlockingBloc(this._executeBlock) : super(const BlockingState.idle());
  final ExecuteBlockActionUseCase _executeBlock;
  // ...
}
```

> If you prefer manual wiring over codegen, drop `injectable` and register by hand: `getIt.registerLazySingleton<PlatformConfigRepository>(() => PlatformConfigRepositoryImpl(getIt(), getIt()));` and `getIt.registerFactory(() => BlockingBloc(getIt()));`.

### 4.2 Router (`lib/config/router.dart`)

```dart
import 'package:go_router/go_router.dart';

GoRouter buildRouter() => GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(
          path: '/permissions',
          builder: (_, __) => const MultiPermissionScreen(),
        ),
        GoRoute(
          path: '/pin-settings',
          builder: (_, __) => const PinSettingsScreen(),
        ),
        GoRoute(path: '/premium', builder: (_, __) => const PremiumScreen()),
        // Deep links from FCM / install referrer resolve here.
        GoRoute(path: '/blocklist/apps', builder: (_, __) => const AppBlockerListScreen()),
        GoRoute(path: '/blocklist/web', builder: (_, __) => const WebBlocklistScreen()),
      ],
    );
```

### 4.3 `main()` wiring

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await configureDependencies(); // get_it + injectable
  runApp(NoScrollApp(router: buildRouter()));
}

class NoScrollApp extends StatelessWidget {
  const NoScrollApp({super.key, required this.router});
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<AccessibilityBloc>()),
        BlocProvider(create: (_) => getIt<PlanBloc>()),
        BlocProvider(create: (_) => getIt<PremiumBloc>()),
      ],
      child: MaterialApp.router(
        title: 'NoScroll',
        routerConfig: router,
      ),
    );
  }
}
```

> The overlay UI (`flutter_overlay_window`) runs in a **separate Flutter engine entrypoint** — register it with `@pragma('vm:entry-point') void overlayMain() => runApp(const OverlayApp());` and call `FlutterOverlayWindow.showOverlay(...)` from the native block path. The background WorkManager callback likewise needs its own `@pragma('vm:entry-point')` dispatcher.

---

## Source evidence

This map is grounded in the decompiled app and verified facts:

- `sources/com/newswarajya/noswipe/reelshortblocker/service/accessibility/NoScrollAccessibilityService.java` — service runtime, throttle/debounce constants, `performGlobalAction(BACK)`, foreground notification id `1125`, command/status broadcasts.
- `sources/com/newswarajya/noswipe/reelshortblocker/service/accessibility/overlay/OverlayUIRenderer.java` — app-owned `WindowManager` overlay (justifies `flutter_overlay_window`/native overlay).
- `sources/com/newswarajya/noswipe/reelshortblocker/monetization/purchases/NoScrollBillingService.java` — Play Billing (`in_app_purchase`).
- `sources/com/newswarajya/noswipe/reelshortblocker/notifications/FirebaseNotificationReceiver.java` + `com/google/firebase/messaging/*` — FCM (`firebase_messaging`).
- `sources/com/newswarajya/noswipe/reelshortblocker/activities/pinblockoverlay/common/BiometricHelper.java` + `androidx/biometric/BiometricPrompt.java` — `local_auth`.
- `sources/com/newswarajya/noswipe/reelshortblocker/activities/home/HomeActivity.java` + `com/google/android/play/core/review/*` + `com/android/installreferrer/api/*` — `in_app_review`, `android_play_install_referrer`.
- `com/google/firebase/remoteconfig/*`, `com/google/firebase/crashlytics/*` — Remote Config, Crashlytics.
- `resources/res/xml/device_admin_policies.xml` (`<disable-uninstall/>`), `resources/res/xml/site_manager_service.xml`, `resources/res/raw/platforms_config.json`, `initial_config.json` — Device Admin policy, AS config, data-driven detection config.
- Synthesis input: `/tmp/synth_flutterPlan.md` (curated and corrected here).

## Related docs

- `01-overview-architecture.md`
- `02-detection-config-schema.md`
- `03-detection-engine.md`
- `04-native-android-layer.md`
- `05-plans-pause-curious.md`
- `06-app-and-web-blocker.md`
- `07-daily-limit-scheduler.md`
- `08-pin-lock-recovery.md`
- `09-persistence-data-model.md`
