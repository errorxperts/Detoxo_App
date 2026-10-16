# Reel Bubble — ten styles over one rule set

**Date:** 2026-10-11 · **Branch:** `sensitive_protection` · **Status:** design, awaiting review

> **Amendment 2026-10-15:** Neon, Steps, Weather and Outline were removed at the user's request;
> six styles ship (Mascot, Ring, Liquid, Hourglass, Bezel, Drop). A stored retired token reads
> back as `MASCOT`. Sections below still describe all ten as designed.

## 1. Goal

Re-implement the floating reel-counter bubble to the design board *Reels Count Widget*
(claude.ai canvas `6KjTRuFZJd73eNf7YwwpxC`): the **Bubble rules BR-01…BR-12**
(`BubbleVariants.dc.html`), the base behaviour (`Bubble.dc.html`) and the **Ten Bubble
Styles** (`BubbleStyles.dc.html`). Every style obeys the same rules; each adds exactly one
ability. The native Kotlin overlay remains the renderer; the Flutter preview mirrors it.

Non-goals: the home widgets, the block screen, iOS (BR-10's Live Activity), counting logic,
the overlay-permission flow, the bubble's show/hide policy in `ContentCounter`.

## 2. Decisions taken in the brainstorm

| # | Decision |
|---|----------|
| D1 | The four old variants (`GLASS_ORB`, `USAGE_RING`, `EMOJI_MOOD`, `MINIMAL_PILL`) are **replaced** by the ten board styles. An old or unknown persisted token loads as the default. |
| D2 | Customisation keeps **Style**, **Size** (48–80 dp, default 68) and **Opacity** (0.5–1, default 1, fill only). `textScale`, `spacing`, `showLabel`, `showTime` are removed from the entity, the wire and the screen. |
| D3 | The style set is exactly the board's ten, in board order; the **default is `MASCOT`** (first on the board). |
| D4 | **Single tap only** (BR-03): tap toggles count ↔ timer. No double tap, no app launch from the bubble. |
| D5 | The One Reel / Unblock **"reels left" override** stays, redrawn on the new shell. |
| D6 | The bubble stops using `UsageLadder` (per-50 green→brown, emoji); the block screen keeps it. Colour is the DS-01 tier, from the widget tokens. |
| D7 | Architecture **A**: one canvas-drawn shell `View`, ten `BubbleFace` strategies; Flutter mirrors the same split. |

## 3. The rules, as implemented

Values are the board's, in dp; `s = size / 68` scales every geometry number when the size
slider is not 68.

| Rule | Implementation |
|------|----------------|
| BR-01 Content | Collapsed: the count only. `countText = n ≤ 999 ? "$n" : "${floor(n/100)/10}k"` (`1240 → 1.2k`). 0 reels → `0` on glass. |
| BR-02 Minimal time | A pill (h 22, radius 11, pad 9, white, ink `#111A2E`, Manrope 800 11.5, 1 px outline in the tier ring colour) 8 above the body. Shows on **appear** and on **tier up**, for 3 s, then folds down (translateY 0→28, fade). Hidden while the timer is open. `shortTime = h ? (m ? "${h}h ${m}m" : "${h}h") : "${m}m"`. |
| BR-03 Timer | Tap: the body widens **inward** from its docked edge to 136 (< 1 h) or 156 (≥ 1 h) — 176 for Ring / Hourglass / Bezel, whose dial stays — over 480 ms with an overshoot spring; the count fades/shrinks (220 ms / scale 0.6), the timer fades in (300 ms, 140 ms delay). Timer = hourglass mark (20 × 31) + `clock` in Manrope 800 20, gap 8, padding 15/16. `clock = h ? "H:MM:SS" : "MM:SS"`. Ticks every second while open. Tap again folds back. |
| BR-04 Colour | `tier = n ≤ 0 ? 0 : min(5, n ÷ 100 + 1)` (`WidgetPayload.tierOf` / `WidgetRules`). Fill = 160° gradient `tier-N-from → tier-N-to`; tier 0 = glass `#FFFFFF → #E6EFFC`. Ring/outline/glow use the tier's `-to` stop (tier 0: `#B8CDEF`). |
| BR-05 Ink | `ink = [#1C3D78, #111111, #111111, #111111, #FFFFFF, #FFFFFF][tier]`. Pill always white with dark ink + tier outline. The timer keeps the tier colours. |
| BR-06 Crossing a hundred | On tier **up**: colour cross-fade 700 ms; one ring (2.5 stroke, tier ring colour) scales 1 → 1.7 fading 0.9 → 0 over 1.1 s; the pill shows 3 s. Nothing repeats until the next hundred. Tier **down** (midnight) does none of this (BR-12). |
| BR-07 Motion | New reel: the count scales 1 → 1.18 → 1 in 420 ms (`cubic-bezier(.34,1.56,.64,1)`). Appear: scale 0.6 → 1, fade in, 500 ms spring. Reduce motion (`Settings.Global.ANIMATOR_DURATION_SCALE == 0`; Flutter `MediaQuery.disableAnimations`): every animator runs at 0 ms, no pulse, no style loops. |
| BR-08 Size & placement | Body `size × size` (default 68). Draggable; on release snaps to the nearest side, **12 dp** from the edge (Drop: 0 — it clings). Resting Y clamped to **20–70 %** of screen height. Touch target is the body (≥ 48). |
| BR-09 Formats | As BR-01/02/03; tabular Manrope digits. |
| BR-10 Visibility | Unchanged (`ContentCounter` shows on a reel surface, hides on positive evidence). |
| BR-11 Accessibility | `contentDescription` / `Semantics.label`: collapsed `"$countText reels today, $shortTime watched. Tap to show the timer."`; open `"Watch time today $clock. Tap to show the reel count."`. Styles with a progress dial say `"… , $toNext to the next colour"` / `"final colour"` instead of the time (the board's `ariaRing`). |
| BR-12 Day reset | Count and time read 0 after the store's rollover; the view just cross-fades to glass with no pill/pulse (tier down). |

## 4. Shared model — `BubbleModel` (pure, mirrored, pinned by tests)

Dart `lib/features/content_counter/content_counter_bubble/domain/bubble_model.dart` and
Kotlin `overlay/bubble/BubbleModel.kt` expose the same functions with the same results:

- `tier(count)`, `countText(count)`, `shortTime(seconds)`, `clock(seconds)`.
- `pct(count)`: `0` at 0, `100` at tier 5, else `count % 100`. `toNext(count)`:
  `(count ÷ 100 + 1) × 100 − count`.
- `nextLine(count)`: `"First reel turns it green."` / `"Final colour reached."` /
  `"$toNext reels to the next colour."` (shown under the Style carousel and used by Ring /
  Outline).
- `timerWidth(seconds, variant)`: 136 / 156, or 176 for Ring, Hourglass, Bezel.
- Accessibility strings (BR-11), `isDial(variant)` for Ring / Liquid / Hourglass / Bezel / Outline.
- Per-style scalars: `mascotMood(tier)` (0–5), `weatherIcon(tier)` (leaf ≤ 2, sun = 3,
  fire ≥ 4), `stepsLit(tier)`, `bezelLit(count)` (`tier == 5 ? 10 : pct ÷ 10`),
  `sandTop(pct)` / `sandBottom(pct)` (13 + pct·0.20 / 53 − pct·0.22), `neonGlow(tier)`
  (10 + 6·tier), `outlineBadge(count)` (`"−$toNext"` / `"max"`).

Colour is **not** in the model; `BubbleLook` (presentation, both sides) maps a tier to the
shell colours from the tokens.

## 5. Tokens — one source of truth

Add to `tool/home_widget/tokens.json` (DS-02 / DS-10: tokens first) with a `bubble-`
prefix. The generator `tool/home_widget/gen_tokens.dart` gains one rule: tokens whose name
starts with `bubble-` are emitted to **`BubbleTokens`** — Kotlin
`overlay/bubble/BubbleTokens.kt` (package `com.errorxperts.detoxo.overlay.bubble`) and
Dart `content_counter_bubble/presentation/bubble_tokens.g.dart` — instead of
`WidgetTokens`; `--check` covers them. Tier gradients and inks stay the existing
`tier-N-from/to`, `widget-ink`, `widget-ink-inverse`.

Colours: `bubble-glass-from #ffffff`, `bubble-glass-to #e6effc`, `bubble-glass-ring #b8cdef`,
`bubble-glass-halo rgba(110,155,235,.16)`, `bubble-glass-shadow rgba(50,100,200,.38)`,
`bubble-ink-navy #1c3d78`, `bubble-pill-bg #ffffff`, `bubble-pill-ink #111a2e`,
`bubble-faint-light rgba(17,17,17,.14)`, `bubble-faint-dark rgba(255,255,255,.3)`,
`bubble-mark-light rgba(255,255,255,.6)`, `bubble-mark-dark rgba(255,255,255,.22)`,
`bubble-neon-0…5` (`#8fb8ff #7fe3a0 #d4ec6a #ffc94d #ff8a65 #ff5a5a`), `bubble-neon-bg-from
#1b1e27`, `bubble-neon-bg-to #0d0f15`, `bubble-neon-pill-bg #15171e`,
`bubble-line-0…5` (`#1c3d78 #1f7a3f #6b8a12 #b86f0a #b8321f #5e0b12`),
`bubble-liquid-glass rgba(255,255,255,.75)`, `bubble-outline-glass rgba(255,255,255,.72)`,
`bubble-outline-shadow rgba(40,60,100,.18)`, `bubble-liquid-shadow rgba(50,80,140,.25)`,
`bubble-mascot-eye #ffffff`, `bubble-mascot-pupil #1b2a8a`, `bubble-mascot-blush #ff8aa8`,
`bubble-mascot-water #9cd6ff`, `bubble-weather-leaf #3fbf6f`, `bubble-weather-leaf-edge
#1d7a44`, `bubble-weather-sun #f5a524`, `bubble-weather-fire #e8572f`,
`bubble-weather-fire-edge #8c1d12`, `bubble-badge-bg #ffffff`, `bubble-sheen
rgba(255,255,255,.6)`, `bubble-chip-shadow rgba(0,0,0,.2)`.
Lists: `bubble-neon`, `bubble-line`.
Numbers: `bubble-size 68`, `bubble-edge 12`, `bubble-pill-h 22`, `bubble-pill-gap 8`,
`bubble-pill-text 11.5`, `bubble-count-text 24`, `bubble-timer-text 20`, `bubble-timer-w 136`,
`bubble-timer-w-hour 156`, `bubble-timer-w-dial 176`, `bubble-glow 12`, `bubble-pulse-halo 24`,
`bubble-min-y-pct 20`, `bubble-max-y-pct 70`, `bubble-ms-pop 420`, `bubble-ms-tap 480`,
`bubble-ms-pulse 1100`, `bubble-ms-pill 3000`, `bubble-ms-appear 500`, `bubble-ms-crossfade 700`
(same value as `motion-crossfade-ms`), `bubble-ms-wave 3200`, `bubble-ms-breath 2600`,
`bubble-ms-sand 1600`, `bubble-loop-fps 30`.

## 6. Native — `overlay/ContentCounterBubble.kt` + `overlay/bubble/`

```
ContentCounter ──watchMs()──▶ ContentCounterBubble (window host)     overlay/ContentCounterBubble.kt
                                 │ anchor, drag, snap, envelope → LayoutParams
                                 ▼
                              BubbleView (shell: state + animators)  overlay/bubble/BubbleView.kt
                                 ├─ BubbleStyleSpec  (JSON → variant/size/opacity)
                                 ├─ BubbleModel      (pure strings/scalars)
                                 ├─ BubbleLook       (tier → colours, BubbleTokens + WidgetTokens)
                                 ├─ BubbleEnvelope   (pure: state → outsets, window rect from anchor)
                                 └─ BubbleFace ×10   (one ability each)   overlay/bubble/faces/
```

### 6.1 Host — `ContentCounterBubble`

- Constructor gains `watchMs: () -> Long`; `ContentCounter` passes
  `{ store.timeTodayMs(dateKey()) + pendingUsageMs }` so the timer includes the unflushed tail.
- Keeps: steady-state fast path, revoke recovery, the 5 s denied-overlay memo, try/caught
  window ops, `runOnMain`, `onStyleChanged` rebuild, `setRemaining` replay, `onCounted`.
- **Anchor** replaces raw window x/y: `cc_bubble_x/y` now persist the **collapsed body's
  top-left** in px. Dock side = anchor centre vs screen centre. The window rect is
  `BubbleEnvelope.windowRect(anchor, side, state, screen)`: body + the state's outsets
  (§6.3). Every state change that alters the envelope calls `relayout()` (one
  `updateViewLayout`); the timer spring updates it per frame, as the snap already does.
- Drag moves the anchor; release snaps to `edge` (12 dp; 0 for Drop) and clamps Y to 20–70 %
  of the screen; the first show restores a stored anchor clamped to the same rules (an old
  value within range survives, no migration).
- Touch: `ACTION_DOWN` scales the body 0.9 (90 ms); a move past slop drags; `ACTION_UP`
  without a drag is the tap → `view.toggleTimer()`. No `GestureDetector`.
- Appear: `show()` adds the window, runs the 500 ms appear spring and `view.showPill()`.
- Timer tick: while open, a 1 Hz `Handler` tick sets `view.setWatch(max(shown + 1000, watchMs()))`
  — bounded: each tick shows `max(shown + 1, store)` capped at `store + 12 s`, and follows a
  store drop (midnight, re-sync) immediately, so the display leads the store by at most the
  12 s event gap and never keeps counting a day that has ended.

### 6.2 Shell — `BubbleView`

State: `count`, `tier`, `open`, `pillUntil`, `remaining`, `reduceMotion`. Animated values
(`ValueAnimator`s, all 0 ms under reduce motion): `tierBlend` 0→1 over 700 ms between the
previous and current `BubbleLook`; `pop` (420 ms, count scale 1→1.18→1); `pulse` (1.1 s,
ring scale/alpha); `expand` (480 ms overshoot, 0 = collapsed, 1 = open — drives width, count
fade/scale, timer fade); `pill` (slide/fade in 420 ms spring, out 280 ms). One shared
~30 fps `Handler` loop runs **only** while a face declares `loops` (Liquid wave, Drop breath;
Hourglass sand only while open) and the view is attached and motion is not reduced.

Drawing order each frame: face `drawBackground` (default: shell fill = 160° gradient, inset
hairline, halo `0 0 0 7`, soft shadow) → face `drawDial` (Ring track/arc, Liquid level,
Hourglass mark/sand, Bezel ticks, Neon glow) → count (`countText`, Manrope 800, face's
`countSize`, ink, pop scale, `1 − expand` alpha) → timer (mark + `clock`, `expand` alpha,
face's `timerPaddingLeft`) → face `drawOverlay` (Mascot face + chip, Steps dots, Weather
badge, Drop sheen, Outline badge) → pulse ring → pill.

`contentDescription` is recomputed on every state change (BR-11). The glass tier-0 look and
each tier's look are built once per `BubbleLook`; paints are reused, no per-frame allocation
beyond text measuring (cached per string).

`remaining != null`: the shell draws the current tier look with `remaining` as the count and
a small `left` caption (Manrope 700 11, ink) below it; faces are skipped; tap still toggles
the timer.

Fonts: `WidgetPainter`'s private Manrope loader moves to `widget/Manrope.kt`
(`internal object Manrope { fun bold(ctx); fun extraBold(ctx) }`), used by both renderers.

### 6.3 Envelope — `BubbleEnvelope` (pure, unit-tested)

Outsets around the body, in dp: glow 12 all sides (halo 7 + a tight shadow; `ponytail:` the
board's `0 12 30` shadow would need a ~40 dp dead zone that steals taps from the app); pulse
+24 all sides while `pulse` runs; pill +(8 + 22 + 6) top while the pill is visible or
animating; timer +(`timerWidth − size`) on the **inward** side while `expand > 0`; face
outsets: Weather +4 top/right (badge), Outline +6 left / +4 bottom (badge). The body never
moves on screen when the envelope changes: `windowRect` subtracts the new outsets from the
anchor.

### 6.4 Faces — `BubbleFace`

```kotlin
internal interface BubbleFace {
    val countSize: Float get() = 24f          // dp at size 68
    val timerPaddingLeft: Float get() = 15f
    val outsets: Outsets get() = Outsets.NONE
    val loops: Boolean get() = false
    fun drawBackground(c: Canvas, f: BubbleFrame, p: BubblePaints) = p.shell(c, f)
    fun drawDial(c: Canvas, f: BubbleFrame, p: BubblePaints) {}
    fun drawOverlay(c: Canvas, f: BubbleFrame, p: BubblePaints) {}
}
```

`BubbleFrame` carries the body rect, `s`, tier look (blended), count/timer strings, `pct`,
`expand`, `pop`, `pill`, `pulse`, `loopT` (0–1 phase of the loop), `open`, `dockedRight`.
`BubbleFace.of(variant)` is an exhaustive `when` — a new style will not compile without one.

| Face | Ability (board transcription at 68) |
|------|-------------------------------------|
| **Mascot** | Eyes: whites r7 at (25,30),(43,30); pupils r3.6 at (26,31),(44,31) + mood offset; highlights r1.1. Brows, mouth (path + fill), blush α, sweat drop at (52,20), tears from (21,38),(47,38), raised palm at tier 5 — per `mascotMood`. Count in a chip (h 18, r 9, white, ink `#111A2E`, 11.5) at bottom centre. Mood lines: *Glass · happy to see you* … *Deep red · palm up: stop* (shown under the carousel). |
| **Ring** | Track r30 stroke 4 (`bubble-faint-*`), arc from −90° to `pct`, round cap, ink colour, eased 800 ms. Count 22. Timer at 176 wide, arc stays, padding-left 72. |
| **Liquid** | Body is `bubble-liquid-glass` with the tier ring; the tier gradient fills from the bottom to `pct %` with a scalloped white crest (28 × 12 repeat, translateX −14 over 3.2 s loop). Ink `#111A2E`, white when tier ≥ 4 and `pct > 55`. |
| **Hourglass** | The mark (path from the board, fill white .35, stroke ink 2, α .55) behind the count; sand rects clipped to the bulbs at `sandTop` / `sandBottom`, ink α .5. Count 20 with a soft white text glow. Timer 176, padding-left 70. While open the falling grain loops (1.6 s). |
| **Neon** | Background `bubble-neon-bg-*`; outline, glow (`0 0 18` + `0 0 neonGlow`), count and timer in `bubble-neon[tier]` with a text glow; pill `bubble-neon-pill-bg` with neon ink/outline; pulse in neon. |
| **Steps** | Count 22 raised 5; five 6 px dots (gap 4) at bottom 11; dot `i ≤ tier ? ink : faint`. |
| **Weather** | 24 px white badge at top-right (−4, −4) with a leaf / sun / flame icon by `weatherIcon`, cross-fading 500 ms on change. |
| **Bezel** | Ten ticks (6 long, stroke 3, round) at 36° steps on r 28; lit `i < bezelLit` in ink, else faint. Count 21. Timer 176, padding-left 70. |
| **Drop** | Body radius 34 on the outer side, 10 on the docked side (point into the edge; mirrored for a left dock); sheen ellipse 22 × 10 at (12, 10); breath scale 1→1.06 (2.6 s loop, origin at the edge); edge 0. |
| **Outline** | Body `bubble-outline-glass` with a 3 dp inset outline in `bubble-line[tier]`; count, timer and mark stroke in the same; a badge (h 20, r 10, line colour, white 11) at bottom-left showing `outlineBadge`. |

## 7. Flutter — `content_counter_bubble/presentation/` + the style screen

```
bubble_tokens.g.dart   (generated)
bubble_look.dart       tier → colours (BubbleTokens + WidgetTokens); shell geometry
bubble_frame.dart      one frame's values (mirror of BubbleFrame)
bubble_face.dart       abstract interface + `BubbleVariant.face`
faces/*_face.dart      ten painters, same ability table as §6.4
bubble_painter.dart    the shell CustomPainter (same drawing order as §6.2)
bubble_preview.dart    the animated widget (moves here from content_counter_appearance/widgets)
```

- `BubblePreview({style, count, watch, area = 132, animate = true, interactive = false,
  excludeFromSemantics = false})`. Same idiom as `WidgetPreview`: one `AnimationController`
  per change (pop / cross-fade / pulse / expand / pill), one `Ticker` for loops; still under
  `animate: false` or `MediaQuery.disableAnimations`. `interactive` enables the tap toggle;
  `GlobalKey<BubblePreviewState>.replayAppear()` for the screen's button. Semantics = BR-11.
- `BubbleStyleScreen`: stage (the board's dark feed gradient, the preview docked right,
  interactive) → **Preview count** slider (0–500, step 1) + **Replay appear** → `SectionHeader
  ('Style')` + `VariantCarousel` of ten (label, selected, 64 px static preview) + the
  blurb line + `nextLine` → `SectionHeader('Customize')` + Size + Opacity. The caption /
  show-time toggles and the tap-reveal demo are removed. Layout idiom stays as the screen is
  today (headers over content).
- Appearance hub card: unchanged apart from the new preview (`area: 88`, not interactive).
- `formatBubbleClock` and the preview's `time` parameter are removed; the barrel exports
  `bubble_preview.dart` from its new path and `bubble_model.dart`.

## 8. Wire & persistence

- `setCounterStyle` bubble map: `{ "variant": <token>, "size": <double>, "opacity": <double> }`.
  `BubbleStyle.fromWire` / `BubbleStyleSpec.fromJson` read only these three, re-clamp, and
  default an unknown variant to `MASCOT`; extra legacy keys are ignored. The persisted
  `cc_bubble_style` JSON is rewritten on the first edit.
- `cc_bubble_x/y`: the collapsed body's top-left in px (was the window's top-left including
  an 8 dp margin). Read values are clamped by the new rules on first show.
- `cc_bubble_enabled`, the snapshot keys and the `contentCounted` event are unchanged.

## 9. Error handling & edge cases

- No overlay grant / `addView` throws / revoke mid-session: as today (no-op, logged once,
  re-attach on re-grant).
- Malformed style JSON → `BubbleStyleSpec()` defaults; a count > 999 → `1.2k` at 22 dp;
  watch ≥ 10 h → `10h 4m` pill, `10:04:00` timer at 156.
- Style changed while the timer is open: rebuild collapsed (the stored anchor is the
  collapsed body), pill not shown.
- Tier down (midnight, counter reset) cross-fades only. Tier up by more than one step
  (a burst) pulses and pills once.
- Manrope asset missing → system bold (the widget loader's fallback).
- Reduce motion: no animator runs, loops never start, states swap instantly.
- The remaining override and a tier change may coincide; the override only replaces the
  count text and skips the face, so colours still cross-fade.

## 10. Tests

- Kotlin: `overlay/bubble/BubbleModelTest` (formats, tier, pct/toNext, aria strings, scalars —
  the same fixtures as Dart), `BubbleEnvelopeTest` (outsets per state, window rect from an
  anchor on both docks, Y clamp, inward growth).
- Dart: `test/bubble_model_test.dart` (the mirror fixtures, byte-equal strings),
  `test/counter_style_test.dart` (ten tokens pinned, defaults, round trip, legacy keys
  ignored, unknown → Mascot), `test/bubble_preview_test.dart` (every variant paints in
  collapsed / open / pill / remaining states, both docks, without throwing; reduce-motion
  path builds no controller).
- `dart run tool/home_widget/gen_tokens.dart --check` stays green in `tool/dev.sh precommit`.

## 11. Docs (`/docs-sync` after implementation)

`docs/code_docs/17-content-counter.md` §1 tree + §5.1; `04-native-android-layer.md` §7;
`18-platform-channel-contracts.md` (bubble style keys); `09-persistence-data-model.md`
(`cc_bubble_x/y`, `cc_bubble_style`); `14-flutter-package-map.md` (new files);
`docs/info_docs/02-feature-walkthroughs.md` Bubble-style paragraph — **ask before editing**.
`UsageLadder.kt` / `usage_ladder.dart` doc comments drop the bubble.

## 12. Build order (the plan details this)

1. Tokens + generator → `BubbleTokens` on both sides.
2. `BubbleModel` + tests on both sides (mirror fixtures first).
3. Dart entity/enum/wire + `counter_style_test`.
4. Kotlin `BubbleEnvelope` + test; `Manrope` extraction.
5. Kotlin shell `BubbleView` + host changes; faces (ten, independent, parallelisable).
6. Dart `BubbleLook` / `BubblePainter` / `BubblePreview`; faces (ten, independent).
7. Style screen + hub card; remove old code and `formatBubbleClock`.
8. `flutter analyze`, `flutter test`, native tests, boundaries; `/docs-sync`.
