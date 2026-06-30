# Module: Background Workers & Receivers

## 1. Purpose & scope
All WorkManager jobs and the system `BroadcastReceiver`s that drive periodic/background behavior: config & scroll sync, event pruning, analytics heartbeats, FCM token save, permission monitoring, friends refresh, file ops, and the **midnight/date‑change reset**. **Owns:** schedules, constraints, backoff, and the calendar math. **Does NOT own:** the network calls themselves (see [module-10-networking-sync.md](module-10-networking-sync.md)) or DB schema (see [module-09-core-data-storage.md](module-09-core-data-storage.md)).

## 2. Migration verdict
**DART+CHANNEL.** Use the **`workmanager`** plugin to schedule/execute Dart callbacks (covers daily/6h/30min jobs). Two pieces stay native and are bridged: (a) the **`DateChangedReceiver`** system broadcasts (Flutter can't receive `DATE_CHANGED`/`TIME_SET`/`TIMEZONE_CHANGED`) → forwarded via `brainpal/system_events`; (b) `PermissionMonitorWorker`'s permission‑state checks → `brainpal/permissions`. iOS has no WorkManager — use BGTaskScheduler equivalents (see §6).

## 3. Business logic & algorithms (load‑bearing)

### 3.1 Worker cadence table (verbatim constants)
| Worker | Schedule / trigger | Constraints / backoff | What it does |
|---|---|---|---|
| `BlockConfigSyncWorker` | Daily (period 24h, initial delay **5 min**) **+** one‑time immediate (delay 0, backoff 1 min). WorkNames `brainrot_config_sync_worker_daily`/`_onetime` | network; retry on fail | Pull/push blocking config; requires non‑null `brUserId`; if `sync_trigger_type=DAILY` also runs daily sync |
| `ReelsSyncWorker` | Daily + one‑time immediate (same pattern). WorkNames `brainrot_scroll_sync_worker_daily`/`_onetime` | network; retry | Push scroll splits; updates widget (`qh.b.a()`); if DAILY refreshes reels widget |
| `ReelsEventsPruneWorker` | One‑time scheduled at **03:00** (next occurrence), 6h flex | gated on migration `REELS_EVENTS_TO_APP_SPLIT` done | Prune `reels_events` older than **`cutoff_days = 10`** |
| `DailyHeartbeatWorker` | Daily at **23:45** (next occurrence), 6h flex | — | Analytics heartbeat ping (`pc.j.a`) |
| `DailyDeviceImpactAnalyticsWorker` | Daily at **midnight** (next midnight + 86,400,000ms), 6h flex | — | Two sequential analytics tasks (`pc.h.a` then `pc.m.a`) |
| `PermissionMonitorWorker` | Periodic **every 6h** (`21,600,000ms`). WorkName `permission_monitor_periodic` (unique) | unique periodic | Check accessibility/overlay/notification perms; alert/re‑prompt on revoke |
| `FriendsUpdateWorker` | One‑time, initial delay **30 min**, flex **5 min**. WorkName `friends_update_worker_onetime` | — | Refresh friends/duel counts; on success `wc.h0.a()` (UI refresh) |
| `D1RetentionWorker` | On‑demand (via DateChangedReceiver / init) | — | Log D1 retention metric (`uc.h.D1_RETENTION_FIRED`) |
| `SaveFCMTokenWorker` | One‑time on FCM `onNewToken` (and app start) | — | `POST /auth/save_fcm_token` |
| `FileDeleteWorker` | On‑demand, input `fileName` | retry | Delete file from `getFilesDir()`; analytics success/fail/exception |
| `FileDownloadWorker` | On‑demand, input URL | backoff retry | Stream‑download file to app storage |
| `FeedbackUploadWorker` | On‑demand (feedback submit) | — | Poll for screenshot file up to **20 × 500ms = 10s**, then upload; returns success even if not found |

### 3.2 Calendar scheduling math (replicate exactly, timezone‑aware)
```
scheduleAt(hour, minute):
  next = today at hour:minute:00.000   // Calendar.set(11,h) set(12,m) set(13,0) set(14,0)
  if now > next: next += 1 day
  delaySeconds = (next.millis - now.millis + 999) / 1000   // ceil to seconds
```
- Heartbeat → 23:45. Prune → 03:00. Device‑impact → next midnight (`qb.a.X(now) + 86_400_000`, clamp ≥1ms).
- In Dart use timezone‑aware `DateTime`/`tz`; store the computed next‑run timestamp locally to survive clock skew; handle DST/timezone changes.

### 3.3 DateChangedReceiver (midnight reset)
- Intent filters: `android.intent.action.TIME_SET`, `DATE_CHANGED`, `TIMEZONE_CHANGED`.
- On receive → `dateChangeNotifier.q(...)` triggers an app‑level reset (reset daily counters, refresh sync schedules) and `goAsync()` for deferred work.
- **Vivo SDK 31–33 guard:** early‑return that skips the async `goAsync` coroutine (known OEM issue). Replicate the guard.

### 3.4 App‑startup scheduling sequence (`BrainRotApplication.b()`)
On launch, schedule: device‑impact analytics, heartbeat (23:45), prune (03:00), `PermissionMonitorWorker` (6h periodic), `FriendsUpdateWorker` (30min one‑time), `BlockConfigSyncWorker` (daily + immediate), `ReelsSyncWorker` (daily + immediate).

## 4. Data models
No own entities. Reads/writes: `reels_events` (prune), `user_blocking_config` (config sync), `daily_reels_app_split` (scroll sync), `migration_status` (prune gate), prefs (`brUserId`, `sync_trigger_type` = DAILY/IMMEDIATE, FCM token, last‑sync timestamps), files in app dir (feedback/file workers), WorkManager's own `WorkSpec` DB. Worker input data passed as `Map<String,dynamic>` (`sync_trigger_type`, `fileName`, `url`).

## 5. Android deps → Flutter map
| Android API | Verdict | Flutter | Notes |
|---|---|---|---|
| WorkManager `CoroutineWorker` (periodic/one‑time, constraints, backoff) | PKG | `workmanager` | `registerPeriodicTask`/`registerOneOffTask`; `flexInSeconds`, `initialDelay`, `backoffPolicy` |
| `DateChangedReceiver` (system broadcasts) | KEEP‑NATIVE + CHANNEL | native `BroadcastReceiver` → `brainpal/system_events` | Flutter can't receive these |
| `PermissionMonitorWorker` permission checks | DART + CHANNEL | `workmanager` callback + `brainpal/permissions` | state machine in Dart, checks via channel |
| FCM token refresh → save | PKG | `firebase_messaging.onTokenRefresh` → http | enqueue save |
| `Context.getFilesDir()` | PKG | `path_provider` (`getApplicationDocumentsDirectory`) | file workers |
| Analytics events (`mc.a.*`) | PKG | `firebase_analytics` (+ Mixpanel) | keep event names |
| Boot restart (`RECEIVE_BOOT_COMPLETED`) | KEEP‑NATIVE | native receiver re‑enqueues | `workmanager` persists across reboot but verify |

## 6. iOS strategy
No WorkManager. Map to **`BGAppRefreshTask` / `BGProcessingTask`** (BackgroundTasks framework) for the periodic syncs — but iOS gives **no guaranteed exact‑time execution** (no true 03:00/23:45 jobs). Strategy: opportunistic background refresh + a foreground catch‑up on app open that runs any missed daily rollups/prune based on stored "last run" timestamps. There is **no `DATE_CHANGED` broadcast** on iOS → use `UIApplication.significantTimeChangeNotification` (bridged) for the midnight/timezone reset. Document these as reduced‑fidelity on iOS.

## 7. Platform‑channel surface
- `brainpal/system_events` (Event, native→Dart): `DATE_CHANGED` / `TIME_SET` / `TIMEZONE_CHANGED` / `SCREEN_CAPTURED`.
- `brainpal/permissions` (Method, Dart→native): permission status queries used by `PermissionMonitorWorker`.
Full payloads in [01-platform-channel-contracts.md](01-platform-channel-contracts.md).

## 8. State management & DI
- `workmanager` callback dispatcher is a top‑level Dart entrypoint; inside it resolve `get_it` singletons (`SyncEngine`, repositories, analytics) — initialize DI inside the callback isolate.
- Riverpod: `ref.invalidate(...)` after sync workers complete to refresh dashboards (mirrors `wc.h0.a()`/`qh.b.a()` UI‑refresh callbacks).

## 9. User flows
1. **Launch** `[dart]`: schedule all jobs per §3.4.
2. **Midnight / date change** `[native→channel→dart]`: receiver fires → `system_events` → reset daily counters, reschedule day‑boundary jobs.
3. **03:00 prune** `[dart]`: if migration done, delete `reels_events` older than 10 days.
4. **6h permission monitor** `[dart+channel]`: check perms; if accessibility revoked → notification + re‑prompt.
5. **FCM token refresh** `[dart]`: `onTokenRefresh` → save token.
6. **Feedback submit** `[dart]`: poll screenshot (≤10s) → multipart upload.

## 10. Parity risks & validation
- **OEM survivability (Vivo/Xiaomi/Samsung/Huawei) + Doze:** replicate the Vivo 31–33 guard; test job execution after reboot, with battery optimization, and in Doze.
- **Exact‑time jobs:** WorkManager flex windows mean 03:00/23:45 are approximate — verify the daily reset still happens exactly once per day (idempotency keyed on date).
- **Migration gate:** prune must skip until `REELS_EVENTS_TO_APP_SPLIT` is done — test the gate.
- **DST/timezone:** simulate timezone + DST change; assert counters reset once and `stats_date` correct.
- **iOS fidelity:** document and test the foreground catch‑up path since background timing isn't guaranteed.

## 11. Open questions
- Where exactly `SaveFCMTokenWorker` is enqueued (FCM `onNewToken` assumed).
- Full `PermissionMonitorWorker` logic (~150 lines omitted): does it notify or only log?
- `FileDownloadWorker` URL source (API vs input data).
- Exact analytics event identifiers (`mc.a.f16542r2` etc.).
- Whether config/reels sync workers are also enqueued on‑demand vs only daily.
- `ka.l.f14430n` constraint contents (network + battery assumed).

## 12. Migration checklist (Phase 2)
- [ ] Set up `workmanager` dispatcher + DI bootstrap in the callback isolate.
- [ ] Port each worker with exact cadence/constraints from §3.1.
- [ ] Implement calendar math (23:45 / 03:00 / midnight) timezone‑aware with stored next‑run.
- [ ] Native `DateChangedReceiver` + `brainpal/system_events` bridge; Vivo guard.
- [ ] `PermissionMonitorWorker` (6h) using `brainpal/permissions`.
- [ ] Prune gate on `migration_status`; cutoff 10d.
- [ ] iOS BGTaskScheduler + significant‑time‑change + foreground catch‑up.
- [ ] OEM/Doze/reboot test matrix.
