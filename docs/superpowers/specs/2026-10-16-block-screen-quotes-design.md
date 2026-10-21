# Block screen: the Quotes design (Face Down / Spotlight) — design

Date: 2026-10-16 · Branch: `sensitive_protection` · Status: **implemented 2026-10-16** (uncommitted; device checks pending)

> **Revised the same day** by
> [`2026-10-16-block-screen-quotes-only-design.md`](2026-10-16-block-screen-quotes-only-design.md):
> Classic, the Background / Theme pickers and "Colour by usage" are gone (so decision 1's
> Classic, decision 4 and decision 5's Theme option no longer apply — the wall always follows
> the app's theme), the text is compact, and the buttons are the app's own. Where the two
> disagree, the follow-up wins.

> **As built, where it departs from this spec.**
> - **Motion landed with the static wall.** Tasks 6, 8 and 9 shipped as one `overlay/QuoteWall.kt`
>   (Face Down's flip and Spotlight's light are in the same view); the pure helpers are pinned by
>   `QuoteWallTest`.
> - **`reduceMotion` was not lifted** into `overlay/OverlayWindows.kt`: it lives in `QuoteWall.kt`,
>   and the bubble keeps its private copy. Both bubble files are swept into the pending
>   `commit-bubble.sh` commits, so lifting would have mixed this work into them.
> - **The mark is the app logo** (`assets/images/Detoxo_logo.png`, asked for on 2026-10-16), not
>   the hourglass path: decoded once natively and cropped to its visible mark (`LOGO_CROP`, pinned
>   against the asset by `QuoteWallTest`); Spotlight lights it with a `ComposeShader` (the bitmap ×
>   the light's falloff), the preview with a `saveLayer` + `dstIn`. It is recoloured since the
>   Quotes-only revision: `legibleOn(accent)` on the light wall, the accent under Spotlight's light. The content-counter barrel exports nothing new.
> - **FlutterGen was not regenerated**: no Dart code reads `motivational_quotes.json`; the next
>   `build_runner` run adds its getter.
> - Engineering docs 02 / 04 / 05 / 09 / 14 / 17 / 18 / 22 / 25 and `info_docs/02` + `04` are updated.

Source boards: claude.ai canvas `Rfi9ApPDGVJye8Vd1mCijH` ("Detoxo Block Overlay — Organized":
`32-FaceDown.dc.html`, `19-Spotlight.dc.html`). Quotes: `assets/content/motivational_quotes.json`.

## Context

The block screen ("the wall") is a native overlay drawn by the AccessibilityService
(`overlay/BlockScreenRenderer.kt`) and mirrored in Flutter by `BlockScreenPreview`. The user
wants the two designs from the claude.ai canvas `Rfi9ApPDGVJye8Vd1mCijH` (the attached
`Detoxo Block Overlay — Organized.html` is an export of the same two boards):
- **32 · Face Down** (light)
- **19 · Spotlight — move your finger** (dark)

Each design shows a motivational quote from the attached `motivational_quotes.json`: 100
quotes with `sr_no, quote, writer, category`; the longest is 216 chars, the median 67.

The user also asked for:
- light/dark picked automatically from the **app's** theme
- background and theme switchable in the Block Screen settings
- smooth animation
- three exits: **Home** (icon), **Open Detoxo**, and **Back to Instagram**, which lands on
  Instagram's home feed after a reel-only block
- the overlay's primary colour = the app's selected theme colour

### Decisions (agreed with the user)
1. **One design per theme.** New design **Quotes** alongside the current one, now called
   **Classic** (still the default). A wall resolved to light renders Face Down; dark renders
   Spotlight.
2. **App fonts only.** Manrope Bold/ExtraBold (`widget/Manrope.kt`) for the wordmark, title
   and buttons; the system serif for quotes (italic in Face Down). No new font files.
3. **Back to Instagram.** On a REEL wall, the service taps Instagram's own Home tab
   (`:id/feed_tab`).
   - If the tab bar isn't on screen (e.g. BACK left the user in a DM), it reopens Instagram at
     its root.
   - Apps with no configured tab keep today's behaviour: the wall just closes.
   - Preview walls never navigate.
4. **Both designs** get the theme-primary accent and the Back→home behaviour.
5. The Theme option "System" is relabelled **Auto** and follows the app's theme
   (`AppThemeMode`) instead of the phone's night mode. Today native reads night mode while the
   preview reads the app theme, so this also fixes a real mismatch (the app defaults to Dark).
6. info_docs may be edited directly (approved 2026-10-16).

**User-visible changes to existing behaviour:**
- Classic's teal accent becomes the theme primary ("Colour by usage" still overrides it).
- Classic's "Back to Instagram" lands on the feed.
- "System" reads "Auto" and follows the app's theme.

## Design (canvas → app; the board is 390×844)

**Face Down (light)**
- Layout: centred column. Header: the Detoxo mark + "Detoxo" (Manrope ExtraBold).
- Phone card (150×290 dp) flips on Y over an 8 s loop, using `cubic-bezier(.6,0,.3,1)` per
  segment, with perspective 900 dp:
  - 0–30 % front 0°; 42–82 % back 180°; 94–100 % 360°.
- Card faces:
  - **Front:** r30, `#1C1F26`, 4 dp `#2A2E37` border. Two soft blobs (pink `#FF5C8A`,
    blue `#5C8AFF`, α .8) drift (10, −14) dp over 4 s; the second is offset −2 s. Three
    translucent feed bars.
  - **Back:** `#F7F8FA`, a 1 dp `#D5DAE3` border, a 42×42 r12 camera bump, and the mark in the
    theme primary.
- Floor-shadow ellipse: f = (1 − cos θ) / 2, scale 1 − .15f, α .35 − .13f.
- Text, in order:
  - Title "Put it face down." (wraps to 2 lines if needed).
  - Quote: serif italic, 22 sp. Writer: Bold 16 sp, muted.
  - Sub-line "{Name} can wait. Your peace can’t.", then the block reason, then the stat lines
    (all muted).

**Spotlight (dark)**
- Layout: left-aligned.
- Light: dots (1.2 dp, 16 dp pitch, accent α .55) and a large glowing mark appear only near a
  soft radial light (R ≈ 170 dp), plus a glow (r220, accent α .14).
- The light follows the finger. Idle, it drifts on `x = w/2 + 0.31w·sin(0.8t)`,
  `y = 0.47h + 0.24h·sin(0.5t)`, and eases back onto that path after the finger lifts.
- Text: quote in serif 30 sp, fading up 10 dp over 1.2 s; writer in UPPERCASE 13 sp, tracking
  .08, 0.3 s later. Sub-line: "{Name} is resting. Move your finger to find the light.", then
  reason and stats.

**Shared rules**
- **Colours:** the ground is the selected background's `paletteFor` gradient. The accent (dots,
  glow, mark, Open Detoxo fill) is the theme primary. The phone illustration keeps its own
  colours (illustrations stay natural, per the 2026-10-15 brand decision).
- **Name:** `appLabel` for REEL and APP walls ("Instagram can wait…"). For website walls, the
  host. Adult walls use the browser label and never the host.
- **Buttons, top to bottom:**
  1. Row **[⌂ Home, 56 dp icon | Open Detoxo, primary]**.
  2. **Back to {app}**: ghost, keeps the EVO-025 countdown and the EVO-026 "Dismiss" relabel.
  3. **Allow for a while** plus its chips, when offered (M8 / EVO-050).
  - App walls drop only the Back button.
- **Fit on short screens / large fonts,** in this order: phone scale 1 → 0.5, then hide the
  phone, then shrink the quote 22 → 14 sp, then cap max lines with an ellipsis.
- **Reduced motion:** no loop, no fade, no easing. Face Down rests on its front; Spotlight's
  light sits at the centre, and the finger still moves it.

## Approach

### 1. `design` field
- **Dart:** `enum BlockScreenDesign { classic('CLASSIC'), quotes('QUOTES') }` in
  `block_screen_style.dart`, wire key `design`. Unknown values fall back to classic; add it to
  `copyWith`, `toWire` and `props`. The cubit gets `setDesign`.
- **Native:** `BlockScreenStyleSpec.design = "CLASSIC"` in `fromJson`. `setBlockScreenStyle`
  already stores the whole map (`CommandHandler.kt:427`), so the handler needs no change.

### 2. Auto follows the app theme
- **Dart:** `EngineRepositoryImpl.pushSettings` gains `'themeMode': settings.themeMode.wire`.
  `SettingsCubit._commit` already pushes on every change. Fix the stale `setThemeMode` comment
  ("the engine ignores the field").
- **Native:** the `pushSettings` arm whitelists `SYSTEM|LIGHT|DARK` into
  `ConfigStore.appThemeMode` (key `app_theme_mode`, default `""`).
- **Resolution:** a pure `wallIsDark(theme, appTheme, systemDark)` replaces the inline `when`
  at `BlockScreenRenderer.build`. LIGHT and DARK are forced; otherwise it uses `appTheme`,
  falling back to night mode. `build` gains an `appTheme` parameter, which the overlay passes
  from `store.appThemeMode`.
- **Editor:** "System" is relabelled "Auto".

### 3. Accent = the theme primary, legible
- **Native accent:** `UsageLadder.color(count)` when "Colour by usage" is on, otherwise
  `ContentCounterStore(ctx).brand(dark)`.
- **Dart accent:** `brandFor(BackgroundScope.of(context, b), b).primary`, with no new export.
- **`legibleFill(fill)`:** new, pure, sits next to `onColorFor` (Kotlin) and is mirrored in
  `widget_palette.dart`. It darkens the fill in small steps (blending toward navy) until the
  better text colour reaches 4.5:1. Apply it to the primary-button fill only.
  - Only light1 `#2F6BFF` needs it (white 4.499:1 → `#2E69FA` 4.65:1).
- **Delete** `Palette.label` / `WidgetPalette.label`: this accent was their only reader.

### 4. Native Quotes wall: new `overlay/QuoteWall.kt`
- **`QuoteWallView`:** one Canvas View drawing the gradient, art, header, title, quote,
  writer, sub-line, `WallCopy.reason` and stats.
  - `interface WallSurface { var reservedBottom: Int; var extraStats: List<String> }` is
    implemented by `WallView` and `QuoteWallView`. `build()` keeps one path, and the overlay's
    `setOpens` casts to the interface instead of `WallView`.
- **Performance** (the "smooth" requirement):
  - StaticLayouts and auto-fit are rebuilt only on size, `reservedBottom` or `extraStats`
    changes, never in `onDraw`.
  - Shaders are allocated once. Blobs and shadow are placed with `canvas.translate/scale` and
    faded with `paint.alpha`.
  - The frame loop is `postInvalidateOnAnimation()` while attached and visible, and stops in
    `onDetachedFromWindow`.
  - Lift the bubble's private `reduceMotion()` into `overlay/OverlayWindows.kt`. Under reduced
    motion, `ACTION_MOVE` invalidates the view itself.
- **Face Down flip:** `android.graphics.Camera.rotateY` with
  `setLocation(0, 0, -900·density/72)`, applied about the card centre; the back face is
  mirrored with `scale(-1,1)`. Use no `clipPath` under the camera matrix (it renders jagged on
  API < 28). Blobs, glow and shadow are unit `RadialGradient`s plus transforms; avoid
  `BlurMaskFilter` (unsupported on API < 28 under hardware rendering).
- **Spotlight light, without `saveLayer`:** one `RadialGradient` (accent → transparent at R)
  colours both the dots and the mark.
  - The dots are a `drawCircle` loop over only the grid points within R.
  - The mark path is transformed into screen space once per size change.
  - Each frame: `shader.setLocalMatrix(m)`, then re-assign `paint.shader` (needed on API
    24–25). The glow is drawn via `canvas.translate`.
  - Finger input is handled in `onTouchEvent` (true on DOWN). The buttons sit above the view,
    so they still get their taps.
- **Mark:** `BubblePaths.MARK` via the existing `SvgPath`.
- **Pure helpers** (file-level; no Android objects in top-level vals, so they stay
  JVM-testable):
  - `flipDegrees(t, ease)`, with `PathInterpolator(.6f,0f,.3f,1f)` passed in.
  - `lissajous(t, w, h)`.
  - `phoneScale(available)`.
- **Renderer:** `build()` branches on `spec.design`. The buttons reuse `button()`; pull out its
  background for the Home `ImageButton`, which gets the new `res/drawable/ic_wall_home.xml`
  with content description `wall_go_home`. The ghost exit keeps `TAG_BACK`.

### 5. Quotes data: new `overlay/QuoteBook.kt`
- Copy the JSON to `assets/content/motivational_quotes.json`. The folder is already declared;
  run `bash tool/dev.sh assets` to keep `assets.gen.dart` in step.
- Lazy-load from `flutter_assets/assets/content/motivational_quotes.json`, the `Manrope.kt`
  pattern.
- `parse(json)` and `pick(size, last, random)` are pure; pick never repeats `last`. There is a
  fallback quote.
- Pick only when `design == QUOTES`.
- The overlay owns the wall's quote via `detach(keepQuote = false)`:
  - `true` comes only from `onStyleChanged` and from `show()`'s rebuild branch for the same
    `referenceId`.
  - Every other path clears it, so the next wall gets a new quote.

### 6. Back to {app} → the app's home feed
- **Config:** `PlatformRule.homeTabId` (`String? = null`) is parsed like `pagerViewId`
  (`:id/x` → `<pkg>:id/x`). In `assets/config/platforms_config.json`, set
  `"homeTabId": ":id/feed_tab"` on `ig_reel`, `ig_reel_by_friend` and `ig_stories`.
  - Not on `ig_feed`, which is itself blockable.
  - Not on the Instapro mods, which use different ids.
- **Overlay, `onAction(DISMISS)`:** the ghost exit is the only DISMISS source on a REEL wall,
  so no new action token is needed.
  - Before `detach()`, compute
    `home = !preview && p.referenceType == REEL && backLabel != getString(wall_dismiss)`.
  - After `detach()`, if `home`, call
    `DetoxoAccessibilityService.instance?.openAppHome(p.packageName, p.referenceId)` (same
    precedent as `refreshTemporaryUnblocks`).
- **`openAppHome`**, step by step:
  1. Stop if `isProtected(pkg)`, or if the platform has no `homeTabId`.
  2. Find the node in an application window whose root package matches. Otherwise use
     `rootInActiveWindow` with a package check (with TalkBack on, the overlay can still be the
     active window).
  3. If the tab is already selected, do nothing, so an open feed isn't scrolled to the top.
  4. Otherwise click the node or its nearest clickable ancestor.
  5. If it isn't found or the click fails, `startActivity(makeRestartActivityTask(launch.component))`.
  6. Release nodes with `recycleSafe()`.
- **Accepted edge case:** a user who blocks `ig_feed` gets a second wall. That wall's Back
  just closes, so there is no loop.

### 7. Flutter mirror and editor
- **Preview:** `BlockScreenPreview` branches on design into a private `_QuotesPreview`.
  - It is static when `compact` (no ticker: the editor and hub hold six previews). Otherwise
    one `AnimationController` drives it, unless `MediaQuery.disableAnimationsOf`.
  - Face Down uses `Transform` with a perspective `rotateY` and `Cubic(.6,0,.3,1)`.
  - Spotlight uses a `CustomPainter` with the idle drift only; there is no pointer listener,
    because the editor is a ListView. The Try-it wall has the finger.
  - Sample quotes are constants from the JSON: sr 46 (Dalai Lama) and sr 48 (Hermann Hesse).
  - Export `show BubblePaths, BubbleBrush` from the `content_counter.dart` barrel.
- **`BlockScreenCopy`:** Quotes buttons (`BlockScreenButton.icon`) in the top-to-bottom order
  above, plus the title and sub-lines. It mirrors native exactly.
- **Editor:** `SectionHeader('Design')` + `VariantCarousel` (Classic / Quotes), placed above
  Background. Theme reads Auto / Light / Dark. The Appearance hub card picks up Quotes
  automatically.

### 8. Strings
- Native `res/values/strings.xml`: `wall_facedown_title`, `wall_facedown_line` ("%1$s can
  wait. Your peace can’t."; U+2019, since a bare `'` fails the resource compile),
  `wall_spotlight_line`. Mirror them verbatim in Dart.
