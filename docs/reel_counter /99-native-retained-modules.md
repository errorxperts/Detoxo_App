# 99 · Native‑Retained Modules

> The definitive list of everything that **cannot** move to Dart and must stay native (Kotlin on Android, Swift on iOS), why, the source to port, and the channel that fronts it. This is the "what we keep native" companion to the hybrid decision in [00-OVERVIEW.md](00-OVERVIEW.md). Channel names are canonical — see [01-platform-channel-contracts.md](01-platform-channel-contracts.md).

## 1. Why these stay native
Flutter's engine renders into a single view; it cannot run inside an `AccessibilityService`, participate in another app's a11y tree, draw `TYPE_APPLICATION_OVERLAY` windows over other apps, or render Glance home‑screen widgets. These are not gaps in a package — they are architectural limits. The strategy is **port, don't rewrite**: keep the decompiled detection/overlay code byte‑for‑byte and expose a thin channel seam.

## 2. Android native‑retained inventory

| # | Module | Why no Flutter package | Source to port | Channel | iOS counterpart |
|---|---|---|---|---|---|
| 1 | **AccessibilityService detection** (foreground app, per‑app reel detectors, scroll counting) | Dart can't run in an a11y service or read the a11y tree | `services/ReelsAccessibilityService.java`; detectors `xh/{a,b,d,e}.java`, `b7/l.java`; scroll mgr `wh/x.java`; `res/xml/accessibility_service_config.xml` | `brainpal/detection` (Event), `brainpal/accessibility` (Method), `brainpal/accessibility_status` (Event) | **N/A** — use `DeviceActivityMonitor` (Screen Time) instead |
| 2 | **Block & onboarding overlay Activities** | full‑screen overlay over other apps; NFC reader‑mode in Activity | `BlockReelsOverlayActivity.java`, `PermissionStepsOverlayActivity.java`, `RatingPromptOverlayActivity.java` | `brainpal/overlay` (Method), `brainpal/overlay_events` (Event) | **Shield UI** (`ManagedSettingsUI` `ShieldConfiguration` + `ShieldActionExtension`) |
| 3 | **Floating bubble + multi‑window overlay** (bubble + leaderboard + dim, spring snap k≈14.14/ζ=0.75, flags 262664, type 2038) | no Dart multi‑window overlay or spring physics over other apps | `floating_bubble/ReelsCounterFloatingService.java`, `wo/*`, `yo/*`, `th/*` | `brainpal/overlay`, `brainpal/overlay_events` | **None** (no overlay on iOS; consider Live Activity/widget as soft substitute) |
| 4 | **Foreground service** (FGS id 9001, `FOREGROUND_SERVICE_SPECIAL_USE`, channel `reels_counter_bubble`) | hosts the overlay window; long‑lived | same as #3 | via #3 channels | **N/A** (background limited; BGTask + Live Activity) |
| 5 | **Glance home‑screen widgets** (compact 2×2 + expanded 4×2 leaderboard `RemoteViewsFactory`, pin flow, Vivo SDK 31‑33 guard) | Flutter has no home‑screen widget rendering; Glance/RemoteViews are native | `feature_widget/presentation/widget/*`, `res/xml/reels_counter_widget_*.xml` | `brainpal/widgets` (Method) + `home_widget` data conduit | **WidgetKit** (separate SwiftUI widget extension) |
| 6 | **DateChangedReceiver** (system broadcasts TIME_SET/DATE_CHANGED/TIMEZONE_CHANGED, Vivo guard) | Flutter can't receive system broadcasts | `core/receiver/DateChangedReceiver.java` | `brainpal/system_events` (Event) | `significantTimeChangeNotification` |
| 7 | **ScreenCaptureCallback** (API 34+ anti‑cheat) | no package | `MainActivity.java` (`registerScreenCaptureCallback`) | `brainpal/system_events: SCREEN_CAPTURED` | `userDidTakeScreenshotNotification` / `capturedDidChangeNotification` |
| 8 | **Device admin** (`disable-uninstall`) | no package; security feature | `res/xml/device_admin_policies.xml` + `DeviceAdminReceiver` | `brainpal/permissions` | **N/A** (no equivalent on iOS) |
| 9 | **NFC reader‑mode in overlay** (tap‑card / forehead challenges) | reader‑mode lifecycle bound to the native block Activity | `BlockReelsOverlayActivity` NFC (`feature_block_reels/nfc/*`) | `brainpal/challenges`, `brainpal/challenge_events` | `CoreNFC` (in‑app only; cannot gate the Shield in real time) |
| 10 | **Sensor unlock challenges** (step/jump/forehead/phone‑jail) | tight native sensor loops; thresholds | sensor handlers in overlay/service | `brainpal/challenges` | `CoreMotion` (in‑app challenge only) |
| 11 | **Package `<queries>` detection** (60+ social + UPI/bank apps) | Flutter can't query installed packages (Android 11+) | `AndroidManifest.xml <queries>` + `PackageManager` | `brainpal/permissions` (or `brainpal/packages`) | `canOpenURL` (limited; iOS `LSApplicationQueriesSchemes`) |
| 12 | **Pairip integrity wrapper** (`com.pairip.application.Application`) | anti‑tamper wrapper around `BrainRotApplication` | manifest `application android:name` | n/a (app‑init) | **N/A** — **OPEN QUESTION: investigate removal in Phase 0** |
| 13 | **Couchbase Lite sync** (optional, from `register_sync_user` → sync_url) | `cbl_dart`/`cbl_flutter` are heavy; may not be needed | sync setup in networking layer | `brainpal/sync` (only if kept) | Couchbase Lite iOS SDK (still a native module) — **OPEN QUESTION: REST may replace it** |
| 14 | **Play Core in‑app updates** | Android‑only API | `MainActivity` AppUpdateManager | `in_app_update` plugin or channel | **N/A** (App Store updates) |

### Notes
- #1 detection is the **highest‑risk** retained piece — guard with the golden‑event replay harness (see [module-01-reels-detection-core.md](module-01-reels-detection-core.md) §10). Keep it byte‑for‑byte.
- #2–#4 form one cohesive overlay/bubble subsystem; port together to avoid breaking the internal `BRAINROT_ACCESSIBILITY_ACTION` broadcasts (`PAUSE_MEDIA`/`PLAY_MEDIA`/`FRESH_START_CLOSED`).
- #12 (Pairip) and #13 (Couchbase) are **Phase‑0 decisions** that unblock app‑init and storage architecture respectively.

## 3. iOS native‑retained inventory (new code, not a port)

iOS blocking is a **different native implementation** behind the same Dart domain layer. There is no port of the Android detection/overlay — instead:

| iOS module | Framework | Role | Fronted by |
|---|---|---|---|
| Screen Time authorization | `FamilyControls` (`AuthorizationCenter`, `FamilyActivityPicker`) | user grants Screen Time; selects apps to limit | `brainpal/permissions` (iOS impl) |
| Usage monitoring & thresholds | `DeviceActivity` (`DeviceActivityMonitor`, `DeviceActivitySchedule`, events) | detect usage of selected apps; fire on thresholds | `brainpal/detection` (iOS impl — coarse, not per‑reel) |
| Blocking / shielding | `ManagedSettings` (`ManagedSettingsStore`, `ShieldSettings`) | apply/remove app shields | `brainpal/overlay` (iOS impl) |
| Block screen UI | `ManagedSettingsUI` (`ShieldConfiguration`) + `ShieldActionExtension` | the system Shield screen + unlock action buttons | `brainpal/overlay_events` (iOS impl) |
| Home‑screen widget | `WidgetKit` (SwiftUI) | counter widget | `brainpal/widgets` (iOS impl) + `home_widget` |
| Challenges (in‑app) | `CoreNFC`, `CoreMotion` | NFC/step/accel challenges run in‑app, then lift shield | `brainpal/challenges` (iOS impl) |

**Key fidelity caveat (document for product):** iOS `DeviceActivity` detects *app usage / time thresholds*, **not individual reels**. Per‑reel counting (the heart of BrainPal) is **not possible on iOS**. The iOS product is necessarily "limit time on these apps / shield after N minutes," not "count and block each reel." The Dart domain layer (config, stats, duels, subscription) is shared; only the detection/enforcement primitive differs.

## 4. The channel seam (summary)
All native↔Dart traffic flows through the 11 canonical channels in [01-platform-channel-contracts.md](01-platform-channel-contracts.md). The same Dart interfaces are implemented by **Kotlin** on Android and **Swift** on iOS, so feature code in Dart is platform‑agnostic; only the native implementations differ. Freeze this contract early (Phase 0) — it is the stable boundary the whole rewrite builds against.

## 5. Phase‑0 decisions gated here
1. **AccessibilityService→EventChannel feasibility spike** (make‑or‑break for the whole hybrid).
2. **Pairip wrapper** — keep / remove / replace.
3. **Couchbase vs REST** — drop Couchbase if REST delta‑sync is the real path.
4. **Freeze the platform‑channel contract.**
