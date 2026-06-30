# 01 — Platform-Channel Contracts (THE SEAM)

> **Status:** FROZEN CONTRACT v1. This file is the single source of truth for the
> Dart ⇄ native boundary of the BrainPal Flutter migration. Every per-module doc
> (`03-*` … `NN-*`) cross-references channel names from here verbatim. **Do not
> rename a channel, method, event, or payload key without bumping the contract
> version (§Contract Versioning) and updating every consumer.**

---

## 0. Why this seam exists

BrainPal (`com.brainrot.android`, v7.1.340) is **~70 % an OS-integration app**.
The following capabilities have **no Dart equivalent** and are retained as a
near-verbatim **native Kotlin "detection/overlay core"**:

| Native capability | Decompiled origin | Dart-portable? |
|---|---|---|
| AccessibilityService reel detection + node-tree parsing | `services/ReelsAccessibilityService.java`, `xh/*.java`, `b7/l.java`, `wh/x.java` | **No** — must stay native |
| `TYPE_APPLICATION_OVERLAY` block overlays | `BlockReelsOverlayActivity.java`, `PermissionStepsOverlayActivity.java`, `RatingPromptOverlayActivity.java` | **No** |
| Foreground floating bubble (multi-window + spring physics) | `floating_bubble/ReelsCounterFloatingService.java`, `wo/*.java`, `yo/*.java` | **No** (`flutter_overlay_window` rejected: cannot do multi-window + spring) |
| Glance home-screen widgets | `feature_widget/presentation/widget/*.java`, `sh/*.java` | **No** |
| NFC / sensor unlock challenges | `be/p.java`, `ee/u.java`, strings `block_reels_nfc_*` | **No** |
| System broadcasts (date/time change) | `core/receiver/DateChangedReceiver.java` | **No** |
| Screen-capture detection (API 34+) | `MainActivity.java` `ScreenCaptureCallback` | **No** |

The Flutter app owns: in-app UI (Riverpod v2), the domain layer (pure Dart),
data/sync (dio + retrofit, drift, secure storage), and orchestration. The two
halves talk **only** through the channels below. **No business logic crosses the
seam in raw form** — native emits *facts* (detection events, permission
transitions); Dart emits *commands* (show overlay, start challenge).

> **iOS reality (applies to the whole seam):** On iOS the Android-style
> AccessibilityService / overlay-window / Glance-widget model **does not exist**.
> The detection+blocking core is re-implemented on Apple's **Screen Time API**
> (`FamilyControls` + `DeviceActivity` + `ManagedSettings` + `ShieldUI`). The
> **same channel names and payload schemas are reused** so the Dart domain layer
> is platform-agnostic, but the native fronting classes differ (Swift
> `DeviceActivityMonitor` extension, `ManagedSettingsStore`, `ShieldConfiguration`
> provider) and several Android-only events/methods are **inert no-ops on iOS**
> (flagged per channel below). See [09-ios-screentime-strategy.md](99-native-retained-modules.md).

---

## 1. Channel inventory (canonical namespace)

| # | Channel | Type | Direction | Native fronting class (Android) | iOS fronting | Purpose |
|---|---|---|---|---|---|---|
| 1 | `brainpal/detection` | Event | native→Dart | `services/ReelsAccessibilityService.java` (+ `wh/x.java`, `xh/a.java`) | `DeviceActivityMonitor` ext | reel detection events |
| 2 | `brainpal/overlay` | Method | Dart→native | `BlockReelsOverlayActivity.java`, `floating_bubble/ReelsCounterFloatingService.java` | `ManagedSettingsStore` / `ShieldConfiguration` | show/hide/update/setMode overlay + bubble |
| 3 | `brainpal/overlay_events` | Event | native→Dart | `BlockReelsOverlayActivity.java`, `floating_bubble/ReelsCounterFloatingService.java`, `yo/b.java` | Shield action extension | overlay tap / dismiss / challenge-completed / pause-requested |
| 4 | `brainpal/accessibility` | Method | Dart→native | `services/ReelsAccessibilityService.java`, `feature_permission/*` | FamilyControls authz | isServiceEnabled / openSettings / serviceStatus |
| 5 | `brainpal/accessibility_status` | Event | native→Dart | `services/ReelsAccessibilityService.java` `onServiceConnected`/`onUnbind` | FamilyControls authz observer | enabled/disabled transitions |
| 6 | `brainpal/widgets` | Method | Dart→native | `feature_widget/presentation/widget/*.java`, `qh/a.java`, `sh/x.java` | WidgetKit `WidgetCenter` | pushWidgetData / requestPinWidget / refresh |
| 7 | `brainpal/permissions` | Method | Dart→native | `PermissionStepsOverlayActivity.java`, `core/worker/PermissionMonitorWorker.java` | system authz APIs | check/request overlay, battery-opt, device-admin, notifications |
| 8 | `brainpal/permission_status` | Event | native→Dart | `core/worker/PermissionMonitorWorker.java` | authz observers | permission grant/revoke transitions |
| 9 | `brainpal/system_events` | Event | native→Dart | `core/receiver/DateChangedReceiver.java`, `MainActivity.java` (`ScreenCaptureCallback`) | `NotificationCenter` (significant time change) | DATE_CHANGED / TIME_SET / TIMEZONE_CHANGED / SCREEN_CAPTURED |
| 10 | `brainpal/challenges` | Method | Dart→native | `be/p.java`, `ee/u.java`, sensors/NFC native | sensors/NFC native | start/cancel unlock challenge |
| 11 | `brainpal/challenge_events` | Event | native→Dart | `be/p.java`, `ee/u.java` | sensors/NFC native | challenge progress / completed / failed |

**Encoding:** all channels use `StandardMethodCodec` (default). Payloads are
JSON-shaped `Map<String, Object?>` (Kotlin) / `[String: Any?]` (Swift) /
`Map<String, dynamic>` (Dart). Timestamps are **epoch milliseconds**
(`System.currentTimeMillis()` on Android — confirmed `ReelsScrollEvent.eventTimestamp`,
`MainActivity` etc.) carried as `int` (Dart) / `Long` (Kotlin). No protobuf, no
custom codec crosses the seam.

---

## 2. `brainpal/detection` — EventChannel (native→Dart)

**Purpose:** stream of reel/short detection facts produced by the
AccessibilityService node-tree parsers. This is the **highest-frequency** stream;
debounce/throttle lives natively (Android 500 ms accessibility coalescing) **and**
must be re-applied in Dart (see §2.4).

**Native source of truth.** The native payload is assembled from
`xh.a` ("DetectionData", `sources/xh/a.java`) merged with the foreground package
and a server-event tuple `ReelsScrollEvent`
(`feature_reels_counter/domain/model/ReelsScrollEvent.java`). Verbatim native fields:

`xh.a` (DetectionData):
```
boolean f27709a  // isDetected
String  f27710b  // videoIdentifier  (NULLABLE)
boolean f27711c  // isPanelOpen
boolean d        // isAd
```
`ReelsScrollEvent`:
```
String androidDeviceId    // non-null
String brUserId           // NULLABLE (hashCode treats null-safe)
long   eventTimestamp     // System.currentTimeMillis()
String appId              // non-null, package name
long   viewDurationMillis
```

### 2.1 Event payload schema — `DetectionEvent`

| Key | Type | Req? | Meaning / source |
|---|---|---|---|
| `appId` | `String` | **required** | foreground package; one of the 6 monitored packages (see §2.3). From `event.getPackageName()` / `ReelsScrollEvent.appId`. |
| `videoId` | `String` | nullable | `xh.a.f27710b` (`videoIdentifier`). Formats: `""`, `ch_<handle>_<title≤30>`, `ch_<handle>`, `<title≤40>` (YouTube, `xh/e.java`); `snapchat_spotlight_<hash|ts/10000>`, prefixed `snapchat_spotlight_ad_` for ads (`xh/d.java`). `null` when parser found no content. |
| `isAd` | `bool` | **required** | `xh.a.d`. CTA-keyword heuristic per app. |
| `isPanelOpen` | `bool` | **required** | `xh.a.f27711c`. YouTube engagement/bottom-sheet panel open; affects whether the overlay should fire. |
| `viewDurationMs` | `int` | **required** | `ReelsScrollEvent.viewDurationMillis` — ms on the single reel/short. May be `0` for the first detection of a new reel. |
| `ts` | `int` | **required** | epoch ms (`eventTimestamp`). |
| `isDetected` | `bool` | optional | `xh.a.f27709a`. Native should only emit events with `isDetected == true`; kept in the schema so Dart can assert. **Default `true` if absent.** |

```jsonc
// example DetectionEvent
{
  "appId": "com.instagram.android",
  "videoId": "ch_@natgeo_lions of the serengeti at dusk",
  "isAd": false,
  "isPanelOpen": false,
  "viewDurationMs": 0,
  "ts": 1751299200000,
  "isDetected": true
}
```

### 2.2 NOT carried on this channel (stays native)

Screen-geometry / bounds math (`(left+right)/2` clustering, `0.75 * screenWidth`
threshold in `b7/l.java`), the 1500-node BFS, view-ID strings
(`com.google.android.youtube:id/reel_recycler`, `watch_panel_scrim`,
`com.snapchat.android:id/spotlight_container`), and the CTA/UI-label blocklists.
Dart receives **only the distilled fact**. See [03-reels-detection-core.md](module-01-reels-detection-core.md).

### 2.3 Monitored packages (verbatim — `kc/a.java`)

```
f14465b = [ "com.zhiliaoapp.musically",   // TikTok (musically / global)
            "com.ss.android.ugc.trill",   // TikTok (trill variant)
            "com.google.android.youtube",
            "com.instagram.android",
            "com.snapchat.android",
            "com.facebook.katana" ]
f14464a = { "com.zhiliaoapp.musically", "com.ss.android.ugc.trill" } // TikTok special-case set
```
`appId` on a `DetectionEvent` is always a member of `f14465b`.

### 2.4 Threading / lifecycle / error semantics

- **Producer thread:** Android AccessibilityService main thread → coroutine
  (`wh/x.java` `ReelsScrollManager` uses a `Channel`/`Flow`). Events are
  marshalled to the platform-channel via the main looper. **Sink must be set on
  the Flutter UI isolate's main thread.**
- **Backpressure:** native applies the 500 ms `notificationTimeout`
  (`accessibility_service_config.xml`). Dart **must additionally** `debounce`/
  `throttle` (Riverpod stream operator) — see §2 note. Recommended: collapse
  duplicate `(appId, videoId)` within 750 ms.
- **Lifecycle:** the stream is live only while the AccessibilityService is bound.
  On service unbind it silently stops; Dart learns via
  `brainpal/accessibility_status` (§5), **not** via an error on this channel.
- **`onError`:** reserved for native marshalling failures only (parser exceptions
  are swallowed natively and produce no event). Error code namespace: `DET_*`.
- **iOS:** emitted from the `DeviceActivityMonitor` extension on
  `eventDidReachThreshold` / `intervalDidStart`. iOS **cannot** populate
  `videoId`, `isAd`, `isPanelOpen`, or `viewDurationMs` (Screen Time exposes app
  tokens, not content). On iOS: `videoId=null`, `isAd=false`, `isPanelOpen=false`,
  `viewDurationMs=0`; `appId` is a stable opaque mapping of the
  `ApplicationToken`. Dart must treat these fields as **best-effort / platform-
  conditional**.

---

## 3. `brainpal/overlay` — MethodChannel (Dart→native)

**Purpose:** command the native block overlay (`BlockReelsOverlayActivity`) and
the floating bubble (`ReelsCounterFloatingService`, FGS id **9001**, channel
`reels_counter_bubble`, title "Shorts Counter"). Overlay windows use
`TYPE_APPLICATION_OVERLAY` (2038 on API 26+, 2002 fallback); bubble flags
`262664`. **Requires `SYSTEM_ALERT_WINDOW`** — Dart must gate every call on
`brainpal/permissions.check("overlay")` (native fast-fails via
`Settings.canDrawOverlays()` and `stopSelf()` otherwise — `ReelsCounterFloatingService.onCreate`).

### 3.1 Methods

| Method | Args | Returns | Meaning |
|---|---|---|---|
| `showBlockOverlay` | `BlockOverlayArgs` (below) | `bool` (shown) | launch `BlockReelsOverlayActivity` over the detected app; native dedupes via `source_app_id` (`onNewIntent` `SparseIntArray`). |
| `hideBlockOverlay` | `{ "appId": String? }` | `bool` | finish the block overlay; broadcasts `PLAY_MEDIA`. |
| `updateBubble` | `BubbleState` (below) | `void` | push a new counter/state to the floating bubble. |
| `setBubbleMode` | `{ "displayMode": String, "milestoneVariant": String? }` | `void` | switch bubble display mode / milestone variant (enums §3.3). |
| `showBubble` | `{ }` | `bool` | start `ReelsCounterFloatingService` (FGS 9001). Returns `false` if overlay perm missing. |
| `hideBubble` | `{ }` | `void` | stop the floating service. |
| `showRatingPrompt` | `RatingPromptArgs` (below) | `void` | launch `RatingPromptOverlayActivity`. |
| `showPermissionSteps` | `{ "permissionType": String }` | `void` | launch `PermissionStepsOverlayActivity` (extra `extra_permission_type`). |

#### `BlockOverlayArgs`

| Key | Type | Req? | Native extra | Meaning |
|---|---|---|---|---|
| `appId` | `String` | **required** | `source_app_id` | which monitored app triggered the block (dedupe key). |
| `videoId` | `String?` | nullable | — | for analytics correlation. |
| `quoteIndex` | `int?` | nullable | — | index into `assets/mindful_timer_quotes.json` (52 quotes). If null, native picks random. |
| `blockStatus` | `String` | **required** | — | one of `block-reels status` enum (§3.4). |
| `challengeType` | `String?` | nullable | — | pre-selected unlock challenge (enum §11.2). Drives the "Unlock Reels/Shorts" CTA. |

#### `BubbleState`

| Key | Type | Req? | Native extra / source | Meaning |
|---|---|---|---|---|
| `countToday` | `int` | **required** | `count_today` | today's blocked/scrolled count. |
| `allTimeCount` | `int?` | nullable | `all_time_count` | lifetime count (analytics/rating). |
| `displayMode` | `String` | **required** | `th.h` enum | `NormalCount` \| `CountPulse` \| `FriendBigCard` \| `RaceStrip`. |
| `milestoneVariant` | `String` | **required** | `th.k` enum value | `auto` \| `invite_friend` \| `battle` \| `guilt_1` \| `guilt_2` \| `night` \| `fresh_start`. |
| `blockReelsStatus` | `String` | **required** | `td.d` enum | block status (§3.4). |
| `hasFriend` | `bool` | optional | analytics `has_friend` | drives FriendBigCard/duel UI. |
| `isPlusUser` | `bool` | optional | analytics `is_plus_user` | subscription gate. |

#### `RatingPromptArgs` (verbatim extras — `RatingPromptOverlayActivity.java`)

| Key | Type | Req? | Native extra | Notes |
|---|---|---|---|---|
| `source` | `String` | **required** | `source` (enum `eg.a.e`) | triggering app. |
| `countToday` | `int` | **required** | `count_today` (default 0) | |
| `allTimeCount` | `int` | **required** | `all_time_count` (default = countToday) | |
| `friendAgeHours` | `int?` | nullable | `friend_age_hours` (`-1L` sentinel = null) | hours since friend joined. |

### 3.2 Bubble display modes (`th/h.java`, verbatim ordinals)

```
NormalCount(0)  CountPulse(1)  FriendBigCard(2)  RaceStrip(3)
```

### 3.3 Milestone variants (`th/k.java`, verbatim string values)

```
AUTO("auto")  INVITE_FRIEND("invite_friend")  BATTLE("battle")
GUILT_1("guilt_1")  GUILT_2("guilt_2")  NIGHT("night")  FRESH_START("fresh_start")
```
> GUILT_1 ≈ >100 blocks, GUILT_2 ≈ >200, NIGHT 21:00–04:00 (per finding-02; the
> exact thresholds live in native bubble logic — Dart sets the variant explicitly).

### 3.4 Block-reels status (`td/d.java`, verbatim ordinals)

```
NOT_SETUP(0)  BLOCK_ACTIVE(1)  REELS_ALLOWED(2)
REELS_LIMIT_REACHED(3)  REELS_EXHAUSTED(4)  PAUSED(5)
```
Carried over the seam as the **string name** (e.g. `"BLOCK_ACTIVE"`).

### 3.5 Threading / lifecycle / error semantics

- All methods are invoked from the Dart UI isolate; native hops to the main
  looper to touch `WindowManager` / launch activities.
- `showBlockOverlay` / `showBubble` **fast-fail** if `SYSTEM_ALERT_WINDOW` is not
  granted → return `false` (do not throw). Dart must then route to
  `showPermissionSteps("overlay")`.
- On a block, native broadcasts `PAUSE_MEDIA` (action `BRAINROT_ACCESSIBILITY_ACTION`,
  extra value `"PAUSE_MEDIA"`); on dismiss/exit it broadcasts `PLAY_MEDIA`. These
  are **internal native broadcasts**, not channel traffic; their *effects* surface
  on `brainpal/overlay_events` (§4).
- Error code namespace `OVL_*` (e.g. `OVL_NO_PERMISSION`, `OVL_SERVICE_DEAD`).
- **iOS:** there is no overlay window. `showBlockOverlay` maps to applying a
  `ShieldConfiguration` via `ManagedSettingsStore.shield`; the "overlay" is
  Apple's system Shield UI. `updateBubble`/`setBubbleMode`/`showBubble`/`hideBubble`
  are **no-ops** (no floating bubble on iOS) — Dart must hide bubble UI affordances
  on iOS. `showRatingPrompt` → `SKStoreReviewController`. `showPermissionSteps`
  → in-app Flutter onboarding + `AuthorizationCenter.requestAuthorization`.

---

## 4. `brainpal/overlay_events` — EventChannel (native→Dart)

**Purpose:** user/system interactions with the block overlay and bubble.

### 4.1 Event payload schema — `OverlayEvent`

| Key | Type | Req? | Meaning |
|---|---|---|---|
| `type` | `String` | **required** | discriminator (enum below). |
| `appId` | `String?` | nullable | source app (`source_app_id`). |
| `closeSource` | `String?` | nullable | e.g. `"counter_leaderboard"`, `"milestone_counter"`, `"fresh_start_exit"` (verbatim from finding-02). |
| `shouldRecord` | `bool?` | nullable | from `EXTRA_FRESH_START_SHOULD_RECORD`; `false` when FRESH_START auto-closed. |
| `ts` | `int` | **required** | epoch ms. |

`type` enum values:

| `type` | Trigger | Native origin |
|---|---|---|
| `tap` | user tapped overlay/bubble | `yo/b.java`, `BlockReelsOverlayActivity` |
| `dismiss` | overlay/bubble dismissed | overlay finish |
| `challenge_completed` | unlock challenge satisfied → overlay released | `be/p.java` → overlay |
| `pause_requested` | block fired; media paused | `PAUSE_MEDIA` broadcast effect |
| `pause_done` | `PAUSE_MEDIA_DONE` received | `ReelsCounterFloatingService` `f4800v0` receiver |
| `play_requested` | user exited → resume | `PLAY_MEDIA` broadcast effect |
| `fresh_start_closed` | FRESH_START session ended/exited | `FRESH_START_CLOSED` + `EXTRA_FRESH_START_SHOULD_RECORD` |

```jsonc
{ "type": "fresh_start_closed", "appId": "com.snapchat.android",
  "closeSource": "fresh_start_exit", "shouldRecord": false, "ts": 1751299200000 }
```

### 4.2 Threading / lifecycle / error

- Emitted on the main looper from activity/service callbacks. Single active sink.
- `challenge_completed` here is the **overlay-level** signal that the block was
  released; the granular challenge progress lives on `brainpal/challenge_events`
  (§11). Dart should treat `challenge_completed` on *this* channel as the
  authoritative "overlay dismissed because challenge passed".
- Error namespace `OVL_*`.
- **iOS:** Shield action button taps arrive via the Shield Action App Extension
  (`ShieldActionDelegate`) → mapped to `tap`/`dismiss`. `pause_*`/`play_*`/
  `fresh_start_closed` are **not emitted** on iOS (no media-pause broadcast model).

---

## 5. `brainpal/accessibility` — MethodChannel (Dart→native)

**Purpose:** query/manage the AccessibilityService enablement
(`com.brainrot.android.services.ReelsAccessibilityService`). Detection is
**impossible** without it — this is the app's master gate.

### 5.1 Methods

| Method | Args | Returns | Meaning |
|---|---|---|---|
| `isServiceEnabled` | `{ }` | `bool` | reads `Settings.Secure "enabled_accessibility_services"`, splits on `:`, exact-match component name (per finding-04 `AccessibilityServiceHelper`). |
| `openSettings` | `{ }` | `void` | `startActivity(Settings.ACTION_ACCESSIBILITY_SETTINGS)`. |
| `serviceStatus` | `{ }` | `ServiceStatus` | richer snapshot (below). |

#### `ServiceStatus` (return)

| Key | Type | Req? | Meaning |
|---|---|---|---|
| `enabled` | `bool` | **required** | service currently bound/enabled. |
| `everEnabled` | `bool` | optional | has been enabled at least once (drives onboarding copy). |
| `serviceComponent` | `String` | optional | `com.brainrot.android.services.ReelsAccessibilityService`. |

### 5.2 Threading / lifecycle / error

- Synchronous-style queries; native reads `Settings.Secure` on the calling thread
  (cheap). `openSettings` hops to main looper.
- **`permission_handler` MUST NOT be used for accessibility** (no API for it) —
  this channel is the only correct path (canonical-stack rule).
- Error namespace `ACC_*`.
- **iOS:** "accessibility service" has no analog. `isServiceEnabled`/`serviceStatus`
  return the **FamilyControls authorization** state
  (`AuthorizationCenter.shared.authorizationStatus == .approved`). `openSettings`
  triggers `requestAuthorization(for: .individual)` (system sheet), not a Settings
  deep-link.

---

## 6. `brainpal/accessibility_status` — EventChannel (native→Dart)

**Purpose:** push enabled/disabled transitions so Dart can flip the master gate
without polling.

### 6.1 Event payload — `AccessibilityStatusEvent`

| Key | Type | Req? | Meaning |
|---|---|---|---|
| `enabled` | `bool` | **required** | new state. |
| `transition` | `String` | **required** | `"enabled"` \| `"disabled"`. |
| `ts` | `int` | **required** | epoch ms. |

### 6.2 Threading / lifecycle / error

- `enabled` emitted from `ReelsAccessibilityService.onServiceConnected()`;
  `disabled` from `onUnbind()`/`onDestroy()` (finding-01 user-flow "ACCESSIBILITY
  SERVICE STOP"). Because `onDestroy` may race teardown, native wraps emission in
  try/catch; **Dart must also reconcile by calling `serviceStatus` on app resume.**
- `PermissionMonitorWorker` (6 h periodic) is a secondary detector of silent
  revocation and may also drive a `disabled` event.
- Error namespace `ACC_*`.
- **iOS:** emitted from an `AuthorizationCenter` status observer; `transition`
  reflects `.approved` ⇄ `.denied/.notDetermined`.

---

## 7. `brainpal/widgets` — MethodChannel (Dart→native)

**Purpose:** feed the two Glance home-screen widgets and drive pinning. Glance is
**reactive (Flow-driven)** natively; over the seam it becomes **push + refresh**
(`home_widget` is a *data conduit only* per canonical stack — it does **not** own
the Android RemoteViews layout; native Glance/RemoteViews are retained).

Widget receivers: `ReelsCounterWidgetReceiver` (compact 2×2, 120×120dp) and
`ReelsCounterWidgetExpandedReceiver` (expanded 4×2, 250×120dp).

### 7.1 Methods

| Method | Args | Returns | Meaning |
|---|---|---|---|
| `pushWidgetData` | `WidgetData` (below) | `void` | write the shared data the Glance widgets read; native then triggers `updateAppWidget`. |
| `requestPinWidget` | `{ "source": String, "expanded": bool }` | `bool` | `AppWidgetManager.requestPinAppWidget()` (per `qh/a.java`). `source` → `widget_source` extra. Returns whether pinning is supported. |
| `refresh` | `{ "expanded": bool? }` | `void` | force recomposition of all (or one type of) widget instances (`sh/x.java` `b()`). |

#### `WidgetData` — mirrors `ReelsStats` + duel leaderboard

| Key | Type | Req? | Source (`ReelsStats` / finding-03) | Meaning |
|---|---|---|---|---|
| `totalCountToday` | `int` | **required** | `ReelsStats.totalCountToday` | "Reels Today" number. |
| `totalTimeMillisToday` | `int` | optional | `ReelsStats.totalTimeMillisToday` (long) | |
| `lastUpdateTime` | `int` | optional | `ReelsStats.lastUpdateTime` | epoch ms. |
| `appWiseSplit` | `List<AppSplit>` | optional | `ReelsStats.appWiseSplit` (`List<AppReelsStats>`) | per-app breakdown. |
| `friend` | `FriendInfo?` | nullable | OneFriend profile | drives expanded leaderboard; only shown if `firstName` present. |
| `leaderboard` | `List<LeaderRow>?` | nullable | duel rows | expanded widget only. |

`AppSplit` = `{ "appId": String, "displayName": String, "count": int, "totalTimeMillis": int }`
(`AppReelsStats`).
`FriendInfo` = `{ "firstName": String, "count": int, "avatarUrl": String? }`.
`LeaderRow` = `{ "name": String, "count": int, "avatarUrl": String? }`.

### 7.2 Deep-links emitted by the widgets (verbatim — `sh/c0.java`, `sh/n.java`)

These are produced **natively** when the widget is tapped (Glance PendingIntent →
`MainActivity` with `FLAG_ACTIVITY_NEW_TASK` 268435456); Dart receives them via
`app_links` + `go_router`, **not** over this channel:

```
brainrot://home?widget_source=home_widget&widget_action=open
brainrot://duel?widget_source=duel_widget&widget_action=open
brainrot://duel?widget_source=duel_widget&widget_action=invite_friend&open_invite=true
```

> ⚠️ **Scheme drift note:** decompiled deep-links use scheme **`brainrot://`**, not
> `brainpal://`. The migration keeps the legacy `brainrot://` scheme to preserve
> already-pinned widgets and external links. See [08-deeplinks-and-routing.md](module-12-messaging-app-shell.md).
> **OPEN QUESTION:** confirm whether new builds also register `brainpal://`.

### 7.3 Pin callback (native→Dart, secondary)

Pin success is observed natively by `WidgetPinResultReceiver` (reads
`widget_source`, logs analytics **event 149** `WIDGET_PIN_CALLBACK_SUCCESS`,
`mc/a.java:942`). The Dart-visible result is the boolean returned by
`requestPinWidget`; the analytics event is fired natively. Widget-click analytics
(`HOME_WIDGET_CLICKED`=150, `DUEL_WIDGET_CLICKED`=151) are also native-side.

### 7.4 Threading / lifecycle / error

- `pushWidgetData` writes to shared widget storage then recomposes on a background
  Glance coroutine; returns immediately.
- **Vivo quirk:** widgets are disabled on Vivo SDK 31–33 (`sh/c.b(ctx,false)`);
  on those devices `requestPinWidget` returns `false` and `pushWidgetData` is a
  no-op. Dart must hide "add widget" UI accordingly (or rely on the return value).
- `AppUpdateReceiver` (action `android.intent.action.MY_PACKAGE_REPLACED`) rebuilds
  widgets after an app update — **not** a channel event.
- Error namespace `WGT_*`.
- **iOS:** widgets are **WidgetKit** (SwiftUI). `pushWidgetData` writes to the
  shared App Group container and calls `WidgetCenter.shared.reloadAllTimelines()`.
  `requestPinWidget` is **unsupported** (iOS has no programmatic pinning) → return
  `false`. Deep-links use a Universal Link / custom-scheme equivalent.

---

## 8. `brainpal/permissions` — MethodChannel (Dart→native)

**Purpose:** check/request the non-accessibility OS permissions the native core
needs. (Accessibility is on its own channel §5. `permission_handler` covers
runtime perms like `POST_NOTIFICATIONS`/`ACTIVITY_RECOGNITION`; this channel
covers the special-access ones `permission_handler` cannot.)

### 8.1 Permission keys (verbatim domain — finding-04)

| Key | Android backing | Notes |
|---|---|---|
| `overlay` | `SYSTEM_ALERT_WINDOW` / `Settings.canDrawOverlays()` | gate for §3 overlay/bubble. |
| `battery_opt` | `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (DOZE whitelist) | persistent counting. |
| `device_admin` | Device Admin (uninstall-protection / lock) | **OPEN QUESTION** — confirm component exists in manifest; finding-04 lists DEVICE_ADMIN among permission_handler targets but no `DeviceAdminReceiver` was confirmed in decompile. |
| `notifications` | `POST_NOTIFICATIONS` (API 33+) | granted pre-13. |
| `autostart` | OEM autostart / `RECEIVE_BOOT_COMPLETED` | OEM-specific guided UI. |
| `nfc` | NFC adapter enabled | only for tap-a-card challenge. |
| `activity_recognition` | `ACTIVITY_RECOGNITION` | pedometer (walk/jump challenges). |

### 8.2 Methods

| Method | Args | Returns | Meaning |
|---|---|---|---|
| `check` | `{ "permission": String }` | `PermissionResult` | current grant state. |
| `request` | `{ "permission": String }` | `PermissionResult` | launch the appropriate system dialog / settings intent; resolves on return. |

`PermissionResult` = `{ "permission": String, "status": String, "canRequest": bool }`
where `status` ∈ `granted | denied | permanently_denied | unsupported | unknown`.

### 8.3 Threading / lifecycle / error

- `request` may launch an Activity/Settings screen; it resolves when the user
  returns (native re-checks on resume). Dart must not block UI.
- `PermissionStepsOverlayActivity` (extra `extra_permission_type`) renders the
  device-specific guided steps natively; `showPermissionSteps` on §3 is the
  command to launch it.
- Error namespace `PRM_*`.
- **iOS:** `overlay`/`battery_opt`/`device_admin`/`autostart` are **`unsupported`**
  (return that status). `notifications` → `UNUserNotificationCenter`,
  `activity_recognition` → `CMMotionActivityManager`/`CMPedometer`, `nfc` →
  `NFCReaderSession`. The master grant on iOS is FamilyControls authorization
  (queried via §5, not here).

---

## 9. `brainpal/permission_status` — EventChannel (native→Dart)

**Purpose:** push grant/revoke transitions detected by `PermissionMonitorWorker`
(6 h periodic) or by OS callbacks, so Dart re-gates features without polling.

### 9.1 Event payload — `PermissionStatusEvent`

| Key | Type | Req? | Meaning |
|---|---|---|---|
| `permission` | `String` | **required** | one of §8.1 keys. |
| `status` | `String` | **required** | `granted | denied | permanently_denied | unsupported`. |
| `transition` | `String` | **required** | `"granted"` \| `"revoked"`. |
| `ts` | `int` | **required** | epoch ms. |

### 9.2 Threading / lifecycle / error

- Revocations are frequently discovered **late** (only when the 6 h worker runs or
  on app resume). Dart must reconcile via `brainpal/permissions.check` on resume.
- A `revoked` for `overlay` should cause Dart to stop pushing bubble/overlay
  commands (they would fast-fail anyway).
- Error namespace `PRM_*`.
- **iOS:** emitted from the relevant authorization observers; `overlay`/`battery_opt`
  never appear.

---

## 10. `brainpal/system_events` — EventChannel (native→Dart)

**Purpose:** system-level signals the app reacts to: date/time/timezone changes
(daily-counter reset) and screen-capture (anti-screenshot analytics).

Native fronting: `core/receiver/DateChangedReceiver.java` (manifest-registered for
the three actions) + `MainActivity.java` `ScreenCaptureCallback` (API 34+).

### 10.1 Event payload — `SystemEvent`

| Key | Type | Req? | Meaning |
|---|---|---|---|
| `type` | `String` | **required** | discriminator (enum below). |
| `ts` | `int` | **required** | epoch ms. |
| `screen` | `String?` | nullable | only for `SCREEN_CAPTURED`: current screen route name (`MainActivity` puts `"screen"` into the analytics event). |

`type` enum (verbatim actions / sources):

| `type` | Android trigger | Source |
|---|---|---|
| `DATE_CHANGED` | `android.intent.action.DATE_CHANGED` | `DateChangedReceiver` (manifest line ~360) |
| `TIME_SET` | `android.intent.action.TIME_SET` | `DateChangedReceiver` |
| `TIMEZONE_CHANGED` | `android.intent.action.TIMEZONE_CHANGED` | `DateChangedReceiver` |
| `SCREEN_CAPTURED` | `Activity.ScreenCaptureCallback.onScreenCaptured()` (SDK ≥ 34) | `MainActivity.java` (analytics `mc.a.f16578v6` = event `v6`) |

```jsonc
{ "type": "DATE_CHANGED", "ts": 1751299200000 }
{ "type": "SCREEN_CAPTURED", "ts": 1751299200000, "screen": "home" }
```

### 10.2 Threading / lifecycle / error

- `DateChangedReceiver` runs on a broadcast thread; it calls
  `dateChangeNotifier.q(...)` natively to reset daily counters **and** should emit
  the channel event for Dart to refresh in-app state. **Vivo SDK 31–33 workaround:**
  the receiver `return`s early (skips the `goAsync()` coroutine) on Vivo
  31/32/33 — the **channel event must still be emitted synchronously** before the
  early return, or Dart will miss midnight on Vivo. **VALIDATION REQUIRED.**
- `SCREEN_CAPTURED` only fires on API ≥ 34 while `MainActivity` is started
  (callback registered in `onStart`, unregistered in `onStop`).
- Error namespace `SYS_*`.
- **iOS:** `DATE_CHANGED`/`TIME_SET`/`TIMEZONE_CHANGED` → observe
  `NSCalendarDayChanged` / `.NSSystemClockDidChange` / `.NSSystemTimeZoneDidChange`.
  `SCREEN_CAPTURED` → `UIScreen.capturedDidChangeNotification` /
  `UIScreen.main.isCaptured` (continuous, not a single shot) — semantics differ;
  treat as best-effort.

---

## 11. `brainpal/challenges` — MethodChannel (Dart→native)

**Purpose:** start/cancel a gamified "unlock challenge" that, when completed,
releases the block overlay. Challenges drive native sensors / NFC and **must stay
native** (sensor sampling, NFC reader mode, foreground-while-blocking).

### 11.1 Methods

| Method | Args | Returns | Meaning |
|---|---|---|---|
| `startChallenge` | `ChallengeArgs` (below) | `bool` (started) | begin a challenge; native shows its UI inside the block overlay. |
| `cancelChallenge` | `{ "challengeId": String? }` | `void` | abort the active challenge. |

#### `ChallengeArgs`

| Key | Type | Req? | Meaning |
|---|---|---|---|
| `type` | `String` | **required** | challenge type (enum §11.2). |
| `appId` | `String?` | nullable | the app being unlocked (for analytics + which "X is Locked" title). |
| `target` | `int?` | nullable | goal count: jumps / steps / scrolls / seconds (see §11.3). |
| `challengeId` | `String?` | nullable | client-generated correlation id echoed on `challenge_events`. |

### 11.2 Challenge types (verbatim — `res/values/strings.xml` `block_reels_nfc_*`)

| Canonical `type` | String-resource family | Sensor / API | iOS feasible? |
|---|---|---|---|
| `nfc` | `block_reels_nfc_tap_card_*`, `card_help_*` | `NfcAdapter.enableReaderMode` (in `BlockReelsOverlayActivity`) | `CoreNFC` (partial) |
| `walk_steps` | `block_reels_nfc_walk_steps_*` (`/ %1$d steps`) | `pedometer` / `ACTIVITY_RECOGNITION` | `CMPedometer` ✅ |
| `jump_count` | `block_reels_nfc_jump_count_*` (`/ %1$d jumps`) | accelerometer (`sensors_plus`) | CoreMotion ✅ |
| `forehead_scan` | `block_reels_nfc_forehead_scan_*` ("Hold your phone on forehead for 30 sec") | proximity + accelerometer | CoreMotion ~ |
| `phone_jail` | `block_reels_nfc_phone_jail_*` ("Keep phone face down for %1$d sec") | accelerometer (orientation) | CoreMotion ✅ |
| `thumb_detox` | `block_reels_nfc_thumb_detox_*` ("Press both thumbs on the screen") | multi-touch | UIKit ✅ |
| `scroll` | `block_reels_nfc_scroll_counter` (`/ %1$d scrolls`) | overlay scroll counter | n/a (no overlay on iOS) |

> Unlock-key picker CTAs (`block_reels_nfc_unlock_key_sheet_*_cta`):
> Tap a card / Walk / Jump / Forehead Scan / Phone Flip Down / Thumb Detox.

### 11.3 `target` semantics by type

| type | `target` means | default copy hint |
|---|---|---|
| `jump_count` | number of jumps | `Jump %1$d times to unlock` |
| `walk_steps` | number of steps | `/ %1$d steps` |
| `scroll` | number of scrolls | `/ %1$d scrolls` |
| `forehead_scan` | seconds to hold (≈30) | `forehead for 30 sec` |
| `phone_jail` | seconds face-down | `face down for %1$d sec` |
| `thumb_detox` | seconds holding | `for <n> sec` |
| `nfc` | n/a (single tap) | `Tap any card to watch reels` |

### 11.4 Threading / lifecycle / error

- Native runs the sensor/NFC loop on its own thread; UI on main looper. NFC reader
  mode is enabled `onResume` / disabled `onPause` of the block overlay
  (`BlockReelsOverlayActivity` — finding-02).
- `startChallenge` returns `false` if the required permission is missing (e.g.
  `activity_recognition` for `walk_steps`, NFC disabled for `nfc`); Dart should
  route to `brainpal/permissions.request`.
- Error namespace `CHL_*` (`CHL_NO_SENSOR`, `CHL_NFC_DISABLED`, `CHL_UNSUPPORTED`).
- **iOS:** `scroll` and `nfc` (reader-while-shielded) are **`unsupported`** (return
  `false`); the others map to CoreMotion/CoreNFC but run inside the app, not a
  system Shield, so the UX differs. See [09-ios-screentime-strategy.md](99-native-retained-modules.md).

---

## 12. `brainpal/challenge_events` — EventChannel (native→Dart)

**Purpose:** granular progress/result of the active unlock challenge.

### 12.1 Event payload — `ChallengeEvent`

| Key | Type | Req? | Meaning |
|---|---|---|---|
| `type` | `String` | **required** | `progress` \| `completed` \| `failed`. |
| `challengeType` | `String` | **required** | the §11.2 type. |
| `challengeId` | `String?` | nullable | echoes `ChallengeArgs.challengeId`. |
| `current` | `int?` | nullable | progress value (jumps/steps/scrolls/seconds done). |
| `target` | `int?` | nullable | the goal (echoes start). |
| `reason` | `String?` | nullable | for `failed`: e.g. `"lifted_thumb"`, `"phone_flipped_up"` (strings `*_fail`). |
| `ts` | `int` | **required** | epoch ms. |

```jsonc
{ "type": "progress", "challengeType": "jump_count", "current": 7, "target": 10, "ts": 1751299200000 }
{ "type": "completed", "challengeType": "forehead_scan", "ts": 1751299230000 }
{ "type": "failed", "challengeType": "phone_jail", "reason": "phone_flipped_up", "ts": 1751299215000 }
```

### 12.2 Relationship to overlay events

A `completed` here is the **cause**; native then releases the overlay and emits
`challenge_completed` on `brainpal/overlay_events` (§4) as the **effect**. Dart's
domain layer should update challenge UI from this channel but treat the overlay
channel as the authoritative "block lifted" signal.

### 12.3 Threading / lifecycle / error

- High-frequency for sensor challenges (`progress` per detected jump/step/tick).
  Dart should throttle UI repaints.
- Error namespace `CHL_*`.
- **iOS:** emitted from CoreMotion/CoreNFC callbacks where the challenge type is
  supported; `scroll`/`nfc` produce no events.

---

## 13. Cross-channel invariants & ordering

1. **Detection → block, never the reverse.** `brainpal/detection` events may lead
   Dart to call `brainpal/overlay.showBlockOverlay`. Native never auto-shows an
   overlay from Dart's domain decisions without a Dart command **except** the
   legacy in-service fast path (`ReelsAccessibilityService` can launch
   `BlockReelsOverlayActivity` directly). **OPEN QUESTION:** during migration,
   does Dart own the block decision (preferred) or does native still self-trigger?
   This determines whether §3 `showBlockOverlay` is the only entry point.
2. **Bubble follows detection.** Each accepted detection increments the count Dart
   pushes via `updateBubble`.
3. **Cooldowns are Dart-owned business rules** (Remote Config, `kc/a.java`):
   `BLOCK_REELS_MIN_COOLDOWN_MINS` default **30**, `BLOCK_REELS_MIN_WINDOW_MINS`
   default **5**, `BACK_PRESS_YEARLY_OFFER_BUFFER_MINUTES` default **60**. Native
   does **not** enforce them post-migration; Dart decides whether a detection
   becomes a block. See [04-block-engine-and-rules.md](module-09-core-data-storage.md).
4. **Permission gating precedes overlay/bubble/challenge commands.** Always
   `check`/`request` first; the native fast-fail (`canDrawOverlays`) is a backstop,
   not the primary gate.
5. **Reconcile on resume.** Status EventChannels (5/6, 8/9) can drop transitions
   when the app is dead; on `AppLifecycleState.resumed` Dart re-queries
   `serviceStatus` + `permissions.check` for every gated capability.
6. **Timestamps are epoch ms, device clock.** `ts`/`eventTimestamp` use
   `System.currentTimeMillis()` — subject to clock skew and user time changes
   (hence `TIME_SET` on §10). Backend sync must tolerate skew. Daily boundary is
   **device-local midnight** (`statsDate` = `YYYY-MM-DD`).

---

## 14. Error semantics (uniform)

- Method channels reject via `FlutterError(code, message, details)`. **Code
  prefixes are reserved per channel:** `DET_`, `OVL_`, `ACC_`, `WGT_`, `PRM_`,
  `SYS_`, `CHL_`.
- A capability not available on the current platform/OS returns a **value**
  (`false` / `status:"unsupported"`), **not** an error, so Dart branches on data
  rather than catching.
- Event channels surface only marshalling/transport errors via `onError`; domain
  failures (e.g. challenge failed) are **normal events** (`type:"failed"`), not
  channel errors.
- Native parser/sensor exceptions are swallowed natively and never cross the seam.

---

## 15. Contract versioning & stability

**Contract version: `1.0.0` (frozen).** Carried as a constant on both sides:
- Dart: `const kPlatformContractVersion = '1.0.0';` (in `core/platform/contract.dart`).
- Kotlin: `const val PLATFORM_CONTRACT_VERSION = "1.0.0"` (in the native core).
- A `getContractVersion` method **SHOULD** exist on `brainpal/accessibility`
  (cheapest always-present method channel) returning the native version; Dart
  asserts compatibility at startup and degrades gracefully on mismatch.

**SemVer rules for this seam:**

| Change | Version bump | Notes |
|---|---|---|
| Add an **optional** payload key, a new method/event `type`, or a new channel | **MINOR** | backward-compatible; old Dart ignores unknown keys, old native ignores unknown methods. |
| Add a **required** key, rename/remove a key/method/event/channel, change a type or units | **MAJOR** | breaking; requires lockstep native+Dart release and a migration note here. |
| Tighten/relax error codes, add an error code | **PATCH** | no payload change. |

**Stability guarantees:**
- **Channel names, method names, event `type` strings, and existing payload keys
  are immutable within a MAJOR version.**
- **Enum string values are immutable** (`th.k` `"guilt_1"`, `td.d` `"BLOCK_ACTIVE"`,
  challenge `"forehead_scan"`, etc.) — they are persisted/synced and appear in
  analytics; renaming is a MAJOR change.
- **Unknown-field tolerance is mandatory both ways:** receivers MUST ignore keys
  they don't recognize (forward-compat) and MUST supply documented defaults for
  optional keys they expect but don't receive (back-compat).
- The **legacy `brainrot://` deep-link scheme is part of the frozen contract**
  (pinned widgets depend on it) and may not be removed in v1.x.
- Adding a platform (iOS) does **not** bump the version: iOS reuses v1.0.0 names
  and schemas; platform-unsupported methods return `unsupported`/`false`.

**Change procedure:** propose here → bump version table → update every
cross-referenced per-module doc → ship native + Dart together for MAJOR.

---

## 16. Source-of-truth cross-reference

| Channel | Primary decompiled class(es) |
|---|---|
| `brainpal/detection` | `services/ReelsAccessibilityService.java`, `wh/x.java`, `xh/a.java` (DetectionData), `xh/b.java` `xh/d.java` `xh/e.java`, `b7/l.java`, `feature_reels_counter/domain/model/ReelsScrollEvent.java` |
| `brainpal/overlay` | `BlockReelsOverlayActivity.java`, `floating_bubble/ReelsCounterFloatingService.java`, `RatingPromptOverlayActivity.java`, `PermissionStepsOverlayActivity.java`, `th/h.java`, `th/k.java`, `td/d.java` |
| `brainpal/overlay_events` | `BlockReelsOverlayActivity.java`, `floating_bubble/ReelsCounterFloatingService.java`, `yo/b.java` |
| `brainpal/accessibility` (+status) | `services/ReelsAccessibilityService.java`, `feature_permission/*`, `core/worker/PermissionMonitorWorker.java`, `res/xml/accessibility_service_config.xml` |
| `brainpal/widgets` | `feature_widget/presentation/widget/*.java`, `qh/a.java`, `sh/c0.java`, `sh/x.java`, `sh/c.java`, `mc/a.java` (events 149/150/151) |
| `brainpal/permissions` (+status) | `PermissionStepsOverlayActivity.java`, `core/worker/PermissionMonitorWorker.java`, `feature_permission/domain/model/PermissionLogs.java`, `AndroidManifest.xml` |
| `brainpal/system_events` | `core/receiver/DateChangedReceiver.java`, `MainActivity.java` (`ScreenCaptureCallback`) |
| `brainpal/challenges` (+events) | `be/p.java`, `ee/u.java`, `res/values/strings.xml` (`block_reels_nfc_*`) |

Sibling docs: [03-reels-detection-core.md](module-01-reels-detection-core.md) ·
[04-block-engine-and-rules.md](module-09-core-data-storage.md) ·
[05-floating-bubble-and-overlays.md](module-02-overlays-floating-bubble.md) ·
[06-home-widgets.md](module-03-widgets-homescreen.md) ·
[07-permissions-and-onboarding.md](module-04-permissions-onboarding.md) ·
[08-deeplinks-and-routing.md](module-12-messaging-app-shell.md) ·
[09-ios-screentime-strategy.md](99-native-retained-modules.md) ·
[02-backend-api-contract.md](02-backend-api-contract.md).

---

## 17. Open questions (seam-level)

1. **Block-decision ownership** (§13.1): post-migration, does Dart own the
   "detection → block" decision (calling `showBlockOverlay`) or does the retained
   native service keep self-launching `BlockReelsOverlayActivity`? Affects whether
   `brainpal/overlay.showBlockOverlay` is the sole entry point or a parallel path.
2. **Device-admin permission** (§8.1): finding-04 lists `device_admin` but no
   `DeviceAdminReceiver` was confirmed in the decompile — verify in
   `AndroidManifest.xml` whether uninstall-protection/device-admin is actually used.
3. **Scheme registration** (§7.2): is `brainpal://` registered alongside the legacy
   `brainrot://`, or is only `brainrot://` kept?
4. **Vivo midnight emission** (§10.2): confirm the `system_events` event is emitted
   *before* the Vivo SDK 31–33 early-`return` in `DateChangedReceiver`.
5. **FGS / notification IDs beyond bubble**: bubble FGS id is **9001**; the
   AccessibilityService's own foreground-notification id was not located in the
   decompile — confirm if it runs as FGS and on which channel.
6. **`viewDurationMs` accrual** (§2.1): is duration computed natively per-reel and
   pushed on each detection, or accrued in Dart from successive `ts` deltas?
```
