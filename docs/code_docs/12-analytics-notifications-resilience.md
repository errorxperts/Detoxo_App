# Analytics, Notifications & Resilience

How Detoxo records what it blocked, keeps its engine alive as an Android
foreground service, survives reboots/updates, and (optionally) protects itself
from being uninstalled. Everything here is **local and on-device** — there is no
Firebase, FCM, Crashlytics, or remote analytics sink bundled in the app.

Related docs: [03-detection-engine.md](03-detection-engine.md) (where `blocked`
events originate), [17-content-counter.md](17-content-counter.md) (the parallel,
decoupled counting pipeline), [13-onboarding-permissions.md](13-onboarding-permissions.md)
(how Device Admin / notifications are requested).

---

## 1. Local analytics (block-event history)

The `analytics` feature is a thin, local **block-event buffer** plus a read-only
"Activity" feed. It records one record per native `blocked` event and shows the
recent history; there is no aggregation, upload, or dashboard beyond a list.

### 1.1 Feature layout & boundary

```
lib/features/analytics/
  analytics.dart                                   # public barrel (domain only)
  domain/repositories/analytics_repository.dart    # AnalyticsRepository interface
  data/repositories/analytics_repository_impl.dart # LocalStore-backed impl
  presentation/analytics_cubit.dart                # AnalyticsCubit
  presentation/analytics_screen.dart               # AnalyticsScreen + AnalyticsTab
```

The barrel exports **only** the domain contract, so other features depend on the
interface, never the `LocalStore`-backed implementation or the UI (boundary
enforced by `tool/check_boundaries.sh`).

### 1.2 Domain contract

`AnalyticsRepository` is deliberately tiny:

```dart
abstract interface class AnalyticsRepository {
  Future<void> logBlock(BlockEvent event);
  Future<List<BlockEvent>> recent({int limit = 50});
  Future<int> countToday();
}
```

`BlockEvent` (defined in the blocking feature,
`lib/features/blocking/shared/domain/entities/engine_event.dart`) carries
`platformId`, `packageName`, `mode` (`BlockingMode`), and a `timestamp`.

### 1.3 Storage implementation

`AnalyticsRepositoryImpl` persists to the Dart key-value store
(`lib/core/storage/local_store.dart`) under key
`StoreKeys.analyticsEvents = 'analytics_events'` as a single JSON array. Key
behaviours:

- **Newest-first, capped at 500.** `logBlock` reads the existing list, prepends
  the new event, and truncates with `.take(_maxEvents)` where
  `_maxEvents = 500`. So the buffer is a rolling window of the most recent ~500
  blocks (older entries fall off).
- **Explicit wire (de)serialization.** Each record is
  `{ platformId, packageName, mode, ts }` where `mode` is `BlockingMode.wire`
  (e.g. `"PRESS_BACK"`, `"KILL_APP"`) and `ts` is
  `timestamp.millisecondsSinceEpoch`. Reads use `BlockingMode.fromWire(...)`,
  which falls back to `pressBack` for unknown/legacy tokens, and default empty
  strings / epoch-0 for missing fields — so a malformed record never throws.
- **`recent({limit})`** decodes the array and returns the first `limit`
  entries (default 50; the UI asks for 100). Returns `const []` when the key is
  unset.
- **`countToday()`** loads up to `_maxEvents` and counts entries whose
  `timestamp` falls on the local calendar day (year/month/day match
  `DateTime.now()`). This is the Dart-side "blocks today"; note the native engine
  keeps its own authoritative counters (see [03-detection-engine.md](03-detection-engine.md)
  and §2.4 below) — this local count is derived only from the buffered events.

> Design note (from the impl's own comment): the interface is the seam for a
> future cloud sink. "A cloud sink (Firebase Analytics) can be added behind the
> same interface later." That is a **planned swap-in**, not shipped — nothing
> uploads today.

### 1.4 Cubit — the sink and the loader

`AnalyticsCubit extends Cubit<List<BlockEvent>>` (state is just the list;
initial `const []`):

```dart
AnalyticsCubit(this._repo, this._engine) : super(const []) {
  _engine.blockStream().listen(_repo.logBlock);   // persist every block
}
Future<void> load() async => emit(await _repo.recent(limit: 100));
```

Two responsibilities:

1. **Persistence sink.** In its constructor it subscribes to
   `EngineRepository.blockStream()` and pipes every `BlockEvent` straight into
   `_repo.logBlock`. `blockStream()`
   (`lib/features/blocking/shared/data/repositories/engine_repository_impl.dart`)
   filters the multiplexed EventChannel for `type == "blocked"` and maps
   `platformId` / `package` / `mode` into a `BlockEvent`, stamping
   `timestamp: DateTime.now()` on the Dart side (the native `today`/`total`
   counters on that event feed the status stream, not the history record).
2. **UI loader.** `load()` reads the last 100 records for display.

> Caveat worth knowing: the sink lives on the cubit, and the cubit is created
> where the Activity view mounts (see §1.5). Persistence therefore runs while an
> Activity view has been opened at least once and its cubit is alive — it is not
> an app-lifetime background logger. The native engine's own counters and events
> are the source of truth for "what was blocked"; this buffer is a UI-facing
> convenience history.

### 1.5 Presentation — one cubit, two entry points

`analytics_screen.dart` exposes the same feed two ways that differ only in
chrome, both wired through `_withCubit(...)`, which provides an `AnalyticsCubit`
(`sl<AnalyticsRepository>()`, `sl<EngineRepository>()`) already `..load()`-ed
plus a `ContentCounterCubit`:

- **`AnalyticsScreen`** — full-screen drawer route ("Activity") with a
  `GlassAppBar` + back button.
- **`AnalyticsTab`** — the second HomeShell tab, with an in-tab header, a
  feedback button, and a drawer menu button, wired to the floating nav bar's
  scroll controller for hide-on-scroll.

The body (`_ActivityBody`) is always a scrollable `ListView` that leads with the
always-visible `ReelCounterCard` (from the content-counter feature), then either
an `EmptyState` ("Nothing blocked yet" / "Block events will show up here as they
happen.") or one `_EventTile` per event. A tile renders a red "ban" `IconBadge`,
`platformId` as the title, `packageName · mode.wire` as the subtitle, and a
`DateFormat('MMM d, HH:mm')` timestamp.

### 1.6 Dependency injection

`lib/core/di/injector.dart` registers the repo as a lazy singleton over the
`LocalStore`:

```dart
..registerLazySingleton<AnalyticsRepository>(
  () => AnalyticsRepositoryImpl(sl()),
)
```

The cubit itself is not a singleton — it is created per-view by the
`BlocProvider` in `_withCubit`.

### 1.7 No cloud analytics / messaging

A repo-wide search for `firebase`, `fcm`, `messaging`, `crashlytics`, and
`google-services` across `pubspec.yaml` and the Gradle files returns nothing.
There is **no Firebase, no FCM push, no remote crash/analytics reporting**.
All "analytics" is the local buffer above. (For monetization/ads posture see
the monetization doc; AdMob uses Google **test** IDs only.)

---

## 2. Foreground-service notification

Detoxo's engine is an `AccessibilityService`
(`accessibility/DetoxoAccessibilityService.kt`) that **also runs as a foreground
service in the main process** — there is no separate `:as_process`. The ongoing
notification is what keeps that service alive and OS-visible.

### 2.1 Channel & notification (verbatim from `startAsForeground()`)

| Field | Value |
|---|---|
| Channel id (`CHANNEL_ID`) | `detoxo_protection_channel` |
| Channel name | `Detoxo Service Status` |
| Channel importance | `IMPORTANCE_LOW` (silent, no sound/heads-up) |
| Channel flags | `setShowBadge(false)`, description `"Focus protection active"` |
| Notification id (`NOTIF_ID`) | `1125` |
| Title | `Detoxo is active` |
| Text | `Monitoring and blocking short-form video.` |
| Small icon | `R.mipmap.ic_launcher` |
| Ongoing | `true` |
| Priority | `PRIORITY_MIN` |

The channel is created (API 26+/`O`) before the `NotificationCompat.Builder`
notification is shown. `IMPORTANCE_LOW` + `PRIORITY_MIN` + no badge make it a
quiet, persistent status entry rather than an alert.

### 2.2 startForeground with special-use FGS type

```kotlin
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {  // API 34+
    startForeground(NOTIF_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
} else {
    startForeground(NOTIF_ID, notification)
}
```

On Android 14+ the service is promoted with
`FOREGROUND_SERVICE_TYPE_SPECIAL_USE`; older versions use the un-typed overload.
The whole call is wrapped in `try/catch` and only logs on failure (never
crashes). This is mirrored in the manifest:

- `<uses-permission>` `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`,
  `POST_NOTIFICATIONS`.
- The `<service>` declares `android:foregroundServiceType="specialUse"` plus a
  `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` property explaining the special use ("Blocks
  short-form video via accessibility to support digital wellbeing.").

### 2.3 Lifecycle: when it starts, restarts, and reports status

`startAsForeground()` is invoked:

- in **`onServiceConnected()`** — right after config load, the first time the OS
  binds the enabled accessibility service; and
- in **`onTaskRemoved()`** — re-issued when the user swipes the app away, so the
  foreground service stays alive after the task is removed.

Service liveness is broadcast to Dart over the multiplexed EventChannel as
`serviceStatus` events (via `ServiceEventBus`):

| Callback | Emitted `serviceStatus` |
|---|---|
| `onServiceConnected()` | `{ running: true }` |
| `onInterrupt()` | `{ running: false }` |
| `onUnbind()` | `{ running: false }` (also clears `instance`, stops the Conscious accountant, disposes the counter) |
| `onDestroy()` | clears `instance`, stops the accountant, disposes the counter |

A static `instance` / `isRunning()` also lets `CommandHandler` reach the live
service directly (e.g. `performBack`, `killApp`, and the accessibility-enabled
check).

### 2.4 Relationship to counters

The notification is only about **liveness**; it carries no live counts. Block
counters (`today`/`total`) live natively in `ConfigStore` and ride the `blocked`
/ status events, and the content-counter widget/bubble is a separate surface
(see [17-content-counter.md](17-content-counter.md)). Nothing updates the
notification text after it is first posted.

---

## 3. Resilience: BootReceiver (log-only + OS auto-rebind)

`receivers/BootReceiver.kt` is intentionally minimal:

```kotlin
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        Log.i("DetoxoBoot", "received ${intent?.action}")
    }
}
```

It is registered in the manifest (exported, with `RECEIVE_BOOT_COMPLETED`
permission) for three actions:

- `android.intent.action.BOOT_COMPLETED`
- `android.intent.action.MY_PACKAGE_REPLACED` (after an app update)
- `android.intent.action.QUICKBOOT_POWERON` (OEM quick-boot)

**Why log-only:** an `AccessibilityService` that the user has enabled is
**re-bound automatically by the OS** after a reboot or package replacement — the
app does not (and cannot) manually start it. The receiver exists purely to log
these events (and gives a hook to later nudge the user to re-enable the service
if it was turned off). There is **no** date-changed receiver, no
`APP_COMMAND`-style broadcast entry point, and no manual service restart here —
runtime commands arrive over the `MethodChannel`, not broadcasts.

---

## 4. Resilience: Device Admin (optional uninstall protection)

Device Admin is **optional** and serves two purposes: (1) uninstall protection
while active, and (2) enabling the device-level `lockNow()` used by the
`LOCK_SCREEN` block mode.

### 4.1 Receiver & policy

`admin/DetoxoDeviceAdminReceiver.kt` extends `DeviceAdminReceiver` and only logs
its `onEnabled` / `onDisabled` transitions (no policy logic in code):

```kotlin
class DetoxoDeviceAdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent)  { Log.i("DetoxoAdmin", "device admin enabled") }
    override fun onDisabled(context: Context, intent: Intent) { Log.i("DetoxoAdmin", "device admin disabled") }
}
```

The declared policies live in `res/xml/device_admin_policies.xml`:

```xml
<uses-policies>
    <force-lock/>     <!-- allows lockNow() -->
    <watch-login/>
</uses-policies>
```

Manifest registration: the receiver is `exported="true"`, guarded by
`android.permission.BIND_DEVICE_ADMIN`, points at the `device_admin_policies`
meta-data, and filters `android.app.action.DEVICE_ADMIN_ENABLED`.

### 4.2 Request / query / remove flow (via MethodChannel)

The admin lifecycle is driven from Dart (the permissions feature) through
`channels/CommandHandler.kt`:

| Command | Native action |
|---|---|
| `isDeviceAdminActive` | `DevicePolicyManager.isAdminActive(ComponentName(DetoxoDeviceAdminReceiver))` |
| `requestDeviceAdmin` | launches `ACTION_ADD_DEVICE_ADMIN` with `EXTRA_DEVICE_ADMIN` + an `EXTRA_ADD_EXPLANATION` ("Enable to protect Detoxo from being uninstalled while active.") |
| `removeDeviceAdmin` | `DevicePolicyManager.removeActiveAdmin(...)` (wrapped in try/catch) |

### 4.3 How it is used at block time

`LOCK_SCREEN` is the only block mode that touches Device Admin. In the service:

```kotlin
fun lockScreen() {
    val dpm = getSystemService(DEVICE_POLICY_SERVICE) as DevicePolicyManager
    val admin = ComponentName(this, DetoxoDeviceAdminReceiver::class.java)
    if (dpm.isAdminActive(admin)) dpm.lockNow()   // guarded — no-op if admin off
}
```

Because it is guarded by `isAdminActive`, `LOCK_SCREEN` silently degrades to
nothing if the user never granted admin. Per `enums.dart`, `LOCK_SCREEN` is
**retained for wire/config compatibility but is no longer offered in the
block-mode picker**; the default block mode is `PRESS_BACK`
(`performGlobalAction(GLOBAL_ACTION_BACK)`), and `LOCK_APP` currently degrades to
a back press (native app-lock enforcement is a documented follow-up). See
[03-detection-engine.md](03-detection-engine.md) for the full block-mode
resolution.

---

## 5. Summary of what is and isn't shipped

| Capability | Status |
|---|---|
| Local block-event history (rolling ~500, buffer key `analytics_events`) | Shipped |
| Activity feed UI (tab + drawer route) | Shipped |
| Foreground-service notification (`detoxo_protection_channel`, id `1125`, special-use FGS) | Shipped |
| BootReceiver (log-only; OS auto-rebinds the accessibility service) | Shipped |
| Device Admin uninstall protection + `lockNow()` for `LOCK_SCREEN` | Shipped, optional/opt-in |
| Firebase / FCM push / remote crash+analytics upload | **Not bundled** (cloud sink is a planned swap-in behind `AnalyticsRepository`) |
| `LOCK_SCREEN` block mode UI | Retained on the wire, removed from the picker |

---

## Source files

- `lib/features/analytics/analytics.dart`
- `lib/features/analytics/domain/repositories/analytics_repository.dart`
- `lib/features/analytics/data/repositories/analytics_repository_impl.dart`
- `lib/features/analytics/presentation/analytics_cubit.dart`
- `lib/features/analytics/presentation/analytics_screen.dart`
- `lib/features/blocking/shared/domain/entities/engine_event.dart`
- `lib/features/blocking/shared/domain/entities/enums.dart`
- `lib/features/blocking/shared/domain/repositories/blocking_repositories.dart`
- `lib/features/blocking/shared/data/repositories/engine_repository_impl.dart`
- `lib/core/storage/local_store.dart`
- `lib/core/di/injector.dart`
- `android/app/src/main/kotlin/com/errorxperts/detoxo/accessibility/DetoxoAccessibilityService.kt`
- `android/app/src/main/kotlin/com/errorxperts/detoxo/receivers/BootReceiver.kt`
- `android/app/src/main/kotlin/com/errorxperts/detoxo/admin/DetoxoDeviceAdminReceiver.kt`
- `android/app/src/main/kotlin/com/errorxperts/detoxo/channels/CommandHandler.kt`
- `android/app/src/main/res/xml/device_admin_policies.xml`
- `android/app/src/main/AndroidManifest.xml`
