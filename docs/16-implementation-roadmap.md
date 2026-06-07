# Implementation Roadmap, Testing & Risks

This document is the build plan for re-creating the short-form content blocker as a **Flutter app** (`flutter_bloc` + Clean Architecture), distilled from the decompiled native Android source. It sequences delivery into six phases (Phase 0 native spike → Phase 5 hardening + iOS), each with goals, deliverables, the exact pub.dev packages to use, and concrete exit criteria. It then specifies a layered testing strategy (Dart unit / bloc_test / widget / native Kotlin JUnit / on-device manual) and an explicit risk register covering Google Play AccessibilityService policy, OEM background-kill, overlay restrictions, and the obfuscated areas that must be re-verified before they are trusted. A milestone checklist closes the doc.

> Legend: ✅ a pub.dev package fully handles it · ⚠️ needs a native MethodChannel/EventChannel (Kotlin) · ❌ not possible on iOS.

---

## 0. How to read this roadmap

- **Vertical-slice first.** The core risk is the detection engine, not the UI. Phase 0 + Phase 1 prove the riskiest thing (real-time accessibility detection + block) before any business features.
- **Data-driven from day one.** Detection rules come from `platforms_config.json` (bundled fallback + server-fetched). Do not hardcode view-ids in Dart or Kotlin; load them from config. Verified at `resources/res/raw/platforms_config.json`.
- **Native boundary is fixed.** AccessibilityService, node-tree traversal, `performGlobalAction(BACK)`, app-kill, system overlays, DeviceAdmin, boot receiver and usage stats are ⚠️ native. Everything else is ✅ Dart. See `02-native-boundary.md` (sibling).
- **iOS is a separate track.** There is ❌ no AccessibilityService equivalent; only Apple FamilyControls / DeviceActivity / ManagedSettings, addressed in Phase 5.

### Verified constants this roadmap relies on

| Constant | Value | Source (verified) |
|---|---|---|
| `THROTTLE_INTERVAL_MS` | `150` | `NoScrollAccessibilityService.java:116` |
| block debounce | skip if `now - lastBlockTime <= 1200ms` | `NoScrollAccessibilityService.java:203` |
| PRESS_BACK rate-limit | act only if `lastVideoBlocked <= now - 1100ms` | `NoScrollAccessibilityService.java:241` |
| `ONE_REEL_OVERLAY_GRACE_MS` | `500` | `NoScrollAccessibilityService.java:111` |
| `ONE_REEL_OVERLAY_POLL_MS` | `500` | `NoScrollAccessibilityService.java:112` |
| `HARD_BLOCK_AFTER_CLOSE_TAP_MS` | `= SCAR_VERSION_FETCH_TIMEOUT = 5000ms` | `NoScrollAccessibilityService.java:114` → `ServiceProvider.java:422` (was estimated ~10000ms; **verified = 5000ms**) |
| FGS notification id / channel | `1125` / `"noscroll_protection_channel"` (LOW=importance 2) | `NoScrollAccessibilityService.java:543,560` |
| command broadcast action | `"com.noscroll.action.APP_COMMAND"` (RECEIVER_NOT_EXPORTED) | `NoScrollAccessibilityService.java:461` |
| status broadcast | `"...reelshortblocker.ACCESSIBILITY_SERVICE_STATUS_CHANGED"` extra `extra_accessibility_service_enabled` | `NoScrollAccessibilityService.java:367` |
| isolated process | `android:process=":as_process"` | `resources/AndroidManifest.xml:179` |
| DFS cap | max 12000 iterations, `ArrayDeque.removeLast()` | `LegacyDetector.findViewByIdWithId` (verified) |

---

## 1. Phase 0 — Native spike (prove the engine)

**Goal:** prove that a Flutter app can host an Android AccessibilityService, observe a target app's view tree, identify a short-form-content view-id, and dismiss it with a simulated Back press. Throwaway-quality is acceptable; this de-risks the whole project.

### Deliverables

| Deliverable | Layer | Detail |
|---|---|---|
| `ShortContentAccessibilityService.kt` | ⚠️ native | Minimal `AccessibilityService` declared in `AndroidManifest.xml` with `android:process=":as_process"` and an XML config (mirror of `resources/res/xml/site_manager_service.xml`). |
| `EventChannel("…/accessibility/events")` | ⚠️ native↔Dart | Emits `{packageName, viewId, eventType, ts}` for each relevant `AccessibilityEvent`. |
| `MethodChannel("…/accessibility/control")` | ⚠️ native↔Dart | `pressBack()` → `performGlobalAction(GLOBAL_ACTION_BACK)`; `isServiceEnabled()`. |
| Hardcoded probe | native | Detect YouTube Shorts via `":id/reel_player_underlay"` (verified identifier) and call back. Press back when seen. |
| Dart consumer | presentation | A debug screen streaming events from the EventChannel and logging detections. |

### Packages

- ⚠️ Custom Kotlin (no package is production-complete for tree search). For the spike you *may* prototype with `flutter_accessibility_service: ^0.4.x` to shorten the loop, but plan to replace it — its node-search API is too thin for `FINDBYID` DFS.
- ✅ `flutter/services.dart` (MethodChannel/EventChannel, built-in).

### Exit criteria

- [ ] Opening YouTube Shorts on a **physical device** triggers an event on the Dart EventChannel within ~150ms.
- [ ] Calling `pressBack()` from Dart actually exits the Short.
- [ ] Service survives screen-off/on and app backgrounding.
- [ ] Confirmed: the `:as_process` service can still receive the `APP_COMMAND` broadcast and read shared state (validates IPC assumption flagged in gaps §c.4).

---

## 2. Phase 1 — MVP (data-driven LEGACY detection + PRESS_BACK + toggle)

**Goal:** ship a usable blocker. Load detection rules from `platforms_config.json`, run the verified LEGACY detection path natively, block with `PRESS_BACK`, give the user a master on/off toggle, and a basic dashboard (block count).

### Deliverables

| Deliverable | Layer | Detail |
|---|---|---|
| Config models | data | `freezed` + `json_serializable` for `PlatformConfigResponse → AppDetails → PlatformRule → Detector → DetectionParams`. Keys verified: `detectionType` ∈ {LEGACY, CALIBRATION, OVERLAY, MANUAL, NONE}; detector keys `identifiers`, `supportedBlockModes`, `defaultBlockMode`, `priority`, `haltOnDetect`, `coupleWith`, `childNodeLimit`, `paramsClass`, `params`, `detectionParams`. |
| `PlatformConfigRepository` | data | Loads bundled `assets/json/platforms_config.json`, overlays server config (Phase 4 wires the network fetch; Phase 1 = bundled only). |
| `LegacyDetector` (Kotlin) | ⚠️ native | Re-implement the verified 3-stage search: **Stage 1** `event.source.getViewIdResourceName() == pkg+identifier && isFocusable && isVisibleToUser`; **Stage 2** `findAccessibilityNodeInfosByViewId(pkg+identifier)` → tag `[FIND]`; **Stage 3** DFS via `ArrayDeque.removeLast()`, children pushed last, ≤12000 iterations, tag `[DEEP]`, recycle non-result nodes. `ViewDetectorsEnum` = FINDBYID \| VIEWID_RES_NAME \| CONT_DESC \| BROWSER (Phase 1 = FINDBYID + VIEWID_RES_NAME only). |
| Throttle + debounce | ⚠️ native | Per-package throttle `THROTTLE_INTERVAL_MS=150`; block debounce `now-lastBlockTime<=1200ms` skip; PRESS_BACK gate `lastVideoBlocked<=now-1100ms` then `performGlobalAction(1)`. |
| `DetectShortContentUsecase` | domain | Pure Dart: given a native detection event + active config, decides whether it is a block-worthy match (also unit-testable host of the matching policy not done natively). |
| `BlockingBloc` | presentation | States: `BlockingIdle / BlockingActive / ContentBlocked(count)`. |
| Master toggle | presentation + ⚠️ native | Enable/disable via the verified `APP_COMMAND` broadcast (`EnumCommandToService`); reflect actual service state via the status broadcast `ACCESSIBILITY_SERVICE_STATUS_CHANGED`. |
| Foreground service notification | ⚠️ native | id `1125`, channel `"noscroll_protection_channel"` (LOW), FGS `specialUse` on API 34+. |
| Dashboard | presentation | Today's block count, service-on indicator, "Grant accessibility" CTA. |
| Permission flow | presentation | Open `ACTION_ACCESSIBILITY_SETTINGS`; prominent disclosure screen (policy requirement — see Risks §10.1). |

### Packages

- ✅ `flutter_bloc` / `bloc`, `equatable`
- ✅ `freezed` + `json_serializable` + `json_annotation` (+ `build_runner`)
- ✅ `get_it` (DI), `go_router` (nav)
- ✅ `app_settings` (open accessibility settings), `permission_handler`
- ✅ `vibration` (haptic on block — original fires a `VIDEO_BLOCKED` haptic)
- ✅ `shared_preferences` (toggle + counter) — encrypted store deferred to Phase 2
- ⚠️ Native Kotlin: service, LegacyDetector, EventChannel/MethodChannel, FGS notification, command/status broadcasts

### Exit criteria

- [ ] Detection rules come **only** from `platforms_config.json` (no hardcoded ids); swapping the JSON changes behavior with no recompile.
- [ ] YouTube Shorts, Instagram Reels (`:id/clips_author_username`), and Insta Pro (`:id/reel_viewer_title`) are blocked via PRESS_BACK on a real device.
- [ ] Throttle (150ms) and debounce (1200ms) measurably prevent double-blocks (log timestamps).
- [ ] Master toggle reliably starts/stops blocking; UI reflects true service state from the status broadcast.
- [ ] FGS notification appears with id 1125 and the LOW-importance channel.
- [ ] **iOS:** app builds and shows a "blocking unavailable on iOS" state (❌ no AccessibilityService).

---

## 3. Phase 2 — Plans + Pause + PIN

**Goal:** add the behavioral layer: blocking plans, a mindful pause countdown, and PIN + biometric protection so the user can't trivially disable the blocker.

### Deliverables

| Deliverable | Layer | Detail |
|---|---|---|
| `BlockingPlan` entity | domain | `PlansEnum` = BLOCK_ALL \| CURIOUS \| ONE_REEL \| PAUSED (verified). |
| `PlanBloc` | presentation | Switch active plan; persist; broadcast to service via `APP_COMMAND`. |
| `BlockingMode` resolution | domain/native | `BlockingModesEnum` ordinals PRESS_BACK(1)=BACK, KILL_APP(2)=close, LOCK_SCREEN(3)=lock, NONE(4)=noop. Resolution order (verified): `defaultBlockingMode` → first non-NONE `supportedBlockMode` → fallback PRESS_BACK. |
| Mindful pause | presentation + ⚠️ native | `PAUSED` plan with countdown; while paused, detection still runs but blocking is suppressed until expiry. (Pause-window data shape needs verification — gaps §c.1.) |
| ONE_REEL grace | ⚠️ native | Honor `ONE_REEL_OVERLAY_GRACE_MS=500` / `ONE_REEL_OVERLAY_POLL_MS=500`; `onKeyEvent` BACK closes the one-reel overlay (verified). |
| PIN setup/verify | data + presentation | `PinBloc`; store PIN **hashed** in `flutter_secure_storage` (original keeps a `LOCAL_OTP` in DataStore — encryption details unverified, gaps §b.3; we mandate hashing). |
| Biometric gate | presentation | `local_auth` BiometricPrompt before disabling protection / editing blocklists. |

### Packages

- ✅ `local_auth` (biometric), `flutter_secure_storage` (PIN hash, tokens)
- ✅ `hive` / `hive_flutter` (plan state, session objects)
- ✅ `flutter_bloc`, `intl` (countdown formatting)
- ⚠️ Native: plan/pause state pushed to `:as_process` service; `KILL_APP` via `ActivityManager`, `LOCK_SCREEN` via DeviceAdmin (DeviceAdmin enrollment in Phase 5; until then LOCK_SCREEN is disabled with a clear UI note)

### Exit criteria

- [ ] Switching plans changes block behavior live; `PAUSED` suppresses blocking until countdown ends, then auto-resumes.
- [ ] PIN required to turn protection off; PIN is never stored in plaintext (verify in storage dump).
- [ ] Biometric unlock works and falls back to PIN.
- [ ] ONE_REEL allows exactly one reel within the grace window, then blocks.
- [ ] **iOS:** plans/PIN UI works; enforcement remains ❌ (FamilyControls path deferred to Phase 5).

---

## 4. Phase 3 — App blocker + Web blocker + Daily limit + Scheduler

**Goal:** broaden enforcement beyond reels: block whole apps, block web reels via URL matching, enforce a daily time limit, and schedule blocking windows.

### Deliverables

| Deliverable | Layer | Detail |
|---|---|---|
| App blocker | data + ⚠️ native | User picks installed apps; service kills/locks them on foreground. Foreground detection is best via the AccessibilityService event stream (most real-time). |
| Web blocker | domain + ⚠️ native | Re-implement verified `parseWebUrlParts`: strip unicode directional marks `{65279,8206,8207,8234,8235,8236,8294,8295,8296,8297}`, drop scheme + `www.`/`m.` → canonical host; `matchesSubdomainWildcard` (`*.domain`); `pathMatchesDomainScope` = path prefix. `WebMatchTypeEnum` = DOMAIN \| EXACT \| WILDCARD. URL is read from the **browser address bar node** (BROWSER detector). Note: address-bar view-ids per browser are **unverified** — see Risks §10.4. |
| `MatchWebUrlUsecase` | domain | Pure Dart; the canonicalization + wildcard/exact/domain matching is testable without native. |
| Daily limit | domain + data | Counter with daily reset signature (`dd-MM-yyyy`). **Timezone of reset is unverified** (gaps §a.4) — implement explicitly in device-local time and document. |
| Scheduler | data + ⚠️ native | Time-window rules (e.g., block 9am–5pm). Use `workmanager` for periodic checks + reset; live enforcement stays in the service. |

### Packages

- ✅ `device_apps` / `installed_apps` (app list + icons)
- ✅ `workmanager` (daily reset, periodic schedule checks, config sync)
- ✅ `usage_stats` (supplementary periodic foreground check; not the primary real-time path)
- ✅ Dart built-in `Uri` + `RegExp` for URL canonicalization (no native needed for the matching logic)
- ✅ `drift` (analytics/history of blocks, daily counters) — introduced here
- ⚠️ Native: app-kill, browser address-bar node read, scheduler enforcement in service

### Exit criteria

- [ ] Selected apps are blocked on launch; list survives reboot.
- [ ] A blocked web reel host (e.g. a `*.domain` wildcard) is detected from the address bar and blocked; `MatchWebUrlUsecase` unit tests cover DOMAIN/EXACT/WILDCARD + directional-mark stripping.
- [ ] Daily limit resets exactly once per local day; documented timezone behavior.
- [ ] Scheduled windows activate/deactivate blocking automatically.
- [ ] **iOS:** app/web blocking ❌ (closest is ManagedSettings app/web-content restrictions, Phase 5).

---

## 5. Phase 4 — Premium (billing + gating) + Ads + Analytics + Notifications

**Goal:** monetize and instrument. Wire Google Play Billing with feature gating, AdMob (incl. rewarded-unlock), analytics, FCM, and the server config fetch.

### Deliverables

| Deliverable | Layer | Detail |
|---|---|---|
| Billing | data | `in_app_purchase`; subscriptions + one-time. Premium gates `premiumExclusive` platforms/detectors (verified key). |
| Purchase → backend sync | data | **Unverified in source** (gaps §b.4, §c) — no `syncPurchase()` endpoint was visible. Design our own: send purchase token to backend for server-side validation; treat client entitlement as a cache. |
| Premium gating usecase | domain | `CheckPremiumStatusUsecase`; gate blocked features and remove ads when premium. |
| Ads | presentation/data | `google_mobile_ads` banner/interstitial/rewarded + UMP consent. Rewarded-ad → temporary unlock hook (original's reward-grant body was synthetic/unverified, gaps §a.3 — implement the unlock explicitly). |
| Server config fetch | data | `dio`-based client fetches `platforms_config.json` (+ `initial_config.json`, calibration). Retry/backoff + **bundled-asset fallback** (original's retry/fallback strategy was not visible, gaps §a.5 — define it: exponential backoff, fall back to last-good cache, then bundled asset). Optionally `firebase_remote_config`. |
| Analytics | data | `firebase_analytics`; log block/unlock/plan-switch events. Local mirror in `drift`. |
| Notifications | data | `flutter_local_notifications` + `firebase_messaging` (FCM). |

### Packages

- ✅ `in_app_purchase` (+ `in_app_purchase_android`)
- ✅ `google_mobile_ads` (ads + UMP consent)
- ✅ `firebase_core`, `firebase_analytics`, `firebase_messaging`, `firebase_remote_config` (optional), `cloud_firestore` (optional)
- ✅ `dio` (+ `retrofit`/`json_serializable` codegen), `flutter_local_notifications`
- ✅ `drift` (analytics persistence)

### Exit criteria

- [ ] Purchasing premium unlocks `premiumExclusive` rules and disables ads; entitlement persists and is validated server-side.
- [ ] Rewarded ad grants a verifiable temporary unlock that expires.
- [ ] Server config fetch succeeds; on network failure the app falls back last-good cache → bundled asset without crashing.
- [ ] Analytics events fire for block/unlock/plan-switch; FCM message displays a notification.
- [ ] **iOS:** billing ✅ (StoreKit via `in_app_purchase`), ads ✅, analytics ✅; enforcement still ❌.

---

## 6. Phase 5 — Hardening (resurrection, device admin, OEM battery, calibration) + iOS FamilyControls

**Goal:** make it survive hostile OS conditions and aggressive users, add the precision/overlay detection paths, and stand up the iOS parental-control track.

### Deliverables

| Deliverable | Layer | Detail |
|---|---|---|
| Service resurrection | ⚠️ native | `onTaskRemoved` restarts the foreground service (verified behavior); boot receiver (`BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`) re-arms the service. |
| Device admin | ⚠️ native | `DeviceAdminReceiver` for uninstall-protection + `LOCK_SCREEN` block mode (`DevicePolicyManager.lockNow()`). Surface enable/disable via EventChannel. |
| OEM battery handling | ⚠️ native + ✅ | Detect manufacturer (`device_info_plus`) and deep-link to OEM auto-start/battery settings; request `isIgnoringBatteryOptimizations()` exemption via `permission_handler`. |
| CALIBRATION + OVERLAY detection | ⚠️ native | `detectionType` CALIBRATION (bounds-based, uses calibration config: TOP/BOTTOM/LEFT/RIGHT margins, width/height per platform version) and OVERLAY (system overlay via `flutter_overlay_window` or native `TYPE_APPLICATION_OVERLAY`); honor `supportsOverlay`. Hard-block grace `HARD_BLOCK_AFTER_CLOSE_TAP_MS=5000`. |
| iOS FamilyControls track | iOS native | FamilyControls + DeviceActivity + ManagedSettings (Family Controls entitlement; parental-control framing). Block app/web *categories*; **no in-app content detection** (cannot see reel view-ids). Documented as a fundamentally reduced feature set. |

### Packages

- ✅ `device_info_plus` (OEM brand/version), `permission_handler` (battery exemption), `app_settings`
- ✅ `flutter_overlay_window` (overlay block UI) — native `WindowManager` fallback for animated overlays
- ⚠️ Native: device admin, boot receiver, `onTaskRemoved` restart, calibration/overlay detectors
- iOS: FamilyControls / DeviceActivity / ManagedSettings (no Flutter package is complete; thin Swift plugin)

### Exit criteria

- [ ] Killing the app from recents and rebooting both re-arm the service automatically.
- [ ] Device admin enables uninstall-protection and `LOCK_SCREEN` blocking works.
- [ ] On a known-aggressive OEM (e.g., Xiaomi/Oppo/Vivo) the service survives an overnight idle test.
- [ ] CALIBRATION + OVERLAY detection block at least one platform that LEGACY cannot.
- [ ] **iOS:** FamilyControls restricts a chosen app category end-to-end (reduced scope, documented).

---

## 7. Testing strategy

The accessibility engine cannot be fully tested in CI — the actual node tree only exists on a device — so testing is layered: maximize what is verifiable in pure Dart/JVM, and reserve a disciplined manual matrix for the device-only parts.

### 7.1 Layered test pyramid

| Layer | Tooling | What to cover | Runs in CI? |
|---|---|---|---|
| Dart unit | `flutter_test`, `mocktail` | Entities (`BlockingPlan`, `WebBlocklistEntry`), usecases (`MatchWebUrlUsecase`, `DetectShortContentUsecase`, `CheckPremiumStatusUsecase`), enum converters, daily-reset signature, URL canonicalization | ✅ |
| Bloc | `bloc_test` | `BlockingBloc`, `PlanBloc`, `PinBloc`, `PremiumBloc`, `DailyLimitBloc` — event→state transitions, debounce/throttle policy where modeled in Dart | ✅ |
| Widget | `flutter_test` (`WidgetTester`) | Dashboard, permission/disclosure screen, plan picker, PIN entry, pause countdown, blocklist editors | ✅ |
| Native unit | Kotlin **JUnit** + Robolectric, mock `AccessibilityNodeInfo` | `LegacyDetector` 3-stage search; DFS cap (12000) + node recycling; throttle/debounce timers; `BlockingMode` resolution order; URL parse (directional-mark strip, wildcard match) | ✅ (JVM) |
| Integration | `integration_test`, MethodChannel mocks | Detection-event → block-decision → UI count, with the native layer mocked | ✅ (mocked) / ⚠️ device |
| On-device manual | physical devices | Real accessibility detection + real PRESS_BACK/KILL/LOCK on real target apps | ❌ device-only |

### 7.2 Key Dart unit targets (highest ROI, no device needed)

- `MatchWebUrlUsecase`: assert directional marks `{65279,8206,8207,8234,8235,8236,8294,8295,8296,8297}` are stripped; `www.`/`m.` removed; `*.domain` wildcard, EXACT, DOMAIN, and path-prefix scope all behave.
- Daily-reset signature: same `dd-MM-yyyy` day → no reset; next local day → reset; **explicit timezone test** (the original's TZ handling is unverified — pin ours).
- `BlockingMode` resolution: `defaultBlockingMode` honored; else first non-NONE `supportedBlockMode`; else PRESS_BACK.

### 7.3 bloc_test sketch

```dart
blocTest<BlockingBloc, BlockingState>(
  'debounces a second detection inside 1200ms',
  build: () => BlockingBloc(blockUseCase: mockBlock),
  act: (bloc) {
    bloc.add(ContentDetected(at: t0));
    bloc.add(ContentDetected(at: t0 + 800)); // within debounce → ignored
  },
  expect: () => [const ContentBlocked(count: 1)],
  verify: (_) => verify(() => mockBlock(any())).called(1),
);
```

### 7.4 Native Kotlin JUnit sketch (the detector)

```kotlin
@Test fun stage1_matchesFocusableVisibleNodeById() {
  val node = mockNode(viewId = "com.google.android.youtube:id/reel_player_underlay",
                       focusable = true, visibleToUser = true)
  val result = LegacyDetector.findViewByIdWithId(node, "com.google.android.youtube",
                                                 ":id/reel_player_underlay")
  assertTrue(result.matched); assertEquals("[FIND]", result.tag)
}

@Test fun dfs_stopsAt12000_andRecyclesNonResultNodes() { /* deep tree, assert cap + recycle */ }
```

### 7.5 On-device manual matrix (device-only, mandatory before release)

| Dimension | Values |
|---|---|
| OS | Android 11, 12, 13, 14, 15 (FGS specialUse + overlay rules differ) |
| OEM | Pixel (clean), Samsung One UI, Xiaomi MIUI/HyperOS, Oppo/Vivo, OnePlus |
| Targets | YouTube Shorts, Instagram Reels + Insta Pro, Facebook Reels, TikTok, Snapchat Spotlight, Chrome/Firefox/Samsung Browser web reels |
| Scenarios | grant flow, block each plan, pause+resume, PIN/biometric, kill-from-recents resurrection, reboot resurrection, overnight battery idle, daily-limit rollover at local midnight |

**Why device-only:** AccessibilityService binding, real view-ids, `performGlobalAction`, overlays and OEM kill behavior have no faithful emulator/CI equivalent.

---

## 8. Risks & mitigations

### 8.1 Google Play AccessibilityService policy (highest risk)

- **Risk:** Play requires that AccessibilityService be used only for a *qualifying* purpose and demands a **prominent in-app disclosure** plus a Play Console declaration; misuse (or weak disclosure) → rejection/removal. The IsAccessibilityTool flag and store-listing justification matter.
- **Mitigation:** Frame as an accessibility/digital-wellbeing aid; ship a dedicated prominent-disclosure screen *before* requesting the permission (built in Phase 1); complete the Console AccessibilityService declaration; keep a privacy policy describing exactly what node data is read and that it never leaves the device.

### 8.2 OEM background-kill / battery optimization

- **Risk:** Xiaomi/Oppo/Vivo/Samsung aggressively kill background + accessibility services, breaking enforcement silently.
- **Mitigation:** FGS `specialUse` (API 34+) with persistent notification (id 1125); `onTaskRemoved` + boot receiver resurrection (Phase 5); battery-exemption request + OEM auto-start deep-links (`device_info_plus` + `permission_handler` + `app_settings`); overnight idle test in the manual matrix.

### 8.3 Overlay restrictions on newer Android

- **Risk:** `TYPE_APPLICATION_OVERLAY` and `SYSTEM_ALERT_WINDOW` are increasingly restricted; some surfaces (other overlays/secure windows) can't be drawn over; OVERLAY block mode may be unreliable on 12+.
- **Mitigation:** prefer PRESS_BACK/KILL as the primary block; treat OVERLAY as enhancement; gate overlay usage behind a runtime `canDrawOverlays()` check; `flutter_overlay_window` with native fallback.

### 8.4 Obfuscated areas to re-verify before trusting (from gaps analysis)

These were `Method dump skipped` / synthetic / unverified in the decompile. **Do not encode them as fact** — re-verify on a device or from a cleaner decompile, and label our implementation `(inferred)` until confirmed.

| # | Area | Open question | Source |
|---|---|---|---|
| 1 | `onAccessibilityEvent` order | Does per-package throttle run **before or after** plan/detection checks? Our inferred order: throttle → active-plan → detector dispatch → `handleShortVideoDetection`. | `NoScrollAccessibilityService.java` (dump skipped), gaps §a.1 |
| 2 | `processAndBlockShortContent` gating | Exact pause/curious/premium/quota control flow is obfuscated. | gaps §a.2 |
| 3 | Daily-reset timezone | UTC vs device-local midnight in `refreshSignature("dd-MM-yyyy")`. We pin **device-local** + test it. | `DailyAppBlocker.java`, gaps §a.4 |
| 4 | Browser URL-bar view-ids | Per-browser address-bar node ids (Chrome/Firefox/Samsung) not in source; must be captured from real node dumps. | gaps §b.1 |
| 5 | Hard-block constant | Re-verified here as **5000ms** (`SCAR_VERSION_FETCH_TIMEOUT`), not the earlier ~10000ms estimate — confirm on device that it's the intended grace. | `ServiceProvider.java:422` |
| 6 | Billing token → backend sync | No `syncPurchase()`/`updatePurchase()` endpoint visible; design server-side validation ourselves. | gaps §b.4 |
| 7 | Rewarded-ad reward grant | Callback body synthetic; the actual unlock hook is missing — implement explicitly. | gaps §a.3 |
| 8 | Node recycling in DFS | Confirm all 12000-iteration nodes are recycled to avoid leaks. | gaps §b.5 |
| 9 | `:as_process` IPC | Confirm command broadcast + shared-state propagation across the isolated process. | gaps §c.4 |

### 8.5 Other engineering risks

- **iOS feasibility:** ❌ no content detection; FamilyControls is parental-control-scoped and needs the Family Controls entitlement. Mitigation: ship Android-first, scope iOS to category-level restrictions (Phase 5) and set expectations in store copy.
- **Config drift:** target apps change view-ids frequently. Mitigation: server-fetched `platforms_config.json` with bundled fallback (Phase 4) so rule updates ship without an app release.
- **Battery/CPU from DFS:** 12000-iteration traversal on every event is costly. Mitigation: honor `THROTTLE_INTERVAL_MS=150` and `childNodeLimit`/`haltOnDetect`; short-circuit on Stage-1/Stage-2 before DFS.

---

## 9. Milestone checklist

**Phase 0 — Native spike**
- [ ] AccessibilityService hosted in Flutter app (`:as_process`), XML config in place
- [ ] EventChannel emits `{packageName, viewId}`; MethodChannel `pressBack()` works
- [ ] YouTube Shorts detected + dismissed on a physical device

**Phase 1 — MVP**
- [ ] `platforms_config.json` models (freezed/json_serializable) + repository (bundled)
- [ ] LegacyDetector (FINDBYID/VIEWID_RES_NAME) 3-stage search in Kotlin
- [ ] Throttle 150 / debounce 1200 / PRESS_BACK gate 1100 enforced
- [ ] Master toggle via `APP_COMMAND`; UI reflects status broadcast
- [ ] FGS notification id 1125, channel `noscroll_protection_channel`
- [ ] Prominent disclosure + accessibility-settings deep link
- [ ] Dashboard with daily block count

**Phase 2 — Plans + Pause + PIN**
- [ ] PlansEnum (BLOCK_ALL/CURIOUS/ONE_REEL/PAUSED) switchable live
- [ ] BlockingMode resolution order implemented
- [ ] Mindful pause countdown suppresses then auto-resumes
- [ ] PIN hashed in secure storage; biometric gate via `local_auth`
- [ ] ONE_REEL grace (500ms) + onKeyEvent BACK closes overlay

**Phase 3 — App + Web + Daily limit + Scheduler**
- [ ] App blocker (kill/lock on foreground), persists across reboot
- [ ] Web blocker: canonicalization + DOMAIN/EXACT/WILDCARD matching unit-tested
- [ ] Daily limit with documented local-time reset (`workmanager`)
- [ ] Scheduled blocking windows enforce automatically

**Phase 4 — Premium + Ads + Analytics + Notifications**
- [ ] `in_app_purchase` gating of `premiumExclusive`; server-side token validation
- [ ] AdMob + UMP; rewarded-ad temporary unlock that expires
- [ ] `dio` config fetch with backoff → last-good cache → bundled fallback
- [ ] Analytics events + FCM notifications wired

**Phase 5 — Hardening + iOS**
- [ ] `onTaskRemoved` + boot-receiver resurrection verified
- [ ] DeviceAdmin uninstall-protection + LOCK_SCREEN
- [ ] OEM battery-exemption + auto-start deep links
- [ ] CALIBRATION + OVERLAY detectors (hard-block grace 5000ms)
- [ ] iOS FamilyControls category restriction end-to-end (reduced scope)

**Cross-cutting**
- [ ] Dart unit + bloc_test + widget tests green in CI
- [ ] Kotlin JUnit detector tests green
- [ ] On-device manual matrix (OS × OEM × targets) passed
- [ ] All `(inferred)` items from §8.4 re-verified or explicitly documented as our own design

---

## Source evidence

- `sources/com/newswarajya/noswipe/reelshortblocker/service/accessibility/NoScrollAccessibilityService.java` (constants verified: lines 111–116, 203, 241, 367, 461, 543, 560)
- `sources/com/unity3d/services/core/di/ServiceProvider.java:422` (`SCAR_VERSION_FETCH_TIMEOUT = 5000` → hard-block grace)
- `sources/.../service/accessibility/processors/detectors/` — `LegacyDetector.findViewByIdWithId` (3-stage search, DFS cap 12000, recycling) — verified
- `resources/res/raw/platforms_config.json` (data-driven detectors; identifiers e.g. `:id/reel_player_underlay`, `:id/clips_author_username`, `:id/media_group`, `:id/reel_viewer_title`)
- `resources/res/xml/site_manager_service.xml` (service config), `resources/AndroidManifest.xml:179` (`:as_process`)
- `resources/res/raw/` (verified present): `initial_config.json`, `daily_limit_emoji_bands.json`, `curious_emojis.json`, `pause_*_emojis.json`
- Synthesis inputs: `/tmp/synth_flutterPlan.md`, `/tmp/synth_gaps.md`

## Related docs

- `01-overview.md`
- `02-native-boundary.md`
- `03-detection-engine.md`
- `04-blocking-modes.md`
- `05-plans-and-pause.md`
- `06-pin-and-biometric.md`
- `07-web-blocker.md`
- `08-app-blocker-and-scheduler.md`
- `09-daily-limit.md`
- `10-premium-billing.md`
- `11-ads-and-analytics.md`
- `12-config-sync.md`
- `13-service-runtime-and-resurrection.md`
- `14-calibration-and-overlay.md`
- `15-ios-familycontrols.md`
