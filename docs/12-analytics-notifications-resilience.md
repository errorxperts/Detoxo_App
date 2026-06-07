# Analytics, Notifications & Service Resilience

This document is the re-build blueprint for the three "supporting subsystems" of the short-form content blocker: (1) the **analytics pipeline** — a local block-event buffer in a SQL database, periodically batched to Firebase Analytics and/or a backend; (2) **notifications** — FCM push handling, the always-on foreground-service notification, and in-app notifications driven by remote config; and (3) **resilience / resurrection** — DeviceAdmin uninstall protection, boot + package-replaced + custom broadcast receivers that restart the core services, accessibility-status health broadcasts, and `onTaskRemoved` recovery. Each mechanism is mapped to a concrete Flutter package or a native `MethodChannel`/`EventChannel`, with iOS fallbacks. This is a blueprint for a new Flutter app: names below are our own clean Dart names; original decompiled paths are cited only as evidence.

> **Legend** — ✅ a pub.dev package handles it · ⚠️ needs a native MethodChannel/EventChannel (or manifest entry) · ❌ not possible on iOS.

---

## 0. Subsystem map at a glance

| Area | Original mechanism (evidence) | Flutter target | Legend |
|---|---|---|---|
| Block-event buffer | Room DB `shorts_block_history` table, `AnalyticsRepository.recordBlock` | `drift` (typed SQL) | ✅ |
| Session/focus tracking | Room `device_unlock_sessions`, `focus_unlock_sessions`, `unlocked_app_access` | `drift` | ✅ |
| Stat aggregation | `computeScrollingSessionStats` (30s / 240s thresholds) | pure Dart in repository | ✅ |
| Batch upload / sync | (inferred — separate worker, not in scope) | `workmanager` periodic task | ✅ |
| Cloud analytics events | Firebase Analytics (inferred `<platformId>_blocked`) | `firebase_analytics` | ✅ |
| Push messaging | `FirebaseNotificationReceiver extends FirebaseMessagingService` | `firebase_messaging` | ✅ |
| FGS persistent notification | id **1125**, channel `noscroll_protection_channel`, LOW importance | `flutter_foreground_task` + `flutter_local_notifications` | ⚠️ |
| In-app / local notifications | `NotificationHelper.sendNotification`, `NotificationEnum` channels | `flutter_local_notifications` | ✅ |
| Notification dismissal | `NotificationDismissBroadcastReceiver` → `NotificationManager.cancel(id)` | `flutter_local_notifications` `cancel(id)` | ✅ |
| Remote in-app config | `initial_config.json` `inappNotification[]` / `warningMessages[]` | `firebase_remote_config` + JSON model | ✅ |
| Uninstall protection | `NSDeviceAdminReceiver` + `device_admin_policies.xml` (`<disable-uninstall/>`) | native DeviceAdmin via MethodChannel + manifest | ⚠️ ❌ iOS |
| Boot / update restart | `SystemReceiver` (BOOT_COMPLETED, MY_PACKAGE_REPLACED, QUICKBOOT) | native BroadcastReceiver in Kotlin | ⚠️ ❌ iOS |
| Accessibility health | `AccessibilityStatusReceiver` (`...ACCESSIBILITY_SERVICE_STATUS_CHANGED`) | `EventChannel` stream | ⚠️ |
| Swipe-away recovery | `onTaskRemoved` → restart FGS | native service override | ⚠️ |

---

## 1. Analytics pipeline

### 1.1 What the original does (evidence)

The detection service writes one local row per block event; aggregation and (inferred) upload happen later. Verified in `analytics/AnalyticsRepository.java` and `analytics/db/AnalyticsDatabase.java` (4 DAOs, 4 tables).

**Room entities → our `drift` tables.** Field names taken directly from the decompiled entities:

| Original entity / table | Fields (verified) |
|---|---|
| `ShortsBlockHistoryEntity` → `shorts_block_history` | `id:long` (autoinc, `nullif(?,0)`), `timestamp:long`, `packageName:String`, `blockMode:String`, `planWhenBlocked:String`, `platformId:String`, `sessionId:String` |
| `DeviceUnlockSessionEntity` → `device_unlock_sessions` | `sessionId:String` (PK), `unlockedOn:long`, `lockedOn:long` |
| `FocusUnlockSessionEntity` → `focus_unlock_sessions` | `unlockId:String` (PK), `sessionId:String`, `unlockedOn:long`, `unlockedDurationMillis:long`, `unlockedAppPackage:String` |
| `UnlockedAppAccessEntity` → `unlocked_app_access` | `id:long` (autoinc), `unlockId:String`, `packageName:String`, `usedOn:long` |

Notable verified behaviors:
- Enums are stored as **strings**: `blockMode` is the `BlockingModesEnum` name (`PRESS_BACK` / `KILL_APP` / `LOCK_SCREEN` / `NONE`); `planWhenBlocked` is the `PlansEnum` name (`BLOCK_ALL` / `CURIOUS` / `ONE_REEL` / `PAUSED`).
- All writes use INSERT-only DAOs (INSERT OR ABORT); no UPDATE/DELETE exposed (verified: persistence notes "DELETEs/UPDATEs not exposed via DAOs").
- `recordBlock` first calls `ensureSessionExists(sessionId, timestamp)` (idempotent: query, insert `DeviceUnlockSession(sessionId, unlockedOn=timestamp, lockedOn=0)` if absent), then inserts the block row — both inside a Room transaction.
- `recordFocusUnlock` / `recordUnlockedAppAccess` validate non-empty ids and return early if blank.
- **Stat aggregation** `computeScrollingSessionStats` (verified algorithm): group block rows by `sessionId`; walk events; a session "closes" when `event.timestamp - previous.timestamp >= 30000ms`; accumulate a session's duration only if `>= 30000ms` (30s min threshold); count sessions whose duration `> 240000ms` (4 min) separately as "long scrolling" sessions; return `{sessionsCount, avgDurationMs = totalDurationMs / sessionsCount, totalDurationMs}`.
- **Batch upload / cloud events are inferred** — no REST call or Firebase Analytics call is visible in the analytics subsystem files ("No visible batch upload or REST API calls in current scope; analytics data is stored locally in Room and likely synced via a separate worker/repository"). The Firebase Analytics event naming `<platformId>_blocked` and the periodic upload worker are therefore **(inferred)** and are documented below as the recommended re-build approach, not as observed code.

### 1.2 Flutter design — Clean Architecture slices

```
domain/
  entities/block_event.dart
  entities/scrolling_session_stats.dart
  usecases/record_block_usecase.dart
  usecases/get_scrolling_stats_usecase.dart
  usecases/flush_analytics_usecase.dart
  repositories/analytics_repository.dart        // abstract
data/
  models/block_event_model.dart                 // freezed/json_serializable
  datasources/analytics_local_datasource.dart   // drift DB
  datasources/analytics_remote_datasource.dart  // firebase_analytics + backend
  repositories/analytics_repository_impl.dart
presentation/
  bloc/analytics_bloc.dart
```

#### 1.2.1 Entity & event schema

```dart
// domain/entities/block_event.dart
enum BlockingMode { pressBack, killApp, lockScreen, none }   // mirrors BlockingModesEnum names
enum Plan { blockAll, curious, oneReel, paused }             // mirrors PlansEnum names

class BlockEvent {
  final int? id;                 // autoincrement, null on insert (= nullif(?,0))
  final DateTime timestamp;
  final String packageName;      // e.g. com.instagram.android
  final BlockingMode blockMode;  // stored as enum NAME string
  final Plan planWhenBlocked;    // stored as enum NAME string
  final String platformId;       // Firebase platform id, e.g. "instagram_reels"
  final String sessionId;        // device unlock session id (UUID)

  const BlockEvent({
    this.id,
    required this.timestamp,
    required this.packageName,
    required this.blockMode,
    required this.planWhenBlocked,
    required this.platformId,
    required this.sessionId,
  });
}
```

Canonical event schema (what goes on the wire / into Firebase):

| Key | Type | Example | Source field |
|---|---|---|---|
| `timestamp` | epoch ms | `1717718400000` | `ShortsBlockHistoryEntity.timestamp` |
| `package_name` | string | `com.google.android.youtube` | `packageName` |
| `block_mode` | enum name | `PRESS_BACK` | `blockMode` |
| `plan` | enum name | `BLOCK_ALL` | `planWhenBlocked` |
| `platform_id` | string | `youtube_shorts` | `platformId` |
| `session_id` | uuid | `9b2a…` | `sessionId` |

#### 1.2.2 drift table (local buffer ✅)

```dart
// data/datasources/analytics_local_datasource.dart
@DataClassName('BlockEventRow')
class ShortsBlockHistory extends Table {
  IntColumn get id => integer().autoIncrement()();           // nullif(?,0) equivalent
  IntColumn get timestamp => integer()();                    // epoch ms
  TextColumn get packageName => text()();
  TextColumn get blockMode => text()();                      // enum NAME
  TextColumn get planWhenBlocked => text()();                // enum NAME
  TextColumn get platformId => text()();
  TextColumn get sessionId => text()();
  BoolColumn get uploaded => boolean().withDefault(const Constant(false))(); // our addition for batching
}
```

> We add an `uploaded` flag (not in the original schema) so the batch worker can mark rows after a successful flush. The original is INSERT-only; we keep DELETE/UPDATE confined to the upload worker.

#### 1.2.3 Stat aggregation in pure Dart (✅)

```dart
// domain/entities/scrolling_session_stats.dart
class ScrollingSessionStats {
  final int sessionsCount;
  final int avgDurationMs;
  final int totalDurationMs;
  final int longSessionsCount;   // sessions > 240000ms
  const ScrollingSessionStats(...);
}

// in repository impl — mirrors computeScrollingSessionStats (verified thresholds)
const minSessionMs = 30000;    // 30s: gap >= this closes a session; session ignored if < this
const longSessionMs = 240000;  // 4 min: counts toward "long scrolling"

ScrollingSessionStats compute(List<BlockEvent> events) {
  final bySession = groupBy(events, (e) => e.sessionId);
  var total = 0, count = 0, longCount = 0;
  for (final group in bySession.values) {
    group.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    var winStart = group.first.timestamp.millisecondsSinceEpoch;
    var prev = winStart;
    void close(int end) {
      final dur = end - winStart;
      if (dur >= minSessionMs) { total += dur; count++; if (dur > longSessionMs) longCount++; }
    }
    for (final e in group.skip(1)) {
      final t = e.timestamp.millisecondsSinceEpoch;
      if (t - prev >= minSessionMs) { close(prev); winStart = t; }
      prev = t;
    }
    close(prev);
  }
  return ScrollingSessionStats(
    sessionsCount: count,
    avgDurationMs: count == 0 ? 0 : total ~/ count,
    totalDurationMs: total,
    longSessionsCount: longCount,
  );
}
```

#### 1.2.4 Repository + cloud events

```dart
// data/repositories/analytics_repository_impl.dart
class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final AnalyticsLocalDataSource local;     // drift
  final AnalyticsRemoteDataSource remote;   // firebase_analytics + backend

  @override
  Future<void> recordBlock(BlockEvent e) async {
    await local.ensureSession(e.sessionId, e.timestamp); // idempotent insert
    await local.insertBlock(e);                          // local buffer (source of truth)
    // (inferred) cloud breadcrumb — fire-and-forget, never blocks the service
    unawaited(remote.logBlocked(e));
  }

  @override
  Future<int> flushPending() => _uploadUnsynced();        // called by workmanager
}

// remote: firebase_analytics ✅  (event name pattern is INFERRED)
class AnalyticsRemoteDataSource {
  final FirebaseAnalytics fa;
  Future<void> logBlocked(BlockEvent e) => fa.logEvent(
    name: '${e.platformId}_blocked',                      // e.g. instagram_reels_blocked  (inferred)
    parameters: {
      'block_mode': e.blockMode.name,
      'plan': e.planWhenBlocked.name,
      'package_name': e.packageName,
    },
  );
}
```

> **`recordBlock` must be non-blocking on the hot path.** In the original, blocks debounce at `now - lastBlockTime <= 1200ms` and the service runs in an isolated `:as_process` (see doc 03/11). In Flutter, the block decision happens in the native accessibility plugin; the Dart side receives the event over an `EventChannel` and persists asynchronously so DB I/O never stalls a `performGlobalAction(BACK)`.

#### 1.2.5 Batch upload (workmanager ✅, inferred mechanism)

```dart
// background isolate entrypoint
@pragma('vm:entry-point')
void analyticsCallbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task == 'flush_analytics') {
      final repo = await buildAnalyticsRepository(); // own DI in bg isolate
      final n = await repo.flushPending();           // uploads + marks uploaded=true
      return true;                                    // false => retry with backoff
    }
    return true;
  });
}

// registration (app start)
Workmanager().registerPeriodicTask(
  'flush_analytics', 'flush_analytics',
  frequency: const Duration(hours: 6),
  constraints: Constraints(networkType: NetworkType.connected),
  existingWorkPolicy: ExistingWorkPolicy.keep,
);
```

**iOS:** `workmanager` periodic tasks map to `BGAppRefreshTask` — opportunistic and OS-throttled, not guaranteed every 6h. `firebase_analytics` and `firebase_messaging` work normally. The local `drift` buffer also works normally; only the *cadence* of upload differs.

#### 1.2.6 AnalyticsBloc (presentation)

```dart
// presentation/bloc/analytics_bloc.dart
sealed class AnalyticsEvent {}
class BlockRecorded extends AnalyticsEvent { final BlockEvent e; BlockRecorded(this.e); }
class StatsRequested extends AnalyticsEvent { final DateTime since; StatsRequested(this.since); }

sealed class AnalyticsState {}
class AnalyticsLoading extends AnalyticsState {}
class AnalyticsLoaded extends AnalyticsState { final ScrollingSessionStats stats; AnalyticsLoaded(this.stats); }

class AnalyticsBloc extends Bloc<AnalyticsEvent, AnalyticsState> {
  final RecordBlockUseCase recordBlock;
  final GetScrollingStatsUseCase getStats;

  AnalyticsBloc(this.recordBlock, this.getStats) : super(AnalyticsLoading()) {
    on<BlockRecorded>((e, emit) => recordBlock(e.e));               // fire & forget persist
    on<StatsRequested>((e, emit) async {
      emit(AnalyticsLoading());
      emit(AnalyticsLoaded(await getStats(e.since)));
    });
  }
}
```

---

## 2. Notifications

### 2.1 FCM push (firebase_messaging ✅)

**Evidence.** `notifications/FirebaseNotificationReceiver.java` extends `FirebaseMessagingService`; `onMessageReceived(RemoteMessage)` spawns a coroutine on the IO dispatcher and dispatches on a `NotificationEnum` parsed from the payload. It injects a billing service, the DataStore, and home use-cases (Hilt) to (a) check premium status, (b) read PIN config, (c) update platform preferences from the message. The full handler body is heavily obfuscated (≈2322 bytecode units in `AnonymousClass1.invokeSuspend()`), so **the exact payload field names are inferred**; what is verified is the *set of behaviors* and the `NotificationEnum` it switches on.

**Verified channel IDs / names** (`notifications/NotificationEnum.java`):

| Enum constant | `notificationId` | `notificationName` |
|---|---|---|
| `SCROLLING_ALERTS` | `8795293` | `Doom Scrolling Alerts` |
| `NOSCROLL_PLAY_STORE` | `8795288` | `App Update` |
| `OFFERS_AND_PROMOTIONS` | `8795289` | `Offers and Promotions` |
| `FEATURE_ALERTS` | `8795290` | `New Feature Alerts` |
| `MISCELLANEOUS` | `8795292` | `Miscellaneous` |
| `NOSCROLL_ACCESSIBILITY_SCHEDULE` | `8795291` | `Service Stop Alerts` |
| `NO_SCROLL_STATUS` | `1125` | `NoScroll Service Status` |

> `NO_SCROLL_STATUS = 1125` is the **foreground-service** notification id (matches the verified FGS id 1125 in `NoScrollAccessibilityService`). The other six are user-facing channels.

**Verified dispatch branches** (from `analytics-and-notifications.json` workflow):
- `SCROLLING_ALERTS` → check premium status, possibly log event.
- `FEATURE_ALERTS` → show in-app notification, parse deeplink / CTA URL.
- `NOSCROLL_ACCESSIBILITY_SCHEDULE` → if accessibility enabled, stop `AppMonitorService` as needed ("Service Stop Alerts" = scheduled service pause).
- `NO_SCROLL_STATUS` → service status update (restart / stop).
- others → general in-app notification with priority / dismissible flags from `initial_config.json`.
- Side effects each message: `checkAppLockerServiceStatus()` (stop `AppMonitorService` based on PIN config — `PIN_RESTRICTED_SECTIONS_ENUM.APP_LOCKER` / `SETTINGS_APP`), `checkPremiumStatus()`, `updatePlatformPreferences()` (sync remote config → DataStore).

**Flutter handler sketch:**

```dart
// data/datasources/fcm_handler.dart

// must be top-level / static for background isolate
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationDispatcher.handle(message);   // own clean dispatcher
}

class NotificationDispatcher {
  static const _channelById = {
    8795293: NotificationChannelSpec('scrolling_alerts', 'Doom Scrolling Alerts', Importance.defaultImportance),
    8795290: NotificationChannelSpec('feature_alerts',   'New Feature Alerts',    Importance.defaultImportance),
    8795289: NotificationChannelSpec('offers',           'Offers and Promotions', Importance.low),
    8795292: NotificationChannelSpec('miscellaneous',    'Miscellaneous',         Importance.low),
    8795291: NotificationChannelSpec('service_schedule', 'Service Stop Alerts',   Importance.low),
    8795288: NotificationChannelSpec('play_store',       'App Update',            Importance.defaultImportance),
    1125:    NotificationChannelSpec('noscroll_protection_channel', 'NoScroll Service Status', Importance.low),
  };

  static Future<void> handle(RemoteMessage m) async {
    // payload field names INFERRED — original handler obfuscated
    final type = NoticeType.fromKey(m.data['type'] ?? '');
    switch (type) {
      case NoticeType.scrollingAlert:   await _maybeShowIfNotPremium(m); break;
      case NoticeType.featureAlert:     await _show(m, deeplink: m.data['cta']); break;
      case NoticeType.serviceSchedule:  await _maybeStopAppMonitor(m); break;   // ⚠️ native channel
      case NoticeType.serviceStatus:    await _refreshServiceStatus();          break; // ⚠️ native
      default:                          await _show(m); break;
    }
    await _syncPlatformPreferences(m); // updatePlatformPreferences() equivalent
  }
}
```

```dart
// app start
FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
FirebaseMessaging.onMessage.listen(NotificationDispatcher.handle);
FirebaseMessaging.instance.subscribeToTopic('all_users'); // topics inferred
```

**iOS:** `firebase_messaging` supports FCM via APNs. Data-only messages do **not** wake the app reliably in the background unless `content-available: 1` is set, and the OS still throttles. Branches that "stop a native service" (`serviceSchedule`, `serviceStatus`) are **❌ no-ops on iOS** — there is no equivalent background service to stop; the iOS build should ignore those types.

### 2.2 Foreground-service notification (id 1125) — flutter_foreground_task ⚠️

**Evidence (verified, see doc 11):** FGS notification id `1125`, channel `noscroll_protection_channel`, **LOW** importance; FGS `specialUse` type on API 34+; service runs in isolated `:as_process`. This notification is the OS contract that keeps the detection process alive.

```dart
// resilience/foreground_service.dart  (uses flutter_foreground_task)
await FlutterForegroundTask.init(
  androidNotificationOptions: AndroidNotificationOptions(
    channelId: 'noscroll_protection_channel',
    channelName: 'NoScroll Service Status',
    channelImportance: NotificationChannelImportance.LOW, // verified LOW
    priority: NotificationPriority.LOW,
    serviceTypes: [ForegroundServiceTypes.specialUse],    // API 34+ specialUse (verified)
  ),
  foregroundTaskOptions: ForegroundTaskOptions(
    eventAction: ForegroundTaskEventAction.repeat(5000),
    autoRunOnBoot: true,        // see §3
    allowWakeLock: true,
  ),
);
```

> Keep the persistent notification's id aligned to **1125** in the native layer if you also hand-roll the AccessibilityService (recommended — see doc 11), so the accessibility service and `flutter_foreground_task` do not fight over channel/notification ownership. The real detection in this app lives in the native AccessibilityService; `flutter_foreground_task` is the convenient way to host the Dart-side keep-alive + the persistent notification.

**iOS:** ❌ no foreground service / persistent notification concept. The closest is a silent-push keep-alive or `BGProcessingTask`, neither of which keeps a process resident. Document this as "Android-only".

### 2.3 In-app & local notifications (flutter_local_notifications ✅)

**Evidence.** `NotificationHelper.sendNotification()` (singleton) builds notifications and **respects per-type DataStore preferences** (dismissible flag, priority). `NotificationDismissBroadcastReceiver` (NOT exported) calls `NotificationManager.cancel(notificationId)`. Content for in-app notices comes from `initial_config.json`:
- `inappNotification[]` — entries with `dismissible`, `priority`, and CTA actions of type `URL` / `NOTIFICATION` / `RATING` / `ACCESSIBILITY` (verified in notes/interactions).
- `warningMessages[]` — **non-dismissible** alerts for accessibility-off and battery-optimization.

The doc prompt names three in-app types — **FEEDBACK / RATING / PERMISSION** — driven by `initial_config` with dismissal flags. Map them to the verified CTA action set:

| In-app type | Verified CTA action(s) | Dismissible? | Source |
|---|---|---|---|
| RATING | `RATING` | yes | `inappNotification[].cta` |
| FEEDBACK | `URL` / `NOTIFICATION` | yes | `inappNotification[]` |
| PERMISSION | `ACCESSIBILITY` | **no** (warning) | `warningMessages[]` (accessibility / battery) |

```dart
// data/models/in_app_notification_model.dart  (parsed from initial_config.json)
enum CtaAction { url, notification, rating, accessibility }   // verified action set

class InAppNotificationSpec {
  final String id;
  final String title;
  final String description;
  final bool dismissible;          // verified flag
  final int priority;              // verified flag
  final CtaAction cta;
  final String? ctaPayload;        // url / deeplink
  // fromJson(...) maps initial_config keys
}
```

```dart
// data/datasources/local_notifications.dart
final _fln = FlutterLocalNotificationsPlugin();

Future<void> showInApp(InAppNotificationSpec s) {
  final ch = _channelFor(s);  // pick channel by mapped NotificationEnum id
  return _fln.show(
    s.id.hashCode, s.title, s.description,
    NotificationDetails(android: AndroidNotificationDetails(
      ch.id, ch.name,
      importance: s.priority >= 1 ? Importance.high : Importance.low,
      ongoing: !s.dismissible,         // non-dismissible warning => ongoing
      autoCancel: s.dismissible,
    )),
    payload: '${s.cta.name}:${s.ctaPayload ?? ''}',
  );
}

// dismissal == NotificationDismissBroadcastReceiver.cancel(id)
Future<void> dismiss(int id) => _fln.cancel(id);
```

**Consumed-notification tracking:** the original persists shown/consumed notices in the `CONSUMED_NOTIFICATIONS` DataStore key (verified in persistence `PrefKeys`). Mirror it with a `Set<String>` of consumed ids in our settings store so dismissible one-shots (RATING/FEEDBACK) are not re-shown; also gate RATING via `ASKED_FOR_REVIEW` / `LAST_REVIEW_REQUEST_TIMESTAMP` keys (verified) using the `in_app_review` package.

**iOS:** `flutter_local_notifications` works (request `DarwinNotificationDetails` permissions). `ongoing/autoCancel` semantics differ — iOS has no true "non-dismissible" notification; render PERMISSION warnings as an in-app banner widget instead.

---

## 3. Resilience / resurrection

This is the hardest part to reproduce in Flutter — every mechanism is native Android. iOS has **no equivalent** to any of it; the only Apple parental-control surface is FamilyControls / DeviceActivity / ManagedSettings (restricted entitlement), noted per item.

### 3.1 DeviceAdmin uninstall protection (⚠️ native, ❌ iOS)

**Evidence.** `service/deviceadmin/NSDeviceAdminReceiver.java extends DeviceAdminReceiver`; `device_admin_policies.xml` declares exactly one policy:

```xml
<device-admin>
  <uses-policies>
    <disable-uninstall/>      <!-- only capability declared -->
  </uses-policies>
</device-admin>
```

Verified callback behavior:
- `onDisableRequested(...)` returns the literal warning string `"Are you sure you want to disable this device administrator?"`.
- `onEnabled`, `onDisabled`, `onPasswordSucceeded`, `onLockTask*` are no-ops (super only).

While the app is an active device admin, **the user cannot uninstall** it (Play/Settings uninstall is blocked) until they first revoke device admin. There is no `lock-device`, `wipe-data`, or password policy — only uninstall blocking.

**Flutter:** No pub package. Implement natively:
1. Add `NSDeviceAdminReceiver.kt` (or your own `UninstallGuardAdminReceiver`) + `res/xml/device_admin_policies.xml` with `<disable-uninstall/>`.
2. Manifest receiver with `android.permission.BIND_DEVICE_ADMIN` and `<action android:name="android.app.action.DEVICE_ADMIN_ENABLED"/>`.
3. A `MethodChannel('app/device_admin')` exposing `requestAdmin()` (launch `ACTION_ADD_DEVICE_ADMIN`), `isAdminActive()`, `removeAdmin()`.

```dart
class DeviceAdminGuard {
  static const _ch = MethodChannel('app/device_admin');
  Future<bool> isActive()   => _ch.invokeMethod<bool>('isAdminActive').then((v) => v ?? false);
  Future<void> request()    => _ch.invokeMethod('requestAdmin');   // user confirms in system UI
  Future<void> revoke()     => _ch.invokeMethod('removeAdmin');    // required before uninstall
}
```

**iOS:** ❌. No uninstall protection exists. With Screen Time / FamilyControls + a Supervised/MDM profile you can hide or block app removal, but that requires Apple's restricted `com.apple.developer.family-controls` entitlement and is not a 1:1 substitute. Document as "Android-only; iOS uninstall cannot be blocked outside MDM/Supervision".

### 3.2 Boot, package-replaced & QUICKBOOT restart (⚠️ native, ❌ iOS)

**Evidence.** `service/receivers/SystemReceiver.java` (a `BroadcastReceiver`) handles, by exact action string:
- `android.intent.action.BOOT_COMPLETED`
- `android.intent.action.MY_PACKAGE_REPLACED`
- `android.intent.action.QUICKBOOT_POWERON`
- `com.htc.intent.action.QUICKBOOT_POWERON`

Verified logic: if `AccessibilityServiceHelper.isAccessibilityServiceEnabled(ctx, NoScrollAccessibilityService.class)` → `startForegroundService(NoScrollAccessibilityService)` ("Nudging..."); **always** `startForegroundService(AppMonitorService)`; each wrapped in try/catch with `Log.e`. Note: the receiver is **exported** (any app may send these broadcasts — low security, see notes).

**Flutter:** no pub package replaces a manifest `BroadcastReceiver`. Re-create natively:

```xml
<!-- AndroidManifest.xml -->
<receiver android:name=".resilience.SystemReceiver" android:exported="true">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED"/>
    <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
    <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
    <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
  </intent-filter>
</receiver>
```
Requires `<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>`. `flutter_foreground_task`'s `autoRunOnBoot: true` covers its own keep-alive task, but the **AccessibilityService** itself is re-enabled by the OS only if previously granted — the receiver's job is to `startForegroundService` so the Dart engine / monitor re-attaches. Consider `android:exported="false"` for the receiver to fix the original's security smell (the original is exported; we improve on it).

**iOS:** ❌. No boot broadcast, no auto-relaunch on reboot or update. The app simply will not run until the user opens it. Document as Android-only.

### 3.3 Accessibility health broadcasts (⚠️ EventChannel)

**Evidence.** `service/broadcastlisteners/AccessibilityStatusReceiver.java` listens to custom action **`com.newswarajya.noswipe.reelshortblocker.ACCESSIBILITY_SERVICE_STATUS_CHANGED`** (verified) with boolean extra **`extra_accessibility_service_enabled`** (verified in core facts) and fires an `onEventReceived` callback to refresh UI / restart logic. (Receiver is exported.)

**Flutter:** surface this as a stream over an `EventChannel`. The native side registers the `BroadcastReceiver`, the plugin (or your channel) pushes the boolean to Dart.

```dart
class AccessibilityHealth {
  static const _events = EventChannel('app/accessibility_status');
  Stream<bool> get enabledStream =>
      _events.receiveBroadcastStream().map((e) => e as bool);
}

// presentation: subscribe and update a "service health" bloc state,
// prompt the PERMISSION in-app warning (§2.3) when it flips to false.
```

`flutter_accessibility_service` exposes `isAccessibilityPermissionEnabled()` for polling; pair it with the broadcast stream for push updates. iOS: ❌ no AccessibilityService → no equivalent; hide the health indicator.

### 3.4 Swipe-away recovery — onTaskRemoved (⚠️ native)

**Evidence (verified, doc 11):** `onTaskRemoved` restarts the foreground service (resurrection); `onKeyEvent` BACK closes the ONE_REEL overlay. Re-create in the native service override (`flutter_foreground_task` keeps the FGS sticky; for the AccessibilityService, override `onTaskRemoved` to re-`startForegroundService`). iOS: ❌.

### 3.5 Resilience checklist (re-build acceptance)

| # | Requirement | Mechanism | Verify by |
|---|---|---|---|
| 1 | Service survives reboot | `SystemReceiver` BOOT_COMPLETED + `autoRunOnBoot` | Reboot → confirm FGS notif 1125 returns |
| 2 | Service survives app update | `SystemReceiver` MY_PACKAGE_REPLACED | Reinstall over → service auto-starts |
| 3 | Service survives swipe-away | `onTaskRemoved` → restart FGS | Swipe from recents → notif persists |
| 4 | Uninstall blocked when armed | DeviceAdmin `<disable-uninstall/>` | Try uninstall → blocked until admin revoked |
| 5 | UI reacts to service on/off | broadcast `...ACCESSIBILITY_SERVICE_STATUS_CHANGED` + extra `extra_accessibility_service_enabled` over EventChannel | Toggle accessibility → UI + PERMISSION warning update |
| 6 | Persistent notif is LOW + correct channel | id 1125, `noscroll_protection_channel`, LOW | Inspect channel importance |
| 7 | FGS uses specialUse on API 34+ | `serviceTypes: [specialUse]` | Launch on Android 14 device |
| 8 | Battery-optimization warning shown | `warningMessages[]` PERMISSION (non-dismissible) | Disable exemption → ongoing warning appears |
| 9 | Block events buffered offline | `drift` insert, no network needed | Airplane mode → block → row present |
| 10 | Batched upload + marks uploaded | `workmanager` flush, `uploaded=true` | Re-enable network → rows flush, flag set |

---

## 4. Pub package summary

| Concern | Package | Legend |
|---|---|---|
| Local event buffer / stats DB | `drift` | ✅ |
| Settings / consumed-notifications / GDPR flags | `flutter_secure_storage` + `shared_preferences` | ✅ |
| Batch upload worker | `workmanager` | ✅ (iOS throttled) |
| Cloud analytics events | `firebase_analytics` | ✅ |
| Push messaging | `firebase_messaging` | ✅ |
| Remote in-app config | `firebase_remote_config` | ✅ |
| Local / in-app notifications + dismiss | `flutter_local_notifications` | ✅ |
| Foreground service + persistent notif | `flutter_foreground_task` | ⚠️ |
| Accessibility detection + permission state | `flutter_accessibility_service` | ⚠️ |
| In-app review (RATING CTA) | `in_app_review` | ✅ |
| DeviceAdmin uninstall guard | none — native MethodChannel + manifest | ⚠️ ❌ iOS |
| Boot / package-replaced restart | none — native BroadcastReceiver | ⚠️ ❌ iOS |
| Accessibility health push | native EventChannel | ⚠️ ❌ iOS |
| State management / DI | `flutter_bloc`, `get_it` | ✅ |

---

## Source evidence

- `sources/com/newswarajya/noswipe/reelshortblocker/analytics/AnalyticsRepository.java` — `recordBlock`, `ensureSessionExists`, `recordFocusUnlock`, `recordUnlockedAppAccess`, `computeScrollingSessionStats` (30000ms / 240000ms thresholds).
- `sources/com/newswarajya/noswipe/reelshortblocker/analytics/db/AnalyticsDatabase.java` and `analytics/db/entity/{ShortsBlockHistoryEntity,DeviceUnlockSessionEntity,FocusUnlockSessionEntity,UnlockedAppAccessEntity}.java` — table/field names, INSERT-only DAOs.
- `sources/com/newswarajya/noswipe/reelshortblocker/notifications/NotificationEnum.java` — channel ids 8795293/8795288/8795289/8795290/8795292/8795291/1125 and names (read directly).
- `sources/com/newswarajya/noswipe/reelshortblocker/notifications/{FirebaseNotificationReceiver,NotificationHelper,NotificationDismissBroadcastReceiver}.java` — FCM dispatch (handler body obfuscated → inferred), `sendNotification`, `cancel(id)`.
- `sources/com/newswarajya/noswipe/reelshortblocker/service/deviceadmin/NSDeviceAdminReceiver.java` + `resources/res/xml/device_admin_policies.xml` — `<disable-uninstall/>`, `onDisableRequested` literal string (read directly).
- `sources/com/newswarajya/noswipe/reelshortblocker/service/receivers/SystemReceiver.java` — BOOT_COMPLETED / MY_PACKAGE_REPLACED / QUICKBOOT actions, `startForegroundService` for `NoScrollAccessibilityService` + `AppMonitorService` (read directly).
- `sources/com/newswarajya/noswipe/reelshortblocker/service/broadcastlisteners/AccessibilityStatusReceiver.java` — `...ACCESSIBILITY_SERVICE_STATUS_CHANGED` custom action.
- `resources/res/raw/initial_config.json` — `inappNotification[]` (`dismissible`, `priority`, CTA `URL`/`NOTIFICATION`/`RATING`/`ACCESSIBILITY`), `warningMessages[]`.
- Cached analysis: `/tmp/ns_analysis/analytics-and-notifications.json`, `/tmp/ns_analysis/persistence.json`.
- FGS facts (id 1125, channel `noscroll_protection_channel` LOW, specialUse, `:as_process`, `onTaskRemoved`) cross-referenced from `service/accessibility/NoScrollAccessibilityService.java` (verified core facts).

## Related docs

- `03-accessibility-service-runtime.md`
- `11-foreground-service-and-process-model.md`
- `10-persistence-datastore-and-room.md`
- `08-remote-config-and-platforms-config.md`
- `09-billing-and-premium-gating.md`
- `13-permissions-and-onboarding.md`
