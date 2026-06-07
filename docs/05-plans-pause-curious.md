# Block Plans, Pause, Curious & Mindful Countdown

This document specifies the behavioral "modes" layer of the Flutter short-form-content blocker: the four **block plans** (Block-All, Curious/pomodoro, One-Reel, Paused), the time-based **Pause** session with its mandatory cooldown, the **Curious** session/cooldown loop, the **One-Reel** allow-one-then-overlay flow, and the **Mindful Countdown** UI (ticking timer + rotating quotes + duration-bucketed emoji bands with animation types). It also documents the **Dynamic Content Engine** — a placement-id-keyed quote/emoji injection system with an offline bundle fallback and tiered remote content. All of these are pure Dart/UI/state concerns; the *enforcement* decision (allow vs. block a detected reel) lives in the native detector, so this doc also defines exactly **what state must reach the native side and how**. Everything here is reconstructed from the decompiled app; original obfuscated names are cited only as evidence — the Dart sketches use clean, original names.

> **Legend:** ✅ = a pub.dev package fully handles it · ⚠️ = needs a native MethodChannel/EventChannel bridge · ❌ = not possible on iOS.

---

## 1. The four block plans (`PlansEnum`)

Verified in `utility/detectionplan/PlansEnum.java`. The enum carries UI metadata (position, title string-res, icon drawable-res, `visibleInSwitcher`). The crucial fact: **`PAUSED` is `visibleInSwitcher = false`** — the user never *picks* "Paused" from the plan switcher; the app enters it by starting a pause session, and the switcher only shows the three real plans.

| Plan | position | visibleInSwitcher | Icon (evidence) | Meaning |
|------|----------|-------------------|-----------------|---------|
| `CURIOUS` | 0 | `true` | `ic_curious` | Pomodoro: watch for N min, then a forced cooldown. |
| `BLOCK_ALL` | 1 | `true` | `ic_block` | Hardest mode: every detected reel is blocked. |
| `PAUSED` | 2 | **`false`** | `ic_pause` | Transient state while a Pause session is live; resumes `_planToResume` after. |
| `ONE_REEL` | 3 | `true` | `noscroll_logo` | Allow exactly one reel, then show a blocking overlay. |

Clean Dart entity (domain layer):

```dart
// domain/entities/block_plan.dart
enum BlockPlan {
  curious(position: 0, visibleInSwitcher: true),
  blockAll(position: 1, visibleInSwitcher: true),
  paused(position: 2, visibleInSwitcher: false), // entered, never picked
  oneReel(position: 3, visibleInSwitcher: true);

  const BlockPlan({required this.position, required this.visibleInSwitcher});
  final int position;
  final bool visibleInSwitcher;

  /// Plans the switcher offers the user, in display order.
  static List<BlockPlan> get switchable =>
      values.where((p) => p.visibleInSwitcher).toList()
        ..sort((a, b) => a.position.compareTo(b.position));
}
```

**iOS:** The plan *concept* is portable, but plans `blockAll` / `oneReel` rely on the accessibility-detector firing a back-press/overlay, which has no iOS equivalent. On iOS the closest mapping is Apple **FamilyControls + ManagedSettings** shields (all-or-nothing per category), so `oneReel`/`curious` degrade to a simple time-window shield and `blockAll` becomes a permanent shield.

---

## 2. Pause sessions

### 2.1 `PauseSessionData` — the contract

Verified in `service/accessibility/data/PauseSessionData.java`. A pause is a **wall-clock contract**: fixed start timestamp, an allowed window, then a mandatory cooldown ("lockdown"). It is stored once and *derived* state (current phase, remaining ms) is computed on every tick by comparing `System.currentTimeMillis()` against stored timestamps — there is no running counter to persist.

| Field (original) | Type | Default (verified) | Meaning |
|------------------|------|--------------------|---------|
| `pausedOn` | `long` ms | `-1` | Epoch ms when the pause began. `-1` = no active pause. |
| `pauseDuration` | `long` ms | `60000` (60 s) | How long content is allowed. |
| `lockDownDuration` | `long` ms | `UnityAdsConstants.Timeout.INIT_TIMEOUT_MS` (≈60000) | Mandatory cooldown after the allowed window. |
| `_planToResume` | `PlansEnum` | `BLOCK_ALL` | Plan to restore when the contract fully expires. |
| `allowInLockDown` | `boolean` | `true` | If `true`, limited access is still permitted during cooldown. |
| `maxPauseDuration` | `int` (min) | `15` | UI cap on selectable pause minutes (server-tunable). |

Two verified invariants from the constructor / helpers:

1. **`_planToResume` can never be `PAUSED`.** The constructor coerces it: `this._planToResume = (plan == PAUSED) ? BLOCK_ALL : plan;`. Resuming into "Paused" would be nonsensical, so it falls back to Block-All.
2. **`getContractExpiry() = pausedOn + pauseDuration + lockDownDuration`** (verified method). This single value is the moment the pause is fully released.

### 2.2 Phase math — `PAUSED → PAUSED_COOLDOWN → IDLE`

The phase enum is `CountDownPhase` (verified `pause/data/CountDownPhase.java`): ordinals `PAUSED(0)`, `PAUSED_COOLDOWN(1)`, `CURIOUS_SESSION(2)`, `CURIOUS_COOLDOWN(3)`, `IDLE(4)`. Pause uses only `PAUSED`, `PAUSED_COOLDOWN`, `IDLE`.

Verified body of `PauseSessionData.getCurrentPhase()` (note: **strict `<`**):

```
now = currentTimeMillis()
pauseEnd    = pausedOn + pauseDuration
cooldownEnd = pauseEnd  + lockDownDuration        // == getContractExpiry()

if      now <  pauseEnd     -> PAUSED            // content allowed
else if now <  cooldownEnd  -> PAUSED_COOLDOWN   // locked (gated by allowInLockDown)
else                        -> IDLE             // contract over -> resume _planToResume
```

Remaining-ms formulas the countdown UI uses each tick:

```
phase == PAUSED          -> remaining = pauseEnd    - now
phase == PAUSED_COOLDOWN -> remaining = cooldownEnd - now
cooldownProgressPct      = ((now - pauseEnd) / lockDownDuration) * 100   // 0..100, used for the 3-band cooldown emoji
```

Clean Dart entity + derived phase:

```dart
// domain/entities/pause_session.dart
enum CountdownPhase { paused, pausedCooldown, curiousSession, curiousCooldown, idle }

class PauseSession {
  const PauseSession({
    this.pausedOn = -1,
    this.pauseDurationMs = 60000,
    this.lockDownDurationMs = 60000,
    this.planToResume = BlockPlan.blockAll,
    this.allowInLockDown = true,
    this.maxPauseMinutes = 15,
  });

  final int pausedOn;            // epoch ms, -1 == none
  final int pauseDurationMs;
  final int lockDownDurationMs;
  final BlockPlan planToResume;  // never BlockPlan.paused (coerce on construct)
  final bool allowInLockDown;
  final int maxPauseMinutes;

  bool get isActive => pausedOn > 0;
  int get pauseEndMs => pausedOn + pauseDurationMs;
  int get contractExpiryMs => pauseEndMs + lockDownDurationMs;

  /// Mirrors PauseSessionData.getCurrentPhase() — strict `<` comparisons.
  CountdownPhase phaseAt(int nowMs) {
    if (!isActive) return CountdownPhase.idle;
    if (nowMs < pauseEndMs) return CountdownPhase.paused;
    if (nowMs < contractExpiryMs) return CountdownPhase.pausedCooldown;
    return CountdownPhase.idle;
  }

  int remainingMs(int nowMs) {
    switch (phaseAt(nowMs)) {
      case CountdownPhase.paused:         return pauseEndMs - nowMs;
      case CountdownPhase.pausedCooldown: return contractExpiryMs - nowMs;
      default:                            return 0;
    }
  }

  /// 0..100 progress through the cooldown window (drives cooldown emoji band).
  int cooldownProgressPct(int nowMs) {
    if (lockDownDurationMs <= 0) return 100;
    final pct = ((nowMs - pauseEndMs) / lockDownDurationMs) * 100;
    return pct.clamp(0, 100).round();
  }

  /// PAUSED constructor coercion (verified).
  PauseSession copyResume(BlockPlan p) => PauseSession(
        pausedOn: pausedOn, pauseDurationMs: pauseDurationMs,
        lockDownDurationMs: lockDownDurationMs,
        planToResume: p == BlockPlan.paused ? BlockPlan.blockAll : p,
        allowInLockDown: allowInLockDown, maxPauseMinutes: maxPauseMinutes);
}
```

**Packages:** state machine is built-in Dart (`DateTime.now().millisecondsSinceEpoch`; use `package:clock` ✅ for testable "now"). Persist with `hive` ✅ (or `flutter_secure_storage`). The ticking timer is `Stream.periodic` ✅ — see §6.

---

## 3. Curious sessions (pomodoro)

### 3.1 `CuriousSessionData`

Verified in `service/accessibility/data/CuriousSessionData.java`. Same wall-clock pattern as Pause but durations are in **minutes** and the phase enum is the separate `CuriousStatusEnum { SESSION, COOLDOWN, IDLE }`.

| Field (original) | Type | Default (verified) | Meaning |
|------------------|------|--------------------|---------|
| `sessionDuration` | `int` min | `5` | Watch window length. |
| `cooldownDuration` | `int` min | `5` | Forced cooldown length. |
| `shortVideoSessionStartTime` | `long` ms | `0` | When the session clock started. |
| `lastWatchedInCurious` | `long` ms | `0` | Last time a reel was watched (engagement bookkeeping). |
| `isVideoAllowedInCooldown` | `boolean` | `false` | If `true`, sneaking videos during cooldown is permitted. |
| `disablePlanSwitchInCooldown` | `boolean` | `false` | If `true`, the plan switcher is locked during cooldown. |

### 3.2 Phase math — `SESSION → COOLDOWN → IDLE`

Verified body of `CuriousSessionData.getCurrentPhase()` (minutes → ms via `*60000`). Note it also guards against a *future* start (`start > now`):

```
now        = currentTimeMillis()
start      = shortVideoSessionStartTime
sessionEnd  = start + sessionDuration  * 60000
cooldownEnd = start + (sessionDuration + cooldownDuration) * 60000

if now <= sessionEnd && start <= now            -> SESSION   // videos allowed
else if now < cooldownEnd && now >= sessionEnd  -> COOLDOWN  // blocked unless isVideoAllowedInCooldown
else                                            -> IDLE      // pick a new plan
```

Clean Dart:

```dart
// domain/entities/curious_session.dart
enum CuriousStatus { session, cooldown, idle }

class CuriousSession {
  const CuriousSession({
    this.sessionMinutes = 5,
    this.cooldownMinutes = 5,
    this.startedOn = 0,
    this.lastWatchedOn = 0,
    this.isVideoAllowedInCooldown = false,
    this.disablePlanSwitchInCooldown = false,
  });

  final int sessionMinutes;
  final int cooldownMinutes;
  final int startedOn;             // epoch ms
  final int lastWatchedOn;
  final bool isVideoAllowedInCooldown;
  final bool disablePlanSwitchInCooldown;

  int get _sessionEndMs  => startedOn + sessionMinutes * 60000;
  int get _cooldownEndMs => startedOn + (sessionMinutes + cooldownMinutes) * 60000;

  CuriousStatus statusAt(int nowMs) {
    if (startedOn <= nowMs && nowMs <= _sessionEndMs) return CuriousStatus.session;
    if (nowMs >= _sessionEndMs && nowMs < _cooldownEndMs) return CuriousStatus.cooldown;
    return CuriousStatus.idle;
  }

  /// Used to gray-out the plan switcher (see PlanBloc, §5).
  bool planSwitchLockedAt(int nowMs) =>
      disablePlanSwitchInCooldown && statusAt(nowMs) == CuriousStatus.cooldown;
}
```

---

## 4. One-Reel: allow one, then overlay

`ONE_REEL` is the only plan whose enforcement is *not* "block immediately." Verified service constants (`NoScrollAccessibilityService.java`) drive it:

- `ONE_REEL_OVERLAY_GRACE_MS = 500` — after a reel is detected, the user gets a 500 ms grace window before the overlay is considered.
- `ONE_REEL_OVERLAY_POLL_MS = 500` — overlay-active state is polled every 500 ms.
- `hardBlockUntilMs` — once the user taps "close" on the overlay, a hard-block grace (`HARD_BLOCK_AFTER_CLOSE_TAP_MS`, ≈10 s per the Unity SCAR timeout) suppresses re-triggering while the screen settles.
- `onKeyEvent` intercepts **BACK** to dismiss the One-Reel overlay (verified).

Behaviorally: first detected reel is *allowed* to play; a system overlay (`TYPE_APPLICATION_OVERLAY`) is then shown over the app inviting the user to stop; tapping close (or BACK) dismisses it and enters the hard-block grace so the next reel is blocked. This is **⚠️ native** (overlay window + accessibility), surfaced to Dart via `flutter_overlay_window` ✅ (for the overlay) + a MethodChannel for grace/poll timing.

**iOS:** ❌ — no system overlay over third-party apps and no accessibility tree. Degrade One-Reel to a FamilyControls time-window shield.

---

## 5. PlanBloc / PauseBloc / CuriousBloc (presentation)

Architecture target is `flutter_bloc` + Clean Architecture. The plan layer is small but must do three things: (1) own the *active* plan + live session, (2) gate the switcher when Curious cooldown locks it, (3) push every change to the native detector (§7).

### 5.1 Use-cases (domain)

```dart
// domain/usecases/set_block_plan.dart
class SetBlockPlan {
  SetBlockPlan(this._repo);
  final PlanRepository _repo;
  Future<void> call(BlockPlan plan) => _repo.setActivePlan(plan); // persists + channels
}

// domain/usecases/start_pause.dart
class StartPause {
  StartPause(this._repo);
  final PlanRepository _repo;
  Future<void> call({required int pauseMinutes, required int cooldownMinutes,
                     required BlockPlan resumeTo}) {
    return _repo.startPause(PauseSession(
      pausedOn: clock.now().millisecondsSinceEpoch,
      pauseDurationMs: pauseMinutes * 60000,
      lockDownDurationMs: cooldownMinutes * 60000,
      planToResume: resumeTo == BlockPlan.paused ? BlockPlan.blockAll : resumeTo,
    ));
  }
}
```

### 5.2 PlanBloc

```dart
// presentation/bloc/plan/plan_event.dart
sealed class PlanEvent {}
class PlanSelected extends PlanEvent { PlanSelected(this.plan); final BlockPlan plan; }
class PauseRequested extends PlanEvent {
  PauseRequested(this.pauseMin, this.cooldownMin, this.resumeTo);
  final int pauseMin, cooldownMin; final BlockPlan resumeTo;
}
class _SessionsTicked extends PlanEvent {} // internal, fired by the ticker

// presentation/bloc/plan/plan_state.dart
class PlanState {
  const PlanState({
    required this.activePlan,
    required this.pause,
    required this.curious,
    required this.switcherEnabled,
  });
  final BlockPlan activePlan;     // PAUSED while a pause contract is live
  final PauseSession pause;
  final CuriousSession curious;
  final bool switcherEnabled;     // false when Curious cooldown locks switching
}

// presentation/bloc/plan/plan_bloc.dart
class PlanBloc extends Bloc<PlanEvent, PlanState> {
  PlanBloc(this._setPlan, this._startPause, this._repo, this._ticker)
      : super(_repo.initialState()) {
    on<PlanSelected>((e, emit) async {
      await _setPlan(e.plan);                 // persist + push to native
      emit(_recompute(activePlan: e.plan));
    });
    on<PauseRequested>((e, emit) async {
      await _startPause(pauseMinutes: e.pauseMin,
          cooldownMinutes: e.cooldownMin, resumeTo: e.resumeTo);
      emit(_recompute(activePlan: BlockPlan.paused)); // PAUSED is entered, not picked
    });
    on<_SessionsTicked>((_, emit) => emit(_recompute()));
    _tickSub = _ticker.listen((_) => add(_SessionsTicked()));
  }

  PlanState _recompute({BlockPlan? activePlan}) {
    final now = clock.now().millisecondsSinceEpoch;
    final pause = _repo.currentPause();
    final curious = _repo.currentCurious();
    // Pause contract expiry auto-resumes the underlying plan.
    var plan = activePlan ?? state.activePlan;
    if (plan == BlockPlan.paused &&
        pause.phaseAt(now) == CountdownPhase.idle) {
      plan = pause.planToResume;
    }
    return PlanState(
      activePlan: plan, pause: pause, curious: curious,
      switcherEnabled: !curious.planSwitchLockedAt(now),
    );
  }
}
```

`PauseBloc` is the countdown-screen-scoped bloc (§6): it owns the per-second tick and exposes `remainingMs`, `phase`, the current emoji band, and the rotating quote.

---

## 6. Mindful Countdown UI

The countdown screen (evidence: `pausecountdown/ui/screens/PauseCountdownScreenContentKt.java`) shows three coordinated things: a **ticking mm:ss timer**, a **rotating motivational quote**, and a **duration/progress-bucketed emoji** with an animation. Rebuild it with a single `Stream.periodic(const Duration(seconds: 1))` driving the bloc.

### 6.1 The ticker

```dart
// data/datasources/countdown_ticker.dart  ✅ built-in
Stream<int> oneSecondTicks() =>
    Stream<int>.periodic(const Duration(seconds: 1), (i) => i);
```

In the bloc, each tick recomputes `remainingMs` from `PauseSession.remainingMs(now)` (or `CuriousSession`), reformats `mm:ss`, re-selects the cooldown emoji band by `cooldownProgressPct`, and advances the quote index when the phase changes or every few seconds.

```dart
// presentation/bloc/countdown/countdown_bloc.dart (sketch)
class CountdownBloc extends Bloc<CountdownEvent, CountdownState> {
  CountdownBloc(this._content) : super(CountdownState.initial()) {
    on<CountdownTicked>((_, emit) {
      final now = clock.now().millisecondsSinceEpoch;
      final phase = _session.phaseAt(now);
      final remaining = _session.remainingMs(now);
      final emoji = _selectEmoji(phase, now);   // §7.x range matching
      final quote = MindfulQuotes.all[_quoteIndex % MindfulQuotes.all.length];
      emit(state.copyWith(
        label: _fmtMmSs(remaining), phase: phase, emoji: emoji, quote: quote));
      if (remaining <= 0) add(const CountdownTicked()); // phase rolled over
    });
  }
  String _fmtMmSs(int ms) {
    final s = (ms / 1000).ceil().clamp(0, 5999);
    return '${(s ~/ 60).toString().padLeft(2, '0')}:'
           '${(s % 60).toString().padLeft(2, '0')}';
  }
}
```

The original animates the timer **per-digit crossfade** (each digit wrapped in `AnimatedContent`). Reproduce with one `AnimatedSwitcher` per digit cell ✅ (built-in) — no package needed.

### 6.2 Rotating quotes

There are **two** quote sources in the original, keep both:

1. **`assets/mindful_timer_quotes.json`** — verified **52 quotes** under a top-level `"quotes": [...]` string array (e.g. *"This pause is the point. Resisting the urge is the win."*, *"Reels can wait. Your goals absolutely cannot."*). Used by the pause-countdown timer to discourage re-entry. Rotate by `index % 52`.
2. **9 hardcoded pause-screen quotes** (evidence: `utility/collections/QuotesManagerKt.java`), each paired with an emoji (e.g. *"The successful warrior is the average man, with laser-like focus."* + 🎯). Rotate by `index % 9`.

```dart
// data/datasources/mindful_quotes.dart
class MindfulQuotes {
  static late final List<String> all; // load once from assets
  static Future<void> load() async {
    final raw = await rootBundle.loadString('assets/mindful_timer_quotes.json');
    all = (jsonDecode(raw)['quotes'] as List).cast<String>(); // 52 entries
  }
}
```

The `QuoteBox` fades+scales in (two `Animatable<Float>` in the original: scale `0.8→1.0`, alpha `0→1`). Reproduce with `TweenAnimationBuilder` / `AnimatedOpacity` + `Transform.scale` ✅.

### 6.3 Emoji bands (duration/progress buckets) + animation types

Every bundled emoji JSON shares one schema (verified across all five files): a top-level `"emojiSets"` array; each set has `setId`, `placementId`, `enabled`, `createdTimeStamp`, and an `emojis` array. Each emoji item has `emojiId`, **`rangeMin`/`rangeMax`** (the bucket bounds), `emoji`, `title`, `description`, and **`animation`** (one of the 14 `EmojiAnimationEnum` values).

The five bundled placement files and what their buckets key on:

| Bundle file (res/raw) | placementId | Bucket key | Verified bands (sample) |
|-----------------------|-------------|-----------|--------------------------|
| `pause_emojis.json` | `EMOJI_PLAN_PAUSE` | pause **re-open count** | `0-2` ✨ "Very Demure" (BREATHING) · `3-5` 👀 "Bombastic Side Eye" (SCANNING) · `6-8` 🫠 "Brain Is Melting" (MELTING) · `9-11` 🤡 "Clown Activity" (BOUNCING) · … `21-23` 🧟 "NPC Energy" (LUMBER) |
| `curious_emojis.json` | `EMOJI_CURIOUS_PLAN` | **minutes elapsed** in session | `0-5` 🎯 "Stay Sharp" (BREATHING) · `6-10` 🤨 "Still Worth It?" (SCANNING) · `11-15` 📉 "Slippery Slope" (SINKING) · `16-20` 🫵 "You vs You" (BOUNCING) · `21-25` 😟 "Disappointed" · `26-30` 😰 "Anxiety Loading" (QUAKING) · `31-35` 🚩 "Red Flag" (WAVING) · `36-40` 🤮 "Sickening" |
| `daily_limit_emoji_bands.json` | `DAILY_LIMIT_HERO` | **daily-limit minutes** | `0-0` 🛑 "Total Lockdown!" · `1-30` 🚀 "Laser Focus" · `31-120` ⚖️ "Healthy Balance" · `121-240` 🕰️ "Slipping Away…" (SHAKE) · `241-999999` 🧟 "Doomscroller Mode" (SHAKE) |
| `pause_countdown_pause_emojis.json` | `EMOJI_PLAN_PAUSE_COUNTDOWN` | **selected pause minutes** | `0-3` ⚡ "Blink mode" (FLASH) · `4-6` 🎯 "Focused chaos" (SHAKE) · `7-9` 🎢 "Mini marathon" (CHAOS) · `10-15` 🎪 … |
| `pause_countdown_cooldown_emojis.json` | `EMOJI_PAUSE_COUNTDOWN_COOLDOWN` | **cooldown % (0-100)** | `0-19` 🔥 "Almost Free" (SHAKE) · `20-49` ⏳ "Keeping Cool" (BREATHING) · `50-100` ❄️ "Chill Out" (BOUNCING) |

The 14 animation types (verified ordinals in `plans/data/EmojiAnimationEnum.java`):

```
BREATHING(0) SCANNING(1) MELTING(2) BOUNCING(3) WAVING(4) QUAKING(5) CHAOS(6)
SLIDE(7) LUMBER(8) SINKING(9) GLOW(10) FLASH(11) FLY(12) SHAKE(13)
```

Suggested Flutter realization of each (all via `AnimationController` ✅, no package needed; consider `rive`/`lottie` ✅ only if you want richer art):

| Animation | Flutter realization |
|-----------|---------------------|
| BREATHING | repeating scale 1.0↔1.08 |
| SCANNING | horizontal translate left↔right (eye dart) |
| MELTING | scaleY down + opacity fade |
| BOUNCING | vertical translate with `Curves.bounceOut` |
| WAVING | rotation ±10° pendulum |
| QUAKING | small random offset jitter |
| CHAOS | combined random rotate+translate |
| SLIDE | translate in from edge |
| LUMBER | slow heavy scale/translate |
| SINKING | translate down + fade |
| GLOW | animated `BoxShadow`/blur radius |
| FLASH | opacity blink |
| FLY | translate across with easing |
| SHAKE | high-frequency ±x offset |

Dart model + range matcher:

```dart
// data/models/emoji_item_model.dart
enum EmojiAnimation { breathing, scanning, melting, bouncing, waving, quaking,
  chaos, slide, lumber, sinking, glow, flash, fly, shake }

class EmojiItem {
  const EmojiItem({required this.id, required this.rangeMin, required this.rangeMax,
    required this.emoji, required this.title, required this.description, required this.animation});
  final String id; final int rangeMin, rangeMax;
  final String emoji, title, description; final EmojiAnimation animation;

  bool covers(int v) => v >= rangeMin && v <= rangeMax; // inclusive (verified)

  factory EmojiItem.fromJson(Map<String, dynamic> j) => EmojiItem(
    id: j['emojiId'], rangeMin: j['rangeMin'], rangeMax: j['rangeMax'],
    emoji: j['emoji'], title: j['title'], description: j['description'],
    animation: EmojiAnimation.values.byName((j['animation'] as String).toLowerCase()),
  );
}
```

**Packages:** `cached_network_image` ✅ for remote emoji *art* (when a tier supplies `imageUrl`); plain `Text(emoji)` otherwise. `hive` ✅ to cache the merged content set.

---

## 7. Dynamic Content Engine (placement-based injection + offline fallback + tiered remote)

Evidence: `utility/dynamiccontent/DynamicContentEngine.java`, `PlacementContentHolder.java`, `PlacementContentResult.java`, `EmojiPlacementIdsEnum.java`, `QuotePlacementIdsEnum.java`, `CuriousOfflineBundle.java`, and the `network/data/fetchcontent/response/*` models.

This is a **placement-id → content** routing system so any emoji/quote can be swapped from the server **without an app update**. Three layers, in priority order: (1) **remote tiered content** (`fetchcontent`), merged over (2) **offline bundle** fallbacks (the five res/raw JSONs above), exposed through (3) a **reactive holder** the UI watches.

### 7.1 Placement ids

`EmojiPlacementIdsEnum` (verified, 6 values): `EMOJI_PLAN_PAUSE(0)`, `EMOJI_CURIOUS_PLAN(1)`, `EMOJI_APP_LOCK_SESSION(2)`, `DAILY_LIMIT_HERO(3)`, `EMOJI_PLAN_PAUSE_COUNTDOWN(4)`, `EMOJI_PAUSE_COUNTDOWN_COOLDOWN(5)`. `QuotePlacementIdsEnum` (verified, 1 value): `WELCOME_SCREEN(0)`. The `placementId` *string* in each emoji set matches the enum `.name()` — that's the join key.

### 7.2 Remote response shape (`fetchcontent`)

Verified models — `FetchContentResponse { renewalTimestamp:Long, freeContentKey:String, content:Map<String,TierContent> }`; `TierContent { quotes:QuotesSection, emojis:EmojisSection }`; sections wrap `List<QuotePlacement>` / `List<EmojiPlacement>`; `EmojiPlacement { placementId, description, enabled, emojiSet:EmojiSet }`; `EmojiSet { setId, placementId, enabled, createdTimeStamp, emojis:List<EmojiItem> }`; `QuotePlacement { placementId, title, description, enabled, quote:QuoteDetail }`; `QuoteDetail { quoteId, quote, description, imageUrl, emoji }`. `content` is keyed by **subscription tier** (free/premium); the active tier(s) are merged into one result.

### 7.3 Two verified algorithms

- **`emojiForProgress(result, placementId, threshold)`** → look up the placement; if both placement and its `EmojiSet` are `enabled`, return the items where `rangeMin <= threshold <= rangeMax` (inclusive); else empty list. This is what the countdown/daily-limit UI calls with the bucket key (re-open count, minutes, or cooldown %).
- **`mergeBundledPlacementIfNeeded(map, placementId, bundled)`** → if the map has no enabled, non-empty placement for that id **and** the bundled fallback *is* enabled & non-empty & its `placementId.name()` matches, insert the bundled placement. This is the offline backfill, run after each remote fetch.

Bundled loading is **lazy** (4 lazy delegates in the original, one per file): on first access, open the raw JSON → GSON `CuriousOfflineBundle` → convert to an `EmojiPlacement`; on error, return an empty placement (null-safe). In Flutter: `rootBundle.loadString` + `jsonDecode`, memoized.

### 7.4 Dart sketch

```dart
// domain/entities/placement_content.dart
class PlacementContent {
  const PlacementContent({this.quotes = const {}, this.emojis = const {}});
  final Map<QuotePlacementId, QuotePlacement> quotes;
  final Map<EmojiPlacementId, EmojiPlacement> emojis;

  /// emojiForProgress: items whose [rangeMin..rangeMax] covers [threshold].
  List<EmojiItem> emojiFor(EmojiPlacementId id, int threshold) {
    final p = emojis[id];
    if (p == null || !p.enabled || !p.set.enabled) return const [];
    return p.set.items.where((e) => e.covers(threshold)).toList();
  }
}

// data/repositories/dynamic_content_repository.dart
class DynamicContentRepository {
  DynamicContentRepository(this._api, this._bundle, this._box);
  final FetchContentApi _api;
  final OfflineBundleSource _bundle;   // loads 5 res/raw -> assets JSONs, lazily
  final Box _box;                      // hive cache

  final _controller = StreamController<PlacementContent>.broadcast();
  Stream<PlacementContent> get stream => _controller.stream; // == PlacementContentHolder

  Future<void> refresh(Set<String> activeTiers) async {
    PlacementContent result;
    try {
      final resp = await _api.fetchContent();      // tiered remote
      result = _mergeTiers(resp, activeTiers);      // pick active tier(s)
    } catch (_) {
      result = const PlacementContent();            // network failed -> empty
    }
    // Offline backfill for any missing/disabled/empty placement (mergeBundledPlacementIfNeeded).
    final emojis = {...result.emojis};
    for (final id in EmojiPlacementId.values) {
      final cur = emojis[id];
      if (cur == null || !cur.enabled || cur.set.items.isEmpty) {
        final bundled = await _bundle.placement(id); // lazy, memoized
        if (bundled.enabled && bundled.set.items.isNotEmpty) emojis[id] = bundled;
      }
    }
    final merged = PlacementContent(quotes: result.quotes, emojis: emojis);
    await _box.put('placement_content', merged); // cache for offline next launch
    _controller.add(merged);
  }
}
```

A **`DynamicContentCubit`** wraps `stream` for the UI:

```dart
class DynamicContentCubit extends Cubit<PlacementContent> {
  DynamicContentCubit(this._repo) : super(const PlacementContent()) {
    _sub = _repo.stream.listen(emit);
  }
}
```

**Packages:** `dio`/`retrofit` ✅ for `fetchContent`, `json_serializable`/`freezed` ✅ for the models, `hive` ✅ for the offline cache, `cached_network_image` ✅ for remote emoji art.

### 7.5 `renewalTimestamp` (TTL)

`FetchContentResponse.renewalTimestamp` is the epoch ms after which cached content should be re-fetched. Gate `refresh()`: skip the network call if `now < cachedRenewalTimestamp`, otherwise re-fetch. (No version-diff logic was present in the decompiled engine — `createdTimeStamp` on `EmojiSet` exists but is unused for invalidation; **(inferred)** TTL is the only freshness signal.)

---

## 8. How plan/session state reaches the native detector

The detector lives in the accessibility service (its own `:as_process`); it cannot read Dart memory. The original propagates state through **DataStore flows** that the service observes (verified: `pauseData`/`curiousData`/`activeDetectionPlan` are `StateFlow`s in `NoScrollServiceModel`, fed by `NoScrollAccessibilityRepository` ← `DataStoreBase`). In Flutter the two viable bridges:

1. **Shared persisted store the native side reads** — write `PauseSession`/`CuriousSession`/active-`BlockPlan` to a store both Dart and native Kotlin can read. ⚠️ Native side reads it on each accessibility event. (`shared_preferences` ✅ is the simplest shared store; the native service reads the same `SharedPreferences` file.)
2. **MethodChannel push on change** — when `PlanBloc`/`PauseBloc` emit, call a channel method so the service caches the new state immediately (avoids waiting for a re-read). ⚠️

Recommended: do **both** — persist (survives service resurrection / boot, mirroring the original DataStore behavior) **and** push a channel event for immediacy.

```dart
// data/datasources/native_plan_channel.dart  ⚠️
class NativePlanChannel {
  static const _ch = MethodChannel('app/plan_state');
  Future<void> pushPlan(BlockPlan p) => _ch.invokeMethod('setActivePlan', {'plan': p.name});
  Future<void> pushPause(PauseSession s) => _ch.invokeMethod('setPause', {
        'pausedOn': s.pausedOn, 'pauseMs': s.pauseDurationMs,
        'lockDownMs': s.lockDownDurationMs, 'resumeTo': s.planToResume.name,
        'allowInLockDown': s.allowInLockDown,
      });
  Future<void> pushCurious(CuriousSession s) => _ch.invokeMethod('setCurious', {
        'sessionMin': s.sessionMinutes, 'cooldownMin': s.cooldownMinutes,
        'startedOn': s.startedOn, 'allowInCooldown': s.isVideoAllowedInCooldown,
      });
}
```

The native service then evaluates, per detected reel, the same gate the original `processAndBlockShortContent` does **(body obfuscated in the decompile → gate order inferred):** if Pause `PAUSED` (or `PAUSED_COOLDOWN` with `allowInLockDown`) → allow; if Curious `SESSION` → allow; if Curious `COOLDOWN` and not `isVideoAllowedInCooldown` → block; otherwise resolve the active plan (`PAUSED → _planToResume`) and apply its block mode.

**Native boundary summary for this doc's scope:**

| Concern | Verdict | Mechanism |
|---------|---------|-----------|
| Plan/session *state machine & math* | ✅ pure Dart | entities in §2/§3 |
| Countdown UI, quotes, emoji bands | ✅ pure Dart | `Stream.periodic`, `flutter_bloc`, assets |
| Dynamic content fetch/cache/merge | ✅ pure Dart | `dio` + `hive` |
| Push state to detector | ⚠️ native | `shared_preferences` shared file + MethodChannel |
| One-Reel overlay + grace/poll | ⚠️ native | `flutter_overlay_window` + channel; BACK via `onKeyEvent` |
| Enforcement (allow/block decision) | ⚠️ native | accessibility service reads the state |
| Any of the above on iOS | ❌ | only FamilyControls/DeviceActivity/ManagedSettings shields |

---

## 9. Defaults & constants quick-reference (verified)

| Constant | Value | Source |
|----------|-------|--------|
| Pause default `pauseDuration` | `60000` ms | `PauseSessionData(int)` |
| Pause default `lockDownDuration` | `UnityAdsConstants.Timeout.INIT_TIMEOUT_MS` (≈60000 ms) | `PauseSessionData(int)` |
| Pause default `_planToResume` | `BLOCK_ALL` (and `PAUSED` is coerced to `BLOCK_ALL`) | constructor |
| Pause default `maxPauseDuration` | `15` min | `PauseSessionData(int)` |
| Curious defaults | `sessionDuration=5`, `cooldownDuration=5` min | `CuriousSessionData()` |
| One-Reel grace | `ONE_REEL_OVERLAY_GRACE_MS = 500` ms | `NoScrollAccessibilityService.java` |
| One-Reel poll | `ONE_REEL_OVERLAY_POLL_MS = 500` ms | `NoScrollAccessibilityService.java` |
| Hard-block after close tap | `HARD_BLOCK_AFTER_CLOSE_TAP_MS ≈ 10000` ms | `NoScrollAccessibilityService.java` |
| Mindful quotes | 52 (`mindful_timer_quotes.json`) + 9 (`QuotesManagerKt`) | assets / source |
| Emoji animation types | 14 (`EmojiAnimationEnum`) | source |
| Emoji placement ids | 6 emoji + 1 quote | source enums |

---

**Source evidence:** `utility/detectionplan/PlansEnum.java`; `service/accessibility/data/PauseSessionData.java`; `service/accessibility/data/CuriousSessionData.java`; `activities/home/compose/pause/data/CountDownPhase.java`, `PauseSettingsState.java`; `activities/home/compose/appblockerpause/data/AppBlockerPauseState.java`; `activities/home/compose/pausecountdown/ui/screens/PauseCountdownScreenContentKt.java`; `activities/home/compose/plans/data/EmojiAnimationEnum.java`; `service/accessibility/data/NoScrollServiceModel.java`, `NoScrollAccessibilityRepository.java`; `service/accessibility/NoScrollAccessibilityService.java`; `data/database/datasource/DataStoreBase.java`; `utility/dynamiccontent/{DynamicContentEngine,PlacementContentHolder,PlacementContentResult,EmojiPlacementIdsEnum,QuotePlacementIdsEnum,CuriousOfflineBundle}.java`; `network/data/fetchcontent/response/{FetchContentResponse,TierContent,QuotesSection,EmojisSection,EmojiPlacement,EmojiSet,EmojiItem,QuotePlacement,QuoteDetail}.java`; `utility/collections/QuotesManagerKt.java`; `resources/assets/mindful_timer_quotes.json`; `resources/res/raw/{pause_emojis,curious_emojis,daily_limit_emoji_bands,pause_countdown_pause_emojis,pause_countdown_cooldown_emojis}.json`.

## Related docs
- `01-architecture-overview.md`
- `02-accessibility-detection-engine.md`
- `03-platforms-config-and-detectors.md`
- `04-service-runtime-and-state.md`
- `06-pin-lock-and-app-blocker.md`
- `07-daily-limit-and-usage-stats.md`
- `08-premium-billing-and-gating.md`
- `09-dynamic-content-and-remote-config.md`
- `10-native-bridge-and-channels.md`
