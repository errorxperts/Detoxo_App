# Block screen: Quotes only, compact, app buttons — design

Date: 2026-10-16 · Branch: `sensitive_protection` · Status: **approved 2026-10-16** (follow-up to
[`2026-10-16-block-screen-quotes-design.md`](2026-10-16-block-screen-quotes-design.md))

## What the user asked for

1. Improve the UI: compact text, smoother motion.
2. Use the app's own buttons on the block screen, in a smaller, compact form.
3. Remove the Classic design and the Background and Theme pickers; only Quotes remains.
4. The block screen's primary colour is the app theme's primary.
5. A simpler, easier Block screen editor.

### Decided with the user (AskUserQuestion, 2026-10-16)
- **Editor: one big preview.** One large live preview of the look the app theme uses, a one-line
  hint that it follows the app theme, *Try it on your phone*, then **one** options panel with three
  switches. The explanation sits behind an ⓘ in the app bar.
- **"Color by usage" is removed.** The wall always uses the theme primary.
- **`docs/info_docs/02` and `04` are edited directly.**

## Design

### The wall follows the app, always
- **Light or dark.** The wall uses the app's theme: Face Down when Detoxo is light, Spotlight
  when it is dark.
  - Native: `wallIsDark(appTheme, systemDark)`. `LIGHT` returns false and `DARK` returns true;
    otherwise (`SYSTEM`, or the app never pushed) it falls back to the device's night mode.
  - The Flutter preview reads `Theme.of(context).brightness`.
- **Accent.** Always `ContentCounterStore.brand(dark)` natively, and
  `brandFor(BackgroundScope.of(context, b), b).primary` in Dart.
- **Removed from the style** (Dart `BlockScreenStyle`, native `BlockScreenStyleSpec`): `theme`,
  `background`, `design`, `accentByUsage`, plus the `BlockScreenDesign` enum and
  `DESIGN_CLASSIC/QUOTES`.
- **Kept:** `enabled`, `showCount`, `showOpens`, `backDelaySec`. Parsing stays tolerant: an old
  persisted map that still holds the removed keys parses fine, and they are ignored. `toWire`
  writes only the four kept keys.
- **Classic is deleted.** Natively that is `WallView`, `buildActions`, the `WallSurface` interface
  (only `QuoteWallView` is left, so the overlay uses it directly), `wallTextTop` and its test,
  `paletteFor`, `WallCopy.chip`, and the `wall_got_it` string if nothing else reads it. In Dart it
  is the Classic body, `_Chip`, the Classic button set, `BlockScreenCopy.chip` and the editor's
  Design, Background and Theme sections.
  - `planLabel` stays in both languages: other features use it.
  - `WidgetBackground` in `counter_style_enums.dart` becomes unused but **stays for now**. That
    file rides in the pending `commit-bubble.sh` commits; delete the enum after they land.
  - The usage ladder (`UsageLadder.kt`, `usage_ladder.dart`, its barrel export and
    `test/usage_ladder_test.dart`) loses its last reader with "Colour by usage". Its files ride in
    the same commits, so delete it after they land too.

### Palette: the canvas grounds
`Palette(ground, ink, muted)` replaces `paletteFor(background, dark, count)`. It lives in
`overlay/BlockScreenPalette.kt`, mirrored by `WallPalette` / `wallPaletteFor` in `widget_palette.dart`.

| | ground | ink | muted |
|---|---|---|---|
| **Face Down** (light) | `#ECEFF4`, the board's | `#12151B` (15.9:1) | `#5A6170` (5.4:1) |
| **Spotlight** (dark) | `blend(accent, #07090E, .07)` | `blend(accent, #FFFFFF, .06)` (≥ 17:1) | `blend(accent, #AEB6C6, .14)` (≥ 7.8:1) |

- **`blend(a, b, t)`** is t·a + (1−t)·b: Kotlin `widget/ColorMath.blend`, Dart
  `Color.lerp(b, a, t)`. The dark ground carries a breath of the accent, as the board's mint-black
  `#0B1510` does.
- **The ground is flat.** No gradient and no stroke on the wall itself. The preview's frame uses
  ink at α .12.
- **`legibleOn(color, ground, ink)`** is new and pure. It blends `color` toward `ink` in 3 % steps
  (at most 40) until it reads at ≥ 4.5:1 on `ground`. It colours the Home icon and the ghost labels
  on the ground, and a chip's label on the chip's own fill (`outlinedFill`: the accent at α .12
  over the ground).
  - On the light wall it darkens Sky `#2F6BFF` (3.9 → 4.6:1), Teal `#0B7E8C` and Rose `#C0367A`
    slightly.
  - On the dark wall it lifts only the never-pushed fallback navy.
- **`legibleFill` and `onColorFor`** stay as they are, for the primary button.

### Compact text (native sp/dp; the preview uses the same numbers)
- **Side padding:** 24. **Top:** 48. **Gap from the bottom group to the buttons:** 12.
- **Header:**
  - Face Down: logo 20 tall, wordmark Manrope ExtraBold 16.
  - Spotlight: logo 22 tall plus its glow, wordmark Manrope Bold 15.
  - Logo-to-wordmark gap: 7.
- **Face Down:**
  - Phone unchanged: 326 block, scales 1 → 0.5, then hides.
  - Title Manrope ExtraBold **24**, tracking −0.02, ≤ 2 lines.
  - Quote serif italic **18**; it shrinks to 13 min, then ellipsizes.
  - Writer Manrope Bold **13**, muted; quote-to-writer gap 6.
  - Group gap 14.
- **Spotlight:**
  - Quote serif **24** (14 min).
  - Writer Manrope Bold **11**, UPPERCASE, tracking 0.1; gap 12.
  - Group gap 16.
  - Light, dots and glow unchanged. The big logo is the accent (`SRC_IN`) at a peak α .157
    (`LIT_LOGO_ALPHA`): with the glow under it, the muted writer and meta keep 4.5:1 for every
    theme primary, with margin (`0x2B` is the edge).
  - On the light wall the header and card-back logo take `legibleOn(accent)`.
- **Bottom group (both):**
  - Sub-line ("{name} can wait…" / "{name} is resting…"): 13 regular, muted.
  - Then the **meta line**: the reason and every stat line joined with `" · "` in one block,
    12 regular, muted, ≤ 3 lines. Late stats (`extraStats`) join it too.
  - Gap 3 between the two.
  - Dart: `BlockScreenCopy.meta`.

### App buttons, compact
These are the app's `LiquidPill` / `SecondaryButton` / `GhostButton` language, drawn natively and
mirrored in the preview.

**Every tappable is a 48 dp tall view** (the app's 48 dp tap floor). Its visual sits inset inside
it, the native counterpart of `AppPressable.minTapTarget`.

| Control | View | Visual | Look |
|---|---|---|---|
| **Open Detoxo** (primary) | flex × 48 | 44 pill (inset 2 top/bottom) | `LiquidPill` |
| **Home** (icon) | 48 × 48 | 44 circle (inset 2) | outlined brand: fill accent α .12, 1 dp ring accent α .45, `ic_wall_home` 20 dp in `legibleOn` |
| **Back to {app}** (ghost) | full × 48 | text only | Manrope Bold 14 in `legibleOn`; pill-masked ripple; keeps `TAG_BACK`, countdown, relabel |
| **Allow for a while** (ghost) | full × 48 | text only | same as Back |
| **Duration chips** | ¼ row × 48 | 36 pill (inset 6) | outlined brand like Home; Manrope Bold 13 in `legibleOn`; 8 dp apart |

**The `LiquidPill` look.**
- Fill: `legibleFill(accent)`, swept top-left → bottom-right from lit (HSL lightness +0.09), to
  the fill at .55, to shade (−0.13).
- Rim: 1 dp, `SweepGradient` `[dim, dim, bounce, dim, dim, key, dim, dim]` at
  `[0, .07, .125, .18, .52, .625, .73, 1]`.
  - key = white α .9, bounce = white α .495.
  - dim = `#2EFFFFFF` on a dark wall, `#33101625` on a light one.
- Inner stroke: 0.8 dp at an inset of 1.2, white α .25 → clear by half height.
- Label: Manrope Bold 15 in `onColorFor(fill)`.
- Shadow: elevation 6 dp; on API 28+ the spot/ambient shadow colour is the fill (the app's
  coloured glow).

**Layout and feedback.**
- **Order, top to bottom:**
  1. Row [Home | 10 dp | Open Detoxo].
  2. 6 dp.
  3. Back (not on app walls).
  4. Allow (when offered), whose chips replace it in place, fading in over 200 ms.
- **Column padding:** 24 at the sides; at the bottom, 20 plus the navigation inset.
- **Press feedback:** every control squishes to 0.96 while pressed, over 90 ms each way
  (`AppPressable`'s values), through a `StateListAnimator`. The ripple is ink α .16.

### Smoother
- **Entrance.**
  - A newly raised wall fades in: root alpha 0 → 1 over 220 ms, decelerating.
  - Its button column rises 16 dp → 0 over 280 ms.
  - An in-place rebuild (a carried quote: a newer payload for the same block, or a style edit)
    does neither, so nothing flashes.
- **Quote fade.** Both designs fade the quote up (10 dp over 1.2 s, ease), and the writer
  follows 0.3 s later. This used to be Spotlight only. A rebuild draws them settled
  (`QuoteWallView(fadeIn = …)`).
- **Reduced motion.** "Remove animations" still holds everything still. `ValueAnimator`s scale
  to 0, and the view's own loop already checks `reduceMotion`.
- **Preview.**
  - The bottom group sits in `AnimatedSize` + `AnimatedSwitcher` (200 ms), so flipping an option
    eases instead of jumping.
  - The editor's stage cross-fades when the app theme flips.

### The Flutter preview
- **Rendered on a fixed board**, scaled with `FittedBox`:
  - The full stage is 360 × 780 (9:19.5).
  - The hub card (`compact`) is 352 × 220 (16:10): header, the quote in 2 lines and the button
    row.
  - Text scaling is off inside the board.
  - So every size above is used as is, with no `* scale` maths.
- **Buttons are the real app widgets.**
  - Open Detoxo is a real `LiquidPill(tint: legibleFill(accent))` holding its label.
  - Home is an outlined circle.
  - Ghost labels are plain text.
  - The preview wraps it all in `IgnorePointer` + `ExcludeFocus`, and keeps
    `Semantics(excludeSemantics)`.
- **The public API is unchanged:** `BlockScreenPreview(style:, payload:, height:, compact:)`. The
  Appearance hub card, in a bubble-swept file, needs no edit.

### The editor (Block screen)
- **App bar:** "Block screen" + `InfoButton`. The ⓘ explains that the quotes are 100 built-in
  ones, a new one each time; that the look follows the app theme (Face Down light, Spotlight
  dark); and that the theme is changed under Appearance.
- **Body:**
  1. A glass stage with a big live preview (360 tall), cross-fading on a theme flip.
  2. A one-line hint: "Face Down · follows your app theme" or "Spotlight · follows your app theme".
  3. *Try it on your phone* (`SecondaryButton`, full width).
  4. `SectionHeader('Options')` over **one** `GlassCard` holding three switch rows, with a
     content-aligned hairline between them (`Divider(color: context.glass.border)`):
     - "Reel count today"
     - "Times opened today", caption "Needs Usage access"
     - "Wait 5 seconds to go back"
- Each row is a private flat row (`IconBadge`, title, optional caption, `AppToggle`) — not
  `AppToggleTile`, which carries its own glass.

### Untouched
- The Appearance hub card (`appearance_screen.dart`), the content-counter barrel,
  `counter_style_enums.dart`, `main.dart`, `CommandHandler.kt` and `OverlayWindows.kt`. Each is
  swept by the pending `commit-bubble.sh`.
- The Quotes data, the Back → feed behaviour, the countdown and relabel, the gesture defence and
  the logo asset (only its colours change, above).

## Tests
- **JVM:**
  - `BlockScreenStyleSpec.fromJson`: the four fields; old keys ignored; malformed input gives the
    defaults.
  - `wallIsDark`: a 2-argument table.
  - `wallPalette` contrast for every theme primary plus the fallback (ink ≥ 7, muted ≥ 4.5).
  - `legibleOn` reaches ≥ 4.5 and leaves an already-legible colour alone.
  - `legibleFill` unchanged.
  - `wallTextTop` cases go with Classic.
- **Dart:**
  - The style round-trip and tolerance of the old keys.
  - The cubit without the removed setters.
  - Copy: the buttons on reel, app and adult walls, and `meta`.
  - Palette contrast mirrored.
  - Preview: light → Face Down, dark → Spotlight, compact holds still, reduce-motion settles,
    the logo is drawn, the primary is a `LiquidPill`.
  - Editor: the three switches drive the cubit; there is no Design, Background or Theme section.
