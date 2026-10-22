# Block Screen (the intervention wall)

Written from shipped source. The block screen is the full-screen native window Detoxo raises at
the moment of a block — instead of the invisible BACK/HOME press plus a 1.5 s toast it used to be.
It shows a motivational quote, names the app and **why** it was blocked, today's reel count, how
often the app was opened today, and the honest ways out. There is one design, **Quotes** (§5b),
in two looks that follow the app's own theme: "Face Down" when Detoxo is light, "Spotlight" when it
is dark. Its buttons are the app's pre-Frozen-Glass skins (the lit `LiquidPill`, the outlined
secondary, the ghost text) drawn natively, in the theme primary. Specs:
[`superpowers/specs/2026-10-16-block-screen-quotes-design.md`](../superpowers/specs/2026-10-16-block-screen-quotes-design.md)
and its follow-up
[`2026-10-16-block-screen-quotes-only-design.md`](../superpowers/specs/2026-10-16-block-screen-quotes-only-design.md)
(Classic, the background / theme pickers and "Colour by usage" removed; compact text; app buttons).
Evolutions EVO-025 (back-button countdown), EVO-026 (the wall survives the engine's
own BACK landing elsewhere) and EVO-027 (the opens-today line from the usage layer) are folded in.

Nothing here is on the detection hot path: the wall is raised **after** a verdict, inside the
existing debounced block regions, and never inside `matches()`.

---

## 1. Contract — an enhancement, never a precondition

- The wall **accompanies** the existing navigation (BACK for reels/websites, HOME for
  whole-app blocks); it never replaces it. With no overlay grant, with the wall switched off, or
  when the window cannot be added, the trigger site falls back to the legacy toast and the user is
  still bounced. A reel block only *wants* a wall in the **Block screen** mode or when forced
  (`WallPolicy`, [03](03-detection-engine.md) §wall rule); other modes bounce with no wall and no
  toast, by design.
- `BlockScreenOverlay.show(...)` returns `false` in every fail case; the trigger site shows the
  toast only then, so the two never stack.
- A `BadTokenException` (overlay grant revoked between the check and the add) ejects to the
  launcher (`goHome`) and tears the window down.
- The wall is always dismissible from an on-screen action; it never imitates system UI; an app
  outside its stays-over set or a system dialog coming to the foreground takes it down (§4).

## 2. Window — `overlay/BlockScreenOverlay.kt`

An `object` (like `ServiceEventBus`), so the accessibility service's four trigger sites and
`CommandHandler`'s preview arm share **one** window and can never stack two. Android members
(`Handler`, `WindowManager`, the usage-query executor) are `by lazy` so the JVM test can load the
class; every public call runs on the main looper (`runOnMain`, the bubble's idiom). Both the
service callbacks and the MethodChannel run there, so no locking.

| | Value |
|---|---|
| Type | `TYPE_APPLICATION_OVERLAY` (API 26+), `TYPE_PHONE` below — shared `overlayType()` in `overlay/OverlayWindows.kt` |
| Flags | `FLAG_NOT_FOCUSABLE \| FLAG_NOT_TOUCH_MODAL \| FLAG_LAYOUT_IN_SCREEN \| FLAG_LAYOUT_NO_LIMITS` = **808** (`overlayFlags()`) |
| Size / gravity | `MATCH_PARENT` × `MATCH_PARENT`, `TOP \| START`, `TRANSLUCENT` |
| Cutout | `LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS` (API 30+), `SHORT_EDGES` (28–29); `setFitInsetsTypes(0)` on 30+ so it draws under the system bars |
| Touch | root `isClickable = true` + `setOnTouchListener { true }` — children (the real buttons) get the touch first, the backdrop swallows the rest |

`show(context, payload, staysOver, preview, raisedOver)` — cheapest check first: a standing,
attached wall for the **same** payload (the opens count aside) returns `true` and only widens its
stays-over set; a standing wall for a **newer** payload (a drained bank, a fresh count) is rebuilt
in place; a detached tracked window is torn down and re-added. Only then is the persisted style
read (`enabled == false` → `false`, unless `WallPolicy.bypassesSwitch(payload,
store.defaultBlockMode)` — a forced block or a reel wall in the Block screen mode; a `preview`
always honours the switch; the grant is never skipped), then the overlay grant: a denied check is memoised for
`OVERLAY_RECHECK_MS = 5000` so a missing grant costs one binder call per 5 s, not one per block;
the once-per-process `Log.w` names the reason. After a successful add the overlay arms the ghost
exit's countdown and kicks off the opens-today query (§5).

### Back-gesture defence — both mechanisms

1. `systemGestureExclusionRects = [Rect(0,0,w,h)]` re-applied on **every layout pass** of the wall
   (first layout, rotation, fold) through an `OnLayoutChangeListener` (API 29+) — the system clamps
   this to a maximum height, which is expected.
2. Two full-height edge **strips** (`TOP|START`, `TOP|END`), flags `NOT_FOCUSABLE | NOT_TOUCH_MODAL`
   (= 40), each swallowing touches. Width from the pure `stripWidthPx(sdkInt, gestureLeftPx,
   gestureRightPx, density)`: API 30+ → `max(left, right) × 1.5` from
   `WindowInsets.Type.systemGestures()`; below → 50 dp. A width of 0 (three-button navigation)
   adds no strips.

The defence is **touch-only** by design: an accessibility service's global BACK, a bottom-edge
gesture on some OEM shells, or a free-form window still routes around it (the `ponytail:` marker
on the object). The upgrade path is a third bottom strip behind a per-OEM flag.

### Actions

The renderer reports a token; the overlay posts `blockScreenAction` (§7) and then:

| Token | Effect |
|---|---|
| `GO_HOME` | `hide()` + `goHome()` (`ACTION_MAIN` + `CATEGORY_HOME` + `NEW_TASK` — works with no Activity and no service). The Home icon (content description "Go home") |
| `OPEN_APP` | `hide()` + `launchDetoxo()` (`getLaunchIntentForPackage` + `NEW_TASK \| SINGLE_TOP`, `overlay/OverlayWindows.kt`) |
| `DISMISS` | `hide()`. On a **REEL** wall the ghost exit is the only `DISMISS` source, so when it still reads "Back to {app}" (not relabelled, not a preview — both read **before** `detach()` clears them) the overlay then calls `DetoxoAccessibilityService.openAppHome(packageName, platformId)`: it taps the platform's `homeTabId` (Instagram's `feed_tab`, §5b) in the app's own window — already on it → nothing, so an open feed is not scrolled to the top — and restarts the app at its root (`Intent.makeRestartActivityTask`) when the tab bar is not on screen (BACK left the user in a DM thread). No `homeTabId`, a protected app, or the service down → the wall just closed. "Dismiss" only closes |
| `UNBLOCK` | **M8**: writes `ConfigStore.pendingUnblock = "TYPE\|id"`, then `hide()` + `launchDetoxo()` — the `OPEN_APP` shape. Dart drains it with `takePendingUnblock` (read-and-clear) and opens the duration sheet. A consumable prefs key rather than the event, because on a cold start the EventChannel sink does not exist when the action is posted. `preview` never writes: the style editor's sample wall must not arm a real unblock ([31](31-locked-rules-and-unblock.md) §5) |

Every exit above is the user's own, and goes through `close()`: a real wall is removed at once,
so the app beneath takes the very next touch; Try it's wall (`preview`) fades out instead
(`fadeOutPreview`, 150 ms — it faded in over 220). Its state clears at once, so a new wall can
rise straight away, and the window turns `FLAG_NOT_TOUCHABLE`, so only the picture lingers over
the editor; the view goes when the fade ends ("Remove animations" ends it at once).

**The ghost exit counts down (EVO-025).** The renderer tags "Back to {app}" with
`BlockScreenRenderer.TAG_BACK`; after the add the overlay disables it, dims it to 55 % and ticks
its label "Back to Instagram · 5 … · 1" once a second (`TICK_MS`) for `BlockScreenStyleSpec.
backDelaySec` seconds (default 5, `0` = instant), then restores label and state. Home and
"Open Detoxo" are never delayed, so the wall cannot trap. The tick is removed in `detach()`.

**The ghost exit relabels (EVO-026)** — and then just closes, with no feed tap. `raisedOver` remembers the package the wall was raised
over. When the service reports the foreground moved *within* the stays-over set to another package
(`onForeground(pkg)`), "Back to Instagram" would promise a return it cannot make, so it becomes
"Dismiss" (`wall_dismiss`) — same `DISMISS` action, the wall just comes down.

## 3. Trigger sites — `accessibility/DetoxoAccessibilityService.kt`

`raiseWall(payload, staysOver, raisedOver)` = `BlockScreenOverlay.show(this, payload.sanitised(),
staysOver, raisedOver = raisedOver)`; the switch bypass is the overlay's own call (§2).
Called before the `ServiceEventBus.post` (the event carries `wall: shown`, EVO-057) and before the
existing navigation, always inside a debounced region (`BLOCK_DEBOUNCE_MS` 1200 for reels and apps,
the per-host web debounce), so `show()` is never hammered per event. Every payload carries
`packageName` (the app under the wall) for the opens-today query.

| Site | Payload | `staysOver` |
|---|---|---|
| `onDetected` (reel surface blocked) | `REEL`, `referenceId = platformId`, `displayName = platformName(pkg, platformId)` (the config's `platformName`, else the app label), `blockReason = PLAN`, `plan = activePlan`, `allowance = store.reelAllowance`, `todayCount = contentCounter.todayCount()` (**-1 when counting is off** — a stale number is never shown), `allowanceLeft` (One Reel / Unblock only), `bankMs` (Conscious only). **Gated by `WallPolicy.reelWall(store.defaultBlockMode, mode, forced)`**: raised only when the user's mode is `BLOCK_SCREEN` or the block is forced (`DAILY_LIMIT`, `SCHEDULE`, or Conscious with the bank at zero); never when the resolved mode is `NONE` — nothing navigates then, and a wall over a still-playing reel would be a trap. Wanted but not shown → `toast_blocked` with the platform name (EVO-056). | `backStaysOver(pkg)` |
| `accountConscious` drain-to-empty (the 1 Hz accountant's own BACK when the bank hits 0) | the same reel payload for the foreground reel platform with `bankMs = 0`; skipped for a protected foreground. A drained bank is forced (EVO-054), so this walls in every mode | `backStaysOver(foregroundPkg)` |
| `onAppBlocked` (whole-app HOME bounce) | `APP`, `referenceId = pkg`, `displayName = appLabel = appLabel(pkg)`, `blockReason = APP_BLOCK` | `appBlockStaysOver(pkg)` = `{pkg, resolved launcher}` — the HOME that follows lands on the launcher, so the wall stays over it until the user acts; `resolveActivity` returning the resolver (`"android"`) falls back to every HOME-capable package |
| `handleBrowser` (website) | `WEBSITE`, `referenceId`/`displayName` = host for a user-rule hit, **`""` for an adult-list hit** (EVO-018), `appLabel` = the browser's label, `blockReason = WEB_RULE \| ADULT` | `backStaysOver(browser pkg)` |

`backStaysOver(pkg)` (EVO-026) = `{pkg}` ∪ `homePkgs` ∪ `{prevForegroundPkg}` — wherever the
engine's BACK can land: the app itself, any launcher (a reel opened from a notification is its
task's root), and the app the reel was opened from (a Short from a WhatsApp link returns to
WhatsApp). `prevForegroundPkg` is tracked in the window-state block (the package in front before
the current one) and never contributes our own package, System UI or the IME.

`BlockScreenPayload.sanitised()` runs on both the native and the channel path: an `ADULT` payload
loses `displayName`, `referenceId` and `offersUnblock`; any non-`PLAN` reason drops `plan` (app and
web rules fire during a live Pause too, when the plan token would lie).

`PlatformRule.platformName` (in `engine/DetectionConfig.kt`) is parsed from the config's
`platformName` so the reel wall can say "Instagram Reels" rather than "Instagram".

## 4. Hide rules

1. **Foreground change** — in `onAccessibilityEvent`'s `TYPE_WINDOW_STATE_CHANGED` block, before the
   privacy guard, cheapest check first: `isShowing() && pkg != packageName && pkg !=
   "com.android.systemui" && pkg !in a11yPkgs && !isImePackage(pkg)` → then `staysOver(pkg)`
   decides: outside the set → `hide()`; inside it → `onForeground(pkg)` (the ghost exit relabels
   once the foreground has left the app the wall was raised over). `a11yPkgs` (the enabled
   accessibility services' packages, refreshed in `reload()`) keeps a TalkBack / Switch Access menu
   from reading as "the user left". The `isShowing()` short-circuit keeps this free while no wall
   is up.
2. **`reload()`** — after a settings push: `!masterOn || now < pausedUntil` → `hide()`. A Pause or
   protection-off lifts every block, so a standing wall goes too.
3. **Screen off** — a `BroadcastReceiver` for `ACTION_SCREEN_OFF` registered on the service in
   `onServiceConnected` (`ContextCompat.registerReceiver(..., RECEIVER_NOT_EXPORTED)`), unregistered
   inside `runCatching` from both `onUnbind` and `onDestroy` (`tearDownOverlays()`), which also
   hides the wall and the nudge. The `MainActivity` receiver cannot do this: it lives with the UI, which is dead exactly
   when the wall is up.
4. **User actions** (§2).

Consequences worth knowing: after a reel block the wall stays until the user picks an exit,
whether the BACK left them in the reel app ("Back to Instagram" returns to the app's other
screens), on the launcher, or in the app the reel was opened from (the ghost exit reads "Dismiss"
there). Leaving by any other route — a notification into a third app — takes the wall down. After
an app block the wall stays over the launcher until Home / "Open Detoxo".

## 5. Renderer — `overlay/BlockScreenRenderer.kt`, `overlay/WallButtons.kt`

`BlockScreenRenderer.build(context, payload, spec, appTheme, quote, animateIn, onAction): View`
returns a `FrameLayout`: the Quotes backdrop `QuoteWallView` (child 0, tagged `TAG_WALL`, §5b) and
the button column on top. The brightness is the pure `wallIsDark(appTheme, isSystemDark)` (§6),
the accent the static spec brand for it (`ContentCounterStore.brand(dark)`, which Dart pushes
once at start as `brandLight` / `brandDark`, [17](17-content-counter.md)), the palette
`wallPalette(dark, accent)`. The backdrop's `reservedBottom` is fed the column's laid-out height,
so the text never draws into the buttons at any font scale; the overlay's `setOpens` reaches the
backdrop as a `QuoteWallView`.

- **Buttons — the app's own, drawn natively** (`WallButtons`, after `buttons.dart`). Every
  control is a real `android.widget.Button` / `ImageButton` (TalkBack gets one focusable target
  each, with a `contentDescription`), **48 dp tall** — the app's tap floor, the native
  `AppPressable.minTapTarget` — with its visual inset inside it, a ripple masked to that visual
  (ink α .16), and `AppPressable`'s press: a per-view `StateListAnimator` scaling to 0.96 over
  90 ms each way.

  | Control | Look |
  |---|---|
  | **Open Detoxo** (`primary`) | `LiquidPill` as a `Drawable`: a 44 dp pill of `legibleFill(accent)` swept top-left → bottom-right from lit (HSL lightness +0.09, `ColorUtils`) through the fill at .55 to shade (−0.13); the `LiquidGlassBorder` rim (a 1 dp `SweepGradient`: key light white α .9 at the top-left, bounce α .495 at the bottom-right, the glass border token elsewhere) and its 0.8 dp inner stroke; label Manrope Bold 15 in `onColorFor(fill)`. Elevation 6 dp on the pill's own outline (`getOutline`); on API 28+ the shadow takes the fill (the app's coloured glow). Nothing above it clips (`clipChildren` / `clipToPadding = false`) |
  | **Home** (`home`) | `SecondaryButton`'s outlined brand as a 44 dp circle: fill accent α .12, a 1 dp ring α .45, `ic_wall_home` at 20 dp; content description "Go home" |
  | **Back to {app}**, **Allow for a while** (`ghost`) | Text only, Manrope Bold 14 |
  | the **5 / 15 / 30 / 60 min** chips (`chip`) | 36 dp outlined brand pills, Manrope Bold 13, 8 dp apart |

  The glyph and the ghost labels take `legibleOn(accent, ground, ink)`: the accent, blended toward
  the ink in 3 % steps until it reads at 4.5:1 on the ground (on the light wall it deepens Sky,
  Teal and Rose a little; on the dark one it lifts only the never-pushed fallback navy). A chip's
  label is made legible on the chip's own fill instead (`outlinedFill`: the accent at α .12 over
  the ground), and a big font scale shrinks all four labels alike so each stays whole
  (`fitChips`: "60 min" needs 82 dp at 2× where a 360 dp phone gives its label 64). Every `RippleDrawable` stacks its layers (`PADDING_MODE_STACK`) — built in code it
  nests them, which would inset Home's and a chip's mask a second time. Order,
  top to bottom: a row **[Home | Open Detoxo]**; 6 dp below it **Back to {app}** (tagged
  `TAG_BACK` for the countdown and relabel, §2; not on an app wall — the app is already
  HOME-bounced); **Allow for a while** — which, since EVO-050, expands **in place** into the chip
  row (it takes the trigger's slot and fades in over 200 ms; TalkBack's focus moves to the first
  chip, and a chip ignores taps for a double-tap timeout, so a double tap on the trigger cannot pick
  a duration) rather than launching Detoxo, so the decision is made on the wall (see [31](31-locked-rules-and-unblock.md) §5). It renders only when
  `offersUnblock`, which since M8 is true at the **non-strict** trigger sites only: an App Blocker
  lock and a non-strict package rule yes, the strict arm no, a reel block `!rule.strict`, and a
  website hit only when `match == RULE && !webEngine.matchesAdult(host)` — a host on **both** the
  user's blocklist and the 18+ set would otherwise get a button that mints a grant the adult walk
  immediately overrules. `ADULT` is already forced false by `sanitised()`
  ([31](31-locked-rules-and-unblock.md) §5). The column pads 24 dp at the sides and 20 dp plus
  the navigation inset at the bottom (`setOnApplyWindowInsetsListener`; the window draws under the
  system bars).
- **Contrast** (pure, pinned by the JVM test): `onColorFor(fill)` is navy or white, whichever
  reads; `legibleFill` darkens the fill toward navy in 3 % steps until that text reaches 4.5:1 —
  of the theme primaries only Sky (`#2F6BFF`, white 4.499:1) needs it; `legibleOn` as above.
  Both hold against the flat fill: the `LiquidPill` sweep lifts the ground under a white label's
  first letters (Sky and Teal read about 4:1 there — above the 3:1 that 15 sp bold needs),
  exactly as on the app's own buttons — a design-system property, not the wall's.
- **Entrance** (`animateIn`, a newly raised wall): the root fades 0 → 1 over 220 ms
  (decelerating) while the column rises 16 dp; the quote fades up (§5b). An in-place rebuild — a
  carried quote (§5b) — passes false, so nothing flashes. "Remove animations" scales both to
  0 ms. `ponytail:` the fade composites the whole wall through one offscreen layer per frame for
  its 220 ms; the upgrade path is fading the window's own alpha.
- **Copy** (`WallCopy`): `headline` reuses `toast_blocked` ("%1$s is blocked by Detoxo") /
  `toast_blocked_adult` — it is not drawn, but leads the wall's spoken description; reasons
  `wall_reason_*` — including `wall_reason_schedule_until` / `wall_reason_daily_limit_until`, used
  when the payload's `unlocksAtMs > 0` so a rule wall reads "Blocked by a schedule · Unlocks at
  5:30 PM" instead of stopping at the reason (EVO-028; the time is rendered with
  `DateFormat.getTimeFormat(context)`, i.e. the device's 12/24-hour setting); stats
  `wall_count_today` (plurals), `wall_bank` (mm:ss), `wall_allowance_left` (plurals),
  `wall_opens_today` (plurals, "Instagram opened 7 times today"); `name` (§5b). All in
  `res/values/strings.xml`. The plan's own label (`planLabel(token, allowance)`, `"CURIOUS"` →
  "Conscious") is no longer on the wall — the reason line names the plan — but stays a pure
  file-level function for the home widgets; the wire token `curious` never reaches a screen,
  asserted natively and in Dart.
- **Palette**: `overlay/BlockScreenPalette.kt` — `Palette(ground, ink, muted)` from the pure
  `wallPalette(dark, accent)`: the canvas boards' flat grounds. Face Down is `#ECEFF4` with ink
  `#12151B` (15.9:1) and muted `#5A6170` (5.4:1); Spotlight is near-black with a breath of the
  accent (`blend(accent, #07090E, .07)`, as the board's mint-black `#0B1510` carries its mint),
  ink `blend(accent, #FFFFFF, .06)` (≥ 17:1) and muted `blend(accent, #AEB6C6, .14)` (≥ 7.8:1) for
  every theme primary. `blend` / `withAlpha` come from `widget/ColorMath.kt`,
  `WidgetBitmapRenderer.isSystemDark` the night-mode fallback.
- Typeface: Manrope Bold / ExtraBold from the Flutter assets (`widget/Manrope.kt`) for the
  wordmark, title, writer and every button; the system sans for the sub-line and meta; the system
  serif for the quote. Sizes via `TypedValue` sp, so the platform font scale applies.
- `ponytail:` content renders on a Canvas, so the wall cannot reuse the Flutter design system —
  `WallButtons` redraws its buttons natively; the upgrade path (a Flutter-rendered wall) costs a
  second engine and is blocked by the single-process invariant.

## 5b. The Quotes design — `overlay/QuoteWall.kt`, `overlay/QuoteBook.kt`

One design, in the look the app's theme gives it, from the claude.ai canvas boards "32 · Face
Down" and "19 · Spotlight". The text is the compact set (sp / dp; the preview uses the same
numbers): 24 at the sides, 48 at the top, 12 above the buttons.

- **Face Down** (a light wall): a centred column — the app logo (20 dp) + wordmark (Manrope
  ExtraBold 16), a 150 × 290 dp phone card that turns face down and back on an 8 s loop (the
  board's keyframes in the pure `flipDegrees(t, ease)`: face up to 30 %, face down by 42 %, held to
  82 %, home by 94 %, eased by `PathInterpolator(.6, 0, .3, 1)` per segment), "Put it face down."
  (`wall_facedown_title`, ExtraBold 24, ≤ 2 lines), the quote in serif italic 18, its writer
  (Bold 13, muted, 6 dp under it), then the foot. Groups are 14 dp apart. The card's front is a
  dark screen with two drifting pink / blue blobs and three feed bars; its back shows a camera bump
  and the app logo. The floor shadow narrows and fades with the pure `turnedAway(degrees)` =
  (1 − cos θ) / 2.
- **Spotlight** (a dark wall): leading-aligned; the logo (22 dp, with a soft accent glow) +
  wordmark (Bold 15); a 16 dp dot grid and a large app logo show only near a soft light, which
  follows the finger and, idle, drifts on the pure `lissajousX` / `lissajousY` (the board's
  x = w/2 + 0.31w·sin 0.8t, y = 0.47h + 0.24h·sin 0.5t), easing back onto the path after a finger
  lifts. The quote is serif 24, its writer Bold 11 UPPERCASE with 0.1 tracking, 12 dp under it;
  groups are 16 dp apart. The line reads "{name} is resting. Move your finger to find the light."
  (`wall_spotlight_line`).
- **The foot** (both): the line ("{name} can wait. Your peace can’t." — `wall_facedown_line` —
  or Spotlight's), 13 regular muted, then **one meta line**: the reason and every stat joined with
  " · " ("Block All is on · 12 reels today · Instagram opened 7 times today"), 12 regular muted,
  ≤ 3 lines, 3 dp below. The stats that land late (`extraStats`, below) join it. The wall's
  spoken description keeps them as separate sentences — a screen reader may say "dot".
- **Entrance**: on a newly raised wall (`fadeIn`) the quote fades up 10 dp over 1.2 s on both
  looks and its writer follows 0.3 s later; the frame loop runs at least until that ends (1.5 s),
  so a Face Down wall whose phone is hidden still finishes it. A rebuild draws them settled.

`{name}` is `WallCopy.name`: the app for reel and app walls, the host for a website, the browser
for an adult hit (never named). The logo is `assets/images/Detoxo_logo.png` (a 1024² RGBA square
with a transparent margin), decoded once per process from the Flutter assets by `DetoxoLogo` and
cropped to `LOGO_CROP` — the visible logo plus a 16 px margin, pinned against the asset by
`QuoteWallTest`; no logo (a missing asset) → none drawn, never a failure. The logo is white: on
the light wall and the card's light back it would vanish, so there it is recoloured
(`PorterDuffColorFilter(SRC_IN)`) to `legibleOn(accent, …)`, as the board's coloured logo is;
Spotlight's header keeps it white. Spotlight's big logo is a `BitmapShader` in the accent
(`SRC_IN`, as the board hue-shifts its logo to the wall's colour) kept only where the light's
falloff has alpha (`ComposeShader(…, DST_IN)`, built fresh each frame: on API 24–25 one built once
would keep the mask's old native shader), at most α .157 (`LIT_LOGO_ALPHA`): the writer and meta
can sit on the glow (`GLOW_ALPHA`, α .14) and the logo at once, and it keeps the muted text at
4.5:1 there for every theme primary, with margin (`0x2B` is the edge; JVM-pinned). Colours otherwise: the palette's ground and text; the accent for the
dots and glow; the phone keeps its own.
`ponytail:` the first wall decodes the 1024² PNG on the main thread (tens of ms) and the ~1.2 MB
crop stays resident; the upgrade path is an io-thread decode at service connect, or a pre-cropped
asset.

**Fit**, measured on a size / reserve / stats change: the phone scales 1 → 0.5 (`phoneScale`),
then hides; then the quote shrinks (Face Down to 13 sp, Spotlight to 14 sp); then it is cut with an
ellipsis; and if a landscape or small wall at a big font scale is still too tall, the Face Down
title goes, then the writer, so the quote never runs into the foot (TalkBack still reads both).

**Smoothness.** StaticLayouts, shaders and paths are built on a size, reserve or stats change —
never per frame. A frame sets a few unit `RadialGradient` local matrices (re-assigned to their
paints: API 24–25 copy the shader at `setShader`), one `android.graphics.Camera` matrix
(location −900 dp / 72 — Camera units are 72-dpi inches), Spotlight's one `ComposeShader` for the
lit logo, and issues draw calls; the dots are a
`drawCircle` loop over the grid points within the light's radius. No `saveLayer`, no clip under
the camera matrix and no blur filter (each costs, or is ignored, on the GPU renderer below
API 28): every soft edge is a gradient. The loop is `postInvalidateOnAnimation()` from `onDraw`
while attached; "Remove animations" (`reduceMotion`, animator duration scale 0) stops it — Face
Down rests face up, Spotlight's light sits at the centre and a finger still moves it (each move
invalidates once). The preview reads Flutter's `disableAnimations`, which Android feeds from the
*transition* scale: "Remove animations" zeroes both, but zeroing only one scale in Developer
options lets one side move while the other holds still. `ponytail:` the loop runs for as long as the wall stands; the upgrade path is
pausing it after a minute without a touch.

**Quotes.** `QuoteBook` reads `flutter_assets/assets/content/motivational_quotes.json` (100
quotes, `{quotes: [{quote, writer, …}]}`) once per process — the `Manrope.kt` pattern — and draws
one per wall at random, never the same twice in a row (pure `parse` / `pick`); a missing or
unreadable file falls back to "Stay focused. The feed can wait." The overlay owns the standing
wall's quote: an in-place rebuild of the same block (a newer payload, `onStyleChanged`) keeps it
(`detach(keepQuote = true)`); every other way the wall comes down clears it. A carried quote is
also how `show()` knows a rebuild from a new wall: only a new one (`carried == null`) is built with
`animateIn` (§5).

### The late stat — "opened N times today" (EVO-027)

The first user-visible consumer of the usage layer ([26](26-catalog-and-usage-signal.md) §2). A
live wall's payload has `opensToday = -1`; after a successful add, when `spec.showOpens` and the
payload names a package and label, the overlay runs `UsageQuery.hasAccess` + `UsageQuery.opensToday
(packageName)` on its lazy single-thread executor (today's `queryEvents` window, foreground
*transitions* only) and posts the lines into `QuoteWallView.extraStats`, which re-lays the text
once and refreshes the backdrop's description. No grant → no line, no error; a query failure is swallowed;
a wall that changed meanwhile ignores the result. The editor's preview payload carries `opensToday`
directly (`WallCopy` renders it) so "Try it" mirrors the Flutter preview.

## 6. Style and the on/off switch

Native is the single source of truth: `ConfigStore.blockScreenStyleJson` (key `block_screen_style`
in `detoxo_engine_prefs`, default `""`), parsed by `BlockScreenStyleSpec.fromJson` — `enabled`
(default **true**), `showCount`, `showOpens` (default true), `backDelaySec` (default **5**, clamped
0–60; 0 = instant); malformed → defaults. A map persisted before 2026-10-16 may still hold
`theme`, `background`, `design` and `accentByUsage`: they are ignored, and the next save drops
them. Read once per new wall in `show()`, never per accessibility event and not for an
already-standing wall.

There is no theme or background choice: the wall **follows the app**. Dart pushes `AppThemeMode`
with the settings (`themeMode`, whitelisted into `ConfigStore.appThemeMode`, key
`app_theme_mode`); the pure `wallIsDark(appTheme, systemDark)` reads LIGHT / DARK from it and falls
back to the device's night mode for "Match system" or a store that was never pushed. The Flutter
preview reads the app theme's brightness. The accent is always the theme primary for that
brightness (`ContentCounterStore.brand(dark)`, §5).

Dart (`lib/features/blocking/block_screen/`):

| Layer | File | Role |
|---|---|---|
| domain | `entities/block_screen_style.dart` | `BlockScreenStyle` (Equatable): `enabled`, `showCount`, `showOpens`, `backDelaySec` (clamped 0–60); `fromWire` tolerant of wrong-typed fields and of the keys an older build wrote (`theme`, `background`, `design`, `accentByUsage` — ignored); `toWire` writes the four |
| domain | `entities/block_screen_payload.dart` | `BlockScreenPayload` (incl. `packageName`, `opensToday`), `BlockReferenceType`, `BlockReason`, `.preview()` (a zero count shows the sample 12). The native payload also carries `unlocksAtMs` (EVO-028) — native-internal, it never crosses the channel |
| domain | `entities/block_screen_copy.dart` | `BlockScreenCopy.from(payload, style)` — the Flutter mirror of `WallCopy` (MIRROR CONTRACT): `headline` (spoken only), `reason`, the stats incl. the opens line, `meta` (the reason and stats joined with " · "), the button set — Home (`BlockScreenButton.icon`), Open Detoxo (`primary`), the ghost "Back to {app}" `locked` with its "· 5" label while the countdown runs (not on an app wall), "Allow for a while" — and `name` / `faceDownTitle` / `faceDownLine` / `spotlightLine` |
| domain | `repositories/block_screen_repository.dart` | `style()`, `setStyle()`, `preview(payload)`, `hide()` |
| data | `repositories/block_screen_repository_impl.dart` | over `EngineChannel`: `blockScreenStyle` / `setBlockScreenStyle` / `showBlockScreen` / `hideBlockScreen` |
| presentation | `block_screen_style_cubit.dart` | app-wide (`main.dart`); emit now, 120 ms debounced push, dirty-guard against a late hydrate (`CounterAppearanceCubit` shape); `setEnabled`, `setShowCount`, `setShowOpens`, `setBackDelay(on:)` (5 / 0), `preview(payload)` for "Try it" (pushes an edit still in the debounce first) |
| presentation | `block_screen_style_screen.dart` | route `Routes.blockScreenStyle` = `/block-screen/style`: an ⓘ `InfoButton` in the app bar (the 100 quotes; the look follows the app theme; change it under Appearance; what off leaves to a toast); a **Show block screen** switch at the top — the hub card's own, in one `GlassCard`, caption "For app & website blocks"; one big live preview (the user's current plan and allowance, selected as two-field records so counter ticks don't rebuild the editor) cross-fading on a theme flip; the hint "Face Down / Spotlight · follows your app theme"; **Try it on your phone** (disabled while off or without the grant, with the `NoticeLine` fix under it); **Options** — one `GlassCard` of three flat switch rows (`_SwitchRow`, hairlines between): Reel count today, Times opened today ("Needs Usage access"), Wait 5 seconds to go back; each row is one `MergeSemantics` node, so TalkBack reads a caption with its own switch; while the block screen is off the options fade and their switches announce as disabled (`_SwitchRow.enabled`) |
| presentation | `widgets/block_screen_preview.dart` | Flutter mirror of the wall, drawn on a fixed board in native dp (360 × 780, or the Appearance card's 352 × 220 `compact` crop: header, the quote in 2 lines, the button row) that a `FittedBox` scales to `height`, text scaling off inside — so every size is the native one; `IgnorePointer` + `ExcludeFocus`, one `Semantics` label. Brightness from the app theme, accent `context.tokens.brand.main` (the static spec brand), palette `wallPaletteFor` + `legibleOn` / `onColorFor` / `legibleFill` from `content_counter_appearance/.../widget_palette.dart`. Open Detoxo is `_WallPill`, a private copy of the native `LiquidPill` drawable (the app's own `LiquidPill` is now the Frozen Glass accent pill; the wall keeps its skin until the native track restyles it); Home an outlined circle; the ghost labels text (a locked one at 55 %). `_Wall` runs one ticker, only on the full stage and never under "Remove animations"; `_PhonePainter` / `_SpotlightPainter` / `_LogoPainter` mirror `QuoteWall.kt` (the idle drift only — a finger would fight the editor's scroll), the canvas's sample quotes (sr 46 / sr 48; the compact Spotlight card takes the short sr 62, which its two lines hold), the foot in the system sans as natively; the foot eases through `AnimatedSize` + `AnimatedSwitcher`. The logo from `ResizeImage(AssetImage('assets/images/Detoxo_logo.png'), width: 512)`, cropped by `_logoCrop` (the native `LOGO_CROP`), recoloured on the light wall, Spotlight's lit through a `saveLayer` + `dstIn` gradient. Switched off (`style.enabled` false) it eases over 300 ms to a 60 % greyscale — through an always-mounted `ColorFiltered`, the identity while on, so a toggle never rebuilds the wall and replays the quote's fade-up — an **Off** `AppBadge` fades in, the label reads "Block screen preview, off.", and the ticker pauses on its frame and resumes from it. Approximations: the quote does not shrink (its `maxLines` is the guard), and Face Down's spare height goes to the phone slot rather than around the quote |

The plan label itself lives with the enum — `planLabel(BlockingPlan?, {allowance})` in
`blocking/shared/domain/entities/enums.dart` — and the dashboard status label and the Unblock
dialog's base label delegate to it, so the wire token maps to "Conscious" in one Dart place.

The **Appearance** hub has a "Block screen" section: one full-width `_SurfaceCard` with the
compact preview, the **on/off `AppToggle`**, an "Off — app & website blocks fall back to a short
toast" hint while off (reel walls follow the block mode, not this switch), and the same
overlay-permission notice the bubble card uses
(`ContentCount.overlayGranted == false`, tri-state — never "unknown reads as denied").
Switched off, the card still opens the editor (the preview itself shows the off state), and both
lines slide in and out — `AppReveal`, with `NoticeLine` for the notice (design system,
`components/feedback.dart`) — rather than pop the card.

**Try it** waits for the switch and the grant: it is disabled while the block screen is off or
`overlayGranted` is a definite `false`, and then a `NoticeLine` under it — *Needs “Display over
other apps” — tap to allow* — opens the grant (`ContentCounterCubit.requestOverlay`). A `false`
from `showBlockScreen` (the grant never read, or no native side) gets a neutral toast.
`preview()` first pushes an edit still inside the 120 ms debounce: native gates the preview on the
*stored* switch, so "on" and then Try it at once would otherwise read the old "off".

The `blocking.dart` barrel exports the block-screen cubit and preview (the `content_counter.dart`
precedent) so the Appearance hub reaches them without a boundary violation; the editor screen is
routed, so `app_router.dart` imports it directly.

### The live accent, natively (ready, not yet wired)

`overlay/AccentResolver.kt` mirrors Dart's `resolveAccent`
(`lib/core/design_system/foundations/accent.dart`): mode (none / Block All / Conscious /
Pause / One Reel), today's share of the daily limit and a live Pause's time left give the
accent palette (main, light, deep) for a theme, from the generated `DxTokens.PALETTE_*`. It
works in Double with one final half-up rounding, not `widget/ColorMath.blend`, so both sides
agree to the bit: `test/fixtures/accent_cases.json` (46 rows, from an independent Python
model) drives `AccentResolverTest.kt` and `test/core/design_system/accent_test.dart`. The wall
still takes the static brand; the block-screen restyle wires the resolver in.

## 7. Channel delta

Commands on `com.errorxperts.detoxo/commands` (contract detail in
[18](18-platform-channel-contracts.md)): `showBlockScreen` (payload map → `Boolean`, raised as a
**preview**), `hideBlockScreen`, `isBlockScreenShowing`, `goHome`, `setBlockScreenStyle`
(`{style: Map}`), `blockScreenStyle` (→ map, `{}` when unset). The preview arm holds the overlay
through the object, so it works with the service dead — unlike `performBack` / `killApp` /
`lockScreen`, which route through the service instance.

`pushSettings` carries `themeMode` (`SYSTEM | LIGHT | DARK`, whitelisted): the wall's brightness
follows it (§6). `setBlockScreenStyle`'s map is the four fields of §6; an older map's extra keys
(`theme`, `background`, `design`, `accentByUsage`) are ignored.

Event `blockScreenAction` — `{action, referenceType, referenceId, preview}`; not sticky.

## 8. Analytics

`FirebaseNativeEventReporter` logs `block_screen_action { action }` for a non-preview event, and
`block_triggered { platform, mode, wall }` — `wall` is 1 when the block screen was actually shown
for that block (EVO-057), since `mode` reports the navigation (`PRESS_BACK` for the Block screen
mode).
`referenceId` (a host or package) is never forwarded — the same rule as `webBlocked`'s host.
No Dart navigation happens on `OPEN_APP`: native foregrounds Detoxo where it was (cold start →
splash → dashboard), so the PIN and permission gates win by construction. `ponytail:` a
deep-link landing on the dashboard is M6's shell work.

## 9. Tests

- JVM (`android/app/src/test/.../overlay/BlockScreenGeometryTest.kt`, in the precommit gate):
  `overlayFlags() == 808`; `stripWidthPx` at both SDK branches; `onColorFor` / `contrastRatio`
  (`primaryButtonTextFollowsItsFill`); the `planLabel` table and the "never contains `curious`"
  sweep; `sanitised()` for adult and app-block payloads; `fromMap` null cases; the style spec —
  defaults (on, count + opens shown, 5 s), every field parsed with the delay clamped, and a map
  saved before 2026-10-16 still parsing with its `theme` / `background` / `design` /
  `accentByUsage` ignored; the two-argument `wallIsDark` table; `wallPalette` for every theme
  primary plus the fallback navy (ink ≥ 7:1, muted ≥ 4.5:1 on both grounds); `legibleOn` reaching
  4.5:1 for every primary on both walls and leaving a legible one alone, and a chip's label
  reaching it on the chip's own fill; the muted text at 4.5:1 under Spotlight's light (ground +
  glow + lit logo) for every dark primary; `legibleFill`.
  `overlay/WallPolicyTest.kt` pins the wall rule: Block screen mode walls and other modes do not,
  a forced block walls in every mode but never over a `NONE` navigation, forced = daily limit /
  schedule / Conscious bank at zero, and the Appearance switch is skipped by forced walls and by a
  reel wall in the chosen mode — never by an app or website wall. `overlay/QuoteWallTest.kt`
  (`flipDegrees` keyframes, `turnedAway`, the Lissajous start and bounds, `phoneScale` 1 → 0.5 →
  hidden, `LOGO_CROP` holds the asset's whole visible logo — decoded with the host JVM's ImageIO),
  `overlay/QuoteBookTest.kt` (the real shipped asset: 100 quotes, none blank, ≤ 220 chars;
  garbage → empty; a pick never repeats the last and can land anywhere first),
  `engine/DetectionConfigTest.kt` (the real config: Instagram's wall surfaces name
  `com.instagram.android:id/feed_tab`, `ig_feed` and YouTube have none, a qualified id is kept
  verbatim), `engine/UsageQueryTest.kt` (`startOfDay` in two zones, `countOpens` transitions only).
  Window lifecycle, the buttons' drawables and the animations need a device; `org.json` parsing
  does not (the real `org.json` is on the unit-test classpath).
- Dart: `test/block_screen_test.dart` — the payload (round-trips, the sample-12 rule, adult
  anonymisation, the plan rule of `sanitised()`), `planLabel`, `BlockScreenCopy` (Conscious never
  "curious", the locked ghost label, the opens line and its toggle, Unblock-5, an app wall keeps
  Home and Open Detoxo with no way back in, an adult wall is unnamed and offers the browser back, a
  website names the host, `showCount`, `meta`), the wall palette (ink / muted / `legibleOn` on both
  grounds for every spec palette main of both themes and the fallback, Face Down's board ground,
  Spotlight's accent breath, `legibleFill` for every main — only Light over-main darkens), `onColorFor`, `BlockScreenStyle` (defaults, a
  round-trip writing its four keys only, old keys ignored, `backDelaySec` clamping and tolerance),
  and that the settings push carries `themeMode`; `test/block_screen_cubit_test.dart` (hydrate,
  debounce, dirty guard, `enabled=false` push, the 5 s / instant back delay, Try it right after the
switch pushes it first — and only once — while nothing pending goes straight to the wall, failed
hydrate);
  `test/block_screen_preview_test.dart` (light → Face Down, dark → Spotlight, Open Detoxo is a
  wall pill full and compact, the logo ships in the bundle and both walls draw it once decoded,
  the stage holds still under "Remove animations" and moves otherwise, a compact card never runs a
  ticker, and the editor's three switches drive the cubit with no Design / Background / Theme
  picker left, each row one TalkBack node with its caption; switched off the preview greys under
  an **Off** badge and stops its loop, and on brings both back; the editor's own switch, Try it and
  the options disabled while off, and a missing grant fixed in place by the `NoticeLine`);
  `test/appearance_block_screen_card_test.dart` (switched off, the hub card says what off means
  and still opens the editor); `native_event_reporter_test.dart` (`blockScreenAction` logged, preview skipped;
  `block_triggered` carries `wall`); `test/block_mode_picker_test.dart` (the four-row picker, the
  selected row reaches Semantics, the entry tile's "Needs Display over other apps" row only without
  the grant); `test/domain_test.dart` (`BLOCK_SCREEN` round-trips).
- Device sanity (not automatable here): wall on an Instagram Reel within the debounce; both edge
  swipes swallowed, also after a rotation; "Back to Instagram · 5" ticks to 0 and unlocks while
  Home stays instant, and the "Wait 5 seconds" option off makes it instant; a reel opened from a
  notification → BACK lands on the launcher → the wall stays and the ghost exit reads "Dismiss"; a
  Short from a WhatsApp link → the wall stays over WhatsApp; "Instagram opened N times today"
  appears within ~1 s, is absent with Usage access revoked, and its option hides it; at font
  scale 1.5× and 2× the text clears the buttons and every label fits its 48 dp control; Home ejects; "Open Detoxo" foregrounds Detoxo with
  the PIN gate intact; screen-off hides; a second block does not stack; an app-block shows Home and Open Detoxo
  over the launcher; a third app foregrounding hides it; the Conscious bank draining mid-reel raises
  it; revoking "Display over other apps" mid-session falls back to toast + BACK with no crash;
  TalkBack reaches every button, reads the late opens line, and its menu does not take the wall
  down; the Appearance switch off restores the toast-only behaviour for app and website blocks;
  a reel block walls only in the **Block screen** mode — and still does with the Appearance switch
  off; a spent daily limit, a schedule and a drained Conscious bank wall in every mode with the
  switch off; Block screen mode with the overlay grant revoked toasts the platform name; toggling
  the Appearance switch while a forced wall stands keeps it up. Quotes: app Light → Face Down,
  app Dark → Spotlight, "Match system" follows the device; the theme primary colours Open Detoxo,
  the Home ring and the labels; Open Detoxo's shadow takes its colour on API 28+ and is not clipped;
  every control squishes on press; a new wall fades in and its buttons rise, an in-place rebuild
  does not flash; the flip and the light hold 60 fps
  (`dumpsys gfxinfo`, also on an API 24–27 device); a finger moves the light; "Remove animations"
  stills both; a new quote per wall, the same one across an in-place rebuild; "Back to Instagram"
  lands on the feed from the Reels tab and a profile, restarts Instagram from a DM thread, and
  reads "Dismiss" (just closes) on the launcher; TalkBack reads the quote; at font scale 2× the
  phone hides before the quote shrinks.

## 10. Play policy notes

See [22-play-release.md](22-play-release.md) §3 and §5: the wall is raised by the accessibility
service at the moment of a block, is always dismissible from an on-screen action (the countdown
delays only the ghost exit, never Home), can be switched off, never imitates system UI or
covers a system dialog or an app outside the one the block came from, its launcher, or the app it
was opened from, captures no input meant for other apps, and is removed on screen-off, Pause,
protection-off and overlay revoke (falling back to the toast + BACK). "Back to {app}" on a reel
wall taps the app's own Home tab (one `ACTION_CLICK` on `homeTabId`, or a restart of the app at
its root) only because the user tapped that button — never otherwise, never in a protected app.

## The late-filled stat lines (EVO-027, EVO-034)

Two figures reach the wall after it is already on screen, because both need a
`UsageStatsManager` query that must not run on the main thread:

- **"Instagram opened 7 times today"** — `UsageQuery.opensToday` (EVO-027).
- **"1h 10m today in Instagram"** — `UsageQuery.timeTodayMs` (EVO-034), rendered
  only at a minute or more, since "0m today" beside a block reads as a bug.

`BlockScreenOverlay.loadOpens` runs **both** on the existing `io` executor in one
pass — behind a single `hasAccess` check, with no grant meaning no lines and no
error — then posts back once, so the wall never repaints twice. `QuoteWallView`
takes them as `extraStats: List<String>` (it was a single `String` before
EVO-034) and joins them onto the meta line after `WallCopy.stats` (§5b).
`sameWall` guards the late post: if the wall moved on while the query was in
flight, the result is dropped.

Kotlin `UsageQuery.formatHm` mirrors Dart `formatHm`
(`lib/core/utils/duration_format.dart`) so the same span never reads two ways
across the process boundary; both truncate seconds rather than rounding up.
Pinned by `UsageQueryTest`.

## Source files

- `android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/BlockScreenOverlay.kt` (`show`, `close` / `fadeOutPreview`, `detach`, the countdown and relabel)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/BlockScreenRenderer.kt` (payload, style spec, `planLabel`, `contrastRatio`, `onColorFor`, `legibleFill`, `legibleOn`, `wallIsDark`, `build`, the button column with `addUnblock` / `fitChips`, `WallCopy`)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/WallButtons.kt` (`WallButtons`: `primary` / `home` / `ghost` / `chip`, the press squish, the stacked `ripple`; `OUTLINED_FILL` / `outlinedFill`; the `LiquidPill` drawable)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/QuoteWall.kt` (`QuoteWallView`, `flipDegrees`, `turnedAway`, `lissajousX` / `lissajousY`, `phoneScale`, `GLOW_ALPHA` / `LIT_LOGO_ALPHA`, `reduceMotion`, `LOGO_CROP`, `DetoxoLogo`), `overlay/QuoteBook.kt` (`Quote`, `QuoteBook`), `res/drawable/ic_wall_home.xml`, `assets/content/motivational_quotes.json`, `assets/images/Detoxo_logo.png`
- `android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/WallPolicy.kt` (`forced`, `reelWall`, `bypassesSwitch`, `MODE_BLOCK_SCREEN`)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/OverlayWindows.kt` (`overlayType` — shared with the bubble and the nudge — and `launchDetoxo`, used only by the wall)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/accessibility/DetoxoAccessibilityService.kt` (`openAppHome`, `tapInApp`, `appRoot`, `raiseWall`, `reelPayload`, `appLabel`, `platformName`, `appBlockStaysOver`, `backStaysOver`, `prevForegroundPkg`, `a11yPkgs`, `screenOffReceiver`, `tearDownOverlays`)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/channels/CommandHandler.kt` (six arms, `jsonToMap`)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/engine/UsageQuery.kt` (`hasAccess`, `opensToday`, `startOfDay`, `countOpens`)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/engine/ConfigStore.kt` (`blockScreenStyleJson`, `appThemeMode`), `engine/ContentCounterStore.kt` (`brand(dark)`)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/engine/DetectionConfig.kt` (`PlatformRule.platformName`, `homeTabId`), `assets/config/platforms_config.json` (`homeTabId` on Instagram's wall surfaces)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/engine/ContentCounter.kt` (`todayCount()`)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/BlockScreenPalette.kt` (`Palette` / `wallPalette`), `widget/ColorMath.kt` (`blend` / `withAlpha`), `widget/WidgetBitmapRenderer.kt` (`isSystemDark`)
- `android/app/src/main/res/values/strings.xml` (`wall_*`)
- `android/app/src/test/kotlin/com/errorxperts/detoxo/overlay/BlockScreenGeometryTest.kt`, `WallPolicyTest.kt`, `QuoteWallTest.kt`, `QuoteBookTest.kt`, `engine/UsageQueryTest.kt`, `engine/DetectionConfigTest.kt`, `widget/Fixtures.kt` (`repoFile`)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/channels/CommandHandler.kt` (`BLOCK_MODES` / `THEME_MODES` whitelists on `pushSettings`)
- `lib/features/blocking/block_screen/**`
- `lib/features/blocking/blocking.dart`
- `lib/features/blocking/shared/domain/entities/enums.dart` (`planLabel`, `BlockingMode.blockScreen`), `engine_event.dart` (`BlockEvent.wall`)
- `lib/features/settings/presentation/widgets/block_mode_picker.dart` (`blockModes`, `BlockModeOptions`, `BlockModeTile`, `OptionTile`, `PermissionNeededRow`) and the `_BlockModeSheet` / `_BlockModeTile` wrappers in `settings_screen.dart`
- `lib/features/limits/daily_limit/presentation/daily_limit_screen.dart` (the overlay-missing banner branch)
- `lib/features/content_counter/content_counter_appearance/presentation/widgets/widget_palette.dart` (`WallPalette` / `wallPaletteFor`, `legibleOn`, `onColorFor`, `legibleFill`), `lib/core/design_system/tokens/app_tokens.g.dart` (the spec palettes)
- `lib/features/additional_feature/appearance/presentation/appearance_screen.dart` (`_BlockScreenSection`)
- `lib/core/design_system/components/buttons.dart` (`SecondaryButton` — one tree for both states, so going disabled fades and keeps its 48 dp floor — and `InfoButton`, which opens its copy in a sheet; the editor uses them), `components/toggle.dart` (`AppToggle`, which fades to disabled too), `components/feedback.dart` (`AppReveal`, `NoticeLine`), `components/badges.dart` (`AppBadge`, the preview's Off), `foundations/liquid_glass_border.dart` (the rim), `foundations/motion.dart` (`AppPressable`'s press)
- `lib/core/constants/channel_constants.dart`, `lib/core/platform_channels/engine_channel.dart`
- `lib/core/services/firebase/analytics/{analytics_events,analytics_service,native_event_reporter}.dart`
- `lib/core/navigation/{routes,app_router}.dart`, `lib/core/di/injector.dart`, `lib/main.dart`
- `lib/features/blocking/shared/data/repositories/engine_repository_impl.dart` (`themeMode` on `pushSettings`), `lib/features/blocking/shared/presentation/settings_cubit.dart` (`setThemeMode`)
- `test/block_screen_test.dart`, `test/block_screen_cubit_test.dart`, `test/block_screen_preview_test.dart`, `test/block_mode_picker_test.dart`, `test/core/services/firebase/native_event_reporter_test.dart`
