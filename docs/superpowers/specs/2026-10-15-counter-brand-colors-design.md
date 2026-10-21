# Counter surfaces on the app's colour system — design

Date: 2026-10-15 · Branch: `sensitive_protection` · Status: **implemented 2026-10-15** (uncommitted)

> **As built, where it departs from this spec.**
> - **§1 ramp.** It targets a fixed *brightness* per tier (`BrandTint.ramp`: `.2126 r² +
>   .7152 g² + .0722 b²`, solved by a 24-step bisection on lightness), not the fixed-lightness
>   table below. At one HSL lightness a mint primary is ~2.4× brighter than an indigo one, so
>   no single lightness table kept the ink readable for every theme. Ink stays per tier (dark
>   on 1–3, white on 4–5); no runtime `inkOn` was needed. The tables live in `BrandTint`; the
>   §5 contrast sweep is `test/counter_ramp_test.dart`.
> - **§3b stage.** The Home widget preview has **no** stage surface: each tile sits on the page
>   (user request). Only the bubble stage is `StageSurface`.
> - Engineering docs 04 / 09 / 17 / 18 and `info_docs/02` are updated; the picker PNGs were
>   re-rendered.

## Goal

The reel bubble and the home-screen widgets stop carrying their own colour system
and take the app's: every tier is drawn from the selected theme's **primary**
(`brandFor(background, brightness).primary`), and every in-app preview shows it.
Today only tier 0 (0 reels) does; tiers 1–5 use a fixed green → lime → amber →
orange → red ramp.

**User decisions (2026-10-15):**

1. Usage still escalates, as a **ramp of shades of the primary** (pale → deep).
2. The widget uses the primary of **its own theme**: Light → the app's light-theme
   primary, Dark → the dark-theme primary, System → the device's mode decides.
3. The bubble picks between the same two primaries by the **device's night mode**,
   at draw time.
4. **Illustrations stay natural:** Bonsai's foliage, blossom, pot and face, and the
   Mascot's eyes, pupil, blush and water drop keep their own colours. Only the
   chrome (tiles, shells, rings, bars, dots, glows, count ink) follows the primary.
5. Both preview **stages** sit on the app's glass surface plus a faint wash of the
   preview's primary, replacing the per-style light/dark board backdrops.

**Deviation on record:** this supersedes the design canvas's tier palette
(Widget Rules DS-01 / DS-02, canvas `6KjTRuFZJd73eNf7YwwpxC`) and the bubble
spec's "colour follows the DS-01 tier" (`2026-10-11-reel-bubble-styles-design.md`,
BR-04/05). Tier *thresholds* (0, 1–99, 100–199, 200–299, 300–399, 400+) and every
other rule on those boards are unchanged.

## 1. Colour source: `BrandTint` grows a tier ramp

`BrandTint` already derives a colour from the primary: the primary's hue, its
saturation capped, at a fixed lightness per role. It exists twice and must stay
bit-identical: Dart `content_counter_core/domain/brand_tint.dart` and Kotlin
`widget/BrandTint.kt`, both pinned by `test/fixtures/brand_tints.json`.

Changes, on both sides:

- `at(brand, lightness, [maxSaturation = 0.75])`: the saturation cap becomes an
  optional parameter, which the dark ramp needs.
- Tier tables, index 0..5:
  - `tileFrom[t]` / `tileTo[t]`: the light-theme tile's 135° gradient stops.
    Tier 0 stays flat at the existing `tileLight` (0.94).
  - `accentDark[t]` (lightness, saturation cap): the dark theme's count, fill and
    glow on the dark surface, calm → vivid.
  - `dotLight[t]`: Bento's status dot and mini ring in the light theme. The dark
    theme uses `accentDark[t]`.
- `inkOn(from, to)`: picks the count/values ink, `widgetInk` (#111111) or
  `widgetInkInverse` (white), whichever has the higher *minimum* WCAG contrast
  over both gradient stops. This replaces the hard-coded "tiers 0–3 dark ink,
  4–5 white". `muted`, `band` and `faint` follow the chosen ink exactly as the
  inverse flag drives them today.

Starting values (lightness; dark: lightness / saturation cap):

| tier | tileFrom | tileTo | accentDark | dotLight |
|---|---|---|---|---|
| 0 | 0.94 | 0.94 | 0.72 / 0.30 | 0.62 |
| 1 | 0.90 | 0.82 | 0.84 / 0.40 | 0.70 |
| 2 | 0.84 | 0.72 | 0.80 / 0.52 | 0.60 |
| 3 | 0.76 | 0.62 | 0.77 / 0.62 | 0.52 |
| 4 | 0.56 | 0.44 | 0.74 / 0.70 | 0.44 |
| 5 | 0.42 | 0.28 | 0.72 / 0.75 | 0.36 |

These are starting points only. The contrast sweep (§5) is the acceptance gate,
and values may move by up to ±0.06 to pass it. Tier 0's dark accent drops from
saturation 0.75 to 0.30 so that 0 reels reads as the calmest step, not the
loudest.

Consumers move from fixed tokens to the ramp:

| Surface | Dart | Kotlin |
|---|---|---|
| Bubble shell, tiers 1–5 (fill from/to, ring, halo, shadow, ink, faint, mark) | `content_counter_bubble/presentation/bubble_look.dart` `_build` | `overlay/bubble/BubbleLook.kt` |
| Tier tiles: Count, Next colour, Time limit, Rhythm | `home_content_counter/presentation/widget_face_painter.dart` `tileLook`, `darkAccent` | `widget/WidgetPainter.kt` `Ink.tier`, `Ink.darkAccent`, `tierFill` |
| Bento dot / mini ring | `bentoLook` | `Ink.bento` |
| Bonsai health bar (foliage unchanged): same colour as Bento's dot (light `dotLight[t]`, dark `accentDark[t]`) | `bonsaiLook` gains a `bar` field; `faces/bonsai_face.dart` line ~85 paints `look.bar` instead of `look.leaf`. `leaf` keeps feeding the tree | `Ink.bonsai` `fill` (line ~149); the foliage `leaf` at ~454 is unchanged |

The bubble cache becomes per brand: today `BubbleLook.of` builds tiers 1–5 once,
statically. It becomes one cached list of six per brand, with the same
last-brand memo the glass look uses now.

**Tokens removed** from `tool/home_widget/tokens.json`, then regenerated with
`dart run tool/home_widget/gen_tokens.dart` (Dart `*_tokens.g.dart`, Kotlin
`WidgetTokens.kt` / `BubbleTokens.kt`): `tier0`, `tier1..5-from/to`,
`dark-accent-0..5`, `bento-dot-0..5-light/dark`, and their list entries.
**Kept:** neutral surfaces, inks, bands, faint/mark, hairlines, sheen, the
`dark-surface` / `dark-empty` tiles, all `bonsai-*` illustration colours, all
`mascot-*`, pill, badge and chip. `glass-*` and `ink-navy` are already superseded
by `BrandTint` and are removed if nothing else reads them.

## 2. Which primary: wire, store, native

- **Wire:** `setCounterStyle` carries `brandLight` and `brandDark` (ARGB ints)
  instead of `brand`.
  - Dart: `EngineChannel.setCounterStyle({…, int? brandLight, int? brandDark})`.
  - `CounterAppearanceRepository.setBrand(int)` becomes
    `setBrands({required int light, required int dark})`.
- **Store:** `ContentCounterStore` replaces `brandArgb` with `brandLight` and
  `brandDark` (keys `cc_brand_light`, `cc_brand_dark`). Each one, unset, falls
  back to the legacy `cc_brand` value, then to `BrandTint.FALLBACK`. There's no
  migration step. `CommandHandler` stores whichever changed, then re-renders as
  it does now (`contentCounter?.onStyleChanged()` plus a `ReelWidgetSync` push).
- **Widget:** `WidgetBitmapRenderer.render` passes
  `if (dark) store.brandDark else store.brandLight`. `dark` is already resolved
  from the widget theme (System → `isSystemDark`).
- **Bubble:** `ContentCounterBubble` resolves the brand from `isSystemDark` when
  it builds the `BubbleView`. `DetoxoAccessibilityService.onConfigurationChanged`
  already reacts to a night-mode flip, and gains
  `contentCounter?.onStyleChanged()` so a visible bubble re-tints.
- **Dart push:** `_BrandSync` (`lib/main.dart`) takes `light` and `dark` from
  `_Router`'s `lightBrand.primary` / `darkBrand.primary` and pushes both when
  either changes, no longer reading `Theme.of(context)`. Its ponytail note (a
  brightness flip with the app closed shows stale) is resolved, so delete it.

## 3. Previews

One helper, in `content_counter_core/presentation/`:

```dart
/// The primary native draws with in [brightness]: the selected background's
/// brand for that brightness.
int counterBrand(BuildContext context, Brightness brightness) =>
    brandFor(BackgroundScope.of(context, brightness), brightness)
        .primary
        .toARGB32();
```

- `WidgetPreview` (`home_content_counter/presentation/widget_preview.dart`)
  takes the brightness it already resolves for its theme (`dark` in
  `_retarget`) and uses `counterBrand(context, dark ? Brightness.dark : Brightness.light)`
  instead of `Theme.of(context).colorScheme.primary`. Flipping the Theme picker
  re-tints the preview live.
- `BubblePreview` (`content_counter_bubble/presentation/bubble_preview.dart`)
  uses `counterBrand(context, MediaQuery.platformBrightnessOf(context))`.

## 3b. Preview stage

`StageSurface` lives in
`content_counter_appearance/presentation/widgets/stage_carousel.dart`, and both
screens use it (`home_widget_screen.dart` already references it):

- **Done 2026-10-15.** It's the design system's
  `GlassContainer(selected: true, enableBlur: false)`, inset `AppSpacing.xxs` each
  side. `selected` blends the theme's primary into the glass fill and lights the
  rim: the "glass + primary wash". There's no blur because the preview animates
  on it.
- Bubble screen: `_StageCard` uses it. The hint ("Tap the bubble for the timer")
  uses `context.glass.onGlassMuted`. `stageGradient` and `lightStage` are gone.
  Covered by `test/bubble_style_screen_test.dart` ("the stage is the theme
  glass").
- Still open, with §3: `GlassContainer` reads `Theme.of(context)`'s primary. Once
  the widget preview follows its own Light/Dark theme, the stage should take the
  same `counterBrand` value, through a local `Theme` override around
  `StageSurface`, not a new parameter.

## 4. Out of scope

- The block screen's `USAGE_TINT` background (`UsageLadder.color`, `BlockScreenPalette`).
- The widget's Theme picker, sizes and families.
- Copy: "Next colour" and "N reels to the next colour" still hold, since the tile
  changes shade.
- The app's own `AppColors.limitTone` usage gauges.

## 5. Testing

- **Mirror fixture:** `test/fixtures/brand_tints.json` gains the tier roles and
  `inkOn` cases. Dart `test/brand_tint_test.dart` and Kotlin `BrandTintTest`
  both run it, and the outputs must be identical.
- **Contrast sweep** (new, Dart, `test/counter_ramp_contrast_test.dart`): for
  every `brandFor` primary (12 backgrounds × their brightness, plus
  `BrandTint.fallback`), check tiers 0–5 in both themes:
  - light: `inkOn` ink ≥ 4.5:1 against both gradient stops;
  - dark: `accentDark[t]` ≥ 4.5:1 on `darkSurface` (`darkEmpty` at tier 0);
  - distinct steps: adjacent tiers differ by ≥ 0.06 lightness (light) or
    ≥ 0.06 lightness-or-saturation (dark).
- **Updated assertions:** `brand_tint_test.dart` (the "brand at 0 reels only"
  group becomes "brand at every tier"), Kotlin `WidgetGeometryTest`
  (`DARK_ACCENT_*`, `BENTO_DOT_*`), and the `setBrands` fake in
  `test/home_widget_screen_test.dart`.
- **Wire:** a `CommandHandler` / `ContentCounterStore` unit test covers
  `brandLight`/`brandDark` storage and the legacy `cc_brand` fallback.
- **Gate:** `flutter analyze`, `flutter test`, `bash tool/check_boundaries.sh`,
  and `./gradlew :app:testDebugUnitTest -x compileFlutterBuildDebug`.
- **Device:**
  - the bubble at 0 / 150 / 450 reels with two different backgrounds, plus a
    night-mode flip while it's visible;
  - each widget family in Light and Dark, with different dark and light
    backgrounds picked;
  - preview vs pinned widget compared side by side.

## Docs

- `docs/code_docs/17-content-counter.md`, via `/docs-sync`.
- The user-facing `docs/info_docs/` section on bubble and widget colours: ask
  before editing.
