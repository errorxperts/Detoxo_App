# Content Counter (Reel/Short Counter)

The **content counter** tallies the short-form videos (Reels, Shorts, and other
infinite-feed clips) the user actually watches, and surfaces that number three
ways: the in-app Activity figures, a draggable **floating bubble** overlay, and
**six home-screen widget designs** (Count, Next colour, Time limit, Rhythm,
Bonsai, Bento), each resizable across Small / Medium / Large. It is deliberately **decoupled from blocking** — a
side-effect-free counting pass runs *before* the block logic and tallies reels
whether blocking is master-off, paused, or the app/platform is disabled. The
counter is **enabled by default** (awareness-first), independent of whether any
blocking plan is active.

> Blocking, detection, and the accessibility service that hosts this counter are
> covered in [03-detection-engine.md](03-detection-engine.md) and
> [05-plans-pause-conscious.md](05-plans-pause-conscious.md). This doc covers only the counter.

---

## 1. Architecture at a glance

```
AccessibilityService (main process, single thread)
   │  onAccessibilityEvent()
   │     ├─ countContent(event, pkg)      ← runs FIRST, side-effect-free
   │     └─ (block logic, only if masterEnabled & not paused)
   ▼
ContentCounter.kt          fan-out + bubble visibility; owns the one tracker timer
   ├─ ReelTracker.kt           WHEN a distinct reel is counted (page identity + dwell; pure Kotlin, unit-tested)
   ├─ ContentCounterStore.kt   persists to SharedPreferences "detoxo_engine_prefs"
   ├─ ContentCounterBubble.kt  floating overlay (WindowManager)
   │    └─ overlay/bubble/     BubbleView shell + BubbleModel/Envelope/Look + 10 BubbleFace
   │                           (generated BubbleTokens; font widget/Manrope.kt)
   └─ widget/ReelWidgetSync.kt the ONE widget-payload writer (IM-01), budgeted pushes
        ├─ WidgetPayload.kt / WidgetModel.kt   wire payload + every display value (pure)
        ├─ HomeWidgets.kt      worker, 6 providers, per-instance render, pin, tap
        └─ WidgetBitmapRenderer.kt → WidgetFace ×6 → WidgetPainter (Canvas bitmap)

MethodChannel "com.errorxperts.detoxo/commands"     (pull / toggles / style)
EventChannel  "com.errorxperts.detoxo/events"        contentCounted {...}
   ▼
Dart feature lib/features/content_counter/**
   ├─ content_counter.dart        public barrel (entities, contracts, cubits, card, previews)
   ├─ content_counter_core        ContentCount, cubits, live card, repos
   ├─ content_counter_bubble      BubbleStyle + bubble on/off + overlay perm
   ├─ home_content_counter        WidgetPayload/WidgetModel mirrors, faces, WidgetPreview,
   │                              tap listener, HomeWidgetRepository (pin/push/payload/tap)
   └─ content_counter_appearance  Bubble-style + Home-widget editor screens
```

The Dart feature follows the same feature-first Clean Architecture as the rest of
the app (data / domain / presentation, wired via `get_it` locator `sl` in
`lib/core/di/injector.dart`, Cubits only). The **native store is the single
source of truth**: the bubble and widget stay correct even when the Flutter UI is
dead, because the counting brain writes SharedPreferences and pushes the surfaces
directly.

---

## 2. The counting pass (native, independent of blocking)

### 2.1 Where it runs

In `DetoxoAccessibilityService.onAccessibilityEvent`, counting is invoked before
any block gate:

```kotlin
if (pkg == packageName) return
// ── Awareness counting: runs independent of blocking (master-off /
//    paused / platform-disabled) and is strictly side-effect-free ──
if (contentCounter.isEnabled) countContent(event, pkg)
if (!store.masterEnabled) return                 // block path gated AFTER counting
if (System.currentTimeMillis() < store.pauseUntil) return
```

`countContent(...)` **never presses back and never reads or writes block state**.
It reuses the same read-only 3-stage `matches()` view-id search the blocker uses,
but only to answer "is a reel surface on screen right now?". It has its own
per-package throttle (`lastCountEventByPackage`, `COUNT_THROTTLE_MS = 400`,
slower than the block path's 150 ms because a stage-3 miss on a non-reel screen
is a full DFS and nothing about a reel's dwell is anchored to this check;
`TYPE_WINDOW_STATE_CHANGED` bypasses it so reel entry/exit is seen at once).
Scroll events are forwarded **before** that throttle, with the pager's own
`fromIndex` / `toIndex` / `scrollDeltaY` (API 28+) — the reel's identity (§2.3).
Setting `adb shell setprop log.tag.DetoxoService DEBUG` logs the raw scroll
fields per event for per-app calibration; the switch is read once per service
bind (`scrollDebug`), so re-bind the service after setting the property.

**DFS back-off (EVO-021).** On a non-reel screen every check is a miss, and a
miss used to end in the full stage-3 walk. The pass keeps a per-package
consecutive-miss counter (`countMisses`, cycling `0..DFS_SKIP = 4`): the DFS
runs only when it is 0, so on the feed it walks at most every 5th check (2 s)
while stages 1–2 (`findAccessibilityNodeInfosByViewId` under
`flagReportViewIds`) still run every check. A hit and every
`TYPE_WINDOW_STATE_CHANGED` reset it. Shallow results are computed with
`matches(..., deep = false)` and **bypass the per-event memo**, so the block
pass — which never backs off — always gets a full answer.
`ponytail:` a surface only the DFS finds (an id the app's own `Resources`
can't resolve) is seen ≤ 2 s late.

Foreground changes are forwarded separately from `TYPE_WINDOW_STATE_CHANGED`.
The soft keyboard's window emits this event under the IME's own package
(`Settings.Secure.DEFAULT_INPUT_METHOD`), which is **not** a foreground change to
the counter — typing a comment must not suspend the reel:

```kotlin
if (contentCounter.isEnabled && !isImePackage(pkg)) {
    contentCounter.onForegroundChanged(
        pkg,
        !pkgProtected && config.platformsFor(pkg).any { isReelPlatform(it) },
    )
}
```

### 2.2 What counts as a "reel surface" — `isReelPlatform` + `NON_REEL_PLATFORM_IDS`

Counting reuses the pushed `platforms_config.json` (parsed by
`engine/DetectionConfig.kt`; see [03-detection-engine.md](03-detection-engine.md)).
A platform is treated as a countable reel/short surface only when:

1. its `detectionType` is `LEGACY` or `OVERLAY`, **and**
2. it has at least one `FINDBYID` / `VIEWID_RES_NAME` detector, **and**
3. its `platformId` is **not** in `NON_REEL_PLATFORM_IDS`.

The exclusion set keeps feeds, stories, and statuses out of the reel tally
(they are watched content but not "reels"):

```kotlin
private val NON_REEL_PLATFORM_IDS = setOf(
    "ig_feed", "ig_stories", "insta_pro_stories", "insta_pro2_stories",
    "snap_stories", "wa_status", "wab_status",
)
```

Everything else detectable in a supported app is treated as a reel/short.

### 2.3 Distinct-reel rule (settled-page identity + dwell) — `ReelTracker.kt`

The decision lives in `engine/ReelTracker.kt`, a pure-Kotlin state machine
(no Android imports; every call takes a monotonic `now` — `SystemClock.uptimeMillis`
in production: the Handler's own clock, which stops in deep sleep so a phone that
slept mid-reel can't wake up owing a dwell; usage-time deltas use the same clock)
driven by `ContentCounter.kt`, which owns the single `Handler`
runnable (`tickRunnable`, re-armed by `syncTimer()` from `tracker.nextDueAtMs`)
and the fan-out. State mutates only on the service's main thread. Signals:

| Signal | Fired when | Tracker effect |
| --- | --- | --- |
| `onForegroundChanged(pkg, isReelApp)` | window-state change to a new package (never the IME) | `suspend()` — keeps the session, freezes the dwell; a return within `AWAY_EXPIRY_MS = 60s` resumes the same reel, later = fresh session. Hides the bubble unless the new package **is** the session's own app — another reel-capable app's feed included (its non-reel screens are not leave-evidence, so this is the only hide on that path; `onReelSurfaceSeen` re-shows it) |
| `onReelSurfaceSeen(pkg)` | a reel surface is detected on screen | `surfaceSeen()` — starts / resumes / continues the session; clears no-surface evidence; shows the bubble |
| `onNoReelSurface(pkg)` | a monitored app's window was checked and had **no** reel surface (e.g. the feed) | Only for the **session's own app**: `noSurface(pkg)` stamps the reel's end; after `HIDE_GRACE_MS` one runnable hides the bubble **and** `leave()`s the session. Works with the bubble off. Another monitored app's window (a WhatsApp reply — `wa_status` makes WhatsApp a monitored package — or the YouTube feed) is a detour handled by `suspend`, and is ignored here so the return doesn't recount the reel |
| `onScroll(pkg, fromIndex, toIndex, deltaY, isPager)` | `TYPE_VIEW_SCROLLED` in a reel app (pre-throttle) | `scroll()` records the latest snapshot; classified once the burst is quiet for `SCROLL_SETTLE_MS = 300`. `isPager` (EVO-024) is the platform's verdict on the scrolled view when it declares a `pagerViewId` — `false` makes the snapshot an inner scroll whatever its indices; `null` (no id declared, or no event source) classifies as usual |
| `setEnabled(false)` | counter toggled off | `leave()` (the fan-out is gated, nothing lands) |

**Identity.** A reel is `(pkg, session, page)`. `page` comes from the fields a
pager already puts on every scroll event (RecyclerView / ViewPager:
`fromIndex..toIndex` = visible adapter positions), via `ReelTracker.settledPage`:

- `toIndex − fromIndex ≤ 1` → page = `fromIndex`. A pixel-exact pager reports
  `(n, n)`, one with a 1 px peek reports `(n, n+1)` even at rest — both shift by
  one per advance, so `fromIndex` is stable either way. A different page than the
  current reel = **advance** (the dwell anchor is the scroll event time, not the
  settle time); the same page (snap-back) is ignored.
- `toIndex − fromIndex ≥ 2` → a multi-item list (comments, grids) → ignored.
- `fromIndex = −1` (ScrollView / custom view) → ignored in an app whose pager has
  reported pages (a caption expand); otherwise legacy any-scroll = advance,
  debounced by the dwell (unindexed pagers, e.g. Snapchat).
- The entry reel's page is unknown until the first settle: if that settle
  finished moving backwards (`scrollDeltaY < 0`, a forward-peek snap-back) the
  page is learned without advancing.

The system keeps one pending scroll event per service and restarts its 100 ms
timer on each new one, so a fling often delivers only its final snapshot — the
last event of a burst *is* the settled state, and intermediate deltas are lossy
(hence no delta-sum heuristics).

**Counting.** A reel counts once it has been the current page for
`MIN_VIEW_MS = 1000ms` with no leave-evidence — stopped on, not flicked past.
Passive, event-quiet playback counts (there is no staleness check). At tick
time, if `PowerManager.isInteractive` is false the dwell is *paused* (anchor
zeroed, session kept) and resumes from the next `surfaceSeen` after unlock.
Leave-evidence — the next settled page, the first `noSurface` stamp, an app
switch, disable — ends the reel with a belt-and-braces count when it had earned
its dwell (the end time is the first `noSurface` stamp, never the grace expiry).
A per-session `countedPages` set stops a scroll back up from recounting; a
scroll on the way out of reels can't start a countable reel because only a fresh
`surfaceSeen` clears no-surface evidence.

**Ceilings** (`ponytail:` in the file KDoc): a one-or-two-item inner list
settles like a page — on platforms without a `pagerViewId` (EVO-024; with one
declared, scrolls from any other view are ignored as page evidence — no ids are
shipped until device calibration supplies them); unindexed pagers fall back to
any-scroll + debounce; the entry page is guessed as `firstPage − 1`; holding a
*backward* peek for a whole dwell reads as the previous page. Each ≤ 1
phantom/miss per occurrence.

The rule is surfaced to the user as "counts once you've stopped on it for about
a second; flicks, half-swipes and scrolling the comments are ignored, and the
same reel never counts twice" (FAQ, product overview, walkthroughs). The One
Reel allowance keeps its own 2 s "watched" dwell in the service.

Tests: `android/app/src/test/kotlin/com/errorxperts/detoxo/engine/ReelTrackerTest.kt`
(plain JUnit4, 23 timeline scenarios incl. the monitored-detour and
non-pager-scroll cases) —
`cd android && ./gradlew :app:testDebugUnitTest --tests '*ReelTrackerTest*'`
(also run by `bash tool/dev.sh precommit`).

### 2.4 Bubble visibility (positive-evidence hide)

The bubble is **shown** by `onReelSurfaceSeen` and stays up the entire time the
user watches — even during a passive, event-quiet video, because a detection gap
never hides it. It is **hidden only on positive evidence** the user left reels:

- `onNoReelSurface` (a checked window with no reel surface, e.g. the feed) → a
  single graced hide after `HIDE_GRACE_MS = 1500ms` (bridges between-reel
  transitions without flicker); the same runnable ends the reel session, so the
  grace also gates counting and runs whether or not the bubble is showing, or
- `onForegroundChanged` to another real app → immediate hide.

Our own overlay window and system UI are ignored (`TRANSIENT_PKGS`) so the bubble
can never self-toggle into a show/hide loop.

### 2.5 Fan-out on each count

`count(pkg)` does four things:

1. `store.recordCount(pkg, dateKey(), hour(), pendingUsageMs)` — **one** prefs edit
   persists the count *and* the batched usage window (so the event's
   `timeTodayMs` includes the accumulated-but-unwritten time) and returns the
   snapshot built from the maps it already parsed. A count used to cost three
   `apply()`s and four JSON parses (usage flush + count + snapshot).
2. Emit the `contentCounted` event on `ServiceEventBus` (see §4).
3. **The widget budget (IM-03).** `ReelWidgetSync.push(COUNT)` only when
   `WidgetPayload.shouldPushOnCount(today - 1, today)` — the count crossed a
   multiple of 10 (`PUSH_EVERY_REELS`) or changed the tier (the first reel, then
   every 100). Each push is a build + prefs write on the widget worker, never on
   this thread. `ponytail:` the widget lags the bubble by up to 9 reels; leaving
   Detoxo (`BACKGROUND`) and the watchdog (`HEARTBEAT`) catch it up (§5.2).
4. If the bubble is enabled and visible, `bubble.onCounted(today)` (springy pop).

All timing in `ContentCounter` is `SystemClock.uptimeMillis` (`mono()`); the
wall clock is only read through `DateKeys.today()`, which is memoised per
wall-clock minute (a per-check zone lookup + format was the largest allocation
on the surface-check path).

The emitted `contentCounted` payload also carries `timeTodayMs` (§2.6, §4) and
the real `enabled` / `bubbleEnabled` flags — Dart's stream mapper defaults
missing flags to `true`, which used to corrupt the toggles' state on a streamed
update.

### 2.6 Whole-app usage-time accrual (`onAppActivity`)

Alongside reel counting, the pass tracks **screen time spent in monitored social
apps** — the signal behind the dashboard's screen-time ring and the bubble's
tap-to-show timer. It needs **no new Android permission**; it rides the existing
AccessibilityService. `countContent` calls `contentCounter.onAppActivity(pkg)` for
**every** event from a package that has any configured platform (feed / stories /
DMs / reels — deliberately broader than the reel-surface set of §2.2), *before* the
per-package throttle.

`onAppActivity` accrues the gap between consecutive events from the **same**
monitored app, but only when that gap is under `USAGE_ACTIVE_GAP_MS = 12000ms`; a
longer silence (screen off / user away → no events) starts a fresh window and is
not counted, and a switch to a different package restarts the window. Accrued
deltas are **batched in memory** (`pendingUsageMs`) and flushed via
`store.recordUsage(pendingMs, dateKey())` into `cc_time_today` /
`cc_time_total` (§3) at `USAGE_FLUSH_MS = 5000ms`, on app switch, on
protected-app foreground, on every snapshot pull, and on dispose — previously
one SharedPreferences write per accessibility event at scroll frequency.
Ceiling: ≤ 5 s of usage lost on a hard process kill, and a flush straddling
midnight attributes up to the pending window to the wrong day.

> **Known ceiling (`ponytail:`).** This counts active, event-bearing time and
> deliberately **undercounts truly passive, event-quiet playback** (a silent long
> video fires few accessibility events). The documented upgrade path is a 1 Hz
> foreground ticker while a monitored app is front-most (mirroring the Conscious
> accountant).
>
> **This ceiling is still live.** Insights ([28](28-insights.md)) does not fix it
> — it sidesteps it, by reading the OS's own `UsageStatsManager` figure for a
> *different* purpose (whole-device screen time). The two numbers measure
> different things and are both shown: `cc_time_today` is time in monitored
> social apps as the accessibility pass saw it, and insights' `screenTimeMs` is
> every app as Android recorded it. Reconciling the first against the second —
> and only then editing this comment — is deliberately left as separate work.
> Nothing in this section changed.

---

## 3. Persistence — `ContentCounterStore` (`detoxo_engine_prefs`)

`ContentCounterStore.kt` owns storage only (SRP — the *when-to-count* decision is
`ContentCounter`'s). It shares the same `detoxo_engine_prefs` SharedPreferences
file as `engine/ConfigStore.kt`, so the service, `channels/CommandHandler.kt`, and
the widget all read one source of truth. Keys:

| Key | Type | Meaning |
| --- | --- | --- |
| `cc_enabled` | bool (default **true**) | master on/off for counting |
| `cc_bubble_enabled` | bool (default **true**) | may the floating bubble show |
| `cc_bubble_x` / `cc_bubble_y` | int (`-1` = unset) | the **collapsed body's** top-left in px (unset → right dock at 30 % height) |
| `cc_date` | string `dd-MM-yyyy` | day the "today" buckets belong to (shared by counts **and** usage time) |
| `cc_today` | int | today's reel count |
| `cc_total` | int | all-time reel count |
| `cc_time_today` | long (ms) | today's whole-app foreground time in monitored apps (§2.6) |
| `cc_time_total` | long (ms) | all-time whole-app foreground time |
| `cc_per_app_today` | JSON `{pkg:count}` | today per-app breakdown |
| `cc_per_app_total` | JSON `{pkg:count}` | all-time per-app breakdown |
| `cc_bubble_style` | JSON string | persisted `BubbleStyle` (see §6) |
| `cc_widget_style` | JSON string | persisted `WidgetStyle` — only its `theme` is read now (`widgetTheme()`, legacy `SYSTEM`/`LIGHT`/`DARK` accepted); the old background/density/line keys ride along unread |
| `cc_brand_light` / `cc_brand_dark` | int (ARGB) | the app theme's primary in each brightness (`setCounterStyle(brandLight:, brandDark:)`): the widgets take the one of their theme, the bubble the device's (`store.brand(dark)`), the block screen the one of its resolved brightness ([25](25-block-screen.md) §5). Unset: the pre-split `cc_brand`, then `BrandTint.FALLBACK` (the old glass navy) |
| `cc_hourly_today` | CSV of 24 longs (ms) | today's usage time per local hour — the Rhythm face's bars. Written by `recordCount` / `recordUsage` with the hour, zeroed by the shared `cc_date` rollover |
| `cc_reel_limits` | JSON array | mirror of the `pushRules` snapshot's **reel-meter** entries only (`RuleEngine.reelMetersJson`), so Time limit can show the soonest limit with the service down. Empty until the first `pushRules` after an upgrade (`ponytail:`) |
| `widget_payload` | JSON (IM-02, 9 keys) | the last payload `ReelWidgetSync` wrote — what every pinned widget draws (§5.2) |
| `widget_rendered_key` | string | `WidgetPayload.visibleKey` of the last full render; an equal key skips the redraw |
| `widget_previews_version` | long | the versionCode whose Android 15+ picker previews were published |

> `cc_enabled` / `cc_bubble_enabled` are cached per `ContentCounterStore`
> instance (the service gates every event on `enabled`, so the hot path never
> takes the prefs lock). Safe because every writer also goes through the live
> service's instance: `CommandHandler` writes its own store *and* calls
> `contentCounter.setEnabled` / `setBubbleEnabled`.

**Day rollover** is keyed off the **single shared `cc_date` marker** — the reel
counts and the usage-time buckets roll over together — and is handled two ways:

- **Durable** reset, by whichever writer turns the day over. When the stored
  `cc_date` differs from today, `recordCount` zeroes `cc_today`,
  `cc_per_app_today` **and `cc_time_today`** before its increment; symmetrically
  `recordUsage` (the usage-time writer) zeroes `cc_today` and `cc_per_app_today`
  before adding time. Because `cc_date` gates *both* features, whichever writer
  rolls the day must zero the other feature's today bucket too, or a same-day read
  after that write would return yesterday's value.
- **Read-time** rollover: `snapshot` and `todayCount` (and `timeTodayMs`) report
  `today = 0` / `timeTodayMs = 0` and an empty per-app-today map **without
  writing** when the stored day is stale, so a snapshot pulled just after midnight
  is correct even before the day's first event.

`widgetSource(dateKey)` is the widget writer's one typed read (today, time
today, hourly seconds capped at 3600 each, reel limits, theme, enabled, total),
with the same read-time rollover. `snapshot(dateKey)` returns the map consumed everywhere:
`{enabled, bubbleEnabled, today, total, date, perAppToday, perAppTotal,
timeTodayMs, timeTotalMs, bubbleStyle, widgetStyle}`.

---

## 4. Platform channel surface

Channels are defined in `lib/core/constants/channel_constants.dart` and wrapped by
`lib/core/platform_channels/engine_channel.dart` (which no-ops off Android via
`PlatformCapabilities`). Commands are handled in `channels/CommandHandler.kt`.

### Commands (MethodChannel `…/commands`)

| Method | Dart wrapper | Native behavior |
| --- | --- | --- |
| `contentCounterSnapshot` | `contentCounterSnapshot()` | prefers the live service's in-memory snapshot; falls back to `ContentCounterStore(context).snapshot(...)` when the service is dead |
| `setContentCounterEnabled` | `setContentCounterEnabled(enabled:)` | writes `store.enabled` **and** calls `contentCounter.setEnabled` on the live service; a missing/malformed `enabled` is a no-op (`false`), never a silent "on" |
| `setContentBubbleEnabled` | `setContentBubbleEnabled(enabled:)` | writes `store.bubbleEnabled` **and** `contentCounter.setBubbleEnabled`; same no-op rule |
| `refreshContentWidget` | `refreshContentWidget({reason})` | `{reason: "refresh" \| "background"}` → `ReelWidgetSync.push(REFRESH \| BACKGROUND)`; a refresh also publishes the Android 15+ picker previews (once per versionCode). Replies `null` |
| `contentWidgetPayload` | `contentWidgetPayload({demo})` | a **fresh, unstored** `ReelWidgetSync.build(demo)` as IM-02 JSON text, built on the widget worker — the in-app previews' data, so a preview never moves the pinned widgets. `demo` null = demo until the first reel is ever counted. A failed build replies `null` (Dart: the Empty payload) |
| `takePendingWidgetTap` | `takePendingWidgetTap()` | read-and-clear `MainActivity.pendingWidgetTap`, `"FAMILY\|SIZE\|TARGET"` (like `takePendingUnblock`) |
| `setCounterStyle` | `setCounterStyle(bubble:, widget:, brandLight:, brandDark:)` | persists only the present key(s) (`as? Map`, a malformed one is skipped) and live re-renders **only that surface**: `bubble` → `onStyleChanged`, `widget` → `push(SETTINGS)` (only its `theme` is read); `brandLight` / `brandDark` (ARGB, each only when it changed) → `cc_brand_light` / `cc_brand_dark`, then both surfaces |
| `pinContentWidget` | `pinContentWidget({family})` | `HomeWidgets.requestPin(family)` on the worker — `requestPinAppWidget` on that family's provider, its dialog showing the family's demo face (`EXTRA_APPWIDGET_PREVIEW`). Absent family = `COUNT`; an unknown token or a launcher that can't pin → `false` |
| `pushRules` (side effect) | `pushRules(json)` | besides the rule engine (see [27](27-rules-engine.md)), `ReelWidgetSync.onRules` mirrors the reel meters into `cc_reel_limits` and pushes `SETTINGS` only when the soonest limit changed |
| `setContentCounterEnabled` (side effect) | — | also `push(SETTINGS)`, so "Turn on tracking" clears |

`setCounterStyle` sends only the keys present (`{'bubble': ?bubble, 'widget': ?widget,
'brandLight': ?brandLight, 'brandDark': ?brandDark}`), so a bubble edit doesn't re-push
the widget style and vice-versa. `main.dart`'s `_BrandSync` (inside the `MaterialApp`
builder) pushes both primaries — `brandFor(background, brightness).primary` for the
light and the dark background — when either background changes. Native picks per
surface, so a device brightness flip needs no push: `DetoxoAccessibilityService.
onConfigurationChanged` re-renders the widgets and rebuilds the visible bubble.

**Every tier in the theme's hue (`BrandTint`).** The counter has no colour system
of its own (user decision 2026-10-15, superseding the boards' DS-01/02 green → red
tier palette; tier thresholds are unchanged). Dart
`content_counter_core/domain/brand_tint.dart` and Kotlin `widget/BrandTint.kt`
keep only the brand's hue and saturation (capped) and produce two kinds of colour:

- `at(brand, lightness)` — a fixed lightness per role, for tier 0: the bubble
  glass (`glassTo` 0.945, `glassRing` 0.83, `glassInk` 0.29, `glassHalo` 0.676 @
  `0x29`, `glassShadow` 0.49 @ `0x61`; the gradient still starts white) and the
  light widget's empty tile (`tileLight` 0.94) and count (`countLight` 0.34).
- `ramp(brand, brightness, [saturation])` — the **usage ramp**: a fixed target
  *brightness* (`.2126 r² + .7152 g² + .0722 b²`, a squared gamma) per tier, the
  lightness found by a 24-step bisection. Fixed brightness, not fixed lightness,
  because at one HSL lightness a mint primary is ~2.4× brighter than an indigo
  one; this way every theme's ramp reads alike and keeps its ink. Plain
  arithmetic only (no `pow`), so both languages land on the same ints. Tables:
  `tileFrom` / `tileTo` (light tile gradient and bubble body, tiers 1–5, pale →
  deep; dark ink on 1–3, white on 4–5), `accentDarkY` / `accentDarkS` (the dark
  theme's count / fill / glow, tiers 0–5, calm → vivid by saturation), `dotLight`
  (Bento's dot and Bonsai's health bar on a light module, tiers 0–5).

Consumers: `BubbleLook.of(tier, brand)` (all six looks cached per brand),
`tileLook` / `darkAccent` / `tierDot` / `bentoLook` / `bonsaiLook(…, brand)` and
Kotlin `Ink.tier` / `darkAccent` / `dot` / `bento` / `bonsai(…, brand)`. Bonsai's
tree (leaves, blossom, pot, face) and the Mascot's eyes / blush / water keep their
own colours. `test/fixtures/brand_tints.json` (18 brands × 7 roles + every ramp
tier, generated by an independent Python model) pins both languages;
`test/counter_ramp_test.dart` holds every `brandFor` primary to its contrast (tile
ink and muted labels ≥ 4.5:1 at both gradient ends, each tier a visible step
deeper, dark accents ≥ 4.5:1 on every dark surface, light dots ≥ 3:1 on white).
The previews take the same value native will draw with — `counterBrand(context,
brightness)` (`content_counter_core/presentation/counter_brand.dart`): the widget
preview in its own Light / Dark theme, the bubble preview in the device's.

### Event (EventChannel `…/events`, `type = contentCounted`)

Emitted on every counted reel:

```
{ type: "contentCounted", package, today, total, perAppToday, perAppTotal,
  timeTodayMs, enabled, bubbleEnabled }
```

`timeTodayMs` is today's whole-app usage time (§2.6). `enabled` /
`bubbleEnabled` carry the real toggle values because Dart's stream mapper
defaults missing flags to `true`. The `contentCounterSnapshot`
pull reply additionally carries `timeTotalMs`; no new method/event name was added.

`ContentCounterRepositoryImpl.watch()` yields an initial pull, then re-maps each
`contentCounted` event into a `ContentCount` for the live UI.

---

## 5. The two native surfaces

### 5.1 Floating bubble — `overlay/ContentCounterBubble.kt` + `overlay/bubble/`

- Hosted inside the **existing accessibility service** — no new
  service. All view ops run on the main `Looper`.
- `WindowManager` overlay: `TYPE_APPLICATION_OVERLAY` (API 26+) with a
  `TYPE_PHONE` fallback pre-O; flags `NOT_FOCUSABLE | NOT_TOUCH_MODAL |
  LAYOUT_NO_LIMITS`. **No-ops without `Settings.canDrawOverlays`** — counting
  still works, only the overlay is skipped, and a once-per-process `Log.w`
  ("bubble suppressed: overlay permission missing") leaves a trace so a revoked
  grant doesn't read as "the counter stopped".
- **Steady-state fast path + revoke recovery**: `show()` checks
  `shown && view.isAttachedToWindow` *before* the `canDrawOverlays` binder
  call, so the per-detection IPC is gone while the window is alive — and the
  attach check is what makes a **revoke → re-grant** re-attach the bubble
  instead of updating a detached view forever (the OS removes the window on
  revoke but the fields survive). A detached-but-tracked view is torn down via
  the private `detach()` (shared with `hide()`) before re-adding.
- **Day key**: the bubble's `dateKey()` uses the shared engine
  `DateKeys.today()` (its private `SimpleDateFormat` was the last holdout;
  the shared formatter is timezone-change correct).
- **Anchor, drag, snap.** `cc_bubble_x/y` persist the **collapsed body's
  top-left** in px (`-1` = unset → right dock at 30 % of the screen height); the
  window itself is the body plus the current state's **envelope**
  (`overlay/bubble/BubbleEnvelope`, pure + unit-tested: glow 12 dp, +24 dp while
  the tier-up pulse runs, a pill strip above while the time pill shows, the
  timer's width on the **inward** side while open).
  `windowRect(anchor, side, state, screen)` subtracts the outsets from the
  anchor, so **the body never moves on screen when the envelope changes**; each
  envelope change is one `relayout()` (`updateViewLayout`). Dock side = anchor
  centre vs the screen centre. A drag moves the anchor (it folds an open timer
  first); on release the bubble springs (`ValueAnimator`, 240 ms) to the nearest
  side, **12 dp** from the edge (Drop: 0 — it clings), Y clamped to **20–70 %** of
  the screen height, and persists. A stored anchor in range survives (no
  migration from the old window-based x/y).
- **One tap, nothing else.** A touch-down scales the body to 0.9; a release
  without a drag **toggles count ↔ timer**. There is no `GestureDetector`, no
  double tap, and nothing opens the app from the bubble. The open body widens
  inward over 480 ms (overshoot spring) from the docked edge to 136 dp
  (< 1 h), 156 dp (≥ 1 h) or 176 dp for the dial styles that keep their dial
  (Ring, Hourglass, Bezel) — `BubbleModel.timerWidth`. The timer reads the
  **`watchMs` provider** the host is constructed with
  (`ContentCounter` passes `store.timeTodayMs(dateKey()) + pendingUsageMs`, so
  the unflushed usage tail is included) and, while open, a **1 Hz `Handler`
  tick** steps the display by `BubbleGeometry.nextShownSeconds` (`ponytail:` the
  store accrues only between events < 12 s apart, so the display leads it by at
  most 12 s and follows a drop, e.g. midnight, immediately). The bubble no
  longer uses `UsageLadder` — colour is the **tier** in the theme's hue (below).
- **Time pill.** A white pill (ink `#111A2E`, 1 px outline in the tier ring
  colour) 8 dp above the body shows the short watch time (`48m`, `1h 12m`,
  `2h`) for **3 s on appear and on each tier-up**, then folds down; hidden
  while the timer is open. Under reduce motion it shows and hides instantly.
- **Colour = tier, in the theme's hue.** `tier = min(5, count ÷ 100 + 1)` (0 at
  0 reels), the same tier as the home widgets, resolved by `BubbleLook`: tier 0 is
  the glass, tiers 1–5 the usage ramp shared with the widget tiles (`BrandTint`,
  above), all in the app theme's primary for the **device's** brightness
  (`cc_brand_light` / `cc_brand_dark`), so it follows the selected backgrounds.
  A tier **up** cross-fades the look
  over 700 ms and fires **one** 1.1 s ring pulse (plus the pill); a tier
  **down** (midnight reset) cross-fades only. A new reel pops the count
  (1 → 1.18 → 1, 420 ms); appear is a 500 ms scale/fade spring.
- **Reduce motion** (`Settings.Global.ANIMATOR_DURATION_SCALE == 0`): every
  animator runs at 0 ms, no pulse, no face loops — states swap instantly.
- **Six styles, one shell.** `overlay/bubble/BubbleView` is the one canvas-drawn
  shell (state + animators); a `BubbleFace` strategy per style
  (`BubbleFace.of(variant)` is an exhaustive `when`, so a new style does not
  compile without a face) draws the background, dial and overlay. The wire
  tokens are `MASCOT` (default), `RING`, `LIQUID`, `HOURGLASS`, `BEZEL` and
  `DROP`; each has one ability. The board's `NEON`, `STEPS`, `WEATHER` and
  `OUTLINE` were retired; a stored one reads back as `MASCOT` on both sides:

  | Style | Ability |
  |---|---|
  | Mascot | a character whose mood changes every hundred, count in a chip |
  | Ring | an arc that fills toward the next colour |
  | Liquid | the tier colour fills from the bottom with a waving crest |
  | Hourglass | the logo mark; sand drains with progress, a grain falls while open |
  | Bezel | ten watch ticks, lit per ten reels |
  | Drop | a drop that clings to the edge, gently breathing |

  Loops (Liquid wave, Drop breath, Hourglass sand while open) share one ~30 fps
  `Handler` that runs only while a face declares them, the view is attached and
  motion is not reduced. `contentDescription` is recomputed on every state
  change: collapsed `"<count> reels today, <time> watched. Tap to show the
  timer."` (dial styles say how many reels to the next colour / "final colour"
  instead of the time), open `"Watch time today <clock>. Tap to show the reel
  count."`; a count of 1 reads "1 reel". The count shows `1.2k` above 999.
  Style = the three-key `BubbleStyleSpec` (§6.2); `onStyleChanged()` rebuilds
  collapsed with no pill. Font: `widget/Manrope.kt` (shared with the widget
  renderer); colours and geometry numbers come from the generated
  `BubbleTokens` (`tool/home_widget/tokens.json` `bubble-*`, emitted by
  `gen_tokens.dart` to Kotlin and Dart).
- **"Reels left" override (One Reel / Unblock).** `BubbleView` has a
  `remaining: Int?` render mode. While a One Reel / Unblock session is armed the
  bubble shows the **remaining unlockable reels** instead of the today-total:
  when `remaining != null` the shell draws the **current tier look** with the
  remaining number and a small "left" caption under it, and **skips the face**
  (a style's ability would misreport the count); a tap still toggles the timer
  and the TalkBack label reads "N reels left". `ContentCounterBubble.setRemaining(Int?)` stores a
  `lastRemaining` that is **replayed** on view rebuild/show, and
  `setCount`/`onCounted` still update the underlying count so it's correct the
  instant the session ends and `remaining` reverts to `null`. This is a
  **display-only** coupling — the counting brain never changes; only the
  bubble's face reflects a reel session (see §7). Driven from
  `ContentCounter.setReelSessionRemaining(Int?)` (a passthrough gated
  `if (!store.enabled) return`, so a disabled counter keeps the bubble off),
  which the AccessibilityService calls via `syncReelBubble()` on arm / each
  allowed reel / revert-to-base — see
  [03-detection-engine.md](03-detection-engine.md) §5.3. The bubble's own
  show/hide still honours `bubbleEnabled` and the on-a-reel-surface condition.

### 5.2 Home-screen widgets — `widget/**`

The spec is the claude.ai design board *Library* + *Widget Rules* (DS-01…DS-10
design rules, IM-01…IM-09 implementation rules), applied by intent on this
native-first stack. Six families, one shape on both sides:

```
WidgetPayload ─▶ WidgetModel ─▶ WidgetFace ×6 (layout only) ─▶ WidgetPainter (Canvas primitives)
 (wire, IM-02)   (every string/value     ▲ exhaustive `WidgetFamily.face()`      ColorMath, WidgetTokens
                  a face shows; pure)    │
              Kotlin: WidgetBitmapRenderer → RemoteViews     Dart: WidgetPreview (animated)
```

- **Families and sizes.** `WidgetFamily` = `COUNT`, `NEXT_COLOUR`, `TIME_LIMIT`,
  `RHYTHM`, `BONSAI`, `BENTO` (the wire token is the name, same in Dart).
  `WidgetSize` = `SMALL` / `MEDIUM` / `LARGE`, picked per instance by
  `WidgetSize.of(wDp, hDp, screenShortDp)`: wide (w ≥ 1.15·h) is Medium, else
  ≥ 55 % of the screen's short side is Large, else Small; an unreported size is
  Small. A phone always measures its portrait bounds (min width × max height,
  `HomeWidgets.instanceDp`) so turning it never swaps the face.
- **Launcher entries.** Six `AppWidgetProvider`s in `HomeWidgets.kt`, one-line
  subclasses of `FamilyWidgetProvider(family)`, sharing
  `res/xml/content_counter_widget_info.xml` (2×2 target, `minWidth/Height
  110dp`, resizable both ways, **`updatePeriodMillis="0"`**) and each with its own
  `android:label` (`widget_label_*`). **Count keeps the old FQCN
  `widget.ContentCounterWidgetProvider`**, so widgets pinned before the families
  existed carry on as Count. `HomeWidgets.providerFor(family)` is an exhaustive
  `when` — a new family needs its provider to compile.
- **One writer (IM-01).** `ReelWidgetSync` is the only code that builds the
  payload or computes the tier. `build(demo)` composes it from
  `ContentCounterStore.widgetSource(today)`, the soonest reel limit
  (`RuleEngine.soonestReelLimitMs` over `cc_reel_limits`), the OS "remove
  animations" setting and `AccessibilityCheck.isEnabled` — tracking = counter on
  **and** service enabled. Before the first reel is ever counted it builds the
  board's demo day. `push(reason)` builds, writes `widget_payload`, makes sure the
  midnight job is armed, and redraws every pinned instance **only when
  `WidgetPayload.visibleKey` changed** (`widget_rendered_key`; written after the
  render, so a failed render retries next push).
- **Push reasons.** `COUNT` (the §2.5 budget), `BACKGROUND` (Dart, on app
  pause), `SETTINGS` (style/theme, counter on/off, `pushRules` limit change,
  service connect/unbind, a night-mode flip while the service runs), `REFRESH`
  (Dart, at bootstrap), `HEARTBEAT` (`WatchdogJobService`, every 15 min: a fresh
  build while the service runs, else the stored payload ages into **Stale** —
  `ponytail:` Stale shows 60–75 min after the last refresh), `MIDNIGHT`
  (`widget/MidnightJobService.kt`, persisted one-off JobScheduler job **id 1128**
  at the next local midnight, DST-correct, re-armed after each run; writes the
  new day's Empty keeping limit/theme/flags — IM-04. `ponytail:` Doze can defer
  it; every render also compares local days).
- **Threading.** Every widget task runs through `HomeWidgets.run {}` — one
  single-thread executor, so renders and payload writes never interleave and the
  dedupe needs no lock. A throw is logged, never rethrown (it would kill the
  process hosting the accessibility service). Provider `onUpdate` /
  `onAppWidgetOptionsChanged` use `goAsync()` and `finish()` in `finally`; jobs
  call `jobFinished` from the worker; channel replies are posted back to main.
- **Rendering.** `WidgetBitmapRenderer.render(family, size, model, cellW, cellH)`
  draws the face on a transparent bitmap the size of the launcher cell (long side
  ≤ 1200 px). `fitBox` scales the design box uniformly, lets the face stretch up
  to 1.25× wider / 1.8× taller, and letterboxes past that. Faces are `object`s
  that only place primitives; `WidgetPainter(…, dark, brand)` owns the tier tile
  (135° gradient, dark glow, sheen, hairline; every tier in the brand's hue — the
  renderer reads `store.brand(dark)`, the primary of the widget's own theme), band,
  chip, ring, segments, bars, the hand-built
  bonsai paths, and Manrope text (`flutter_assets/assets/fonts/Manrope-*.ttf`,
  `tnum`, shrink-to-fit; `DEFAULT_BOLD` fallback). Tier colours come from
  `BrandTint`; every other colour only from the generated `WidgetTokens.kt` (`tool/home_widget/tokens.json` →
  `gen_tokens.dart`; precommit runs `--check`). Theme `system` follows the
  device at draw time (IM-07). `ponytail:` a Large bitmap rides the RemoteViews
  binder call — lower the pixel budget if a device throws
  `TransactionTooLargeException`.
- **Per instance.** `setContentDescription(model.describe(family, size))` — one
  TalkBack line per widget (DS-05) — and a tap `PendingIntent`
  (`requestCode = appWidgetId`, extras family + size).
- **Tap (IM-08).** `MainActivity` (`onCreate`, and `onNewIntent` after
  `super` + `setIntent`) turns a `WIDGET_TAP` intent into
  `pendingWidgetTap = "FAMILY|SIZE|TARGET"`, the target decided at tap time by
  `WidgetTapTarget.of(counterOn, accessibilityOn)`: counter off → `APPEARANCE`,
  service off → `PERMISSIONS`, else `ACTIVITY`. Relaunches from Recents are
  ignored. Dart drains it with `takePendingWidgetTap` (§6.3).
- **Pin and picker.** `requestPin(family)` passes that family's Small demo face
  as `EXTRA_APPWIDGET_PREVIEW`. On Android 15+ `publishPickerPreviews` sets each
  family's real demo face in the widget picker once per versionCode;
  `ponytail:` older launchers show the one static preview
  (`content_counter_widget_preview.xml`) for all six.
- **Old pieces.** The single-face `WidgetStyleSpec` / `drawLines` renderer and
  the per-reel 1 s throttle are gone. The block screen's palette moved to
  `overlay/BlockScreenPalette.kt` ([25](25-block-screen.md)); colour helpers to
  `widget/ColorMath.kt`. There is **no `home_widget` plugin**.

**Rules compliance (by intent).** DS-01 tiers (`tierOf`: 0, then one per 100
reels, max 5; their colours are the theme's ramp, not the board's palette — see
`BrandTint`) · DS-02/05 tokens only, one description per instance · DS-04 three
size classes per family · DS-07 numbers roll from the last value in the
preview · DS-08 Stale / Turn-on-tracking notes in each face's label slot ·
DS-10 exhaustive family switches · IM-01 one writer · IM-02 the nine-key
payload pinned by `test/fixtures/home_widget_{cases,payloads}.json` on both
sides · IM-03 the count budget + visible-key dedupe · IM-04 midnight job ·
IM-07 theme · IM-08 tap routing · IM-09 corrupt data renders Empty.

### 5.3 Shared usage ladder — `engine/UsageLadder.kt` ↔ `usage_ladder.dart`

Both the color band (green → brown-red) and the emoji ladder step once **per 50
reels** and cap at **500** (`kUsageCap` / `CAP`). The Dart source of truth
(`content_counter_core/domain/usage_ladder.dart`) and the native mirror
(`engine/UsageLadder.kt`) must stay **byte-identical**. Nothing reads them now: the
block screen's "Colour by usage" was the last reader and went with the
Quotes-only wall (2026-10-16); the home widgets (DS-01 tiers, §5.2) and the
bubble (same tiers, §5.1) never did. Both copies stay until the pending bubble
commits land, then go.
`bandIndexFor(count) = count.clamp(0, 500) ~/ 50` → 0..10.

---

## 6. Dart feature (`lib/features/content_counter/**`)

Four sub-modules, registered in `lib/core/di/injector.dart`, behind one public
barrel `lib/features/content_counter/content_counter.dart` (entities, contracts,
the two cubits, `BubblePreview`, `WidgetPreview`) — the only
import other features may use (`tool/check_boundaries.sh`). The bubble- and
home-widget editors are routed at `/content-counter/bubble` and
`/content-counter/widget` (`lib/core/navigation/routes.dart`); the counter's
on/off toggles and the links into those editors now live on the shared
**Appearance** screen (`/appearance`,
`lib/features/additional_feature/appearance/**`) alongside the app theme +
background, reached from the drawer and Settings. There is no longer a standalone
"Reel counter" route.

### 6.1 `content_counter_core` — live count + hub

- **Entities**: `ContentCount` (`today`, `total`, `enabled`, `bubbleEnabled`,
  `perAppToday`, `perAppTotal` — each list sorted desc — plus `timeToday`, a
  `Duration` of today's whole-app usage parsed from `timeTodayMs`, and
  `overlayGranted: bool?` — the "Display over other apps" grant, tri-state like
  the permission model: `null` = unread / unanswered, never rendered as denied;
  `bubbleBlocked` = on but grant missing) with a safe `ContentCount.empty()`
  for off-Android; `AppContentCount` (per-app tally enriched with catalog
  `appName` / `displayName` / `iconUrl`). `timeToday` is what the dashboard's
  screen-time ring reads (with the `DailyLimit` as the ring's max — see
  [07-daily-limit-scheduler.md](07-daily-limit-scheduler.md)); with `enabled`
  off the ring shows "Counting off — screen time not measured", the reels and
  streak pills show "—", and the "days under your limit" streak is **not**
  observed (usage accrual stops with the counter, so a zero there is
  unmeasured, not earned; the stored streak is reconciled again when counting
  resumes).
- **Repository**: `ContentCounterRepositoryImpl` bridges the native snapshot to
  the domain and enriches each per-app entry with catalog metadata from
  `ConfigRepository.loadBlockTargets()` (built once, cached; a catalog failure
  is logged and degrades to bare package names — it must never take the
  counter with it). `watch()` yields an initial pull then streams
  `contentCounted` events.
- **Cubit**: `ContentCounterCubit(repo, bubble)` is the one source of truth for
  every counter control surface. It streams the live `ContentCount` into the UI
  (the subscription has an `onError` — one bad read must not kill the hero
  count, breakdown and ring for the session), owns both switches
  (`setEnabled`, `setBubbleEnabled` — optimistic emit, then native; switching
  the bubble on without the grant opens the system screen), `requestOverlay()`,
  and `refresh()` — which re-pulls the snapshot so `timeToday` is fresh on
  demand **and re-reads the overlay grant** (usage time advances between
  counted reels, which the `contentCounted` stream doesn't emit; the dashboard
  hero calls it on mount and on pull-to-refresh, and `AppResumeSync` calls it on
  **every app resume** — the day-rollover repair for a dashboard kept in
  recents across midnight, and what clears a "needs permission" state after the
  user returns from Settings). Provided once, globally, in `lib/main.dart`
  (the Activity screen no longer creates a second instance).
- **UI**: the counter has no card of its own any more. The **Activity** screen
  reads `ContentCounterCubit` directly — a compact **Reels** tile (today,
  with the all-time total as its caption) in the Today panel, and a **Reels**
  segment in the By app section whose rows are the shared `AppLimitRow`
  ([28](28-insights.md) §6). The former `ReelCounterCard` hero (count-up, today /
  all-time toggle, its own per-app rows) is gone; its all-time per-app breakdown
  has no surface. Per-app icons still render via the shared `AppIconAvatar`
  (bundled `social_icon_pack` asset via `AppContentCount.iconUrl`, with a
  letter-tile fallback) — the same widget the blocklist uses. The old `ContentCounterScreen` hub was
  removed: its counting controls and the Bubble-style / Home-widget entries
  migrated to the shared **Appearance** screen
  (`features/additional_feature/appearance/presentation/appearance_screen.dart`).
  There a single **Count short videos** master switch gates the section, and the
  **Bubble** and **Home widget** are hero cards each rendering a large live
  `BubblePreview` / `WidgetPreview` you tap to open its editor. The bubble carries
  its own on/off (`bubbleEnabled`) on its card; the widget has **no** independent
  enable (a placed widget always updates), so its card is gated by the counting
  master. The section is a plain reader of the two app-wide cubits
  (`ContentCounterCubit` for switches / grant / figures,
  `CounterAppearanceCubit` for the live styles) — no `sl<>` repos and no
  `setState` mirrors of native state. When the bubble is on but the grant is
  missing (`bubbleBlocked`) the card shows a warning row — *Needs "Display over
  other apps" — tap to allow* — that opens the system screen (EVO-022). Each
  preview is an `AppPressable` (announced as a button; the bubble's and the
  widget's disable when their surface is off, the block screen's stays live — its
  editor carries the same switch, [25](25-block-screen.md) §6). A card's off hint
  and its grant warning slide in and out (`AppReveal`, `NoticeLine`: design
  system, `components/feedback.dart`) instead of popping the card. With counting off the Activity card's breakdown says so instead of
  promising reels that can't be counted.
- **Appearance carrier**: `CounterAppearance` (bubble + widget styles) with
  `CounterAppearanceCubit` — each setter emits immediately (so the preview tracks
  the slider with no lag) but **debounces the native push by 120ms** so dragging a
  slider doesn't flood the command channel. Provided once, app-wide, in
  `lib/main.dart` (lazy — hydrated from native by the first screen that reads
  it), so the Appearance hub and both editors share one state and an edit is
  visible on return with no re-pull; per-surface dirty flags stop the hydrate
  from overwriting an edit that beat it. The Appearance hub's third card — the
  **block screen**, with its own on/off switch — follows the same shape through
  `BlockScreenStyleCubit` ([25](25-block-screen.md) §6). `CounterAppearanceRepositoryImpl`
  hydrates from the snapshot's `bubbleStyle` / `widgetStyle` JSON (a malformed
  one is logged, then defaults) and pushes via `setCounterStyle`.
- **Wire enums**: `counter_style_enums.dart` — `BubbleVariant`,
  `WidgetBackground` (no reader since the block screen dropped its background picker on
  2026-10-16; kept until the pending bubble commits land), `WidgetTheme`, and the home
  widgets' `WidgetFamily` (wire, label, one-line blurb) and `WidgetSize` (wire,
  label), each carrying its wire token (`MASCOT`, `GLASS_DARK`, `SYSTEM`,
  `BONSAI`, `MEDIUM`, …) with an order-independent `fromWire` fallback. The
  size's design box lives in presentation (`widget_geometry.dart`), keeping the
  domain free of the generated tokens.

### 6.2 `content_counter_bubble` — bubble control + style

- `BubbleStyle` entity (`variant`, `size` 48–80dp default 68, `opacity` 0.5–1
  default 1 — fill only), with `toWire` / `fromWire` re-clamping (the native
  `BubbleStyleSpec` re-clamps again, and an unknown or legacy variant token
  becomes `MASCOT`, so a malformed payload can never produce an unusable
  bubble). The old `textScale` / `spacing` / `showLabel` / `showTime` keys are
  gone from the entity and the wire and are ignored on read. `BubbleVariant`
  (in `counter_style_enums.dart`) carries the six wire tokens and labels.
  Rides the existing `setCounterStyle` → `bubbleStyleJson`
  pipe; no new channel method.
- `domain/bubble_model.dart` — the pure `BubbleModel` (tier, `countText`,
  `shortTime`, `clock`, `pct` / `toNext` / `nextLine`, `timerWidth`, the
  BR-11 accessibility strings, per-style scalars) plus `TierChange`; the Kotlin `overlay/bubble/BubbleModel` mirrors it and both are
  pinned by `test/fixtures/bubble_cases.json`.
- `presentation/` — `bubble_tokens.g.dart` (generated `BubbleTokens`, never
  edited), `bubble_look.dart` (tier → colours), `bubble_frame.dart`,
  `bubble_face.dart` + `faces/*_face.dart` ×10 (one painter per style, same
  split as native), `bubble_brush.dart` (`BubblePaths`, paints), `svg_path.dart`
  (SVG path parser shared in spirit with native `SvgPath`), `bubble_painter.dart`
  (the shell `CustomPainter`, same drawing order as `BubbleView`) and
  `bubble_preview.dart`. **`BubblePreview({style, count, watch, area = 132,
  animate = true, interactive = false, dockedRight, excludeFromSemantics})`**
  animates like the native view (count pop, 700 ms cross-fade, one pulse and the
  3 s time pill on a tier up, tap-to-toggle timer when `interactive`, Liquid /
  Drop / open-Hourglass loops on one ticker; `replayAppear()` through its
  `GlobalKey` state). Animation frames repaint, never rebuild: a private
  live painter reads the controllers at paint time (`repaint:` the merged
  motion) and draws the appear spring on the canvas, like `WidgetPreview`;
  tests read the current frame through `BubblePreviewState.frame`.
  Non-interactive previews (hub card, carousel thumbnails)
  are centred and scaled to fit and skip the pill/pulse so they never spill.
  Still under `MediaQuery.disableAnimations` or `animate: false` (the pill
  still shows for 3 s — information, not motion). Glow convention: CSS blur
  radius `r`; Dart sigma = `r/2`, Kotlin `BlurMaskFilter` radius = `r`.
- `BubbleRepositoryImpl` gates the bubble on/off (`setContentBubbleEnabled`) and
  reuses the existing overlay-permission channel methods (`canDrawOverlays` —
  read tri-state via `invokeBoolOrNull`, so an unanswered read is `null`, not
  "denied" — / `requestOverlayPermission`) — no new permission plumbing. The
  bubble's actual show/hide is native (driven by the foreground app); this only
  toggles the flag.

### 6.3 `home_content_counter` — the six widgets' Dart half

- **Domain** (pure, mirrors native and is pinned by the same fixtures,
  `test/fixtures/home_widget_{cases,payloads}.json`):
  `entities/widget_payload.dart` — `WidgetPayload` (the IM-02 nine keys,
  tolerant `parse`, `demo`, `copyWith`, `empty`); `widget_model.dart` —
  `WidgetModel`, every value a face shows (count, tier, time strings, segments,
  limit left, hourly minutes + peak, stale / tracking note, `describe(family,
  size)` for the semantics line); `entities/widget_tap.dart` — `WidgetTap.parse`
  of `"FAMILY|SIZE|TARGET"`; `entities/widget_style.dart` — `WidgetStyle {theme}`,
  the widgets' one user setting (old keys ignored on read).
- **Repository**: `HomeWidgetRepository` / `HomeWidgetRepositoryImpl` —
  `pin(family)`, `push({reason})` (`WidgetPushReason.refresh` at bootstrap,
  `.background` from `AppResumeSync` on pause), `payload({demo})` (fresh,
  unstored), `takePendingTap()`. All over the command channel, which no-ops
  off-Android (the payload then reads as Empty).
- **Drawing**: `presentation/widget_tokens.g.dart` (generated, never edited),
  `widget_geometry.dart` (`WidgetSize.box / radius / inset / band`),
  `widget_face_painter.dart` (`WidgetFace` interface, `FaceFrame`, `FaceCanvas`
  primitives + bonsai paths — Manrope via a raw `TextStyle(fontFamily:
  'Manrope')` on the bundled 700/800 files), and one
  layout-only face per family in `presentation/faces/`.
- **`WidgetPreview(family, size, payload, {width, animate})`** — the animated
  in-app widget. One 800 ms controller lerps count, watch seconds and each hour
  from the previous payload (`Cubic(.2,.8,.2,1)`; numbers roll from the last
  value, never up from 0), the tier cross-fades over 700 ms, Bonsai sways while
  below tier 5. Still under the OS "remove animations", `payload.reduceMotion`
  or `animate: false`. Follows the platform brightness for `system`; a
  `RepaintBoundary` and one `Semantics('Preview: …describe…')`.
- **`WidgetTapListener`** (IM-08) — mounted next to `PendingUnblockListener` in
  `main.dart`'s router builder; once the `AppGate` is open (past PIN and first
  run) and on every resume it drains `takePendingTap()`, logs
  `AnalyticsService.logWidgetOpened(family, size)` (`widget_opened`) and pushes
  `Routes.analytics?family=&size=` / `Routes.appearance` / `Routes.permissions`.

### 6.4 `content_counter_appearance` — editor screens

- `BubbleStyleScreen` — laid out like `HomeWidgetScreen`: a swipeable
  152 dp `PageView` stage of every style on the shared `StageSurface` (the
  `sizeMax` bubble plus its pill; viewport 0.86 of a pager widened past the
  screen with an `OverflowBox`, so the centred glass spans exactly the 16 dp
  gutters and each neighbour, scaled and dimmed by the shared `StagePage` and
  pulled back by its `peek`, shows 8 dp at the screen edge; only the centred
  page's 220 × 152 `BubblePreview` animates and takes taps, a side page tap
  flies there) → one centred line, the style's name · its mood /
  next-colour line (cross-fading per style) → one row: the count, the
  **Preview count** slider (0–500) and a **Replay appear** icon button →
  `SectionHeader('Style')` + the six styles as 88 px static thumbnails in an
  84 × 96 `VariantCarousel` laid edge to edge (`inset: md`, so it rests on the
  gutter and scrolls out to the screen edge; staggered in by the shared
  `RailThumb`, which also scrolls the selected one into view) →
  `SectionHeader('Customize')` + **Size** and
  **Opacity**. A swipe selects the page it settles on; a rail tap selects and
  flies the stage; a style set elsewhere (the cubit's first load) moves the
  stage. Each section rebuilds only for its inputs (the preview count is a
  `ValueNotifier`; the live watch time rebuilds only the stage).
  `widgets/stage_carousel.dart` holds `StagePage` / `RailThumb` for both
  pickers and the bubble stage's `StageSurface`: the design system's
  `GlassContainer` (selected: lit with the theme's primary; no backdrop blur,
  since the preview animates on it), so the stage follows the app's
  light/dark theme and background; the hint reads in `onGlassMuted`. (The
  board's fixed dark/light stage gradients are gone.) Every slider's value is
  formatted once for both the visible label and the screen reader
  (`AdaptiveSlider.semanticFormatter`), so TalkBack says "56 dp", not a bare
  percentage.
- `HomeWidgetScreen` + screen-scoped `HomeWidgetCubit` (`home_widget_cubit.dart`,
  state `{family, size, payload, loading}`; `load()` pulls `payload()` with no
  demo flag, `select`, `selectSize`, `pin()`). Top to bottom: a swipeable
  `PageView` stage (viewport 0.86, each tile straight on the page with no
  surface behind it (the tile is its own surface), a narrow neighbour pulled in
  to peek, neighbours scaled 0.90 and dimmed to 0.55, height morphing with the
  size), the family name + blurb, the six families as
  64 px static Small thumbnails in the design system's `VariantCarousel`, the
  **Size** `GlassSegmented` (preview only — an `InfoButton` says a pinned widget is
  resized on the home screen), a **Set a daily limit** link shown only for Time
  limit with no limit (reloads the payload on return), **Theme** (System / Light /
  Dark, owned by `CounterAppearanceCubit` and overlaid onto the payload, so
  neither cubit depends on the other), and **Add to home screen** →
  `pin(family)`. The toast is truthful: Small "Confirm the prompt to add it to
  your home screen.", Medium / Large "…then long-press it and drag to resize.",
  and the add-by-hand copy when the launcher can't pin. Entrance stagger, and
  every motion off under "remove animations". The Appearance hub card shows the
  Count face on the demo day (`WidgetPayload.demo`, `animate: false`).
- The bubble editor reads the app-wide `CounterAppearanceCubit` and seeds its preview
  figures from the live `ContentCounterCubit` (no snapshot re-pull); the
  widget editor's figures come from `HomeWidgetCubit.load()`.
- The pinned
  Flutter previews (`BubblePreview`, `WidgetPreview` — each carries a
  `Semantics` label describing what it shows — and the design system's
  `VariantCarousel`) mirror the native render, and — because the cubit's
  debounced push live re-renders native — any on-screen bubble and pinned
  widget update as the user edits.

---

## 7. Lifecycle & independence notes

- **Enabled by default.** `cc_enabled` and `cc_bubble_enabled` both default to
  `true`; the counter runs from first launch of the service, no opt-in required.
- **Decoupled from blocking.** The counting pass runs before the `masterEnabled`
  and `pauseUntil` gates, so reels are tallied even while blocking is off, paused,
  or the specific platform is disabled for blocking. The counter never consults
  the active `BlockingPlan` (`blockAll` / `curious` (= "Conscious") / `oneReel` /
  `paused`) and never triggers a back-press. The One Reel / Unblock "reels left"
  bubble state (§5.1) is the one place the plan touches this feature, and it
  touches only the **display**: `setReelSessionRemaining` swaps what the bubble
  *shows* while a reel session runs, but the tally itself — what `count(pkg)`
  records and pushes to store/widget/event — stays blocking-independent.
- **Survives UI death.** All state is in `detoxo_engine_prefs`; the bubble and
  widget render from the native store, so they stay live and correct with the
  Flutter engine detached. Snapshot pulls prefer the live service but fall back to
  the store.
- **Disposal.** `contentCounter.dispose()` (from the service's
  `onUnbind`/`onDestroy`) removes timers and hides the bubble.
- **iOS / off-Android.** `EngineChannel` no-ops (pins return `false`, refreshes
  and the overlay read return nothing — `overlayGranted` stays `null`), and
  snapshots resolve to `ContentCount.empty()` — the feature is Android-only.

---

## Source files

Native (Android, `android/app/src/main/kotlin/com/errorxperts/detoxo/…`):

- `engine/ReelTracker.kt` — the counting decision: session + settled-page
  identity + dwell state machine (pure Kotlin, no Android imports); shares
  `settledPage()` with the One Reel gate. Tested by
  `android/app/src/test/kotlin/com/errorxperts/detoxo/engine/ReelTrackerTest.kt`.
- `engine/ContentCounter.kt` — drives the tracker (one Handler timer), bubble
  visibility, fan-out to store/bubble/widget/event; `setReelSessionRemaining`
  passthrough for the bubble's "reels left" display (gated on the counter toggle).
- `engine/ContentCounterStore.kt` — SharedPreferences (`detoxo_engine_prefs`)
  persistence, day rollover, snapshot; `recordCount` folds the usage flush and
  returns the snapshot; `enabled` / `bubbleEnabled` cached per instance.
- `engine/DateKeys.kt` — the shared `dd-MM-yyyy` day key, memoised per minute.
- `engine/DetectionConfig.kt` — `DetectorRule.qualifiedIds` (precomputed
  target ids for `matches()`).
- `receivers/WatchdogJobService.kt` — the 15-min job is also the widgets'
  `HEARTBEAT`.
- `engine/UsageLadder.kt` — the color-band + emoji ladders (native mirror; no reader since the block screen dropped "Colour by usage" — kept until the bubble commits land).
- `engine/RuleEngine.kt` — `soonestReelLimitMs`, `reelMetersJson`,
  `DAILY_REEL_LIMIT_ID` (the Time limit widget's source).
- `overlay/ContentCounterBubble.kt` — the window host: anchor + envelope
  layout, drag/edge-snap, single-tap timer, `watchMs` provider + 1 Hz tick;
  `setRemaining`/`lastRemaining` replayed on rebuild.
- `overlay/bubble/{BubbleView,BubbleStyleSpec,BubbleModel,BubbleEnvelope,BubbleGeometry,BubbleLook,BubbleFrame,BubblePaints,SvgPath,BubbleFace,BubbleTokens}.kt`
  + `faces/{Mascot,Ring,Liquid,Hourglass,Bezel,Drop}Face.kt`
  — the shell, the pure model/envelope/geometry, and the six faces (the "left"
  override draws on the tier look, faces skipped).
- `widget/Manrope.kt` (shared font loader), `widget/ColorMath.kt` (`blendArgb`).
- `widget/ReelWidgetSync.kt` — the one payload writer (build / push / reasons /
  visible-key dedupe / `onRules`).
- `widget/HomeWidgets.kt` — the worker, `FamilyWidgetProvider` + the six
  providers (Count = `ContentCounterWidgetProvider`), per-instance render, pin,
  picker previews, `WidgetTapTarget`, `tapWire`.
- `widget/MidnightJobService.kt` — the midnight turnover job (id 1128).
- `widget/WidgetPayload.kt`, `widget/WidgetModel.kt` — wire payload + display
  model (`WidgetFamily`, `WidgetSize.of`), pure and JVM-tested.
- `widget/WidgetBitmapRenderer.kt` (`render`, `preview`, `fitBox`,
  `isSystemDark`), `widget/WidgetFace.kt` + `widget/faces/*Face.kt` (one per
  family), `widget/WidgetPainter.kt` (Canvas primitives, bonsai paths, Manrope),
  `widget/ColorMath.kt`, `widget/BrandTint.kt` (the theme's hue per role and the
  usage ramp), `widget/WidgetTokens.kt` (generated from
  `tool/home_widget/tokens.json` by `tool/home_widget/gen_tokens.dart`).
- `overlay/BlockScreenPalette.kt` — the block screen's palette (`Palette` /
  `wallPalette`; `legibleOn` / `legibleFill` / `onColorFor` live in
  `BlockScreenRenderer.kt`; [25](25-block-screen.md)).
- `lib/features/content_counter/content_counter_appearance/presentation/widgets/widget_palette.dart`
  — `WallPalette` / `wallPaletteFor` (the Quotes wall's flat grounds; the accent only tints
  the dark one), `legibleOn`, `onColorFor` and `legibleFill`, the Flutter mirror of that
  palette, used by the block-screen preview; exported from the barrel.
- `lib/features/content_counter/content_counter_appearance/presentation/widgets/stage_carousel.dart` (`StageSurface` (bubble stage), `StagePage`, `RailThumb`)
- `engine/ContentCounter.kt` — `todayCount()` is also read by the block screen
  for its "N reels today" line (−1 when counting is off, so a stale number is
  never shown).
- `accessibility/DetoxoAccessibilityService.kt` — `countContent()` pass
  (`COUNT_THROTTLE_MS`, scroll-field forwarding + calibration log, the
  `countMisses` / `DFS_SKIP` stage-3 back-off), `matches(..., deep)`,
  `isReelPlatform`, `NON_REEL_PLATFORM_IDS`, `isImePackage`, foreground
  forwarding, and `syncReelBubble()` (drives the bubble's "reels left" display on
  arm/allow/revert).
- `channels/CommandHandler.kt` — `contentCounterSnapshot`,
  `setContentCounterEnabled`, `setContentBubbleEnabled`, `refreshContentWidget`,
  `setCounterStyle`, `pinContentWidget`, `contentWidgetPayload`,
  `takePendingWidgetTap`, and the `pushRules` reel-limit mirror.
- `MainActivity.kt` — `pendingWidgetTap` from the tap intent.
- `AndroidManifest.xml` — the six widget receivers + `MidnightJobService`;
  `res/values/strings.xml` — `widget_label_*`, `cc_widget_description`.
- `res/xml/content_counter_widget_info.xml` — widget metadata shared by all six.
- `res/layout/content_counter_widget.xml`, `res/layout/content_counter_widget_preview.xml`
  — the `RemoteViews` host (`cc_widget_root` / `cc_widget_image`) and the static
  picker preview; `res/drawable/cc_widget_bg.xml`.
- `assets/fonts/Manrope-{Bold,ExtraBold}.ttf` + `OFL.txt` — shared by both
  renderers (native reads them from `flutter_assets/`).

Dart (`lib/…`):

- `core/constants/channel_constants.dart`, `core/platform_channels/engine_channel.dart`
  — command/event names + counter channel wrappers.
- `core/di/injector.dart`, `core/navigation/routes.dart`,
  `core/navigation/app_router.dart` — DI + routes; `main.dart` provides the
  two cubits app-wide.
- `core/design_system/components/variant_carousel.dart` — the style-variant
  picker (promoted from the feature; also the shape of the Appearance
  background picker).
- `features/content_counter/content_counter.dart` — the public barrel.
- `features/content_counter/content_counter_core/domain/entities/content_count.dart`
- `features/content_counter/content_counter_core/domain/entities/app_content_count.dart`
- `features/content_counter/content_counter_core/domain/entities/counter_appearance.dart`
- `features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart`
- `features/content_counter/content_counter_core/domain/usage_ladder.dart`
- `features/content_counter/content_counter_core/domain/brand_tint.dart` — the theme's hue per role and the usage ramp (mirror of `widget/BrandTint.kt`; `test/fixtures/brand_tints.json`, `test/counter_ramp_test.dart`).
- `features/content_counter/content_counter_core/presentation/counter_brand.dart` — `counterBrand(context, brightness)`, the primary a preview draws with.
- `features/content_counter/content_counter_core/domain/repositories/content_counter_repository.dart`
- `features/content_counter/content_counter_core/domain/repositories/counter_appearance_repository.dart`
- `features/content_counter/content_counter_core/data/repositories/content_counter_repository_impl.dart`
- `features/content_counter/content_counter_core/data/repositories/counter_appearance_repository_impl.dart`
- `features/content_counter/content_counter_core/presentation/content_counter_cubit.dart`
- `features/content_counter/content_counter_core/presentation/counter_appearance_cubit.dart`
- `features/content_counter/content_counter_bubble/domain/entities/bubble_style.dart`
- `features/content_counter/content_counter_bubble/domain/repositories/bubble_repository.dart`
- `features/content_counter/content_counter_bubble/data/repositories/bubble_repository_impl.dart`
- `features/content_counter/home_content_counter/domain/entities/{widget_style,widget_payload,widget_tap}.dart`
- `features/content_counter/home_content_counter/domain/widget_model.dart`
- `features/content_counter/home_content_counter/domain/repositories/home_widget_repository.dart`
- `features/content_counter/home_content_counter/data/repositories/home_widget_repository_impl.dart`
- `features/content_counter/home_content_counter/presentation/{widget_tokens.g,widget_geometry,widget_face_painter,widget_preview,widget_tap_listener}.dart`
- `features/content_counter/home_content_counter/presentation/faces/{count,next_colour,time_limit,rhythm,bonsai,bento}_face.dart`
- `features/content_counter/content_counter_appearance/presentation/home_widget_cubit.dart`
- `app/app_resume_sync.dart` (the pause push), `app/bootstrap.dart` (the refresh
  push), `main.dart` (`WidgetTapListener`, the Manrope OFL `LicenseRegistry` entry)
- `features/content_counter/content_counter_appearance/presentation/bubble_style_screen.dart`
- `features/content_counter/content_counter_appearance/presentation/home_widget_screen.dart`
- `features/content_counter/content_counter_bubble/domain/{bubble_model,entities/bubble_style}.dart`
- `features/content_counter/content_counter_bubble/presentation/{bubble_tokens.g,svg_path,bubble_look,bubble_frame,bubble_brush,bubble_face,bubble_painter,bubble_preview}.dart`
- `features/content_counter/content_counter_bubble/presentation/faces/{mascot,ring,liquid,hourglass,bezel,drop}_face.dart`
- `tool/home_widget/{tokens.json,gen_tokens.dart}` (`bubble-*` tokens → `BubbleTokens`), with the helpers it shares with the design-token generator in `tool/tokens_common.dart`

Tests: `test/content_counter_test.dart` (snapshot mapping, catalog fallback,
`watch()` filtering, cubit switch / grant paths),
`test/counter_style_test.dart`, the bubble's `test/bubble_{model,painter,preview,style_screen}_test.dart` + `test/svg_path_test.dart` (shared fixture `test/fixtures/bubble_cases.json`; native `overlay/bubble/*Test`), `test/usage_ladder_test.dart`, the home widgets'
`test/home_widget_{payload,model,preview,cubit,screen}_test.dart` +
`test/widget_tap_listener_test.dart` (the shared fixtures in `test/fixtures/`),
and the native `ReelTrackerTest`, `ContentCounterStoreTest` and
`widget/{WidgetPayload,WidgetModel,WidgetGeometry,ReelWidgetSync,HomeWidgets,…}Test`
(run by `bash tool/dev.sh precommit` when a JDK 17 is present).

Cross-feature (the migrated counter hub; theme + background live here too):

- `features/additional_feature/appearance/presentation/appearance_screen.dart` — the
  shared **Appearance** screen that now hosts the **Count short videos** master switch
  and the Bubble / Home-widget hero cards (large live `BubblePreview` / `WidgetPreview`,
  tapped to edit; bubble on/off on its card, widget gated by the master), plus the app
  theme (a Light/Dark `GlassSegmented` control + Match system) and background picker.
  `GlassSegmented` (design system, `components/selection.dart`) is the shared
  liquid-glass segmented control — frosted stadium track with a depth shadow and an
  accent-lit sliding pill; also used for the Reels-seen today/all-time selector.
  A tap selects on release, a horizontal drag anywhere on the track scrubs the
  selection live under the finger (`onChanged` fires as each segment is crossed —
  a theme picker previews live), the pill swells and brightens while a finger is
  down, and the label colour/weight tween on the pill's clock; reduce-motion
  collapses all of it to `Duration.zero`. `selectedIndex: -1` lights nothing (the pill
  fades out) — the Unblock sheet's quick picks use it for a custom value.
