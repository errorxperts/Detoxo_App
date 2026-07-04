# Config Sync (offline-first)

> **There is no live backend in this build.** Detoxo loads all of its
> detection config, feature flags, and in-app notices from **bundled JSON
> assets** shipped inside the APK. Every code path that would talk to a server
> is either absent or documented below as a **swap-in / follow-up**. This doc
> explains what is loaded today, by whom, and exactly where a remote fetch
> would plug in without touching the rest of the app.

---

## 1. What "config" means here

Two bundled JSON files drive the app, declared in
`lib/core/constants/app_constants.dart`:

| Constant | Asset path | Drives |
| --- | --- | --- |
| `AppConstants.bundledPlatformsConfig` | `assets/config/platforms_config.json` | The detection catalog: which apps/surfaces (Reels, Shorts, feeds…) are blockable, their view-id detectors, supported block modes, dashboard visibility. This is the JSON pushed verbatim to the native engine. |
| `AppConstants.bundledInitialConfig` | `assets/config/initial_config.json` | App-level metadata: version gating, feature flags, AdMob slots, a premium promo CTA, and in-app notices. |

Both are declared as Flutter assets in `pubspec.yaml`:

```yaml
assets:
  - assets/config/
  - assets/content/
```

The `assets/content/` set (quotes / emoji bands) is unrelated dynamic content
loaded by a separate `ContentRepository`; it is not part of config sync.

> **Naming note:** `AppConstants` carries a doc comment referring to a
> `core/config` package for environment values (API base URL, ad ids, billing
> ids). **That package does not exist** in this build — there is no
> `lib/core/config/` directory. The comment describes the intended swap-in
> location, not current code.

---

## 2. The `ConfigRepository` contract

The single seam for config is the `ConfigRepository` interface in
`lib/features/blocking/shared/domain/repositories/blocking_repositories.dart`:

```dart
abstract interface class ConfigRepository {
  Future<List<BlockTarget>> loadBlockTargets({Set<String>? installedPackages});
  Future<String> rawConfigJson();
  Future<List<AppNotice>> loadNotices();
}
```

- `rawConfigJson()` — the raw `platforms_config.json` string, to be pushed to
  the native engine unmodified.
- `loadBlockTargets()` — the parsed catalog projected into user-facing
  `BlockTarget`s for the blocklist UI, optionally filtered by installed apps.
- `loadNotices()` — in-app notices parsed from `initial_config.json`.

The **whole app depends only on this interface.** A remote implementation can
be dropped in behind it with zero changes to cubits or UI (see §6).

### The only implementation today: `ConfigRepositoryImpl`

`lib/features/blocking/shared/data/repositories/config_repository_impl.dart` is
**offline-only**. It reads the two bundled assets through an injectable
`AssetBundle` (defaults to `rootBundle`; overridable for tests) and caches:

```dart
class ConfigRepositoryImpl implements ConfigRepository {
  final AssetBundle _bundle;
  String? _cachedRaw;              // raw platforms_config.json string
  PlatformConfigModel? _cachedConfig;  // parsed model
  ...
  Future<String> rawConfigJson() async =>
      _cachedRaw ??= await _bundle.loadString(AppConstants.bundledPlatformsConfig);
}
```

- `rawConfigJson()` reads and memoises the file string once per process.
- `_config()` decodes it once into a `PlatformConfigModel` and memoises that.
- `loadNotices()` reads `initial_config.json`, parses `InitialConfigModel`, and
  maps its `inappNotification` list to `AppNotice` entities. It is wrapped in a
  `try/catch` that returns `const []` on any parse failure — a bad or missing
  notices asset degrades silently.

There are **no other `ConfigRepository` implementations** in the tree
(`find lib -name '*config_repository*'` returns only this one file).

Registered as a lazy singleton in the service locator
(`lib/core/di/injector.dart`):

```dart
..registerLazySingleton<ConfigRepository>(ConfigRepositoryImpl.new)
```

---

## 3. The wire models

The JSON contract is modelled with `freezed` DTOs whose field names mirror the
wire format (schema detailed in
[02-detection-config-schema.md](02-detection-config-schema.md)).

### `platforms_config.json` → `PlatformConfigModel`

`lib/features/blocking/shared/data/models/platform_config_model.dart`:

- `PlatformConfigModel` — `{ responsecode, featuredApps: { pkg -> AppDetailsModel } }`.
- `AppDetailsModel` — per-app metadata (`packageName`, `appName`, `iconUrl`,
  `premiumExclusive`, `showInDashboard`, `showIfNotInstalled`, `browser`, …)
  plus a `platforms[]` list.
- `PlatformModel` — a blockable surface (`platformId`, `platformName`,
  `detectionType`, `detectors{}`, `defaultStatus`, dashboard flags, …).
- `DetectorModel` — one detector (`supportedBlockModes`, `defaultBlockMode`,
  `identifiers`, `haltOnDetect`, …).
- `OverlayParamsModel` / `OverlayConfigModel` — for `OVERLAY` detectors whose
  `params` field is itself an escaped JSON string, parsed lazily.

### `initial_config.json` → `InitialConfigModel`

`lib/features/blocking/shared/data/models/initial_config_model.dart` models a
much richer surface than the app currently consumes:

| Field | Modelled | Consumed today |
| --- | --- | --- |
| `inappNotification[]` (`InAppNotificationModel`) | ✅ | Parsed by `loadNotices()` into `AppNotice` — **the interface exists but has no UI consumer yet** (see §5). |
| `versionAvailability` (`VersionAvailabilityModel` / `VersionInfoModel`) | ✅ | ❌ not wired — force/prompt-update gating is **planned**. |
| `admobConfig` (`AdSlotModel`) | ✅ | ❌ not wired — ads use Google **TEST** ids, no live init. |
| `featuresAvailability` (`FeatureFlagModel`) | ✅ | ❌ not wired — remote feature flags are **planned**. |
| `premiumPurchaseCTA` (`PromoCtaModel`), `activePlanDetails` | ✅ | ❌ not wired — premium is a local dev-unlock, no Play Billing. |
| `platformConfigVersion` (int) | ✅ | ❌ not read — intended as a cache-invalidation key for a remote refresh (**planned**). |

These fields are decoded and defaulted so that a future remote payload
round-trips cleanly, but most are inert in this build.

---

## 4. How the config reaches the native engine

The push happens once on blocklist load, in
`lib/features/blocking/blocklist/presentation/targets_cubit.dart`:

```dart
Future<void> load() async {
  final raw = await _config.rawConfigJson();   // bundled asset string
  await _engine.pushConfig(raw);               // hand to native engine
  final installed = await _engine.installedPackages();
  final targets = await _config.loadBlockTargets(installedPackages: installed);
  emit(TargetsState(targets: targets));
}
```

`TargetsCubit` is constructed with both repos in `lib/main.dart`.

### The push chain

```
ConfigRepositoryImpl.rawConfigJson()              // read assets/config/platforms_config.json
   → EngineRepositoryImpl.pushConfig(json)        // data/repositories/engine_repository_impl.dart
      → EngineChannel.pushConfig(json)            // core/platform_channels/engine_channel.dart
         → MethodChannel "com.errorxperts.detoxo/commands"
            .invokeMethod("pushConfig", {"json": json})
               → CommandHandler "pushConfig"      // native: channels/CommandHandler.kt
                  store.platformsConfigJson = json          // engine/ConfigStore.kt (SharedPreferences)
                  DetoxoAccessibilityService.instance?.reload()
                     → DetectionConfig.parse(json)          // engine/DetectionConfig.kt (package-indexed)
```

Native side (grounded in source):

- `CommandHandler.kt` `"pushConfig"` writes `call.argument<String>("json")` into
  `store.platformsConfigJson` and calls `service.reload()`.
- `ConfigStore.kt` persists it under key `platforms_config_json` in the
  SharedPreferences file `detoxo_engine_prefs`. **The last-pushed config
  survives process death** — the getter returns `null` only before the first
  push.
- `DetectionConfig.parse()` re-parses the JSON into an O(1) package-indexed
  lookup for the hot path. A null/blank/malformed config yields
  `DetectionConfig.EMPTY` (no detectors → nothing blocked), so a parse failure
  fails safe.

Detail on the native consumer lives in
[03-detection-engine.md](03-detection-engine.md) and
[04-native-android-layer.md](04-native-android-layer.md).

### Off-Android no-op

`EngineChannel` short-circuits every command when
`PlatformCapabilities.supportsBlockingEngine` is false (iOS / tests): the push
returns immediately without a channel round-trip. On those platforms the config
is still parsed in Dart (for UI) but never handed to a native engine, because
there isn't one.

---

## 5. How the config drives the UI

### Block targets

`loadBlockTargets({installedPackages})` walks `featuredApps → platforms`,
building one `BlockTarget` per surface that is `showInDashboard` **or**
`showAlwaysInBlockList`. Notable derivations:

- **Package fallback:** `platform.packageName`, else the parent app's.
- **Icon/name fallback:** platform value, else the app's.
- **Supported modes:** the union of every detector's `supportedBlockModes`
  (mapped via `BlockingMode.fromWire`); defaults to `pressBack` if empty.
- **Install-awareness:** when `installedPackages` is non-null, each target is
  tagged `isInstalled`; uninstalled apps not flagged `showIfNotInstalled` are
  dropped; installed apps sort first, then alphabetically by app name.
- **`installedPackages == null`** (off-Android, or the channel returned no
  data) → the full catalog is returned with everything marked installed. This
  is why the blocklist still renders on unsupported platforms.

The same catalog is reused by the content counter:
`ContentCounterRepositoryImpl` (`lib/features/content_counter/.../content_counter_repository_impl.dart`)
calls `loadBlockTargets()` to build a `packageName → BlockTarget` index so it
can label per-app counts with real app names and icons.

### Notices (modelled, not yet surfaced)

`loadNotices()` produces `AppNotice` entities from `initial_config.json`. As of
this build **no widget or cubit consumes `loadNotices()`** — a grep for
`loadNotices` / `AppNotice` outside the repo, interface, and entity files
returns nothing. The parsing path is complete and safe; wiring it into a
notices UI is a **follow-up**.

---

## 6. Where a remote fetch swaps in

Everything above is offline-first by design. To add a live backend:

1. **New implementation, same interface.** Add e.g. a
   `RemoteConfigRepository implements ConfigRepository` that fetches
   `platforms_config.json` / `initial_config.json` over HTTP, and layer it over
   `ConfigRepositoryImpl` as an offline fallback (fetch → cache → fall back to
   bundle on failure). Swap the single `registerLazySingleton<ConfigRepository>`
   line in `lib/core/di/injector.dart`. **No cubit or UI changes are required**
   — `TargetsCubit`, the counter, and any future notices consumer already
   depend only on the interface.
2. **Cache invalidation.** `InitialConfigModel.platformConfigVersion` is already
   modelled to serve as the "should I re-fetch / re-push" key; nothing reads it
   yet.
3. **Where env values would live.** The intended home for API base URL, ad unit
   ids, and billing product ids is a `core/config` package (per the
   `AppConstants` doc comment). It does not exist yet — create it there so
   feature code stays untouched.

### Networking primitives available

- `dio: ^5.9.2` is declared in `pubspec.yaml` but **is not imported or used
  anywhere in `lib/`** (`grep 'package:dio'` over `lib/` is empty). It is a
  staged dependency for the future remote repository, currently dead weight.
- There is **no** `lib/core/network/` directory, no `http`/`HttpClient` usage, no FCM, and no
  networking-based `ConfigRepository` implementation. (The app does bundle a Firebase **telemetry**
  layer — analytics/crash/perf — but that is not a config or networking path; see
  [19-firebase-telemetry.md](19-firebase-telemetry.md).)

---

## 7. Infra follow-ups (bundled data)

The bundled JSON assets were carried over from an earlier product iteration and
still contain **legacy branding strings and legacy icon URLs**. Specifically,
`iconUrl` values in `platforms_config.json` still point at the old vendor host
`curizic.com` (e.g. `https://curizic.com/NoScroll/icons/...`), and
`initial_config.json` still carries legacy notice copy and `expiry` timestamps.

These are **infra follow-ups**, not code bugs: the offline flow works because
the icons/notices are just data fields projected into `BlockTarget`/`AppNotice`.
When the icon host is decommissioned or rebranded, refresh the bundled assets
(and/or serve them from the future remote config). Do not hard-code a
replacement URL in code — it belongs in the config payload.

---

## Source files

- `lib/core/constants/app_constants.dart` — `AppConstants.bundledPlatformsConfig` / `bundledInitialConfig` asset paths.
- `lib/features/blocking/shared/domain/repositories/blocking_repositories.dart` — `ConfigRepository` interface (+ `EngineRepository.pushConfig`).
- `lib/features/blocking/shared/data/repositories/config_repository_impl.dart` — offline-first implementation.
- `lib/features/blocking/shared/data/models/platform_config_model.dart` — `platforms_config.json` DTOs.
- `lib/features/blocking/shared/data/models/initial_config_model.dart` — `initial_config.json` DTOs (feature flags, version gating, notices, promo CTA).
- `lib/features/blocking/blocklist/presentation/targets_cubit.dart` — reads config, pushes to engine, builds targets.
- `lib/features/blocking/shared/data/repositories/engine_repository_impl.dart` — `pushConfig` bridge.
- `lib/core/platform_channels/engine_channel.dart` — `pushConfig` command wrapper + off-Android no-op.
- `lib/core/di/injector.dart` — `ConfigRepository` registration.
- `lib/features/content_counter/content_counter_core/data/repositories/content_counter_repository_impl.dart` — reuses `loadBlockTargets()` for app naming.
- `assets/config/platforms_config.json`, `assets/config/initial_config.json` — bundled config payloads.
- `pubspec.yaml` — asset declarations; unused `dio` dependency.
- `android/app/src/main/kotlin/com/errorxperts/detoxo/channels/CommandHandler.kt` — native `pushConfig` handler.
- `android/app/src/main/kotlin/com/errorxperts/detoxo/engine/ConfigStore.kt` — persists pushed config (`platforms_config_json` in `detoxo_engine_prefs`).
- `android/app/src/main/kotlin/com/errorxperts/detoxo/engine/DetectionConfig.kt` — parses the pushed config into the native lookup.
