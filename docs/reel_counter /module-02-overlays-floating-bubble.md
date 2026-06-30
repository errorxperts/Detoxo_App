# Module: Overlays, Floating Bubble & Unlock Challenges

## 1. Purpose & scope
Everything drawn **over other apps**: the three blocking/onboarding/rating overlay Activities, the draggable foreground **floating bubble counter**, and the gamified **unlock challenges** that gate dismissing a block. **Owns:** WindowManager overlay rendering, drag/spring physics, the cooldown timer + mindful quotes, and challenge mechanics. **Does NOT own:** detection (see [module-01-reels-detection-core.md](module-01-reels-detection-core.md)) or the allow/block decision (see [module-09-core-data-storage.md](module-09-core-data-storage.md)).

## 2. Migration verdict
**KEEP‑NATIVE (Android, Kotlin) + DART config.** Flutter cannot draw `TYPE_APPLICATION_OVERLAY` windows over other apps, run the multi‑window bubble+leaderboard+dim stack, or host the foreground overlay service from Dart. Port `BlockReelsOverlayActivity`, `PermissionStepsOverlayActivity`, `RatingPromptOverlayActivity`, and `ReelsCounterFloatingService` (+ `wo/*`, `yo/*`, `th/*`) near‑verbatim to Kotlin; Flutter sends config (quote, app id, mode, timer) and receives taps/dismiss/challenge‑results over channels. `flutter_overlay_window` is **rejected** as primary (single overlay; no spring physics, no multi‑layer). **iOS:** none of this exists — block UI is Apple's **Shield** screen via Screen Time API (see §6).

## 3. Business logic & algorithms (load‑bearing)

### 3.1 Overlay windows (verbatim)
- Window type `TYPE_APPLICATION_OVERLAY` = **2038** (API 26+), fallback **2002**.
- Main bubble flags = **262664** (`LAYOUT_IN_SCREEN | NOT_TOUCHABLE? | NOT_FOCUSABLE | LAYOUT_NO_LIMITS | WATCH_OUTSIDE_TOUCH | ALT_FOCUSABLE_IM`), gravity **51** (`top|center_horizontal`), width `-1` (full) or `-2` (wrap), height `-2`.
- Background/dim overlay `dimAmount = 0.5`; optional bottom bar = 1/5 screen height, color `#0D0D0D`.
- Overlay Activities lock **portrait**, navigation bar `#0D0D0D`; `setFinishOnTouchOutside(false)` on rating prompt.
- Foreground service (`ReelsCounterFloatingService`): FGS **id 9001**, channel **`reels_counter_bubble`** ("Shorts Counter" / "Counting your shorts scrolls"). `onCreate` fast‑fails via `Settings.canDrawOverlays()`; stops self if denied.

### 3.2 Drag‑to‑snap spring physics (verbatim)
```
on ACTION_DOWN: record bubble (x,y) + raw touch (rawX,rawY)
on ACTION_MOVE: delta = raw - start; clamp y∈[0, screenH - bubbleH]; WindowManager.updateViewLayout
on ACTION_UP : snapTarget = (centerX < screenW/2) ? 0 : screenW - bubbleW
               SpringAnimation(stiffness = sqrt(200.0) ≈ 14.14, dampingRatio = 0.75)
               Choreographer frame callbacks animate x → snapTarget
               if snapDistance > 5.0f: show bottom background overlay
```

### 3.3 Bubble display modes & milestones (verbatim enums)
- Display mode `th/h`: `NormalCount(0)`, `CountPulse(1)`, `FriendBigCard(2)`, `RaceStrip(3)`.
- Milestone variant `th/k` (string values): `auto`, `invite_friend`, `battle`, `guilt_1` (>100), `guilt_2` (>200), `night` (21:00–04:00), `fresh_start`.
- Block status `td/d`: `NOT_SETUP(0)`, `BLOCK_ACTIVE(1)`, `REELS_ALLOWED(2)`, `REELS_LIMIT_REACHED(3)`, `REELS_EXHAUSTED(4)`, `PAUSED(5)`.
- Milestone celebration throttle: prefs `last_celebrated_milestone` (per app) + `last_celebrated_milestone_day` (daily) prevent repeat UI.
- Service launches ~16 coroutine collectors observing count/variant/mode/friend data → maps to Riverpod stream providers + a native StateFlow→EventChannel bridge.

### 3.4 Block overlay + cooldown quotes
- On block, `BlockReelsOverlayActivity` shows a random quote from `assets/mindful_timer_quotes.json` (key `quotes`, **50 items** — re‑verified; an earlier note said 52, use 50). Quote theme: "Urges have a lifespan of 90 seconds…" → implies a ~90s timer per pause.
- Internal broadcasts `BRAINROT_ACCESSIBILITY_ACTION`: `PAUSE_MEDIA` / `PLAY_MEDIA` / `FRESH_START_CLOSED`; `PAUSE_MEDIA_DONE`; extra `EXTRA_FRESH_START_SHOULD_RECORD`. Dedup via extra `source_app_id`.

### 3.5 Unlock challenges (verbatim option set)
`nfc_unlock_challenge_options = thumb_detox, nfc, forehead_scan, phone_jail, walk_steps, jump_count, scroll` (strings `block_reels_nfc_*`). Mechanics:
| Challenge | Mechanic | Sensor/API | Flutter approach |
|---|---|---|---|
| `nfc` (tap_card) | scan an NFC tag/card | `NfcAdapter.enableReaderMode` (in overlay Activity) | `nfc_manager` or CHANNEL (reader‑mode tied to native Activity) |
| `forehead_scan` | hold phone to forehead ~30s (hold‑steady) | accelerometer / NFC | `sensors_plus` (variance threshold) |
| `phone_jail` | put phone away for a duration | timer + screen state | timer + `screen_state` |
| `walk_steps` | walk N steps | `TYPE_STEP_COUNTER` | `pedometer` |
| `jump_count` | jump N times | accelerometer peaks | `sensors_plus` |
| `thumb_detox` | hold thumb on screen | touch pressure/duration | Flutter gesture (in overlay) |
| `scroll` | slow controlled scroll (velocity ≤ ~100px/s) | accessibility node monitor | gesture velocity check |
NFC unlock options are gated by remote config / allowlist; treat as feature‑flagged post‑MVP.

## 4. Data models
Intent extras / config payloads (verbatim):
- `BlockReelsOverlayActivity`: `source_app_id`, launch_mode, `milestone_variant`, `count_today`.
- `PermissionStepsOverlayActivity`: `extra_permission_type` (enum string).
- `RatingPromptOverlayActivity`: `source` (enum), `count_today` (int, def 0), `all_time_count` (int, def=count_today), `friend_age_hours` (long, `-1L` = null).
Prefs: `COUNTER_SIZE` (string), `CREATOR_LARGE_BUBBLE_ENABLED` (bool). Dart side models these as a `BlockOverlayConfig` freezed class passed over the channel.

## 5. Android deps → Flutter map
| Android API | Verdict | Flutter | Notes |
|---|---|---|---|
| WindowManager overlay (2038, flags 262664, multi‑layer) | KEEP‑NATIVE | `brainpal/overlay` channel | no Dart equivalent |
| Foreground service (FGS 9001) | KEEP‑NATIVE | hosts overlay | notif channel via `flutter_local_notifications` at startup |
| SpringAnimation (`p5.d`) | KEEP‑NATIVE | native physics | re‑tune for 60/120Hz |
| Overlay Activities | KEEP‑NATIVE | native Activities | Flutter passes config |
| `mindful_timer_quotes.json` | PKG | bundle asset, `rootBundle` | quote selection in Dart, passed to overlay |
| NFC reader‑mode | CHANNEL / `nfc_manager` | `brainpal/challenges` | lifecycle tied to overlay Activity |
| Sensors (step/accel) | PKG | `sensors_plus`, `pedometer` | challenge logic |
| Vibration | PKG | `vibration` | haptics on block/complete |
| `Settings.canDrawOverlays` | CHANNEL | `brainpal/permissions` | fast‑fail before showing bubble |

## 6. iOS strategy
**Not possible as on Android.** iOS forbids drawing over other apps and has no accessibility‑style foreground bubble. The block experience = Apple **Shield** UI (`ManagedSettingsUI` `ShieldConfiguration` + a `ShieldActionExtension`) shown by the system when a shielded app is opened, configured via `DeviceActivityMonitor`. Unlock challenges become **custom Shield action buttons**; sensor challenges (steps/accel) can still run in the main app but cannot gate the system Shield in real time — so the iOS challenge model is reduced (e.g. unlock = open app → complete challenge in‑app → lift shield via `ManagedSettings`). No floating bubble on iOS (consider a Live Activity / widget as a soft substitute). See [99-native-retained-modules.md](99-native-retained-modules.md).

## 7. Platform‑channel surface
- `brainpal/overlay` (Method, Dart→native): `showBlockOverlay(config)`, `hideOverlay()`, `updateBubble({count, mode, status})`, `setMode(variant)`, `startBubbleService()`, `stopBubbleService()`.
- `brainpal/overlay_events` (Event, native→Dart): `overlayTap`, `overlayDismiss`, `pauseRequested`, `freshStartClosed`.
- `brainpal/challenges` (Method) + `brainpal/challenge_events` (Event): start/cancel a challenge; progress/completed/failed.
Full payloads in [01-platform-channel-contracts.md](01-platform-channel-contracts.md).

## 8. State management & DI
- Native side keeps the authoritative bubble StateFlow; mirror to Dart via `brainpal/overlay_events` into a Riverpod `StreamProvider<BubbleState>`.
- `get_it`: `OverlayController` (channel facade), `ChallengeController`, `QuoteRepository` (loads the 50 quotes).
- Block decision comes from `AllowReelUseCase` (Dart, [module-09](module-09-core-data-storage.md)); result → `overlay.showBlockOverlay` via channel.

## 9. User flows
1. **Reel limit hit** `[dart]` decision → `[channel]` `showBlockOverlay({quote, sourceAppId, timerSecs})` → `[native]` overlay draws, broadcasts `PAUSE_MEDIA`.
2. **User waits/dismisses** `[native]` → emits `overlayDismiss` → `[dart]` logs analytics, updates count → `[channel]` `updateBubble`.
3. **Unlock via challenge** `[native overlay]` invokes `[channel]` `startChallenge(type)` → sensors/NFC → `challenge_events: completed` → `[dart]` lifts block (set `blockPauseExpiryTime`) → overlay hides, `PLAY_MEDIA`.
4. **Bubble drag** `[native]` spring‑snaps to edge; expand → leaderboard overlay.
5. **Fresh‑start mode** `[native]` locks bubble for a focus session; on exit logs `fresh_start_closed`.

## 10. Parity risks & validation
- **Multi‑window + spring parity:** side‑by‑side video capture of drag‑to‑edge snap (k≈14.14, ζ=0.75) and milestone transitions vs old APK; verify z‑order, dim 0.5, full vs auto width.
- **FGS survival:** bubble service survives Doze/rotation; `onConfigurationChanged` rebuild.
- **Challenge reliability:** step/accel thresholds re‑tuned per device (Samsung/Huawei pedometer differences); NFC reader‑mode across devices.
- **Quote count fix:** assert 50 quotes load (not 52).
- **Notification channel ID** matches `reels_counter_bubble`.

## 11. Open questions
- Exact cooldown timer length per quote (90s implied).
- Auto‑block trigger threshold (1st scroll vs allowance) — cross‑check [module-01](module-01-reels-detection-core.md).
- Which challenges are enabled by default vs allowlist/remote‑config gated.
- Bubble flag 262664 exact decomposition (NOT_TOUCHABLE inclusion).

## 12. Migration checklist (Phase 1)
- [ ] Port overlay Activities + `ReelsCounterFloatingService` + `wo/*`,`yo/*`,`th/*` to `android/` Kotlin.
- [ ] Implement `brainpal/overlay`, `overlay_events`, `challenges`, `challenge_events`.
- [ ] Create `reels_counter_bubble` channel at app start via `flutter_local_notifications`.
- [ ] Bundle `mindful_timer_quotes.json` (50) as asset; Dart `QuoteRepository`.
- [ ] Wire challenges (`nfc_manager`/`sensors_plus`/`pedometer`); feature‑flag NFC.
- [ ] iOS: Shield config + ShieldAction extension + in‑app challenge → `ManagedSettings` unblock.
- [ ] Parity capture vs APK (drag/snap, milestones).
