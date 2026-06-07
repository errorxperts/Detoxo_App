# Onboarding & Permission Funnel

This document is the blueprint for the **first-run experience** of the Flutter short-form content blocker: the intro/value-prop screens, the plan picker, and — most importantly — the **multi-permission funnel** that has to be cleared before the blocker can actually work. Unlike a normal app, a content blocker is *useless without a wall of OS-level grants* (Accessibility, Overlay, Usage Access, Notifications, battery-optimization exemption, optionally Device Admin). This doc maps each grant to its exact Android check + intent action (verified from the decompiled source), maps it to a Flutter package or a `⚠️ MethodChannel`, and gives a `flutter_bloc` + Clean Architecture design for a `PermissionBloc` plus a `go_router` redirect gate. Manufacturer-specific accessibility instructions (15 brands) are reproduced as data, not code.

> **Legend** — ✅ a pub.dev package fully handles it · ⚠️ needs a native MethodChannel/EventChannel (no adequate package) · ❌ not possible on iOS.

---

## 1. The funnel at a glance

The original is a single `HomeActivity` hosting Jetpack Compose, driven by `HomeViewModel` which exposes `currentScreenState` (a `NoScrollScreen` enum of 23 screens) and re-runs all permission checks on **every `onResume`**. Our Flutter port keeps the same idea: a router that *redirects* based on a reactive permission/onboarding state, and a re-check whenever the app returns to the foreground.

```
 App launch
   │
   ▼
[ Splash ] ─► is onboarded? ──no──► [ Intro / value-prop carousel ]
   │                                          │
   │ yes                                      ▼
   │                                  [ Plan picker (BLOCK_ALL / CURIOUS / ONE_REEL) ]
   │                                          │  "Continue" / "Skip"
   │                                          ▼  mark onboarded + (Android13+) ask notifications
   ▼                                          │
[ Permission gate ] ◄───────────────────────┘
   │   each grant missing -> dedicated screen, re-checked on resume
   ├─► Accessibility   (mandatory, dismissible=false)
   ├─► Overlay         (mandatory)
   ├─► Usage Access    (mandatory)
   ├─► Notifications    (soft ask, Android 13+)
   ├─► Battery exempt   (soft ask, "aggressive" brands push harder)
   └─► Device Admin     (optional, only if user enables hard-lock)
   │   all mandatory granted
   ▼
[ Optional PIN setup ] ─► [ Dashboard ]
```

**Source evidence (high level):** `activities/home/HomeActivity.java`, `activities/home/viewmodel/home/HomeViewModel.java` (`checkMultiPermissions`, `navigateToAccessibilityPermission`, `checkPinLockOnLaunch`, `onResume` permission sweep), `activities/home/compose/onboarding/helpers/OnboardingImpl.java` (`skipOnboarding`), `resources/res/raw/initial_config.json`.

---

## 2. Onboarding (pre-permission) flow

### 2.1 Screens

| Step | Screen | Content | Notes |
|------|--------|---------|-------|
| 1 | Intro carousel | App value prop ("Stop doom-scrolling reels/shorts"), how-it-works | Original drives onboarding videos from `initial_config.json > videoConfig` (`PLAN_SELECTION_VID`, `CONFIG_ACCESS_VID`, `CONFIG_CURIOUS_VID`, `STRESSED_DEVICE`) — YouTube IDs shown as explainer clips. |
| 2 | Plan picker | Choose a blocking **plan** | State held in `OnboardingState { activeDetectionPlan: PlansEnum }`. Selectable: `BLOCK_ALL`, `CURIOUS`, `ONE_REEL` (the 4th, `PAUSED`, is a runtime state, not an onboarding choice). See `08-blocking-modes.md` for plan semantics. |
| 3 | Finish | "Continue" / "Skip" | Both call the same completion path. |

### 2.2 Completion logic — verified from `OnboardingImpl.skipOnboarding`

The original `skipOnboarding()` does exactly three things, in order:

1. Set in-memory `_isUserOnboardedValue = true`.
2. **If Android 13+ (API 33)**, request the notification permission (`requestNotificationPermissionIfEligible`) — onboarding is where the runtime `POST_NOTIFICATIONS` prompt is first triggered.
3. Persist `isUserOnboarded = true` to DataStore, then navigate to Dashboard.

> Key insight: **onboarding completion is decoupled from permission grants.** Finishing onboarding only flips a persisted boolean; it does *not* require any OS permission. The permission wall is enforced afterward by the resume-time sweep + router redirect (Section 4). Replicate this — do not block the "Continue" button on grants.

**Flutter sketch — onboarding completion use case**

```dart
// domain/usecases/complete_onboarding.dart
class CompleteOnboarding {
  CompleteOnboarding(this._onboardingRepo, this._permissionRepo);
  final OnboardingRepository _onboardingRepo;
  final PermissionRepository _permissionRepo;

  /// Mirrors skipOnboarding(): persist flag, then (Android 13+) ask notifications.
  Future<void> call({required BlockingPlan selectedPlan}) async {
    await _onboardingRepo.setOnboarded(true);
    await _onboardingRepo.setActivePlan(selectedPlan);
    if (await _permissionRepo.isNotificationRuntimePermissionEligible()) {
      await _permissionRepo.requestNotifications(); // permission_handler
    }
  }
}
```

```dart
// domain/entities/blocking_plan.dart  (own clean names; ordinals mirror PlansEnum)
enum BlockingPlan { blockAll, curious, oneReel, paused }
```

| Mechanism | Mapping |
|-----------|---------|
| Persist `isUserOnboarded` | ✅ `shared_preferences` (simple flag) — original uses Jetpack DataStore. |
| Notification runtime ask | ✅ `permission_handler` (`Permission.notification.request()`), gated to Android 13+ via `device_info_plus`. |
| Explainer videos | ✅ `youtube_player_flutter` / `youtube_player_iframe` if you keep the `videoConfig` IDs. |
| iOS | Onboarding screens are pure Flutter — fully portable. No native gate needed here. |

---

## 3. The permission matrix (the core of this doc)

Every row below is **verified** against the decompiled source: the exact Android API used to *check* status and the exact intent action used to *open* the relevant settings page were grepped from the codebase.

| # | Permission | Check API (verified) | Open intent action (verified) | Mandatory? | Flutter mapping |
|---|-----------|----------------------|-------------------------------|------------|-----------------|
| 1 | **Accessibility Service** | `AccessibilityManager` enabled-services list **and** `Settings.Secure` `enabled_accessibility_services` contains our service component | `android.settings.ACCESSIBILITY_SETTINGS` | ✅ yes (`dismissible=false`) | ⚠️ native channel (or `flutter_accessibility_service` to check/enable + receive events) |
| 2 | **Overlay / `SYSTEM_ALERT_WINDOW`** | `Settings.canDrawOverlays(context)` | `android.settings.action.MANAGE_OVERLAY_PERMISSION` (`package:` URI) | ✅ yes | ⚠️ status check via channel or `flutter_overlay_window`; ✅ open via `app_settings` |
| 3 | **Usage Access** | `AppOpsManager.checkOpNoThrow("android:get_usage_stats", uid, pkg) == MODE_ALLOWED(0)` | `android.settings.USAGE_ACCESS_SETTINGS` | ✅ yes | ⚠️ status check via channel; ✅ open via `app_settings` |
| 4 | **Notifications** | runtime `POST_NOTIFICATIONS` (API 33+) | runtime dialog, fallback `android.settings.APPLICATION_DETAILS_SETTINGS` | ⚠️ soft | ✅ `permission_handler` |
| 5 | **Battery optimization exemption** | `PowerManager.isIgnoringBatteryOptimizations(pkg)` | `android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | ⚠️ soft (hard-pushed on aggressive brands) | ⚠️ status + request via channel |
| 6 | **Device Admin** (optional) | `DevicePolicyManager.isAdminActive(adminComponent)` | `DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN` | ❎ optional | ⚠️ native channel (no package) — see `12-device-admin-lock.md` |

> Verified constants grepped from source: `android.settings.ACCESSIBILITY_SETTINGS`, `android.settings.action.MANAGE_OVERLAY_PERMISSION`, `android.settings.USAGE_ACCESS_SETTINGS`, `android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `android.settings.APPLICATION_DETAILS_SETTINGS`, AppOps string `get_usage_stats`, `canDrawOverlays`, `isIgnoringBatteryOptimizations`, `POST_NOTIFICATIONS`.

### 3.1 Why so many of these are `⚠️ native`

`permission_handler` does **not** cover Accessibility-Service-enabled, Usage-Access (`get_usage_stats`), overlay *status*, or battery-optimization *status* reliably across the row above. The original checks them with first-party Android APIs (`AppOpsManager`, `Settings.canDrawOverlays`, `PowerManager`, `Settings.Secure`). You need a small Kotlin `PermissionStatusChannel` exposing four boolean getters + the corresponding "open settings" launches. `app_settings` can *open* most pages but cannot *read* the granted state of Accessibility/Usage/Battery — hence the channel.

**MethodChannel contract (illustrative)**

```dart
// data/datasources/native/permission_channel.dart
class PermissionChannel {
  static const _m = MethodChannel('app/permissions');

  Future<bool> isAccessibilityEnabled()       => _m.invoke('accessibility.isEnabled');
  Future<bool> isOverlayGranted()             => _m.invoke('overlay.isGranted');
  Future<bool> isUsageAccessGranted()         => _m.invoke('usage.isGranted');
  Future<bool> isBatteryOptimizationIgnored() => _m.invoke('battery.isIgnored');
  Future<bool> isDeviceAdminActive()          => _m.invoke('admin.isActive');

  Future<void> openAccessibilitySettings()    => _m.invoke('accessibility.open');
  Future<void> openOverlaySettings()          => _m.invoke('overlay.open');
  Future<void> openUsageAccessSettings()      => _m.invoke('usage.open');
  Future<void> requestIgnoreBatteryOpt()      => _m.invoke('battery.request');
  Future<void> openDeviceAdmin()              => _m.invoke('admin.open');
}

extension on MethodChannel {
  Future<bool> invoke(String name) async => (await invokeMethod<bool>(name)) ?? false;
}
```

```kotlin
// android/.../PermissionStatusPlugin.kt  (illustrative — Stage refs verified)
"usage.isGranted" -> {
    val ops = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
    val mode = ops.checkOpNoThrow(
        AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
    result.success(mode == AppOpsManager.MODE_ALLOWED)
}
"overlay.isGranted" -> result.success(Settings.canDrawOverlays(ctx))
"battery.isIgnored" -> {
    val pm = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
    result.success(pm.isIgnoringBatteryOptimizations(ctx.packageName))
}
"accessibility.open" -> ctx.startActivity(
    Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
```

### 3.2 Accessibility-enabled check (the subtle one)

The original verifies the accessibility service two ways (`AccessibilityServiceHelper.isAccessibilityServiceEnabled` + an `isServiceGrantedButNotRunning` variant). The robust native check is: read `Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES`, split on `:`, and look for `"<packageName>/<fully-qualified-service-class>"`. Relying on `AccessibilityManager.getEnabledAccessibilityServiceList` alone misses the "granted but process not yet running" edge case — which is exactly why the original distinguishes them (and offers a **restart** flow, see §5.2). `flutter_accessibility_service` exposes `isAccessibilityPermissionEnabled()` / `requestAccessibilityPermission()` and is adequate for the happy path; keep the Secure-Settings string check in native as the source of truth.

> The original cross-app **status broadcast** is `com.newswarajya.noswipe.reelshortblocker.ACCESSIBILITY_SERVICE_STATUS_CHANGED` with extra `extra_accessibility_service_enabled`. In Flutter, surface the same signal as an **EventChannel** stream so the gate re-evaluates instantly when the user flips the toggle (instead of only on resume). See `04-accessibility-service.md`.

---

## 4. PermissionBloc + status model

### 4.1 Per-permission status entity

```dart
// domain/entities/app_permission.dart
enum AppPermission {
  accessibility,
  overlay,
  usageAccess,
  notifications,
  batteryOptimization,
  deviceAdmin,
}

enum PermissionState { unknown, granted, denied, notApplicable }

class PermissionStatus {
  const PermissionStatus({
    required this.permission,
    required this.state,
    required this.mandatory,
  });
  final AppPermission permission;
  final PermissionState state;
  final bool mandatory; // accessibility/overlay/usage = true; others = false
  bool get isBlocking => mandatory && state != PermissionState.granted;
}

class PermissionSnapshot {
  const PermissionSnapshot(this.statuses);
  final Map<AppPermission, PermissionStatus> statuses;

  bool get allMandatoryGranted =>
      statuses.values.where((s) => s.mandatory).every((s) => s.state == PermissionState.granted);

  /// First mandatory permission still missing — drives which screen to show.
  AppPermission? get nextBlocking =>
      statuses.values.firstWhereOrNull((s) => s.isBlocking)?.permission;
}
```

This mirrors the original `PermissionRequestItem { id, iconRes, title, description, ctaText = "Grant Permission", isGranted }` and `MultiPermissionUiState { title, description, permissions, allGranted }`. The original groups **overlay + usage** into one "multi-permission" screen and gates navigation to PIN setup on `allGranted`; the snapshot's `allMandatoryGranted` reproduces that gate (and folds in accessibility, which the original handled on its own screen).

### 4.2 Bloc

```dart
// presentation/bloc/permission/permission_event.dart
sealed class PermissionEvent {}
class PermissionRefreshRequested extends PermissionEvent {}      // call on resume + on stream tick
class PermissionGrantRequested extends PermissionEvent {         // user tapped "Grant Permission"
  PermissionGrantRequested(this.permission);
  final AppPermission permission;
}
class AccessibilityStatusPushed extends PermissionEvent {        // from EventChannel broadcast
  AccessibilityStatusPushed(this.enabled);
  final bool enabled;
}
```

```dart
// presentation/bloc/permission/permission_state.dart
class PermissionBlocState {
  const PermissionBlocState({required this.snapshot, this.requesting});
  final PermissionSnapshot snapshot;
  final AppPermission? requesting;
  PermissionBlocState copyWith({PermissionSnapshot? snapshot, AppPermission? requesting}) =>
      PermissionBlocState(snapshot: snapshot ?? this.snapshot, requesting: requesting);
}
```

```dart
// presentation/bloc/permission/permission_bloc.dart
class PermissionBloc extends Bloc<PermissionEvent, PermissionBlocState> {
  PermissionBloc(this._check, this._request, this._accessibilityStream)
      : super(const PermissionBlocState(snapshot: PermissionSnapshot({}))) {
    on<PermissionRefreshRequested>((e, emit) async {
      emit(state.copyWith(snapshot: await _check())); // CheckAllPermissions usecase
    });
    on<PermissionGrantRequested>((e, emit) async {
      emit(state.copyWith(requesting: e.permission));
      await _request(e.permission);                   // OpenPermissionSettings usecase
      // No await of result: Android settings pages don't return a value.
      // Re-check happens on the next PermissionRefreshRequested (resume / stream).
    });
    on<AccessibilityStatusPushed>((e, emit) async {
      emit(state.copyWith(snapshot: await _check()));
    });
    _sub = _accessibilityStream.listen((_) => add(PermissionRefreshRequested()));
  }
  final CheckAllPermissions _check;
  final OpenPermissionSettings _request;
  final Stream<bool> _accessibilityStream;
  late final StreamSubscription _sub;
  @override Future<void> close() { _sub.cancel(); return super.close(); }
}
```

### 4.3 The resume sweep

The original re-checks **everything on `onResume`** (`checkMultiPermissions`, accessibility status, overlay, usage, battery, device-admin, plus PIN-on-launch). Reproduce with a lifecycle observer that fires `PermissionRefreshRequested` on `AppLifecycleState.resumed`:

```dart
// presentation/widgets/resume_permission_refresher.dart
class _State extends State<ResumePermissionRefresher> with WidgetsBindingObserver {
  @override void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      context.read<PermissionBloc>().add(PermissionRefreshRequested());
    }
  }
  // ... initState/dispose add/removeObserver, build returns widget.child
}
```

---

## 5. Accessibility screen — manufacturer-specific instructions

This is the highest-friction grant, so the original ships **15 hardcoded brand variants** of step-by-step instructions, keyed by `Build.BRAND` (case-insensitive), each with a brand image URL and an `aggressiveBatteryOptimizer` flag. **Verified verbatim in `compose/accessibility/data/AccessibilityInstructions.java`.**

### 5.1 The data (verified)

Model: `ManufacturerInstruction { brand, steps:List<String>, imageUrl, aggressiveBatteryOptimizer }`. Lookup `getForBrand(brand, isForRestart)` does case-insensitive `equalsIgnoreCase` match; falls back to the `"Default"` entry; if not found at all, `genericSteps` is used.

| Brand (`Build.BRAND`) | `aggressiveBatteryOptimizer` | Steps (verbatim) |
|-----------------------|:---------------------------:|------------------|
| Samsung | false | Grant Permission ▸ "Installed Apps" ▸ NoScroll ▸ Turn On the switch |
| Xiaomi | **true** | Grant Permission ▸ "Downloaded Apps" ▸ NoScroll ▸ Turn On the switch |
| Oppo | **true** | Grant Permission ▸ "System Settings" > "Accessibility" ▸ "Downloaded Apps" ▸ NoScroll + Turn On |
| Vivo | **true** | Grant Permission ▸ "Downloaded Apps" ▸ NoScroll ▸ Turn On the switch |
| OnePlus | false | Grant Permission ▸ "Downloaded Apps" ▸ NoScroll ▸ Turn On the switch |
| Realme | false | Grant Permission ▸ "Downloaded Apps" ▸ NoScroll ▸ Turn On the switch |
| Google | false | Grant Permission ▸ scroll to NoScroll ▸ "Use NoScroll" On ▸ "Allow" to confirm |
| Motorola | false | Grant Permission ▸ scroll to NoScroll ▸ Turn On ▸ "Allow" to confirm |
| Huawei | **true** | Grant Permission ▸ "Installed/Downloaded Services" ▸ NoScroll ▸ Turn On |
| Honor | false | Grant Permission ▸ "Installed Services" ▸ NoScroll ▸ Turn On |
| Poco | **true** | Grant Permission ▸ "Downloaded Apps" ▸ NoScroll ▸ Turn On the switch |
| Nothing | false | Grant Permission ▸ scroll to NoScroll ▸ Turn On ▸ "Allow" to confirm |
| Asus | **true** | Grant Permission ▸ "Downloaded Services" ▸ NoScroll ▸ Turn On |
| Infinix | **true** | Grant Permission ▸ "Downloaded Apps" or "Installed Services" ▸ NoScroll ▸ Turn On |
| Default | false | Grant Permission ▸ find NoScroll in list ▸ Turn On accessibility switch ▸ "Allow" if prompted |

Generic fallback (`genericSteps`): "Tap 'Grant Permission' below" ▸ "Select 'Downloaded Apps' or 'Installed Services'" ▸ "Find 'NoScroll' in the list" ▸ "Tap on it and turn on the switch".

Image URLs follow the pattern `https://curizic.com/NoScroll/icons/instructions/<brand>_accessibility.png` (Samsung uses `ic_samsung.png`).

> **Insight — the `aggressiveBatteryOptimizer` flag.** Brands flagged `true` (Xiaomi, Oppo, Vivo, Huawei, Poco, Asus, Infinix) kill background services aggressively and often need *autostart* / *no-restriction* settings beyond plain battery-opt exemption. Use this flag to also surface an autostart hint and push the battery-optimization step harder on those devices. (Original surfaces it; the autostart deep-link behaviour beyond the flag is **inferred**.)

### 5.2 Restart variant (verified)

`getForBrand(brand, isForRestart=true)` rewrites any step containing "Turn On" / "Turn On the switch" / "Turn On 'Use NoScroll'" / "Turn On the accessibility switch" into **"Turn Off the switch and turn On again"**. This is the recovery flow for a service that was granted but hung/crashed (`isServiceGrantedButNotRunning`). Reproduce this string transform exactly.

### 5.3 Flutter port

Ship the table above as a Dart asset/const map (own clean names), brand-matched via `device_info_plus` (`AndroidDeviceInfo.brand`). Keep it data-driven so it can later be overridden by remote config, exactly like the original (which also fetches `warningMessages` from `initial_config.json`).

```dart
// data/models/manufacturer_instruction.dart
class ManufacturerInstruction {
  const ManufacturerInstruction({
    required this.brand,
    required this.steps,
    required this.imageUrl,
    required this.aggressiveBatteryOptimizer,
  });
  final String brand;
  final List<String> steps;
  final String imageUrl;
  final bool aggressiveBatteryOptimizer;

  /// Verified transform: restart flow rewrites the "Turn On" step.
  ManufacturerInstruction asRestart() => ManufacturerInstruction(
        brand: brand,
        imageUrl: imageUrl,
        aggressiveBatteryOptimizer: aggressiveBatteryOptimizer,
        steps: [
          for (final s in steps)
            s.toLowerCase().contains('turn on')
                ? 'Turn Off the switch and turn On again'
                : s,
        ],
      );
}
```

```dart
// domain/usecases/get_accessibility_instructions.dart
class GetAccessibilityInstructions {
  GetAccessibilityInstructions(this._deviceInfo, this._repo);
  final DeviceInfoSource _deviceInfo;
  final InstructionRepository _repo; // const table now, remote-config later

  Future<ManufacturerInstruction> call({bool forRestart = false}) async {
    final brand = await _deviceInfo.brand(); // device_info_plus
    final m = _repo.forBrand(brand) ?? _repo.defaultInstruction();
    return forRestart ? m.asRestart() : m;
  }
}
```

| Mechanism | Mapping |
|-----------|---------|
| `Build.BRAND` | ✅ `device_info_plus` (`AndroidDeviceInfo.brand` / `.manufacturer`). |
| Brand image | ✅ `cached_network_image` (URLs above). |
| Open accessibility settings | ⚠️ native (`ACTION_ACCESSIBILITY_SETTINGS`) or `flutter_accessibility_service.requestAccessibilityPermission()`; ✅ `app_settings` can open it too. |
| Re-evaluate after return | EventChannel broadcast (§3.2) + resume sweep (§4.3). |

---

## 6. The overlay + usage "multi-permission" screen (verified)

`checkMultiPermissions()` (verified algorithm):

1. Read overlay status via `Settings.canDrawOverlays()`.
2. Read usage status via `AppOpsManager.checkOpNoThrow("android:get_usage_stats")`.
3. Build a list of `PermissionRequestItem` (`ctaText = "Grant Permission"`) for overlay + usage with per-item `isGranted`.
4. Set `MultiPermissionUiState.allGranted = overlay && usage`.
5. **If `allGranted` and the current screen is `MultiPermissionRequest`, navigate to `PINSettings`.**

Per-item CTA opens the matching intent: overlay ▸ `MANAGE_OVERLAY_PERMISSION`, usage ▸ `USAGE_ACCESS_SETTINGS`. After the user returns, `checkMultiPermissions()` re-runs (resume sweep) and advances when both are green. Reproduce with the snapshot's `allMandatoryGranted` and the router redirect (§7).

---

## 7. Gating router (`go_router` redirect)

The original's `currentScreenState` + on-resume redirect logic becomes a `go_router` `redirect`. The redirect is **pure** over `(isOnboarded, PermissionSnapshot, pinConfigured)` — it never mutates, it only chooses the next route, so it re-evaluates correctly every time the `PermissionBloc` emits.

```dart
// presentation/router/app_router.dart
GoRouter buildRouter(PermissionBloc perm, OnboardingCubit onboard) {
  return GoRouter(
    refreshListenable: GoRouterRefreshStream(
      Rx.merge([perm.stream, onboard.stream]),
    ),
    redirect: (context, state) {
      final onboarded = onboard.state.isOnboarded;
      final snap = perm.state.snapshot;
      final loc = state.matchedLocation;

      if (!onboarded) {
        return loc.startsWith('/onboarding') ? null : '/onboarding';
      }
      // Onboarded but a mandatory grant is missing -> route to that grant.
      final blocking = snap.nextBlocking; // accessibility | overlay | usageAccess
      if (blocking != null) {
        final target = switch (blocking) {
          AppPermission.accessibility => '/grant/accessibility',
          AppPermission.overlay       => '/grant/overlay',
          AppPermission.usageAccess   => '/grant/usage',
          _ => '/grant/usage',
        };
        return loc == target ? null : target;
      }
      // All mandatory granted: bounce off any grant/onboarding routes to home.
      if (loc.startsWith('/grant') || loc.startsWith('/onboarding')) return '/';
      return null;
    },
    routes: [ /* /onboarding, /grant/accessibility, /grant/overlay, /grant/usage, / (dashboard), /pin-setup ... */ ],
  );
}
```

> The original also runs `checkPinLockOnLaunch()` on resume — if a PIN is configured for the `NOSCROLL_APP` restriction it shows a lock before the dashboard. That gate lives in `11-pin-lock.md`; the router above hands off to `/pin-setup` (first-run) and the PIN-lock overlay (returning users) once mandatory grants are green.

---

## 8. Remote-config-driven warnings (verified)

`initial_config.json > warningMessages` carries two non-dismissible, server-controlled warnings whose `ctaAction` maps to a permission flow:

| `notificationId` | `ctaAction` | `cta` | `dismissible` | Routes to |
|------------------|-------------|-------|:-------------:|-----------|
| `/noscroll/accessibility` | `ACCESSIBILITY` | "Turn On" | false | Accessibility grant flow |
| `/noscroll/battery` | `BATTERY_OPTIMIZATION` | "Open Settings" | false | Battery-opt exemption flow |

And `initial_config.json > inappNotification` carries a soft notification-permission nudge: `notificationId = /noscroll/notification_permission`, `ctaAction = "NOTIFICATION"`, `cta = "Allow"`, `dismissible = true`. The full `ctaAction` vocabulary observed is `URL`, `NOTIFICATION`, `RATING`, `ACCESSIBILITY`, `BATTERY_OPTIMIZATION` (plus `UPDATE`/`GOOGLE_PLAY` referenced in analysis). Model these as a small enum so the same in-app-message component can re-enter the permission funnel post-onboarding.

```dart
enum CtaAction { url, notification, rating, accessibility, batteryOptimization, update, googlePlay }
```

Mapping: fetch config with `dio` + cache (`shared_preferences`/`hive`); render banners with your design system; route `ACCESSIBILITY`/`BATTERY_OPTIMIZATION`/`NOTIFICATION` CTAs back into the same use cases used by the gate. See `15-remote-config.md`.

---

## 9. iOS reality check

| Permission | iOS equivalent |
|-----------|----------------|
| Accessibility Service | ❌ No equivalent. The only sanctioned mechanism is **`FamilyControls` + `ManagedSettings` + `DeviceActivity`** (Screen Time), which is a *restricted entitlement* (parental-control framing) — you cannot read other apps' view trees or press Back. |
| Overlay (`SYSTEM_ALERT_WINDOW`) | ❌ No arbitrary system overlays. |
| Usage Access | ⚠️ Aggregate, privacy-preserving usage only via `DeviceActivity` reports — not real-time per-app. |
| Notifications | ✅ `permission_handler` (`UNUserNotificationCenter`). |
| Battery optimization | ❌ Not user-exposed on iOS. |
| Device Admin | ❌ No consumer equivalent (MDM only). |

**iOS onboarding** therefore replaces the permission wall with a single **FamilyControls authorization** request (`AuthorizationCenter.shared.requestAuthorization(for: .individual)`), after which blocking is enforced by `ManagedSettingsStore` shields rather than accessibility traversal. The Flutter onboarding/plan-picker screens stay identical; only the "grant" screens diverge. See `16-ios-familycontrols.md`.

---

## Source evidence

- `sources/com/newswarajya/noswipe/reelshortblocker/activities/home/HomeActivity.java` — lifecycle, resume permission sweep, accessibility status receiver registration.
- `sources/com/newswarajya/noswipe/reelshortblocker/activities/home/viewmodel/home/HomeViewModel.java` — `checkMultiPermissions`, `navigateToAccessibilityPermission`, `checkPinLockOnLaunch`, on-resume checks (overlay/usage/battery/device-admin).
- `sources/com/newswarajya/noswipe/reelshortblocker/activities/home/compose/onboarding/helpers/OnboardingImpl.java` — `skipOnboarding` (onboarded flag + Android-13 notification ask + navigate to Dashboard).
- `sources/com/newswarajya/noswipe/reelshortblocker/activities/home/compose/accessibility/data/AccessibilityInstructions.java` — **15 brand instruction sets + `genericSteps` + `getForBrand` restart transform (verbatim)**.
- `sources/com/newswarajya/noswipe/reelshortblocker/activities/home/compose/accessibility/data/ManufacturerInstruction.java` — `{ brand, steps, imageUrl, aggressiveBatteryOptimizer }`.
- `sources/com/newswarajya/noswipe/reelshortblocker/activities/home/compose/multipermission/data/{MultiPermissionUiState,PermissionRequestItem}.java` — overlay+usage screen model, CTA `"Grant Permission"`.
- `sources/com/newswarajya/noswipe/reelshortblocker/activities/home/compose/onboarding/data/OnboardingState.java` — `activeDetectionPlan: PlansEnum`.
- `resources/res/raw/initial_config.json` — `versionAvailability`, `inappNotification`, `warningMessages` (`ACCESSIBILITY` / `BATTERY_OPTIMIZATION` / `NOTIFICATION` CTAs), `videoConfig`, `featuresAvailability`.
- Grepped verified constants: `android.settings.ACCESSIBILITY_SETTINGS`, `android.settings.action.MANAGE_OVERLAY_PERMISSION`, `android.settings.USAGE_ACCESS_SETTINGS`, `android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `android.settings.APPLICATION_DETAILS_SETTINGS`, `get_usage_stats`, `canDrawOverlays`, `isIgnoringBatteryOptimizations`, `POST_NOTIFICATIONS`, broadcast `…ACCESSIBILITY_SERVICE_STATUS_CHANGED` extra `extra_accessibility_service_enabled`.

## Related docs

- `04-accessibility-service.md` — the AccessibilityService itself, status broadcast/EventChannel.
- `08-blocking-modes.md` — `PlansEnum` plan semantics chosen in the plan picker.
- `11-pin-lock.md` — PIN setup / `checkPinLockOnLaunch` gate after permissions.
- `12-device-admin-lock.md` — optional Device Admin permission.
- `15-remote-config.md` — `initial_config.json` parsing, warnings, in-app notifications.
- `16-ios-familycontrols.md` — iOS FamilyControls/Screen Time alternative to this funnel.
