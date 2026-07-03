# Plans, Pause & Conscious

How Detoxo decides *whether* to block. The detection engine ([03-detection-engine.md](03-detection-engine.md)) answers "is this a reel?"; this layer answers "and should I act on it right now?" — via four **blocking plans**, a clock-based **Pause** window, and the **Conscious** earn-as-you-abstain time bank enforced natively.

Everything here lives under `lib/features/blocking/plans/**` (Dart) plus the Conscious accountant inside `accessibility/DetoxoAccessibilityService.kt` (native). Plan state itself is owned by the sibling `blocking/shared` feature (`AppSettings` + `SettingsCubit`), which this doc also covers because the plan state machine is where Pause/Conscious are driven.

---

## 1. The four plans

`BlockingPlan` (`lib/features/blocking/shared/domain/entities/enums.dart`) is the user's active high-level strategy. Each value carries a verbatim **wire token** used in persisted JSON and on the platform channel.

| Enum value | Wire token | User-facing label | Enforcement |
|---|---|---|---|
| `blockAll` | `BLOCK_ALL` | Block All | Every detected reel is acted on immediately (default). |
| `curious` | `CURIOUS` | **Conscious** | Native earn-as-you-abstain token bucket (see §5). |
| `oneReel` | `ONE_REEL` | One Reel | Allow one reel, then block (grace handled in the detection/overlay layer). |
| `paused` | `PAUSED` | Paused | Legacy/derived only — see §3. Never the persisted `activePlan` in the current model. |

### The `curious` / `CURIOUS` ↔ "Conscious" mapping (read this)

The **internal token is `curious` / `CURIOUS` and must stay verbatim** everywhere in code and on the wire. The **user-facing name is "Conscious."** This is a deliberate, verified split — do not rename the token to match the label.

The mapping is applied in three concrete places:

- **Dart plan enum:** `BlockingPlan.curious('CURIOUS')` — the constant and its wire string.
- **UI relabel:** the dashboard status maps `BlockingPlan.curious → 'CONSCIOUS'` (`dashboard_tab.dart` `_statusLabel`), and the session dialog / hero all read "Conscious." The turn-on/turn-off actions are `SettingsCubit.enterConscious()` / `stopConscious()`, which set/clear `BlockingPlan.curious`.
- **Native:** the accountant's active-plan token is `private const val PLAN_CONSCIOUS = "CURIOUS"` — i.e. the class is *named* "Conscious" but it matches on the `"CURIOUS"` wire string that Dart pushes.

So: **`curious`/`CURIOUS` (code/wire) = "Conscious" (everything the user sees).**

---

## 2. Plan state machine — `SettingsCubit`

`lib/features/blocking/shared/presentation/settings_cubit.dart` owns the single `AppSettings` object and is the only writer. Every mutation runs through one `_commit(next)` path that **persists locally → pushes the derived state to native → re-syncs the pause ticker**:

```dart
Future<void> _commit(AppSettings next) async {
  emit(next);
  await _settings.save(next);        // local_store
  await _engine.pushSettings(next);  // MethodChannel pushSettings
  _syncTicker(next);
}
```

Plan-relevant actions:

| Method | Effect |
|---|---|
| `setPlan(plan)` | Switch active plan; **clears any live pause** (`clearPauseSession: true`) — the user is choosing fresh. |
| `enterConscious()` | `setPlan(BlockingPlan.curious)`. Native starts a fresh empty bank (see §5.4). |
| `stopConscious()` | `setPlan(BlockingPlan.blockAll)` — Conscious always falls back to Block All. |
| `startPause({pause})` | Opens a pause window (see §3). Sets `activePlan = blockAll` up front + attaches a `PauseSession`. |
| `resumeNow()` | Ends a live pause immediately → Block All + clears the session. |

`AppSettings.activePlan` never holds `paused`. `AppSettings.fromJson` includes a **legacy migration**: any persisted `activePlan == PAUSED` is collapsed to `blockAll` on load, so an upgrade killed mid-pause can't surface a phantom permanent "Paused" plan with no live window to clear it.

---

## 3. Pause — a clock-based allow-window

Pause is **not** a plan the engine enforces; it's a temporary *suspension* of blocking modelled as a live `PauseSession` carved out of whatever plan is active.

### The `PauseSession` model

`lib/features/blocking/plans/domain/entities/sessions.dart` — a three-phase contract with verified phase math `active → cooldown → idle`:

```
startedAt ──pauseDuration──▶ pauseEnd ──cooldownDuration──▶ cooldownEnd
   │            active            │           cooldown          │   idle
```

- `phaseAt(now)` → `SessionPhase.active | cooldown | idle`.
- `remainingIn(now)` → time left in the current phase (clamped ≥ 0).
- `cooldownProgressPct(now)` → 0..100 through the cooldown window; drives the cooldown emoji band (`EMOJI_PAUSE_COUNTDOWN_COOLDOWN`).
- Serializable (`toJson`/`fromJson`) — it is a field of `AppSettings` and persists across restarts.

### Current live behaviour: no cooldown wind-down

`SettingsCubit.startPause` constructs the session with **`cooldownDuration: Duration.zero`** and `planToResume: BlockingPlan.blockAll`. So today a Pause is: *every app allowed for the chosen window, then blocking returns immediately as Block All* — the cooldown phase and its emoji band are **modelled but not exercised** by the current picker. The cooldown machinery (`cooldownProgressPct`, `EMOJI_PAUSE_COUNTDOWN_COOLDOWN`, `allowInCooldown`) is retained for a future graduated wind-down and should be treated as **planned / follow-up**, not live.

### How Pause reaches the engine (derived enforcement)

Native has no "pause plan" concept — Dart derives two values from the live session and pushes them over the ordinary `pushSettings` call (`AppSettings.effectiveNativePlan` / `nativePauseUntil`, wired in `engine_repository_impl.dart`):

| Pushed field | Value while pause is live | After the window |
|---|---|---|
| `activePlan` | `planToResume.wire` (currently `BLOCK_ALL`) | the real `activePlan` |
| `pauseUntil` | `pauseEnd.millisecondsSinceEpoch` | `0` |

Native gate (`DetoxoAccessibilityService.onAccessibilityEvent`):

```kotlin
// A live Pause window suspends ALL blocking (every app allowed) until pauseUntil.
if (System.currentTimeMillis() < store.pauseUntil) return
```

This gate is **purely clock-based**, so it holds even if the Flutter UI is dead. Pickers/defaults come from `SessionDefaults` (`lib/features/blocking/plans/domain/entities/session_defaults.dart`): slider 2–10 min in 2-min steps (`snapPauseMinutes`), default 4, `maxPauseMinutes` 10.

### Pause ticker (UI truth)

While a pause is live, `SettingsCubit` runs a 1 Hz `_ticker` whose only job is to flip UI state back to Block All and drop the session the instant `pauseEnd` passes — native already enforces this via `pauseUntil`; the ticker just keeps the banner/state honest when the app is awake.

---

## 4. Conscious — earn-as-you-abstain, at a glance

Conscious lets reels play **only while the user has banked allowance by staying off them**. It is a **token bucket**:

- **Abstaining** (off any reel-bearing app): the bank fills at `1 / earnDivisor` of elapsed time → **+1 min per 10 min** (default). Capped at **10 min**.
- **Watching** (a reel is on screen): the bank drains **1:1**.
- **Empty bank**: the reel is booted (back-press) and blocking resumes until the user earns more.

The running balance lives **natively** so it survives the Flutter UI being killed; Dart only mirrors it for display. There is **no Dart-side Conscious session** — unlike Pause, `AppSettings` holds nothing live for Conscious.

Tuning constants (`SessionDefaults`, mirrored natively):

| Constant | Value | Meaning |
|---|---|---|
| `consciousEarnDivisor` | `10` | Earn rate: `elapsed / 10` while abstaining ("1 min every 10 min"). |
| `consciousMaxBank` | `10 min` (600 000 ms) | Bank cap. |
| `consciousEarnLabel` | "1 min every 10 min" | Human-readable earn rate string. |

---

## 5. Conscious — native accountant

Enforcement lives in `accessibility/DetoxoAccessibilityService.kt`. Bank state persists in `engine/ConfigStore.kt` (SharedPreferences file `detoxo_engine_prefs`).

### 5.1 The 1 Hz accountant

A `Handler` on the main looper posts `consciousTick` every `CONSCIOUS_TICK_MS = 1000L`. It runs **only while the active plan is Conscious**:

```kotlin
private fun syncConscious() {
  val conscious = store.activePlan == PLAN_CONSCIOUS  // "CURIOUS"
  when {
    conscious && !consciousRunning -> { // start
      consciousRunning = true
      store.consciousAnchorMs = System.currentTimeMillis() // don't credit downtime
      lastReelAtMs = 0L
      consciousHandler.postDelayed(consciousTick, CONSCIOUS_TICK_MS)
      emitConsciousState()
    }
    !conscious && consciousRunning -> { /* stop + removeCallbacks */ }
    conscious -> emitConsciousState() // already running; just refresh UI
  }
}
```

`syncConscious()` is called from `reload()` (i.e. after every `pushSettings`), so entering/leaving Conscious starts/stops the accountant. On start it **re-anchors to now** so accumulated service downtime is never retroactively credited (the persisted bank carries over; only the elapsed clock restarts).

### 5.2 One accounting step

`accountConscious()` runs each tick. It computes `elapsed = now − consciousAnchorMs`, advances the anchor first (even if it then freezes), and classifies the current moment:

- **`watching`** = a reel was detected within `WATCH_STALE_MS = 2500L` (`now − lastReelAtMs < 2500`).
- **`inReelApp`** = the foreground package has reel surfaces but detection has gone quiet (paused video / non-feed overlay).
- Otherwise → **abstaining** (genuinely off reels).

Then:

```kotlin
if (!store.masterEnabled) { emitConsciousState(); return }  // freeze: no drain, no accrue

if (watching) {
  bank -= elapsed.coerceAtMost(CONSCIOUS_MAX_STEP_MS)   // drain 1:1, capped step
  if (bank <= 0L) { bank = 0L; lastReelAtMs = 0L; pressBackWithRateLimit() } // boot the reel
} else if (!inReelApp) {
  bank = (bank + elapsed / store.consciousEarnDivisor)   // accrue while abstaining
           .coerceAtMost(store.consciousMaxBankMs)        // capped at 10 min
}
// else: lingering on a reel app with no fresh detection → hold steady (no drain, no accrue)
```

Key rules:
- **Drain-step cap** `CONSCIOUS_MAX_STEP_MS = 5000L`: a delayed/coalesced tick can drain at most 5 s at once, so a stalled handler can't dump the whole bank instantly.
- **Paused-reel guard:** a reel that's on screen but not actively producing detections (`inReelApp && !watching`) neither refills the bank nor drains for free — it holds steady. Only genuine abstinence accrues.
- **Master-off freeze:** with `masterEnabled == false` the bank neither drains nor accrues; the anchor is still advanced so re-enabling can't dump a huge credit.

### 5.3 Detection-path interaction

The Conscious decision is made inside the block loop of `onAccessibilityEvent`, right after a detector matches:

```kotlin
if (store.activePlan == PLAN_CONSCIOUS && store.consciousBankMs > 0L) {
  lastReelAtMs = now   // mark "watching" so the accountant drains the bank
  return               // let the reel play
}
onDetected(pkg, platform.platformId, detector)  // bank empty → fall through to block
```

So while the bank has allowance, a matched reel simply refreshes `lastReelAtMs` and is **let through**; the accountant drains it. When the bank is empty the code doesn't touch `lastReelAtMs` and **falls through to the normal block** — a bounced reel therefore counts as abstaining, and the bank starts refilling. Note the accountant's own `pressBackWithRateLimit()` on drain-to-empty is a second boot path for the case where the bank empties *between* detection events.

### 5.4 Bank reset on entry

Entering Conscious starts a **fresh empty bank**. Dart just flips the plan; native does the reset in `channels/CommandHandler.kt` on `pushSettings`:

```kotlin
if (plan == PLAN_CONSCIOUS && store.activePlan != PLAN_CONSCIOUS) {
  store.resetConsciousBank(System.currentTimeMillis())  // bank=0, anchor=now
}
store.activePlan = plan
```

`pushSettings` also ships the tuning constants each time: `consciousEarnDivisor` and `consciousMaxBankMs` (from `SessionDefaults`). `ConfigStore` defaults them defensively (`divisor` ≥ 1 default 10, `maxBank` default 600 000 ms) so a missing push never divides by zero or uncaps the bank.

### 5.5 `consciousState` event + Dart mirror

Every tick (and on start/refresh) native posts a `consciousState` event via `ServiceEventBus`; the same snapshot answers the `consciousState` pull query. Payload (`consciousSnapshot`):

| Field | Meaning |
|---|---|
| `bankMs` | Current banked allowance (ms). |
| `maxBankMs` | Bank cap (ms). |
| `watching` | `active && a reel is on screen now`. |
| `blocked` | `active && bank <= 0` (reels blocked, must earn). |
| `active` | The Conscious plan is the active plan. |

Dart side:
- **Entity** `ConsciousState` (`plans/domain/entities/conscious_state.dart`) — `fromMap`, plus derived `banked`/`maxBank` `Duration`s, `progress` (0..1 bank fill for the ring), `hasAllowance`.
- **Cubit** `ConsciousCubit` (`plans/presentation/conscious_cubit.dart`) — subscribes to `consciousStream()` and relays each push; calls `refresh()` once at startup (`consciousCurrent()` pull) so the display is correct before the first push. **Enforcement never depends on this mirror** — the native accountant owns the bank, so a momentarily stale read self-corrects within ~1 s.

---

## 6. Native Conscious constants (companion object)

| Constant | Value | Role |
|---|---|---|
| `PLAN_CONSCIOUS` | `"CURIOUS"` | Active-plan token Conscious matches on (the verbatim wire string). |
| `CONSCIOUS_TICK_MS` | `1000L` | Accountant cadence (1 Hz). |
| `WATCH_STALE_MS` | `2500L` | A reel detected within this window still counts as "watching." |
| `CONSCIOUS_MAX_STEP_MS` | `5000L` | Max drain per tick (guards against a delayed tick emptying the bank). |
| `BACK_RATE_LIMIT_MS` | `1100L` | Min gap between back presses (shared with the block path). |

`ConfigStore` bank keys (file `detoxo_engine_prefs`): `conscious_bank_ms`, `conscious_anchor_ms`, `conscious_earn_divisor`, `conscious_max_bank_ms`.

---

## 7. The emoji-band / mindful-quote content engine

Detoxo ships a small **offline dynamic-content engine** that supplies rotating emojis (with animations) and motivational quotes for the mindful-countdown surfaces. It's the offline tier of a `ContentRepository` interface; a remote `fetchcontent` tier could layer behind the same interface later (planned / swap-in).

### 7.1 Placement model

`plans/domain/entities/emoji_band.dart`. Bundled JSON and any future remote response share one schema: a top-level `emojiSets[]`; each set has `setId`, `placementId`, `enabled`, and an `emojis[]` array of **inclusive range-bucketed** items (`rangeMin <= value <= rangeMax`, via `EmojiItem.covers`). Each item carries `emoji`, `title`, `description`, and an `animation` token.

`EmojiPlacementId` (the join key — its `wire` matches the `placementId` in the asset):

| Placement id | Wire | Bundled asset | Bucket value (domain meaning) |
|---|---|---|---|
| `planPause` | `EMOJI_PLAN_PAUSE` | `pause_emojis.json` | re-open count |
| `curiousPlan` | `EMOJI_CURIOUS_PLAN` | `curious_emojis.json` | re-open count |
| `dailyLimitHero` | `DAILY_LIMIT_HERO` | `daily_limit_emoji_bands.json` | selected daily-limit minutes |
| `pauseCountdown` | `EMOJI_PLAN_PAUSE_COUNTDOWN` | `pause_countdown_pause_emojis.json` | minutes of the pause window |
| `pauseCountdownCooldown` | `EMOJI_PAUSE_COUNTDOWN_COOLDOWN` | `pause_countdown_cooldown_emojis.json` | cooldown progress **%** (0..100) |
| `appLockSession` | `EMOJI_APP_LOCK_SESSION` | *(none — returns empty/disabled)* | — |

Asset shapes (verified counts / ranges):

| Asset | Placement | Items | Range span |
|---|---|---|---|
| `curious_emojis.json` | `EMOJI_CURIOUS_PLAN` | 11 | 0..60 |
| `pause_emojis.json` | `EMOJI_PLAN_PAUSE` | 10 | 0..30 |
| `pause_countdown_pause_emojis.json` | `EMOJI_PLAN_PAUSE_COUNTDOWN` | 11 | 0..60 |
| `pause_countdown_cooldown_emojis.json` | `EMOJI_PAUSE_COUNTDOWN_COOLDOWN` | 3 | 0..100 (percent) |
| `daily_limit_emoji_bands.json` | `DAILY_LIMIT_HERO` | 5 | 0..999999 |

Example item (`curious_emojis.json`, first band):

```json
{ "emojiId": "curious_2_0", "rangeMin": 0, "rangeMax": 5, "emoji": "🎯",
  "title": "Stay Sharp", "description": "You opened this for a reason. Don't forget it.",
  "animation": "BREATHING" }
```

### 7.2 `ContentRepository`

Interface `plans/domain/repositories/content_repository.dart`; impl `plans/data/repositories/content_repository_impl.dart` (DI singleton in `core/di/injector.dart`). It reads bundled assets **lazily + memoized**, and **degrades safely** — any parse/IO failure returns an empty *disabled* placement (`isUsable == false`) or a single fallback quote, so the countdown UI never crashes.

- `emojiPlacement(id)` → the `EmojiPlacement` (empty-disabled where no asset, e.g. `appLockSession`).
- `emojiFor(id, threshold)` → items whose inclusive range covers `threshold` (mirrors the verified `emojiForProgress`).
- `mindfulQuotes()` → the bundled `quotes[]` (**50** entries in `mindful_timer_quotes.json`) **plus 9 hard-coded paired quotes** appended in the impl (`_pairedQuotes`) → 59 total. `randomQuote()` picks one at random.

### 7.3 Animations

`plans/presentation/widgets/animated_emoji.dart` renders a glyph with one of **14** `EmojiAnimation` styles (wire tokens are the upper-case enum names in the JSON, e.g. `"BREATHING"`). `EmojiAnimation.fromWire` is case-insensitive and falls back to a calm `breathing` for unknown/extended values, so a bad server token never breaks the UI. Each style is a closed-form transform driven by one repeating controller; per-motion loop durations:

| Duration | Animations |
|---|---|
| 650 ms | `shake`, `quaking` |
| 900 ms | `flash`, `chaos` |
| 3200 ms | `lumber` |
| 2400 ms | `fly`, `slide` |
| 1800 ms (default) | `breathing`, `scanning`, `melting`, `bouncing`, `waving`, `sinking`, `glow` |

All content widgets honour reduce-motion (still glyph / plain text).

### 7.4 Mount status (accuracy note)

`ContentRepositoryImpl` is DI-registered and the widgets (`AnimatedEmoji`, `QuoteBox`) are built and reduce-motion-aware, but **they are not currently mounted on a live screen** — no presentation code calls `emojiPlacement`/`randomQuote`, and the emoji/quote assets aren't yet wired into the Pause/Conscious surfaces. The live plan surfaces today are the **`SessionDialogs`** and the **dashboard hero ring** (§8). Treat the emoji-band/quote engine as **built infrastructure awaiting a screen (planned / follow-up)**, not a live feature. (`daily_limit_emoji_bands.json` / `DAILY_LIMIT_HERO` is consumed by the daily-limit feature — see [07-daily-limit-scheduler.md](07-daily-limit-scheduler.md).)

---

## 8. Presentation surfaces (live today)

| Widget | File | Role |
|---|---|---|
| `SessionDialogs` | `plans/presentation/widgets/session_dialogs.dart` | The single global frosted `GlassDialog` for **Pause** and **Conscious**. Each is dual-state: a setup/picker view when idle, and a live action view (Resume / Turn off) while a session runs. `_ConsciousDialog` keys on `settings.activePlan == BlockingPlan.curious`. |
| `CountdownRing` | `plans/presentation/widgets/countdown_ring.dart` | Read-only circular gauge (`SleekCircularSlider`, no handle) used by the dashboard hero. `progress` = **remaining fraction for Pause, banked fraction for Conscious**. Shares `pauseSliderAppearance` with the interactive Pause picker so both look identical. |
| `AnimatedDigitTimer` | `plans/presentation/widgets/animated_digit_timer.dart` | Per-digit crossfading `mm:ss` countdown in the hero. |
| `CountdownCubit` | `plans/presentation/countdown_cubit.dart` | Generic 1 Hz countdown to a target `DateTime`; emits remaining `Duration` clamped at zero. |
| `ConsciousCubit` | `plans/presentation/conscious_cubit.dart` | Mirrors the native bank (§5.5). Provided app-wide in `main.dart`; watched by the dashboard. |
| `AnimatedEmoji`, `QuoteBox` | `plans/presentation/widgets/{animated_emoji,quote_box}.dart` | Built content widgets (§7.3/§7.4) — not yet mounted. |

The dashboard (`lib/features/dashboard/presentation/dashboard_tab.dart` + `widgets/command_center_card.dart`) is the caller: it opens `SessionDialogs.showPause/showConscious`, builds the hero `SessionCountdown` from either the live `PauseSession.remainingIn` or `ConsciousState` (`progress`/`banked`), and relabels `BlockingPlan.curious → 'CONSCIOUS'`.

---

## 9. End-to-end flows (summary)

**Start a Pause (4 min):** `SessionDialogs` picker → `SettingsCubit.startPause(4 min)` → `AppSettings` gets `activePlan=blockAll` + `PauseSession(cooldown=0)` → `_commit` persists + pushes `{activePlan: BLOCK_ALL, pauseUntil: pauseEnd}` → native gate `now < pauseUntil` suspends all blocking → at `pauseEnd`, native gate re-arms and the 1 Hz UI ticker clears the session → Block All.

**Turn on Conscious:** `SessionDialogs` → `SettingsCubit.enterConscious()` → `setPlan(curious)` → `_commit` pushes `{activePlan: CURIOUS, consciousEarnDivisor, consciousMaxBankMs}` → `CommandHandler` resets the bank (empty, anchored now) → `reload()` → `syncConscious()` starts the 1 Hz accountant → each tick accrues while abstaining / drains 1:1 while watching, booting reels on empty → `consciousState` events stream to `ConsciousCubit` for the hero/dialog.

---

## Source files

- `lib/features/blocking/plans/domain/entities/sessions.dart` — `PauseSession`, `SessionPhase` phase math.
- `lib/features/blocking/plans/domain/entities/session_defaults.dart` — Pause slider + Conscious tuning constants.
- `lib/features/blocking/plans/domain/entities/conscious_state.dart` — Conscious bank snapshot entity.
- `lib/features/blocking/plans/domain/entities/emoji_band.dart` — `EmojiAnimation`, `EmojiItem`, `EmojiSet`, `EmojiPlacement`, `EmojiPlacementId`.
- `lib/features/blocking/plans/domain/entities/mindful_quote.dart` — `MindfulQuote`.
- `lib/features/blocking/plans/domain/repositories/content_repository.dart` — content interface.
- `lib/features/blocking/plans/data/repositories/content_repository_impl.dart` — bundled/offline content impl (memoized, safe-degrade).
- `lib/features/blocking/plans/presentation/conscious_cubit.dart` — native bank mirror.
- `lib/features/blocking/plans/presentation/countdown_cubit.dart` — generic 1 Hz countdown.
- `lib/features/blocking/plans/presentation/widgets/session_dialogs.dart` — Pause + Conscious dialogs.
- `lib/features/blocking/plans/presentation/widgets/countdown_ring.dart` — hero gauge + shared appearance.
- `lib/features/blocking/plans/presentation/widgets/animated_digit_timer.dart` — per-digit countdown.
- `lib/features/blocking/plans/presentation/widgets/animated_emoji.dart` — 14 emoji animations.
- `lib/features/blocking/plans/presentation/widgets/quote_box.dart` — animated quote card.
- `lib/features/blocking/shared/domain/entities/enums.dart` — `BlockingPlan` (`curious`/`CURIOUS`), `SessionPhase`.
- `lib/features/blocking/shared/domain/entities/app_settings.dart` — plan state, `effectiveNativePlan`, `nativePauseUntil`, pause derivation, legacy migration.
- `lib/features/blocking/shared/presentation/settings_cubit.dart` — plan state machine, Pause ticker, `enterConscious`/`stopConscious`.
- `lib/features/blocking/shared/data/repositories/engine_repository_impl.dart` — `pushSettings` derivation + `consciousStream`/`consciousCurrent`.
- `lib/features/dashboard/presentation/dashboard_tab.dart` — plan cells, `_statusLabel` (`curious → 'CONSCIOUS'`), dialog wiring.
- `lib/features/dashboard/presentation/widgets/command_center_card.dart` — `SessionCountdown`, hero ring.
- `lib/core/constants/app_constants.dart` — bundled content asset paths, `EngineTimings`.
- `android/app/src/main/kotlin/com/errorxperts/detoxo/accessibility/DetoxoAccessibilityService.kt` — Conscious accountant (`syncConscious`, `accountConscious`, `consciousSnapshot`), Pause `pauseUntil` gate, constants.
- `android/app/src/main/kotlin/com/errorxperts/detoxo/engine/ConfigStore.kt` — bank/pause persistence, `resetConsciousBank`.
- `android/app/src/main/kotlin/com/errorxperts/detoxo/channels/CommandHandler.kt` — `pushSettings` handler, bank reset on Conscious entry, `consciousState` query.
- `assets/content/curious_emojis.json` — `EMOJI_CURIOUS_PLAN` band.
- `assets/content/pause_emojis.json` — `EMOJI_PLAN_PAUSE` band.
- `assets/content/pause_countdown_pause_emojis.json` — `EMOJI_PLAN_PAUSE_COUNTDOWN` band.
- `assets/content/pause_countdown_cooldown_emojis.json` — `EMOJI_PAUSE_COUNTDOWN_COOLDOWN` band (percent).
- `assets/content/mindful_timer_quotes.json` — mindful quotes.
- `assets/content/daily_limit_emoji_bands.json` — `DAILY_LIMIT_HERO` band (consumed by daily-limit feature).
