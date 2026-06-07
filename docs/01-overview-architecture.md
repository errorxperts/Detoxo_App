# Overview & Architecture

> **Purpose.** This is the entry technical document of a developer blueprint for re-building a short-form content blocker (Instagram Reels / YouTube Shorts / Facebook Reels / TikTok / browser Shorts) as a **Flutter** app, reverse-engineered from a decompiled Android-native original. It gives you the executive summary, the complete feature inventory, the high-level architecture (native Android service ↔ platform channels ↔ Dart Clean-Architecture layers ↔ remote config API), the recommended Flutter project layout, and how dependency injection and routing are wired. Sibling docs go deep on each subsystem; this one orients you.

---

## 1. Executive summary

The app is a **digital-wellbeing "doom-scroll" blocker**. It runs an always-on **Android AccessibilityService** that watches the screen of *other* apps. When the service detects that the foreground app is rendering short-form video (a "reel"/"short"), it executes a **block action** — usually a simulated Back press, but optionally killing the app or locking the device — within a fraction of a second, so the user is pulled out of the infinite-scroll feed. Detection is fully **data-driven**: a JSON config (`platforms_config.json`, bundled and refreshed from a server) lists each target app, its platforms, and the Android view resource-ids / content-descriptions / URL patterns that mark "this is a reel." On top of raw blocking the app layers **blocking plans** (Block-All, Curious time-boxing, One-Reel, Paused), an **app blocker** (PIN-locked apps, per-app sessions), a **web blocker** (browser URL matching), a **daily limit** with midnight reset, **pause/cooldown countdowns**, a **PIN lock with email-OTP recovery**, **monetization** (premium gating + ads), **analytics**, **notifications**, a guided **onboarding/permissions** flow, **device-admin** uninstall protection, and **service resilience** (foreground service + boot restart). This is **Android-first**; iOS has no AccessibilityService equivalent, so the iOS story is a heavily reduced FamilyControls/ScreenTime approximation (see §9).

---

## 2. Complete feature inventory

Every subsystem the blueprint covers, with the legend showing how it maps onto Flutter:

> **Legend:** ✅ a pub.dev package handles it · ⚠️ needs a native MethodChannel/EventChannel bridge · ❌ not possible on iOS

| # | Subsystem | What it does | Flutter mapping | Deep-dive doc |
|---|---|---|---|---|
| 1 | **Detection engine** | Real-time matching of the foreground app's view tree / URL against config rules to decide "this is a reel". | ⚠️ native (AccessibilityService + node traversal) · ❌ iOS | `05`, `02` |
| 2 | **Block plans** | `BlockingModesEnum` actions: `PRESS_BACK`(1), `KILL_APP`(2), `LOCK_SCREEN`(3), `NONE`(4). | ⚠️ native (`performGlobalAction`, `ActivityManager`, `DevicePolicyManager.lockNow`) | `06` |
| 3 | **Detection plans** | `PlansEnum`: `BLOCK_ALL`, `CURIOUS`, `ONE_REEL`, `PAUSED` — high-level mode gating. | ✅ Dart state (BLoC) + ⚠️ command to service | `07` |
| 4 | **App blocker** | PIN-lock arbitrary apps; per-app unlock sessions w/ expiry; brute-force throttle. | ⚠️ native foreground-app detection · ❌ iOS | `09` |
| 5 | **Web blocker** | Match browser address-bar URLs (domain / exact / wildcard) against a user blocklist. | ⚠️ native URL extraction; ✅ Dart matching logic | `08` |
| 6 | **Daily limit** | Per-day consumed-time quota per app; midnight reset by date signature. | ✅ Dart logic + ⚠️ usage tracking; `workmanager` for reset | `10` |
| 7 | **Scheduler / windows** | Time-window phase machines for pause and curious cooldowns. | ✅ pure Dart (Duration math + timers) | `07`, `10` |
| 8 | **Pause / Curious / Countdown** | Temporary suspension (pause) and Pomodoro-style watch/cooldown (curious) with animated countdown UI. | ✅ Dart + Flutter UI | `07` |
| 9 | **PIN + recovery** | PIN setup (custom/date/time/OTP/device), restriction scoping, retry lockouts, email-OTP "forgot PIN". | ✅ `local_auth`, Dart logic + remote OTP API | `09` |
| 10 | **Persistence** | Encrypted key-value + structured local store (config, sessions, plans, PIN). | ✅ `flutter_secure_storage` + `hive`/`drift` | `11` |
| 11 | **Networking / config sync** | Fetch `platforms_config.json`, `initial_config.json`, calibration, plans from REST; cache locally. | ✅ `dio` + `firebase_remote_config` | `12` |
| 12 | **Monetization** | Premium gating of platforms/modes; Play billing; ads; deep-link offers. | ✅ `in_app_purchase`, `google_mobile_ads` | `13` |
| 13 | **Analytics** | Per-block events (`<platformId>_blocked`), session/scroll stats. | ✅ `firebase_analytics` + local `drift` | `13` |
| 14 | **Notifications** | Foreground-service notification + in-app promos (rating, update, permission nudges). | ✅ `flutter_local_notifications`, `firebase_messaging` | `13` |
| 15 | **Onboarding / permissions** | Plan picker + staged grant flow (accessibility, overlay, usage-access, notifications, battery, device-admin). | ✅ `permission_handler`/`app_settings` + ⚠️ accessibility/battery checks | `03` |
| 16 | **Device-admin** | Uninstall protection + screen-lock capability. | ⚠️ native `DeviceAdminReceiver` · ❌ iOS | `14` |
| 17 | **Service resilience** | Foreground service in isolated process, `onTaskRemoved` resurrection, boot-restart. | ⚠️ native foreground service + boot receiver | `14` |

---

## 3. High-level architecture

The system spans three runtime tiers: a **native Android process** that touches the OS, the **Flutter/Dart app** organised in Clean-Architecture layers, and a **remote config/REST backend**. The channels are the only seam between native and Dart.

```
                              ┌──────────────────────────────────────────────────────┐
                              │                  REMOTE BACKEND                        │
                              │  REST: getPlatformConfig / initialConfig /             │
                              │        getCalibrationConfig / upgradablePlans /        │
                              │        sendOtp / validateOtp                           │
                              │  Firebase: Analytics · Remote Config · FCM             │
                              └───────────────▲──────────────────────────┬────────────┘
                                              │ dio (HTTPS, JSON)         │ push / config
                                              │                           ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                  FLUTTER / DART  (main isolate, UI process)            │
│                                                                                       │
│  PRESENTATION         ┌──────────────────────────────────────────────────────────┐   │
│  presentation/bloc    │ AccessibilityBloc · BlockingBloc · PlanBloc · PauseBloc    │   │
│  presentation/screens │ PinBloc · PremiumBloc · DailyLimitBloc · PermissionBloc    │   │
│  presentation/widgets │ go_router navigates screens; widgets render state          │   │
│                       └───────────────▲──────────────────────────────────────────┘   │
│                                       │ events / states                                │
│  DOMAIN               ┌───────────────┴──────────────────────────────────────────┐   │
│  domain/entities      │ Entities: DetectedContent, BlockingPlan, BlockingAction,  │   │
│  domain/usecases      │           PauseSession, FocusSession, PinConfig, ...       │   │
│                       │ UseCases: DetectShortContent, ExecuteBlockAction,          │   │
│                       │           SwitchPlan, EnforcePinLock, SyncPlatformConfig   │   │
│                       │ Repository INTERFACES (abstract)                           │   │
│                       └───────────────▲──────────────────────────────────────────┘   │
│                                       │ implements                                     │
│  DATA                 ┌───────────────┴──────────────────────────────────────────┐   │
│  data/repositories    │ Repo impls · models (freezed/json_serializable)           │   │
│  data/datasources     │ local: hive/secure_storage/drift   remote: dio/firebase   │   │
│  data/models          │ platform: MethodChannel + EventChannel datasources        │   │
│                       └───────────────▲──────────────────────────────────────────┘   │
│  config/di_container.dart (get_it)    │  config/router.dart (go_router)               │
└───────────────────────────────────────┼──────────────────────────────────────────────┘
                                         │  MethodChannel (commands → native)
                                         │  EventChannel  (events ← native)
┌────────────────────────────────────────┼─────────────────────────────────────────────┐
│                NATIVE ANDROID  (Kotlin) — runs partly in isolated :accessibility_service_process │
│                                                                                        │
│  AccessibilityService  ──► node-tree traversal ──► detection result ──EventChannel──►   │
│  performGlobalAction(BACK) · ActivityManager (kill) · DevicePolicyManager.lockNow      │
│  WindowManager system overlays (TYPE_APPLICATION_OVERLAY)                               │
│  Foreground service (id 1125, channel "noscroll_protection_channel")                    │
│  BroadcastReceivers: command "com.noscroll.action.APP_COMMAND" · BOOT_COMPLETED · SCREEN│
│  DeviceAdminReceiver (uninstall protection)                                             │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

**Key flow (verified):** the native `AccessibilityService` receives events, throttles per package (`THROTTLE_INTERVAL_MS = 150` via a per-package map), checks the active plan, dispatches a detector, and on a match calls a "handle detection" step that resolves a block mode and performs the OS action. Block actions are debounced (skip if `now − lastBlockTime ≤ 1200 ms`) and Back presses are further rate-limited (`lastVideoBlocked ≤ now − 1100 ms`). In our Flutter design, **detection + OS actions stay native** (they have no Dart equivalent); the **decision policy** (which plan, premium/quota gating, web matching, schedules) can live in Dart, with native asking Dart over a channel — or, for latency, the policy can be mirrored into the native layer and Dart owns configuration/UI. The blueprint recommends keeping the *hot path* (event → throttle → detect → block) native for sub-100 ms latency, and using Dart for everything else.

*Source evidence:* `service/accessibility/NoScrollAccessibilityService.java`, `service/accessibility/processors/detectors/LegacyDetector.java`, `res/xml/site_manager_service.xml` (`accessibilityEventTypes="typeAllMask"`, `notificationTimeout="100"`, flags `flagRetrieveInteractiveWindows|flagRequestFilterKeyEvents|flagReportViewIds|flagRequestEnhancedWebAccessibility`, isolated `:accessibility_service_process`).

---

## 4. Clean Architecture for this app

We use **flutter_bloc + Clean Architecture**. Dependencies point inward: Presentation → Domain ← Data. Domain is pure Dart and knows nothing about Flutter, channels, or HTTP.

| Layer | Folder | Responsibility | Examples in this app |
|---|---|---|---|
| **Presentation** | `presentation/bloc`, `presentation/screens`, `presentation/widgets` | Render state, dispatch events. No business rules. Each feature gets one BLoC. | `AccessibilityBloc` reacts to detected-content events from an EventChannel; `PlanBloc` switches `BlockingPlan`; `PinBloc` drives the PIN lock screen. |
| **Domain** | `domain/entities`, `domain/usecases` | Platform-agnostic entities + single-responsibility use cases + repository **interfaces**. The "rules" of blocking. | `DetectShortContentUseCase`, `ExecuteBlockActionUseCase`, `EnforcePinLockUseCase`, `SwitchBlockingPlanUseCase`, `ResolvePauseProgressUseCase`. Entities: `DetectedContent`, `BlockingPlan`, `BlockingAction`, `PauseSession`, `PinConfig`. |
| **Data** | `data/repositories`, `data/datasources`, `data/models` | Implement domain interfaces. Three datasource kinds: **local** (hive/secure_storage/drift), **remote** (dio/firebase), **platform** (Method/EventChannel). Models do JSON ⇄ entity. | `PlatformConfigRepositoryImpl` parses `platforms_config.json`; `AccessibilityDataSource` listens on EventChannel; `BlockingDataSource` calls MethodChannel to press Back / kill / lock. |

**Why this maps cleanly from the original.** The decompiled app already separates concerns the same way under different names — a `Repository` (DataStore-backed flows), a `ServiceModel` (in-memory reactive state combining those flows), and the `Service` (consumer that performs actions). We translate:

| Original (Android) | Our Clean-Arch home | Note |
|---|---|---|
| `NoScrollAccessibilityRepository` (DataStore flows) | `data/datasources/local` + repositories | persisted config/sessions |
| `NoScrollServiceModel` (combined `StateFlow`s, `processAndBlockShortContent`) | domain use cases + a `BlockingPolicy` service | the policy/gating brain |
| `NoScrollAccessibilityService` (event loop, OS actions) | native Kotlin behind channels | hot path stays native |
| `HomeViewModel` (Compose state) | `presentation/bloc/*` | one BLoC per feature instead of one mega VM |
| Kotlin `Flow`/`StateFlow` | Dart `Stream` + BLoC states | reactive equivalence |
| Hilt `@Inject` | `get_it` registrations | service locator |
| Compose Navigation `NoScrollScreen` enum | `go_router` routes | declarative routing |

---

## 5. The native ↔ Dart boundary at a glance

Only these things *must* cross the channel; everything else is Dart. (Full channel contracts + Kotlin sketches are in `04-platform-channels.md`; the service internals in `14-native-android-service.md`.)

| Capability | Direction | Channel | pub package option | Legend |
|---|---|---|---|---|
| Accessibility events / detected reel | native → Dart | EventChannel | `flutter_accessibility_service` (partial) | ⚠️ ❌iOS |
| View-tree traversal (FINDBYID / CONT_DESC / DFS) | native only | — | none | ⚠️ ❌iOS |
| Press Back (`performGlobalAction(GLOBAL_ACTION_BACK)`=1) | Dart → native | MethodChannel | none | ⚠️ ❌iOS |
| Kill app (`ActivityManager`) | Dart → native | MethodChannel | none | ⚠️ ❌iOS |
| Lock screen (`DevicePolicyManager.lockNow`) | Dart → native | MethodChannel | `device_admin`(custom) | ⚠️ ❌iOS |
| System overlay (one-reel / cooldown) | both | MethodChannel + plugin | `flutter_overlay_window` | ⚠️ ❌iOS |
| Foreground app changes | native → Dart | EventChannel | `usage_stats` (polling only) | ⚠️ ❌iOS |
| Service status changed | native → Dart | EventChannel/broadcast | — | ⚠️ |
| Command to service (plan switch, refresh) | Dart → native | MethodChannel/broadcast `com.noscroll.action.APP_COMMAND` | — | ⚠️ |
| Boot restart | native only | BroadcastReceiver | — | ⚠️ ❌iOS |
| Device-admin enable/state | both | MethodChannel + receiver | none | ⚠️ ❌iOS |
| Accessibility/overlay/battery permission state | Dart → native | MethodChannel | `permission_handler`, `app_settings` (partial) | ⚠️ |
| Vibration on block | Dart | — | `vibration` | ✅ |
| Persistence, networking, billing, ads, notifications, analytics, biometrics | Dart | — | see §2 mappings | ✅ |

The original confirms the broadcast seam already exists natively: a command receiver listens on **`com.noscroll.action.APP_COMMAND`** (`RECEIVER_NOT_EXPORTED`) mapping to an `EnumCommandToService` (e.g. `PLAN_SWITCH`, `CURIOUS_CONFIG_UPDATED`, `PAUSE_CONFIG_UPDATED`, `REFRESH_DATA`), and the service broadcasts **`com.newswarajya.noswipe.reelshortblocker.ACCESSIBILITY_SERVICE_STATUS_CHANGED`** with extra `extra_accessibility_service_enabled`. *(Verified in `NoScrollAccessibilityService.java`.)*

---

## 6. Recommended Flutter project structure

Trimmed from the synthesis plan; only the entry-doc skeleton (each feature folder is fleshed out in its own doc).

```
no_scroll/
├── lib/
│   ├── main.dart                         # bootstrap: DI + router + Firebase + BlocProviders
│   ├── core/
│   │   ├── constants/                    # durations (THROTTLE=150ms, DEBOUNCE=1200ms, BACK_RATE=1100ms,
│   │   │                                 #            ONE_REEL_GRACE=500ms, HARD_BLOCK≈10000ms), action ids
│   │   ├── enums/                        # BlockingMode, BlockingPlan, DetectionType, WebMatchType, ...
│   │   ├── error/                        # failures + exceptions
│   │   └── platform_channels/            # AccessibilityChannel, BlockingChannel, OverlayChannel,
│   │                                     #   DeviceAdminChannel, ServiceCommandChannel, BootChannel
│   ├── data/
│   │   ├── datasources/
│   │   │   ├── local/                    # hive + secure_storage + drift (analytics)
│   │   │   ├── remote/                   # dio api client, firebase remote config, fcm
│   │   │   └── platform/                 # EventChannel listeners → Dart models
│   │   ├── models/                       # freezed/json_serializable: PlatformConfig, Detector, ...
│   │   └── repositories/                 # *RepositoryImpl
│   ├── domain/
│   │   ├── entities/                     # DetectedContent, BlockingPlan, BlockingAction, PinConfig, ...
│   │   ├── repositories/                 # abstract repo interfaces
│   │   └── usecases/                     # detection/ blocking/ planning/ config/ premium/ permissions/
│   ├── presentation/
│   │   ├── bloc/                         # one folder per feature (event/state/bloc)
│   │   ├── screens/                      # splash, onboarding, dashboard, permission, pin, premium, ...
│   │   ├── widgets/                      # reusable: plan_card, countdown_timer, permission_card, ...
│   │   └── theme/
│   ├── config/
│   │   ├── di_container.dart             # get_it registrations
│   │   ├── router.dart                   # go_router routes
│   │   └── firebase_config.dart
│   └── services/                         # background_service (workmanager), notification, analytics
├── android/app/src/main/kotlin/...       # NoScrollAccessibilityService.kt + channels + receivers
│   └── AndroidManifest.xml               # service (:accessibility_service_process), FGS special-use,
│                                         #   receivers, device-admin, BIND_ACCESSIBILITY_SERVICE
├── ios/Runner/                           # README_iOS.md: limitations (see §9)
├── assets/json/                          # bundled fallbacks: platforms_config.json, initial_config.json
├── pubspec.yaml
└── test/
```

---

## 7. Dependency injection (get_it)

A single `get_it` service locator wires everything, registered once at startup before `runApp`. Singletons for stateless services/repos/use cases; **factories** for BLoCs that own per-screen lifecycle (or singletons for app-wide BLoCs like Accessibility/Plan).

```dart
// lib/config/di_container.dart  (blueprint sketch — illustrative)
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  // --- core / platform channels ---
  getIt.registerLazySingleton(() => AccessibilityChannel());   // EventChannel wrapper
  getIt.registerLazySingleton(() => BlockingChannel());        // MethodChannel: back/kill/lock
  getIt.registerLazySingleton(() => ServiceCommandChannel());  // APP_COMMAND broadcasts

  // --- data sources ---
  getIt.registerLazySingleton<ConfigRemoteDataSource>(
      () => ConfigRemoteDataSourceImpl(getIt())); // dio
  getIt.registerLazySingleton<PreferencesLocalDataSource>(
      () => HivePreferencesDataSource());

  // --- repositories (interface -> impl) ---
  getIt.registerLazySingleton<PlatformConfigRepository>(
      () => PlatformConfigRepositoryImpl(getIt(), getIt()));
  getIt.registerLazySingleton<BlockingRepository>(
      () => BlockingRepositoryImpl(getIt()));

  // --- use cases ---
  getIt.registerFactory(() => DetectShortContentUseCase(getIt()));
  getIt.registerFactory(() => ExecuteBlockActionUseCase(getIt()));
  getIt.registerFactory(() => SwitchBlockingPlanUseCase(getIt()));

  // --- blocs ---
  getIt.registerLazySingleton(() => AccessibilityBloc(
        detect: getIt(), executeBlock: getIt(), channel: getIt()));
  getIt.registerFactory(() => PinBloc(enforce: getIt()));
}
```

`main.dart` calls `setupDependencies()`, then provides app-wide BLoCs via `MultiBlocProvider` and hands routing to `go_router`.

---

## 8. Routing (go_router)

The original used a 23-entry `NoScrollScreen` enum with a `bottomNav` flag per screen, driven imperatively by the ViewModel's `currentScreenState`. We replace that with **declarative `go_router`** routes plus a `redirect` that mirrors the original's launch gating (onboarding → permissions → PIN gate → dashboard).

```dart
// lib/config/router.dart  (blueprint sketch — illustrative)
final router = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) {
    final appState = getIt<AppGateCubit>().state;     // onboarded? perms? pin-locked?
    if (!appState.onboarded)            return '/onboarding';
    if (!appState.accessibilityGranted) return '/permission/accessibility';
    if (!appState.overlayAndUsageGranted) return '/permission/system';
    if (appState.pinGateRequired)       return '/pin-lock';
    return null;                                       // proceed
  },
  routes: [
    GoRoute(path: '/splash',     builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    ShellRoute(                                        // bottom-nav shell == bottomNav=true screens
      builder: (_, __, child) => DashboardShell(child: child),
      routes: [
        GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/apps',      builder: (_, __) => const AppBlockerScreen()),
        GoRoute(path: '/web',       builder: (_, __) => const WebBlocklistScreen()),
        GoRoute(path: '/settings',  builder: (_, __) => const SettingsScreen()),
      ],
    ),
    GoRoute(path: '/permission/accessibility', builder: (_, __) => const AccessibilityPermissionScreen()),
    GoRoute(path: '/permission/system',        builder: (_, __) => const SystemPermissionScreen()),
    GoRoute(path: '/pin-lock',  builder: (_, __) => const PinLockScreen()),
    GoRoute(path: '/premium',   builder: (_, __) => const PremiumScreen()),
    GoRoute(path: '/pause',     builder: (_, __) => const PauseCountdownScreen()),
  ],
);
```

Deep links (install-referrer offers in the original: `aff`, `promo_campaign`, `coupon_code`, `offer_type`) route to `/premium` via go_router's URL handling. *(Launch gating verified in `HomeActivity`/`HomeViewModel` `onResume` permission-check sequence and `checkPinLockOnLaunch`.)*

---

## 9. Cross-platform reality (Android vs iOS)

**Android** is the target and supports the whole feature set: AccessibilityService gives in-app, real-time, content-level detection of reels and the OS hooks (`performGlobalAction`, `ActivityManager`, `DevicePolicyManager`, `WindowManager` overlays, foreground service, boot receiver, device admin) needed to act on it.

**iOS has no equivalent.** There is no public API to read another app's view hierarchy, detect "this view is a reel," press Back in another app, kill another app, or draw a system overlay over another app. Apple's nearest tools are **Family Controls / DeviceActivity / ManagedSettings (Screen Time)** — built for *parental control*, requiring the Family Controls entitlement, and only able to **shield/limit whole apps or categories on a schedule or time budget**, not detect or block short-form content *inside* an app. So on iOS the realistic product is a much weaker "block/limit the whole TikTok/Instagram app" via ManagedSettings shields — marked **❌** for every detection/in-app-blocking row above. Recommendation: ship **Android-first**; treat iOS as a separate, reduced FamilyControls-based app or defer it.

---

**Source evidence:** `service/accessibility/NoScrollAccessibilityService.java`, `service/accessibility/data/NoScrollServiceModel.java`, `service/accessibility/data/NoScrollAccessibilityRepository.java`, `service/accessibility/processors/detectors/LegacyDetector.java`, `service/helpers/AccessibilityServiceHelper.java`, `activities/home/HomeActivity.java`, `activities/home/viewmodel/home/HomeViewModel.java`, `res/xml/site_manager_service.xml`, `res/raw/platforms_config.json`, `res/raw/initial_config.json`, `AndroidManifest.xml`; cached analyses `onboarding-permissions-shell.json`, `accessibility-core.json`, `service-state-and-session.json`; synthesis `synth_flutterPlan.md`, `synth_flows.md`.

---

## Related docs

- `02-data-driven-config.md` — `platforms_config.json` schema, detectors, enums, remote sync
- `03-onboarding-and-permissions.md` — staged permission flow, manufacturer instructions
- `04-platform-channels.md` — exact Method/EventChannel contracts (Dart + Kotlin)
- `05-detection-engine.md` — LegacyDetector stages, traversal, web URL parsing
- `06-block-actions.md` — PRESS_BACK / KILL_APP / LOCK_SCREEN, debounce/rate-limit constants
- `07-plans-pause-curious.md` — PlansEnum, pause & curious phase machines, countdown UI
- `08-web-blocker.md` — domain/exact/wildcard matching, restriction durations
- `09-app-blocker-and-pin.md` — per-app sessions, PIN types, OTP recovery, lockouts
- `10-daily-limit-and-scheduler.md` — quota tracking, midnight reset, focus mode
- `11-persistence.md` — secure storage + hive + drift mapping of DataStore keys
- `12-networking-and-config-sync.md` — REST endpoints, caching, fallbacks
- `13-monetization-analytics-notifications.md` — billing, ads, analytics, notifications
- `14-native-android-service.md` — service lifecycle, foreground notification, resilience, device-admin
