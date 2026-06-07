# Full-App Blocker & Web Blocklist

This document is a from-scratch Flutter re-build blueprint for the **two non-reel restriction subsystems** of the original short-form blocker: (A) **Full-App Blocking** — detecting that a fully-blocked app (e.g. a game or a social app you want gone entirely) has come to the foreground and forcing the user out of it, with per-app PIN-unlock sessions and a global pause/cooldown; and (B) **Web Blocklist** — reading the browser address-bar text via accessibility, canonicalizing the URL, matching it against a user-defined block list with three match modes (DOMAIN / EXACT / WILDCARD), and enforcing the same block actions. The detection engine for reels themselves is covered in the sibling detector docs; here we reuse that engine's node-tree plumbing but drive it from a different data set. Both features ultimately depend on the same Android **AccessibilityService** native boundary — the matching/canonicalization/state logic is pure Dart, but the interception (reading nodes, pressing back, killing apps, locking the screen, showing overlays) is `⚠️` native via MethodChannel/EventChannel.

> **Legend** — `✅` a pub.dev package handles it • `⚠️` needs a native MethodChannel/EventChannel (Kotlin) • `❌` not possible on iOS.

---

## 1. Scope, evidence & enum facts

| Subsystem | Original anchor file(s) | Drives |
|---|---|---|
| Full-app blocker | `service/AppMonitorService.java`, `service/accessibility/processors/applocker/AppLockerProcessor.java`, `data/database/data/DailyAppBlocker.java`, `service/accessibility/data/AppSessionDetails.java`, `service/accessibility/data/PauseSessionData.java` | foreground-app detection, throttle, CLOSE_APP/LOCK_SCREEN/OVERLAY, per-app PIN sessions, global pause/cooldown |
| Web blocklist | `service/accessibility/processors/detectors/LegacyDetector.java`, `.../dashboard/data/WebMatchTypeEnum.java`, `WebBlockingModesEnum.java`, `WebRestrictionsStatus.java`, `assets/PublicSuffixDatabase.list` | address-bar capture, URL canonicalization, DOMAIN/EXACT/WILDCARD matching, per-URL pause |

### 1.1 Verified enums (copy the *semantics*, not the names)

**`AppLockActionEnum`** — what happens when a blocked app is opened (VERIFIED `common/ui/AppLockActionEnum.java`):

| Ordinal | Original | `title` | `premiumExclusive` | `passageMillis` | Meaning |
|---|---|---|---|---|---|
| 0 | `NONE` | "NONE" | false | 0 | no action |
| 1 | `OVERLAY` | "Overlay" | false | 0 | show blocking overlay UI |
| 2 | `CLOSE_APP` | "Close App" | **true** | **15000** | press-back / send to home |
| 3 | `LOCK_SCREEN` | "Lock Screen" | **true** | **30000** | lock the device |

> `passageMillis` is the *grace window* the action grants after firing (15 s for close, 30 s for lock) before the app may be acted on again — a per-action cooldown so the user isn't fought continuously.

**`WebMatchTypeEnum`** (VERIFIED, exact labels/descriptions from `WebMatchTypeEnum.java`):

| Ordinal | Original | `label` | `description` (verbatim) |
|---|---|---|---|
| 0 | `DOMAIN` | "Domain" | "Blocks the entire website and all of its subpages (e.g., blocking 'youtube.com' also blocks 'youtube.com/feed/trending')." |
| 1 | `EXACT` | "Exact URL" | "Blocks only this specific page. Other pages on the same website remain accessible." |
| 2 | `WILDCARD` | "Starting URL" | "Blocks any URL that begins with this specific path (e.g., blocking 'youtube.com/shorts/' blocks all Shorts but allows the homepage)." |

**`WebBlockingModesEnum`** (VERIFIED ordinals `WebBlockingModesEnum.java`): `PRESS_BACK(0)`, `KILL_APP(1)`, `LOCK_SCREEN(2)`, `OVERLAY(3)`, `NONE(4)`.

### 1.2 Verified constants

| Constant | Value | Source | Use |
|---|---|---|---|
| App-locker re-attempt throttle | **2000 ms** | `AppLockerProcessor.restrictApp` (`j - lastTs <= 2000 → return`) | min gap between two block actions on the same/any app |
| App-locker attempts buffer | **4 entries** | `AppLockerProcessor` `ArrayDeque` (`size==4 → removeFirst`, `addLast`) | rolling history of recent block attempts |
| Block debounce (web/reel) | **1200 ms** | `NoScrollAccessibilityService.blockShortContent` | skip if `now - lastBlockTime <= 1200` |
| Per-package event throttle | **150 ms** | `THROTTLE_INTERVAL_MS` | min gap between processing events for one package |
| Daily app-blocker limit | **9 000 000 ms** (2.5 h) | `DailyAppBlocker.dailyLimitDuration` | quota of allowed time before hard-block |
| Default pause duration | **60 000 ms** (1 min) | `PauseSessionData.pauseDuration` | default global pause |
| Default post-pause lockdown | **10 000 ms** | `PauseSessionData.lockDownDuration` | cooldown after a pause ends |
| Max pause | **15 min** | `PauseSessionData.maxPauseMinutes` | UI slider ceiling |
| App-monitor FGS notification id | **2** | `AppMonitorService` | foreground notification |
| Free tier — app block count | **5 apps** | UI gate (`onRestrictionSwitched`) | premium upsell beyond 5 |
| Free tier — web block count | **3 sites**, WILDCARD premium-only | UI gate (`onShowPremiumPrompt`) | premium upsell |

**Source evidence:** `service/AppMonitorService.java`; `service/accessibility/processors/applocker/AppLockerProcessor.java` (throttle/deque VERIFIED); `service/accessibility/processors/detectors/LegacyDetector.java` (`parseWebUrlParts`, `matchesSubdomainWildcard`, `pathMatchesDomainScope` VERIFIED); `service/accessibility/data/AppSessionDetails.java`, `PauseSessionData.java`; `data/database/data/DailyAppBlocker.java`; `.../dashboard/data/{WebMatchTypeEnum,WebBlockingModesEnum,WebRestrictionsStatus,AppLockActionEnum}.java`; `resources/assets/PublicSuffixDatabase.list`.

---

## 2. Feature A — Full-App Blocking

### 2.1 Detection: usage_stats vs accessibility

The original ran **two cooperating services**:

- **`AppMonitorService`** — a foreground service (notification id 2, channel `app_monitoring_service`) that observes DataStore flows (PIN config, per-app sessions, platform restrictions, daily quota), registers a `ScreenStateReceiver` to *pause monitoring when the screen is off*, and launches `PinBlockOverlayActivity` to demand a PIN.
- **`NoScrollAccessibilityService`** — receives window-transition events, extracts the foreground package, and calls `AppLockerProcessor.restrictApp(...)`.

The accessibility path is the real-time one. Usage-stats is a *fallback / secondary* signal (the `PACKAGE_USAGE_STATS` permission is declared, used for the daily-quota accounting, not for live interception).

| Mechanism | Real-time? | Flutter mapping |
|---|---|---|
| **AccessibilityService** window-transition → foreground package | yes (best) | `⚠️` `flutter_accessibility_service` + native event stream. **iOS:** `❌` (use FamilyControls/DeviceActivity — see §5) |
| **UsageStatsManager** `queryEvents` polling | near-real-time (1–2 s lag) | `✅` `usage_stats` (Android only) for quota accounting; `⚠️` for live block |
| Installed-app inventory (names/icons for the UI list) | n/a | `✅` `installed_apps` or `device_apps` |
| Screen on/off gating | n/a | `✅` `screen_state` |

**Recommendation:** drive live interception from the accessibility EventChannel (same channel the reel detector uses); use `usage_stats` only to maintain `consumedDuration` against the 2.5 h daily quota and `installed_apps` to build the picker UI.

### 2.2 `AppLockerProcessor` — the throttle + action dispatch (VERIFIED)

The original logic is small and exact:

```java
// AppLockerProcessor.restrictApp(AppLockActionEnum action, String pkg, long now)  — VERIFIED
Pair last = attemptsDeque.lastOrNull();
if (now - (last != null ? last.second : 0L) <= 2000) return;   // 2 s throttle
if (attemptsDeque.size == 4) attemptsDeque.removeFirst();      // bounded history (4)
attemptsDeque.addLast(new Pair(pkg, now));
pressBackAndThenRestrictApp.invoke(action);                     // fire the action
```

So: **at most one block action per 2 seconds**, and the last 4 `(package, timestamp)` attempts are retained (older ones discarded). The action itself is "press back, *then* apply the restriction" — back first to dismiss whatever is on screen, then CLOSE_APP / LOCK_SCREEN / OVERLAY.

Dart re-implementation (pure logic; the `_fire` callback crosses the native boundary):

```dart
/// Bounded, throttled dispatcher for full-app block actions.
/// Mirrors AppLockerProcessor: 2000ms throttle + 4-entry rolling history.
class AppLockerThrottle {
  static const Duration _throttle = Duration(milliseconds: 2000);
  static const int _maxAttempts = 4;
  final _attempts = <_BlockAttempt>[]; // acts as a deque

  /// Returns true if an action was fired (i.e. not throttled).
  bool restrict(AppLockAction action, String packageName, DateTime now) {
    final last = _attempts.isEmpty ? null : _attempts.last;
    if (last != null && now.difference(last.at) <= _throttle) return false;
    if (_attempts.length == _maxAttempts) _attempts.removeAt(0); // removeFirst
    _attempts.add(_BlockAttempt(packageName, now));              // addLast
    _fire(action, packageName);
    return true;
  }

  late final void Function(AppLockAction, String) _fire; // → native channel
}

class _BlockAttempt {
  final String packageName;
  final DateTime at;
  const _BlockAttempt(this.packageName, this.at);
}
```

The native side (`⚠️`) is what `_fire` calls. Mapping of each action:

| `AppLockAction` | Native call | Flutter package / channel |
|---|---|---|
| `closeApp` | `performGlobalAction(GLOBAL_ACTION_BACK)` → then `GLOBAL_ACTION_HOME` if still foreground | `⚠️` accessibility channel |
| `lockScreen` | `DevicePolicyManager.lockNow()` (needs DeviceAdmin) | `⚠️` device-admin channel. **iOS:** `❌` |
| `overlay` | `WindowManager` `TYPE_APPLICATION_OVERLAY` PIN screen | `⚠️` `flutter_overlay_window` |
| `none` | no-op | — |

### 2.3 Per-app PIN unlock sessions (`AppSessionDetails`, VERIFIED fields)

`AppSessionDetails` (VERIFIED `service/accessibility/data/AppSessionDetails.java`): `packageName:String`, `pinUnlockedOn:long`, `pinExpiry:long`, `unlockedBlockActionMode:AppLockActionEnum`.

Flow: user opens a PIN-locked app → blocked → enters PIN in the overlay → on success we write `AppSessionDetails(pkg, now, now + unlockDuration, action)`. On every subsequent event the accessibility service checks the session map: if `pinExpiry > now`, **allow**; else re-lock. `unlockedBlockActionMode` records which action applies once the session expires.

```dart
class AppUnlockSession {
  final String packageName;
  final DateTime unlockedOn;
  final DateTime expiry;
  final AppLockAction actionAfterExpiry; // unlockedBlockActionMode
  const AppUnlockSession({
    required this.packageName,
    required this.unlockedOn,
    required this.expiry,
    required this.actionAfterExpiry,
  });

  bool isActiveAt(DateTime now) => now.isBefore(expiry);
}
```

### 2.4 Global pause / cooldown (`DailyAppBlocker` + `PauseSessionData`)

Two layers gate *all* full-app blocking:

1. **Pause** — user temporarily disables blocking (`DailyAppBlocker.isPaused && now <= pauseExpiry`). After the pause window, a **cooldown / lockdown** begins (`now <= cooldownExpiry`) during which the user *sees* blocks again but cannot pause again (anti-abuse).
2. **Daily quota** — `consumedDuration` accumulates allowed-app time; when `>= dailyLimitDuration` (9 000 000 ms) all blocked apps are hard-blocked until the next calendar day. `DailyAppBlocker.refreshSignature(now)` compares a `dd-MM-yyyy` date signature and resets counters at the day boundary.

```dart
enum BlockerPhase { active, paused, cooldown }

class DailyAppBlockerState {
  final String dateSignature;        // "dd-MM-yyyy"
  final int dailyLimitMs;            // 9_000_000
  final int consumedMs;
  final bool isPaused;
  final DateTime? pauseExpiry;
  final DateTime? cooldownExpiry;

  const DailyAppBlockerState({
    required this.dateSignature,
    this.dailyLimitMs = 9000000,
    this.consumedMs = 0,
    this.isPaused = false,
    this.pauseExpiry,
    this.cooldownExpiry,
  });

  BlockerPhase phaseAt(DateTime now) {
    if (isPaused && pauseExpiry != null && now.isBefore(pauseExpiry!)) {
      return BlockerPhase.paused;
    }
    if (cooldownExpiry != null && now.isBefore(cooldownExpiry!)) {
      return BlockerPhase.cooldown;
    }
    return BlockerPhase.active;
  }

  bool get quotaExhausted => consumedMs >= dailyLimitMs;

  /// Mirrors refreshSignature: reset counters when the day changes.
  DailyAppBlockerState refreshFor(DateTime now, String Function(DateTime) fmt) {
    final sig = fmt(now); // intl DateFormat('dd-MM-yyyy')
    if (sig == dateSignature) return this;
    return DailyAppBlockerState(dateSignature: sig); // new day → counters cleared
  }
}
```

### 2.5 `BlockedApp` model

```dart
class BlockedApp {
  final String packageName;
  final String appLabel;          // from installed_apps
  final AppLockAction action;     // NONE / overlay / closeApp / lockScreen
  final bool pinLocked;           // isPinLocked
  final bool inAppYouTubeBlocked; // PlatformRestrictionStatus.inAppYouTubeBlocked

  const BlockedApp({
    required this.packageName,
    required this.appLabel,
    this.action = AppLockAction.none,
    this.pinLocked = false,
    this.inAppYouTubeBlocked = false,
  });

  bool get isBlocked => action != AppLockAction.none;
}

enum AppLockAction {
  none(premium: false, passageMs: 0),
  overlay(premium: false, passageMs: 0),
  closeApp(premium: true, passageMs: 15000),
  lockScreen(premium: true, passageMs: 30000);

  const AppLockAction({required this.premium, required this.passageMs});
  final bool premium;
  final int passageMs;
}
```

### 2.6 Decision flow (per foreground-app event)

```
event → foreground package
  ├─ phase == paused?  → allow (skip)
  ├─ phase == active && quotaExhausted? → force block regardless of per-app action
  ├─ app not in blocked set? → allow
  ├─ active PIN session (expiry > now)? → allow
  └─ else → AppLockerThrottle.restrict(app.action, pkg, now)   // 2s throttle
```

---

## 3. Feature B — Web Blocklist

### 3.1 Address-bar capture (`⚠️` native, ids INFERRED)

The original locates the browser address bar via the same node-tree machinery as the reel detector (`findViewByIdWithId`, DFS, 12000-node cap, VERIFIED). It tries resource-ids per browser. **The exact browser url-bar resource-ids are device/browser/version specific and were NOT enumerated as fixed constants in the decompiled source — treat this id set as INFERRED:**

| Browser (INFERRED) | Likely address-bar id | Strategy |
|---|---|---|
| Chrome | `com.android.chrome:id/url_bar` | FINDBYID |
| Chrome (alt) | `:id/location_bar` text | CONT_DESC / VIEWID_RES_NAME |
| Firefox | `org.mozilla.firefox:id/mozac_browser_toolbar_url_view` | FINDBYID |
| Samsung Internet | `com.sec.android.app.sbrowser:id/location_bar_edit_text` | FINDBYID |
| Edge | `com.microsoft.emmx:id/url_bar` | FINDBYID |

> The original `ViewDetectorsEnum` strategies (`FINDBYID | VIEWID_RES_NAME | CONT_DESC | BROWSER`) are how it widens the net across browsers; `BROWSER` is the dedicated web path. The address-bar **text** is read from the matched `EditText` node. In Flutter this is `⚠️` native — the Kotlin accessibility service reads the node text and pushes the raw URL string up an EventChannel.

| Step | Flutter mapping |
|---|---|
| Find address-bar node + read text | `⚠️` native accessibility (Kotlin), pushed via EventChannel. **iOS:** `❌` |
| Canonicalize URL | `✅` pure Dart (`Uri` + `public_suffix`) |
| Match against block list | `✅` pure Dart |
| Enforce block | `⚠️` native (press-back / kill / lock / overlay) |

### 3.2 `parseWebUrlParts` — canonicalization (VERIFIED, port faithfully)

VERIFIED steps from `LegacyDetector.parseWebUrlParts`:

1. **Strip leading Unicode directional/zero-width marks** — exact char set `{65279, 8206, 8207, 8234, 8235, 8236, 8294, 8295, 8296, 8297}` (BOM, LRM, RLM, LRE, RLE, PDF, LRI, RLI, FSI, PDI). Skip them from the front.
2. If the text has no `http://`/`https://` prefix, extract the first URL-looking substring via a regex (`URL_IN_TEXT`, approx `https?://[^\s<>"]+` per the reel-detector notes).
3. Lowercase. Iteratively strip `https://`, `http://`, `//` prefixes until stable.
4. Split on the **first** `/` → `domainPart` + `pathPart` (path is `""` if no slash).
5. `hostRaw` = `domainPart` with everything after the first `:` dropped, trimmed, trailing `.` removed.
6. Trim trailing `/` from the path (but keep a lone `/` → normalize to `""`).
7. **Canonical host**: if `hostRaw` starts with `*.`, keep it as-is; otherwise iteratively drop a leading label while it equals `www` or `m`, trimming trailing dots — yielding `hostCanonical`.
8. Return `WebUrlParts(hostRaw, hostCanonical, path)`.

```dart
class WebUrlParts {
  final String hostRaw;        // e.g. "www.youtube.com"
  final String hostCanonical;  // e.g. "youtube.com"  (www./m. stripped)
  final String path;           // e.g. "/shorts/abc"  ("" if none)
  const WebUrlParts(this.hostRaw, this.hostCanonical, this.path);
}

const _directionalMarks = {
  0xFEFF, 0x200E, 0x200F, 0x202A, 0x202B,
  0x202C, 0x2066, 0x2067, 0x2068, 0x2069,
};
final _urlInText = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);

WebUrlParts parseWebUrlParts(String input) {
  var s = input.trim();
  // 1. strip leading directional / zero-width marks
  var start = 0;
  while (start < s.length && _directionalMarks.contains(s.codeUnitAt(start))) {
    start++;
  }
  s = s.substring(start);

  // 2. if no scheme, pull the first URL-looking substring
  final lower0 = s.toLowerCase();
  if (!lower0.startsWith('http://') && !lower0.startsWith('https://')) {
    final m = _urlInText.firstMatch(s);
    if (m != null) s = m.group(0)!;
  }

  // 3. lowercase + strip scheme/// prefixes until stable
  var t = s.toLowerCase();
  while (true) {
    final stripped = t
        .replaceFirst(RegExp(r'^https://'), '')
        .replaceFirst(RegExp(r'^http://'), '')
        .replaceFirst(RegExp(r'^//'), '');
    if (stripped == t) break;
    t = stripped;
  }

  // 4. split domain / path on first '/'
  final slash = t.indexOf('/');
  final domainPart = slash >= 0 ? t.substring(0, slash) : t;
  var pathPart = slash >= 0 ? t.substring(slash) : '';

  // 5. hostRaw: drop port, trim, trailing dots
  var hostRaw = domainPart.split(':').first.trim();
  hostRaw = hostRaw.replaceFirst(RegExp(r'\.+$'), '');

  // 6. normalize trailing slashes in path
  while (pathPart.endsWith('/') && pathPart.length > 1) {
    pathPart = pathPart.substring(0, pathPart.length - 1);
  }
  if (pathPart == '/') pathPart = '';

  // 7. canonical host: strip leading www./m. labels (unless wildcard *.)
  String hostCanonical;
  if (hostRaw.startsWith('*.')) {
    hostCanonical = hostRaw;
  } else {
    var h = hostRaw.replaceFirst(RegExp(r'\.+$'), '');
    while (true) {
      final dot = h.indexOf('.');
      if (dot <= 0) break;
      final label = h.substring(0, dot);
      if (label != 'www' && label != 'm') break;
      h = h.substring(dot + 1).replaceFirst(RegExp(r'\.+$'), '');
    }
    hostCanonical = h;
  }

  return WebUrlParts(hostRaw, hostCanonical, pathPart);
}
```

### 3.3 `matchesSubdomainWildcard` & `pathMatchesDomainScope` (VERIFIED)

```dart
/// VERIFIED LegacyDetector.matchesSubdomainWildcard:
/// pattern must start with "*." ; matches base exactly OR ".base" suffix.
/// "*.instagram.com" matches "instagram.com" and "api.instagram.com",
/// but NOT "fakeinstagram.com".
bool matchesSubdomainWildcard(String pattern, String target) {
  final p = pattern.trim().toLowerCase();
  if (!p.startsWith('*.')) return false;
  final base = p.substring(2).trim();
  if (base.isEmpty) return false;
  final t = target.toLowerCase();
  return t == base || t.endsWith('.$base');
}

/// VERIFIED LegacyDetector.pathMatchesDomainScope:
/// empty scope → whole domain matches; else equals OR startsWith(scope + "/").
bool pathMatchesDomainScope(String fullPath, String scopePath) {
  if (scopePath.isEmpty) return true;
  if (fullPath.isEmpty) return false;
  return fullPath == scopePath || fullPath.startsWith('$scopePath/');
}
```

### 3.4 The full match algorithm (port of `webDetection`)

For each enabled entry (skip if `pauseExpiry > now`), parse both the *captured* URL and the *entry pattern* with `parseWebUrlParts`, then branch on match type:

```dart
bool urlMatchesEntry(WebUrlParts captured, WebBlocklistEntry entry, DateTime now) {
  if (!entry.enabled) return false;
  if (entry.pauseExpiry != null && now.isBefore(entry.pauseExpiry!)) return false;

  final pat = parseWebUrlParts(entry.url);
  switch (entry.matchType) {
    case WebMatchType.domain:
      // entire site (and subdomains via wildcard rule)
      if (captured.hostCanonical == pat.hostCanonical) return true;
      if (pat.hostRaw.startsWith('*.')) {
        return matchesSubdomainWildcard(pat.hostRaw, captured.hostCanonical) ||
               matchesSubdomainWildcard(pat.hostRaw, captured.hostRaw);
      }
      // host equal + path within scope (scope empty → whole domain)
      return captured.hostCanonical == pat.hostCanonical &&
             pathMatchesDomainScope(captured.path, pat.path);

    case WebMatchType.exact:
      // same host AND same path
      return captured.hostCanonical == pat.hostCanonical &&
             captured.path == pat.path;

    case WebMatchType.wildcard: // "Starting URL" — prefix match on host+path
      return captured.hostCanonical == pat.hostCanonical &&
             pathMatchesDomainScope(captured.path, pat.path);
  }
}
```

> The web-detection method body in the original is partially obfuscated; the per-entry skip-if-disabled / skip-if-paused gating and "return on first match" loop are **VERIFIED** from the analysis, while the precise per-match-type combination of host+path is reconstructed from `parseWebUrlParts` + the two helpers above **(inferred)** — it is consistent with the enum descriptions (DOMAIN = whole site, EXACT = exact page, WILDCARD = startsWith).

### 3.5 `PublicSuffixDatabase` usage

The original bundles `assets/PublicSuffixDatabase.list` (OkHttp's public-suffix list, ~10k rules) so that wildcard/registered-domain logic respects multi-label TLDs (`*.co.uk`, `*.github.io`). For Flutter:

| Need | Package | Notes |
|---|---|---|
| Registered-domain / eTLD+1 extraction, public-suffix-aware matching | `✅` `public_suffix` (pub.dev) | ship the bundled list as an asset and feed it to `PublicSuffixList.process` |
| Generic URL parsing | `✅` `Uri` (dart:core) | host/path split (we hand-roll to mirror the verified algorithm) |

Use `public_suffix` only where you need to know the *registrable* domain (e.g. to prevent `*.youtube.com` from over-matching). The verified canonicalization above already handles `www.`/`m.` and trailing-dot normalization without it.

### 3.6 `WebBlocklistEntry` model

```dart
class WebBlocklistEntry {
  final String url;             // canonical key in the map
  final WebMatchType matchType; // domain / exact / wildcard
  final bool enabled;           // isEnabled
  final WebBlockingMode mode;   // pressBack / killApp / lockScreen / overlay / none
  final DateTime? pauseExpiry;  // temporary unblock; null = never paused

  const WebBlocklistEntry({
    required this.url,
    this.matchType = WebMatchType.domain,
    this.enabled = true,
    this.mode = WebBlockingMode.pressBack,
    this.pauseExpiry,
  });

  bool isPausedAt(DateTime now) =>
      pauseExpiry != null && now.isBefore(pauseExpiry!);

  WebBlocklistEntry copyWith({bool? enabled, DateTime? pauseExpiry}) =>
      WebBlocklistEntry(
        url: url,
        matchType: matchType,
        enabled: enabled ?? this.enabled,
        mode: mode,
        pauseExpiry: pauseExpiry ?? this.pauseExpiry,
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'webMatchType': matchType.name,
        'isEnabled': enabled,
        'blockingMethod': mode.name,
        'pauseExpiry': pauseExpiry?.millisecondsSinceEpoch ?? 0,
      };

  factory WebBlocklistEntry.fromJson(Map<String, dynamic> j) => WebBlocklistEntry(
        url: j['url'] as String,
        matchType: WebMatchType.values.byName(j['webMatchType'] as String),
        enabled: j['isEnabled'] as bool? ?? true,
        mode: WebBlockingMode.values.byName(j['blockingMethod'] as String),
        pauseExpiry: (j['pauseExpiry'] as int? ?? 0) > 0
            ? DateTime.fromMillisecondsSinceEpoch(j['pauseExpiry'] as int)
            : null,
      );
}

enum WebMatchType { domain, exact, wildcard }
enum WebBlockingMode { pressBack, killApp, lockScreen, overlay, none }
```

> JSON keys mirror the original DataStore serialization (`WEB_BLOCK_LIST` key holds a `LinkedHashMap<String, WebRestrictionsStatus>`; fields `url`, `webMatchType`, `isEnabled`, `blockingMethod`, `pauseExpiry` are VERIFIED). Honor the legacy `BLOCKED_SITES` → `WEB_BLOCK_LIST` migration if importing old data.

### 3.7 Quick options (VERIFIED hardcoded set)

Seed the UI with one-tap presets (verbatim from `WebBlockListComposablesKt`):

| Title | URL | Match type |
|---|---|---|
| YouTube Shorts | `youtube.com/shorts/` | WILDCARD |
| Instagram Reels | `instagram.com/reels/` | WILDCARD |
| Facebook Reels | `facebook.com/reel/`, `facebook.com/reels/` | WILDCARD |
| Facebook Watch | `facebook.com/watch/` | WILDCARD |
| TikTok | `tiktok.com` | DOMAIN |

---

## 4. Clean-Architecture layout & BLoCs

```
lib/features/restrictions/
├─ domain/
│  ├─ entities/        blocked_app.dart, app_unlock_session.dart,
│  │                   daily_app_blocker_state.dart, web_blocklist_entry.dart,
│  │                   web_url_parts.dart
│  ├─ repositories/    restriction_repository.dart (abstract)
│  └─ usecases/        toggle_app_block.dart, set_app_pin_unlock.dart,
│                      pause_app_blocker.dart, toggle_web_block.dart,
│                      add_web_block.dart, pause_web_url.dart,
│                      match_url.dart (wraps urlMatchesEntry)
├─ data/
│  ├─ models/          blocked_app_model.dart, web_blocklist_entry_model.dart
│  ├─ datasources/     accessibility_channel.dart (⚠️ EventChannel),
│  │                   restriction_local_ds.dart (hive/secure_storage),
│  │                   installed_apps_ds.dart (installed_apps),
│  │                   usage_stats_ds.dart (usage_stats)
│  └─ repositories/    restriction_repository_impl.dart
└─ presentation/
   ├─ bloc/ app_blocker_bloc.dart, web_blocker_bloc.dart
   └─ pages/ app_block_list_page.dart, web_block_list_page.dart, pause_page.dart
```

### 4.1 `WebBlockerBloc`

```dart
// ---- events ----
sealed class WebBlockerEvent {}
class WebBlockerStarted extends WebBlockerEvent {}
class WebBlockAdded extends WebBlockerEvent {
  final WebBlocklistEntry entry; WebBlockAdded(this.entry);
}
class WebBlockToggled extends WebBlockerEvent {
  final String url; final bool enabled; WebBlockToggled(this.url, this.enabled);
}
class WebBlockRemoved extends WebBlockerEvent {
  final String url; WebBlockRemoved(this.url);
}
class WebUrlPaused extends WebBlockerEvent {
  final String url; final Duration duration; WebUrlPaused(this.url, this.duration);
}

// ---- state ----
class WebBlockerState {
  final List<WebBlocklistEntry> entries;
  final bool isPremium;
  final bool inputWildcardLockedForFree; // free tier: WILDCARD premium-only
  const WebBlockerState({
    this.entries = const [],
    this.isPremium = false,
    this.inputWildcardLockedForFree = true,
  });
  static const int freeLimit = 3; // verified free cap
  bool get atFreeLimit => !isPremium && entries.length >= freeLimit;
}

// ---- bloc ----
class WebBlockerBloc extends Bloc<WebBlockerEvent, WebBlockerState> {
  final RestrictionRepository repo;
  WebBlockerBloc(this.repo) : super(const WebBlockerState()) {
    on<WebBlockerStarted>((e, emit) async {
      await emit.forEach(repo.watchWebBlocklist(),
          onData: (list) => state._copy(entries: list));
    });
    on<WebBlockAdded>((e, emit) async {
      if (state.atFreeLimit) return; // UI shows premium prompt
      if (!state.isPremium && e.entry.matchType == WebMatchType.wildcard) return;
      await repo.upsertWebBlock(e.entry);
    });
    on<WebBlockToggled>((e, emit) =>
        repo.setWebBlockEnabled(e.url, e.enabled));
    on<WebBlockRemoved>((e, emit) => repo.removeWebBlock(e.url));
    on<WebUrlPaused>((e, emit) =>
        repo.pauseWebUrl(e.url, DateTime.now().add(e.duration)));
  }
}
```

### 4.2 `AppBlockerBloc` (sketch)

```dart
sealed class AppBlockerEvent {}
class AppBlockerStarted extends AppBlockerEvent {}
class AppBlockToggled extends AppBlockerEvent {
  final String pkg; final AppLockAction action; AppBlockToggled(this.pkg, this.action);
}
class AppBlockerPaused extends AppBlockerEvent {
  final Duration pause; final Duration cooldown;
  AppBlockerPaused(this.pause, this.cooldown);
}
class AppPinUnlocked extends AppBlockerEvent {
  final String pkg; final Duration grant; AppPinUnlocked(this.pkg, this.grant);
}

class AppBlockerState {
  final List<BlockedApp> apps;
  final DailyAppBlockerState daily;
  final bool isPremium;
  const AppBlockerState({this.apps = const [], required this.daily, this.isPremium = false});
  static const int freeLimit = 5; // verified free cap
  int get blockedCount => apps.where((a) => a.isBlocked).length;
  bool get atFreeLimit => !isPremium && blockedCount >= freeLimit;
}

class AppBlockerBloc extends Bloc<AppBlockerEvent, AppBlockerState> {
  final RestrictionRepository repo;
  AppBlockerBloc(this.repo)
      : super(AppBlockerState(daily: DailyAppBlockerState(dateSignature: ''))) {
    on<AppBlockToggled>((e, emit) async {
      final action = e.action;
      if (action.premium && !state.isPremium) return;      // CLOSE_APP/LOCK_SCREEN gated
      if (action != AppLockAction.none && state.atFreeLimit) return;
      await repo.setAppBlock(e.pkg, action);
    });
    on<AppBlockerPaused>((e, emit) => repo.pauseAppBlocker(e.pause, e.cooldown));
    on<AppPinUnlocked>((e, emit) => repo.grantAppUnlock(
        e.pkg, DateTime.now(), DateTime.now().add(e.grant)));
  }
}
```

### 4.3 A representative use case

```dart
class MatchUrl {
  /// Returns the first matching enabled, non-paused entry, or null.
  WebBlocklistEntry? call(
      String rawCapturedUrl, List<WebBlocklistEntry> entries, DateTime now) {
    final captured = parseWebUrlParts(rawCapturedUrl);
    for (final e in entries) {
      if (urlMatchesEntry(captured, e, now)) return e;
    }
    return null;
  }
}
```

---

## 5. iOS reality

Neither feature is achievable the way Android does it. iOS has **no AccessibilityService**, no foreground-app enumeration, and no way to read another app's browser address bar.

| Android capability | iOS closest |
|---|---|
| Block a specific app (CLOSE_APP) | `✅`-ish `FamilyControls` / `ManagedSettings` `shield` an app token (parental-control entitlement, user must approve in Screen Time). No back-press; iOS shows the system shield. `⚠️` native Swift + special entitlement |
| Lock the device (LOCK_SCREEN) | `❌` not available to third-party apps |
| Per-app PIN unlock | Partially via `DeviceActivity` schedules / Screen Time passcode (system-owned), not arbitrary per-app PIN windows |
| Block a website | `✅`-ish `ManagedSettings` web-content filter (`WebContentSettings`) for whole domains via Screen Time; no per-path WILDCARD, no live address-bar reading |
| Daily quota | `✅`-ish `DeviceActivity` time-limit schedules |

**Summary:** on iOS, re-implement as a Screen Time / FamilyControls overlay (domain-level web filtering + app shields), accept that EXACT/WILDCARD path matching and device-lock are `❌`, and gate the whole module behind the FamilyControls entitlement.

---

## 6. Package cheat-sheet

| Concern | Package(s) | Legend |
|---|---|---|
| Live foreground-app + address-bar capture | accessibility EventChannel (Kotlin) + `flutter_accessibility_service` | `⚠️` |
| Usage accounting / daily quota | `usage_stats` (Android) | `✅` Android-only |
| Installed-app list for picker | `installed_apps` / `device_apps` | `✅` |
| Press back / home / kill | accessibility `performGlobalAction` | `⚠️` |
| Lock screen | `DevicePolicyManager.lockNow` (DeviceAdmin) | `⚠️`, iOS `❌` |
| Block overlay / PIN screen | `flutter_overlay_window` | `⚠️` |
| URL parse | `Uri` (dart:core) + `public_suffix` | `✅` |
| Persistence | `hive` / `flutter_secure_storage` | `✅` |
| Screen on/off gating | `screen_state` | `✅` |
| Haptics on block | `vibration` / `HapticFeedback` | `✅` |
| State | `flutter_bloc` | `✅` |
| Analytics (`{platform}_blocked`) | `firebase_analytics` | `✅` |

---

## Related docs

- `01-architecture-overview.md` — Clean Architecture + bloc layering and the native boundary map.
- `02-accessibility-service.md` — `NoScrollAccessibilityService`, foreground service, command/status broadcasts, the EventChannel both features consume.
- `03-detection-engine.md` — `platforms_config.json`, `LegacyDetector.findViewByIdWithId`, DFS/12000-node traversal shared with web capture.
- `04-block-actions-and-modes.md` — `BlockingModesEnum`, debounce (1200 ms), PRESS_BACK rate-limit, overlay grace windows.
- `05-plans-pause-and-premium.md` — `PlansEnum`, premium gating, pause/cooldown UI shared with the app blocker.
- `07-persistence-and-config.md` — DataStore keys (`WEB_BLOCK_LIST`, `BLOCKED_SITES` migration), Hive/secure-storage mapping.
