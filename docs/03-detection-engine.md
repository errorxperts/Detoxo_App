# Detection & Block Engine (core)

This is the heart of the app: a data-driven engine that, on every Android `AccessibilityEvent`, decides whether the current screen is short-form video (Instagram Reels, YouTube Shorts, TikTok, Facebook Reels, browser short URLs, etc.) and, if so, executes a block action (back-press, kill app, lock screen, or overlay). This document reconstructs the **verified** detection/block algorithm from the decompiled native Android app and then designs the equivalent **Flutter (flutter_bloc + Clean Architecture)** system, marking exactly which pieces must stay native (⚠️), which a pub.dev package covers (✅), and which are impossible on iOS (❌). The original engine is decompiled and obfuscated; method bodies that could not be read are explicitly labeled **(inferred)**.

> **Legend** — ✅ pure-Dart / pub.dev package handles it · ⚠️ requires a native Kotlin MethodChannel/EventChannel · ❌ not possible on iOS.

---

## 1. The Event Loop

### 1.1 What fires the loop

The native `AccessibilityService` is configured (in `res/xml/site_manager_service.xml`) with `accessibilityEventTypes="typeAllMask"`, `notificationTimeout=100`, and flags `flagRetrieveInteractiveWindows | flagRequestFilterKeyEvents | flagRequestEnhancedWebAccessibility | flagReportViewIds`. `flagReportViewIds` is what makes `getViewIdResourceName()` return values like `com.instagram.android:id/clips_author_username` — without it the entire detection scheme breaks. The service runs in an **isolated process** (`:as_process`) so a crash in the tree-walker never takes down the UI.

The decompiled `onAccessibilityEvent` body is obfuscated ("Method dump skipped, 1217 units") so the exact per-event sequencing is **(inferred)**, but every constant and downstream method it calls is verified. The reconstructed loop:

```
onAccessibilityEvent(event):                                  # (inferred ordering)
    source   = event.source                                   # AccessibilityNodeInfo (nullable)
    pkg      = event.packageName
    now      = System.currentTimeMillis()

    # (1) PER-PACKAGE THROTTLE — verified constant THROTTLE_INTERVAL_MS = 150
    last = packageThrottleMap[pkg]                             # ConcurrentHashMap<String,Long>
    if last != null AND now - last < 150: return              # drop flood of events during fast scroll
    packageThrottleMap[pkg] = now

    # (2) ACTIVE-PLAN GATE  (PlansEnum: BLOCK_ALL | CURIOUS | ONE_REEL | PAUSED)
    plan = serviceModel.activeDetectionPlan.value
    if plan == PAUSED   and pauseData.phase blocks access:  return     # see §1.3
    if plan == CURIOUS  and curiousData.phase blocks access: ...       # see §1.3

    # (3) DETECTOR DISPATCH — find the Platform for pkg in platformsConfig, run its detectors
    response = dispatchDetectors(pkg, source, event)         # ShortContentDetectionResponse | null
    if response == null: return

    # (4) HAND OFF to gating + block
    handleShortVideoDetection(pkg, response.platform, response.node)
```

| Stage | Mechanism | Verified source |
|---|---|---|
| Per-package throttle | `packageThrottleMap` (`ConcurrentHashMap`), interval `THROTTLE_INTERVAL_MS = 150` | `NoScrollAccessibilityService.java:115-116` |
| Active-plan gate | `serviceModel.activeDetectionPlan` (StateFlow of `PlansEnum`) | `NoScrollServiceModel` |
| Detector dispatch | per-platform detectors from `platforms_config.json` | `res/raw/platforms_config.json` |
| Hand-off | `handleShortVideoDetection$app(pkg, DetectedReelConfig, node, …)` | `NoScrollAccessibilityService.java:291` |

### 1.2 PlansEnum

| Plan | Meaning |
|---|---|
| `BLOCK_ALL` | Block every detected short-video unconditionally. |
| `CURIOUS` | Pomodoro-style: a watch SESSION window, then a COOLDOWN window that blocks. |
| `ONE_REEL` | Allow exactly one reel via an auto-hiding overlay, then block (see §7). |
| `PAUSED` | Blocking suspended for a window, then a lockdown window, then resume. |

### 1.3 Plan-phase gating (verified phase math)

**`PauseSessionData.getCurrentPhase()`** → `PAUSED | PAUSED_COOLDOWN | IDLE`:

```
pauseEnd    = pausedOn + pauseDuration
cooldownEnd = pauseEnd + lockDownDuration
now < pauseEnd      -> PAUSED            # access allowed
now < cooldownEnd   -> PAUSED_COOLDOWN   # blocked unless allowInLockDown == true
otherwise           -> IDLE              # resume _planToResume
```

**`CuriousSessionData.getCurrentPhase()`** → `SESSION | COOLDOWN | IDLE`:

```
sessionEnd  = shortVideoSessionStartTime + sessionDuration*60000
cooldownEnd = sessionEnd + cooldownDuration*60000
now in [start, sessionEnd)   -> SESSION   # videos allowed
now in [sessionEnd, cooldownEnd) -> COOLDOWN  # blocked unless isVideoAllowedInCooldown
otherwise                    -> IDLE
```

---

## 2. The Verified 3-Stage View-ID Detection Algorithm

This is the single most important verified routine: `LegacyDetector.findViewByIdWithId(root, event, identifiers, packagePrefix, detectorEnum)`. It returns `Pair<AccessibilityNodeInfo, String>` (matched node + a debug tag) or `null`. `identifiers` come straight from `platforms_config.json` (e.g. `":id/reel_player_underlay"`). `packagePrefix` is the foreground app package; the search key is `packagePrefix + identifier` (e.g. `com.google.android.youtube` + `:id/reel_player_underlay`). The `VIEWID_RES_NAME` variant matches the **full** resource name instead and uses an empty prefix.

### 2.1 Stages (verified, `LegacyDetector.java:102-164`)

1. **Stage 1 — event-source fast path.** Read `event.source.getViewIdResourceName()`. For each identifier, if it equals `prefix+id` (or, in `VIEWID_RES_NAME` mode, equals the bare identifier) **and** `source.isFocusable() && source.isVisibleToUser()`, return immediately. Cheapest path; most scroll events land here.
2. **Stage 2 — direct API lookup.** For each identifier call `root.findAccessibilityNodeInfosByViewId(prefix+id)`. Return the first result with `isVisibleToUser()`; tag the match `" [FIND]"`.
   - **Note:** Stage 2 checks only `isVisibleToUser()` (not focusable), whereas Stage 1 and Stage 3 also require focusability/visibility. This is verified, not a paraphrase.
3. **Stage 3 — bounded DFS.** Push `root` onto an `ArrayDeque`; loop while non-empty **and `i < 12000`**. Each iteration: `removeLast()` (LIFO → depth-first), `i++`, test `getViewIdResourceName()` against identifiers; on a visible match, recycle the deque (keeping root + match) and return tag `" [DEEP]"`. Children are pushed via `addLast()` in reverse (`childCount-1 .. 0`) so the tree is walked left-to-right. Every popped node except root is `recycle()`-d to avoid handle leaks.

### 2.2 Pseudocode (clean reconstruction, semantics verified)

```
findViewByIdWithId(root, event, identifiers, prefix, mode):
    # ── Stage 1: event source ────────────────────────────
    src = event?.source
    if src and src.viewIdResourceName != null:
        rid = src.viewIdResourceName
        for id in identifiers:
            if rid == prefix+id  or  (mode == VIEWID_RES_NAME and rid == id):
                if src.isFocusable and src.isVisibleToUser:
                    return (src, substringAfter(rid, ":id/"))

    # ── Stage 2: direct API ──────────────────────────────
    for id in identifiers:
        nodes = root.findAccessibilityNodeInfosByViewId(prefix+id)
        for n in nodes:
            if n.isVisibleToUser: return (n, id + " [FIND]")

    # ── Stage 3: bounded DFS (LIFO ArrayDeque, cap 12000) ─
    dq = ArrayDeque(); dq.addLast(root); i = 0
    while dq.notEmpty and i < 12000:
        node = dq.removeLast(); i++
        rid = node.viewIdResourceName
        if rid != null:
            for id in identifiers:
                if rid == prefix+id or (mode == VIEWID_RES_NAME and rid == id):
                    if node.isVisibleToUser:
                        recycleDequeExcept(dq, root, node)
                        return (node, substringAfter(rid, ":id/") + " [DEEP]")
        for c in childCount-1 .. 0:                  # reverse push = left-to-right DFS
            child = node.getChild(c); if child: dq.addLast(child)
        if node != root: node.recycle()
    recycleDequeExcept(dq, root, null)
    return null
```

### 2.3 Other `ViewDetectorsEnum` strategies

| Enum (ordinal) | Strategy | Notes |
|---|---|---|
| `FINDBYID` (1) | Match `prefix + ":id/..."` via the 3-stage algorithm. | Primary path; identifiers strip to bare `:id/x`. |
| `VIEWID_RES_NAME` (2) | Same 3 stages but matches the **full** resource name (empty prefix). | For apps whose ids don't share the package prefix. |
| `CONT_DESC` (3) | Match `getContentDescription()` against identifiers. | **(inferred)** body — used where ids are missing but labels stable. |
| `BROWSER` (4) | URL extraction + domain matching (see §2.4). | Body obfuscated. |

### 2.4 Web (BROWSER) detection — verified helpers, inferred body

`webDetection(platformId, root, event, restrictions, cache, useCache)` is obfuscated ("Method dump skipped, 400 units") but its return shape was recovered from the JADX comment and its helpers are fully readable:

- **`URL_IN_TEXT`** regex (verified): `https?://[^\s<>"]+`.
- **`parseWebUrlParts(s)`** (verified): strips leading Unicode directional/BOM marks `{65279, 8206, 8207, 8234, 8235, 8236, 8294, 8295, 8296, 8297}`; lowercases; strips `https://` / `http://` / `//`; splits host vs path at first `/`; trims trailing `/` and `.`; canonicalizes host by repeatedly removing `www.` and `m.` leading labels. Returns `WebUrlParts(hostRaw, hostCanonical, path)`.
- **`matchesSubdomainWildcard(pattern, host)`** (verified): if pattern starts with `*.`, the bare host matches the suffix exactly or ends with `"." + suffix`.
- **`pathMatchesDomainScope(urlPath, scopePath)`** (verified): true if `scopePath` is empty, else `urlPath == scopePath` or `urlPath.startsWith(scopePath + "/")` (prefix match).
- **Return (recovered from JADX comment):** on match, returns `ShortContentDetectionResponse(node, DetectedReelConfig(platformId, "Web blocking", isBrowser=true, packageName=platformId, iconUrl="", premiumExclusive=true, supportedBlockModes = all BlockingModesEnum entries, supportsOverlay=true))`.
- **`WebMatchTypeEnum`** = `DOMAIN | EXACT | WILDCARD`.

---

## 3. Detection-Type Routing

Each `Platform` in `platforms_config.json` carries a `detectionType` (`DetectionTypeEnum`). The dispatcher routes on it **before** running detectors:

| `DetectionTypeEnum` (ordinal) | Engine | iOS |
|---|---|---|
| `LEGACY` (1) | View-id / content-desc / browser via `LegacyDetector` (§2). | ❌ no AccessibilityService. |
| `OVERLAY` (2) | Show a system overlay (`OverlayType.CALIBRATION`); user/ML confirms. | ❌ |
| `MANUAL` (3) | User-defined rules (inferred). | ❌ |
| `CALIBRATION` (4) | Screen-zone bounds match for in-app/webview content with no stable ids (§3.1). | ❌ |
| `NONE` (5) | Detection disabled for this platform. | n/a |

### 3.1 CALIBRATION (screen-zone matching)

When a platform's UI exposes no reliable view-ids (in-app webviews, custom renderers), the app falls back to **pixel/zone** matching tuned per device. The server returns `PlatformCalibrationConfig` per `EnumDeviceConfig` (`MOBILE | TABLET | LANDSCAPE | LANDSCAPE_TABLET`) with `width`/`height` floats and a constraints map keyed by `CalibrationConstrainPosition` (`TOP | BOTTOM | RIGHT | LEFT`) → margin doubles. These flatten at runtime into `CalibratedConfig { x, width, platformId, packageName, supportedBlockActions, detectionParams, coupleWith, haltOnDetect, priority, supportsOverlay }`, cached in `DisplayConfig.calibratedConfig[platformId]`.

Detection (inferred from data shape): take the candidate node's `getBoundsInScreen()`, compare its horizontal position against the zone `[x, x+width)`; if inside (and `detectionParams` thresholds pass), treat as short-form content. `PlatformConfigMetaData.supportStatusEnum` (`UPDATE_REQUIRED | NOT_SUPPORTED | FRESH | SUPPORTED`) and `min/maxPlatformVersion` gate whether the config is even usable. Recalibrated on `onConfigurationChanged` (rotation) by re-measuring `DisplayMetrics`.

> **Flutter:** CALIBRATION business logic is ✅ pure Dart (zone arithmetic, version gating). It still depends on ⚠️ native node bounds arriving from the AccessibilityService event payload.

---

## 4. Priority, haltOnDetect, coupleWith, childNodeLimit

A platform's `detectors` is a map keyed by `ViewDetectorsEnum`; each entry carries:

| Field | Type | Semantics (verified shape; ordering inferred) |
|---|---|---|
| `priority` | int | Detectors evaluated in **ascending** priority (lower = first). |
| `haltOnDetect` | bool | On a match: `true` → return immediately, skip remaining detectors; `false` → keep evaluating. |
| `coupleWith` | List&lt;String&gt; | Secondary confirmation: a primary match is only accepted if a child matching one of these ids exists (reduces false positives, e.g. "reel player" only counts if it also contains the expected child). |
| `childNodeLimit` | int | Bounds the child search depth for `coupleWith` validation; `-1` = unbounded. |
| `identifiers` | List&lt;String&gt; | The `:id/...` (or full) resource names to match. |
| `supportedBlockModes` | List&lt;BlockingModesEnum&gt; | Allowed block actions for this detector. |
| `defaultBlockMode` | BlockingModesEnum | Preferred action. |
| `paramsClass` / `params` | int / String | Overlay params (JSON) for OVERLAY detection. |
| `detectionParams` | object | Extra thresholds (e.g. CALIBRATION). |

**Verified real entry** (`res/raw/platforms_config.json`, YouTube Shorts):

```json
"FINDBYID": {
  "supportedBlockModes": ["PRESS_BACK", "KILL_APP"],
  "defaultBlockMode": "PRESS_BACK",
  "priority": 0,
  "identifiers": [":id/reel_player_underlay"],
  "childNodeLimit": -1,
  "haltOnDetect": true,
  "coupleWith": []
}
```

**Verified identifiers seen in config / facts:** YouTube Shorts `:id/reel_player_underlay`; YouTube Vanced Shorts `:id/progress`; Instagram Reels `:id/clips_author_username`; Instagram Feed `:id/media_group`; Insta Pro `:id/reel_viewer_title`.

---

## 5. Timing Constants (all verified)

| Constant | Value | Location | Purpose |
|---|---|---|---|
| `THROTTLE_INTERVAL_MS` | `150` ms | `NoScrollAccessibilityService.java:116` | Per-package event throttle. |
| block debounce | `1200` ms | `…:203` (`now - lastBlockTime <= 1200` → skip) | Prevents double-block from one scroll burst. |
| back rate-limit | `1100` ms | `…:241` (`lastVideoBlocked <= now - 1100`) | Limits repeated `performGlobalAction(BACK)`. |
| `ONE_REEL_OVERLAY_GRACE_MS` | `500` ms | `…:111` | Grace before ONE_REEL overlay auto-hides. |
| `ONE_REEL_OVERLAY_POLL_MS` | `500` ms | `…:112` | Poll interval for the auto-hide loop. |
| `HARD_BLOCK_AFTER_CLOSE_TAP_MS` | `ServiceProvider.SCAR_VERSION_FETCH_TIMEOUT` (~10000 ms) | `…:114` | Hard-block grace after a close-tap. |
| DFS cap | `12000` iterations | `LegacyDetector.java:135` | Bounds tree walk. |
| AppLocker attempt debounce | `2000` ms / deque cap `4` | `AppLockerProcessor` | Brute-force unlock throttle. |
| `notificationTimeout` | `100` ms | `site_manager_service.xml` | Min interval for accessibility feedback. |
| FGS notification id | `1125`, channel `noscroll_protection_channel` (LOW) | `…:543-562` | Foreground service. |

> The atomics: `lastBlockTime = AtomicLong(-1)`, `hardBlockUntilMs = AtomicLong(0)`; `lastVideoBlocked` is a plain `Long` on `NoScrollServiceModel`.

---

## 6. Block-Mode Execution

`blockShortContent$app(now, mode, pkg, platformId, planName)` (verified, `NoScrollAccessibilityService.java:200-251`):

1. **Debounce:** if `now - lastBlockTime.get() <= 1200` → log and return.
2. **Analytics:** if `platformId` non-blank, fire Firebase event `"<platformId>_blocked"`; `lastBlockTime.set(now)`; launch async DB write on `Dispatchers.Default`.
3. **Switch on `BlockingModesEnum.ordinal()`:**

| `BlockingModesEnum` (ordinal) | Action | Verified detail |
|---|---|---|
| `PRESS_BACK` (1) | `performGlobalAction(1)` = `GLOBAL_ACTION_BACK` | Only if `lastVideoBlocked <= now - 1100`; then set `lastVideoBlocked = now`; then haptic `VibrationMode.VIDEO_BLOCKED` if vibration enabled (gated by premium plan). |
| `KILL_APP` (2) | `pressBackAndThenRestrictApp(AppLockActionEnum.CLOSE_APP)` | Back-press then AppLocker close (CLOSE_APP timeout 15000 ms). |
| `LOCK_SCREEN` (3) | `pressBackAndThenRestrictApp(AppLockActionEnum.LOCK_SCREEN)` | Back-press then device lock (LOCK_SCREEN timeout 30000 ms). |
| `NONE` (4) | no-op | Returns. |

The haptic call (verified line 248): `BundleCompat.performVibration(this, premiumPlans.value, isVibrationEnabled.value, VibrationMode.VIDEO_BLOCKED)` — so haptics depend on both the vibration setting and premium status.

### 6.1 Hard-block grace window

`handleShortVideoDetection$app` (verified, `…:291-324`) branches on `hardBlockUntilMs`:

- **`now >= hardBlockUntilMs`** (normal): delegate to `serviceModel.processAndBlockShortContent(pkg, reelConfig, onPreBlock, onBlock, onNode, cont)` — the full gating chain (pause / curious / premium / quota / restriction). Body obfuscated → gating order is **(inferred)**; see §8.
- **`now < hardBlockUntilMs`** (inside grace): resolve a mode directly and block without the full gating. Mode resolution (verified):
  1. start with `serviceModel.defaultBlockingMode.value`;
  2. if that is `null`/`NONE`, or not contained in `reelConfig.supportedBlockModes`, fall back to the **first non-NONE** entry of `supportedBlockModes`;
  3. if none qualifies, fall back to `PRESS_BACK`.

---

## 7. ONE_REEL Overlay Auto-Hide

In `ONE_REEL` plan, a system overlay (`OverlayType.ONE_REEL`) is shown to allow one reel, then auto-dismissed:

- After detection, `scheduleOneReelOverlayAutoHide()` cancels any running `oneReelOverlayHideJob` and launches a coroutine that waits `ONE_REEL_OVERLAY_GRACE_MS = 500`, polling at `ONE_REEL_OVERLAY_POLL_MS = 500`, then calls `hideOneReelOverlay(showToast=false)` to `removeView` from the `WindowManager`.
- **BACK-key dismiss (verified, `…:423-433`):** `onKeyEvent` intercepts `KEYCODE_BACK` (`keyCode == 4`) on key-up (`action == 1`); if `OverlayType.ONE_REEL` is active, it calls `hideOneReelOverlay(true)` and returns `false` (does not consume the event).
- Overlays are `WindowManager` `ComposeView`s; the renderer implements `LifecycleOwner`/`SavedStateRegistryOwner`/`ViewModelStoreOwner`.

> **Flutter:** ✅⚠️ `flutter_overlay_window` renders the overlay UI, but the auto-hide timer + BACK interception live in native (`onKeyEvent` only exists in the AccessibilityService). iOS: ❌.

---

## 8. `handleShortVideoDetection` → `processAndBlockShortContent` Gating Order (inferred)

`NoScrollServiceModel.processAndBlockShortContent()` is a bytecode dump (unreadable), so this order is **(inferred)** from the surrounding state model and callback signatures (`onPreBlock`, `onBlock`, `onNode`):

```
processAndBlockShortContent(pkg, reelConfig, onPreBlock, onBlock, onNode, cont):   # (inferred)
    1. read all StateFlows atomically: activeDetectionPlan, pauseData, curiousData,
       appRestrictionsHelper, premiumPlans, platformsConfig
    2. PAUSE gate:    if pauseData.phase in {PAUSED} or
                      (PAUSED_COOLDOWN and !allowInLockDown) -> block now
    3. CURIOUS gate:  if curiousData.phase == COOLDOWN and !isVideoAllowedInCooldown -> block
                      if SESSION -> allow (return)
    4. resolve active plan: PAUSED -> _planToResume, else activeDetectionPlan
       (cache result in LastPlanCheck{packageName,lastResult,lastPlanCheckTime})
    5. PREMIUM gate:  if reelConfig.premiumExclusive and !user.isPremium -> skip (return)
    6. APP-SESSION:   if appSessions[pkg] exists and pinExpiry passed -> restrict app instead
    7. QUOTA gate:    if dailyQuota exceeded for pkg -> block (focus mode)
    8. RESTRICTION:   look up PlatformRestrictionEnum (ONE_MIN/FIVE_MIN/TEN_MIN/ALWAYS/NEVER/
                      AS_PER_PLAN); honour calm-down cooldown vs lastBlockTime
    9. resolve BlockingModesEnum -> invoke onBlock callback -> blockShortContent$app(...)
   10. update lastVideoBlocked; record analytics
```

---

## 9. Native ↔ Flutter Boundary

| Capability | Verdict | Package / approach |
|---|---|---|
| AccessibilityService binding + event stream | ⚠️ | `flutter_accessibility_service` (EventChannel of events) |
| Node-tree DFS / `findAccessibilityNodeInfosByViewId` | ⚠️ | Must stay native Kotlin; emit a flattened `DetectedContent` payload to Dart |
| `performGlobalAction(BACK)` | ⚠️ | Native MethodChannel; ❌ iOS |
| Kill app (`ActivityManager`) | ⚠️ | Native; ❌ iOS |
| Lock screen (DeviceAdmin `lockNow`) | ⚠️ | Native + `device_policy_controller`-style admin; ❌ iOS |
| System overlay window | ⚠️/✅ | `flutter_overlay_window`; ❌ iOS |
| `onKeyEvent` BACK interception | ⚠️ | Only inside AccessibilityService; ❌ iOS |
| Foreground service + notification | ✅⚠️ | `flutter_foreground_task` |
| Haptics | ✅ | `vibration` |
| Config storage (DataStore) | ✅ | `shared_preferences` / `hive` |
| Remote config JSON | ✅ | `dio` + `freezed`/`json_serializable` |
| Analytics | ✅ | `firebase_analytics` |
| **Rule evaluation, plan/phase math, web URL parsing, calibration zone math, debounce/throttle bookkeeping** | ✅ | **Pure Dart** (this doc's `DetectionRuleEngine` + `BlockingBloc`) |

> **iOS reality (❌):** there is no AccessibilityService, no node-tree access, no global BACK, no app-kill, no system overlay over other apps. The closest Apple primitives are **FamilyControls / DeviceActivity / ManagedSettings / ManagedSettingsUI** (Screen Time), which can *shield* whole apps/categories on a schedule but cannot detect "this screen is a reel". An iOS build degrades to app-level shielding only.

The native side does the *unsafe, platform-bound* work (walk the tree, find the node, fire the action). It emits a clean payload; **all decision logic lives in Dart** so it is testable and shared.

### 9.1 EventChannel payload — `DetectedContent`

```dart
/// domain/entities/detected_content.dart
class DetectedContent {
  final String packageName;        // foreground app, e.g. com.instagram.android
  final String? viewIdResourceName;// matched id, e.g. com.instagram.android:id/clips_author_username
  final String? contentDescription;// for CONT_DESC detectors
  final String? url;               // for BROWSER detectors
  final Rect? boundsInScreen;      // for CALIBRATION zone matching
  final bool isFocusable;
  final bool isVisibleToUser;
  final String matchTag;           // "[FIND]" | "[DEEP]" | "" (debug provenance)
  final int eventTimeMs;
  const DetectedContent({ required this.packageName, this.viewIdResourceName,
    this.contentDescription, this.url, this.boundsInScreen,
    this.isFocusable = false, this.isVisibleToUser = false,
    this.matchTag = '', required this.eventTimeMs });
}
```

The native side is intentionally "dumb": it may either (a) emit *every* candidate node and let Dart match, or (b) match against ids it was handed and emit only hits. For battery, the original matches natively; the Flutter port should pass the active id-set down once (`MethodChannel('setActiveIdentifiers')`) and emit only hits.

---

## 10. Flutter Design

### 10.1 Domain entities

```dart
enum BlockMode { pressBack, killApp, lockScreen, none }          // ordinals mirror native 1..4
enum DetectorKind { findById, viewIdResName, contDesc, browser } // ViewDetectorsEnum
enum DetectionType { legacy, overlay, manual, calibration, none }
enum DetectionPlan { blockAll, curious, oneReel, paused }        // PlansEnum
enum WebMatchType { domain, exact, wildcard }

class DetectorRule {
  final DetectorKind kind;
  final List<String> identifiers;         // ":id/reel_player_underlay"
  final List<BlockMode> supportedBlockModes;
  final BlockMode defaultBlockMode;
  final int priority;                     // ascending = first
  final bool haltOnDetect;
  final List<String> coupleWith;
  final int childNodeLimit;               // -1 = unbounded
  const DetectorRule({ required this.kind, required this.identifiers,
    required this.supportedBlockModes, required this.defaultBlockMode,
    this.priority = 0, this.haltOnDetect = true,
    this.coupleWith = const [], this.childNodeLimit = -1 });
}

class PlatformConfig {
  final String platformId, platformName, packageName;
  final DetectionType detectionType;
  final bool premiumExclusive, browser, defaultStatus;
  final Map<DetectorKind, DetectorRule> detectors;
  const PlatformConfig({ required this.platformId, required this.platformName,
    required this.packageName, required this.detectionType,
    required this.detectors, this.premiumExclusive = false,
    this.browser = false, this.defaultStatus = true });
}

/// Result of a successful detection (mirrors DetectedReelConfig + node).
class DetectionResult {
  final PlatformConfig platform;
  final BlockMode resolvedMode;
  final String matchTag;
  const DetectionResult(this.platform, this.resolvedMode, this.matchTag);
}
```

### 10.2 `DetectionRuleEngine` (pure Dart — the testable core)

```dart
/// domain/services/detection_rule_engine.dart
class DetectionRuleEngine {
  final List<PlatformConfig> _config;        // from platforms_config.json
  DetectionRuleEngine(this._config);

  /// Evaluate one native event payload against the data-driven config.
  DetectionResult? evaluate(DetectedContent c, {required bool isPremium}) {
    final platform = _config.firstWhereOrNull((p) =>
        p.packageName == c.packageName && p.defaultStatus &&
        p.detectionType != DetectionType.none);
    if (platform == null) return null;
    if (platform.premiumExclusive && !isPremium) return null;

    // detectors in ascending priority
    final rules = platform.detectors.values.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    for (final r in rules) {
      final hit = _matches(r, c);
      if (hit) {
        final mode = _resolveMode(r, platform);
        if (r.haltOnDetect) return DetectionResult(platform, mode, c.matchTag);
        // haltOnDetect == false -> keep scanning, remember last
      }
    }
    return null;
  }

  bool _matches(DetectorRule r, DetectedContent c) {
    if (!c.isVisibleToUser) return false;
    switch (r.kind) {
      case DetectorKind.findById:
        final rid = c.viewIdResourceName;
        return rid != null && r.identifiers.any((id) =>
            rid == '${c.packageName}$id') && c.isFocusable;
      case DetectorKind.viewIdResName:
        final rid = c.viewIdResourceName;
        return rid != null && r.identifiers.contains(rid) && c.isFocusable;
      case DetectorKind.contDesc:
        final d = c.contentDescription;
        return d != null && r.identifiers.any(d.contains);
      case DetectorKind.browser:
        return c.url != null && _webMatches(c.url!);
    }
  }

  BlockMode _resolveMode(DetectorRule r, PlatformConfig p) {
    // mirrors handleShortVideoDetection fallback chain
    final m = r.defaultBlockMode;
    if (m != BlockMode.none && r.supportedBlockModes.contains(m)) return m;
    return r.supportedBlockModes.firstWhere((x) => x != BlockMode.none,
        orElse: () => BlockMode.pressBack);
  }

  bool _webMatches(String rawUrl) {
    final parts = WebUrl.parse(rawUrl);                  // §10.3
    // ...iterate web restrictions: domain/exact/wildcard + path scope
    return false; // illustrative
  }
}
```

### 10.3 Web URL parsing (verified semantics → Dart)

```dart
/// domain/services/web_url.dart  (mirrors LegacyDetector.parseWebUrlParts)
class WebUrl {
  static const _marks = {0xFEFF,0x200E,0x200F,0x202A,0x202B,0x202C,
                         0x2066,0x2067,0x2068,0x2069};
  final String hostRaw, hostCanonical, path;
  WebUrl(this.hostRaw, this.hostCanonical, this.path);

  static WebUrl parse(String input) {
    var s = input.trim();
    s = String.fromCharCodes(s.runes.skipWhile(_marks.contains)); // strip leading marks
    final m = RegExp(r'https?://[^\s<>"]+').firstMatch(s);
    if (!s.toLowerCase().startsWith('http') && m != null) s = m.group(0)!;
    s = s.toLowerCase();
    while (true) {                                   // strip scheme + //
      final t = s.replaceFirst(RegExp(r'^(https://|http://|//)'), '');
      if (t == s) break; s = t;
    }
    final slash = s.indexOf('/');
    final host = slash >= 0 ? s.substring(0, slash) : s;
    var path = slash >= 0 ? s.substring(slash) : '';
    final hostRaw = host.split(':').first.trim().replaceAll(RegExp(r'\.+$'), '');
    while (path.endsWith('/') && path.length > 1) path = path.substring(0, path.length-1);
    if (path == '/') path = '';
    var canon = hostRaw;
    while (true) {                                   // drop leading www./m.
      final dot = canon.indexOf('.');
      if (dot <= 0) break;
      final label = canon.substring(0, dot);
      if (label != 'www' && label != 'm') break;
      canon = canon.substring(dot + 1).replaceAll(RegExp(r'\.+$'), '');
    }
    return WebUrl(hostRaw, canon, path);
  }

  static bool matchesSubdomainWildcard(String pattern, String host) {
    final p = pattern.trim().toLowerCase();
    if (!p.startsWith('*.')) return false;
    final suffix = p.substring(2).trim();
    if (suffix.isEmpty) return false;
    final h = host.toLowerCase();
    return h == suffix || h.endsWith('.$suffix');
  }

  static bool pathInScope(String urlPath, String scope) =>
      scope.isEmpty || (urlPath.isNotEmpty &&
          (urlPath == scope || urlPath.startsWith('$scope/')));
}
```

### 10.4 `BlockingBloc`

```dart
// presentation/bloc/blocking_event.dart
sealed class BlockingEvent {}
class ContentDetected extends BlockingEvent { final DetectedContent c; ContentDetected(this.c); }
class PlanChanged    extends BlockingEvent { final DetectionPlan plan; PlanChanged(this.plan); }
class OverlayDismissed extends BlockingEvent {}

// presentation/bloc/blocking_state.dart
sealed class BlockingState {}
class BlockingIdle    extends BlockingState {}
class ContentBlocked  extends BlockingState { final BlockMode mode; final String platformId; ContentBlocked(this.mode, this.platformId); }
class OverlayShowing  extends BlockingState { final String platformId; OverlayShowing(this.platformId); }

// presentation/bloc/blocking_bloc.dart
class BlockingBloc extends Bloc<BlockingEvent, BlockingState> {
  final DetectionRuleEngine _engine;
  final ExecuteBlock _execute;          // usecase wrapping native MethodChannel
  final ResolvePlanPhase _phase;        // pause/curious phase math (pure Dart)

  // throttle/debounce bookkeeping (pure Dart, single-threaded event loop = no atomics needed)
  final _pkgLastSeen = <String, int>{};
  int _lastBlockMs = -1, _lastBackMs = -1, _hardBlockUntil = 0;
  DetectionPlan _plan = DetectionPlan.blockAll;

  BlockingBloc(this._engine, this._execute, this._phase) : super(BlockingIdle()) {
    on<PlanChanged>((e, emit) => _plan = e.plan);
    on<ContentDetected>(_onDetected);
  }

  Future<void> _onDetected(ContentDetected e, Emitter emit) async {
    final c = e.c; final now = c.eventTimeMs;
    // (1) per-package throttle 150ms
    final last = _pkgLastSeen[c.packageName];
    if (last != null && now - last < 150) return;
    _pkgLastSeen[c.packageName] = now;
    // (2) plan-phase gate
    if (!_phase.allowsDetection(_plan)) return;
    // (3) evaluate config
    final r = _engine.evaluate(c, isPremium: _phase.isPremium);
    if (r == null) return;
    // (4) debounce 1200ms
    if (now - _lastBlockMs <= 1200) return;
    _lastBlockMs = now;
    // (5) execute
    switch (r.resolvedMode) {
      case BlockMode.pressBack:
        if (_lastBackMs <= now - 1100) { _lastBackMs = now; await _execute.back(); }
        emit(ContentBlocked(BlockMode.pressBack, r.platform.platformId));
      case BlockMode.killApp:
        _hardBlockUntil = now + 15000; await _execute.killApp(c.packageName);
        emit(ContentBlocked(BlockMode.killApp, r.platform.platformId));
      case BlockMode.lockScreen:
        _hardBlockUntil = now + 30000; await _execute.lockScreen();
        emit(ContentBlocked(BlockMode.lockScreen, r.platform.platformId));
      case BlockMode.none: break;
    }
  }
}
```

### 10.5 Usecase + datasource layering (Clean Architecture)

| Layer | Class | Responsibility |
|---|---|---|
| presentation/bloc | `BlockingBloc` | Orchestrates throttle → gate → evaluate → debounce → execute. |
| domain/usecases | `ExecuteBlock` (`back()`/`killApp()`/`lockScreen()`), `ResolvePlanPhase`, `WatchDetectedContent` | Pure intent; no platform code. |
| domain/services | `DetectionRuleEngine`, `WebUrl` | Verified algorithms, fully unit-testable. |
| domain/entities | `DetectedContent`, `PlatformConfig`, `DetectorRule`, `DetectionResult` | Immutable models. |
| data/repositories | `BlockingRepositoryImpl` | Bridges Dart ↔ native channels + config store. |
| data/datasources | `AccessibilityChannel` (EventChannel ⚠️), `BlockActionChannel` (MethodChannel ⚠️), `PlatformConfigRemote` (`dio` ✅), `PlatformConfigLocal` (`hive` ✅) | I/O. |
| data/models | `PlatformConfigDto` (`freezed`/`json_serializable`) | Maps `platforms_config.json` ↔ entities. |

---

## 11. Full-Loop ASCII Diagram

```
                         ANDROID FRAMEWORK
                                │ AccessibilityEvent (typeAllMask)
                                ▼
        ┌──────────────────────────────────────────────────┐
        │  NATIVE  AccessibilityService (:as_process) ⚠️     │
        │  flagReportViewIds → getViewIdResourceName()       │
        │                                                    │
        │  per-pkg throttle 150ms ──skip──┐                  │
        │            │ pass               │                  │
        │            ▼                    │                  │
        │  3-stage view-id match (LegacyDetector)            │
        │   Stage1 event.source [exact]                      │
        │   Stage2 findById...ByViewId  [FIND]               │
        │   Stage3 DFS ArrayDeque cap 12000  [DEEP]          │
        │            │ hit                                   │
        │            ▼                                       │
        │  emit DetectedContent  ──EventChannel──┐           │
        └────────────────────────────────────────┼──────────┘
                                                  ▼
        ┌──────────────────────────────────────────────────┐
        │  DART  BlockingBloc (flutter_bloc) ✅              │
        │   1 per-pkg throttle 150ms                         │
        │   2 plan/phase gate (PAUSED/CURIOUS) ── allow ─┐   │
        │   3 DetectionRuleEngine.evaluate()             │   │
        │       • priority asc • haltOnDetect            │   │
        │       • coupleWith / childNodeLimit            │   │
        │       • premiumExclusive                       │   │
        │   4 debounce 1200ms ── skip ─┐                 │   │
        │   5 resolve BlockMode        │                 │   │
        └──────────────┬───────────────┴─────────────────┴──┘
                       │ ExecuteBlock usecase
        ┌──────────────▼───────────────────────────────────┐
        │  NATIVE BlockActionChannel (MethodChannel) ⚠️      │
        │   PRESS_BACK  → performGlobalAction(BACK)          │
        │       (rate-limit 1100ms + haptic VIDEO_BLOCKED)   │
        │   KILL_APP    → ActivityManager  (hardBlock +15s)  │
        │   LOCK_SCREEN → DeviceAdmin.lockNow (hardBlock+30s)│
        │   NONE        → no-op                              │
        │   ONE_REEL    → overlay + 500ms auto-hide,         │
        │                 onKeyEvent(BACK) dismiss           │
        └───────────────────────────────────────────────────┘
                       │
                       ▼  firebase "<platformId>_blocked" + Room/Hive log ✅
            (iOS path ❌: none of the native blocks exist →
             degrade to FamilyControls/ManagedSettings app shielding)
```

---

## Source evidence

- `service/accessibility/processors/detectors/LegacyDetector.java` — verified 3-stage `findViewByIdWithId` (lines 102-164, DFS cap `12000` at 135), `recycleDequeExcept` (258-265), `URL_IN_TEXT` regex (27), `parseWebUrlParts` directional-mark set + canonicalization (185-249), `matchesSubdomainWildcard` (166-183), `pathMatchesDomainScope` (251-256), `webDetection` return shape recovered from JADX comment (267-294).
- `service/accessibility/NoScrollAccessibilityService.java` — constants (105-116), `blockShortContent$app` debounce 1200 / back rate-limit 1100 / haptic (200-251), `handleShortVideoDetection$app` hard-block branch + mode fallback (291-324), `onKeyEvent` BACK overlay dismiss (423-433), FGS id `1125` / channel `noscroll_protection_channel` (543-562), command receiver `com.noscroll.action.APP_COMMAND` (461-467), status broadcast (367).
- `resources/res/raw/platforms_config.json` — detector shape (`identifiers`, `supportedBlockModes`, `defaultBlockMode`, `priority`, `haltOnDetect`, `coupleWith`, `childNodeLimit`), real ids `:id/reel_player_underlay`, `:id/progress`, detectionType `LEGACY`.
- `resources/res/xml/site_manager_service.xml` — `typeAllMask`, `notificationTimeout=100`, `flagReportViewIds | flagRequestFilterKeyEvents | flagRetrieveInteractiveWindows`.
- Cached analyses: `/tmp/ns_analysis/accessibility-core.json`, `/tmp/ns_analysis/detectors-and-processors-accessibility-d.json`, `/tmp/ns_analysis/calibration.json`, `/tmp/ns_analysis/service-state-and-session.json`, `/tmp/synth_flows.md`.
- **(inferred)** parts: `onAccessibilityEvent` loop ordering, `processAndBlockShortContent` gating order, CALIBRATION bounds-matching, CONT_DESC body — all bodies were obfuscated / "Method dump skipped".

## Related docs

- `01-architecture-overview.md`
- `02-accessibility-service.md`
- `04-blocking-modes-and-applocker.md`
- `05-calibration-and-config.md`
- `06-plans-pause-curious.md`
- `07-web-blocking.md`
- `08-overlays.md`
- `09-flutter-native-bridge.md`
