# Reel Bubble Styles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the floating reel-counter bubble's four variants with the design board's ten styles, all obeying the Bubble rules BR-01…BR-12 (time pill, tap-to-timer, tier colour every 100 reels, milestone cross-fade + pulse, reduce motion), rendered natively and mirrored by the Flutter preview.

**Architecture:** One canvas-drawn shell owns every shared rule (tier look, cross-fade, count pop, pulse, pill, timer expansion, accessibility text); each style is a small `BubbleFace` strategy drawing its one ability. A colour-free `BubbleModel` (Dart + Kotlin, pinned by one shared JSON fixture) owns formats, tier and labels; `BubbleLook` maps a tier to colours from generated `BubbleTokens` + the existing tier tokens. The overlay window host positions by an anchor and derives its rect from a pure `BubbleEnvelope`.

**Tech Stack:** Flutter (CustomPainter, AnimationController/Ticker, flutter_bloc), Kotlin (android.view.View + Canvas, ValueAnimator, WindowManager overlay), `tool/home_widget/gen_tokens.dart` token generator, flutter_test, JUnit4.

**Spec:** `docs/superpowers/specs/2026-10-11-reel-bubble-styles-design.md`

## Global Constraints

- Names: only **Detoxo** / **errorxperts** anywhere; the blocking token `"CURIOUS"` is untouched.
- Feature boundaries: other features import `lib/features/content_counter/content_counter.dart` only; `bash tool/check_boundaries.sh` must pass.
- Colours and sizes come from tokens (`tool/home_widget/tokens.json` → generated `BubbleTokens` / `WidgetTokens`); no raw hex in renderers.
- Tier: `tier = count ≤ 0 ? 0 : min(5, count ÷ 100 + 1)`; wire tokens `MASCOT RING LIQUID HOURGLASS NEON STEPS WEATHER BEZEL DROP OUTLINE`; default `MASCOT`.
- Style wire = `{variant, size (48–80, default 68), opacity (0.5–1, default 1)}`; unknown keys ignored, unknown variant → `MASCOT`.
- Single tap toggles count ↔ timer; no double tap; nothing opens the app from the bubble.
- Reduce motion = `Settings.Global.ANIMATOR_DURATION_SCALE == 0` (native) / `MediaQuery.disableAnimations` (Flutter): animators run at 0 ms, no pulse, no loops.
- Font Manrope 800 (counts, timer, pill), 700 (captions), tabular figures, from `assets/fonts/`.
- Kotlin unit tests are plain JVM/JUnit4 (no Robolectric): logic lives in pure classes; `View` subclasses carry none of it.
- No new dependencies. Every task ends green on its own `flutter test <file>` / gradle filter; Task 16 runs `bash tool/dev.sh precommit`.
- Commits go on the current branch `sensitive_protection`, never `main`; end each commit message with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.

## Review Focus

1. Counts of 10 000+: the board's `floor(n/100)/10 + 'k'` gives `123.4k`; a person expects `12k` — pinned in Task 3 (fixture case `ten_thousand_drop`).
2. A negative or absurd count/seconds from a corrupt store must read `0` / `0m` / `00:00`, never throw — Task 3 (`negative_garbage`).
3. Persisted style JSON with legacy keys or wrong types (`"size":"big"`) must load as defaults, not crash the accessibility service — Tasks 2 and 9.
4. Timer open + pill + pulse at the same moment, docked on either side: the body must not move and must stay on screen — Task 11.
5. A tier jump of more than one step (a burst) pulses once; a tier drop (midnight) only cross-fades — Task 3 (`transitions`) and Task 7 (preview `99→200`).

---

## File structure

**Shared**
- Modify `tool/home_widget/tokens.json` — `bubble-*` colours, lists, numbers.
- Modify `tool/home_widget/gen_tokens.dart` — emit `BubbleTokens` (Kotlin + Dart) from `bubble-*`.
- Create `test/fixtures/bubble_cases.json` — the model vectors both sides run.

**Dart** (`lib/features/content_counter/`)
- Modify `content_counter_core/domain/entities/counter_style_enums.dart` — `BubbleVariant` ×10 (`wire`, `label`, `blurb`).
- Modify `content_counter_bubble/domain/entities/bubble_style.dart` — variant/size/opacity.
- Create `content_counter_bubble/domain/bubble_model.dart` — pure formats/tier/labels/scalars.
- Create `content_counter_bubble/presentation/bubble_tokens.g.dart` (generated), `svg_path.dart`, `bubble_look.dart`, `bubble_frame.dart`, `bubble_brush.dart`, `bubble_face.dart`, `bubble_painter.dart`, `bubble_preview.dart`, `faces/{mascot,ring,liquid,hourglass,neon,steps,weather,bezel,drop,outline}_face.dart`.
- Modify `content_counter_appearance/presentation/bubble_style_screen.dart` — rewrite; delete `content_counter_appearance/presentation/widgets/bubble_preview.dart`.
- Modify `content_counter.dart` (barrel), `lib/features/additional_feature/appearance/presentation/appearance_screen.dart:145`, `content_counter_core/domain/usage_ladder.dart` (doc comment).
- Tests: `test/bubble_model_test.dart`, `test/svg_path_test.dart`, `test/bubble_painter_test.dart`, `test/bubble_preview_test.dart`, `test/bubble_style_screen_test.dart`; modify `test/counter_style_test.dart`, `test/content_counter_test.dart`.

**Kotlin** (`android/app/src/main/kotlin/com/errorxperts/detoxo/`)
- Create `overlay/bubble/BubbleTokens.kt` (generated), `BubbleStyleSpec.kt`, `BubbleModel.kt`, `BubbleEnvelope.kt`, `SvgPath.kt`, `BubbleLook.kt`, `BubbleFrame.kt`, `BubblePaints.kt`, `BubbleFace.kt`, `BubbleView.kt`, `faces/{Mascot,Ring,Liquid,Hourglass,Neon,Steps,Weather,Bezel,Drop,Outline}Face.kt`.
- Create `widget/Manrope.kt`; modify `widget/WidgetPainter.kt` (use it), `widget/ColorMath.kt` (`blendArgb`).
- Modify `overlay/ContentCounterBubble.kt` (host rewrite; old inner `BubbleStyleSpec` / `BubbleView` deleted), `engine/ContentCounter.kt` (provider), `engine/UsageLadder.kt` (doc comment).
- Tests (`android/app/src/test/kotlin/com/errorxperts/detoxo/overlay/bubble/`): `BubbleStyleSpecTest`, `BubbleModelTest`, `BubbleEnvelopeTest`, `SvgPathTest`, `BubbleLookTest`.

**Commands used below**
- Dart: `flutter test <file>`; `flutter analyze`.
- Kotlin: `cd android && JAVA_HOME=/opt/homebrew/Cellar/openjdk@17/17.0.18/libexec/openjdk.jdk/Contents/Home ./gradlew -q :app:testDebugUnitTest -x compileFlutterBuildDebug --tests 'com.errorxperts.detoxo.overlay.bubble.*'` (abbreviated `GRADLE_BUBBLE` below; results in `build/app/test-results/testDebugUnitTest/`).

---

### Task 1: Bubble tokens through the generator

**Files:**
- Modify: `tool/home_widget/tokens.json`
- Modify: `tool/home_widget/gen_tokens.dart`
- Create (generated): `android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/bubble/BubbleTokens.kt`, `lib/features/content_counter/content_counter_bubble/presentation/bubble_tokens.g.dart`

**Interfaces:**
- Produces Kotlin `internal object BubbleTokens` (package `com.errorxperts.detoxo.overlay.bubble`) and Dart `abstract final class BubbleTokens`, constant names = token name with the `bubble-` prefix stripped (`bubble-glass-from` → `GLASS_FROM` / `glassFrom`; lists `bubble-neon` → `NEON: IntArray` / `List<Color> neon`, `bubble-line` → `LINE` / `line`; numbers `bubble-ms-pop` → `MS_POP: Int` / `int msPop`).

- [ ] **Step 1: Add the tokens to `tokens.json`**

Colours (`color`): `bubble-glass-from #ffffff`, `bubble-glass-to #e6effc`, `bubble-glass-ring #b8cdef`, `bubble-glass-halo rgba(110,155,235,0.16)`, `bubble-glass-shadow rgba(50,100,200,0.38)`, `bubble-ink-navy #1c3d78`, `bubble-pill-bg #ffffff`, `bubble-pill-ink #111a2e`, `bubble-faint-light rgba(17,17,17,0.14)`, `bubble-faint-dark rgba(255,255,255,0.3)`, `bubble-mark-light rgba(255,255,255,0.6)`, `bubble-mark-dark rgba(255,255,255,0.22)`, `bubble-neon-0 #8fb8ff`, `bubble-neon-1 #7fe3a0`, `bubble-neon-2 #d4ec6a`, `bubble-neon-3 #ffc94d`, `bubble-neon-4 #ff8a65`, `bubble-neon-5 #ff5a5a`, `bubble-neon-bg-from #1b1e27`, `bubble-neon-bg-to #0d0f15`, `bubble-neon-pill-bg #15171e`, `bubble-line-0 #1c3d78`, `bubble-line-1 #1f7a3f`, `bubble-line-2 #6b8a12`, `bubble-line-3 #b86f0a`, `bubble-line-4 #b8321f`, `bubble-line-5 #5e0b12`, `bubble-liquid-glass rgba(255,255,255,0.75)`, `bubble-liquid-shadow rgba(50,80,140,0.25)`, `bubble-outline-glass rgba(255,255,255,0.72)`, `bubble-outline-shadow rgba(40,60,100,0.18)`, `bubble-mascot-eye #ffffff`, `bubble-mascot-pupil #1b2a8a`, `bubble-mascot-blush #ff8aa8`, `bubble-mascot-water #9cd6ff`, `bubble-weather-leaf #3fbf6f`, `bubble-weather-leaf-edge #1d7a44`, `bubble-weather-sun #f5a524`, `bubble-weather-fire #e8572f`, `bubble-weather-fire-edge #8c1d12`, `bubble-badge-bg #ffffff`, `bubble-sheen rgba(255,255,255,0.6)`, `bubble-chip-shadow rgba(0,0,0,0.2)`. Each with a one-line `usage` naming the style that uses it.

Lists (`colorList`): `bubble-neon` = `bubble-neon-0…5`; `bubble-line` = `bubble-line-0…5`.

Numbers (`number`): `bubble-size 68`, `bubble-edge 12`, `bubble-pill-h 22`, `bubble-pill-gap 8`, `bubble-pill-text 11.5`, `bubble-count-text 24`, `bubble-timer-text 20`, `bubble-timer-w 136`, `bubble-timer-w-hour 156`, `bubble-timer-w-dial 176`, `bubble-glow 12`, `bubble-pulse-halo 24`, `bubble-min-y-pct 20`, `bubble-max-y-pct 70`, and (`"type":"int"`) `bubble-ms-pop 420`, `bubble-ms-tap 480`, `bubble-ms-pulse 1100`, `bubble-ms-pill 3000`, `bubble-ms-pill-in 420`, `bubble-ms-pill-out 280`, `bubble-ms-appear 500`, `bubble-ms-crossfade 700`, `bubble-ms-wave 3200`, `bubble-ms-breath 2600`, `bubble-ms-sand 1600`, `bubble-loop-fps 30`.

Append to `source`: `"Bubble rules BR-01…BR-12 and the Ten Bubble Styles board: tokens prefixed bubble- generate overlay/bubble/BubbleTokens.kt and content_counter_bubble/presentation/bubble_tokens.g.dart."`

- [ ] **Step 2: Teach the generator the `bubble-` group**

In `gen_tokens.dart`: add `_bubbleKotlinPath` / `_bubbleDartPath` constants (paths above); in `_Tokens` add `bool _isBubble(String name) => name.startsWith('bubble-')` and getters `widget` / `bubble` returning a `_Tokens` view filtered on colours, lists and numbers (rules stay widget-only). Add `String _kotlinBubble(_Tokens t)` and `String _dartBubble(_Tokens t)` mirroring `_kotlin` / `_dart` but: package `com.errorxperts.detoxo.overlay.bubble`, object/class `BubbleTokens`, doc `/** Reel-bubble design tokens (Bubble rules BR-04/05): colours as ARGB ints, sizes in dp at size 68. */`, and names via a `_strip(name) => name.substring(7)` before `_upperSnake` / `_lowerCamel`. Register both in `outputs` so `--check` covers five files; existing outputs are built from `tokens.widget`. Update the header comment's output list.

- [ ] **Step 3: Generate and check**

Run: `dart run tool/home_widget/gen_tokens.dart && dart run tool/home_widget/gen_tokens.dart --check`
Expected: five `wrote …` lines, then `home-widget tokens: up to date`. `grep -c "static const Color" lib/features/content_counter/content_counter_bubble/presentation/bubble_tokens.g.dart` prints `43`; `grep -c "const val" android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/bubble/BubbleTokens.kt` prints `69` (43 colours + 26 numbers); `WidgetTokens.kt` contains no `BUBBLE_`.

- [ ] **Step 4: Commit**

```bash
git add tool/home_widget/tokens.json tool/home_widget/gen_tokens.dart android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/bubble/BubbleTokens.kt lib/features/content_counter/content_counter_bubble/presentation/bubble_tokens.g.dart
git commit -m "feat(bubble): generate BubbleTokens from the bubble- design tokens"
```

---

### Task 2: Dart variant enum and style entity

**Files:**
- Modify: `lib/features/content_counter/content_counter_core/domain/entities/counter_style_enums.dart:8-32`
- Modify: `lib/features/content_counter/content_counter_bubble/domain/entities/bubble_style.dart`
- Modify (keep compiling only): `lib/features/content_counter/content_counter_appearance/presentation/widgets/bubble_preview.dart`, `lib/features/content_counter/content_counter_appearance/presentation/bubble_style_screen.dart`
- Test: `test/counter_style_test.dart`

**Interfaces:**
- Produces `enum BubbleVariant { mascot, ring, liquid, hourglass, neon, steps, weather, bezel, drop, outline }` with `final String wire; final String label; final String blurb;` and `static BubbleVariant fromWire(String? v)` (→ `mascot` on unknown/null).
- Produces `class BubbleStyle extends Equatable { variant, size, opacity }` with `sizeMin 48, sizeMax 80, sizeDefault 68, opacityMin 0.5, opacityMax 1, opacityDefault 1`, `BubbleStyle.defaults()`, `fromWire(Map<String,dynamic>?)`, `toWire()` (exactly `variant`, `size`, `opacity`), `copyWith`.

- [ ] **Step 1: Rewrite the `BubbleStyle` group in `test/counter_style_test.dart`**

Tests: `defaults` (variant `mascot`, size 68, opacity 1); `wire tokens and labels are pinned in board order` (`values.map(wire)` equals the ten tokens; `values.map(label)` equals `Mascot, Ring, Liquid, Hourglass, Neon, Steps, Weather, Bezel, Drop, Outline`); `toWire has exactly variant, size, opacity` (`keys` unorderedEquals); `survives a wire round-trip` (ring, 72, 0.6); `legacy keys are ignored and old variants fall back` (`{'variant':'GLASS_ORB','textScale':1.2,'spacing':1.1,'showLabel':true,'showTime':false}` → `BubbleStyle.defaults()`); `fromWire clamps and defaults` (`null` → defaults; `size 999 → 80`, `size 10 → 48`, `opacity 5 → 1`, `opacity 0.1 → 0.5`, `variant 'NOPE' → mascot`, `size 'big'` (a String) → 68).

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/counter_style_test.dart`
Expected: FAIL (`mascot` isn't defined / `label` getter missing).

- [ ] **Step 3: Implement the enum and the entity**

`BubbleVariant` blurbs (verbatim from the board): Mascot `Your character, changing mood every hundred`; Ring `A ring that fills toward the next colour`; Liquid `Fills up like a glass`; Hourglass `The logo, with sand that runs out`; Neon `Dark glass with a coloured glow`; Steps `Five dots keep the score`; Weather `A small badge, from leaf to flame`; Bezel `Watch ticks that light up`; Drop `A drop that clings to the edge`; Outline `Just a line and a number`. Update the enum's doc comment to the shell/face model. `BubbleStyle`: drop the four fields and their ranges; `_clamp` treats a non-`num` as the fallback.

- [ ] **Step 4: Keep the old preview and screen compiling (both are replaced in Tasks 7–8)**

`bubble_preview.dart`: `paint` always calls `_drawOrb`; delete `_drawUsageRing`, `_drawEmoji`, `_drawPill`, the `usage_ladder` import and every `style.textScale` / `style.spacing` / `style.showLabel` read (use `1` / `false`); `_variantName(v)` → `v.label`. `bubble_style_screen.dart`: delete the Text size, Spacing, Show caption and Show time controls, `_TapRevealDemo`, `_previewTime`, `_variantLabel` (use `v.label`); Size slider uses `BubbleStyle.sizeMin/sizeMax`, `divisions: 8`.

- [ ] **Step 5: Verify**

Run: `flutter test test/counter_style_test.dart test/content_counter_test.dart && flutter analyze`
Expected: all PASS; `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/content_counter test/counter_style_test.dart
git commit -m "feat(bubble): ten board variants and a variant/size/opacity style"
```

---

### Task 3: Shared model fixture and Dart `BubbleModel`

**Files:**
- Create: `test/fixtures/bubble_cases.json`
- Create: `lib/features/content_counter/content_counter_bubble/domain/bubble_model.dart`
- Test: `test/bubble_model_test.dart`

**Interfaces:**
- Produces `abstract final class BubbleModel` with static: `int tier(int count)`; `String countText(int count)`; `String shortTime(int seconds)`; `String clock(int seconds)`; `int pct(int count)`; `int toNext(int count)`; `String nextLine(int count)`; `bool isDial(BubbleVariant v)`; `double timerWidth(int seconds, BubbleVariant v)`; `String collapsedLabel(int count, int seconds, BubbleVariant v)`; `String openLabel(int seconds)`; `BubbleWeather weather(int tier)`; `int stepsLit(int tier)`; `int bezelLit(int count)`; `double sandTop(int pct)`; `double sandBottom(int pct)`; `double neonGlow(int tier)`; `String outlineBadge(int count)`; `String mascotLine(int tier)`; `TierChange transition(int oldTier, int newTier)`. Plus `enum BubbleWeather { leaf, sun, fire }`, `enum TierChange { none, down, up }`.
- Produces the fixture, read by Task 10 too.

- [ ] **Step 1: Write the fixture**

`{"cases":[…],"transitions":[…]}`. Each case: `name, count, seconds, variant` and `expected` with keys `tier, countText, shortTime, clock, pct, toNext, nextLine, isDial, timerWidth, collapsedLabel, openLabel, weather, stepsLit, bezelLit, sandTop, sandBottom, neonGlow, outlineBadge, mascotLine`. The twelve cases (count, seconds, variant → the values that differ from the pattern):

| name | count | seconds | variant | key expectations |
|---|---|---|---|---|
| zero_mascot | 0 | 0 | MASCOT | tier 0 · `0` · `0m` · `00:00` · pct 0 · toNext 100 · `First reel turns it green.` · dial false · 136 · `0 reels today, 0m watched. Tap to show the timer.` · `Watch time today 00:00. Tap to show the reel count.` · leaf · 0 · 0 · 13.0 · 53.0 · 10 · `−100` · `Glass · happy to see you` |
| tier1_liquid | 47 | 1316 | LIQUID | tier 1 · `47` · `21m` · `21:56` · 47 · 53 · `53 reels to the next colour.` · dial true · 136 · `47 reels today, 53 to the next colour. Tap to show the timer.` · leaf · 1 · 4 · 22.4 · 42.66 · 16 · `−53` · `Green · big smile` |
| tier2_ring | 152 | 4328 | RING | tier 2 · `152` · `1h 12m` · `1:12:08` · 52 · 48 · dial true · **176** · `152 reels today, 48 to the next colour. Tap to show the timer.` · leaf · 2 · 5 · 23.4 · 41.56 · 22 · `−48` · `Lime · surprised, that many already?` |
| tier3_weather | 238 | 7200 | WEATHER | tier 3 · `2h` · `2:00:00` · 38 · 62 · dial false · 156 · `238 reels today, 2h watched. Tap to show the timer.` · **sun** · 3 · 3 · 20.6 · 44.64 · 28 · `−62` · `Amber · worried` |
| tier4_hourglass | 341 | 36240 | HOURGLASS | tier 4 · `10h 4m` · `10:04:00` · 41 · 59 · dial true · 176 · `341 reels today, 59 to the next colour. Tap to show the timer.` · fire · 4 · 4 · 21.2 · 43.98 · 34 · `−59` · `Orange-red · upset` |
| tier5_outline | 467 | 3599 | OUTLINE | tier 5 · `59m` · `59:59` · pct **100** · toNext 33 · `Final colour reached.` · dial true · 136 · `467 reels today, final colour. Tap to show the timer.` · fire · 5 · **10** · 33.0 · 31.0 · 40 · `max` · `Deep red · palm up: stop` |
| over_999_neon | 1240 | 3600 | NEON | `1.2k` · `1h` · `1:00:00` · 100 · 60 · `Final colour reached.` · dial false · 156 · `1.2k reels today, 1h watched. Tap to show the timer.` · `max` |
| exactly_100_bezel | 100 | 2812 | BEZEL | tier 2 · `100` · `46m` · `46:52` · pct 0 · toNext 100 · `100 reels to the next colour.` · dial true · 176 · `100 reels today, 100 to the next colour. Tap to show the timer.` · bezelLit 0 · 13.0 · 53.0 · `−100` |
| thousand_even_steps | 1000 | 59 | STEPS | `1k` · `0m` · `00:59` · 100 · 100 · dial false · 136 · `1k reels today, 0m watched. Tap to show the timer.` · `max` |
| ten_thousand_drop | 12345 | 86399 | DROP | `12k` · `23h 59m` · `23:59:59` · 100 · 55 · dial false · 156 · `12k reels today, 23h 59m watched. Tap to show the timer.` · `max` |
| negative_garbage | -5 | -7 | MASCOT | same as zero_mascot |
| nineteen_fifty | 1950 | 0 | RING | `1.9k` · `0m` · `00:00` · 100 · 50 · dial true · 176 · `1.9k reels today, final colour. Tap to show the timer.` · bezelLit 10 · `max` |

Every case carries all 19 `expected` keys; a row above lists only the values that are not implied by the algorithms in Step 4 (for tier 5 those are always: weather `fire`, stepsLit 5, bezelLit 10, sandTop 33.0, sandBottom 31.0, neonGlow 40, mascotLine `Deep red · palm up: stop`). The minus in `outlineBadge` is U+2212. `transitions`: `[{"from":0,"to":1,"expected":"up"},{"from":1,"to":3,"expected":"up"},{"from":3,"to":3,"expected":"none"},{"from":5,"to":0,"expected":"down"},{"from":2,"to":1,"expected":"down"}]`.

- [ ] **Step 2: Write `test/bubble_model_test.dart`**

Mirror `test/home_widget_model_test.dart`: read the fixture with `File(...)`, one `test(c['name'])` per case building `actual = _fields(count, seconds, BubbleVariant.fromWire(variant))` (a map keyed exactly like `expected`; `weather`/`transition` as lowercase enum names, `isDial` bool); `expect(actual.keys, unorderedEquals(expected.keys))`; every key `expect(actual[k], value)` except `sandTop`/`sandBottom` with `closeTo(value, 1e-6)`. One `test('transitions')` over the array.

- [ ] **Step 3: Run to verify it fails**

Run: `flutter test test/bubble_model_test.dart`
Expected: FAIL — `BubbleModel` undefined.

- [ ] **Step 4: Implement `BubbleModel`**

Algorithms the fixture does not fully determine: `countText` — `n = max(0, count)`; `n ≤ 999 → "$n"`; `n < 10000 → tenths = n ~/ 100; tenths % 10 == 0 ? "${tenths ~/ 10}k" : "${tenths ~/ 10}.${tenths % 10}k"`; else `"${n ~/ 1000}k"`. `tier` via `WidgetRules.tierStep / maxTier` (import `home_content_counter/domain/widget_rules.g.dart`). `pct`: `n == 0 → 0; tier == 5 → 100; else n % 100`. `toNext`: `(n ~/ 100 + 1) * 100 − n`. `timerWidth`: ring/hourglass/bezel → 176, else `seconds ≥ 3600 ? 156 : 136`. `isDial`: ring, liquid, hourglass, bezel, outline. `sandTop = 13 + pct * 0.20`, `sandBottom = 53 − pct * 0.22`, `neonGlow = 10 + 6 * tier`, `bezelLit = tier == 5 ? 10 : pct ~/ 10`, `stepsLit = tier`, `weather: tier ≤ 2 leaf, 3 sun, else fire`. Doc comment: MIRROR CONTRACT with `overlay/bubble/BubbleModel.kt`, pinned by `test/fixtures/bubble_cases.json`.

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/bubble_model_test.dart`
Expected: 13 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add test/fixtures/bubble_cases.json test/bubble_model_test.dart lib/features/content_counter/content_counter_bubble/domain/bubble_model.dart
git commit -m "feat(bubble): colour-free BubbleModel with the shared fixture"
```

---

### Task 4: Dart SVG path parser

**Files:**
- Create: `lib/features/content_counter/content_counter_bubble/presentation/svg_path.dart`
- Test: `test/svg_path_test.dart`

**Interfaces:**
- Produces `Path parseSvgPath(String d)` in board units (caller translates/scales the canvas). Supports `M m L l H h V v Q q C c Z z`, comma/space separators, and a `-` glued to the previous number (`q0 8-8 8`). Unknown command → `FormatException`.

- [ ] **Step 1: Write the test**

`bounds of a square` (`'M0 0 h10 v10 z'` → `getBounds() == Rect.fromLTWH(0,0,10,10)`); `glued negatives` (`'M1 1 q0 8-8 8'` bounds `left == -7` within 1e-6, `width == 8`); `the hourglass mark` (`'M9 3 H31 Q37 3 37 9 V17 Q37 23 30 29 L27 32 L30 35 Q37 41 37 47 V55 Q37 61 31 61 H9 Q3 61 3 55 V47 Q3 41 10 35 L13 32 L10 29 Q3 23 3 17 V9 Q3 3 9 3 Z'` bounds `Rect.fromLTRB(3,3,37,61)`); `unknown command throws` (`'M0 0 A1 1 0 0 1 2 2'` → `throwsFormatException`).

- [ ] **Step 2: Run to verify it fails** — `flutter test test/svg_path_test.dart` → FAIL (undefined).

- [ ] **Step 3: Implement** — tokenizer regex `[MmLlHhVvQqCcZz]|-?\d*\.?\d+`; a command repeats while numbers remain.

- [ ] **Step 4: Run to verify it passes** — same command → 4 PASS.

- [ ] **Step 5: Commit** — `git add lib/features/content_counter/content_counter_bubble/presentation/svg_path.dart test/svg_path_test.dart && git commit -m "feat(bubble): minimal SVG path parser for board artwork"`

---

### Task 5: Dart shell — look, frame, brush, face interface, painter, face scaffolds

**Files:**
- Create: `…/content_counter_bubble/presentation/bubble_look.dart`, `bubble_frame.dart`, `bubble_brush.dart`, `bubble_face.dart`, `bubble_painter.dart`, `faces/*_face.dart` (ten scaffolds)
- Test: `test/bubble_painter_test.dart`

**Interfaces:**
- `final class BubbleLook { const BubbleLook({fillFrom, fillTo, ring, ink, faint, mark, neon, line, halo, shadow}); static BubbleLook of(int tier); static BubbleLook lerp(BubbleLook a, BubbleLook b, double t); }` and `LinearGradient stageGradient(BubbleVariant v)` (light stage for liquid/steps/bezel/outline: 170° `#F2F4F8 → #DFE4EC`; else `#2B3448 → #161B26 (60 %) → #0D1017`).
- `final class BubbleFrame { body: Rect; s: double; look; tier; prevTier; blend; count; pct; countText; clock; expand; pop; pulse; pill; loopT; open; dockedRight; }` with `double u(double v) => v * s` and `Offset at(double x, double y)` (board units → canvas).
- `final class BubbleBrush { BubbleBrush(Canvas canvas, double opacity); void shell(BubbleFrame f, {Color? fillFrom, Color? fillTo, double radiusOuter = 34, double radiusEdge = 34, Color? ring, Color? halo, Color? shadow}); void text(String s, Offset center, {required double size, required Color color, double scale = 1, double letterSpacing = 0, double alpha = 1, FontWeight weight = FontWeight.w800, double glow = 0, Color? glowColor}); void mark(BubbleFrame f, Offset topLeft, double w, double h, {required Color fill, required Color stroke, double? grainT, double alpha = 1}); void path(String d, Offset origin, double scale, Paint paint); }` + `abstract final class BubblePaths` (the string constants in Task 6's table).
- `abstract class BubbleFace { const BubbleFace(); double get countSize => 24; Offset get countOffset => Offset.zero; double get timerPaddingLeft => 15; BubbleOutsets get outsets => BubbleOutsets.none; double get edge => 12; bool get shellCount => true; bool loops({required bool open}) => false; int get loopPeriodMs => 0; Color countColor(BubbleLook l) => l.ink; Color timerColor(l) => l.ink; Color? markFill(l) => l.mark; Color markStroke(l) => l.ink; Color pillBackground(l) => BubbleTokens.pillBg; Color pillInk(l) => BubbleTokens.pillInk; Color pillOutline(l) => l.ring; Color pulseColor(l) => l.ring; void drawBackground(BubbleFrame f, BubbleBrush b) => b.shell(f); void drawDial(BubbleFrame f, BubbleBrush b) {} void drawOverlay(BubbleFrame f, BubbleBrush b) {} }`; `final class BubbleOutsets { const BubbleOutsets(left, top, right, bottom); static const none; }`; `extension BubbleVariantFace on BubbleVariant { BubbleFace get face }` (exhaustive switch).
- `class BubblePainter extends CustomPainter { BubblePainter({required BubbleFrame frame, required BubbleFace face, required double opacity, int? remaining}); }`.

- [ ] **Step 1: Write `test/bubble_painter_test.dart`**

`TestWidgetsFlutterBinding.ensureInitialized()`. Helper `BubbleFrame frameFor(BubbleVariant v, {int count = 152, int seconds = 4328, double expand = 0, double pill = 0, double pulse = 0, double loopT = 0, bool dockedRight = true, int tier = 2, int prevTier = 2})` building `body` from `expand` (collapsed 68 square at the docked side of a 200×160 canvas; width `lerp(68, timerWidth, expand)` growing inward). Tests: group `BubbleLook` — `of(0).ink == BubbleTokens.inkNavy`, `of(3).ink == WidgetTokens.widgetInk`, `of(4).ink == WidgetTokens.widgetInkInverse`, `of(2).ring == WidgetTokens.tier2To`, `lerp(of(1), of(2), 1) == of(2)` field-wise, `lerp(of(1), of(2), 0.5).fillTo == Color.lerp(tier1To, tier2To, .5)`. Group `paints every variant in every state`: for each `BubbleVariant` × `{collapsed, open (expand 1), pill 1, pulse .5, loop .3, dockedLeft, remaining 3, tier0 glass, tier5 blending from 4 (blend .5)}` → `expect(() => BubblePainter(...).paint(canvas, Size(200,160)), returnsNormally)` on a `PictureRecorder` canvas. `shouldRepaint` true when the frame differs, false when equal.

- [ ] **Step 2: Run to verify it fails** — `flutter test test/bubble_painter_test.dart` → FAIL (undefined).

- [ ] **Step 3: Implement `bubble_look.dart`**

Tier 0: `glassFrom/glassTo/glassRing/inkNavy/faintLight/markLight/neon[0]/line[0]/glassHalo/glassShadow`. Tier n ≥ 1: `WidgetTokens.tierFrom[n]/tierTo[n]`, `ring = tierTo[n]`, `ink = n ≤ 3 ? widgetInk : widgetInkInverse`, `faint = n ≥ 4 ? faintDark : faintLight`, `mark = n ≥ 4 ? markDark : markLight`, `neon = neon[n]`, `line = line[n]`, `halo = tierTo[n].withValues(alpha: 0x2E / 255)`, `shadow = tierTo[n].withValues(alpha: 0x73 / 255)`. `lerp` = `Color.lerp` per field.

- [ ] **Step 4: Implement `bubble_frame.dart`, `bubble_brush.dart`, `bubble_face.dart`**

Brush shell: body rounded rect (radii: outer corners `radiusOuter·s`, docked-side corners `radiusEdge·s`, the docked side = `f.dockedRight ? right : left`), fill = 160° gradient `fillFrom → fillTo` with alpha × `opacity`; halo stroke 7·s outside in `halo`; shadow: the shape blurred (sigma 6·s, dy 3·s) in `shadow` under everything; ring stroke 1.5·s in `ring`; inner hairline 1.5·s white at .95 (tier 0) / .55. Text: `TextPainter`, `fontFamily 'Manrope'`, `FontFeature.tabularFigures()`, optional glow = same text drawn with `MaskFilter.blur(normal, glow)`. `mark`: `BubblePaths.mark` scaled to `w × h` from the 40×64 box, fill/stroke (stroke 4 in box units), static grains, plus the falling grain at `y = −6 + 16·grainT`, alpha `sin(π·grainT)` when `grainT != null`. `path`: `canvas.save/translate/scale/drawPath/restore`.

- [ ] **Step 5: Implement `bubble_painter.dart`**

Order: `face.drawBackground` → `face.drawDial` → count (if `face.shellCount` and `remaining == null`: `countText` at the collapsed square's centre + `countOffset·s`, size `countSize·s`, letterSpacing `−0.6·s`, scale `popScale × (1 − 0.4·expand)`, alpha `1 − expand`, colour `face.countColor`) → remaining (`"$remaining"` at `at(34, 29)`, caption `left` Manrope 700 `11·s` at `at(34, 52)`, both `countColor`) → timer (alpha `((expand − 0.3) / 0.7).clamp(0,1)`: mark 20×31 at `body.left + timerPaddingLeft·s`, then gap 8·s, then `clock` size 20·s letterSpacing −0.4·s in `timerColor`; mark fill `face.markFill`, stroke `face.markStroke`, `grainT = face.loops(open: true) && f.open ? loopT : null`) → `face.drawOverlay` → pulse ring (if `pulse > 0`: the body shape inflated by `23.8·s·pulse`, stroke 2.5·s, `pulseColor` alpha `0.9·(1 − pulse)`) → pill (if `pill > 0 && !open`: centred above the collapsed square, `pill-h·s` tall, radius half, pad 9·s, `shortTime` text 11.5·s, bg `pillBackground`, ink `pillInk`, 1·s outline `pillOutline`, translated down `28·s·(1 − pill)`, alpha `pill`). `popScale = 1 + 0.18 · (pop < 0.4 ? pop / 0.4 : 1 − (pop − 0.4) / 0.6)`. The collapsed square is the `size × size` square at the docked side of `body`.

- [ ] **Step 6: Scaffold the ten faces**

Each `final class XFace extends BubbleFace { const XFace(); }` overriding only the scalars from Task 6's table (`countSize`, `countOffset`, `timerPaddingLeft`, `outsets`, `edge`, `shellCount`, `loops`, `loopPeriodMs`, colour hooks); `BubbleVariantFace.face` maps all ten.

- [ ] **Step 7: Run to verify it passes** — `flutter test test/bubble_painter_test.dart` → all PASS; `flutter analyze` clean.

- [ ] **Step 8: Commit** — `git add lib/features/content_counter/content_counter_bubble/presentation test/bubble_painter_test.dart && git commit -m "feat(bubble): Flutter shell painter, look, brush and face scaffolds"`

---

### Task 6: Dart faces — ten abilities

**Files:**
- Modify: `…/content_counter_bubble/presentation/faces/*_face.dart`, `bubble_brush.dart` (`BubblePaths` constants)
- Test: `test/bubble_painter_test.dart` (filtered per face)

**Interfaces:** consumes Task 5. All numbers are board units at size 68 (multiply by `f.s`; place with `f.at`). Overlays that "fade with the count" draw at alpha `1 − f.expand`.

`BubblePaths` (verbatim from the board, viewBox noted):
- `mark` (40×64): `M9 3 H31 Q37 3 37 9 V17 Q37 23 30 29 L27 32 L30 35 Q37 41 37 47 V55 Q37 61 31 61 H9 Q3 61 3 55 V47 Q3 41 10 35 L13 32 L10 29 Q3 23 3 17 V9 Q3 3 9 3 Z`; grains: top rect (15.5,12,9,9) r2.2 rotated 45° about (20,16.5); falling (17.8,27.8,4.4,4.4) r1.1 rotated 45° about (20,30); bottom (14.5,44,11,11) r2.6 rotated 45° about (20,49.5).
- `hourglassBig` (68 box): `M26 12 H42 Q46 12 46 16 V22 Q46 26 41 30 L39 32 L41 34 Q46 38 46 42 V50 Q46 54 42 54 H26 Q22 54 22 50 V42 Q22 38 27 34 L29 32 L27 30 Q22 26 22 22 V16 Q22 12 26 12 Z`; `clipTop`: `M23 13 H45 V24 Q45 27 40 31 L34 32 L28 31 Q23 27 23 24 Z`; `clipBottom`: `M23 53 H45 V40 Q45 37 40 33 L34 32 L28 33 Q23 37 23 40 Z`.
- Mascot: `hand` `M48 54 v-10 q0-2 2-2 q2 0 2 2 v6 v-9 q0-2 2-2 q2 0 2 2 v9 v-8 q0-2 2-2 q2 0 2 2 v8 v-5 q0-2 2-2 q2 0 2 2 v9 q0 8-8 8 h-2 q-6 0-6-6z`; `sweat` `M52 20 q3 5 0 8 q-3 -3 0 -8z`; `tears` `M21 38 q-1 6 0 10 M47 38 q1 6 0 10`; brows/mouth per mood (mood = tier):

| mood | brows | mouth | mouth fill | blush α | sweat α | tears α | hand α | pupil dx,dy |
|---|---|---|---|---|---|---|---|---|
| 0 | `M19 22 q6 -4 12 -1 M37 21 q6 -3 12 1` | `M26 42 q8 8 16 0` | none | .7 | 0 | 0 | 0 | 0,0 |
| 1 | same | `M25 41 q9 10 18 0` | pupil @.9 | .7 | 0 | 0 | 0 | 0,0 |
| 2 | `M19 20 q6 -5 12 -2 M37 18 q6 -3 12 2` | oval centre (34,41) rx 4 ry 5 | pupil @.9 | 0 | 0 | 0 | 0 | 0,−1 |
| 3 | `M19 20 q6 2 12 3 M37 23 q6 -1 12 -3` | `M27 44 h14` | none | 0 | .9 | 0 | 0 | 1,0 |
| 4 | `M19 19 q6 3 12 5 M37 24 q6 -2 12 -5` | `M26 46 q8 -7 16 0` | none | 0 | .9 | .8 | 0 | 0,1 |
| 5 | same as 4 | `M26 47 q8 -8 16 0` | none | 0 | 0 | 1 | 1 | 0,1 |

- Weather icons (24 box, drawn 14 wide): `leaf` `M5 20 C5 9 11 4 21 4 C21 14 15 20 5 20 Z M5 20 L15 10` (fill `weatherLeaf`, stroke `weatherLeafEdge` 1.6); `sunRays` `M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1 7 17M17 7l2.1-2.1` (stroke `weatherSun` 2) + disc (12,12) r5; `fire` body `M12 2 C13 7 18 9 18 14` then the bottom half-circle from (18,14) to (6,14) (`arcTo(Rect(6,8,18,20), 0, π)`) then `C6 11 8 9 9 7 C9 10 11 10 11 8 C11 6 12 4 12 2 Z` (fill `weatherFire`, stroke `weatherFireEdge` 1.4).

| Face | Scalars | Drawing |
|---|---|---|
| Mascot | `shellCount false` | overlay (alpha 1−expand): highlight ellipse centre (22,18) rx9 ry4 white .55; eye whites r7 at (25,30),(43,30) `mascotEye`; pupils r3.6 at (26+dx,31+dy),(44+dx,31+dy) `mascotPupil`; glints r1.1 at (27.2,29.6),(45.2,29.6) white; brows stroke `ink` 2.2 round; mouth stroke `ink` 2.4 round + fill; blush r3 at (16,40),(52,40) `mascotBlush`; sweat `mascotWater`; tears stroke `mascotWater` 2; hand fill white stroke `mascotPupil` 1.6; chip: rounded rect h18 r9 centred at (34,56), width `textWidth + 14`, `badgeBg`, shadow 0 1 4 `chipShadow`, `countText` 11.5 w800 `pillInk`. |
| Ring | `countSize 22`, `timerPaddingLeft 72` | dial: track circle (34,34) r30 stroke 4 `faint`; arc same, stroke 4 round cap `ink`, from −90° sweep `pct·3.6°`. |
| Liquid | `loops(open) true`, `loopPeriodMs msWave`, `countColor = tier ≥ 4 && pct > 55 ? white : pillInk`, `markFill white .5` | background: `shell(fillFrom: liquidGlass, fillTo: liquidGlass, shadow: liquidShadow)` then, clipped to the body shape, the tier gradient from `y = 68·(1 − pct/100)` to 68; crest: half-ellipses rx14 ry8 white .55 every 28 along the level, offset `x = −14·sin(π·loopT)`, clipped to the 12 above the level. |
| Hourglass | `countSize 20`, `timerPaddingLeft 70`, `loops(open) = open`, `loopPeriodMs msSand` | dial: `hourglassBig` fill white .35 stroke `ink` 2 at alpha .55; sand rects (23, sandTop, 22×20) clipped by `clipTop` and (23, sandBottom, 22×22) clipped by `clipBottom`, `ink` alpha .5; count drawn with `glow 8` white .6. |
| Neon | `countColor/timerColor/pillInk/pillOutline/pulseColor = neon`, `pillBackground neonPillBg`, `markFill null`, `markStroke neon` | background: body fill 160° `neonBgFrom → neonBgTo`, inner hairline white .1, outline 1.5 `neon`, glow = body shape blurred sigma 9 and `neonGlow/2`, `neon` at alpha .6; count/timer text `glow 10` in `neon`. |
| Steps | `countSize 22`, `countOffset (0,−5)` | overlay (alpha 1−expand): five dots r3 at y 54, x = 14 + 10·i; `i < stepsLit ? ink : faint`. |
| Weather | `outsets (0,4,4,0)` | overlay: badge circle (60,8) r12 `badgeBg` shadow 0 2 6 black .25; icon 14 box centred (60,8): draw `weather(prevTier)` at alpha `1 − blend` and `weather(tier)` at `blend`. |
| Bezel | `countSize 21`, `timerPaddingLeft 70` | dial: ten lines (34,6)–(34,12) rotated `36°·i` about (34,34), stroke 3 round; `i < bezelLit ? ink : faint`. |
| Drop | `edge 0`, `loops(open) true`, `loopPeriodMs msBreath` | background: `shell(radiusEdge: 10)`; the whole face scaled `1 + 0.06·sin(π·loopT)` about the docked edge's centre (painter applies when `loops`); overlay: sheen ellipse centre (23,15) rx11 ry5 `sheen` (mirrored to x 45 when docked left). |
| Outline | `outsets (6,0,0,4)`, `countColor/timerColor/markStroke = line`, `markFill null` | background: body fill `outlineGlass`, inset outline 3 `line`, shadow 0 10 24 `outlineShadow`, no halo; overlay (alpha 1−expand): badge rounded rect h20 r10 from x −6, y 52, width `textWidth + 14`, fill `line`, `outlineBadge` white 11 w800. |

- [ ] **Step 1: Mascot** — implement per the table; run `flutter test test/bubble_painter_test.dart --name Mascot` → PASS.
- [ ] **Step 2: Ring** — same, `--name Ring`.
- [ ] **Step 3: Liquid** — `--name Liquid`.
- [ ] **Step 4: Hourglass** — `--name Hourglass`.
- [ ] **Step 5: Neon** — `--name Neon`.
- [ ] **Step 6: Steps** — `--name Steps`.
- [ ] **Step 7: Weather** — `--name Weather`.
- [ ] **Step 8: Bezel** — `--name Bezel`.
- [ ] **Step 9: Drop** — add the breath scale to the painter (`if (face.loops(open: f.open)) canvas.scale about the docked edge`); `--name Drop`.
- [ ] **Step 10: Outline** — `--name Outline`.
- [ ] **Step 11: Full run and commit** — `flutter test test/bubble_painter_test.dart && flutter analyze` → PASS / clean; `git add lib/features/content_counter/content_counter_bubble/presentation && git commit -m "feat(bubble): the ten Flutter faces"`

---

### Task 7: Animated `BubblePreview`, hub card, barrel, old preview removed

**Files:**
- Create: `…/content_counter_bubble/presentation/bubble_preview.dart`
- Delete: `…/content_counter_appearance/presentation/widgets/bubble_preview.dart`
- Modify: `lib/features/content_counter/content_counter.dart` (exports), `lib/features/additional_feature/appearance/presentation/appearance_screen.dart:145-149`, `test/content_counter_test.dart:291-301` (remove the `formatBubbleClock` group), `…/content_counter_appearance/presentation/bubble_style_screen.dart` (import path only)
- Test: `test/bubble_preview_test.dart`

**Interfaces:**
- Produces `class BubblePreview extends StatefulWidget { const BubblePreview({required BubbleStyle style, required int count, Duration watch = Duration.zero, double area = 132, bool animate = true, bool interactive = false, bool dockedRight = true, bool excludeFromSemantics = false, super.key}); State createState() => BubblePreviewState(); }` and `class BubblePreviewState extends State<BubblePreview> with TickerProviderStateMixin { void replayAppear(); void toggleTimer(); bool get isOpen; }`.
- Barrel exports `content_counter_bubble/presentation/bubble_preview.dart` and `content_counter_bubble/domain/bubble_model.dart`; `formatBubbleClock` no longer exists.

- [ ] **Step 1: Write `test/bubble_preview_test.dart`**

Pump inside `MaterialApp(home: Scaffold(body: …))`. Tests: `every variant builds still` (for each variant, `animate: false`, `count 152`, `watch 4328 s` → `find.bySemanticsLabel(BubbleModel.collapsedLabel(152, 4328, v))` findsOneWidget); `a tap opens the timer and reads the open label` (`interactive: true`, tap, `pumpAndSettle` → `find.bySemanticsLabel(BubbleModel.openLabel(4328))`, `isOpen` true; tap again → collapsed label); `reduce motion schedules no frames` (wrap in `MediaQuery(data: MediaQueryData(disableAnimations: true))`, change `count` 99 → 100 via `pumpWidget`, `pump()` once → `tester.binding.transientCallbackCount == 0`); `a burst across two tiers animates once and settles` (`animate: true`, count 99 → 200, `pumpAndSettle()` completes within 3 s and the label reads 200); `replayAppear settles` (`GlobalKey<BubblePreviewState>`, call it, `pump(const Duration(seconds: 4))`, no exception, `transientCallbackCount == 0` for a non-looping variant).

- [ ] **Step 2: Run to verify it fails** — `flutter test test/bubble_preview_test.dart` → FAIL (import missing).

- [ ] **Step 3: Implement `bubble_preview.dart`**

Controllers (ms from `BubbleTokens`): `_blend msCrossfade`, `_pop msPop`, `_pulse msPulse`, `_expand msTap` with `Cubic(.34, 1.36, .64, 1)`, `_pill` (forward `msPillIn`, reverse `msPillOut`) + a `msPill` `Timer`, `_appear msAppear` same cubic; one `Ticker` for loops (`loopT = (elapsed.inMilliseconds % face.loopPeriodMs) / period`) running only when `face.loops(open: isOpen)` and not still. `still = !animate || MediaQuery.disableAnimationsOf(context)`; when still every controller sits at its end value and the ticker never starts. `didUpdateWidget`: `BubbleModel.transition(oldTier, newTier)` → `up`: remember `prevLook`, `_blend.forward(from 0)`, `_pulse.forward(from 0)`, `showPill()`; `down`: blend only; same tier and count changed → `_pop.forward(from 0)`. `replayAppear()`: `_appear.forward(from 0)` + `showPill()`. Build: `Semantics(label: isOpen ? openLabel : collapsedLabel, button: interactive, excludeSemantics: true)` → `GestureDetector(onTap: interactive ? toggleTimer : null)` → `SizedBox(area × area)` → `Transform.scale(appear)` → `CustomPaint(BubblePainter(frame, face, opacity))`. The frame's `body`: the collapsed square is centred in the area; the body width is `lerp(size, timerWidth, _expand.value)` growing inward (`dockedRight` → leftwards). `BubbleLook` = `lerp(prevLook, BubbleLook.of(tier), _blend.value)`.

- [ ] **Step 4: Re-point the hub and the barrel; remove the old preview and `formatBubbleClock`**

`appearance_screen.dart`: `BubblePreview(style: appearance.bubble, count: today, watch: count.timeToday, area: 88)`. Barrel: swap the export path, add `bubble_model.dart`. Delete the old file; delete the `formatBubbleClock` test group; the style screen imports the new path.

- [ ] **Step 5: Verify** — `flutter test test/bubble_preview_test.dart test/content_counter_test.dart && flutter analyze && bash tool/check_boundaries.sh` → PASS / clean / no new violation.

- [ ] **Step 6: Commit** — `git add -A lib/features/content_counter lib/features/additional_feature/appearance test && git commit -m "feat(bubble): animated BubblePreview mirroring the native shell"`

---

### Task 8: Bubble style screen

**Files:**
- Modify (rewrite): `lib/features/content_counter/content_counter_appearance/presentation/bubble_style_screen.dart`
- Test: `test/bubble_style_screen_test.dart`

**Interfaces:** consumes `BubblePreview` (Task 7), `BubbleModel`, `stageGradient`, `VariantCarousel` / `VariantOption`, `SectionHeader`, `AdaptiveSlider`, `CounterAppearanceCubit.setBubble`, `ContentCounterCubit.state.today/.timeToday`.

- [ ] **Step 1: Write `test/bubble_style_screen_test.dart`**

Set up like `test/home_widget_screen_test.dart` (its `_FakeAppearance` recording `setBubbleStyle` calls, a fake `ContentCounterRepository` whose `watch()` is an empty stream and `current()` returns `ContentCount.empty()`, a fake `BubbleRepository` with `canShow() → true`; `_theme()` with `GlassTokens.dark`; `MultiBlocProvider` of `CounterAppearanceCubit` + `ContentCounterCubit`). Tests: `shows the ten styles and the two controls` (`find.text('Mascot')`, `find.text('Ring')` found; `find.text('Size')`, `find.text('Opacity')`, `find.text('Preview count')`, `find.text('Replay appear')` found; `find.text('Show caption')`, `find.text('Show time on tap')`, `find.text('Text size')` findsNothing); `picking Ring pushes the style` (tap `'Ring'`, `pump(300 ms)` → the fake's last style `.variant == BubbleVariant.ring` and the blurb `'A ring that fills toward the next colour'` is shown); `the mascot shows its mood line` (default style → `find.textContaining('happy to see you')`); `the stage preview is interactive` (`find.byType(BubblePreview)` first has `interactive == true`).

- [ ] **Step 2: Run to verify it fails** — `flutter test test/bubble_style_screen_test.dart` → FAIL.

- [ ] **Step 3: Rewrite the screen**

`ListView` children: `_Stage` (height 220, `AppRadius.lg`, `stageGradient(style.variant)`, `BubblePreview(key: _previewKey, style, count, watch, area: 180, interactive: true, dockedRight: true)` aligned right with 12 dp padding, a muted `'Tap the bubble for the timer'` bottom-left); a row with `_LabeledSlider('Preview count', 0–500, divisions 50, '$n reels')` and a `TextButton('Replay appear')` → `_previewKey.currentState?.replayAppear()`; `SectionHeader('Style')` + `VariantCarousel` (ten `VariantOption(label: v.label, selected, onTap: setStyle(variant: v), preview: BubblePreview(style.copyWith(variant: v), count, watch, area: 64, animate: false, excludeFromSemantics: true))`); `Text(style.variant.blurb)` and `Text(variant == mascot ? BubbleModel.mascotLine(tier) : BubbleModel.nextLine(count))` muted; `SectionHeader('Customize')` + Size (`sizeMin–sizeMax`, divisions 8, `'${v.round()} dp'`) + Opacity (`opacityMin–opacityMax`, divisions 5, percent). `_previewCount` seeds from the live count (else 137); `watch` = `context.watch<ContentCounterCubit>().state.timeToday`. Keep `_LabeledSlider` as is.

- [ ] **Step 4: Verify** — `flutter test test/bubble_style_screen_test.dart && flutter analyze` → PASS / clean.

- [ ] **Step 5: Commit** — `git add lib/features/content_counter/content_counter_appearance test/bubble_style_screen_test.dart && git commit -m "feat(bubble): style screen with the ten styles, size and opacity"`

---

### Task 9: Kotlin `BubbleStyleSpec`

**Files:**
- Create: `android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/bubble/BubbleStyleSpec.kt`
- Test: `android/app/src/test/kotlin/com/errorxperts/detoxo/overlay/bubble/BubbleStyleSpecTest.kt`

**Interfaces:**
- Produces `internal data class BubbleStyleSpec(val variant: String = MASCOT, val sizeDp: Float = 68f, val opacity: Float = 1f) { companion object { const val MASCOT … OUTLINE; val ALL: List<String>; fun fromJson(json: String?): BubbleStyleSpec } }`.

- [ ] **Step 1: Write the test** — `defaults on null and empty`; `reads the three keys` (`{"variant":"RING","size":72,"opacity":0.6}`); `clamps` (size 999 → 80f, 10 → 48f; opacity 5 → 1f, 0.1 → 0.5f); `legacy and unknown variants fall back to MASCOT` (`GLASS_ORB`, `NOPE`, with `textScale`/`showTime` present → equals `BubbleStyleSpec()`); `wrong types are defaults` (`{"size":"big","opacity":[1]}` → defaults); `garbage JSON is defaults` (`"not json"`).
- [ ] **Step 2: Run to verify it fails** — `GRADLE_BUBBLE` → compilation error.
- [ ] **Step 3: Implement** — `JSONObject.optString/optDouble`, `coerceIn(48f, 80f)` / `coerceIn(0.5f, 1f)`, `variant.takeIf { it in ALL } ?: MASCOT`, `try/catch Throwable → BubbleStyleSpec()`.
- [ ] **Step 4: Run to verify it passes** — `GRADLE_BUBBLE` → `BubbleStyleSpecTest` 6 PASS in `build/app/test-results/testDebugUnitTest/`.
- [ ] **Step 5: Commit** — `git add android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/bubble/BubbleStyleSpec.kt android/app/src/test/kotlin/com/errorxperts/detoxo/overlay/bubble && git commit -m "feat(bubble): native BubbleStyleSpec for the three-key style"`

---

### Task 10: Kotlin `BubbleModel`

**Files:**
- Create: `…/overlay/bubble/BubbleModel.kt`
- Test: `…/overlay/bubble/BubbleModelTest.kt` (reads `test/fixtures/bubble_cases.json` via `com.errorxperts.detoxo.widget.fixture`)

**Interfaces:**
- Produces `internal object BubbleModel` with `fun tier(count: Int): Int` (= `WidgetPayload.tierOf`), `countText(count: Int): String`, `shortTime(seconds: Int): String`, `clock(seconds: Int): String`, `pct(count: Int): Int`, `toNext(count: Int): Int`, `nextLine(count: Int): String`, `isDial(variant: String): Boolean`, `timerWidth(seconds: Int, variant: String): Float`, `collapsedLabel(count: Int, seconds: Int, variant: String): String`, `openLabel(seconds: Int): String`, `enum class Weather { LEAF, SUN, FIRE }`, `weather(tier: Int): Weather`, `stepsLit(tier: Int): Int`, `bezelLit(count: Int): Int`, `sandTop(pct: Int): Float`, `sandBottom(pct: Int): Float`, `neonGlow(tier: Int): Float`, `outlineBadge(count: Int): String`, `mascotLine(tier: Int): String`, `enum class TierChange { NONE, DOWN, UP }`, `transition(oldTier: Int, newTier: Int): TierChange`.

- [ ] **Step 1: Write the test** — loop the fixture's `cases`: for each `expected` key call the function of the same name and `assertEquals(name/key, expected, actual)` (`weather` compared to `name.lowercase()`, floats with `1e-4f`); fail on an `expected` key with no mapping; loop `transitions`.
- [ ] **Step 2: Run to verify it fails** — `GRADLE_BUBBLE` → compilation error.
- [ ] **Step 3: Implement** — same algorithms as Task 3 Step 4 (Kotlin: `Int` division, `"%02d".format`). Doc: MIRROR CONTRACT with the Dart `BubbleModel`.
- [ ] **Step 4: Run to verify it passes** — `GRADLE_BUBBLE` → `BubbleModelTest` PASS.
- [ ] **Step 5: Commit** — `git add android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/bubble/BubbleModel.kt android/app/src/test/kotlin/com/errorxperts/detoxo/overlay/bubble/BubbleModelTest.kt && git commit -m "feat(bubble): native BubbleModel mirroring the shared fixture"`

---

### Task 11: Kotlin `BubbleEnvelope`

**Files:**
- Create: `…/overlay/bubble/BubbleEnvelope.kt`
- Test: `…/overlay/bubble/BubbleEnvelopeTest.kt`

**Interfaces:**
- Produces `internal data class Outsets(val left: Float, val top: Float, val right: Float, val bottom: Float) { operator fun plus(o: Outsets): Outsets; companion object { val NONE; fun all(v: Float) } }`; `internal data class EnvelopeState(val bodyW: Float, val bodyH: Float, val pulsing: Boolean, val pill: Boolean, val face: Outsets)` (px); `internal data class WindowBox(val x: Int, val y: Int, val w: Int, val h: Int, val bodyLeft: Float, val bodyTop: Float)`; `internal object BubbleEnvelope { fun outsets(s: EnvelopeState, density: Float): Outsets; fun window(anchorX: Int, anchorY: Int, sizePx: Float, dockedRight: Boolean, s: EnvelopeState, density: Float): WindowBox; fun dockedRight(anchorX: Int, sizePx: Float, screenW: Int): Boolean; fun snapX(sizePx: Float, screenW: Int, edgePx: Float, dockedRight: Boolean): Int; fun clampAnchor(x: Int, y: Int, sizePx: Float, screenW: Int, screenH: Int, edgePx: Float): Pair<Int, Int> }` using `BubbleTokens.GLOW (12)`, `PULSE_HALO (24)`, `PILL_GAP + PILL_H + 6 (36)` dp, `MIN_Y_PCT / MAX_Y_PCT`.

- [ ] **Step 1: Write the test** (density 1f, size 68f, screen 400×800):
`collapsed outsets are the glow` (12 all); `pulsing adds the halo` (36 all); `the pill adds its zone on top` (top 48); `face outsets add` (Weather `Outsets(0,4,4,0)` → top 16, right 16); `right dock collapsed` (`window(320,300,…,true, collapsed)` → `WindowBox(308,288,92,92,12f,12f)`); `right dock grows inward` (bodyW 156 → x 220, w 180, bodyLeft 12; the body's right edge `x + bodyLeft + bodyW == 388`); `left dock grows outward` (anchor 12, bodyW 156 → x 0, w 180); `everything at once stays anchored` (right dock, bodyW 156, pulsing, pill → outsets 36 all + 36 more on top; x 196, y 228, w 228, h 176; body right edge still 388, body top still 300); `dockedRight by the anchor centre` (320 → true, 12 → false, 166 → true); `snapX` (right 320, left 12; edge 0 → 332 / 0); `clampAnchor` ((−50, 10) → (12, 160); (390, 790) → (320, 492); (100, 300) unchanged).
- [ ] **Step 2: Run to verify it fails** — `GRADLE_BUBBLE` → compilation error.
- [ ] **Step 3: Implement** — pure arithmetic; `window`: `bodyLeftPx = dockedRight ? anchorX + sizePx − bodyW : anchorX`; `x = round(bodyLeftPx − o.left)`, `y = round(anchorY − o.top)`, `w = round(bodyW + o.left + o.right)`, `h = round(bodyH + o.top + o.bottom)`.
- [ ] **Step 4: Run to verify it passes** — `GRADLE_BUBBLE` → `BubbleEnvelopeTest` PASS.
- [ ] **Step 5: Commit** — `git add android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/bubble/BubbleEnvelope.kt android/app/src/test/kotlin/com/errorxperts/detoxo/overlay/bubble/BubbleEnvelopeTest.kt && git commit -m "feat(bubble): pure window envelope and anchor geometry"`

---

### Task 12: Kotlin `Manrope` extraction and `SvgPath`

**Files:**
- Create: `…/widget/Manrope.kt`, `…/overlay/bubble/SvgPath.kt`
- Modify: `…/widget/WidgetPainter.kt:179,518-540`, `…/widget/ColorMath.kt`
- Test: `…/overlay/bubble/SvgPathTest.kt`

**Interfaces:**
- `internal object Manrope { fun bold(context: Context): Typeface; fun extraBold(context: Context): Typeface }` (the loader + process cache moved out of `WidgetPainter`'s companion; `WidgetPainter` builds its private `Fonts` from it).
- `internal fun blendArgb(a: Int, b: Int, t: Float): Int` in `ColorMath.kt` (alpha-aware; `blend` unchanged).
- `internal object SvgPath { data class Cmd(val op: Char, val args: FloatArray); fun commands(d: String): List<Cmd>; fun path(d: String): Path }` — same grammar as Task 4.

- [ ] **Step 1: Write `SvgPathTest`** — `glued negatives tokenize` (`commands("M1 1 q0 8-8 8z")` → ops `M q z`, `q` args `[0,8,-8,8]`); `the mark parses to 20 commands` (the Task 6 `mark` string → `commands().size == 20`, first `M(9,3)`, last `Z`); `unknown command throws` (`"M0 0 A1 1 0 0 1 2 2"` → `IllegalArgumentException`). (`path()` touches `android.graphics.Path` and is not JVM-tested.)
- [ ] **Step 2: Run to verify it fails** — `GRADLE_BUBBLE` → compilation error.
- [ ] **Step 3: Implement** all three files; `WidgetPainter` compiles against `Manrope`.
- [ ] **Step 4: Run to verify it passes** — `GRADLE_BUBBLE` → `SvgPathTest` PASS; the full `./gradlew -q :app:testDebugUnitTest -x compileFlutterBuildDebug` stays green (widget tests unaffected).
- [ ] **Step 5: Commit** — `git add android/app/src/main/kotlin/com/errorxperts/detoxo/widget android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/bubble/SvgPath.kt android/app/src/test/kotlin/com/errorxperts/detoxo/overlay/bubble/SvgPathTest.kt && git commit -m "refactor(widget): shared Manrope loader; feat(bubble): SvgPath"`

---

### Task 13: Kotlin shell pieces — look, frame, paints, face interface, scaffolds

**Files:**
- Create: `…/overlay/bubble/BubbleLook.kt`, `BubbleFrame.kt`, `BubblePaints.kt`, `BubbleFace.kt`, `faces/*Face.kt` (ten scaffolds)
- Test: `…/overlay/bubble/BubbleLookTest.kt`

**Interfaces:**
- `internal class BubbleLook(val fillFrom: Int, val fillTo: Int, val ring: Int, val ink: Int, val faint: Int, val mark: Int, val neon: Int, val line: Int, val halo: Int, val shadow: Int) { companion object { fun of(tier: Int): BubbleLook; fun blend(a: BubbleLook, b: BubbleLook, t: Float): BubbleLook } }` — same mapping as Task 5 Step 3 using `BubbleTokens` / `WidgetTokens` and `withAlpha(to, 0x2E)` / `withAlpha(to, 0x73)`; `blend` via `blendArgb` per field.
- `internal class BubbleFrame(val body: RectF, val s: Float, val look: BubbleLook, val tier: Int, val prevTier: Int, val blend: Float, val count: Int, val pct: Int, val countText: String, val clock: String, val expand: Float, val pop: Float, val pulse: Float, val pill: Float, val loopT: Float, val open: Boolean, val dockedRight: Boolean) { fun x(bx: Float): Float; fun y(by: Float): Float; fun u(v: Float): Float }`.
- `internal class BubblePaints(context: Context, private val opacity: Float)` with `shell(c: Canvas, f: BubbleFrame, fillFrom: Int? = null, fillTo: Int? = null, radiusOuter: Float = 34f, radiusEdge: Float = 34f, ring: Int? = null, halo: Int? = null, shadow: Int? = null)`, `text(c, s: String, cx: Float, cy: Float, sizePx: Float, color: Int, extraBold: Boolean = true, scale: Float = 1f, letterSpacing: Float = 0f, alpha: Float = 1f, glowPx: Float = 0f, glowColor: Int = 0)`, `mark(c, f, left: Float, top: Float, w: Float, h: Float, fill: Int?, stroke: Int, grainT: Float?, alpha: Float = 1f)`, `path(c, d: String, ox: Float, oy: Float, scale: Float, paint: Paint)`, `circle / arc / roundRect / line(c, …, color, strokePx)`; typefaces from `Manrope`; `fontFeatureSettings = "'tnum'"`; software-layer shadows via `setShadowLayer` or `BlurMaskFilter`.
- `internal interface BubbleFace` exactly as the spec §6.4 plus `val countOffsetY: Float get() = 0f`, `val edgeDp: Float get() = 12f`, `val shellCount: Boolean get() = true`, `fun loops(open: Boolean): Boolean = false`, `val loopPeriodMs: Int get() = 0`, colour hooks `countColor/timerColor/markFill (Int?)/markStroke/pillBackground/pillInk/pillOutline/pulseColor(l: BubbleLook): Int`, and `companion object { fun of(variant: String): BubbleFace }` (exhaustive `when`, `else → MascotFace`). `BubblePaths` constants as Task 6.

- [ ] **Step 1: Write `BubbleLookTest`** — `of(0).ink == BubbleTokens.INK_NAVY`; `of(3).ink == WidgetTokens.WIDGET_INK`; `of(4).ink == WidgetTokens.WIDGET_INK_INVERSE`; `of(2).ring == WidgetTokens.TIER_2_TO`; `of(1).halo == withAlpha(TIER_1_TO, 0x2E)`; `blend(of(1), of(2), 1f)` equals `of(2)` on every field; `blend(…, 0f)` equals `of(1)`.
- [ ] **Step 2: Run to verify it fails** — `GRADLE_BUBBLE` → compilation error.
- [ ] **Step 3: Implement** the five files and the ten `internal object XFace : BubbleFace` scaffolds overriding only the scalars of Task 6's table.
- [ ] **Step 4: Run to verify it passes** — `GRADLE_BUBBLE` → `BubbleLookTest` PASS, everything compiles.
- [ ] **Step 5: Commit** — `git add android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/bubble android/app/src/test/kotlin/com/errorxperts/detoxo/overlay/bubble/BubbleLookTest.kt && git commit -m "feat(bubble): native look, frame, paints, face interface and scaffolds"`

---

### Task 14: Kotlin faces — ten abilities

**Files:**
- Modify: `…/overlay/bubble/faces/*Face.kt`

**Interfaces:** consumes Task 13; each face mirrors its Dart twin (Task 6 table, same board numbers via `f.x/f.y/f.u`). Clips use `canvas.save(); clipPath(...); restore()`. Blurred glows use `BlurMaskFilter` (the view runs on a software layer, Task 15).

- [ ] **Steps 1–10: Mascot, Ring, Liquid, Hourglass, Neon, Steps, Weather, Bezel, Drop, Outline** — one face per step, each followed by `GRADLE_BUBBLE` (compiles; the JVM cannot draw, so correctness is checked on device in Task 15 Step 7).
- [ ] **Step 11: Commit** — `git add android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/bubble/faces && git commit -m "feat(bubble): the ten native faces"`

---

### Task 15: `BubbleView` shell and the window host

**Files:**
- Create: `…/overlay/bubble/BubbleView.kt`
- Modify: `…/overlay/ContentCounterBubble.kt` (host rewrite; delete its old `BubbleStyleSpec` and `BubbleView`), `…/engine/ContentCounter.kt:51` (provider), `…/engine/UsageLadder.kt` (doc comment: bubble no longer uses it)

**Interfaces:**
- `internal class BubbleView(context: Context, val spec: BubbleStyleSpec, dockedRight: Boolean, val reduceMotion: Boolean, private val onEnvelopeChanged: () -> Unit) : View(context)` with `val face: BubbleFace`, `val envelope: EnvelopeState` (px, from the current body width / pulsing / pill / `face.outsets`), `val bodyWidthPx: Float`, `val isOpen: Boolean`, `fun setCount(count: Int, pop: Boolean)`, `fun setWatchSeconds(seconds: Int)`, `fun showPill()`, `fun toggleTimer()`, `fun setRemaining(n: Int?)`, `fun setDockedRight(right: Boolean)`, `fun stopLoops()`. `onMeasure` = body + `BubbleEnvelope.outsets(envelope, density)`; `onDraw` builds a `BubbleFrame` and runs the spec §6.2 order through `BubblePaints` + `face`.
- `ContentCounterBubble(context: Context, private val watchMs: () -> Long)`; public surface unchanged: `show(count)`, `onCounted(count)`, `setRemaining(n)`, `hide()`, `onStyleChanged()`.

- [ ] **Step 1: Implement `BubbleView`**

State: `count, tier, prevLook, look, open, remaining, watchSeconds`. Animators (`ValueAnimator`, durations from `BubbleTokens.MS_*`, 0 ms when `reduceMotion`): `blend` (crossfade; `look = BubbleLook.blend(prevLook, target, v)`), `pop`, `pulse` (toggles `envelope.pulsing` at start/end → `onEnvelopeChanged`), `expand` (`OvershootInterpolator`; drives `bodyWidthPx = lerp(size, BubbleModel.timerWidth(watchSeconds, variant)·density, v)` → `requestLayout()` + `onEnvelopeChanged` per frame), `pill` (in 420 / out 280; a `Handler` reverts after `MS_PILL`; toggles `envelope.pill`). `setCount`: `BubbleModel.transition(tier, newTier)` → `UP`: blend + pulse + `showPill()`; `DOWN`: blend; same tier and `pop` → pop. `toggleTimer`: flips `open`, animates `expand`, hides the pill. One 30 fps `Handler` loop while `face.loops(open)` and attached and not reduced; `stopLoops()` on detach. `contentDescription` = `BubbleModel.collapsedLabel/openLabel` on every state change; `setLayerType(LAYER_TYPE_SOFTWARE, null)`.

- [ ] **Step 2: Rewrite the host**

Anchor: `anchorX/anchorY` (collapsed body top-left px) restored via `BubbleEnvelope.clampAnchor(store.bubbleX, store.bubbleY, …)` (unset `-1` → right dock at 30 % height), `dockedRight = BubbleEnvelope.dockedRight(...)`, `edgePx = face.edgeDp · density`. `relayout()` = `BubbleEnvelope.window(...)` → `lp.x/y/width/height` + `updateViewLayout` (try/caught). `show(count)`: build `BubbleView(context, spec, dockedRight, reduceMotion()) { relayout() }`, `setCount(count, pop = false)`, `setWatchSeconds(watchSeconds())`, `setRemaining(lastRemaining)`, add at `window(...)`, appear spring (scale .6 → 1, alpha, `MS_APPEAR`, `OvershootInterpolator`), `showPill()`. `onCounted(count)`: `setWatchSeconds(...)` then `setCount(count, pop = true)`. Touch: `ACTION_DOWN` scale .9 (90 ms); move past slop → drag (`anchorX/Y` follow the finger, `relayout()`); `ACTION_UP`: not dragging → `view.toggleTimer()` + `syncTicker()`; dragging → `snapToEdge()` (animate `anchorX` to `BubbleEnvelope.snapX(...)` 240 ms, then `setDockedRight`, `savePosition(anchorX, anchorY)`). Ticker: `Runnable` every 1000 ms while `view.isOpen`: `shownSec = max(shownSec + 1, watchSeconds())`, `view.setWatchSeconds(shownSec)`; reset on open; removed on close/hide. `reduceMotion()` = `Settings.Global.getFloat(resolver, ANIMATOR_DURATION_SCALE, 1f) == 0f`. `onStyleChanged()`: rebuild collapsed from the stored anchor (dock side recomputed; `edgePx` may change for Drop → re-snap without animation). `detach()`: `view.stopLoops()`, remove ticker and pill callbacks. Delete `BUBBLE_DP`, `REVEAL_MS`, `GestureDetector`, `launchApp`, the old inner classes. `watchSeconds() = (watchMs() / 1000L).toInt()`.

- [ ] **Step 3: Wire `ContentCounter`** — `private val bubble by lazy { ContentCounterBubble(context) { store.timeTodayMs(dateKey()) + pendingUsageMs } }`. Update `UsageLadder.kt`'s doc (block screen only).

- [ ] **Step 4: Compile and run every native test** — `cd android && JAVA_HOME=… ./gradlew -q :app:testDebugUnitTest -x compileFlutterBuildDebug` → BUILD SUCCESSFUL, all suites PASS.

- [ ] **Step 5: Full Dart gate still green** — `flutter analyze && flutter test` → clean / PASS.

- [ ] **Step 6: Build and install** — `flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 7: Device check (record each as done/failed in the task notes)** — open a reels app: the bubble appears with the pill, pill folds after 3 s; tap → capsule grows inward on a right dock and on a left dock, timer ticks, tap folds back; cross 100 (use the Appearance preview count only for Flutter — on device, watch real reels or temporarily set `cc_today` via `adb shell` prefs) → cross-fade, one pulse, pill; drag → snaps 12 dp from the edge, Drop clings at 0; change the style while shown → rebuilt in place; Developer options → Animator duration scale off → no pop/pulse/loops; arm One Reel → `N left` badge, then back. Check TalkBack reads the BR-11 text.

- [ ] **Step 8: Commit** — `git add android/app/src/main/kotlin/com/errorxperts/detoxo && git commit -m "feat(bubble): BubbleView shell and anchor-based overlay host; single-tap timer"`

---

### Task 16: Docs and the full gate

**Files:**
- Modify: `docs/code_docs/17-content-counter.md` (§1 tree, §5.1), `docs/code_docs/04-native-android-layer.md` (§7), `docs/code_docs/18-platform-channel-contracts.md` (bubble style keys), `docs/code_docs/09-persistence-data-model.md` (`cc_bubble_x/y`, `cc_bubble_style`), `docs/code_docs/14-flutter-package-map.md` (new files), `lib/features/content_counter/content_counter_core/domain/usage_ladder.dart` (doc comment)
- Ask first, then modify: `docs/info_docs/02-feature-walkthroughs.md:563-567`

- [ ] **Step 1: Run `/docs-sync`** for `content_counter` + the overlay; write the §5.1 rewrite from the spec §3/§6 (ten styles, BR mapping, anchor/envelope, single tap, `watchMs` provider, reduce motion), the §7 native note, the wire keys, the persistence semantics, the package map.
- [ ] **Step 2: Ask the user** (AskUserQuestion) before replacing the info_docs Bubble-style paragraph with: the ten styles by name, the pill, tap-for-timer, colour every 100 reels, Size and Opacity.
- [ ] **Step 3: Full gate** — `bash tool/dev.sh precommit` → format, tokens up to date, analyze clean, all Dart and native tests PASS, boundaries OK.
- [ ] **Step 4: Commit** — `git add docs lib/features/content_counter/content_counter_core/domain/usage_ladder.dart && git commit -m "docs(bubble): ten styles, bubble rules and the new overlay host"`
