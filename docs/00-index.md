# Short-Content Blocker — Flutter Implementation Blueprint

This `docs/` folder is a **complete, implementation-ready blueprint** for building a "short-form content blocker" — an app that detects and blocks Instagram Reels, YouTube Shorts, Facebook Reels, TikTok, in-app/web short video, and more — as a **Flutter** app using **flutter_bloc + Clean Architecture**.

It was reconstructed by reverse-engineering a shipped, production Android app (a native **Kotlin + Jetpack Compose** "reel/short blocker"). The blueprint captures **what the app does and how**, not its code. Everything here is rebuilt from scratch with clean naming and Dart conventions — **no original code is copied**. Where a behavior was confirmed by reading the decompiled source it is stated as fact; where a method body was obfuscated it is explicitly marked **(inferred)**.

> **Who this is for:** a developer who wants to build this feature (or the whole app) in Flutter and wants the algorithms, data schemas, API contracts, the native↔Dart boundary, and the exact pub.dev packages — without reverse-engineering anything themselves.

---

## How to read this

Legend used throughout every document:

| Symbol | Meaning |
|---|---|
| ✅ | A pub.dev package handles this in pure Dart/Flutter. |
| ⚠️ | Needs a **native** Android (Kotlin) `MethodChannel`/`EventChannel` — Flutter cannot do it alone. |
| ❌ | **Not possible on iOS** (no public API); see [15-ios-cross-platform.md](15-ios-cross-platform.md). |

**The single most important fact:** the core feature (reading another app's screen to detect a reel, then pressing back / killing / shielding it) is built on Android's **AccessibilityService** + **system overlays** + **usage stats**. These have **no pure-Dart equivalent** and **no iOS equivalent**. The app is **Android-first**; the realistic iOS product is a coarser Screen Time / FamilyControls build. Read [04-native-android-layer.md](04-native-android-layer.md) and [15-ios-cross-platform.md](15-ios-cross-platform.md) early.

### Suggested reading order

1. **Understand the system** → [01-overview-architecture.md](01-overview-architecture.md)
2. **Understand the data** → [02-detection-config-schema.md](02-detection-config-schema.md)
3. **Understand the core algorithm** → [03-detection-engine.md](03-detection-engine.md) + [04-native-android-layer.md](04-native-android-layer.md)
4. **Build it** → follow [16-implementation-roadmap.md](16-implementation-roadmap.md), pulling in feature docs (05–13) per phase, with [14-flutter-package-map.md](14-flutter-package-map.md) open beside you.

---

## Document map

| # | Document | What it covers |
|---|----------|----------------|
| 00 | **this file** | Index, legend, glossary, how-to-use. |
| 01 | [01-overview-architecture.md](01-overview-architecture.md) | Executive summary, full feature inventory, high-level architecture, Clean-Architecture layers, native↔Dart boundary overview, recommended Flutter project structure, DI (`get_it`), routing (`go_router`). |
| 02 | [02-detection-config-schema.md](02-detection-config-schema.md) | The remote `platforms_config.json` / `initial_config.json` / calibration config schemas (every field), all enums, and `freezed`/`json_serializable` Dart models. **The contract that drives detection.** |
| 03 | [03-detection-engine.md](03-detection-engine.md) | **Core.** The accessibility event loop, the verified 3-stage view-id detection algorithm, LEGACY/CALIBRATION/OVERLAY/MANUAL routing, priority/halt/couple semantics, all timing constants, block-mode execution, and the Dart-side engine design. |
| 04 | [04-native-android-layer.md](04-native-android-layer.md) | The Kotlin layer Flutter can't host: AccessibilityService config, the `MethodChannel`/`EventChannel` contracts, foreground service + resurrection, package-vs-custom trade-offs, Kotlin + Dart wrapper stubs. |
| 05 | [05-plans-pause-curious.md](05-plans-pause-curious.md) | The 4 block plans (Block-All / Curious-pomodoro / One-Reel / Paused), pause→cooldown phase math, the mindful countdown UI, and the dynamic quote/emoji content engine. |
| 06 | [06-app-and-web-blocker.md](06-app-and-web-blocker.md) | Full-app blocking (foreground monitoring, app-locker throttling) and the website blocklist (DOMAIN/EXACT/WILDCARD matching, URL canonicalization, public-suffix). |
| 07 | [07-daily-limit-scheduler.md](07-daily-limit-scheduler.md) | Daily time quota + midnight reset (with the timezone caveat), schedule windows, and `workmanager` background jobs. |
| 08 | [08-pin-lock-recovery.md](08-pin-lock-recovery.md) | PIN types (custom/date/time/OTP/device), biometrics, the escalating retry-lockout ladder, restriction scopes, and email-OTP PIN recovery. |
| 09 | [09-persistence-data-model.md](09-persistence-data-model.md) | DataStore→`flutter_secure_storage`/`hive`, Room→`drift`, the key inventory, and the cross-process state-sharing problem. |
| 10 | [10-networking-config-sync.md](10-networking-config-sync.md) | The full REST API surface (every endpoint, request/response), the `Resource<T>` pattern, config caching + bundled fallback, version gating, `dio`/`retrofit` design. |
| 11 | [11-monetization.md](11-monetization.md) | Play Billing subscriptions → `in_app_purchase`, premium gating + feature matrix, AdMob mediation → `google_mobile_ads`, UMP consent. |
| 12 | [12-analytics-notifications-resilience.md](12-analytics-notifications-resilience.md) | Local event buffer + batch upload + Firebase analytics, FCM + in-app notifications, device-admin uninstall protection, and boot/system service resurrection. |
| 13 | [13-onboarding-permissions.md](13-onboarding-permissions.md) | The onboarding funnel and the multi-permission flow (accessibility, overlay, usage-access, notifications, battery, device-admin) incl. manufacturer-specific guidance. |
| 14 | [14-flutter-package-map.md](14-flutter-package-map.md) | The master Android-mechanism → pub.dev-package table, a ready-to-paste `pubspec.yaml`, and codegen/bootstrap notes. |
| 15 | [15-ios-cross-platform.md](15-ios-cross-platform.md) | Honest iOS feasibility: why per-reel detection is impossible, what the Screen Time / FamilyControls stack can do, and the shared-domain / split-data-source architecture. |
| 16 | [16-implementation-roadmap.md](16-implementation-roadmap.md) | Phased build plan (native spike → MVP → features → monetization → hardening → iOS), testing strategy, and risks. |

---

## What the app actually does (one-page summary)

- **Data-driven detection.** A remote `platforms_config.json` defines, per app and per "platform" (e.g. `ig_reel`, `yt_shorts`, `ig_feed`), a set of **detectors**: Android resource-ids to look for (e.g. YouTube Shorts `:id/reel_player_underlay`, Instagram Reels `:id/clips_author_username`), a `detectionType` (`LEGACY` view-id, `CALIBRATION` screen-zone, `OVERLAY`, `MANUAL`, `NONE`), the allowed block modes, and tuning flags (`priority`, `haltOnDetect`, `coupleWith`, `childNodeLimit`). See [02](02-detection-config-schema.md).
- **The loop.** A foreground **AccessibilityService** receives view-tree change events, throttles to **150 ms/package**, checks the active plan, then searches the live node tree: (1) event source check → (2) `findAccessibilityNodeInfosByViewId` `[FIND]` → (3) DFS over an `ArrayDeque` capped at **12,000** nodes `[DEEP]`. On a hit it executes a **block mode**: `PRESS_BACK` (`performGlobalAction(BACK)` + haptic, rate-limited 1100 ms, debounced 1200 ms), `KILL_APP`, `LOCK_SCREEN`, or an **overlay** — with a ~10 s hard-block grace window. See [03](03-detection-engine.md).
- **Plans & self-control.** Block-All, Curious (pomodoro session→cooldown), One-Reel (allow one then overlay), and Paused (timed suspend→lockdown), plus a mindful countdown with rotating quotes/emoji. See [05](05-plans-pause-curious.md).
- **More guardrails.** Whole-app blocking, website blocklist, daily limits, schedules, a PIN lock with biometrics + email-OTP recovery, persistence, remote config sync, subscriptions + ads, analytics, push, and a permission/onboarding funnel — all documented in [06](06-app-and-web-blocker.md)–[13](13-onboarding-permissions.md).
- **Resilience.** Isolated service process, foreground notification, boot/task-removed restart, optional device-admin uninstall protection. See [12](12-analytics-notifications-resilience.md).

---

## Glossary

| Term | Meaning |
|---|---|
| **Platform** | A blockable content surface inside an app (e.g. "Instagram Reels" vs "Instagram Feed" are two platforms of one app). |
| **Detector** | A rule that finds short-content UI in the live view tree (by resource-id, content-description, screen zone, or browser URL). |
| **Detection type** | `LEGACY` (match a view resource-id), `CALIBRATION` (match a server-tuned screen region for in-app/webview where ids are absent), `OVERLAY` (cover the content), `MANUAL`, `NONE`. |
| **Block mode** | What happens on detection: `PRESS_BACK`, `KILL_APP`, `LOCK_SCREEN`, overlay, or `NONE`. |
| **Plan** | The user's active blocking strategy: Block-All / Curious / One-Reel / Paused. |
| **Calibration** | Device- and version-specific tuning fetched from the server so detection works where resource-ids aren't available. |
| **Curious mode** | Pomodoro-style allowance: watch for a session window, then a cooldown blocks. |
| **One-Reel** | Allow a single reel, then show a blocking overlay. |
| **Hard-block grace** | A short window after a kill/lock during which the service blocks aggressively without re-running full gating. |
| **AccessibilityService** | The Android system service that streams other apps' UI events and lets you act on them. The engine's foundation; ⚠️ native + ❌ no iOS equivalent. |

---

## Notes & caveats

- **Evidence basis.** Each doc ends with a *Source evidence* line citing the decompiled files it was reconstructed from. Constants (150 ms, 1200 ms, 1100 ms, 12,000 nodes, notification id 1125, etc.) were read directly from source and are reliable.
- **Inferred areas.** A few hot methods were obfuscated in the decompiled output (`onAccessibilityEvent` ordering, `processAndBlockShortContent` gating, web-detection internals, browser address-bar resource-ids, daily-reset timezone, billing token sync). These are clearly marked **(inferred)** and listed as re-verify items in [16-implementation-roadmap.md](16-implementation-roadmap.md).
- **Compliance.** Shipping an AccessibilityService on Google Play requires a qualifying use and a prominent in-app disclosure; uninstall-protection via Device Admin and overlay usage have their own policy and OEM constraints. See risks in [16](16-implementation-roadmap.md).
