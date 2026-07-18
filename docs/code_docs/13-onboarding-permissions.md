# Onboarding & Permission Funnel

How a first-run Detoxo user gets from cold launch to a working blocker: the value-prop onboarding intro, the guided runtime-permission funnel, and the exact splash-screen gate that decides which of those (if any) to show.

The whole flow is driven **imperatively from the splash screen** after app state loads — there is no `go_router` `redirect`. The router's `initialLocation` is always `/` (splash); the splash then `context.go(...)`s to the right destination.

---

## 1. The splash gate (source of truth)

`lib/app/splash_screen.dart` boots the app and routes. On the first post-frame callback it runs `_bootstrap()`:

1. **Load state in parallel** (`Future.wait`):
   - `SettingsCubit.bootstrap()` — app settings (incl. the `onboarded` flag)
   - `TargetsCubit.load()` — installed blockable apps/surfaces
   - `PermissionsCubit.refresh()` — current permission statuses
   - `PinCubit.load()` — PIN configuration
2. **First-run seeding of the enabled set.** If `settings.state.enabledPlatformIds` is empty, it seeds it from every target that is both `defaultEnabled` and `isInstalled` (via `settings.setEnabledPlatforms(...)`). Apps the user doesn't have are never pre-enabled.
3. **Content-counter widget refresh** (fire-and-forget, never blocks routing): `_refreshReelCounterWidget()` reads `ContentCounterRepository.current()` and pushes it to the home-screen widget via `HomeWidgetRepository.pushSnapshot(...)`. The reel counter runs natively and is on by default, independent of blocking.

Then the gate, **in this exact order**:

| # | Condition | Route | Notes |
|---|-----------|-------|-------|
| 1 | `!settings.state.onboarded` | `Routes.onboarding` (`/onboarding`) | Haven't seen the intro yet |
| 2 | `pin.state.isConfigured && pin.state.guards(PinScope.app)` | `Routes.pinLock` (`/pin/lock`) | An **app-scope** PIN is set |
| 3 | `!permissions.allRequiredGranted` | `Routes.permissions` (`/permissions`) | Missing a required permission |
| 4 | (else) | `Routes.home` (`/home`) | Fully set up |

So the canonical funnel is **onboarding → PIN lock → permissions → home**. Each stage is checked only if the earlier ones passed; the first failing condition wins and returns.

Notes on the gate:

- **`onboarded`** is a boolean on `AppSettings` (`lib/features/blocking/shared/domain/entities/app_settings.dart`), persisted through the settings store.
- **PIN gate** uses `PinConfig.isConfigured` (`type != PinType.none`) **and** `guards(PinScope.app)` — i.e. only a PIN whose `scopes` set contains `PinScope.app` (wire `DETOXO_APP`) blocks the launch. A PIN scoped only to settings/plan-switch/etc. does **not** gate the splash. On a genuine first run no PIN exists, so this stage is skipped. (PIN mechanics — types, salted hashing, lockout ladder, biometrics, recovery — live in the access-protection docs; the splash only reads `PinCubit` state.)
- **Required-permission gate** uses `PermissionsCubit.allRequiredGranted` (see §3).
- The `unawaited(...)` widget refresh means a slow/absent native side can never stall the gate.

The `build()` method renders a branded splash (Detoxo logo, "Reclaim your attention", spinner) while `_bootstrap()` runs.

---

## 2. Onboarding intro (`onboarding` feature)

`lib/features/onboarding/` is a **presentation-only feature** — its public barrel (`onboarding.dart`) exports just `OnboardingScreen`; there is no data/ or domain/ layer.

`presentation/onboarding_screen.dart` is a 5-page horizontal `PageView` over the ambient gradient (`GlassScaffold`):

| Page | Accent | Title | Illustration / kind | Fallback icon |
|------|--------|-------|--------------|---------------|
| 0 (welcome) | `AppColors.seed` | "Welcome to Detoxo" | app logo image (`assets/images/detox_logo_no_bg.png`) | — |
| 1 | `AppColors.seed` | "Stop the doom-scroll" | Lottie `bow` | `motion_photos_off` |
| 2 | `AppColors.onbTeal` | "You stay in control" | Lottie `nightyNight` | `tune` |
| 3 (limit step) | `AppColors.onbTeal` | "How much do you scroll daily?" | **interactive drag dial** (`ScreenTimeDial`) | — |
| 4 | `AppColors.onbViolet` | "Build the habit" | Lottie `glasses` | `lock_clock` |

Copy is value-prop only (detecting Reels/Shorts/infinite feeds, choosing which apps to block, pausing with a mindful cooldown, daily limits + schedules + PIN lock) — **except page 3**, the one interactive step. Nothing else is requested or persisted per-page.

**The daily-limit dial (page 3, `_LimitStep`).** Instead of a Lottie slide, page 3 asks "How much do you scroll daily?" and presents an interactive **`ScreenTimeDial`** (`presentation/widgets/screen_time_dial.dart`) — a draggable 270° radial gauge (range **15 min – 5 h**, **15-minute** steps, default **90 min**) that visually mirrors the dashboard screen-time ring. Dragging (or tapping) the arc updates the value, which animates in the centre; it's a Semantics slider (increase/decrease step) for accessibility. The selection is held in local `_draftLimit` state (nothing is saved until finish) and seeds the dashboard's screen-time ring max. Because the dial owns its drag gestures, the `PageView` horizontal swipe is **suspended on this page** (`NeverScrollableScrollPhysics`) — Back/Next still navigate. If the user skips the step, `_finish()` falls back to the **90-minute** default.

UI mechanics:
- **Parallax:** each `_Illustration` drifts at 60px × page-delta relative to the swipe (`Transform.translate` driven by the `PageController`).
- **Lottie with graceful fallback:** illustrations render via `lottie_tgs`; on any load error `_Illustration._fallback()` draws the page's accent-tinted `fallbackIcon` instead, so a missing/broken asset never blanks the page.
- **Skip** (top-right `GhostButton`) — visible on pages 0–3, fades out (opacity 0, disabled) on the last page (index 4).
- **Back** (top-left `GhostButton`) — hidden (opacity 0, disabled) on page 0, visible from page 1 onward; steps back one page via `PageController.previousPage`. Gives a discoverable way back for screen-reader users, since TalkBack intercepts the `PageView` swipe.
- **Bottom bar** — animated dot indicator (active dot widens to 22px in the page accent; the dot row is wrapped in `Semantics(label: 'Page N of M')` so progress is announced) plus a full-width `PrimaryButton` labelled **"Next"** on pages 0–3 and **"Get started"** on the last page, tinted with the current page's accent.

**Finishing** (`_finish()`, reached by *Skip*, or by *Get started* on the last page via `_next()`):

```dart
final settings = sl<SettingsRepository>();
// Seed the dashboard ring's daily limit from the quick-pick (or 90 min default)
// through the app-wide cubit, so the dashboard reflects it live.
final dailyLimit = context.read<DailyLimitCubit>();
await settings.save((await settings.load()).copyWith(onboarded: true));
await dailyLimit.setLimit(_draftLimit ?? _defaultLimit);
if (mounted) context.go(Routes.permissions);
```

Three things to note:

1. It persists `onboarded: true` **directly through `SettingsRepository`** (resolved from `sl`), not through `SettingsCubit`. The flag is durable for the next launch's splash gate; the in-memory `SettingsCubit.state` is not updated here, which is harmless because…
2. …it navigates **straight to `/permissions`**, bypassing the splash re-check (and therefore the PIN gate — which is a no-op on first run anyway, since no PIN exists yet). On subsequent launches the splash gate takes over normally.
3. It **seeds the daily limit** through the **app-wide `DailyLimitCubit`** (`context.read<DailyLimitCubit>().setLimit(...)`, the quick-pick choice or the 90-minute default) — not a direct `DailyLimitRepository.save`, so the value re-emits to the dashboard's screen-time ring **live**. This is the value the ring reads as its max (the ring's fill comes from native usage time, not `DailyLimit.consumed`). See [07-daily-limit-scheduler.md](07-daily-limit-scheduler.md).

---

## 3. Permission funnel (`permissions` feature)

`lib/features/permissions/` is a full Clean-Architecture slice (domain / data / presentation). Its barrel (`permissions.dart`) exports only the domain entity + repository contract.

### 3.1 Domain model

`domain/entities/permission_status.dart`:

- **`AppPermission`** enum — one entry per permission, carrying a user-facing `label` and a `required` flag:

  | Enum | Label | Required |
  |------|-------|----------|
  | `accessibility` | "Accessibility" | **yes** |
  | `overlay` | "Display over apps" | **yes** |
  | `notifications` | "Notifications" | no |
  | `usageAccess` | "Usage access" | no |
  | `batteryOptimization` | "Unrestricted battery" | no |
  | `deviceAdmin` | "Uninstall protection" | no |

  Only **accessibility** and **overlay** are required — they are the minimum for the blocker to detect and to draw the block/PIN screen. Everything else is "recommended".

- **`PermissionStatus`** (`Equatable`) — `{ kind, state }` with `granted` (`state == PermissionState.granted`) and `permanentlyDenied` (`state == PermissionState.permanentlyDenied`) getters and `copyWith`.
- **`PermissionState`** (defined in `lib/features/blocking/shared/domain/entities/enums.dart`) — `{ granted, denied, permanentlyDenied, unknown }`. New statuses default to `unknown`. `permanentlyDenied` only arises for **notifications** — the one runtime permission the OS can mark "don't ask again"; the five settings-based permissions never reach it.

`domain/repositories/permission_repository.dart` — the contract:

```dart
abstract interface class PermissionRepository {
  Future<List<PermissionStatus>> statuses();
  Future<PermissionStatus> status(AppPermission permission);
  Future<void> request(AppPermission permission);
}
```

### 3.2 Data layer — how status/request map to the platform

`data/repositories/permission_repository_impl.dart` (`PermissionRepositoryImpl`, wraps `EngineChannel`).

Everything is gated on `PlatformCapabilities.usesAndroidPermissionFunnel` (Android-only, from `lib/core/platform/platform_capabilities.dart`):

- **Off Android:** `statuses()` returns `const []`. This is deliberate — an empty list makes `PermissionsCubit.allRequiredGranted` **vacuously true**, so the splash gate skips the permissions stage and routes straight to `/home` (the iOS "preview" build has no engine to permission). `status()` returns `denied`; `request()` is a no-op.

- **On Android**, `status(permission)` reads live state per kind:

  | Permission | Status check (`EngineChannel`) |
  |------------|-------------------------------|
  | `accessibility` | `isAccessibilityEnabled()` |
  | `overlay` | `canDrawOverlays()` |
  | `usageAccess` | `hasUsageAccess()` |
  | `batteryOptimization` | `isIgnoringBattery()` |
  | `deviceAdmin` | `isDeviceAdminActive()` |
  | `notifications` | `permission_handler` `Permission.notification.status` → `granted`, else `permanentlyDenied` when `isPermanentlyDenied` (don't-ask-again), else `denied` |

  `statuses()` iterates `AppPermission.values` in order and collects each `status(...)`.

- `request(permission)` triggers the grant path per kind:

  | Permission | Request action |
  |------------|----------------|
  | `accessibility` | `openAccessibilitySettings()` — opens the system Accessibility screen |
  | `overlay` | `requestOverlay()` — "Display over other apps" screen |
  | `usageAccess` | `openUsageAccess()` — Usage-access settings |
  | `batteryOptimization` | `requestIgnoreBattery()` — battery-exemption prompt |
  | `deviceAdmin` | `requestDeviceAdmin()` — device-admin activation prompt |
  | `notifications` | if `Permission.notification.isPermanentlyDenied` → `openAppSettings()`; else `Permission.notification.request()` — in-app runtime dialog |

  A plain `request()` no-ops once notifications is permanently denied (don't-ask-again), so the branch sends the user to the app's system settings screen instead, giving a real recovery path; on resume the funnel re-checks and the card flips to granted.

  Important consequence: **only `notifications` resolves with an inline dialog**. The other five hand off to a full-screen system settings activity that returns no synchronous grant result. That is why the funnel re-checks on resume and after a short delay (below) rather than trusting a return value from `request()`.

The channel methods themselves are thin wrappers over the `com.errorxperts.detoxo/commands` `MethodChannel` (`lib/core/platform_channels/engine_channel.dart`) and no-op off Android via `PlatformCapabilities`. The native intents/receivers behind them (accessibility service, `SYSTEM_ALERT_WINDOW`, usage-access, battery, `DetoxoDeviceAdminReceiver`) are documented in the native/manifest docs.

### 3.3 Presentation

**`PermissionsCubit`** (`presentation/permissions_cubit.dart`) — `Cubit<List<PermissionStatus>>`, initial state `[]`:

- `refresh()` → `emit(await _repo.statuses())`.
- `request(permission)` → calls `_repo.request(...)`, waits **400 ms** (system dialogs/settings are async), then `refresh()`s to reflect the new state.
- `allRequiredGranted` → `state.where((s) => s.kind.required).every((s) => s.granted)` — the getter the splash gate reads. On an empty state (iOS) `.every` on an empty list is `true`.

DI: registered as a global `BlocProvider` in `lib/main.dart` (`PermissionsCubit(sl<PermissionRepository>())`); `PermissionRepository` → `PermissionRepositoryImpl` is a lazy singleton in `lib/core/di/injector.dart`.

**`PermissionsScreen`** (`presentation/permissions_screen.dart`) — the guided funnel UI, title **"Set up protection"**:

- A `WidgetsBindingObserver` that calls `PermissionsCubit.refresh()` on `initState` **and** on every `AppLifecycleState.resumed`. This is the key UX move: the user leaves to a system settings screen, flips a toggle, and returns — the list updates live to reflect what they just granted.
- Splits statuses into **"Required to block"** and **"Recommended"** sections (by `kind.required`), each an animated `EntranceList` of `PermissionCard`s.
- A progress row: a `ProgressBar` plus "*grantedReq* of *totalRequired*" (fraction of required permissions granted).
- Each card shows an icon, the permission `label`, a plain-language *why*, a granted/needed indicator, and an action wired to `cubit.request(status.kind)`. The action reads **Grant** normally, or **Open settings** when the status is `permanentlyDenied` (`PermissionCard(permanentlyDenied: ...)`) — so a don't-ask-again notification permission points at the app's system settings instead of a dead button.
- Bottom `PrimaryButton`: while `allRequiredGranted` is false it reads **"Grant required permissions"** and is **disabled**; once both required permissions are granted it becomes **"Continue"** and `context.go(Routes.home)`.

Per-permission icons and "why" copy (from the screen):

| Permission | Icon | Why |
|------------|------|-----|
| accessibility | `accessibility_new` | "Lets Detoxo detect and block reels & shorts." |
| overlay | `layers` | "Shows the block / PIN screen over other apps." |
| notifications | `notifications` | "Alerts you if protection stops." |
| usageAccess | `bar_chart` | "Powers app usage limits." |
| batteryOptimization | `battery_charging_full` | "Keeps the blocker alive in the background." |
| deviceAdmin | `shield` | "Optional uninstall protection." |

### 3.4 Re-entry after onboarding

The same `PermissionsCubit` is reused in **Settings** (`lib/features/settings/presentation/settings_screen.dart`): a `_PermissionsTile` summarising status ("All set" / "*granted*/*total*") that opens a `_PermissionSheet` listing every permission with **Grant**/**Enable** actions. Settings also `refresh()`es the cubit on init and on resume, so a user who skipped optional permissions during the funnel can grant them later without re-running onboarding.

---

## 4. Manufacturer-specific accessibility guidance

**None is present in the code.** The onboarding, permissions, and splash sources contain no OEM-specific branches or copy (no Xiaomi/MIUI, Oppo, Vivo, Huawei, Samsung, OnePlus, Realme, autostart, etc.). The accessibility request simply opens the standard system Accessibility settings via `openAccessibilitySettings()`; battery-optimization exemption is offered as its own recommended permission. Any OEM autostart/background-restriction guidance would be a **follow-up** (docs/UX), not something the app currently detects or special-cases.

---

## 5. End-to-end sequence (first run, Android)

1. Cold launch → `/` splash → `_bootstrap()` loads settings/targets/permissions/pin, seeds the enabled set from installed defaults, refreshes the counter widget.
2. `onboarded == false` → `/onboarding`. User swipes/skips the 5-page intro (incl. the daily-scroll dial on page 3); finishing persists `onboarded: true`, seeds the daily limit (dialled value or 90 min default), and goes to `/permissions`.
3. `/permissions` funnel. User grants **Accessibility** and **Display over apps** (required) via system screens; returning each time re-checks on resume. Optional permissions (notifications, usage, battery, device-admin) offered but not blocking.
4. Once both required are granted, **Continue** → `/home`.
5. Next launch: splash finds `onboarded == true`, no app-scope PIN (unless the user set one), required permissions granted → routes straight to `/home`. If an app-scope PIN was later configured, step 2 of the gate diverts to `/pin/lock` first.

---

## Source files

- `lib/app/splash_screen.dart`
- `lib/features/onboarding/onboarding.dart`
- `lib/features/onboarding/presentation/onboarding_screen.dart` (5-page intro + `_LimitStep`; seeds `DailyLimit`)
- `lib/features/onboarding/presentation/widgets/screen_time_dial.dart` (`ScreenTimeDial` — the draggable daily-limit gauge)
- `lib/features/limits/daily_limit/presentation/daily_limit_cubit.dart` (`DailyLimitCubit.setLimit` — seeds the limit on finish, via the app-wide provider)
- `lib/features/permissions/permissions.dart`
- `lib/features/permissions/domain/entities/permission_status.dart`
- `lib/features/permissions/domain/repositories/permission_repository.dart`
- `lib/features/permissions/data/repositories/permission_repository_impl.dart`
- `lib/features/permissions/presentation/permissions_cubit.dart`
- `lib/features/permissions/presentation/permissions_screen.dart`
- `lib/core/navigation/app_router.dart`
- `lib/core/navigation/routes.dart`
- `lib/core/platform/platform_capabilities.dart`
- `lib/core/platform_channels/engine_channel.dart`
- `lib/features/blocking/shared/domain/entities/enums.dart` (`PermissionState`, `PinScope`)
- `lib/features/blocking/shared/domain/entities/app_settings.dart` (`onboarded`)
- `lib/features/access_protection/domain/entities/pin_config.dart` (`isConfigured`, `guards`)
- `lib/features/settings/presentation/settings_screen.dart` (permission re-entry tile/sheet)
- `lib/core/di/injector.dart`, `lib/main.dart` (DI/provider wiring)
