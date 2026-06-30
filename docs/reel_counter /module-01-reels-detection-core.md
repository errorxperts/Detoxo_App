# Module: Reels Detection Core

> **THE load-bearing module.** This is the AccessibilityService-based engine that detects short-form video ("reels"/"shorts") inside Instagram, YouTube, TikTok, Snapchat, and Facebook, counts scrolls, derives per-reel view-duration, and emits the scroll/stat trail that every other feature (overlay blocking, bubble counter, widgets, leaderboard, backend sync) consumes. It has **no Dart equivalent** and is **KEEP-NATIVE** on Android.

Source of truth for channel names: [01-platform-channel-contracts.md](01-platform-channel-contracts.md).
Siblings: [module-02-overlay-bubble.md](module-02-overlays-floating-bubble.md) · [module-03-blocking-challenges.md](module-02-overlays-floating-bubble.md) · [02-backend-api-contract.md](02-backend-api-contract.md) · [module-08-stats-sync.md](module-10-networking-sync.md).

---

## 1. Purpose & scope

The Reels Detection Core is the always-on Android `AccessibilityService` (`com.brainrot.android.services.ReelsAccessibilityService`) plus its parser tree (`b7.l`, `xh.{a,b,c,d,e}`, `yh.{a,b,c,d}`) and scroll state-machine (`wh.x`). Responsibilities:

1. **Foreground-app gate** — on every `AccessibilityEvent`, capture the foreground package and, if it is one of the 6 monitored apps, push it into a detection channel (`onAccessibilityEvent` in `ReelsAccessibilityService.java:637`).
2. **Per-app short-form detection** — walk the live accessibility node tree and decide *is the user currently looking at a reel/short*, extract a stable `videoIdentifier`, and detect `isPanelOpen` (comments/engagement) and `isAd`. Per-app heuristics live in `xh.e` (YouTube), `xh.d` (Snapchat), `xh.b` (Instagram/Facebook), shared geometry in `b7.l`.
3. **Scroll counting + debounce** — `wh.x` (`reelsScrollManager`) consumes detection events through a coalescing queue (`lq.d`), computes per-reel `viewDurationMillis`, increments counts, and persists `ReelsScrollEvent` / `WeekEventDb` rows.
4. **Rollup** — events roll up to daily (`ReelsStats` snapshot, `DailyReelsStats` for backend) and weekly (`WeekEventDb`) aggregates, split per app (`AppReelsStats`).
5. **Block decisioning + fresh-start** — feeds the block state machine (`td.e`/`td.d`) that decides "X more reels left" / limit-reached / exhausted, and fires the one-time "fresh start" onboarding (`ReelsAccessibilityService.i()`).

**Out of scope (other modules):** the overlay window/bubble rendering ([module-02](module-02-overlays-floating-bubble.md)), unlock challenges ([module-03](module-02-overlays-floating-bubble.md)), HTTP sync transport ([02-backend-api-contract.md](02-backend-api-contract.md)), widgets ([module-06](module-03-widgets-homescreen.md)). This doc owns **detection + counting + the event/stat data model + the native→Dart detection event stream.**

---

## 2. Migration verdict

**Verdict: KEEP-NATIVE (Android) + DART+CHANNEL (iOS, re-implemented on Screen Time).**

| Concern | Verdict | Rationale |
|---|---|---|
| Android accessibility tree walk, view-ID match, geometry 0.75 rule, BFS ≤1500, ad/UI-label keyword scans | **KEEP-NATIVE** | These run *inside* `AccessibilityService.onAccessibilityEvent` against `AccessibilityNodeInfo`. Flutter widgets never participate in the Android accessibility tree of *other* apps; there is no Dart API for `getRootInActiveWindow()`, `getBoundsInScreen()`, `getViewIdResourceName()`. Port the Kotlin parser tree **near-verbatim** into the retained native detection core. |
| Scroll state-machine / debounce (`wh.x`) | **KEEP-NATIVE (counting), DART (rollup)** | The 500 ms coalescing + per-reel duration math is tightly coupled to native event timing; keep it native and emit *finished* scroll events over `brainpal/detection`. Daily/weekly rollup, stat snapshots, and sync move to the Dart domain/data layer (drift). |
| Monitored-app list, thresholds, regexes, keyword sets | **KEEP-NATIVE constants, MIRROR in Dart** | Constants live in `kc.a`, `zh.a`, `xh.*`. They must be byte-identical in the native core; mirror only the high-level ones (app list, block thresholds) in Dart for UI/settings. |
| iOS detection | **NOT POSSIBLE as-is → re-implement on Apple Screen Time** | iOS has no cross-app accessibility scraping, no `TYPE_APPLICATION_OVERLAY`, no view-ID introspection of Instagram/YouTube. See §6. The Dart domain layer (`ReelsDetectionRepository`) is identical; only the platform implementation differs. |

> **Architectural statement:** BrainPal is ~70% an OS-integration app. This module is the densest part of that 70%. The migration target is a **hybrid**: a retained Kotlin "detection core" (this module, ported verbatim) speaking a frozen platform-channel contract to a Flutter app that owns counting-rollup, UI, and sync. On iOS the entire detection mechanism is replaced (not ported) behind the same Dart domain interface.

---

## 3. Business logic & algorithms

> Every constant below was re-read from the cited decompiled file. Treat them as VERBATIM golden values for the native port and the replay harness (§10).

### 3.1 Monitored package list — `kc/a.java`

```java
// kc/a.java:12  — TikTok variants (special-cased subset)
Set f14464a = {"com.zhiliaoapp.musically", "com.ss.android.ugc.trill"};

// kc/a.java:15  — ALL monitored packages (membership gate in onAccessibilityEvent)
List f14465b = [
  "com.zhiliaoapp.musically",   // TikTok (global / musical.ly)
  "com.ss.android.ugc.trill",   // TikTok (trill variant)
  "com.google.android.youtube", // YouTube Shorts
  "com.instagram.android",      // Instagram Reels
  "com.snapchat.android",       // Snapchat Spotlight
  "com.facebook.katana"         // Facebook Reels
];
```

The foreground gate is **exact set membership** on `event.getPackageName().toString()` against `kc.a.f14465b` (`ReelsAccessibilityService.java:645`).

### 3.2 Rate-limit / block constants — `kc/a.java` (Firebase Remote Config `on.b`, with defaults)

| Constant key (Remote Config) | Getter | Default if unset/invalid | Units |
|---|---|---|---|
| `BACK_PRESS_YEARLY_OFFER_BUFFER_MINUTES` | `kc.a.a()` | **60** min → returned as `60 * 60 * 1000` ms | ms |
| `BLOCK_REELS_MIN_COOLDOWN_MINS` | `kc.a.b()` | **30** (if `< 1`) | minutes |
| `BLOCK_REELS_MIN_WINDOW_MINS` | `kc.a.c()` | **5** (if `< 1`) | minutes |
| `CHECKOUT_OPTIMIZATION_TTL_IN_MILLIS` | `kc.a.d()` | `HTTPTimeoutManager.TIMEOUT_RESET_INTERVAL_MS` | ms |
| `RC_YEARLY_OFFER_PRODUCT_ID` | `kc.a.e()` | `"yearly_offer"` | string |

> Mirror via `firebase_remote_config` in Dart (settings/paywall surface). The cooldown/window values feed the block state machine; the detection core itself does not gate on them — they belong to [module-03](module-02-overlays-floating-bubble.md).

### 3.3 Accessibility service config — `res/xml/accessibility_service_config.xml`

```xml
android:accessibilityEventTypes="typeAllMask"
android:accessibilityFeedbackType="feedbackGeneric"
android:notificationTimeout="500"          <!-- 500 ms OS-level event coalescing == the debounce floor -->
android:accessibilityFlags="flagRetrieveInteractiveWindows|flagReportViewIds|flagIncludeNotImportantViews|flagDefault"
android:canRetrieveWindowContent="true"
android:canPerformGestures="true"
android:settingsActivity="com.brainrot.android.MainActivity"
```

**The 500 ms `notificationTimeout` is the load-bearing debounce.** It is the OS coalescing window; the app adds a *second* explicit 500 ms delay step in `ReelsAccessibilityService.e(...)` (default `500L`, `ReelsAccessibilityService.java:372`) and a 150 ms × up-to-5 settle loop in `c(...)` (see §3.9).

### 3.4 YouTube detection — `b7.l` (geometry) + `xh.e` (content/ad)

**Geometry pass — `b7.l.f(...)` (`b7/l.java:27`):** BFS over the whole tree from the supplied root. For every node:
- View-ID flags:
  - `com.google.android.youtube:id/watch_panel_scrim` → `z10 = isVideoPage = true`
  - `com.google.android.youtube:id/logo` → checked (sets `hasYoutubeLogo`, hard-coded `true` in `toString`)
  - `com.google.android.youtube:id/reel_recycler` → `z11 = isReelPage = true`
  - `com.google.android.youtube:id/app_engagement_panel` **or** `…:id/design_bottom_sheet` → `z12 = isYtPanelOpen = true`
- Bounds via `getBoundsInScreen(rect)`; midpoint `xMid = rint((left+right)/2)`, `yMid = rint((top+bottom)/2)`; track `maxRight = max(maxRight, right)`.
- Nodes bucketed into two `LinkedHashMap`s keyed by `xMid` and `yMid`, then collapsed by `b7.l.h(...)`.

**Cluster collapse — `b7.l.h(TreeMap)` (`b7/l.java:195`):** sort keys ascending; **consecutive keys whose gap `≤ 10 px` are merged** into one logical line (key = last element of the run). This is the "within 10px clustered" rule.

**Decision — `b7.l.g(...)` (`b7/l.java:186`, dump-skipped but reconstructable from the `missing block` hints `B:152–166`):**
```
maxRight = group.maxRight                       // r6
for key in groupMap.keys (left-edge buckets):
    pos = key.intValue()                        // r2
    if pos >= 0.75 * maxRight:  -> NOT a left-edge shorts strip (continue)
    if pos >  0.25 * maxRight:  -> ambiguous middle (continue)
    else (pos <= 0.25 * maxRight):
        log "Shorts detected in left half maxRight=<maxRight> key=<key>"
        return ShortFormContentResult(nodeInfo = group[key])    // isShortFormContentPresent=true
return ShortFormContentResult(false / reel_recycler fallback)
```
i.e. **the 0.75 rule**: a node group is treated as a shorts strip when its left edge sits in the **left quarter** (`≤ 0.25 * maxRight`) while content extends to `maxRight`; groups whose left edge is `≥ 0.75 * maxRight` are excluded. `reel_recycler` presence (`z11`) is the corroborating fallback signal.

**Content/ID extraction — `xh.e.b(node, tag, verbose)` (`xh/e.java:39`):** BFS over the tree (no explicit node cap here — bounded by tree size; **Snapchat/IG use 1500, YouTube relies on early-exit**). For each node take `text`, else `contentDescription`, trimmed. Skip the node's text if it matches any UI label (case-insensitive, `Locale.ROOT`):

```
EXACT-equals blacklist:  "video progress", "home", "shorts", "library", "you",
                         "create", "search", "more options", "trends", "live"
CONTAINS blacklist:      " seconds of ", " second of ", " minutes of ", " minute of ",
                         "subscriptions" (startsWith via r.P), "content available",
                         "new content is available", "subscribe", "unsubscribe",
                         "like this video", "dislike", "share this", "view",
                         "remix this", "see more", "go to", "donate", "navigate"
```
- **Channel handle** captured once via regex `@([A-Za-z0-9_.\-]{3,30})` (`xh/e.java:23`, group 1).
- **Title** = first non-blacklisted node text with `length > 20`, kept only if no title captured yet.
- Early-exit when both handle and title are non-empty.

**Final ID format — `xh.e.b` return + `xh.e.a` wrap:**
```
if handle && title:  id = "ch_" + handle + "_" + title.take(30)
elif handle:         id = "ch_" + handle
elif title:          id = title
else:                id = ""          // empty
// xh.e.a then prefixes app tag and caps:
videoIdentifier = (isAd ? "yt_ad" : "yt") + "_" + id.take(40)   // null if id empty
```
**Ad CTA keyword set — `xh.e.f27722b` (`xh/e.java:26`):**
```
{"shop now","visit site","install","order now","learn more","sign up","get offer","download now"}
```

### 3.5 Snapchat Spotlight detection — `xh.d` (`xh/d.java`)

**Spotlight gate** (`xh/d.java:72`): run `b7.l.g(b7.l.f(...))` with the obfuscated view IDs
`"com.snapchat.android:id/0_resource_name_obfuscated"` and `"com.snapchat.android:id/spotlight_container"`. If `isShortFormContentPresent == false` → `return DetectionData(isDetected=false)` (`new a(14, null, false, false)`).

**Content-text BFS (≤1500 nodes)** (`xh/d.java:83`): collect `text || contentDescription` (trimmed). Skip if it matches the Snapchat UI-label set (lowercased), or if the text is purely numeric/units (digits + `kKmM.,+ ` only — a like/view counter):

```
UI-label set f27719c (xh/d.java:30):
{"spotlight","camera","chat","map","stories","search","add friends","story sent",
 "more","play","share","comment","like","subscribe","follow","for you","explore","send","reply"}
```

**Ad BFS (≤1500 nodes)** (`xh/d.java:120`): only `isVisibleToUser()` nodes. Ad if **either**:
- a **badge** match: `xh.d.b(text)` / `b(contentDescription)` splits on `\n · • | ,` and matches set `zh.a.f29317f = {"sponsored","ad","paid partnership"}` (`zh/a.java:41`); **or**
- a **CTA** match: node text/cd lowercased+trimmed ∈ set `f27718b` (`xh/d.java:27`):
```
{"sign up","shop now","learn more","install","install now","download","book now",
 "order now","get offer","play now","play game","watch now","get app","use app",
 "apply now","buy now","get directions"}
```

**Video ID format** (`xh/d.java:176`):
```
prefix = isAd ? "snapchat_spotlight_ad_" : "snapchat_spotlight_"
if contentTexts empty:  id = prefix + (System.currentTimeMillis() / 10000)
else:                   id = prefix + top5_sorted_texts.joinToString("_", limit=… , maxLen=30)
DetectionData = a(4, id, isPanelOpen=true, isAd)
```
(The `/10000` divisor buckets the timestamp into ~10 s windows so rapid re-detections of the same un-textual reel collapse to one ID.)

### 3.6 Instagram / Facebook detection — `xh.b` (`xh/b.java`)

`xh.b.a(node, tag)` (`xh/b.java:36`, method body is a JADX dump-skip; behavior reconstructed from its static fields + the `b7.l`/`xh` pattern):
- Tokenizer regex `f27712b = "[^\p{L}\p{N}]+"` (`xh/b.java:13`) splits captions into words.
- **Ad CTA set `f27713c`** (`xh/b.java:16`):
```
{"shop now","learn more","sign up","install","install now","book now","order now",
 "get offer","download","send message","send whatsapp message","contact us","get quote",
 "apply now","see menu","use app","play game","get directions","watch more"}
```
- **UI-label blacklists** (shared, `zh.a`, `zh/a.java:32`):
```
f29314b (reel action labels): {"like","dislike","comment","share","remix","try remix",
  "like button","view comments","send","subscribe","not interested","reactions","save",
  "more","comments","shares","whatsapp","navigate to your reels"}
f29315c: {"back","search","mention"} ∪ {"share"} ∪ {"more"} ∪ {"sponsored"}
f29316e: {"reactions","comment","share"} ∪ {"comments","shares","likes"}
f29317f (ad badge): {"sponsored","ad","paid partnership"}
f29313a: regex "\d"   (numeric-counter detector)
```
- Returns `xh.a` (`DetectionData`) with `isDetected`, `videoIdentifier`, `isPanelOpen`, `isAd`.

> **OPEN QUESTION (see §11):** the exact Instagram/Facebook view-IDs (`com.instagram.android:id/…`, `com.facebook.katana:id/…`) and the geometry/ID-format used inside `xh.b.a` are inside the un-decompiled instruction dump and could **not** be recovered as literals. They must be lifted from smali before the verbatim port.

### 3.7 TikTok detection

TikTok (`com.zhiliaoapp.musically`, `com.ss.android.ugc.trill`) is in the monitored gate `f14465b` and the special-case subset `f14464a` (`kc/a.java:12`). **No dedicated `xh.*` TikTok parser class was found** — TikTok is full-screen short-form by construction, so detection is likely "package is foreground ⇒ reel" (every foreground event in TikTok = a reel/scroll), gated only by the special-case set. **OPEN QUESTION:** confirm whether TikTok bypasses tree parsing (treated as always-reel) vs. routes through `xh.b`. This materially affects parity.

### 3.8 DetectionData contract — `xh.a` (`xh/a.java`)

```
DetectionData(int mask, String videoIdentifier, boolean isPanelOpen, boolean isAd)
  // mask bit 0x2 => videoIdentifier nullable; 0x4 => isPanelOpen defaults true when (mask&4)==0
fields: isDetected (a), videoIdentifier (b), isPanelOpen (c), isAd (d)
```
This is the native struct that becomes the `brainpal/detection` EventChannel payload (§7).

### 3.9 Foreground refresh / settle loop — `ReelsAccessibilityService.c(...)`

`c(service, expectedPkg, cont)` (`ReelsAccessibilityService.java:291`): up to **5 attempts**, each re-reading `getRootInActiveWindow().getPackageName()`; returns `true` immediately if it equals the expected package; between attempts (except the last) `delay(150 ms)`. This guards against the OS reporting a stale root window right after an app switch.

### 3.10 Scroll state-machine & debounce — `wh.x` (`wh/x.java`)

State fields (`wh/x.java:36–48`): `f26938j` (int count), `f26939k` (String currentApp), `f26940l` (long lastTs), `f26941m` (bool), `f26942n` (Long), queue `f26934f = lq.d` (mutex/channel), `f26937i = t4.k(9)` (pending-event holder; `f23822t` = pending appId string).

**Flush guard (`a`, `c`, `f`, all `wh/x.java`):** acquire `lq.d`; the event is committed **only if** `f26939k != null` **OR** `f26940l > 0` **OR** `t4.k.f23822t != null` (`wh/x.java:55`, `:245`). Otherwise it is a no-op (debounced away). On commit, `b(System.currentTimeMillis(), cont)` runs the actual save, then clears `t4.k` holder and calls `((tc.b)d).d()` (counter tick).

**Save core `b(now, cont)` (`wh/x.java:188`, dump-skipped):** computes `viewDurationMillis = now - f26940l` for the *previous* reel, builds a `ReelsScrollEvent`, persists via `ng.x` (SaveReelScrollEvent use case `nb.a`) and `WeekEventDb` via `ng.f`, updates `f26938j`/`f26940l`/`f26939k`. The 500 ms config timeout + the explicit `e(...)` 500 ms delay + the `lq.d` single-flight mutex together form the debounce.

### 3.11 Block decision feed — `td.e`/`td.d` + `ReelsAccessibilityService.d(...)`

Block state enum `td.d` (`td/d.java`): `NOT_SETUP(0)`, `BLOCK_ACTIVE(1)`, `REELS_ALLOWED(2)`, `REELS_LIMIT_REACHED(3)`, `REELS_EXHAUSTED(4)`, `PAUSED(5)`.

`ReelsAccessibilityService.d(cont)` (`ReelsAccessibilityService.java:380`): reads block snapshot `td.e`; **iff** `state == REELS_ALLOWED (f24042s)` **AND** `e.f24048b > 5` **AND** `e.f24050e == 5`, it shows the inline countdown overlay using string `block_reels_five_reels_left`:
```xml
<!-- strings.xml:161, id 0x7f1100c4 -->
<string name="block_reels_five_reels_left">%1$d more reels left!</string>
```
formatted with arg `5` → "**5 more reels left!**" (the "five reels left" nudge). Full block logic lives in [module-03](module-02-overlays-floating-bubble.md); this module only *triggers* it from the scroll path.

### 3.12 Fresh-start one-time onboarding — `ReelsAccessibilityService.i(appId, label, cont)`

`i(...)` (`ReelsAccessibilityService.java:523`):
```
day = qb.a.X(System.currentTimeMillis())     // start-of-day local midnight (Calendar, fields 11/12/13/14 = 0)
insertOrReplaceUserPrefLong(key="fresh_start_last_shown_day", value=day)   // wc.o.a(day, key, cont)
R = appId ; S = label                          // captured context (fields R/S)
navigationHandler.invoke( NavEvent(label=appId, count, FRESH_START enum th.k.FRESH_START) )
```
`qb.a.X` (`qb/a.java:413`) truncates to local midnight; `qb.a.Y` (`qb/a.java:423`) formats `yyyy-MM-dd` with `Locale.US` (the `statsDate` formatter, §4).

### 3.13 Stats rollup pipeline

```
ReelsScrollEvent  (one row per detected reel/scroll commit)
   └─ persisted to WeekEventDb table (eventTimestamp, appId, viewDurationMillis)   [7-day trail]
        └─ daily aggregate -> ReelsStats { totalCountToday, totalTimeMillisToday, lastUpdateTime, appWiseSplit:[AppReelsStats] }
             └─ AppReelsStats per appId { appId, displayName, count, totalTimeMillis }
                  └─ backend snapshot -> DailyReelsStats { brUserId, statsDate(yyyy-MM-dd), reelCount, rotScore }
```
`rotScore` is a derived "brain-rot" score on the daily backend snapshot; its formula is **not** in this module (see §11 / [02-backend-api-contract.md](02-backend-api-contract.md)).

---

## 4. Data models

### 4.1 ReelsScrollEvent — `…/domain/model/ReelsScrollEvent.java`

| Field | Java type | Nullable | Notes |
|---|---|---|---|
| `androidDeviceId` | String | **no** (`str.getClass()` null-check) | device ID from `AuthLibrary` |
| `brUserId` | String | **yes** | backend user id (null pre-auth) |
| `eventTimestamp` | long | no | `System.currentTimeMillis()` (ms, local clock) |
| `appId` | String | **no** | monitored package name |
| `viewDurationMillis` | long | no | time on the *previous* reel before this scroll |

### 4.2 WeekEventDb — `…/data/data_source/WeekEventDb.java` (local DB row)

| Field | Java type | Nullable | Notes |
|---|---|---|---|
| `eventTimestamp` | long | no | PK candidate (ms) |
| `appId` | String | no | package |
| `viewDurationMillis` | long | no | per-reel duration |

### 4.3 ReelsStats (daily in-memory snapshot) — `…/domain/model/ReelsStats.java`

| Field | Java type | Default | Notes |
|---|---|---|---|
| `totalCountToday` | int | 0 | |
| `totalTimeMillisToday` | long | 0 | |
| `lastUpdateTime` | long | `System.currentTimeMillis()` | |
| `appWiseSplit` | List\<AppReelsStats\> | `[]` | per-app breakdown |

### 4.4 AppReelsStats — `…/domain/model/AppReelsStats.java`

| Field | Java type | Nullable | Notes |
|---|---|---|---|
| `appId` | String | no | package |
| `displayName` | String | no | human app label |
| `count` | int | no | reels in app today |
| `totalTimeMillis` | long | no | time in app today |

### 4.5 DailyReelsStats (backend sync DTO) — `…/domain/model/DailyReelsStats.java`

| Field | Java type | Nullable | Notes |
|---|---|---|---|
| `brUserId` | String | **yes** | backend user id |
| `statsDate` | String | no | `yyyy-MM-dd`, `Locale.US` (`qb.a.Y`) |
| `reelCount` | int | no | total reels for the day |
| `rotScore` | int | no | derived score (formula in [02-backend-api-contract.md](02-backend-api-contract.md)) |

> **JSON keys:** no `@SerializedName` annotations survive in the decompiled DTOs — serialization is field-name based (likely Moshi/Gson with default naming). Confirm wire keys against the Retrofit interface ([02-backend-api-contract.md](02-backend-api-contract.md)) before freezing `json_serializable` keys. **OPEN QUESTION (§11).**

### 4.6 Dart target shapes

```dart
// freezed domain entities ------------------------------------------------
@freezed
class ReelsScrollEvent with _$ReelsScrollEvent {
  const factory ReelsScrollEvent({
    required String androidDeviceId,
    String? brUserId,
    required int eventTimestamp,      // epoch ms
    required String appId,
    required int viewDurationMillis,
  }) = _ReelsScrollEvent;
  factory ReelsScrollEvent.fromJson(Map<String, dynamic> j) => _$ReelsScrollEventFromJson(j);
}

@freezed
class AppReelsStats with _$AppReelsStats {
  const factory AppReelsStats({
    required String appId,
    required String displayName,
    required int count,
    required int totalTimeMillis,
  }) = _AppReelsStats;
}

@freezed
class ReelsStats with _$ReelsStats {
  const factory ReelsStats({
    @Default(0) int totalCountToday,
    @Default(0) int totalTimeMillisToday,
    required int lastUpdateTime,
    @Default(<AppReelsStats>[]) List<AppReelsStats> appWiseSplit,
  }) = _ReelsStats;
}

@freezed
class DailyReelsStats with _$DailyReelsStats {
  const factory DailyReelsStats({
    String? brUserId,
    required String statsDate,        // yyyy-MM-dd (DateFormat('yyyy-MM-dd','en_US'))
    required int reelCount,
    required int rotScore,
  }) = _DailyReelsStats;
  factory DailyReelsStats.fromJson(Map<String, dynamic> j) => _$DailyReelsStatsFromJson(j);
}

// native-side detection event (decoded off brainpal/detection) ------------
@freezed
class ReelDetectionEvent with _$ReelDetectionEvent {
  const factory ReelDetectionEvent({
    required String appId,
    String? videoId,                  // = DetectionData.videoIdentifier
    required bool isAd,
    required bool isPanelOpen,
    required int viewDurationMs,
    required int ts,                  // epoch ms
  }) = _ReelDetectionEvent;
}
```

```dart
// drift tables (Room -> drift) -------------------------------------------
class WeekEvents extends Table {                 // == WeekEventDb
  IntColumn  get eventTimestamp => integer()();  // ms
  TextColumn get appId          => text()();
  IntColumn  get viewDurationMillis => integer()();
  @override Set<Column> get primaryKey => {eventTimestamp};
}

class ScrollEvents extends Table {               // == ReelsScrollEvent local mirror
  IntColumn  get id            => integer().autoIncrement()();
  TextColumn get androidDeviceId => text()();
  TextColumn get brUserId      => text().nullable()();
  IntColumn  get eventTimestamp => integer()();
  TextColumn get appId         => text()();
  IntColumn  get viewDurationMillis => integer()();
}
```
> **OPEN QUESTION:** the original Room schema (table names, PKs, indices, retention/purge window — "WeekEventDb" implies a rolling 7-day window) is not visible in the decompiled DAO. Lift the `@Entity`/`@Dao` SQL from the Room-generated `…_Impl` classes before finalizing drift migrations.

---

## 5. Android deps → Flutter map

| Android API / class | Verdict | Flutter pkg or channel | Notes |
|---|---|---|---|
| `AccessibilityService` (`ReelsAccessibilityService`) | KEEP-NATIVE | native core + `brainpal/detection` EventChannel | No Dart equivalent; service stays Kotlin. |
| `AccessibilityNodeInfo` tree walk (`getRootInActiveWindow`, `getChild`, `getBoundsInScreen`, `getViewIdResourceName`, `getText`, `getContentDescription`, `isVisibleToUser`) | KEEP-NATIVE | — | Entirely native; only the boolean/ID result crosses the channel. |
| `AccessibilityEvent.getPackageName()` foreground gate | KEEP-NATIVE | — | Emits over `brainpal/detection`. |
| Service enable/disable & "is enabled" check | DART+CHANNEL | `brainpal/accessibility` MethodChannel (`isServiceEnabled`/`openSettings`/`serviceStatus`) + `brainpal/accessibility_status` EventChannel | `permission_handler` is **NOT** used for accessibility — must be a custom channel + `Settings.ACTION_ACCESSIBILITY_SETTINGS`. |
| `getResources().getDisplayMetrics().widthPixels` (screen width for 0.75 rule) | KEEP-NATIVE | — | Geometry cached natively (`l.f2514e`, set in `onServiceConnected` `:749`). |
| `System.currentTimeMillis()` (event ts, debounce, day bucket) | KEEP-NATIVE (emit), DART (rollup) | — | Day-bucket `qb.a.X` → Dart `DateTime` local-midnight; `qb.a.Y` → `DateFormat('yyyy-MM-dd','en_US')`. |
| `java.util.regex.Pattern` (handle `@[A-Za-z0-9_.\-]{3,30}`, numeric `^[\d,.KkMmBb%+\-\s]+$`) | KEEP-NATIVE | (mirror in Dart `RegExp` only for tests) | Compiled in `onServiceConnected` `:752` and `xh.e`/`zh.a`. |
| Room (`BrainRotRoomDatabase`, `WeekEventDb`, scroll/stat DAOs) | DART+CHANNEL | **drift** | Rollup/persistence moves to Dart; native core emits raw events. |
| WorkManager daily sync/rollup job | DART | **workmanager** | Periodic rollup + backend push (see [module-08](module-10-networking-sync.md)). |
| Firebase Remote Config (`on.b`) thresholds | DART | **firebase_remote_config** | Mirror `kc.a` keys. |
| Analytics events (`mc.a.b5`, `V6`, `K5`, `f16445c5`) | DART | **firebase_analytics** | Connect/disconnect/foreground markers (§9). |
| `w6.b` LocalBroadcastManager (`BRAINROT_ACCESSIBILITY_ACTION`), `USER_PRESENT` receiver | KEEP-NATIVE | `brainpal/system_events` / `brainpal/overlay_events` | Lifecycle + battle-unlock hooks; raise to Dart as events. |
| `AuthLibrary` device/user id | DART+CHANNEL | secure storage + auth module | Provides `androidDeviceId`/`brUserId`. |

---

## 6. iOS strategy

**Android-style detection is NOT POSSIBLE on iOS.** iOS sandboxes every app; there is no API to read another app's view hierarchy, view IDs, bounds, or text. The entire `b7.l`/`xh.*` parser tree has **no iOS counterpart**. Blocking is re-implemented on Apple's **Screen Time / Family Controls** stack behind the same Dart `ReelsDetectionRepository` interface.

| Capability (Android) | iOS reality |
|---|---|
| Detect *which* app is foreground + that it shows reels | **Not possible.** Use **FamilyControls** `FamilyActivityPicker` so the user *selects* Instagram/YouTube/TikTok/Snapchat/Facebook tokens; **DeviceActivity** monitors usage of those tokens. iOS cannot tell "reel vs. feed" or extract a `videoId` — granularity is per-app usage, not per-reel. |
| Per-reel `videoIdentifier`, `isAd`, `isPanelOpen` | **Not possible.** No per-video signal exists. Detection events on iOS carry only `appId` + usage interval. `isAd`/`videoId` are always null on iOS. |
| Scroll counting | **Not possible** (no scroll signal). iOS reports *time-on-app* via DeviceActivity thresholds, not scroll counts. Counting-based features degrade to time-based on iOS. |
| Blocking overlay on reel | **ManagedSettings + Shield UI** (`ShieldConfiguration`, `ShieldActionDelegate`) shields the whole app when a DeviceActivity threshold trips — app-level, not reel-level. |
| The 0.75/BFS/keyword heuristics | **Dropped on iOS** — irrelevant without tree access. |

**Consequence for the domain layer:** `ReelDetectionEvent.videoId/isAd/isPanelOpen` must be optional (already nullable above). UI copy that says "reels detected" must fall back to "minutes on \<app\>" on iOS. Requires the **Family Controls** entitlement (Apple approval) and a **DeviceActivityMonitor** app extension. See [01-platform-channel-contracts.md](01-platform-channel-contracts.md) for the shared channel that the iOS Screen Time bridge also implements.

---

## 7. Platform-channel surface

This module **produces** `brainpal/detection` and **consumes** `brainpal/accessibility*`. (It does not directly drive overlays — it *triggers* [module-02](module-02-overlays-floating-bubble.md)/[module-03](module-02-overlays-floating-bubble.md) via `brainpal/overlay` and `brainpal/challenges`, documented there.)

### 7.1 `EventChannel "brainpal/detection"` (native → Dart)

Emitted by `wh.x` after a debounced scroll commit (one event per detected reel/scroll).

```jsonc
{
  "appId":         "com.instagram.android",  // String, from f14465b
  "videoId":       "ch_@handle_title…",       // String|null  == DetectionData.videoIdentifier
  "isAd":          false,                      // bool         == DetectionData.isAd
  "isPanelOpen":   false,                      // bool         == DetectionData.isPanelOpen
  "viewDurationMs": 4210,                      // int  == now - prev f26940l
  "ts":            1751280000000               // int  epoch ms (System.currentTimeMillis)
}
```

### 7.2 `MethodChannel "brainpal/accessibility"` (Dart → native)

| Method | Args | Returns | Maps to |
|---|---|---|---|
| `isServiceEnabled` | — | `bool` | `ReelsAccessibilityService.U` static flag (`onServiceConnected`/`onDestroy`) |
| `openSettings` | — | `void` | `Settings.ACTION_ACCESSIBILITY_SETTINGS` (config `settingsActivity` = MainActivity) |
| `serviceStatus` | — | `{enabled:bool, connectedAtMs:int?}` | derived from `U`/`onServiceConnected` |

### 7.3 `EventChannel "brainpal/accessibility_status"` (native → Dart)

`{ "enabled": true }` / `{ "enabled": false }` on `onServiceConnected` (`:742`, sets `U=true`, analytics `b5`, userprop `V6=true`) and `onDestroy`/`onUnbind` (`:684`/`:815`, `U=false`, analytics `f16445c5`, userprop `V6=null`).

> All four channel names are frozen in [01-platform-channel-contracts.md](01-platform-channel-contracts.md). On iOS the same Dart consumers receive Screen-Time-sourced events (appId-only, null videoId).

---

## 8. State management & DI

| Native (Kotlin) | Dart target |
|---|---|
| `e K = Channel(-1, BUFFERED)` detection channel (`ReelsAccessibilityService.java:110`); `K.j(pkg)` trySend in `onAccessibilityEvent` | `brainpal/detection` EventChannel → `Stream<ReelDetectionEvent>` |
| `wh.x.f26934f = lq.d` (single-flight mutex/queue) | stays native; Dart side is post-debounce |
| `wh.x` scroll counters (`f26938j`, `f26939k`, `f26940l`) | stays native |
| Block snapshot `td.e` Flow (consumed in `d()`) | `brainpal/overlay`/`challenges` (module-03) |

**Riverpod (presentation/domain):**
```dart
@riverpod Stream<ReelDetectionEvent> reelDetectionStream(Ref ref) =>
    ref.watch(detectionChannelProvider).events;          // EventChannel("brainpal/detection")

@riverpod class ReelsStatsNotifier extends _$ReelsStatsNotifier {
  // listens to reelDetectionStream, upserts WeekEvents/ScrollEvents (drift),
  // recomputes ReelsStats (today) + AppReelsStats split, exposes ReelsStats
}

@riverpod Stream<bool> accessibilityEnabled(Ref ref) =>
    ref.watch(accessibilityStatusChannelProvider).enabledStream; // "brainpal/accessibility_status"
```

**get_it + injectable (non-UI singletons):** `ReelsDetectionRepository` (platform-channel impl, Android vs iOS), `ReelsStatsDao` (drift), `RemoteConfigThresholds` (mirrors `kc.a`), `ScrollSyncWorker` handle (workmanager). The native Hilt graph (`onCreate` `:652` injects `reelsScrollManager x`, `navigationHandler u0`, `overlayPermissionChecker`, `logAnalyticsEvent pc.d`, `battleNotificationUnlockTracker u`) is replaced by get_it for the Dart half; the native half retains a thin manual DI for the detection core.

---

## 9. User flows

**A. Service startup**
1. [native] User enables accessibility in system settings (deep-linked via `brainpal/accessibility.openSettings`). [channel/dart]
2. [native] `onCreate` (`:652`) injects deps (Hilt).
3. [native] `onServiceConnected` (`:742`): `U=true`; cache `widthPixels` into parser `l.f2514e`; build `xh.e/d/b` parsers; register `BRAINROT_ACCESSIBILITY_ACTION` + `USER_PRESENT` receivers; analytics `b5`; userprop `V6=true`.
4. [channel] `brainpal/accessibility_status` emits `{enabled:true}`. [dart]

**B. Foreground app switch → detection**
1. [native] `onAccessibilityEvent` (`:637`): set `V=pkg`, `W=now`; if `pkg ∈ f14465b` → `K.j(pkg)`.
2. [native] settle loop `c(...)` (≤5×150 ms) confirms root window package (`:291`).
3. [native] route to app parser: YouTube `b7.l.f`+`xh.e`, Snapchat `xh.d`, IG/FB `xh.b`, TikTok special-case.
4. [native] parser returns `DetectionData{isDetected,videoIdentifier,isPanelOpen,isAd}`.

**C. Reel detected → scroll commit**
1. [native] `wh.x` flush guard (`a/c/f`) passes only if `f26939k!=null || f26940l>0 || pending` (debounce).
2. [native] `b(now)` computes `viewDurationMillis = now - f26940l`, builds `ReelsScrollEvent`, persists `WeekEventDb`, bumps counters.
3. [channel] `brainpal/detection` emits `ReelDetectionEvent`. [dart]
4. [dart] `ReelsStatsNotifier` upserts drift rows, recomputes today's `ReelsStats`/`AppReelsStats`; bubble/widget update via module-02/06.
5. [native] if block state `REELS_ALLOWED && count>5 && f24050e==5` → "%1$d more reels left!" nudge (`d()`), then module-03 takes over at the limit.

**D. Daily rollup**
1. [dart] workmanager periodic job at local day boundary (`DateTime` midnight; mirror `qb.a.X`).
2. [dart] aggregate `WeekEvents` for today by `appId` → `ReelsStats` + per-app `AppReelsStats`.
3. [dart] build `DailyReelsStats{brUserId, statsDate=yyyy-MM-dd (en_US), reelCount, rotScore}`; POST to backend ([02-backend-api-contract.md](02-backend-api-contract.md)).
4. [dart] purge `WeekEvents` older than the retention window (confirm window — §11).

**E. Fresh-start (once per install/upgrade)**
1. [native] `i(appId,label)` (`:523`): write `fresh_start_last_shown_day = qb.a.X(now)`; set `R/S`; fire `FRESH_START` nav event.
2. [dart] onboarding/invite surface shown once.

**F. Service stop**
1. [native] `onDestroy`/`onUnbind` (`:684`/`:815`): `U=false`; unregister receivers (try/catch); cancel scope `b0.j(G,null)`; analytics `f16445c5`; userprop `V6=null`.
2. [channel] `brainpal/accessibility_status` emits `{enabled:false}`. [dart]

---

## 10. Parity risks & validation

### 10.1 Module-specific risks

| # | Risk | Why it bites | Mitigation |
|---|---|---|---|
| R1 | **View-ID drift** (YouTube/IG/Snapchat rename obfuscated IDs across app updates) | `watch_panel_scrim`, `reel_recycler`, `0_resource_name_obfuscated`, `spotlight_container` are brittle | Port verbatim, but version-gate IDs in Remote Config; alert on detection-rate drop. |
| R2 | **IG/FB view-IDs un-recovered** (§3.6) | `xh.b.a` body was a JADX dump-skip; geometry+ID format unknown | Lift from smali before port; block release until golden replay (below) passes for IG/FB. |
| R3 | **TikTok detection path ambiguous** (§3.7) | If TikTok is "always-reel" vs. tree-parsed, counts differ wildly | Confirm from smali; replay TikTok captures both ways and diff counts. |
| R4 | **Debounce reproduction** | 500 ms config + 500 ms `e()` + `lq.d` single-flight + 150 ms settle interact; naive Dart debounce will over/under-count | Keep counting native; replay-test event timing. |
| R5 | **Day-boundary timezone** | `qb.a.X` is *local* midnight; `qb.a.Y` is `Locale.US`; backend tz unknown | Mirror local-midnight exactly; pin `DateFormat('yyyy-MM-dd','en_US')`; clarify backend tz (§11). |
| R6 | **videoId format break** changes dedup behavior | downstream dedup/leaderboard relies on exact ID strings (`ch_…`, `snapchat_spotlight_…`, `yt[_ad]_…`) | Snapshot-test every ID-format branch. |
| R7 | **iOS feature gap** | no scroll/reel/ad signal | Domain layer nullable fields + time-based fallback UI (§6). |

### 10.2 Golden-event replay harness (the primary validation mechanism)

The detection core is pure-ish: `(AccessibilityNodeInfo tree, foregroundPkg) → DetectionData` and `(stream of detection events) → ReelsScrollEvent[]`. Build a **record/replay golden harness** so the Kotlin port is proven byte-identical to the decompiled original, then proven equivalent across native↔Dart counting.

**Step 1 — Capture goldens from the live original app.** Instrument a debug build (or run the decompiled APK) with a tap point that serializes each `AccessibilityNodeInfo` root into a JSON tree:
```json
// golden-tree.json (one per scenario)
{ "viewId": "...|null", "text": "...|null", "contentDescription": "...|null",
  "className": "...", "bounds": [left,top,right,bottom],
  "isVisibleToUser": true, "isEnabled": true, "isSelected": false,
  "children": [ … recursively … ] }
```
Capture a matrix: **{IG, FB, YouTube-shorts, YouTube-panel-open, Snapchat-spotlight, Snapchat-ad, TikTok} × {normal reel, ad reel, non-reel feed, comments-open}**. Record the *expected* `DetectionData{isDetected, videoIdentifier, isPanelOpen, isAd}` produced by the original for each tree.

**Step 2 — Tree-level parity test (native).** Feed each `golden-tree.json` through a `FakeAccessibilityNodeInfo` adapter into the ported Kotlin `b7.l`/`xh.*` and assert the resulting `DetectionData` equals the recorded golden **field-for-field** (including the exact `videoIdentifier` string). This pins the 0.75 rule, the ≤10 px clustering, the 1500-node BFS, every blacklist term, every CTA keyword, and every ID-format branch.

**Step 3 — Stream-level counting parity.** Record a timestamped trace of detection events from a real scrolling session (`[{ts, DetectionData}]`). Replay it through (a) the native `wh.x` debounce and (b) the Dart rollup, asserting identical `ReelsScrollEvent[]`, `viewDurationMillis` values, per-app counts, and daily `ReelsStats`. Include adversarial timings: bursts < 500 ms apart (must collapse), app-switch mid-reel, screen-off mid-stream.

**Step 4 — Constant lock test.** A unit test asserts the literal sets/regexes (`kc.a.f14465b`, `xh.e.f27722b`, `xh.d.f27718b`/`f27719c`, `xh.b.f27713c`, `zh.a.f29317f`, handle regex, `notificationTimeout=500`, block thresholds `>5`/`==5`) match the verbatim values in §3 — this fails loudly if anyone "tidies" a keyword.

**Step 5 — CI gate.** Goldens live in `test/goldens/detection/`; the harness runs on every change to the native core or Dart rollup. A detection-rate regression on any golden blocks merge.

---

## 11. Open questions

1. **IG/FB view-IDs & geometry** — `xh.b.a` (`xh/b.java:36`) body is a JADX dump-skip; the exact `com.instagram.android:id/…` / `com.facebook.katana:id/…` view IDs, geometry usage, and `videoIdentifier` format are **not recovered**. Must be lifted from smali. *(blocks R2)*
2. **TikTok detection path** — no dedicated `xh.*` TikTok parser found. Is TikTok treated as always-reel (foreground = reel) or routed through `xh.b`? *(blocks R3)*
3. **Room schema** — table names, PKs, indices, and the `WeekEventDb` **retention/purge window** (7 days implied by name) are not in the decompiled DAO; lift from Room `…_Impl`.
4. **`rotScore` formula** — derived on `DailyReelsStats`; computation not in this module. See [02-backend-api-contract.md](02-backend-api-contract.md).
5. **Wire JSON keys** — DTOs have no `@SerializedName`; confirm backend key names (Retrofit interface) before freezing `json_serializable`.
6. **Backend timezone** — `statsDate` is `Locale.US yyyy-MM-dd` from a `System.currentTimeMillis()` taken at local midnight; does the backend interpret it as local or UTC?
7. **`viewDurationMillis` for the first reel** — `now - f26940l` when `f26940l==0` would be huge; confirm the guard in `wh.x.b` (dump-skipped) clamps the first event.
8. **`xh.e.b` BFS cap** — YouTube extraction has no explicit 1500 cap (relies on early-exit); confirm whether unbounded walks ever occur on pathological trees (perf).
9. **`mc.a` analytics enum** — confirm the human names for `b5`, `V6`, `K5`, `f16445c5` for parity logging.

---

## 12. Migration checklist

**Phase 0 — Recover the un-decompiled bits (blocking)**
- [ ] Lift `xh.b.a` IG/FB view-IDs, geometry, and `videoIdentifier` format from smali (Q1).
- [ ] Determine TikTok detection path (Q2); document as a parser or as always-reel.
- [ ] Extract Room `@Entity`/`@Dao` SQL + retention window from `…_Impl` classes (Q3).
- [ ] Confirm backend JSON keys + timezone + `rotScore` (Q4–Q6) with [02-backend-api-contract.md](02-backend-api-contract.md).

**Phase 1 — Native detection core (verbatim port)**
- [ ] Port `kc.a` (monitored list `f14465b`, TikTok subset `f14464a`) byte-identical.
- [ ] Port `b7.l` geometry (BFS, midpoints, ≤10 px clustering, 0.75/0.25 rule, `maxRight`).
- [ ] Port `xh.e` (YouTube: blacklist terms, handle regex, ad CTA `f27722b`, ID format + 40-char cap).
- [ ] Port `xh.d` (Snapchat: gate IDs, ≤1500 BFS, UI-labels `f27719c`, CTA `f27718b`, badge `zh.a.f29317f`, ID format + `/10000` bucket).
- [ ] Port `xh.b` (IG/FB: tokenizer `f27712b`, CTA `f27713c`, `zh.a` blacklists) once Q1 resolved.
- [ ] Port `wh.x` scroll state-machine (`lq.d` single-flight, `f26939k/f26940l` guard, `viewDurationMillis` math) + the 500 ms `e()` delay + 150 ms×5 settle loop.
- [ ] Replicate `res/xml/accessibility_service_config.xml` (`notificationTimeout=500`, the 4 flags, `canRetrieveWindowContent`, `canPerformGestures`).

**Phase 2 — Channel surface**
- [ ] Implement `brainpal/detection` EventChannel emitting `ReelDetectionEvent` from `wh.x` commits (§7.1).
- [ ] Implement `brainpal/accessibility` MethodChannel (`isServiceEnabled`/`openSettings`/`serviceStatus`).
- [ ] Implement `brainpal/accessibility_status` EventChannel from `onServiceConnected`/`onDestroy`/`onUnbind`.
- [ ] Freeze payloads against [01-platform-channel-contracts.md](01-platform-channel-contracts.md).

**Phase 3 — Dart domain/data/rollup**
- [ ] Generate freezed `ReelsScrollEvent`/`AppReelsStats`/`ReelsStats`/`DailyReelsStats`/`ReelDetectionEvent` (§4.6).
- [ ] drift `WeekEvents`/`ScrollEvents` tables + DAO; mirror Room schema (Q3).
- [ ] `ReelsStatsNotifier` (Riverpod) consuming `reelDetectionStream`; daily rollup via workmanager.
- [ ] Mirror `kc.a` thresholds via firebase_remote_config; fresh-start day key (`qb.a.X` local midnight, `qb.a.Y` en_US).

**Phase 4 — iOS Screen Time bridge**
- [ ] Add Family Controls entitlement + DeviceActivityMonitor extension.
- [ ] `FamilyActivityPicker` token selection for the 5 apps; emit appId-only detection events (null videoId/isAd) over `brainpal/detection`.
- [ ] Shield UI (ManagedSettings) wired to time-based thresholds; time-based fallback copy in UI.

**Phase 5 — Validation (golden replay)**
- [ ] Capture golden trees + expected `DetectionData` matrix (§10.2 Step 1).
- [ ] Tree-level parity tests (Step 2) for all apps/scenarios.
- [ ] Stream-level counting parity tests with adversarial timings (Step 3).
- [ ] Constant-lock test for every verbatim set/regex/threshold (Step 4).
- [ ] Wire CI gate on `test/goldens/detection/` (Step 5).
