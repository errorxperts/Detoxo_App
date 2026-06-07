# Daily Limit & Scheduler

This document specifies how to rebuild the **daily time-quota** and **scheduler** subsystems of the short-form content blocker in Flutter (flutter_bloc + Clean Architecture). It covers the persisted quota model (`DailyAppBlocker` in the original), consumption tracking, midnight reset by date-signature comparison, the pause/cooldown "break" windows, the focus-mode temporary unlock, emoji feedback bands by quota size, and a time-of-day / day-of-week scheduler. It calls out where Flutter packages suffice (✅), where a native MethodChannel/EventChannel is unavoidable (⚠️), and what is impossible on iOS (❌). The most important caveat is highlighted throughout: **enforcement of the quota requires the native foreground-app signal — Dart alone cannot know which app is on screen.**

---

## 1. Subsystem responsibility

The daily-limit subsystem answers one question per check: **"Has the user spent their allowed minutes on restricted apps today, and if not, how much is left?"** It does NOT itself watch the screen. It is fed by the accessibility/usage signal (see `04-accessibility-engine.md`) which tells it "a restricted app is foregrounded right now." The subsystem then:

1. Tracks elapsed time against a per-day budget (`dailyLimitDuration`).
2. Resets that budget's consumption at the local-day boundary (midnight) via a **date-signature string compare**, not a timer.
3. Honors temporary "break" windows: a **pause** (access allowed despite quota) followed by a **cooldown** (access re-blocked).
4. Issues a **focus-mode unlock** — a short-lived grant of N minutes after the user requests more time at the block screen.

The **scheduler** is a thinner, partially-stubbed layer (see §10) that defines active windows (time-of-day, day-of-week) during which blocking is enforced at all.

> ⚠️ **Enforcement boundary.** Every algorithm below is pure Dart and testable, but the *trigger* ("a restricted app is in the foreground for the last 5 seconds, add 5s to `consumedDuration`") comes from native code over an `EventChannel`. There is no `usage_stats`-only way to get sub-minute, real-time foreground ticks reliably enough on modern Android; the original increments consumption from inside the AccessibilityService. iOS: ❌ no equivalent foreground stream; the closest is `DeviceActivityMonitor` thresholds in Apple's Screen Time framework (parental-control only, see §11).

---

## 2. Source evidence

This doc is based on direct reads of the decompiled app:

| Concern | Decompiled file (evidence) |
|---|---|
| Quota data model, reset, cooldown check | `data/database/data/DailyAppBlocker.java` |
| hours/minutes → millis conversion + save | `activities/home/compose/dailylimit/helpers/DailyLimitActionsImpl.java`, `activities/home/viewmodel/home/HomeViewModel$updateDailyLimit$1.java` |
| Pause/cooldown window setup | `activities/home/viewmodel/home/HomeViewModel$updateAppBlockerPause$1.java` |
| Remaining-quota calc for block overlay | `activities/pinblockoverlay/viewmodel/PinBlockOverlayViewmodel$lockState$1.java` |
| Emoji bands config | `resources/res/raw/daily_limit_emoji_bands.json` |
| Quota enforcement host (foreground service) | `service/AppMonitorService.java` (body obfuscated → inferred) |
| Persistence backend | `data/database/datasource/DataStoreUtils.java`, `DataStoreBase.PrefKeys` |

---

## 3. Verified constants & defaults

All quoted from `DailyAppBlocker.java` and the ViewModel coroutines:

| Constant / default | Value | Evidence |
|---|---|---|
| `dateSignature` format | `"dd-MM-yyyy"` (e.g. `"07-06-2026"`), `Locale.getDefault()` | `SimpleDateFormat("dd-MM-yyyy", ...)` in ctor & `refreshSignature` |
| Default `dailyLimitDuration` | `9_000_000L` ms = **150 min = 2h 30m** | no-arg ctor literal |
| Default `consumedDuration` | `0L` | ctor |
| Default `lastBlockSessionId` | `"NoScroll"` | ctor |
| Default `isActive` | `true` | ctor |
| Default `isPaused` | `false` | ctor |
| Millis-per-minute factor | `60000` | every conversion site |
| hours+minutes → millis | `60000 * ((hours * 60L) + minutes)` | `DailyLimitActionsImpl.onSaveClick` |
| Pause minimum | **1 minute** (`if (pauseMin < 1) pauseMin = 1`) | `updateAppBlockerPause$1` |
| Cooldown minimum | **5 minutes** (`if (coolMin < 5) coolMin = 5`) | `updateAppBlockerPause$1` |
| `pauseExpiry` | `now + pauseMin*60000` | `updateAppBlockerPause$1` |
| `cooldownExpiry` | `pauseExpiry + coolMin*60000` | `updateAppBlockerPause$1` |

`DailyAppBlocker` full field list (all `final`, units in **milliseconds** unless noted):

```
dateSignature        : String  (dd-MM-yyyy, local)
lastUpdate           : long     (epoch ms)
dailyLimitDuration   : long     (budget)
consumedDuration     : long     (used today)
sessionExpiry        : long     (focus-unlock grant end, epoch ms)
currentFocusUnlockId : String   (id of the active focus-mode grant; "" when none)
lastBlockSessionId   : String   (default "NoScroll")
isActive             : boolean
isPaused             : boolean
pauseExpiry          : long     (epoch ms; access allowed until this)
cooldownExpiry       : long     (epoch ms; access re-blocked until this)
pauseDurationMillis  : long
cooldownDurationMillis: long
```

---

## 4. Timezone caveat (READ THIS)

The reset compares two `dd-MM-yyyy` strings produced by `SimpleDateFormat(..., Locale.getDefault())` over `System.currentTimeMillis()`. `SimpleDateFormat` uses the **device's default timezone**, so in the original the day boundary is **device-local midnight** — but this is *implicit*, never set explicitly, and `Locale.getDefault()` only affects formatting symbols, not the zone. The source does **not** pin a timezone, so behavior on DST transitions or after the user changes timezone is **undefined in the original**.

**Recommendation for the Flutter rebuild:** make the timezone *explicit and device-local* using `DateTime.now()` (already local) formatted with `intl`'s `DateFormat('dd-MM-yyyy')`. Do **not** use `DateTime.now().toUtc()` — UTC would shift the user's "day" by their offset and reset consumption mid-evening for users west of UTC (or mid-morning east). If you ever need anti-tamper (user rolling the clock back), validate against a monotonic source or a fetched server time, but keep the *display/reset day* device-local. Document the chosen zone in code:

```dart
// Day boundary = DEVICE-LOCAL midnight. Matches original SimpleDateFormat behavior.
// Explicitly NOT UTC: UTC would reset at the wrong wall-clock time for the user.
final _dayFormat = DateFormat('dd-MM-yyyy'); // intl uses the device locale + local zone
String dateSignatureFor(DateTime t) => _dayFormat.format(t); // t is local
```

---

## 5. Domain entities (Dart sketch)

`domain/entities/daily_app_blocker.dart` — clean rewrite, our own names, value-object style (immutable + `copyWith`):

```dart
import 'package:equatable/equatable.dart';

/// Persisted daily-quota state. All durations are stored as [Duration];
/// the original stored raw milliseconds (longs). Timestamps are absolute
/// wall-clock [DateTime] (device-local).
class DailyAppBlocker extends Equatable {
  /// "dd-MM-yyyy" device-local signature of the day this state belongs to.
  final String dateSignature;
  final DateTime lastUpdate;

  /// User-configured budget for the day (e.g. 2h30m by default).
  final Duration dailyLimit;

  /// How much of the budget has been used today.
  final Duration consumed;

  /// Focus-mode temporary unlock: access granted until this instant.
  final DateTime? sessionExpiry;
  final String currentFocusUnlockId; // "" when no active grant

  final String lastBlockSessionId; // default "NoScroll"
  final bool isActive;

  // --- Break windows (independent of quota) ---
  final bool isPaused;
  final DateTime? pauseExpiry;     // access ALLOWED until here
  final DateTime? cooldownExpiry;  // access RE-BLOCKED until here
  final Duration pauseDuration;
  final Duration cooldownDuration;

  const DailyAppBlocker({
    required this.dateSignature,
    required this.lastUpdate,
    this.dailyLimit = const Duration(milliseconds: 9000000), // 150 min default
    this.consumed = Duration.zero,
    this.sessionExpiry,
    this.currentFocusUnlockId = '',
    this.lastBlockSessionId = 'NoScroll',
    this.isActive = true,
    this.isPaused = false,
    this.pauseExpiry,
    this.cooldownExpiry,
    this.pauseDuration = Duration.zero,
    this.cooldownDuration = Duration.zero,
  });

  Duration get remaining {
    final r = dailyLimit - consumed;
    return r.isNegative ? Duration.zero : r;
  }

  bool get isQuotaExceeded => consumed >= dailyLimit;

  /// Fraction 0.0..1.0 used; clamps so callers can drive a progress bar.
  double get usedFraction =>
      dailyLimit.inMilliseconds == 0
          ? 1.0
          : (consumed.inMilliseconds / dailyLimit.inMilliseconds).clamp(0.0, 1.0);

  DailyAppBlocker copyWith({
    String? dateSignature,
    DateTime? lastUpdate,
    Duration? dailyLimit,
    Duration? consumed,
    DateTime? sessionExpiry,
    String? currentFocusUnlockId,
    String? lastBlockSessionId,
    bool? isActive,
    bool? isPaused,
    DateTime? pauseExpiry,
    DateTime? cooldownExpiry,
    Duration? pauseDuration,
    Duration? cooldownDuration,
  }) => DailyAppBlocker(
        dateSignature: dateSignature ?? this.dateSignature,
        lastUpdate: lastUpdate ?? this.lastUpdate,
        dailyLimit: dailyLimit ?? this.dailyLimit,
        consumed: consumed ?? this.consumed,
        sessionExpiry: sessionExpiry ?? this.sessionExpiry,
        currentFocusUnlockId: currentFocusUnlockId ?? this.currentFocusUnlockId,
        lastBlockSessionId: lastBlockSessionId ?? this.lastBlockSessionId,
        isActive: isActive ?? this.isActive,
        isPaused: isPaused ?? this.isPaused,
        pauseExpiry: pauseExpiry ?? this.pauseExpiry,
        cooldownExpiry: cooldownExpiry ?? this.cooldownExpiry,
        pauseDuration: pauseDuration ?? this.pauseDuration,
        cooldownDuration: cooldownDuration ?? this.cooldownDuration,
      );

  @override
  List<Object?> get props => [
        dateSignature, lastUpdate, dailyLimit, consumed, sessionExpiry,
        currentFocusUnlockId, lastBlockSessionId, isActive, isPaused,
        pauseExpiry, cooldownExpiry, pauseDuration, cooldownDuration,
      ];
}
```

`domain/entities/daily_limit_emoji_band.dart`:

```dart
enum BandAnimation { breathing, shake }

class DailyLimitEmojiBand {
  final String id;        // e.g. "daily_31_120"
  final int rangeMinMin;  // inclusive, in MINUTES
  final int rangeMaxMin;  // inclusive, in MINUTES
  final String emoji;     // e.g. "⚖️"
  final String title;     // e.g. "Healthy Balance"
  final String description;
  final BandAnimation animation;

  const DailyLimitEmojiBand({
    required this.id, required this.rangeMinMin, required this.rangeMaxMin,
    required this.emoji, required this.title, required this.description,
    required this.animation,
  });

  bool contains(int limitMinutes) =>
      limitMinutes >= rangeMinMin && limitMinutes <= rangeMaxMin;
}
```

---

## 6. Core algorithms (verified)

### 6.1 hours/minutes → budget

Verified at `DailyLimitActionsImpl.onSaveClick`: `60000 * ((hours * 60L) + minutes)`. Example: 2h30m → `60000 * (120 + 30) = 9_000_000` ms.

```dart
Duration budgetFrom(int hours, int minutes) =>
    Duration(milliseconds: 60000 * ((hours * 60) + minutes));
```

### 6.2 Midnight reset by date-signature compare (verified)

Verified at `DailyAppBlocker.refreshSignature(long)`: format `now` to `dd-MM-yyyy`; if it differs from the stored `dateSignature`, copy with **`consumedDuration` reset to 0** and the *budget preserved*; otherwise only bump `lastUpdate`. This is a **lazy reset** — there is no timer; it fires whenever the app/service touches the model.

```dart
/// Pure reset rule. Call on app start, on service tick, and on quota read.
DailyAppBlocker refreshSignature(DailyAppBlocker s, {DateTime? clock}) {
  final now = clock ?? DateTime.now();                 // device-local (see §4)
  final sig = DateFormat('dd-MM-yyyy').format(now);
  if (sig != s.dateSignature) {
    // New day: zero the consumption, KEEP the user's budget.
    return s.copyWith(
      dateSignature: sig,
      lastUpdate: now,
      consumed: Duration.zero,
      // Note: original ALSO zeroes sessionExpiry/pause/cooldown fields on
      // a new day (copy$default mask 8180 clears them). We do the same:
      sessionExpiry: null,
      pauseExpiry: null,
      cooldownExpiry: null,
      pauseDuration: Duration.zero,
      cooldownDuration: Duration.zero,
      isPaused: false,
      currentFocusUnlockId: '',
    );
  }
  return s.copyWith(lastUpdate: now); // same day: just touch lastUpdate
}
```

> Evidence on the mask: `refreshSignature` calls `copy$default(this, str, j, 0L,0L,0L, null,null, 0L,0L,0L,0L, 8180)` on a date change. `8180` clears the lower budget/consumed/session/pause/cooldown bits while preserving `dailyLimitDuration` (which is supplied as `0L` but masked back to the existing value? — *inferred*: the original passes `0L` for `dailyLimitDuration` with the mask bit set so the existing value is kept). To be safe and explicit, our Dart **preserves `dailyLimit` and zeroes only consumption + break/focus state**, which matches the documented intent ("reset consumedDuration=0, preserves dailyLimitDuration").

### 6.3 Remaining quota for the block screen (verified)

Verified at `PinBlockOverlayViewmodel$lockState$1`: integer-minute math.

```
limitMin    = dailyLimitDuration / 60000        (int)
consumedMin = consumedDuration  / 60000          (int)
remainingMin= limitMin - consumedMin
if (remainingMin < 0) remainingMin = 0           // clamp
grantMin    = min(requestedMin, remainingMin)    // cap the focus-unlock ask
```

The overlay also computes a progress fraction `consumed/limit` clamped to `[0,1]` and formats minutes via a helper `minToHHMMSS`. Our Dart:

```dart
class QuotaView {
  final Duration remaining;
  final int remainingMinutes;
  final double usedFraction; // 0..1
  const QuotaView(this.remaining, this.remainingMinutes, this.usedFraction);
}

QuotaView quotaView(DailyAppBlocker s) {
  final limitMin = s.dailyLimit.inMinutes;
  final usedMin = s.consumed.inMinutes;
  final remMin = (limitMin - usedMin).clamp(0, 1 << 30);
  return QuotaView(s.remaining, remMin, s.usedFraction);
}

/// Cap a user's "give me N more minutes" request to what's left.
int cappedGrantMinutes(DailyAppBlocker s, int requested) =>
    requested.clamp(0, s.remaining.inMinutes);
```

### 6.4 Pause / cooldown window setup (verified)

Verified at `HomeViewModel$updateAppBlockerPause$1`:

```
pauseMin  = max(requestedPauseMin, 1)
coolMin   = max(requestedCoolMin, 5)
pauseExpiry    = now + pauseMin*60000
cooldownExpiry = pauseExpiry + coolMin*60000
isPaused = true
```

```dart
DailyAppBlocker startPause(DailyAppBlocker s, {
  required int requestedPauseMinutes,
  required int requestedCooldownMinutes,
  DateTime? clock,
}) {
  final now = clock ?? DateTime.now();
  final pauseMin = requestedPauseMinutes < 1 ? 1 : requestedPauseMinutes;   // min 1
  final coolMin  = requestedCooldownMinutes < 5 ? 5 : requestedCooldownMinutes; // min 5
  final pauseEnd = now.add(Duration(minutes: pauseMin));
  final coolEnd  = pauseEnd.add(Duration(minutes: coolMin));
  return s.copyWith(
    isPaused: true,
    pauseExpiry: pauseEnd,
    cooldownExpiry: coolEnd,
    pauseDuration: Duration(minutes: pauseMin),
    cooldownDuration: Duration(minutes: coolMin),
  );
}
```

### 6.5 Cooldown-window check (verified)

Verified at `DailyAppBlocker.isInCooldownWindow(long now)`:

```
if (isPaused && pauseExpiry > 0 && now <= pauseExpiry) return false;  // in PAUSE → allow
return cooldownExpiry > 0 && cooldownExpiry > now;                     // in COOLDOWN → block
```

So the lifecycle is **PAUSE (allowed) → COOLDOWN (blocked) → normal quota rules**.

```dart
/// true ⇒ currently inside the COOLDOWN window (must block).
/// false ⇒ either inside the PAUSE window (allow) or outside all windows.
bool isInCooldownWindow(DailyAppBlocker s, {DateTime? clock}) {
  final now = clock ?? DateTime.now();
  if (s.isPaused && s.pauseExpiry != null && !now.isAfter(s.pauseExpiry!)) {
    return false; // pause active → access allowed
  }
  return s.cooldownExpiry != null && s.cooldownExpiry!.isAfter(now);
}
```

### 6.6 Focus-mode temporary unlock (inferred + verified fields)

When the user requests "N more minutes" at the block screen, the original grants a window via `sessionExpiry` + a `currentFocusUnlockId` (fields verified; the grant body in `AppMonitorService`/overlay VM is obfuscated → **inferred**). The grant is capped by §6.3 to remaining quota.

```dart
DailyAppBlocker grantFocusUnlock(DailyAppBlocker s, int requestedMinutes, {DateTime? clock}) {
  final now = clock ?? DateTime.now();
  final minutes = cappedGrantMinutes(s, requestedMinutes); // never exceed remaining
  if (minutes <= 0) return s;
  return s.copyWith(
    sessionExpiry: now.add(Duration(minutes: minutes)),
    currentFocusUnlockId: 'focus-${now.microsecondsSinceEpoch}',
  );
}

bool isFocusUnlockActive(DailyAppBlocker s, {DateTime? clock}) {
  final now = clock ?? DateTime.now();
  return s.sessionExpiry != null && s.sessionExpiry!.isAfter(now);
}
```

### 6.7 The master "should block?" decision (composed)

Pure function combining the rules. The *only* external input is "is a restricted app on screen right now?" (⚠️ native signal).

```dart
enum BlockDecision { allow, block }

BlockDecision shouldBlock(DailyAppBlocker raw, {DateTime? clock}) {
  final now = clock ?? DateTime.now();
  final s = refreshSignature(raw, clock: now); // lazy midnight reset first
  if (!s.isActive) return BlockDecision.allow;
  if (isInCooldownWindow(s, clock: now)) return BlockDecision.block; // cooldown wins
  if (s.isPaused && s.pauseExpiry != null && !now.isAfter(s.pauseExpiry!)) {
    return BlockDecision.allow; // pause window
  }
  if (isFocusUnlockActive(s, clock: now)) return BlockDecision.allow; // granted N min
  return s.isQuotaExceeded ? BlockDecision.block : BlockDecision.allow;
}
```

### 6.8 Consumption tick (⚠️ fed by native)

The original increments `consumedDuration` from inside the AccessibilityService while a restricted app is foregrounded (thread-safe with an `AtomicLong`-style accumulator). In Flutter the increment is pure, but the *cadence* comes over an `EventChannel`.

```dart
DailyAppBlocker addConsumption(DailyAppBlocker raw, Duration delta, {DateTime? clock}) {
  final s = refreshSignature(raw, clock: clock); // never accrue across midnight
  return s.copyWith(consumed: s.consumed + delta, lastUpdate: clock ?? DateTime.now());
}
```

---

## 7. Use cases (domain layer)

`domain/usecases/` — thin, each wraps the pure functions above + the repository:

| Use case | Signature | Wraps |
|---|---|---|
| `SetDailyLimit` | `Future<void> call(int hours, int minutes)` | §6.1 → repo.save |
| `GetDailyBlocker` | `Stream<DailyAppBlocker> call()` | repo stream (already refreshed) |
| `RefreshDayBoundary` | `Future<DailyAppBlocker> call()` | §6.2 → repo.save |
| `AddConsumption` | `Future<void> call(Duration delta)` | §6.8 → repo.save |
| `StartPause` | `Future<void> call(int pauseMin, int coolMin)` | §6.4 → repo.save |
| `EvaluateBlock` | `BlockDecision call(DailyAppBlocker, DateTime)` | §6.7 (pure) |
| `GrantFocusUnlock` | `Future<void> call(int requestedMin)` | §6.6 → repo.save |
| `LoadEmojiBands` | `Future<List<DailyLimitEmojiBand>> call()` | bundled asset + server override |
| `BandForLimit` | `DailyLimitEmojiBand call(int limitMin, List bands)` | §9 |

```dart
class SetDailyLimit {
  final DailyLimitRepository repo;
  SetDailyLimit(this.repo);
  Future<void> call(int hours, int minutes) async {
    final current = await repo.read();
    await repo.save(current.copyWith(
      dailyLimit: Duration(milliseconds: 60000 * ((hours * 60) + minutes)),
    ));
  }
}
```

---

## 8. Data layer & persistence

| Original | Flutter mapping | Legend |
|---|---|---|
| `DataStoreUtils` / `DataStoreBase.PrefKeys` (Jetpack DataStore) | One JSON blob in a typed box | ✅ |
| `StateFlow<DailyAppBlocker>` reactive reads | `Stream<DailyAppBlocker>` from the box's `watch()` | ✅ |
| Server-fetched emoji bands override | bundled asset + remote fetch + cache | ✅ |

Recommended package: **`hive_ce`** (community-maintained Hive, actively updated) or **`isar`** for the persisted model; **`shared_preferences`** is enough if you keep one JSON string. Reactive stream via `box.watch()`. State management = **`flutter_bloc`** (per architecture target), not Riverpod/GetX.

`data/models/daily_app_blocker_model.dart` — JSON round-trip; store `DateTime` as epoch-ms and `Duration` as ms (matches the original's long storage):

```dart
class DailyAppBlockerModel {
  static Map<String, dynamic> toJson(DailyAppBlocker s) => {
        'dateSignature': s.dateSignature,
        'lastUpdate': s.lastUpdate.millisecondsSinceEpoch,
        'dailyLimitMs': s.dailyLimit.inMilliseconds,
        'consumedMs': s.consumed.inMilliseconds,
        'sessionExpiry': s.sessionExpiry?.millisecondsSinceEpoch ?? 0,
        'currentFocusUnlockId': s.currentFocusUnlockId,
        'lastBlockSessionId': s.lastBlockSessionId,
        'isActive': s.isActive,
        'isPaused': s.isPaused,
        'pauseExpiry': s.pauseExpiry?.millisecondsSinceEpoch ?? 0,
        'cooldownExpiry': s.cooldownExpiry?.millisecondsSinceEpoch ?? 0,
        'pauseDurationMs': s.pauseDuration.inMilliseconds,
        'cooldownDurationMs': s.cooldownDuration.inMilliseconds,
      };

  static DailyAppBlocker fromJson(Map<String, dynamic> j) {
    DateTime? ms(num? v) =>
        (v == null || v == 0) ? null : DateTime.fromMillisecondsSinceEpoch(v.toInt());
    return DailyAppBlocker(
      dateSignature: j['dateSignature'] as String,
      lastUpdate: DateTime.fromMillisecondsSinceEpoch((j['lastUpdate'] as num).toInt()),
      dailyLimit: Duration(milliseconds: (j['dailyLimitMs'] as num).toInt()),
      consumed: Duration(milliseconds: (j['consumedMs'] as num).toInt()),
      sessionExpiry: ms(j['sessionExpiry'] as num?),
      currentFocusUnlockId: (j['currentFocusUnlockId'] as String?) ?? '',
      lastBlockSessionId: (j['lastBlockSessionId'] as String?) ?? 'NoScroll',
      isActive: (j['isActive'] as bool?) ?? true,
      isPaused: (j['isPaused'] as bool?) ?? false,
      pauseExpiry: ms(j['pauseExpiry'] as num?),
      cooldownExpiry: ms(j['cooldownExpiry'] as num?),
      pauseDuration: Duration(milliseconds: (j['pauseDurationMs'] as num?)?.toInt() ?? 0),
      cooldownDuration: Duration(milliseconds: (j['cooldownDurationMs'] as num?)?.toInt() ?? 0),
    );
  }
}
```

---

## 9. Emoji bands (verified JSON)

Source: `res/raw/daily_limit_emoji_bands.json`. The set `daily_limit_round_01` (placement `DAILY_LIMIT_HERO`) maps a **limit in minutes** to feedback. Verified bands:

| id | range (min, inclusive) | emoji | title | animation |
|---|---|---|---|---|
| `daily_0_0` | 0–0 | 🛑 | Total Lockdown! | `BREATHING` |
| `daily_1_30` | 1–30 | 🚀 | Laser Focus | `BREATHING` |
| `daily_31_120` | 31–120 | ⚖️ | Healthy Balance | `BREATHING` |
| `daily_121_240` | 121–240 | 🕰️ | Slipping Away... | `SHAKE` |
| `daily_241_plus` | 241–999999 | 🧟 | Doomscroller Mode | `SHAKE` |

JSON keys to parse: `emojiSets[].setId`, `.placementId`, `.enabled`, `.createdTimeStamp`, `.emojis[].{emojiId, rangeMin, rangeMax, emoji, title, description, animation}`. Animations escalate (BREATHING for sane limits, SHAKE for 121+ min) to nudge the user.

```dart
DailyLimitEmojiBand bandForLimit(int limitMinutes, List<DailyLimitEmojiBand> bands) =>
    bands.firstWhere((b) => b.contains(limitMinutes), orElse: () => bands.last);
```

Render the animation with **`flutter_animate`** (a `.shake()` / a scale "breathing" loop) — ✅ pure Dart, no native code.

---

## 10. Scheduler (time-of-day / day-of-week)

> ⚠️ **Maturity note (evidence).** In the decompiled app, `SchedulerUiState` / `SchedulerActionImpl` are **minimal/placeholder** — the scheduler subsystem appears under-developed. Treat the model below as the *intended* design, clearly marked **(inferred)**.

A schedule defines **active windows** during which blocking is enforced at all (outside a window, restricted apps are allowed regardless of quota). Model (inferred):

```dart
class ScheduleWindow {
  final Set<int> weekdays;     // DateTime.monday..sunday (1..7)
  final int startMinuteOfDay;  // 0..1439, device-local
  final int endMinuteOfDay;    // 0..1439; if end < start ⇒ crosses midnight
  final bool enabled;
  const ScheduleWindow({
    required this.weekdays, required this.startMinuteOfDay,
    required this.endMinuteOfDay, this.enabled = true,
  });

  bool isActiveAt(DateTime t) {
    if (!enabled) return false;
    final m = t.hour * 60 + t.minute;
    final dayOk = weekdays.contains(t.weekday);
    if (startMinuteOfDay <= endMinuteOfDay) {
      return dayOk && m >= startMinuteOfDay && m < endMinuteOfDay;
    }
    // crosses midnight: e.g. 22:00 → 06:00
    final tonight = dayOk && m >= startMinuteOfDay;
    final yesterday = weekdays.contains(_prevWeekday(t.weekday)) && m < endMinuteOfDay;
    return tonight || yesterday;
  }

  int _prevWeekday(int wd) => wd == DateTime.monday ? DateTime.sunday : wd - 1;
}

bool blockingActiveNow(List<ScheduleWindow> windows, DateTime now) =>
    windows.isEmpty || windows.any((w) => w.isActiveAt(now)); // empty ⇒ always on
```

Compose into §6.7: only evaluate quota when `blockingActiveNow(...)` is true; otherwise allow. Use device-local `DateTime.now()` for the same timezone reasons as §4.

---

## 11. Flutter mapping & platform legend

| Concern | Mechanism | Package / channel | Legend |
|---|---|---|---|
| Persist `DailyAppBlocker` | local DB | `hive_ce` / `isar` / `shared_preferences` | ✅ |
| Reactive quota stream to UI | box `watch()` → Bloc | `flutter_bloc` | ✅ |
| hours/minutes → millis, reset, cooldown, focus-unlock math | pure Dart | — | ✅ |
| Date formatting / day boundary | `DateFormat('dd-MM-yyyy')` (local) | `intl` | ✅ |
| Emoji band animations | shake / breathing | `flutter_animate` | ✅ |
| **Periodic** day-boundary check + tidy-up when app is closed | background worker | `workmanager` | ✅ (Android) / ⚠️ iOS BGTaskScheduler is best-effort |
| Foreground-service notification (to keep tracking alive) | low-importance channel | `flutter_local_notifications` + native FGS | ⚠️ |
| **Real-time "restricted app on screen" + consumption ticks** | native AccessibilityService / usage events | `flutter_accessibility_service` or custom `EventChannel`; `usage_stats` is coarse | ⚠️ |
| Show the block screen / overlay when quota hits 0 | system overlay | `flutter_overlay_window` + native `WindowManager` | ⚠️ |
| Reset/enforce on iOS | Screen Time | Apple `FamilyControls` / `DeviceActivityMonitor` thresholds / `ManagedSettings` | ❌ no AccessibilityService equivalent; only the restricted parental-control APIs |

**Why `workmanager` and not just a `Timer`:** the lazy reset (§6.2) already self-heals on next app open, but a daily `workmanager` periodic task makes the new-day state (and any "you have a fresh budget" notification) appear even if the user never reopens the app. Schedule it ~daily; the worker re-runs `refreshSignature` and persists.

> ⚠️ **Restated enforcement caveat.** `workmanager` callbacks cannot poll the foreground app reliably or sub-minute. The actual *minute-by-minute* consumption and the *block trigger* must come from the native foreground-app signal (AccessibilityService / UsageStats over an `EventChannel`). The Dart side only owns the **budget arithmetic and persisted state**.

---

## 12. Presentation: DailyLimitBloc (sketch)

`presentation/bloc/daily_limit/` — events, state, bloc.

```dart
// --- events ---
abstract class DailyLimitEvent {}
class DailyLimitSubscribed extends DailyLimitEvent {}
class _BlockerUpdated extends DailyLimitEvent { final DailyAppBlocker s; _BlockerUpdated(this.s); }
class LimitSaved extends DailyLimitEvent { final int hours, minutes; LimitSaved(this.hours, this.minutes); }
class PauseRequested extends DailyLimitEvent { final int pauseMin, cooldownMin; PauseRequested(this.pauseMin, this.cooldownMin); }
class FocusUnlockRequested extends DailyLimitEvent { final int minutes; FocusUnlockRequested(this.minutes); }
class ConsumptionTicked extends DailyLimitEvent { final Duration delta; ConsumptionTicked(this.delta); }

// --- state ---
class DailyLimitState {
  final DailyAppBlocker? blocker;
  final DailyLimitEmojiBand? band;
  final bool loading;
  const DailyLimitState({this.blocker, this.band, this.loading = true});
  Duration get remaining => blocker?.remaining ?? Duration.zero;
  bool get quotaExceeded => blocker?.isQuotaExceeded ?? false;
  DailyLimitState copyWith({DailyAppBlocker? blocker, DailyLimitEmojiBand? band, bool? loading}) =>
      DailyLimitState(blocker: blocker ?? this.blocker, band: band ?? this.band, loading: loading ?? this.loading);
}

// --- bloc ---
class DailyLimitBloc extends Bloc<DailyLimitEvent, DailyLimitState> {
  final GetDailyBlocker getBlocker;
  final SetDailyLimit setLimit;
  final StartPause startPause;
  final GrantFocusUnlock grantFocus;
  final AddConsumption addConsumption;
  final LoadEmojiBands loadBands;
  StreamSubscription<DailyAppBlocker>? _sub;
  List<DailyLimitEmojiBand> _bands = const [];

  DailyLimitBloc({
    required this.getBlocker, required this.setLimit, required this.startPause,
    required this.grantFocus, required this.addConsumption, required this.loadBands,
  }) : super(const DailyLimitState()) {
    on<DailyLimitSubscribed>(_onSubscribed);
    on<_BlockerUpdated>(_onUpdated);
    on<LimitSaved>((e, _) => setLimit(e.hours, e.minutes));
    on<PauseRequested>((e, _) => startPause(e.pauseMin, e.cooldownMin));
    on<FocusUnlockRequested>((e, _) => grantFocus(e.minutes));
    on<ConsumptionTicked>((e, _) => addConsumption(e.delta));
  }

  Future<void> _onSubscribed(DailyLimitSubscribed e, Emitter emit) async {
    _bands = await loadBands();
    await emit.forEach<DailyAppBlocker>(getBlocker(),
        onData: (s) => state.copyWith(
              blocker: s, loading: false,
              band: bandForLimit(s.dailyLimit.inMinutes, _bands),
            ));
  }

  void _onUpdated(_BlockerUpdated e, Emitter emit) =>
      emit(state.copyWith(blocker: e.s, band: bandForLimit(e.s.dailyLimit.inMinutes, _bands)));

  @override
  Future<void> close() { _sub?.cancel(); return super.close(); }
}
```

---

## 13. Worker callback sketch (workmanager)

`data/workers/daily_reset_worker.dart` — runs the lazy reset off the UI, fires a "fresh budget" notification on a real day change.

```dart
import 'package:workmanager/workmanager.dart';

const kDailyResetTask = 'daily_limit.reset';

@pragma('vm:entry-point')
void workmanagerCallbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task != kDailyResetTask) return true;
    // 1. Re-open DI/storage in the background isolate.
    final repo = await DailyLimitRepositoryFactory.create();
    // 2. Pure lazy reset (§6.2) using DEVICE-LOCAL now (§4).
    final before = await repo.read();
    final after = refreshSignature(before);            // device-local midnight
    if (after.dateSignature != before.dateSignature) {
      await repo.save(after);
      await LocalNotifier.show(
        title: 'New day, fresh limit',
        body: 'Your screen-time budget reset.',
      );
    } else {
      await repo.save(after); // bump lastUpdate
    }
    return true;
  });
}

Future<void> scheduleDailyReset() async {
  await Workmanager().initialize(workmanagerCallbackDispatcher);
  await Workmanager().registerPeriodicTask(
    'daily-reset-unique',
    kDailyResetTask,
    frequency: const Duration(hours: 12), // Android floor is 15 min; 2×/day catches the boundary
    existingWorkPolicy: ExistingWorkPolicy.keep,
    constraints: Constraints(networkType: NetworkType.notRequired),
  );
}
```

> ⚠️ Android throttles periodic work to a 15-minute minimum and may defer it under Doze; the **lazy `refreshSignature` on every read remains the source of truth**. The worker is a convenience for notifications and closed-app freshness, not the authoritative reset.

---

## 14. Testing checklist (pure-Dart, no device)

- Budget conversion: `budgetFrom(2,30).inMilliseconds == 9000000`.
- Reset: same-day read keeps `consumed`; cross-day read zeroes `consumed`, keeps `dailyLimit`, clears pause/cooldown/focus.
- Reset uses device-local day, not UTC (inject a fixed `clock` straddling local midnight vs UTC midnight to prove the difference).
- Pause floors: request `(0, 0)` → stored `(1 min pause, 5 min cooldown)`.
- Window order: at `now < pauseExpiry` → allow; `pauseExpiry < now < cooldownExpiry` → block; `now > cooldownExpiry` → fall through to quota.
- Focus-unlock cap: requesting 60 min with 10 min remaining grants ≤ 10 min.
- `shouldBlock` precedence: cooldown > pause > focus-unlock > quota.
- Emoji band edges: 0→🛑, 30→🚀, 31→⚖️, 120→⚖️, 121→🕰️, 240→🕰️, 241→🧟.

---

## Related docs

- `01-architecture-overview.md`
- `04-accessibility-engine.md` — the native foreground/consumption signal that feeds this subsystem
- `05-blocking-modes-and-plans.md` — `PlansEnum` (BLOCK_ALL / CURIOUS / ONE_REEL / PAUSED) gating that wraps quota
- `06-overlay-and-block-screen.md` — the block/PIN overlay that reads remaining quota and requests focus unlocks
- `08-persistence-and-datastore.md` — local storage backing `DailyAppBlocker`
- `09-foreground-service-and-lifecycle.md` — service hosting tracking + workmanager scheduling
