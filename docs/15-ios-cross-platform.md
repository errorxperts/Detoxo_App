# iOS / Cross-Platform Feasibility

This document is an honest, evidence-grounded assessment of whether the Android short-form-content blocker can be re-built on iOS, and how to structure the Flutter app so that the two platforms share a domain layer while differing entirely at the data/platform layer. The short answer: **iOS cannot replicate the Android detection model at all** — there is no API that lets a third-party app read another app's view hierarchy, detect an individual reel/short, simulate a back press, kill another app, or read a browser's URL. What iOS *can* do is **block entire apps, app categories, and (partially) web domains** through Apple's Screen Time stack (FamilyControls + ManagedSettings + DeviceActivity). This is a coarser, parental-control-flavored model. This doc maps every Android feature to its nearest iOS capability, gives a feasibility verdict for each, and recommends a shared-domain / split-data-source architecture.

---

## 1. Why the Android engine has no iOS analogue

The Android engine (verified across `service/accessibility/NoScrollAccessibilityService.java`, `LegacyDetector`, and `res/raw/platforms_config.json`) works by:

1. Binding to the OS as an **AccessibilityService** (`BIND_ACCESSIBILITY_SERVICE`), which streams `onAccessibilityEvent` for *every other app*.
2. Walking the live **AccessibilityNodeInfo** tree of the foreground app (`findAccessibilityNodeInfosByViewId`, DFS via `ArrayDeque.removeLast()` up to 12000 iterations) to find a resource-id such as `":id/reel_player_underlay"` (YouTube Shorts) or `":id/clips_author_username"` (Instagram Reels).
3. Acting *on another app* — `performGlobalAction(GLOBAL_ACTION_BACK)`, `ActivityManager` kill, `DevicePolicyManager.lockNow()`, or a `TYPE_APPLICATION_OVERLAY` window.
4. Reading **browser URLs** out of the address-bar node (`parseWebUrlParts`, `matchesSubdomainWildcard`) to block specific web domains.

**iOS forbids every one of those four capabilities for third-party apps.** App sandboxing means an app cannot observe, inspect, or control any other app's UI or process. iOS's own accessibility framework (`UIAccessibility`, VoiceOver) is the inverse of Android's: it lets an app *expose* its own content to assistive tech, not *read* other apps' content. There is **no public API** to enumerate another app's views, detect that "a reel is on screen," send a synthetic back gesture to Safari, or terminate Instagram.

> Verdict for the core detection engine on iOS: **Impossible.** Per-reel / per-short detection is the load-bearing feature of the Android app, and it simply cannot be built on iOS. Plan for a *different product shape* on iOS, not a port.

---

## 2. What iOS *does* offer: the Screen Time stack

Apple's only sanctioned mechanism for restricting other apps is the **Screen Time / Family Controls** framework family (iOS 15.1+, meaningfully usable 16.0+). These run inside a *restricted, entitled* sandbox. They give coarse-grained control (whole apps, categories, web domains, schedules, time budgets) but **never** content-level introspection.

| Framework | Role | What it can do | What it cannot do |
|---|---|---|---|
| **FamilyControls** | Authorization + app/category picker | Request `AuthorizationCenter` access; present `FamilyActivityPicker` so the user opaquely selects apps/categories to restrict | Tell you *which* apps were picked (selections are opaque tokens — privacy-preserving) |
| **ManagedSettings** + `ManagedSettingsStore` | Apply restrictions | Shield specific apps, app categories, or web domains; restrict the app from being deleted; restrict adding accounts | Detect or react to in-app content; differentiate a reel from a normal feed |
| **DeviceActivity** + `DeviceActivityMonitor` | Schedules + usage thresholds | Run an OS-launched extension at schedule start/end (`intervalDidStart/End`); fire when a usage **threshold** (e.g. 30 min on a category) is crossed (`eventDidReachThreshold`) | Real-time per-event streaming; reading what is on screen |
| **ShieldConfiguration** / **ShieldAction** | Custom block screen | Customize the shield UI (title, subtitle, icon, button labels/colors) shown over a blocked app; handle the shield's primary/secondary button tap | Render arbitrary Flutter UI; the shield is a constrained Apple-rendered surface configured via an extension |

### Hard requirements / gotchas (be honest about these)

- **Entitlement gate.** FamilyControls requires the **Family Controls capability/entitlement** (`com.apple.developer.family-controls`). For *non-MDM* personal use you must request the **distribution entitlement from Apple** ("Family Controls (Distribution)"); the development entitlement works in Xcode but the App Store build needs Apple's approval. This is an explicit Apple review step, not a checkbox. (Treat this as a project risk, not a given.)
- **App Extensions required.** `DeviceActivityMonitor`, `ShieldConfiguration`, and `ShieldAction` are **App Extension targets**, each running in its own process, launched by the OS — not callable from your main app or from Dart. They are Swift/Obj-C only.
- **Opaque selections.** `FamilyActivitySelection` tokens are deliberately not human-readable; you cannot show "you blocked Instagram" by name unless the user told you, and you cannot programmatically build a blocklist from package ids the way Android does.
- **iOS 16+ for the useful surface.** Shields, web-domain shields, and most extension points stabilized in iOS 16; assume iOS 16.0 as a practical floor.
- **No background "service."** There is no foreground service / always-running process. The OS launches your extensions at scheduled times or threshold crossings only.

---

## 3. Android feature → iOS capability map (feasibility verdict)

Legend: **Possible** = supported by the Screen Time stack with reasonable effort · **Partial** = supported but materially weaker/coarser than Android · **Impossible** = no public iOS API.

| Android feature (evidence) | iOS mechanism | Verdict | Notes |
|---|---|---|---|
| **Per-reel / per-short detection** (`LegacyDetector.findViewByIdWithId`, identifiers like `":id/reel_player_underlay"`) | — none — | **Impossible** | No third-party app may read another app's view tree or know a reel is on screen. This is the defining feature and it is gone on iOS. |
| **Block the whole social app** (KILL_APP / overlay over Instagram) | `ManagedSettingsStore.shield.applications` (tokens from `FamilyActivityPicker`) | **Possible** | Shields the entire app; user sees Apple's shield screen instead of the app. Coarser than "block only reels." |
| **Block by app category** (e.g. all social) | `ManagedSettingsStore.shield.applicationCategories` / `webDomainCategories` | **Possible** | Category = bundle of apps; you cannot selectively allow the non-reel parts. |
| **Web domain blocking in browsers** (`parseWebUrlParts`, `WebMatchTypeEnum = DOMAIN/EXACT/WILDCARD`, `matchesSubdomainWildcard`) | `ManagedSettingsStore.shield.webDomains` / `webDomainCategories` + `WebContentFilter` | **Partial** | Blocks navigation to a domain in Safari and apps using WKWebView/`WebContentFilter`. No reading of the URL, no path-scope/prefix matching like `pathMatchesDomainScope`, no in-app-browser coverage for apps that don't honor content filtering. Wildcard/subdomain behavior is Apple's, not yours. |
| **Daily time limit** (per-package quota in service model) | `DeviceActivitySchedule` + threshold `DeviceActivityEvent` → `eventDidReachThreshold` shields the app | **Possible** | Threshold granularity is minutes of usage on selected apps/categories, not per-reel counts. |
| **Schedules / focus windows** (plan-based gating) | `DeviceActivitySchedule` (`intervalStart`/`intervalEnd`, repeating) → `intervalDidStart`/`intervalDidEnd` apply/clear shields | **Possible** | Maps cleanly to "block social 9am–6pm" style rules. |
| **PRESS_BACK** (`performGlobalAction(GLOBAL_ACTION_BACK)`, `BlockingModesEnum.PRESS_BACK`) | — none — | **Impossible** | Cannot send input to another app. The shield *replaces* the app instead. |
| **KILL_APP** (`ActivityManager`, `BlockingModesEnum.KILL_APP`) | — none — (shield is the substitute) | **Impossible** | Cannot terminate another app; shield prevents interaction instead. |
| **LOCK_SCREEN** (`DevicePolicyManager.lockNow`, `BlockingModesEnum.LOCK_SCREEN`) | — none — | **Impossible** | No public lock-device API for third parties. |
| **Custom block / overlay screen** (`TYPE_APPLICATION_OVERLAY`, one-reel overlay, PIN overlay) | `ShieldConfiguration` + `ShieldAction` extensions | **Partial** | You customize Apple's shield (text/icon/buttons) and handle button taps; you cannot draw arbitrary Flutter UI over another app. Your own in-app screens are unrestricted. |
| **PIN / passcode gate to change settings** (PinBlockOverlay) | In-app passcode/biometric (your own UI) | **Possible** | Implement entirely inside your app (`local_auth` + secure store). You can also let `ShieldAction` defer the unblock to your app where the PIN lives. |
| **Pause blocking** (`PlansEnum.PAUSED`, `pauseExpiry`) | Clear the relevant `ManagedSettingsStore` shields for a window, restore via a `DeviceActivitySchedule` | **Possible** | "Pause for 15 min" = remove shields now, re-apply at a scheduled `intervalDidStart`. |
| **Curious / One-Reel allowance** (`PlansEnum.CURIOUS`, `ONE_REEL`) | — none (no content granularity) — | **Impossible** | These depend on counting individual reels, which iOS cannot observe. Closest *approximation*: a short time budget via threshold, but it is not "one reel." |
| **Real-time foreground-app stream** (`onAccessibilityEvent` throttled 150ms) | `DeviceActivityMonitor` callbacks (interval/threshold only) | **Partial** | Event-driven but only at schedule boundaries / usage thresholds — not a continuous stream and never per-frame. |
| **Boot persistence / resurrection** (`onTaskRemoved` restart, BOOT_COMPLETED) | OS-managed | **Possible (by default)** | Screen Time restrictions persist across reboot because the OS enforces them; there is nothing to "keep alive." |
| **Uninstall protection** (DeviceAdmin) | `ManagedSettings` `application.denyAppRemoval` (when entitled) | **Partial** | Can deny removal of *managed* apps under Family Controls; constrained and Apple-policed. |
| **Usage analytics** (Room/`drift` block history) | `DeviceActivityReport` (SwiftUI report extension) | **Partial** | Apple exposes aggregate usage only inside a sandboxed report extension; raw per-event data is not handed to your app. |

---

## 4. Honest summary of the iOS product

| Android model | iOS model |
|---|---|
| Surgically blocks **just** reels/shorts while letting the rest of the app work | Blocks (shields) the **whole app or category**, or imposes a **time budget / schedule** |
| Detects content in real time, reacts within ~150ms | Reacts at schedule boundaries or usage thresholds only |
| Reads and matches browser URLs with wildcard/path scope | Blocks whole web **domains/categories** via content filter; no URL reading |
| Press-back / kill / lock as block actions | Apple shield screen is the only "action" |
| Counts reels for Curious / One-Reel plans | No content counting → these plans cannot exist on iOS |

The iOS build is therefore best framed to users as a **Screen-Time-powered app/category/website limiter with schedules and time budgets**, not as a reel detector. Set expectations in copy and in the App Store listing accordingly.

---

## 5. Flutter packaging reality (treat pub packages as immature)

There is no mature, production-grade pub.dev package that fully wraps FamilyControls + DeviceActivity + ManagedSettings + the required extensions. Packages that claim Screen Time support tend to cover only authorization and a sliver of ManagedSettings, and they cannot create the **App Extension targets** for you (`DeviceActivityMonitor`, `ShieldConfiguration`, `ShieldAction`) — those must exist in the Xcode project as native Swift targets and are wired up at build time.

**Recommendation:** write a **custom Swift Flutter plugin** plus the required **App Extension targets**, and expose a small MethodChannel surface to Dart. If you adopt a pub package, treat it as a thin convenience over the same native work and verify it against the entitlement/extension requirements above before committing. Legend per the blueprint convention:

| iOS need | How it's reached from Flutter |
|---|---|
| Request FamilyControls authorization | ⚠️ MethodChannel → Swift `AuthorizationCenter.requestAuthorization` |
| Present `FamilyActivityPicker`, persist opaque selection | ⚠️ MethodChannel → Swift (selection stored natively / in App Group) |
| Apply/clear shields (`ManagedSettingsStore`) | ⚠️ MethodChannel → Swift |
| Schedules & thresholds (`DeviceActivityCenter`) | ⚠️ MethodChannel → Swift |
| Monitor callbacks (`DeviceActivityMonitor`) | ⚠️ **Separate App Extension target** (Swift) — not Dart-reachable; communicates state via an **App Group** shared container |
| Custom shield UI/actions (`ShieldConfiguration`/`ShieldAction`) | ⚠️ **Separate App Extension targets** (Swift) |
| In-app PIN / biometric gate | ✅ `local_auth` + `flutter_secure_storage` (pure Flutter, shared with Android) |
| Per-reel detection, press-back, kill, lock, URL reading | ❌ Not possible on iOS |

> The extensions are launched by the OS in their own processes; they cannot call back into the Flutter engine. Use an **App Group** + shared `UserDefaults`/file container as the bridge between your main app (Flutter) and the extensions (Swift).

---

## 6. Recommended cross-platform architecture

Keep a **single shared Dart domain + bloc layer**, and swap the **data/platform layer** per OS. The domain expresses intent ("block this set of platforms," "pause for 15 min," "apply this schedule"); each platform's data source translates that intent into either the Android accessibility engine or the iOS Screen Time stack — or returns "unsupported" for impossible features.

```
domain/  (shared, platform-agnostic)
  entities/        BlockingPlan, BlockTarget, Schedule, PauseSession, ...
  repositories/    abstract BlockingRepository, RestrictionRepository
  usecases/        ApplyBlockingPlan, PauseBlocking, ApplySchedule, ...

data/
  repositories/    BlockingRepositoryImpl  (picks the right data source)
  datasources/
    android/       AndroidAccessibilityDataSource   (MethodChannel/EventChannel)
    ios/           IosScreenTimeDataSource          (MethodChannel -> Swift plugin)

presentation/bloc/ shared blocs; UI branches on platform capability flags
```

### Capability flags drive the UI

Because many features are Impossible/Partial on iOS, expose a capability descriptor from each data source so the UI can hide or reword features rather than crash.

```dart
// domain/entities/blocking_capabilities.dart
class BlockingCapabilities {
  final bool perContentDetection;   // Android: true,  iOS: false
  final bool blockWholeApp;         // Android: true,  iOS: true
  final bool blockCategory;         // Android: false, iOS: true
  final bool blockWebDomain;        // Android: full,  iOS: partial
  final bool pressBack;             // Android: true,  iOS: false
  final bool killApp;               // Android: true,  iOS: false
  final bool lockDevice;            // Android: true,  iOS: false
  final bool dailyTimeLimit;        // both: true
  final bool schedules;             // both: true
  final bool pinGate;               // both: true (in-app)
  final bool pauseBlocking;         // both: true

  const BlockingCapabilities({
    required this.perContentDetection,
    required this.blockWholeApp,
    required this.blockCategory,
    required this.blockWebDomain,
    required this.pressBack,
    required this.killApp,
    required this.lockDevice,
    required this.dailyTimeLimit,
    required this.schedules,
    required this.pinGate,
    required this.pauseBlocking,
  });
}
```

### A shared repository contract, two implementations

```dart
// domain/repositories/restriction_repository.dart
abstract class RestrictionRepository {
  Future<BlockingCapabilities> capabilities();

  /// Throws UnsupportedFeature on platforms where a target type is impossible.
  Future<void> applyPlan(BlockingPlan plan);
  Future<void> pause(Duration window);
  Future<void> applySchedule(Schedule schedule);
}

class UnsupportedFeature implements Exception {
  final String feature;
  const UnsupportedFeature(this.feature);
}
```

```dart
// data/datasources/ios/ios_screen_time_datasource.dart  (sketch)
class IosScreenTimeDataSource implements RestrictionRepository {
  static const _ch = MethodChannel('app/ios_screen_time');

  @override
  Future<BlockingCapabilities> capabilities() async => const BlockingCapabilities(
        perContentDetection: false,
        blockWholeApp: true,
        blockCategory: true,
        blockWebDomain: true,   // partial — surfaced as a caveat in UI
        pressBack: false,
        killApp: false,
        lockDevice: false,
        dailyTimeLimit: true,
        schedules: true,
        pinGate: true,
        pauseBlocking: true,
      );

  @override
  Future<void> applyPlan(BlockingPlan plan) async {
    if (plan.requiresPerContentDetection) {
      throw const UnsupportedFeature('per-reel detection');
    }
    // Native side: ensure FamilyControls auth, then set ManagedSettingsStore shields
    // from the previously-picked FamilyActivitySelection token.
    await _ch.invokeMethod('applyShields', plan.toIosArgs());
  }

  @override
  Future<void> pause(Duration window) =>
      _ch.invokeMethod('pause', {'seconds': window.inSeconds});

  @override
  Future<void> applySchedule(Schedule schedule) =>
      _ch.invokeMethod('applySchedule', schedule.toIosArgs());
}
```

```dart
// data/datasources/android/android_accessibility_datasource.dart  (sketch)
class AndroidAccessibilityDataSource implements RestrictionRepository {
  static const _ch = MethodChannel('app/android_accessibility');

  @override
  Future<BlockingCapabilities> capabilities() async => const BlockingCapabilities(
        perContentDetection: true,
        blockWholeApp: true,
        blockCategory: false,
        blockWebDomain: true,
        pressBack: true,
        killApp: true,
        lockDevice: true,
        dailyTimeLimit: true,
        schedules: true,
        pinGate: true,
        pauseBlocking: true,
      );

  @override
  Future<void> applyPlan(BlockingPlan plan) =>
      _ch.invokeMethod('applyDetectionPlan', plan.toAndroidArgs());

  @override
  Future<void> pause(Duration window) =>
      _ch.invokeMethod('pause', {'ms': window.inMilliseconds});

  @override
  Future<void> applySchedule(Schedule schedule) =>
      _ch.invokeMethod('applySchedule', schedule.toAndroidArgs());
}
```

The bloc layer never references AccessibilityService or FamilyControls directly — it talks to `RestrictionRepository` and reads `BlockingCapabilities` to decide what to render. This keeps ~all business logic shared while isolating the irreducible platform gap.

---

## 7. Practical guidance / open uncertainties

- **Validate the entitlement first.** Before estimating an iOS launch, confirm you can obtain the Family Controls **distribution** entitlement for your account and use case; without it the App Store build is blocked. This is the single biggest unknown.
- **Prototype the extensions early.** The `DeviceActivityMonitor` ↔ App Group ↔ main app handoff is the trickiest plumbing; build a thin spike before committing to scope.
- **Web blocking is "Partial" for real reasons.** It only covers browsers/apps that honor `WebContentFilter`; many apps' embedded webviews will not be filtered. Do not promise URL/path-level blocking parity with Android.
- **Set product expectations.** Market the iOS build as Screen-Time-based app/category/website limiting with schedules and budgets — not reel detection. Curious/One-Reel plans are Android-only.
- **Anything labeled (inferred) in sibling docs about gating logic stays inferred here too** — iOS cannot observe the signals those gates depend on, so the gating simply does not port; it is reduced to schedule/threshold rules.

---

## Source evidence

- `service/accessibility/NoScrollAccessibilityService.java` — AccessibilityService runtime, `performGlobalAction(GLOBAL_ACTION_BACK)`, `BlockingModesEnum` (PRESS_BACK/KILL_APP/LOCK_SCREEN/NONE), `PlansEnum` (BLOCK_ALL/CURIOUS/ONE_REEL/PAUSED), throttle/debounce constants — establishes the Android capabilities that have no iOS equivalent.
- `LegacyDetector` (`findViewByIdWithId`, `parseWebUrlParts`, `matchesSubdomainWildcard`, `WebMatchTypeEnum`) — node-tree traversal and URL matching that iOS forbids for third parties.
- `/Users/shahbazqureshi/Documents/No_scroll Decompile/resources/res/raw/platforms_config.json` — per-platform detector identifiers (`":id/reel_player_underlay"`, `":id/clips_author_username"`) confirming content-level detection that iOS cannot perform.
- `/Users/shahbazqureshi/Documents/No_scroll Decompile/resources/res/xml/site_manager_service.xml` — accessibility service config (Android-only binding model).
- `/tmp/synth_flutterPlan.md` — shared Flutter plan and prior iOS notes (Section 1 "iOS Considerations").
- Apple developer documentation for FamilyControls, ManagedSettings/ManagedSettingsStore, DeviceActivity/DeviceActivityMonitor, ShieldConfiguration/ShieldAction, and the Family Controls entitlement (external; cited as the iOS feasibility basis).

## Related docs

- `01-overview.md`
- `02-architecture.md`
- `03-accessibility-service.md`
- `04-detection-engine.md`
- `05-blocking-actions.md`
- `06-web-url-blocking.md`
- `07-platforms-config.md`
- `14-native-boundary-channels.md`
