# BrainPal → Flutter Migration — 00 OVERVIEW (North Star)

> **This is the entry document for the migration spec.** Read this first, then the contracts in
> [01-platform-channel-contracts.md](01-platform-channel-contracts.md) and
> [02-backend-api-contract.md](02-backend-api-contract.md), then the per-module docs. This file does
> **not** use the per-module template; it is the readable strategy and index. Every per-module doc
> follows the strict 12-section template (see [§9 Documentation index](#9-documentation-index)).

---

## 0. TL;DR — the one decision that drives everything

**BrainPal is ~70% an OS-integration app and ~30% a UI app.** Its core value — accessibility-tree
parsing of Instagram / YouTube / TikTok / Snapchat / Facebook, drawing overlay windows over *other*
apps, a foreground floating bubble counter, home-screen Glance widgets, and NFC/sensor unlock
challenges — has **no Flutter/Dart equivalent and never will**. Flutter's engine does not run inside
an Android `AccessibilityService`, does not participate in the Android a11y tree, and cannot draw
`TYPE_APPLICATION_OVERLAY` windows from Dart.

**Therefore the target is a HYBRID:**

- a **retained native Kotlin "detection / overlay core"** (ported near-verbatim from the decompiled
  APK), plus
- a **Flutter app** that owns all in-app UI + the business/data/sync layer, plus
- a small, **frozen platform-channel contract** joining the two.

> "Migrate BrainPal to Flutter" = **Flutter app shell + Dart domain/data/sync layer + a thin set of
> well-defined platform channels into a retained Kotlin native module.** Do **not** try to push
> detection logic into Dart.

**iOS reality (state it everywhere it matters):** Android-style detection, overlays, and home
widgets **do not exist on iOS**. iOS blocking must be **re-implemented on Apple's Screen Time API**
(`FamilyControls` / `DeviceActivity` / `ManagedSettings` / Shield UI) — a *different* native
implementation behind the *same* Dart domain layer. Treat iOS as a new platform feature, not a port.

---

## 1. App identity

| Field | Value (verified) |
|---|---|
| App name | **BrainPal** |
| Package | `com.brainrot.android` |
| Version | `7.1.340` (`AndroidManifest.xml` line 4) |
| Application class | `com.pairip.application.Application` (Pairip anti-tamper wrapper) → delegates to `BrainRotApplication` |
| Backend base URL | `https://api.brainpalapp.ai` (`sources/kc/x.java:80`) |
| Razorpay key (LIVE) | `rzp_live_SxX4XCM7fABMgJ` (`sources/lc/a.java:42`) |
| Deep-link hosts | `https://join.brainrotapp.ai`, `https://join.brainpalapp.ai`, `https://brainrotapp.ai`, `https://brainpalapp.ai`, scheme `brainrot://` (autoVerify App Links) |
| Cloud backup | disabled (local data only) |
| Auth model | **device-scoped** — no Firebase sign-in; `brUserId` is server-assigned from device ID |

**One-line purpose:** a digital-wellbeing app that **detects & blocks short-form video** ("reels" /
"shorts") in Instagram, YouTube, TikTok, Snapchat and Facebook, **counts scrolls**, shows **blocking
overlays** with motivational quotes + gamified **unlock challenges**, a **floating bubble counter**,
**home-screen widgets**, a **subscription paywall** (Razorpay primary, Play Billing fallback),
friend **"duels"/leaderboard**, and **backend stat sync**.

### Monitored apps (VERBATIM — `kc/a.java`, finding-01)

| Package | App |
|---|---|
| `com.zhiliaoapp.musically` | TikTok (special-cased in set `f14464a`) |
| `com.ss.android.ugc.trill` | TikTok variant (special-cased) |
| `com.google.android.youtube` | YouTube Shorts |
| `com.instagram.android` | Instagram Reels |
| `com.snapchat.android` | Snapchat Spotlight |
| `com.facebook.katana` | Facebook Reels |

> **OPEN QUESTION (carried):** finding-05 also lists `.lite` / alternate packages
> (`com.instagram.lite`, `com.facebook.lite`, `com.snap.android`). The detection set in `kc/a`
> verified above is **6 packages**. Confirm whether `.lite` variants are monitored before adding them.

---

## 2. Screen / feature inventory (one line each)

### Native-owned (Kotlin core — no in-app Flutter UI)
| Feature | One line |
|---|---|
| AccessibilityService detection | Reads a11y tree of 6 monitored apps; emits reel-detection events. |
| Block overlay (`BlockReelsOverlayActivity`) | Full-screen translucent blocker with a quote + countdown + unlock challenge. |
| Permission-steps overlay (`PermissionStepsOverlayActivity`) | Branded, per-OEM permission walkthrough; supports PiP (9:16). |
| Rating-prompt overlay (`RatingPromptOverlayActivity`) | Post-block Play Store review prompt. |
| Floating bubble (`ReelsCounterFloatingService`, FGS id 9001) | Draggable `TYPE_APPLICATION_OVERLAY` counter with spring snap + leaderboard expand. |
| Compact home widget (Glance, 2×2) | "Reels Today" count. |
| Expanded home widget (Glance, 4×2) | Count + duel leaderboard / invite CTA. |
| Unlock challenges | NFC tap-card, forehead-scan (NFC 30s), walk_steps, jump_count, phone_jail (face-down 30s), thumb_detox, scroll_count. |

### Flutter-owned (in-app screens)
| Screen | One line |
|---|---|
| Onboarding / permission steps (in-app) | Guided enablement of accessibility, overlay, notifications, battery-opt. |
| Stats dashboard / home | Today's count, per-app split, weekly chart (`DayStats`). |
| Friends list | `OneFriend` rows: status badge, invite-accepted celebration, remove/block. |
| Duel / leaderboard | Per-date friend leaderboard sorted by `rotScore`; pinned friend; per-app split detail. |
| Invite / referral | Create share link, accept invite, restore on reinstall. |
| Paywall | Monthly/Annual cards, Razorpay checkout, back-press scratch-card offer. |
| Subscription status | Plan, member-till, renewal, trial badge, cancel-with-refund survey. |
| Account & feedback | Delete data (GDPR), feedback form (2000-char), uninstall feedback, vote summary, language. |
| Settings | Counter size, large-bubble toggle, widgets toggle, language. |

---

## 3. The HYBRID architecture decision

### 3.1 Why detection / overlay / widgets stay native

These rely on Android-only OS surfaces that are **structurally unreachable from the Flutter engine**.
Verified facts that pin this decision:

- **`accessibility_service_config.xml`** (re-read & confirmed): `accessibilityEventTypes="typeAllMask"`,
  `notificationTimeout="500"`, `canPerformGestures="true"`,
  `accessibilityFlags="flagRetrieveInteractiveWindows|flagReportViewIds|flagIncludeNotImportantViews|flagDefault"`,
  `canRetrieveWindowContent="true"`, `settingsActivity="com.brainrot.android.MainActivity"`.
- **Overlay windows**: `TYPE_APPLICATION_OVERLAY` (2038; 2002 fallback), main-bubble flags **262664**,
  concurrent multi-window stack (bubble + leaderboard + dim background, `dimAmount=0.5`), spring snap
  physics `stiffness=√200 ≈ 14.14`, `dampingRatio=0.75`.
- **Foreground service**: `FOREGROUND_SERVICE_SPECIAL_USE`, FGS id **9001**, channel
  `reels_counter_bubble`.
- **Manifest** (re-read & confirmed): `SYSTEM_ALERT_WINDOW`, `FOREGROUND_SERVICE` +
  `FOREGROUND_SERVICE_SPECIAL_USE`, `NFC`, `ACTIVITY_RECOGNITION`, `DETECT_SCREEN_CAPTURE`,
  `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `RECEIVE_BOOT_COMPLETED`, `POST_NOTIFICATIONS`, `VIBRATE`,
  and **dual billing** (`com.android.vending.BILLING` + Razorpay `razorpay://com.brainrot.android`).
- App is wrapped by **`com.pairip.application.Application`** (integrity / anti-tamper).

No pub.dev package replicates concurrent multi-window overlays with these exact flags + spring
physics; `flutter_overlay_window` is **explicitly rejected as the primary overlay** (single overlay,
no multi-window, no spring physics). Glance widgets (especially the **expanded leaderboard** with a
`RemoteViewsFactory` list) have no Dart equivalent. **All of these stay Kotlin, ported near-verbatim.**

### 3.2 The seam

The native core and the Flutter app communicate **only** through the frozen platform-channel
contract in [01-platform-channel-contracts.md](01-platform-channel-contracts.md). Dart **never** sees
the a11y tree; it receives high-level detection events and sends overlay/widget/challenge commands.

```
┌──────────────────────────── Flutter (Dart) ─────────────────────────────┐
│  presentation (Riverpod)  →  domain (pure Dart use-cases / entities)     │
│                                   ↑                                       │
│                              data (dio/retrofit + drift + platform DS)    │
└───────────────────────────────────┬──────────────────────────────────────┘
                                     │  frozen platform-channel contract
                                     │  brainpal/detection, /overlay, /widgets,
                                     │  /accessibility, /permissions, /challenges,
                                     │  /system_events  (see 01-...)
┌───────────────────────────────────┴──────────────────────────────────────┐
│  RETAINED NATIVE KOTLIN CORE (android/) — ported ~verbatim                │
│  AccessibilityService + xh/* detectors · WindowManager overlays (wo/yo)   │
│  ReelsCounterFloatingService · Glance widgets · DateChangedReceiver ·     │
│  ScreenCaptureCallback · NFC/sensor challenges                            │
└───────────────────────────────────────────────────────────────────────────┘

iOS: NO detection/overlay/widget surface. Same Dart domain layer drives a
SEPARATE native impl on Apple Screen Time (FamilyControls / DeviceActivity /
ManagedSettings / Shield UI). See §6 per-module iOS strategy sections.
```

---

## 4. Recommended Flutter project structure

Clean Architecture, 3 layers + a platform bridge. `domain` is pure Dart (zero Flutter/native
imports); `data` depends on `domain`; `presentation` depends on `domain` + Riverpod. The native
bridge lives in `core/platform`, consumed only by feature datasources.

```text
brainpal/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── constants/                # MONITORED_APPS, thresholds, channel names, URLs, cutoff_days=10
│   │   ├── error/                    # Failure / Exception types
│   │   ├── network/                  # Dio client, BrUserId interceptor, SWR cache interceptor
│   │   ├── platform/                 # MethodChannel/EventChannel wrappers — THE native bridge
│   │   │   ├── detection_channel.dart        # EventChannel  brainpal/detection
│   │   │   ├── overlay_channel.dart          # MethodChannel brainpal/overlay (+overlay_events)
│   │   │   ├── accessibility_channel.dart     # MethodChannel brainpal/accessibility (+status)
│   │   │   ├── widgets_channel.dart          # MethodChannel brainpal/widgets
│   │   │   ├── permissions_channel.dart       # MethodChannel brainpal/permissions (+status)
│   │   │   ├── system_events_channel.dart     # EventChannel  brainpal/system_events
│   │   │   └── challenges_channel.dart        # MethodChannel brainpal/challenges (+events)
│   │   ├── di/                       # get_it + injectable registration
│   │   └── localization/             # intl, ARB files (migrated from strings.xml)
│   ├── features/
│   │   ├── reels_detection/          # Dart facade over EventChannel brainpal/detection
│   │   ├── overlays/                 # Dart configures + receives events; native draws
│   │   ├── counter_bubble/           # native-driven; Dart pushes state
│   │   ├── widgets_homescreen/       # home_widget data conduit + native Glance
│   │   ├── permissions_onboarding/
│   │   ├── duel_friends/
│   │   ├── invite_referral/
│   │   ├── subscription/
│   │   ├── account_feedback/
│   │   └── stats_dashboard/
│   │       └── (each feature)
│   │           ├── domain/      # entities, repository interfaces, use_cases  (pure Dart)
│   │           ├── data/        # dtos (freezed), datasources (remote/local/platform), repo impl
│   │           └── presentation/ # riverpod providers/notifiers, screens, widgets
│   └── shared/                    # drift db, freezed base types, widgets
│
├── android/
│   └── app/src/main/kotlin/com/brainpal/native/
│       ├── accessibility/   # ReelsAccessibilityService + b7/l, wh/x (ScrollManager), xh/{a,b,d,e}  (PORTED)
│       ├── overlay/         # wo/*, yo/* WindowManager bubble + BlockReels/PermissionSteps/Rating activities
│       ├── widget/          # Glance widgets + receivers (compact + expanded leaderboard)
│       ├── challenges/      # NFC reader-mode, accelerometer, pedometer challenge engines
│       ├── receivers/       # DateChangedReceiver, BootReceiver, ScreenCaptureCallback
│       └── channels/        # MethodChannel/EventChannel handlers ↔ Flutter (the seam)
│
└── ios/
    └── Runner/ScreenTime/   # LATER PHASE — FamilyControls / DeviceActivity / ManagedSettings / Shield
                             # NO equivalent to Android detection/overlay/widgets.
```

---

## 5. State management justification (Riverpod) + package table

### 5.1 Why Riverpod v2

- The app is **stream-heavy**: the decompiled bubble service launches **~16 coroutine collectors**,
  the detection pipeline uses Kotlin `Flow`/`Channel`, and Glance widgets are reactive. Riverpod's
  `StreamProvider` / `AsyncNotifier` is the cleanest 1:1 mapping for Kotlin `StateFlow`/`Flow` and
  for the EventChannels coming off the native core.
- Riverpod's compile-safe DI removes a service locator from the presentation layer; we still use
  `get_it` + `injectable` at the **data/platform boundary** for non-widget singletons (repositories,
  the native bridge, Dio).
- `ref.invalidate` / `ref.watch` cleanly model the "refresh UI after WorkManager sync" callback
  (the `h0.a()` pattern in `FriendsUpdateWorker`).
- Rejected alternatives: Provider (too manual), Bloc (event-class ceremony fights the stream model),
  GetX (not advisable for a long-lived rewrite).

**Pairing rule:** Riverpod for presentation; `get_it` + `injectable` for data/platform singletons.
Do **not** mix two DI systems in the widget tree.

### 5.2 Curated package table (concern → package → notes)

| Concern | Package(s) | Notes |
|---|---|---|
| State | `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator` | Primary state + DI in presentation. |
| DI (non-UI) | `get_it`, `injectable` | Repositories, native bridge, Dio at data/platform boundary. |
| Networking | `dio`, `retrofit`, `dio_cache_interceptor`, `pretty_dio_logger` | `retrofit` gives Retrofit-parity codegen for `BrainRotStatsApiService`. |
| SWR/HTTP cache | `dio_cache_interceptor` (custom) | Honor `X-Cache`, `X-Cache-TTL` (10/30/86400), `X-Cache-Type` (swr/standard), `X-Skip-SWR`, MD5 keys. |
| JSON / models | `freezed`, `json_serializable`, `json_annotation` | Match **exact** `@SerializedName` keys (snake_case). |
| Local DB | `drift` | Room→drift. Recreate exact schemas, composite PKs, 2 migration keys. |
| Key-value prefs | `shared_preferences` | Sync timestamps, `language_code`. NOT for typed pref tables (keep those in drift to mirror `user_pref_*`). |
| Secure storage | `flutter_secure_storage` | Couchbase sync creds (`username`/`password`/`sync_url`); never log. |
| Background jobs | `workmanager` | Wraps native WorkManager; keep daily/6h/30min cadences + exact clock-times. |
| Local notifications | `flutter_local_notifications` | **7 channels, exact IDs** (see §7). |
| Push | `firebase_messaging`, `firebase_core` | FCM type routing via **string equality** (not hashCode). |
| Analytics | `firebase_analytics` | Event-name parity. |
| Remote config | `firebase_remote_config` | paywall_variant, feature flags. |
| Deep links | `app_links` + `go_router` | Domains + `brainrot://`; `notification_source` param. **NOT Firebase Dynamic Links** (sunset). |
| Billing (primary) | `razorpay_flutter` | Razorpay live flow; order polling re-implemented in Dart. |
| Billing (fallback) | `in_app_purchase` | `PLAY_STORE` enum path; keep, backend supports it. |
| Share | `share_plus` | Invite link sharing. |
| Home widget | `home_widget` | **Data conduit only**; Glance layout stays native. |
| Sensors | `sensors_plus`, `pedometer` | Step / accelerometer challenges (native fallback likely). |
| NFC | `nfc_manager` | Tap-card / forehead-scan; reader-mode lifecycle likely via channel. |
| Permissions | `permission_handler` | notification/sensor/NFC runtime grants. **NOT for accessibility** (use channel). |
| Device info | `device_info_plus` | manufacturer/model for per-OEM permission UI; persistent device id. |
| Package info | `package_info_plus` | fresh-start version detection. |
| i18n | `intl`, `flutter_localizations` | Date formats (`yyyy-MM-dd`), strings.xml → ARB. |
| Haptics | `vibration` | Bubble/challenge haptics. |

**Explicitly rejected:** `flutter_overlay_window` as the primary overlay (cannot do multi-window +
spring physics); Firebase Dynamic Links (deprecated/sunset).

---

## 6. Android → Flutter capability verdict table (complete)

Legend — **PKG** = pub.dev package as-is · **DART+CHANNEL** = thin platform channel over retained
native · **KEEP-NATIVE** = substantial Kotlin module, ported, no viable Dart port · **WRITE-PLUGIN**
= no good package, author custom native.

| Capability (Android) | Verdict | Flutter pkg / channel | Notes / risk |
|---|---|---|---|
| AccessibilityService reel detection (`typeAllMask`, `getRootInActiveWindow`, BFS ≤1500 nodes, `xh/*` detectors, view-ID match) | **KEEP-NATIVE** | EventChannel `brainpal/detection` | **HIGHEST risk.** Port `ReelsAccessibilityService` + `b7/l`, `wh/x`, `xh/{a,b,d,e}` verbatim. Dart never sees the tree. |
| Accessibility enable/status query | **DART+CHANNEL** | `brainpal/accessibility` (+`accessibility_status`) | `Settings.Secure enabled_accessibility_services`. `permission_handler` cannot do this. |
| Multi-window overlays (`TYPE_APPLICATION_OVERLAY` 2038, flags 262664, dim 0.5, spring √200/0.75) | **KEEP-NATIVE** | `brainpal/overlay` (+`overlay_events`) | HIGH. Bubble + leaderboard + dim stack; block activities stay native. |
| Floating bubble FGS (`FOREGROUND_SERVICE_SPECIAL_USE`, id 9001, channel `reels_counter_bubble`) | **KEEP-NATIVE** + PKG | native service; `flutter_local_notifications` creates channel | MED. Channel must be created at app startup with matching ID. |
| Home-screen Glance widgets (compact 2×2 + expanded 4×2 leaderboard, Vivo guard, pin flow) | **KEEP-NATIVE** + PKG | `home_widget` (data conduit) + `brainpal/widgets` | HIGH (expanded list = native `RemoteViewsFactory`). |
| Razorpay checkout (LIVE key, order polling 300000ms) | **PKG** | `razorpay_flutter` | MED. Re-implement `setupSubscription`→`checkOrderStatus` polling in Dart. |
| Play Billing | **PKG** | `in_app_purchase` | LOW. Fallback path (`PLAY_STORE` enum). |
| FCM (5 message types) | **PKG** | `firebase_messaging` | MED. Replace hashCode switch with **string equality**. |
| WorkManager (11–12 workers, daily/6h/30min, 03:00/23:45/midnight) | **PKG** (+CHANNEL) | `workmanager` | MED. Calendar math in Dart `DateTime` (TZ-aware); `PermissionMonitorWorker` checks via channel. |
| Deep links (App Links autoVerify, 4 hosts, `brainrot://`) | **PKG** | `app_links` + `go_router` | LOW. Keep `/.well-known/assetlinks.json` on backend. |
| Date/time-change broadcasts (`TIME_SET`/`DATE_CHANGED`/`TIMEZONE_CHANGED`, Vivo guard) | **DART+CHANNEL** | `brainpal/system_events` | LOW. Flutter can't receive system broadcasts; keep native receiver, forward to Dart. |
| Screen-capture detection (API 34+ `ScreenCaptureCallback`) | **DART+CHANNEL** | `brainpal/system_events` (`SCREEN_CAPTURED`) | LOW. No package; thin callback → analytics. |
| NFC reader-mode (tap-card / forehead-scan in overlay) | **PKG → DART+CHANNEL** | `nfc_manager`; `brainpal/challenges` | MED. Reader-mode tied to native block Activity lifecycle. Post-MVP feature flag. |
| Sensors (step counter, accelerometer hold-steady) | **PKG** (+CHANNEL) | `pedometer`, `sensors_plus`; `brainpal/challenges` | MED. Thresholds must be re-derived; OEM variance. |
| Battery-opt exemption / Doze | **DART+CHANNEL** | `brainpal/permissions` | LOW. `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. |
| Room (2 DBs) | **PKG** | `drift` | LOW. Exact schemas/PKs + 2 migration keys. |
| Retrofit/OkHttp + SWR disk cache | **PKG** + custom | `dio` + `retrofit` + `dio_cache_interceptor` | MED. Honor `X-Cache*` / `X-Skip-SWR`. |
| Couchbase Lite sync (`register_sync_user`) | **DART+CHANNEL** / fork | `cbl_dart` (heavy) OR drop for REST delta-sync | **Architectural fork** — decide in Phase 0. |
| Glance ActionTrampoline / widget pin | **KEEP-NATIVE** + PKG | `home_widget` `requestPinWidget` + `brainpal/widgets` | LOW–MED. |
| Pairip wrapper (`com.pairip.application.Application`) | **KEEP-NATIVE / investigate** | n/a | MED. Integrity wrapper; may be droppable. Phase 0. |
| Vibration | **PKG** | `vibration` | LOW. |

**No good Flutter package (must be authored/retained native):** AccessibilityService detection;
multi-window WindowManager overlays + spring physics; Glance widgets (esp. expanded leaderboard);
`ScreenCaptureCallback`; system date-change broadcast; NFC reader-mode-in-overlay; battery-opt /
accessibility status queries. **All stay Kotlin.**

---

## 7. Cross-cutting verified constants (load-bearing)

These are referenced by multiple modules; keep them in `core/constants`. All re-read from source.

- **Foreground service:** FGS id `9001`; notification channel `reels_counter_bubble`
  ("Shorts Counter" / "Counting your shorts scrolls").
- **Notification channels (7, exact IDs):** `general` (DEFAULT/3), `firebase_message` (MAX/4),
  `foreground_service` (LOW/2), `battle_result` (MAX/4), `analytics_events` (LOW/2),
  `offer_countdown` (MAX/4), `permission_alert` (MAX/4). Mismatched IDs ⇒ silent notifications.
- **Overlay:** `TYPE_APPLICATION_OVERLAY`=2038 (fallback 2002); main bubble flags **262664**;
  `dimAmount`=0.5; spring `stiffness=√200≈14.14`, `dampingRatio=0.75`; gravity 51 (top|center_h);
  width `-1` (full) / `-2` (auto); snap threshold `5.0f`.
- **Accessibility:** `notificationTimeout=500ms`; `typeAllMask`; `canPerformGestures=true`;
  flags `flagRetrieveInteractiveWindows|flagReportViewIds|flagIncludeNotImportantViews|flagDefault`.
- **Detection:** BFS cap **1500 nodes**; YouTube right-bound threshold **0.75 × screen width**;
  Y-cluster merge within **10px**; YouTube handle regex `@([A-Za-z0-9_.\-]{3,30})`.
- **Workers / scheduling:** reels prune `cutoff_days=10`, runs **03:00**; heartbeat **23:45**;
  device-impact analytics at **midnight** (`+86400000ms`); `PermissionMonitorWorker` **6h** periodic
  (`21600000ms`); `FriendsUpdateWorker` one-time 30min delay / 5min flex;
  config + scroll sync daily(24h, 5min delay) and one-time(0ms, 1min backoff).
- **Billing:** Razorpay key `rzp_live_SxX4XCM7fABMgJ`; checkout polling timeout **300000ms**;
  `BrainPalPaymentMethod` ∈ {`PLAY_STORE`, `RAZORPAY`}; subscription states {PENDING,
  ACTIVATION_IN_PROGRESS, ACTIVE, ACTIVATION_FAILED, CANCELLED, HALTED, NONE}; order states
  {PENDING, COMPLETED, FAILED, CANCELLED}.
- **Rate limits (`kc/a.java`):** `BACK_PRESS_YEARLY_OFFER_BUFFER_MINUTES`=60 (default);
  `BLOCK_REELS_MIN_COOLDOWN_MINS`=30 (default); `BLOCK_REELS_MIN_WINDOW_MINS`=from config.
- **Assets:** `mindful_timer_quotes.json` → key `quotes` → **50 quotes** (re-verified; the
  architect synthesis said 52 — **use 50**).
- **Feedback:** 2000-char limit; screenshot poll **20 retries × 500ms = 10s**.
- **FCM types (use string equality, not Java hashCode):** `friend_removed` (-893629505),
  `config_changed` (-146003273), `sync_required` (678756547), `invite_accepted` (1587248157).
- **Migration keys:** `REELS_EVENTS_TO_APP_SPLIT` (`reels_events_to_app_split_v1`),
  `RE_REGISTER_FOR_APP_SPLIT` (`re_register_for_app_split_v1`).
- **Room schema hashes:** BrainRotRoomDatabase v1 `5155f408ed131dc24809c68983195e33`;
  UserPrefDatabase v1 `907e7765e4bd8c9b7f05925ea0bfc038`.

> Constants are the contract. Before coding any of the above, re-read it from the cited source and
> confirm against the per-module doc (per the project writing rules).

---

## 8. Glossary

| Term | Meaning |
|---|---|
| **Reel** | A short-form video (Instagram Reel / YouTube Short / TikTok / Snapchat Spotlight / Facebook Reel) detected by the AccessibilityService parsing the on-screen node tree. |
| **Scroll event** | One `ReelsScrollEvent` row (`androidDeviceId`, `brUserId?`, `eventTimestamp` ms, `appId`, `viewDurationMillis`) logged when the user advances to a new reel; debounced by the 500ms a11y coalescing window + `ReelsScrollManager` state. |
| **Split** | Per-app aggregation of reels for a given day: `DailyReelsAppSplit`, composite PK `(androidDeviceId, statsDate, appId)`, fields `displayName`, `reelCount`, `viewDurationMs`, `lastSyncedReelCount`. |
| **Duel** | A daily head-to-head comparison between the user and a friend on a `statsDate`, comparing `reelCount` and `rotScore`. Driven by the `/stats/api/v1/duel/*` endpoints. |
| **Rot score** | `rotScore` (int), a server-computed ranking score; **higher = worse** (more "brain rot"). Used to rank the leaderboard. |
| **Hard block** | Full block of reel access while `hardBlockValidTill` is in the future — no scrolling allowed; the AccessibilityService keeps the block overlay up. |
| **Cooldown** | `cooldownTimeInMillis` — the duration of a block cycle; after the allowance is spent, reels stay blocked until the cooldown elapses (`blockStartTimestamp + cooldownTimeInMillis`). |
| **Window** | The allowance time window — `reelsAllowedCount` reels are permitted per `reelsAllowedValidForMillis`; a secondary throttle independent of cooldown cycles. (`BLOCK_REELS_MIN_WINDOW_MINS` is the min-window floor.) |
| **Pinned friend** | A friend (`pinnedFriendBrUserId` in `UserBlockingConfig` / `BlockReelsState`) chosen for focused duel comparison; surfaced on the leaderboard and widget. The inviter becomes the invitee's pinned friend on accept. |
| **brUserId** | Server-assigned user identifier returned by `POST /stats/register_sync_user`; **device-scoped** (no Firebase sign-in). Sent on essentially every API call and stored in `UserBlockingConfig`. |
| **SWR** | Stale-While-Revalidate HTTP caching driven by response headers `X-Cache: true`, `X-Cache-TTL` (10/30/86400s), `X-Cache-Type` (`swr`/`standard`); `X-Skip-SWR` forces a fresh fetch; disk cache keyed by MD5 of request. |

Additional terms: **Fresh start** (one-per-upgrade onboarding signal, throttled by
`fresh_start_last_shown_day`), **back-press offer** (scratch-card discount shown on app exit, with
`offer_countdown` expiry notification), **mindful timer** (the 50-quote bank shown during a block),
**Vivo guard** (widgets/receivers disabled on Vivo SDK 31–33 to avoid OEM crashes).

---

## 9. Migration sequencing plan (phased, risk-first)

Order is deliberately **"de-risk the irreplaceable native core before building any Flutter UI."**
Building dashboards first proves nothing.

### Phase 0 — Spike & contracts *(highest risk first)*
- **Hybrid feasibility spike (make-or-break):** stand up a Flutter app embedding the ported
  `ReelsAccessibilityService`; prove the EventChannel `brainpal/detection` delivers reel events into
  Dart on a real device while the native bubble still draws. If this fails, reconsider the project.
- **Investigate the Pairip wrapper** (`com.pairip.application.Application`) — removable / replaceable?
- **Decide the Couchbase fork:** is `register_sync_user`/`sync_url` actually exercised, or is REST
  delta-sync the real path? Changes the whole storage/sync architecture.
- **Freeze the platform-channel contract** ([01-...](01-platform-channel-contracts.md)) — the seam.

### Phase 1 — Native core retained + bridged
- Port (don't rewrite) into `android/`: AccessibilityService + detectors; overlay services + block
  activities; foreground bubble service; Glance widgets; DateChangedReceiver; ScreenCaptureCallback;
  NFC/sensor challenge engines.
- Wire each to its channel. Goal: **byte-for-byte behavioral parity** of detection + overlay with
  Flutter merely hosting. Keep analytics + WorkManager native temporarily.

### Phase 2 — Data & domain layer in Dart
- Drift schemas: `user_blocking_config`, `daily_reels_app_split` (composite PK), `reels_events`,
  `user_pref_{boolean,long,string}`, `migration_status`, `app_installation_history`,
  `permission_logs`, invite tables (`invite_links`, `pending_invites`). Recreate **both** migration
  keys + schema hashes.
- Freezed DTOs with **exact** `@SerializedName` parity (Sync request/response, deltas,
  `DuelCountResponse`, `BlockReelsState`, …).
- Dio + retrofit client; BrUserId interceptor; SWR cache interceptor.
- Use-cases: **blocking-state machine** (pause → hard-block → allowance/cooldown precedence), stats
  rollup, delta-sync merge (**server-timestamp-wins**).
- WorkManager schedules via the `workmanager` plugin with exact cadences/constants.

### Phase 3 — Flutter UI *(the actual "rewrite")*
- Compose→Flutter screens: stats dashboard, friends/duel leaderboard, invite, paywall, subscription
  status, account/feedback, onboarding/permission-steps (in-app parts), settings, i18n.
- Riverpod over the domain layer; go_router deep-link routing; FCM type routing; notification
  channels; Razorpay + in_app_purchase flows.

### Phase 4 — Hardening & parity validation
- On-device matrix testing (golden-event replay, overlay side-by-side capture, blocking-state
  enumeration, delta-sync two-device, DST/timezone, OEM/Doze survivability, FCM type parity, billing
  dual-path + restore). Threshold re-tuning (sensors, scroll velocity). Vivo guard.

### Phase 5 — iOS *(separate track, scoped down)*
- **Reality check:** Android-style detection/overlays/widgets do **not** exist on iOS. iOS BrainPal
  offers Screen Time–based blocking (`FamilyControls`/`DeviceActivity`/`ManagedSettings`/Shield UI),
  a **different** native impl behind the same Dart domain layer. New feature, not a port.

**Riskiest pieces, addressed earliest:** (1) AccessibilityService bridge feasibility, (2) multi-window
overlay parity, (3) Pairip wrapper, (4) Couchbase-vs-REST sync decision — all Phase 0–1. The single
biggest existential threat is **detection-accuracy parity**, so keep that code verbatim and guard it
with a **golden-event replay harness**.

---

## 10. Documentation index

`docs/migration/` — three cross-cutting files + one per module. Every per-module doc follows the
**identical 12-section template** (Purpose & scope · Migration verdict · Business logic & algorithms ·
Data models · Android→Flutter map · iOS strategy · Platform-channel surface · State & DI · User flows ·
Parity risks & validation · Open questions · Migration checklist).

| File | Module | Verdict | Source findings |
|---|---|---|---|
| [00-OVERVIEW.md](00-OVERVIEW.md) | *(this file — north star)* | — | synthesis + all 13 |
| [01-platform-channel-contracts.md](01-platform-channel-contracts.md) | Platform-channel contract (the seam) | — | 01, 02, 03, 04, 13 |
| [02-backend-api-contract.md](02-backend-api-contract.md) | Backend API, DTOs, headers, SWR, auth | — | 05, 07, 08, 10 |
| [module-reels-detection-core.md](module-01-reels-detection-core.md) | Reels detection / scroll counting | KEEP-NATIVE | 01 |
| [module-overlays-floating-bubble.md](module-02-overlays-floating-bubble.md) | Block overlays + floating bubble | KEEP-NATIVE | 02 |
| [module-widgets-homescreen.md](module-03-widgets-homescreen.md) | Glance home-screen widgets | KEEP-NATIVE + PKG | 03 |
| [module-permissions-onboarding.md](module-04-permissions-onboarding.md) | Permissions + onboarding | DART+CHANNEL | 04 |
| [module-duel-friends-stats.md](module-05-duel-friends-stats.md) | Duels / friends / leaderboard / stats | DART+CHANNEL | 05 |
| [module-subscription-billing.md](module-06-subscription-billing.md) | Paywall / Razorpay / Play Billing | DART+CHANNEL | 06 |
| [module-invite-referral.md](module-07-invite-referral.md) | Invite / referral / deep links | DART+CHANNEL | 07 |
| [module-account-feedback.md](module-08-account-feedback.md) | Account / feedback / GDPR delete | DART+CHANNEL | 08 |
| [module-core-data-storage.md](module-09-core-data-storage.md) | Drift schemas / migrations / prefs | PURE-DART | 09 |
| [module-networking-sync.md](module-10-networking-sync.md) | Delta-sync engine / SWR / Couchbase fork | DART+CHANNEL | 10 |
| [module-workers-background.md](module-11-workers-background.md) | WorkManager + broadcast receivers | DART+CHANNEL | 11 |
| [module-messaging-app-shell.md](module-12-messaging-app-shell.md) | FCM / app init / MainActivity / channels | DART+CHANNEL | 12 |
| [99-native-retained-modules.md](99-native-retained-modules.md) | Inventory of everything staying Kotlin + why | KEEP-NATIVE | 01, 02, 03, 13 |

---

## 11. Top open questions (carried forward; full lists live in each module doc)

1. **Blocking-state precedence** — exact order of `blockPauseExpiryTime` vs `hardBlockValidTill` vs
   `reelsAllowedCount`/`cooldownTimeInMillis`/`reelsAllowedValidForMillis`. Wrong order ⇒ users
   blocked/unblocked incorrectly. (finding-09, finding-10)
2. **Couchbase vs REST** — is `register_sync_user`/`sync_url` actually used? Architectural fork. (10)
3. **Pairip wrapper** — can `com.pairip.application.Application` be removed/replaced? (12)
4. **`statsDate` format** — confirmed assumed `yyyy-MM-dd`; verify against backend. (09, 10)
5. **`rotScore` direction** — assumed higher = worse; confirm leaderboard sort. (05)
6. **`.lite` packages** — are `com.instagram.lite` / `com.facebook.lite` / `com.snap.android`
   monitored, or only the 6 in `kc/a`? (01, 05)
7. **`DailyReelsAppSplit` conflict resolution** — `INSERT OR REPLACE` overwrites; confirm it should
   overwrite (not SUM). (09)
8. **Razorpay product IDs / pricing / trial duration** — not in the decompile; backend/RemoteConfig
   driven. (06)

---

### Bottom line

Don't "rewrite BrainPal in Flutter." **Wrap a retained Kotlin detection/overlay core in a Flutter
app**, move the data/domain/sync layer and all in-app screens to Dart (Riverpod + drift +
dio/retrofit), and bridge them through a small, frozen platform-channel contract. De-risk the
AccessibilityService bridge, the multi-window overlay, the Pairip wrapper, and the
Couchbase-vs-REST decision in Phase 0–1; everything else is conventional Flutter work. On iOS, there
is no detection/overlay/widget surface — re-implement blocking on Apple's Screen Time API behind the
same Dart domain layer.
