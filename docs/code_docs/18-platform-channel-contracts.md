# Platform Channel Contracts

The Dart app and the native Android engine communicate over exactly **two Flutter
platform channels**, plus **one out-of-band bridge** (the `home_widget` plugin)
for the home-screen widget. This doc is the complete, source-derived contract:
every command method (args + return) on the MethodChannel, every event `type` +
payload shape on the EventChannel, and the widget bridge keys.

Channel names are defined once in `lib/core/constants/channel_constants.dart` and
mirrored in the native `MainActivity`:

| Direction | Kind | Name |
|---|---|---|
| Dart → native | `MethodChannel` | `com.errorxperts.detoxo/commands` |
| native → Dart | `EventChannel` | `com.errorxperts.detoxo/events` |

Both are wired in `android/.../MainActivity.kt`
(`configureFlutterEngine`): the command channel routes to `CommandHandler`, the
event channel to `DetoxoEventStream`.

---

## Wiring & platform gating (Dart side)

`lib/core/platform_channels/engine_channel.dart` (`EngineChannel`) is the only
low-level wrapper; repositories build on it and it owns no domain logic.

Two hard guarantees baked into the wrapper:

- **Off-Android = no-op.** `PlatformCapabilities.supportsBlockingEngine`
  (`lib/core/platform/platform_capabilities.dart`) gates everything. When false
  (iOS / tests):
  - `events()` returns `const Stream.empty()` — it never subscribes, so no
    per-launch `MissingPluginException` is logged.
  - Every command short-circuits **before** the channel round-trip, returning the
    method's safe default.
- **Errors degrade to defaults.** `_invoke<T>` catches `PlatformException` (logged
  via `AppLogger.e`) and `MissingPluginException`, returning `null` in both cases.

Return coercion helpers (define the default a failed/absent call yields):

| Helper | On success | On null/error |
|---|---|---|
| `invokeBool` | the `bool` | `false` |
| `invokeVoid` | — | — (fire-and-forget) |
| `invokeMap`  | `Map<String,dynamic>` | `{}` (empty map) |
| raw `_invoke<List>` (installedPackages) | the list | `null` |

Native results are always delivered via `result.success(...)`; the only
`notImplemented()` path is the `else` branch of `CommandHandler.onMethodCall` (see
[Declared-but-unhandled methods](#declared-but-unhandled-methods)).

---

## Command channel — `com.errorxperts.detoxo/commands`

Method-name constants live in `ChannelMethods` (Dart) and are matched by string in
`CommandHandler.onMethodCall` (Kotlin). Args are read via
`call.argument<T>("key")`.

### Config / settings push

| Method | Args | Native effect | Returns | Dart wrapper |
|---|---|---|---|---|
| `pushConfig` | `{json: String}` | `store.platformsConfigJson = json`; `service.reload()` | `true` | `pushConfig(String json)` |
| `pushSettings` | settings map (see below) | applies each present key to `ConfigStore`; `service.reload()` | `true` | `pushSettings(Map settings)` |
| `pushWebBlocklist` | `{json: String}` | `store.webBlocklistJson = json`; `service.reload()` | `true` | `pushWebBlocklist(String json)` |

**`pushConfig` payload** — `json` is the full `platforms_config.json` string
(featuredApps → platforms → detectors), parsed natively by `DetectionConfig`.

**`pushSettings` payload** — the map is built in
`lib/features/blocking/shared/data/repositories/engine_repository_impl.dart`.
`CommandHandler` reads each key only if present, so partial pushes are legal:

| Key | Type (wire) | Notes |
|---|---|---|
| `activePlan` | `String` | `BlockingPlan.wire`: `BLOCK_ALL` \| `CURIOUS` \| `ONE_REEL` \| `PAUSED`. **`CURIOUS` = the "Conscious" plan** (internal token kept verbatim; UI label is "Conscious"). Switching *into* `CURIOUS` from another plan resets the earn-bank (`store.resetConsciousBank(now)`). |
| `defaultBlockMode` | `String` | `PRESS_BACK` \| `KILL_APP` \| `LOCK_SCREEN` \| `NONE` |
| `enabledPlatforms` | `List<String>` | stored as a set |
| `vibration` | `bool` | |
| `masterEnabled` | `bool` | engine master switch |
| `pauseUntil` | `Number` (epoch ms, `0` = not paused) | read as `Long` |
| `consciousEarnDivisor` | `Number` | read as `Int` |
| `consciousMaxBankMs` | `Number` | read as `Long` |
| `blockAdultWebsites` | `bool` | |
| `blockWebsitesForBlockedApps` | `bool` | |

**`pushWebBlocklist` payload** — `json` is a JSON-encoded array of
`{pattern, matchType}` rules. `matchType` is `WebMatchType.wire`:
`DOMAIN` \| `EXACT` \| `WILDCARD` (native `WebBlockEngine` matches browser hosts
against these).

### Permission queries & launches

Each `is*/has*/canDrawOverlays` returns a `Boolean`; each `open*/request*` launches
a system settings/consent intent and returns a `Boolean` = *launch succeeded*
(true if `startActivity` didn't throw — **not** whether the user granted it).

| Method | Args | Returns | Dart wrapper |
|---|---|---|---|
| `isAccessibilityEnabled` | — | `Boolean` (service present in `ENABLED_ACCESSIBILITY_SERVICES`) | `isAccessibilityEnabled()` |
| `openAccessibilitySettings` | — | `Boolean` | `openAccessibilitySettings()` |
| `canDrawOverlays` | — | `Boolean` (`Settings.canDrawOverlays`) | `canDrawOverlays()` |
| `requestOverlayPermission` | — | `Boolean` | `requestOverlay()` |
| `hasUsageAccess` | — | `Boolean` (`AppOpsManager` GET_USAGE_STATS) | `hasUsageAccess()` |
| `openUsageAccessSettings` | — | `Boolean` | `openUsageAccess()` |
| `isIgnoringBatteryOptimizations` | — | `Boolean` | `isIgnoringBattery()` |
| `requestIgnoreBatteryOptimizations` | — | `Boolean` | `requestIgnoreBattery()` |
| `isDeviceAdminActive` | — | `Boolean` | `isDeviceAdminActive()` |
| `requestDeviceAdmin` | — | `Boolean` (launches `ACTION_ADD_DEVICE_ADMIN`) | `requestDeviceAdmin()` |
| `removeDeviceAdmin` | — | `true` (removes active admin; swallows errors) | `removeDeviceAdmin()` |

### Block actions

Direct engine actions, routed to the live `DetoxoAccessibilityService.instance`
(no-op if the service is dead). Used by the PIN / one-reel / test surfaces.

| Method | Args | Native effect | Returns | Dart wrapper |
|---|---|---|---|---|
| `performBack` | — | `service.performBackPublic()` | `true` | `performBack()` |
| `killApp` | `{package: String}` | `service.killApp(pkg)` (no-op if pkg null) | `true` | `killApp(String pkg)` |
| `lockScreen` | — | `service.lockScreen()` (device-admin `lockNow`) | `true` | `lockScreen()` |

### Device / stats / snapshots (return maps)

| Method | Args | Returns (map shape) | Dart wrapper |
|---|---|---|---|
| `blockStats` | — | `{today: Int, total: Int, date: String}` | `blockStats() → Map` |
| `consciousState` | — | `{bankMs: Long, maxBankMs: Long, watching: Bool, blocked: Bool, active: Bool}` | `consciousState() → Map` |
| `contentCounterSnapshot` | — | `{enabled: Bool, bubbleEnabled: Bool, today: Int, total: Int, date: String, perAppToday: Map<String,Int>, perAppTotal: Map<String,Int>, timeTodayMs: Long, timeTotalMs: Long, bubbleStyle: String, widgetStyle: String}` | `contentCounterSnapshot() → Map` |
| `deviceInfo` | — | `{brand, manufacturer, model, sdkInt}` | *(no Dart wrapper)* |
| `installedPackages` | — | `List<String>` of launchable packages, or `null` on failure | `installedPackages() → Set<String>?` |

Notes:
- **`consciousState`** prefers the live service snapshot; if the service is dead it
  synthesizes from `ConfigStore` (`bankMs`/`maxBankMs`/`active` from stored state,
  `watching:false`). `active`/`blocked`/`watching` are all AND-ed with
  "plan is `CURIOUS`".
- **`contentCounterSnapshot`** prefers the live service counter, else reads
  `ContentCounterStore` directly (works with the service dead). On a date rollover
  `today`/`perAppToday` read as `0`/`{}`.
- **`installedPackages`** runs off the platform thread (launchable-app enumeration
  can take 100s of ms) and posts back on it. It returns **`null`** (not empty) on
  failure so Dart treats install state as "unknown" and shows the full blocklist
  rather than hiding every app.

### Content-counter controls

| Method | Args | Native effect | Returns | Dart wrapper |
|---|---|---|---|---|
| `setContentCounterEnabled` | `{enabled: Bool}` (default `true`) | `store.enabled`; `service.contentCounter.setEnabled` | `true` | `setContentCounterEnabled({enabled})` |
| `setContentBubbleEnabled` | `{enabled: Bool}` (default `true`) | `store.bubbleEnabled`; `service.contentCounter.setBubbleEnabled` | `true` | `setContentBubbleEnabled({enabled})` |
| `pinContentWidget` | — | `AppWidgetManager.requestPinAppWidget(ContentCounterWidgetProvider)` | `Boolean` (false if launcher can't pin / < API 26) | `pinContentWidget()` |
| `refreshContentWidget` | — | `ContentCounterWidgetProvider.pushUpdate(store.snapshot)` | `true` | `refreshContentWidget()` |
| `setCounterStyle` | `{bubble?: Map, widget?: Map}` | persists changed surface(s), live-re-renders bubble + all pinned widgets | `true` | `setCounterStyle({bubble, widget})` |

**`setCounterStyle` payload** — each sub-map is a style *wire map*; only the keys
present are updated (the Dart wrapper uses null-aware spread `{'bubble': ?bubble,
'widget': ?widget}`, so absent surfaces are omitted entirely). Native stores each
as JSON and re-renders.

- `bubble` (from `BubbleStyle.toWire`,
  `lib/features/content_counter/content_counter_bubble/domain/entities/bubble_style.dart`):
  `{variant: String, size: num, textScale: num, spacing: num, opacity: num, showLabel: bool, showTime: bool}`
  (`showTime` gates the bubble's tap-to-reveal-watch-time gesture; default `true`)
- `widget` (from `WidgetStyle.toWire`,
  `lib/features/content_counter/home_content_counter/domain/entities/widget_style.dart`):
  `{background: String, theme: String, density: String, showToday: bool, showLabel: bool, showTotal: bool, accentByUsage: bool}`

### Declared-but-unhandled methods

These constants exist in `ChannelMethods` but `CommandHandler` has **no `when`
branch** for them, so they hit `else -> result.notImplemented()` → a
`PlatformException` that `EngineChannel._invoke` swallows to `null`. They also have
**no Dart convenience wrapper**. Treat them as reserved / planned:

- `showOverlay`, `hideOverlay` — overlay control is currently driven internally by
  the engine (one-reel grace overlay, counter bubble), not via these commands.
- `foregroundPackage` — no native handler; foreground info is not exposed as a
  pull command.

(`deviceInfo` is the inverse case: handled natively but no Dart wrapper — callable
only via a raw `invokeMap('deviceInfo')`.)

---

## Event channel — `com.errorxperts.detoxo/events`

One multiplexed stream. Native posts through
`ServiceEventBus.post(type, data)` (`android/.../engine/ServiceEventBus.kt`), which
merges `data` with `{"type": type}` and delivers on the main thread **only while a
sink is registered** — i.e. while Dart is listening (`DetoxoEventStream.onListen`
sets the sink; `onCancel` clears it). With the UI dead, events are dropped; the
block hot-path never depends on Dart.

Dart side: `EngineChannel.events()` maps each payload to
`Map<String,dynamic>`, is a broadcast stream, and multiplexes on the `type` field.
Repositories filter by `e['type'] == ChannelEvents.<x>`.

Every payload carries `type` plus the fields below.

| `type` | Emitted by | Payload (beyond `type`) | Dart consumer |
|---|---|---|---|
| `serviceStatus` | `DetoxoAccessibilityService` (connect / interrupt / unbind) | `{running: Bool}` | `engine_repository_impl.dart` |
| `blocked` | `DetoxoAccessibilityService.onDetected` | `{package: String, platformId: String, mode: String, today: Int, total: Int}` | `engine_repository_impl.dart` (status + block history) |
| `webBlocked` | `DetoxoAccessibilityService.handleBrowser` | `{host: String, mode: "PRESS_BACK", today: Int, total: Int}` | `web_block_stats_repository_impl.dart` |
| `consciousState` | `DetoxoAccessibilityService` (1 Hz accountant) | `{bankMs: Long, maxBankMs: Long, watching: Bool, blocked: Bool, active: Bool}` | `engine_repository_impl.dart` |
| `contentCounted` | `ContentCounter.count` | `{package: String, today: Int, total: Int, perAppToday: Map<String,Int>, perAppTotal: Map<String,Int>, timeTodayMs: Long}` | `content_counter_repository_impl.dart` |

`mode` on `blocked` is the resolved block mode: `PRESS_BACK` \| `KILL_APP` \|
`LOCK_SCREEN` \| `NONE`. `consciousState.watching`/`blocked` are AND-ed with "plan
is `CURIOUS`" (the Conscious plan).

### Declared-but-inert event types

`ChannelEvents` also declares `detection` and `foregroundChanged`. As of this
source there is **no native emitter** (`ServiceEventBus.post` is never called with
those strings) and **no Dart consumer**. They are reserved constants — a diagnostic
"raw detection" stream and a foreground-app-change stream are the obvious planned
uses. Do not assume they fire.

---

## Home-widget bridge (out of band)

The home-screen reel-counter widget is **not** driven over the two channels above.
It uses the `home_widget` plugin as a side bridge, in
`lib/features/content_counter/home_content_counter/data/repositories/home_widget_repository_impl.dart`:

- **Data keys** (`HomeWidget.saveWidgetData<int>`): `cc_today`, `cc_total`.
- **Provider**: `ContentCounterWidgetProvider` — `name`/`androidName`
  `"ContentCounterWidgetProvider"`, qualified
  `"com.errorxperts.detoxo.widget.ContentCounterWidgetProvider"`.
- **Update**: `HomeWidget.updateWidget(...)` re-renders the provider.
- **Pin**: `HomeWidget.requestPinWidget(...)`; on failure (plugin unavailable /
  launcher refused) it falls back to the native `pinContentWidget` command.

The native provider renders from `ContentCounterStore` (the **native store is the
source of truth**), so these `home_widget` calls only trigger a refresh/pin — a
`home_widget` failure never breaks counting. Every `pushSnapshot` also calls
`refreshContentWidget` on the command channel as the authoritative render path.

---

## Contract summary

- **2 channels**: commands (Method) + events (Event), both under
  `com.errorxperts.detoxo/*`, wired in `MainActivity`.
- **Commands**: string-dispatched in `CommandHandler`; returns are `Boolean`
  (queries/launches/actions), `true` (fire-and-forget mutations), a map
  (stats/snapshots/deviceInfo), or a `List`/`null` (installedPackages). Three
  declared methods (`showOverlay`, `hideOverlay`, `foregroundPackage`) are
  unhandled → `notImplemented`.
- **Events**: 5 live types multiplexed by `type`; 2 declared-but-inert
  (`detection`, `foregroundChanged`).
- **Widget**: separate `home_widget` bridge, keys `cc_today`/`cc_total`, provider
  `ContentCounterWidgetProvider`, native store is source of truth.

See also [03-detection-engine.md](03-detection-engine.md) for how `blocked` /
`detection` are produced, and the content-counter engine doc for `contentCounted`
and the bubble/widget surfaces.

## Source files

- `lib/core/constants/channel_constants.dart`
- `lib/core/platform_channels/engine_channel.dart`
- `lib/core/platform/platform_capabilities.dart`
- `lib/features/blocking/shared/data/repositories/engine_repository_impl.dart`
- `lib/features/blocking/shared/domain/entities/enums.dart`
- `lib/features/limits/web_blocker/data/repositories/web_block_stats_repository_impl.dart`
- `lib/features/content_counter/content_counter_core/data/repositories/content_counter_repository_impl.dart`
- `lib/features/content_counter/content_counter_core/data/repositories/counter_appearance_repository_impl.dart`
- `lib/features/content_counter/content_counter_bubble/domain/entities/bubble_style.dart`
- `lib/features/content_counter/home_content_counter/domain/entities/widget_style.dart`
- `lib/features/content_counter/home_content_counter/data/repositories/home_widget_repository_impl.dart`
- `android/app/src/main/kotlin/com/errorxperts/detoxo/MainActivity.kt`
- `android/app/src/main/kotlin/com/errorxperts/detoxo/channels/CommandHandler.kt`
- `android/app/src/main/kotlin/com/errorxperts/detoxo/channels/DetoxoEventStream.kt`
- `android/app/src/main/kotlin/com/errorxperts/detoxo/engine/ServiceEventBus.kt`
- `android/app/src/main/kotlin/com/errorxperts/detoxo/engine/ContentCounterStore.kt`
- `android/app/src/main/kotlin/com/errorxperts/detoxo/engine/ContentCounter.kt`
- `android/app/src/main/kotlin/com/errorxperts/detoxo/accessibility/DetoxoAccessibilityService.kt`
- `android/app/src/main/kotlin/com/errorxperts/detoxo/widget/ContentCounterWidgetProvider.kt`
