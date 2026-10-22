# Block Screen (the intervention wall)

Written from shipped source. The block screen is the full-screen native window Detoxo raises at
the moment of a block — instead of the invisible BACK/HOME press plus a 1.5 s toast it used to be.
It shows a motivational quote, names the app and **why** it was blocked, today's reel count, how
often the app was opened today, and the honest ways out. There is one design (§5b): one
**Frozen Glass** layout for both themes — the app's own light or dark tokens, generated into
`overlay/DxTokens.kt` — painted in the **live accent** the Today screen shows at that moment
(`AccentResolver.forWall`, §6), with the app's button language drawn natively (a glass Home
circle, the accent "Open Detoxo" pill, calm text exits) and the app's **wait + slide** for "Allow
for a while". Nothing loops: the entrance plays once and the wall holds still. Specs:
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
| `UNBLOCK` | **EVO-050**: nothing is written and the wall stays up — the renderer reveals the durations and the slide in place (§5); the token is still posted so analytics counts the intent apart from the choice |
| `UNBLOCK_<m>` | The confirmed slide, with the picked chip's minutes. `onUnblockPicked` writes the grant natively (`ConfigStore.appendGrant`, which also records the row for Dart's `takeNativeGrants`), refreshes the service's temporary unblocks and takes the wall down — no app switch, no PIN, no launch. If that write fails it falls back to M8's hand-off (`setPendingUnblock` + `launchDetoxo()`; Dart drains it with `takePendingUnblock`) rather than drop the tap. `preview` never writes: the style editor's sample wall must not arm a real unblock ([31](31-locked-rules-and-unblock.md) §5) |

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

## 5. Renderer — `overlay/BlockScreenRenderer.kt`, `overlay/WallButtons.kt`, `overlay/SlideToConfirmView.kt`

`BlockScreenRenderer.build(context, payload, spec, appTheme, quote, animateIn, onAction): View`
returns a `FrameLayout`: the backdrop `QuoteWallView` (child 0, tagged `TAG_WALL`, §5b) and the
button column on top. The brightness is the pure `wallIsDark(appTheme, isSystemDark)` (§6), the
tokens `DxTheme(dark)` ([§ the kit](#the-native-frozen-glass-kit--overlayfrozenglasskt)), the
accent `AccentResolver.forWall(context, dark)[0]` — computed once per build, so a standing wall
does not glide, and an in-place rebuild picks up a change — and the hero icon
`heroIconFor(blockReason, plan, allowance)`. The accent paints only three things: the ambient
light, the Open Detoxo pill and a mode icon's hue. The backdrop's `reservedBottom` is fed the
column's laid-out height and its `topInset` the status bar, so the text clears both at any font
scale; the overlay's `setOpens` reaches the backdrop as a `QuoteWallView`.

- **Buttons — the app's own, drawn natively** (`WallButtons`, after `buttons.dart`). Every
  control is a real `android.widget.Button` / `ImageButton` (TalkBack gets one focusable target
  each, with a `contentDescription`), **48 dp tall** — the app's tap floor — with its visual inset
  inside it, and `AppPressable`'s press: a per-view `StateListAnimator` over 400 ms on
  `PathInterpolator(.34, 1.56, .64, 1)`, glass growing to 1.06 and the rest pressing to .975. No
  ripple. Under "Remove animations" (`reduceMotion`) no press animator is installed at all.

  | Control | Look |
  |---|---|
  | **Open Detoxo** (`primary`) | the spec accent pill (`.dx-pill`, the app's `LiquidPill`) as a `DxDrawable`, 44 dp inside the flexible 48 dp slot: base `accent @ k-pill` (.14 / .30), the `pill-hi → pill-lo` sheen, `pill-edge` hairlines and the glow `0 10 24 accent @ k-pill-glow` pre-rendered; label Manrope Bold 15 (`label`) in ink, padding 16 / 20. Nothing above it clips (`clipChildren` / `clipToPadding = false`) |
  | **Home** (`home`) | a 44 dp glass circle (`GlassIconButton`): `glass-top → glass-bottom` and `shadow-glass` as a `DxDrawable`, `ic_wall_home` at 20 dp in ink; content description "Go home" |
  | **Back to {app}**, **Allow for a while** (`text`) | text only, Manrope Bold 15 in ink-2 (`SecondaryButton`); the countdown keeps its α .55 + disabled (§2) |
  | the **5 / 15 / 30 / 60 min** chips (`chip`) | 36 dp pills in 48 dp slots, 8 dp apart: `fill-quiet` + ink-2, or once picked (`select`) the solid `option-base` + a 16 dp `ic_dx_check` + ink; `isSelected` reaches TalkBack |

  Order, top to bottom: a row **[Home | Open Detoxo]**; 6 dp below it **Back to {app}** (tagged
  `TAG_BACK` for the countdown and relabel, §2; not on an app wall — the app is already
  HOME-bounced); **Allow for a while**. The column pads 20 dp at the sides (the gutter) and 20 dp
  plus the navigation inset at the bottom (`setOnApplyWindowInsetsListener`; the window draws
  under the system bars).
- **Allow for a while = the app's wait + slide** (user decision, 2026-10-21). Since EVO-050 the
  tap expands **in place** rather than launching Detoxo, so the decision is made on the wall (see
  [31](31-locked-rules-and-unblock.md) §5): the chip row takes the trigger's slot with **5 min
  picked**, and 12 dp below it the `SlideToConfirmView`, both fading in over 200 ms; the slide's
  5 s wait starts then. TalkBack's focus moves to the picked chip; a chip ignores taps for a
  double-tap timeout (it only changes the pick now, but the pick must be the user's); a big font
  scale shrinks all four labels alike, the check included (`fitChips`: "60 min" needs 82 dp at 2×
  where a 360 dp phone gives its label 64). The slide mirrors the app's `ConfirmSheet`:

  | Part | Spec |
  |---|---|
  | Track | 64 dp, radius 32: `track-from → track-to` + `track-shadow` (blurred insets, pre-rendered); label padding 66 / 18, `button` 16/20 ExtraBold, scaled down to fit |
  | Wait (5 s) | the knob (56 dp at 4, 4) in `DxTheme.waitKnob` — Light the knob at 55 %, Dark the track mixed 18 % toward the knob (`ConfirmSheet.waitKnob`) — shows the seconds in ink-2; the track reads "Take a breath…" (`wall_breath`). `postDelayed` ticks against `SystemClock.uptimeMillis()`, never an Animator, so "Remove animations" still waits 5 s |
  | Ready | the white knob with a white .5 → 0 sheen over its top 60 %, a zero-blur inset (0, −2) black 5 % and an outer (0, 8) blur 18 `tone-caution-b` @ 35 %; `ic_dx_chevrons_right` 24 in `tone-caution-knob`; "Slide to unblock"; one nudge 0 → 10 → 0 over 600 ms (skipped under "Remove animations") |
  | Drag | travel = width − 64. The caution fill (`a → b @ .55 → c`) runs to the knob's far edge; the label is painted twice, ink-2 clipped to the bare track and `tone-caution-ink` clipped to the fill. At ≥ 88 % (`slideConfirms`) "Release to confirm" + a `CLOCK_TICK` haptic. A drag on the knob calls `requestDisallowInterceptTouchEvent(true)` |
  | Release < 88 % | springs back over 400 ms on the press curve (the system scales it to nothing under "Remove animations") |
  | Release ≥ 88 % | the knob runs to the end with `ic_dx_check` and "Confirmed"; `CONFIRM` haptic (API 30+, `VIRTUAL_KEY` below); after **1000 ms** it posts `UNBLOCK_<picked>` into the unchanged `onUnblockPicked` (§2) |
  | Tap | "Slide all the way →" for 1.5 s |
  | Accessibility | reported as `android.widget.Button`; during the wait disabled, described "Slide to unblock, available in N seconds" (`wall_slide_wait` plurals) and refreshed each tick, with no live region; after it enabled, and `performClick` (TalkBack's double tap, Switch Access) confirms |

  There is no "Keep it blocked" button and no wait ring: Home, Back and Open Detoxo are the ways
  out, and the knob's seconds show the wait. "Allow for a while" renders only when
  `offersUnblock`, which since M8 is true at the **non-strict** trigger sites only: an App Blocker
  lock and a non-strict package rule yes, the strict arm no, a reel block `!rule.strict`, and a
  website hit only when `match == RULE && !webEngine.matchesAdult(host)` — a host on **both** the
  user's blocklist and the 18+ set would otherwise get a slide that mints a grant the adult walk
  immediately overrules. `ADULT` is already forced false by `sanitised()`
  ([31](31-locked-rules-and-unblock.md) §5).
- **Contrast** (pure, pinned by the JVM test for both themes and every accent the wall can take —
  each palette main and the resolver's warm steps): ink on both ground ends; ink and ink-2 on the
  panel over the ground under the ambient at 84 dp; ink on the pill composite at its hi and lo
  ends; ink-2 on a chip's fill-quiet; ink on the picked chip's option base; ink-2 on the track
  ends and the countdown on the waiting knob; the tone ink on the caution stops; and the glyphs
  (Home on glass, the chevrons on the knob) at 3:1.
- **Entrance** (`animateIn`, a newly raised wall): the root fades 0 → 1 over 220 ms
  (decelerating) while the column rises 16 dp; the quote fades up (§5b). An in-place rebuild — a
  carried quote (§5b) — passes false, so nothing flashes. "Remove animations" scales both to
  0 ms. `ponytail:` the fade composites the whole wall through one offscreen layer per frame for
  its 220 ms; the upgrade path is fading the window's own alpha.
- **Copy** (`WallCopy`): `headline` reuses `toast_blocked` ("%1$s is blocked by Detoxo") /
  `toast_blocked_adult` — it is not drawn, but leads the wall's spoken description; reasons
  `wall_reason_*` ("Locked in your App Blocker", "On your Web Blocker list") — including
  `wall_reason_schedule_until` / `wall_reason_daily_limit_until`, used when the payload's
  `unlocksAtMs > 0` so a rule wall reads "Blocked by a schedule · Unlocks at 5:30 PM" instead of
  stopping at the reason (EVO-028; the time is the pure `clockLabel(hour, minute,
  DateFormat.is24HourFormat)`: the device's 12/24-hour setting, a zero minute dropped on a 12-hour
  clock as Dart's `formatLocalTime` does); stats `wall_count_today` (plurals), `wall_bank`
  (mm:ss), `wall_allowance_left` (plurals), `wall_opens_today` (plurals, "Instagram opened 7 times
  today"); `name` (§5b). All in `res/values/strings.xml`, mirrored by Dart `BlockScreenCopy`. The
  plan's own label (`planLabel(token, allowance)`, `"CURIOUS"` → "Conscious") is not on the wall —
  the reason line names the plan — but stays a pure file-level function for the home widgets; the
  wire token `curious` never reaches a screen, asserted natively and in Dart.
- Typeface: Manrope from the Flutter assets (`widget/Manrope.kt`) for everything — ExtraBold for
  title-xl, title, headline and button; Bold for label and the eyebrow; SemiBold for body and
  subhead — with tabular figures (`'tnum'`). Sizes via `TypedValue` sp, so the platform font scale
  applies. No serif, no system sans.
- `ponytail:` content renders on a Canvas, so the wall cannot reuse the Flutter design system —
  the kit redraws its surfaces natively from the same generated tokens; the upgrade path (a
  Flutter-rendered wall) costs a second engine and is blocked by the single-process invariant.

## 5b. The design — `overlay/QuoteWall.kt`, `overlay/QuoteBook.kt`

One Frozen Glass layout for both themes; only the token values change. Units dp / sp, at the
20 dp gutter, top down:

| # | Element | Recipe |
|---|---|---|
| 0 | Ground | `bg-top → bg-bottom`, a vertical `LinearGradient` built on a size change |
| 1 | Ambient light | the accent at `k-amb` (.16 / .30), radial, linear falloff to clear at **120 dp**, centred on the well, drawn only with the well; static |
| 2 | Header | from `max(54, status bar + 8)`: `detoxo-logo.webp` at 23 × 44 with its `logo-glow` (Dark σ 8 in brand light-blue; Light σ 1 + σ 10 at y + 4 — `DxArt` masks, never a recolour of the logo), 10 dp, then "Detoxo" in `title-xl` 34/40 ExtraBold, ink |
| 3 | Icon well | 24 below the header: an 88 circle, `RadialGradient` at (35 %, 30 %) with radius .955 × 88 (CSS farthest corner), `well-from → well-to`, no accent ring; the reason's 3D icon at 58 (`heroIconFor`: a plan block its mode — Block All / Conscious / One Reel, or Pause for an N-reel unblock — App Blocker, Web Blocker for a website or an adult hit, Blocker rules for a schedule or the daily limit). A mode icon is hue-rotated to the accent (`accentIconMatrix`: CSS `hue-rotate(hue(main) − 214°) saturate(1.15)`); the others keep their colour |
| 4 | Quote panel | 24 below the well: a frosted panel (`panel-top → panel-bottom` + `shadow-card`, radius 28, padding 16) as a `DxDrawable`; the quote in `title` 22/28 ExtraBold, ink, start-aligned; the writer 12 below as the `eyebrow` (12/16 Bold, uppercase, 1.6 tracking, ink-2) |
| 5 | Line | 16 below the panel: "{name} can wait. Your peace can’t." (`wall_line`), `body` 14/20 SemiBold, ink-2, ≤ 2 lines |
| 6 | Meta | 6 below: the reason and every stat joined with " · " ("Block All is on · 12 reels today · Instagram opened 7 times today"), `subhead` 13/18 SemiBold, ink-2, ≤ 3 lines. The stats that land late (`extraStats`) join it; the spoken description keeps them as separate sentences |

Line heights are the style's own (`StaticLayout` line spacing = line height − `fontSpacing`).
**Why the ambient's radius is 120:** the nearest ink-2 text (the panel's) is 44 + 24 + 16 = 84 dp
from its centre, where the light is at most .30 × (1 − 84/120) = .09, which keeps ink-2 on the
panel at 4.5:1 for every accent (`ambientAlphaAt`, pinned by the JVM sweep).

**Fit**, measured on a size, inset, reserve or stats change by the pure `wallFit(room, …)`, in
order: drop the well (and the ambient with it); the quote from `title` to `headline` 17/22;
ellipsise the quote; drop the writer; drop the header — so text never runs into the buttons in
landscape or at 2× (TalkBack still reads all of it).

**Entrance**: on a newly raised wall (`fadeIn`) the quote fades up 10 dp over 1.2 s on
`PathInterpolator(.25, .1, .25, 1)` and its writer follows 0.3 s later. The frame loop is
`postInvalidateOnAnimation()` only while that runs (t < 1.5 s); a rebuild draws them settled, and
"Remove animations" (`reduceMotion`) draws them settled at once. Nothing else moves: the Face Down
phone, the Spotlight light and every loop of the 2026-10-16 design are gone.

**Smoothness.** StaticLayouts, shaders and the panel's drawable are built on a size, inset,
reserve or stats change — never per frame; a frame is draw calls. No `saveLayer`, no blur on the
hardware canvas: the panel's shadow is a half-scale software bitmap (`DxDrawable`, released when
the view detaches) and the logo's glow `extractAlpha` masks. No backdrop blur either — behind the
panel is our own gradient, where a blur is invisible (`ponytail:` add `RenderEffect` on API 31+ if
imagery ever sits behind it).

`{name}` is `WallCopy.name`: the app for reel and app walls, the host for a website, the browser
for an adult hit (never named). The art (`DxArt`) is decoded once per process from
`flutter_assets/assets/images/icons/`; a missing file draws nothing and never fails.

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
0–60; 0 = instant); malformed → defaults. **New installs start with `showOpens` off**: the
onboarding hand-off writes `BlockScreenStyleCubit.setShowOpens(show: false)` before
`setOnboarded` ([13](13-onboarding-permissions.md)); the entity and native defaults stay `true`,
so an upgraded install, which never walks onboarding again, keeps its stored choice, and a Reset
app data run comes back through the hand-off like a fresh install. A map persisted before 2026-10-16 may still hold
`theme`, `background`, `design` and `accentByUsage`: they are ignored, and the next save drops
them. Read once per new wall in `show()`, never per accessibility event and not for an
already-standing wall.

There is no theme or background choice: the wall **follows the app**. Dart pushes `AppThemeMode`
with the settings (`themeMode`, whitelisted into `ConfigStore.appThemeMode`, key
`app_theme_mode`); the pure `wallIsDark(appTheme, systemDark)` reads LIGHT / DARK from it and falls
back to the device's night mode for "Match system" or a store that was never pushed. The Flutter
preview reads the app theme's brightness. The accent is the live one the Today screen shows
(`AccentResolver.forWall`, below); the preview takes `context.accent`, from the same inputs.

Dart (`lib/features/blocking/block_screen/`):

| Layer | File | Role |
|---|---|---|
| domain | `entities/block_screen_style.dart` | `BlockScreenStyle` (Equatable): `enabled`, `showCount`, `showOpens`, `backDelaySec` (clamped 0–60); `fromWire` tolerant of wrong-typed fields and of the keys an older build wrote (`theme`, `background`, `design`, `accentByUsage` — ignored); `toWire` writes the four |
| domain | `entities/block_screen_payload.dart` | `BlockScreenPayload` (incl. `packageName`, `opensToday`), `BlockReferenceType`, `BlockReason`, `.preview()` (a zero count shows the sample 12). The native payload also carries `unlocksAtMs` (EVO-028) — native-internal, it never crosses the channel |
| domain | `entities/block_screen_copy.dart` | `BlockScreenCopy.from(payload, style)` — the Flutter mirror of `WallCopy` (MIRROR CONTRACT): `headline` (spoken only), `reason`, the stats incl. the opens line, `meta` (the reason and stats joined with " · "), the button set — Home (`BlockScreenButton.icon`), Open Detoxo (`primary`), the ghost "Back to {app}" `locked` with its "· 5" label while the countdown runs (not on an app wall), "Allow for a while" — and `name` / `line` |
| domain | `repositories/block_screen_repository.dart` | `style()`, `setStyle()`, `preview(payload)`, `hide()` |
| data | `repositories/block_screen_repository_impl.dart` | over `EngineChannel`: `blockScreenStyle` / `setBlockScreenStyle` / `showBlockScreen` / `hideBlockScreen` |
| presentation | `block_screen_style_cubit.dart` | app-wide (`main.dart`); emit now, 120 ms debounced push, dirty-guard against a late hydrate (`CounterAppearanceCubit` shape); `setEnabled`, `setShowCount`, `setShowOpens`, `setBackDelay(on:)` (5 / 0), `preview(payload)` for "Try it" (pushes an edit still in the debounce first) |
| presentation | `block_screen_style_screen.dart` | route `Routes.blockScreenStyle` = `/block-screen/style`: an ⓘ `InfoButton` in the app bar ("Shows a quote when something is blocked. It follows your app theme. Off, app and website blocks show a short message instead."); a **Show block screen** switch at the top — the hub card's own, on one `PanelGroup`, caption "For app & website blocks"; one big live preview (the user's current plan and allowance, selected as two-field records so counter ticks don't rebuild the editor) on a quiet `fill-quiet` stage, cross-fading on a theme flip; the hint "Follows your app theme"; **Try it on your phone** (disabled while off or without the grant, with the `NoticeLine` fix under it); **Options** — a `SectionHeader` over one `PanelGroup` of three flat switch rows (`_SwitchRow`, in the `GlassListTile` metrics: 56 min height, an ink-2 glyph, `label` title, `subhead` caption): Reel count today, Times opened today ("Needs Usage access"), Wait 5 seconds to go back; each row is one `MergeSemantics` node, so TalkBack reads a caption with its own switch; while the block screen is off the options fade and their switches announce as disabled (`_SwitchRow.enabled`) |
| presentation | `widgets/block_screen_preview.dart` | Flutter mirror of the wall (public API frozen: `style`, `payload`, `height`, `compact`), drawn on a fixed board in native dp (360 × 780, or the Appearance card's 352 × 220 `compact` crop: the header, a two-line quote at `headline` size on the panel, the button row) that a `FittedBox` scales to `height`, text scaling off inside — so every size is the native one; `IgnorePointer` + `ExcludeFocus`, one `Semantics` label. The same layout as §5b on DS widgets and the generated `AppTokens`: the `bg-top → bg-bottom` ground; the ambient `RadialGradient(accent.main @ kAmb)` of radius 120 on the well; `DetoxoLogo(height: 44)` + "Detoxo" in `AppTypography.titleXl`; the 88 well (`well-from → well-to` at (−.3, −.4), radius .955) with `Icon3d(58, accentTint:)` for a mode icon — the private `_heroIcon` mirrors Kotlin's `heroIconFor`, with the same table in both tests; the quote on a `GlassContainer` panel (radius 28) in `AppTypography.title` (`maxLines` is the guard) with its writer as the uppercase `eyebrow`; the line (`body`) and meta (`subhead`) in ink-2; `GlassIconButton(Icons.home_rounded)`, `LiquidPill(tint: context.accent.main)` "Open Detoxo" and the text exits in `label` ink-2 (a locked one at 55 %). The accent is `context.accent`, the live one. The entrance plays once on the full stage — the quote fades up 10 dp over 1.2 s and the writer 0.3 s later, through `context.motion` (nothing under Reduce Motion) — and then nothing moves: no ticker, so `pumpAndSettle` returns. Switched off (`style.enabled` false) it eases over 300 ms to a 60 % greyscale — through an always-mounted `ColorFiltered`, the identity while on, so a toggle never rebuilds the wall and replays the fade-up — an **Off** `AppBadge` fades in, and the label reads "Block screen preview, off." |

The plan label itself lives with the enum — `planLabel(BlockingPlan?, {allowance})` in
`blocking/shared/domain/entities/enums.dart` — and the dashboard status label and the Unblock
dialog's base label delegate to it, so the wire token maps to "Conscious" in one Dart place.

The **Appearance** hub has a "Block screen" section: a `SectionHeader` over one `PanelGroup`
holding a flat `_SurfaceTile` — the title row with the **on/off `AppToggle`**, the compact
preview, and a status `Pill` (dot + word, no amber line) in place of the old hint and
`NoticeLine`: **Off · toast instead** while off (app & website blocks fall back to a short toast;
reel walls follow the block mode, not this switch), **Needs access** — a 48 dp button that opens
the grant — when on without the overlay permission (`ContentCount.overlayGranted == false`,
tri-state — never "unknown reads as denied"; the same status the bubble tile uses), else **On**.
Switched off, the tile still opens the editor (the preview itself shows the off state); the status
is always one 48 dp line, so a change cross-fades the word in place rather than move the tile.

**Try it** waits for the switch and the grant: it is disabled while the block screen is off or
`overlayGranted` is a definite `false`, and then a `NoticeLine` under it — *Needs “Display over
other apps” — tap to allow* — opens the grant (`ContentCounterCubit.requestOverlay`). A `false`
from `showBlockScreen` (the grant never read, or no native side) gets a neutral toast.
`preview()` first pushes an edit still inside the 120 ms debounce: native gates the preview on the
*stored* switch, so "on" and then Try it at once would otherwise read the old "off".

The `blocking.dart` barrel exports the block-screen cubit and preview (the `content_counter.dart`
precedent) so the Appearance hub reaches them without a boundary violation; the editor screen is
routed, so `app_router.dart` imports it directly.

### The live accent, natively

`overlay/AccentResolver.kt` mirrors Dart's `resolveAccent`
(`lib/core/design_system/foundations/accent.dart`): mode (none / Block All / Conscious /
Pause / One Reel), today's share of the daily limit and a live Pause's time left give the
accent palette (main, light, deep) for a theme, from the generated `DxTokens.PALETTE_*`. It
works in Double with one final half-up rounding, not `widget/ColorMath.blend`, so both sides
agree to the bit: `test/fixtures/accent_cases.json` (46 rows, from an independent Python
model) drives `AccentResolverTest.kt` and `test/core/design_system/accent_test.dart`.

`AccentResolver.forWall(ctx, dark)` reads the inputs from a bare Context, so a preview works
with the service dead:
- the mode: `modeOf(ReelWidgetSync.plan(ctx), now)` — none while blocking is off, a live Pause
  (`pauseUntil > now`), `BLOCK_ALL` → Block All, `CURIOUS` → Conscious, `ONE_REEL` → One Reel for
  an allowance of 1 and Pause above it, `PAUSED` → Pause, an unknown token → none. This is Dart's
  `accentModeOf` row for row; the fixture's `modes` rows drive both `AccentResolverTest` and
  `test/app/live_accent_test.dart` (a token Dart cannot hold is native only);
- the share used: `usedFraction(ContentCounterStore.enabled, timeTodayMs(DateKeys.today(now)),
  limit)` in whole seconds, as the Today ring divides `inSeconds`, where the limit is the
  `RuleEngine.DAILY_REEL_LIMIT_ID` entry of `reelLimits()` (never `soonestReelLimitMs`, which
  counts rule windows too);
- a live Pause's time left (`pauseUntil − now`); none for an N-reel unblock.

`payload.plan` is never read: `sanitised()` blanks it for every non-plan block.

### The native Frozen Glass kit — `overlay/FrozenGlass.kt`

The wall and the soft nudge draw from the generated `DxTokens` through one file:
- **Pure helpers** (file-level, no Android types, so the JVM test loads them): `cssLine` (the CSS
  gradient line, as Dart's), `blurRadius` (a CSS blur is a Gaussian sigma of blur / 2, and
  HWUI's radius is `(sigma − 0.5) / 0.57735`), `hueOf` and `hueRotateSaturate` /
  `accentIconMatrix` (the CSS Filter Effects `hue-rotate · saturate` matrix, hand-built — never
  `ColorMatrix.setRotate`), `clockLabel` (12-hour "11 PM" / "7:30 AM", 24-hour "23:00"),
  `heroIconFor` (the block reason's 3D icon), `ambientAlphaAt`, `slideConfirms` (≥ 88 %),
  `waitSecondsLeft`, `alphaOver`, `contrastRatio`, and `DxTheme(dark)`, the tokens of one theme
  under the Dart field names, with `waitKnob` mirroring `ConfirmSheet.waitKnob`.
- **`DxDrawable`** — one surface (`fill`, `angleDeg`, `base`, `radiusPx`, `shadows`, `inset`):
  the fill shader, zero-blur inset layers as exact `Path.op` hairlines, and every blurred layer
  drawn once into a half-scale software bitmap (`BlurMaskFilter` is ignored on the hardware
  canvas below API 28). All built in `onBoundsChange`; the bitmaps go when the drawable is
  hidden. No backdrop blur at any API level.
- **`DxArt`** — the 3D icons and `detoxo-logo.webp` from `flutter_assets/assets/images/icons/`,
  decoded once per process (null-safe), and the logo's `logo-glow` per theme as
  `extractAlpha` masks drawn in the layer colour (never a recolour of the logo).

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
  `overlayFlags() == 808`; `stripWidthPx` at both SDK branches; the `planLabel` table and the "never contains `curious`"
  sweep; `sanitised()` for adult and app-block payloads; `fromMap` null cases; the style spec —
  defaults (on, count + opens shown, 5 s), every field parsed with the delay clamped, and a map
  saved before 2026-10-16 still parsing with its `theme` / `background` / `design` /
  `accentByUsage` ignored; the two-argument `wallIsDark` table; and the contrast sweep (§5) over
  both themes × every accent the wall can take (each palette main, and `AccentResolver.resolve` at
  used 0 / .6 / .85 / 1 for no mode, Block All and a Pause in its last second) — every text pair
  at 4.5:1, the glyphs at 3:1.
  `overlay/WallPolicyTest.kt` pins the wall rule: Block screen mode walls and other modes do not,
  a forced block walls in every mode but never over a `NONE` navigation, forced = daily limit /
  schedule / Conscious bank at zero, and the Appearance switch is skipped by forced walls and by a
  reel wall in the chosen mode — never by an app or website wall.
  `overlay/FrozenGlassTest.kt` (`cssLine` at 180° / 90° / 145°, `blurRadius`, `hueOf`, the identity
  matrix, the dark Pause matrix turning the 214° blue icon warm, `clockLabel`, `heroIconFor` and every
  icon shipping as RIFF/WEBP, `wallFit` shedding the well, the size, lines, the writer and the
  header in that order, the 88 % threshold and `waitSecondsLeft`, `ambientAlphaAt`, `alphaOver`,
  the waiting knob), `overlay/AccentResolverTest.kt` (every `cases` row, every `modes` row, an ended
  Pause, `usedFraction`),
  `overlay/QuoteBookTest.kt` (the real shipped asset: 100 quotes, none blank, ≤ 220 chars;
  garbage → empty; a pick never repeats the last and can land anywhere first),
  `engine/DetectionConfigTest.kt` (the real config: Instagram's wall surfaces name
  `com.instagram.android:id/feed_tab`, `ig_feed` and YouTube have none, a qualified id is kept
  verbatim), `engine/UsageQueryTest.kt` (`startOfDay` in two zones, `countOpens` transitions only).
  Window lifecycle, the buttons' drawables and the animations need a device; `org.json` parsing
  does not (the real `org.json` is on the unit-test classpath).
- Dart: `test/block_screen_test.dart` — the payload (round-trips, the sample-12 rule, adult
  anonymisation, the plan rule of `sanitised()`), `planLabel`, `BlockScreenCopy` (Conscious never
  "curious", the locked label of the way back, the opens line and its toggle, Unblock-5, an app
  wall keeps Home and Open Detoxo with no way back in and reads "Locked in your App Blocker", an
  adult wall is unnamed and offers the browser back, a website names the host and "On your Web
  Blocker list", `showCount`, `meta`, `line`), "the wall reads" (the native sweep on the Dart
  tokens via `Color.alphaBlend`: ink on the ground, ink-2 on the panel under the ambient at
  84 dp — .09 Dark / .048 Light — and ink on the Open Detoxo pill, for each palette main and the
  live accent's warm steps, both themes), `BlockScreenStyle` (defaults, a
  round-trip writing its four keys only, old keys ignored, `backDelaySec` clamping and tolerance),
  and that the settings push carries `themeMode`; `test/block_screen_cubit_test.dart` (hydrate,
  debounce, dirty guard, `enabled=false` push, the 5 s / instant back delay, Try it right after the
switch pushes it first — and only once — while nothing pending goes straight to the wall, failed
hydrate);
  `test/block_screen_preview_test.dart` (one layout in Light and Dark: the "Detoxo" wordmark and
  `DetoxoLogo`, the quote and its uppercase writer, the line and the meta, `LiquidPill` "Open
  Detoxo", `Icons.home_rounded`, the counted way back, one `Icon3d` tinted for a plan wall; the
  icon per block reason, the same table as `FrozenGlassTest`; the compact card; the logo and the
  seven icon WebPs load from `rootBundle`; the entrance plays once and `pumpAndSettle` returns
  with no frame scheduled, and under "Remove animations" nothing is scheduled at all; switched off
  the preview greys under an **Off** badge, and on brings it back; the editor's own switch and
  three options on panels drive the cubit, with its `InfoButton` copy and no look picker, Face
  Down or Spotlight left, each row one TalkBack node with its caption; Try it and the options
  disabled while off, and a missing grant fixed in place by the `NoticeLine`);
  `test/appearance_block_screen_card_test.dart` (the compact preview; switched off, the hub tile's status says what off
  means and the tile still opens the editor; on, it reads On; without the grant, Needs access
  opens it); `native_event_reporter_test.dart` (`blockScreenAction` logged, preview skipped;
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
  the Appearance switch while a forced wall stands keeps it up. The look: Try it in Light and
  Dark, "Match system" following the device, for every block reason (its 3D icon; a plan wall's
  mode icon in the accent) on API 24–27 and a recent device; the accent matches the Today screen
  (Block All indigo, Conscious, a Pause warming over its last 2 minutes, the daily limit warming
  toward `over`) on the ambient, Open Detoxo and the mode icon only; the logo keeps its colours
  with its glow; the panel's and the pill's shadows are soft and not clipped; glass grows and the
  rest presses on touch, nothing scales under "Remove animations"; a new wall fades in and its
  buttons rise, the quote fades up once and then nothing draws (`dumpsys gfxinfo`), an in-place
  rebuild does not flash; a new quote per wall, the same one across an in-place rebuild. Allow for
  a while: the chips (5 min picked) and the slide appear in place, the knob counts 5 s — also with
  `animator_duration_scale 0` — then a slide past 88 % confirms and the grant holds, an earlier
  release springs back, a tap hints; TalkBack lands on the picked chip and a double tap on the
  slide after the wait confirms, Switch Access too; at 2× font and in landscape the wall sheds the
  well, the quote size, its lines, the writer and the header before any text meets the buttons;
  the shadow bitmaps stay under 3 MB (`dumpsys meminfo`). "Back to Instagram" lands on the feed
  from the Reels tab and a profile, restarts Instagram from a DM thread, and reads "Dismiss"
  (just closes) on the launcher; TalkBack reads the quote.

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
- `android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/BlockScreenRenderer.kt` (payload, style spec, `planLabel`, `wallIsDark`, `build`, the button column with `addUnblock` / `fitChips`, `WallCopy` with `clockAt`)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/WallButtons.kt` (`WallButtons`: `primary` / `home` / `text` / `chip` + `select`, the press animators), `overlay/SlideToConfirmView.kt` (the wait + slide)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/QuoteWall.kt` (`QuoteWallView`, `reduceMotion`), `overlay/QuoteBook.kt` (`Quote`, `QuoteBook`), `res/drawable/ic_wall_home.xml`, `ic_dx_check.xml`, `ic_dx_chevrons_right.xml`, `assets/content/motivational_quotes.json`, `assets/images/icons/*.webp` (the 3D icons and `detoxo-logo.webp`)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/FrozenGlass.kt` (the pure helpers, `DxTheme`, `DxDrawable`, `DxArt`), `overlay/AccentResolver.kt` (`resolve`, `modeOf`, `usedFraction`, `forWall`), `overlay/DxTokens.kt` (generated)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/WallPolicy.kt` (`forced`, `reelWall`, `bypassesSwitch`, `MODE_BLOCK_SCREEN`)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/OverlayWindows.kt` (`overlayType` — shared with the bubble and the nudge — and `launchDetoxo`, used only by the wall)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/accessibility/DetoxoAccessibilityService.kt` (`openAppHome`, `tapInApp`, `appRoot`, `raiseWall`, `reelPayload`, `appLabel`, `platformName`, `appBlockStaysOver`, `backStaysOver`, `prevForegroundPkg`, `a11yPkgs`, `screenOffReceiver`, `tearDownOverlays`)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/channels/CommandHandler.kt` (six arms, `jsonToMap`)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/engine/UsageQuery.kt` (`hasAccess`, `opensToday`, `startOfDay`, `countOpens`)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/engine/ConfigStore.kt` (`blockScreenStyleJson`, `appThemeMode`, `appendGrant`), `engine/ContentCounterStore.kt` (`enabled`, `timeTodayMs`, `reelLimits` — the accent's inputs)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/engine/DetectionConfig.kt` (`PlatformRule.platformName`, `homeTabId`), `assets/config/platforms_config.json` (`homeTabId` on Instagram's wall surfaces)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/engine/ContentCounter.kt` (`todayCount()`)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/widget/ColorMath.kt` (`blend` / `withAlpha`), `widget/WidgetBitmapRenderer.kt` (`isSystemDark`), `widget/ReelWidgetSync.kt` (`plan`), `engine/RuleEngine.kt` (`DAILY_REEL_LIMIT_ID`)
- `android/app/src/main/res/values/strings.xml` (`wall_*`)
- `android/app/src/test/kotlin/com/errorxperts/detoxo/overlay/BlockScreenGeometryTest.kt`, `FrozenGlassTest.kt`, `AccentResolverTest.kt`, `WallPolicyTest.kt`, `QuoteBookTest.kt`, `engine/UsageQueryTest.kt`, `engine/DetectionConfigTest.kt`, `widget/Fixtures.kt` (`repoFile`)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/channels/CommandHandler.kt` (`BLOCK_MODES` / `THEME_MODES` whitelists on `pushSettings`)
- `lib/features/blocking/block_screen/**`
- `lib/features/blocking/blocking.dart`
- `lib/features/blocking/shared/domain/entities/enums.dart` (`planLabel`, `BlockingMode.blockScreen`), `engine_event.dart` (`BlockEvent.wall`)
- `lib/features/settings/presentation/widgets/block_mode_picker.dart` (`blockModes`, `BlockModeOptions`, `BlockModeTile`, `OptionTile`, `PermissionNeededRow`) and the `_BlockModeSheet` / `_BlockModeTile` wrappers in `settings_screen.dart`
- `lib/features/limits/daily_limit/presentation/daily_limit_screen.dart` (the overlay-missing banner branch)
- `lib/core/design_system/tokens/app_tokens.g.dart` (the spec tokens and palettes), `foundations/accent.dart` (`resolveAccent`, `accentIconFilter`), `components/dx_icons.dart` (`Icon3d`, `DetoxoLogo`), `components/buttons.dart` (`LiquidPill`, `GlassIconButton`), `foundations/glass_container.dart` (`GlassContainer`), `components/list_tiles.dart` (`PanelGroup`)
- `lib/features/additional_feature/appearance/presentation/appearance_screen.dart` (`_BlockScreenSection`)
- `lib/core/design_system/components/buttons.dart` (`SecondaryButton` — one tree for both states, so going disabled fades and keeps its 48 dp floor — and `InfoButton`, which opens its copy in a sheet; the editor uses them), `components/toggle.dart` (`AppToggle`, which fades to disabled too), `components/feedback.dart` (`AppReveal`, `NoticeLine`), `components/badges.dart` (`AppBadge`, the preview's Off), `foundations/motion.dart` (`AppPressable`'s press)
- `lib/core/constants/channel_constants.dart`, `lib/core/platform_channels/engine_channel.dart`
- `lib/core/services/firebase/analytics/{analytics_events,analytics_service,native_event_reporter}.dart`
- `lib/core/navigation/{routes,app_router}.dart`, `lib/core/di/injector.dart`, `lib/main.dart`
- `lib/features/blocking/shared/data/repositories/engine_repository_impl.dart` (`themeMode` on `pushSettings`), `lib/features/blocking/shared/presentation/settings_cubit.dart` (`setThemeMode`)
- `test/block_screen_test.dart`, `test/block_screen_cubit_test.dart`, `test/block_screen_preview_test.dart`, `test/block_mode_picker_test.dart`, `test/core/services/firebase/native_event_reporter_test.dart`
