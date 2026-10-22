# Overview & Architecture

Detoxo is a shipped Android app that detects short-form content — Reels, Shorts,
infinite feeds, stories/statuses — inside *other* apps and pulls the user back
out (Back / close / lock), plus a decoupled counter that tallies how many short
videos you scroll. It is built in **Flutter + flutter_bloc (Cubit)** with a
native **Android AccessibilityService** engine doing the hot detection/block
work. Package / application id: `com.errorxperts.detoxo`; asset & vendor
namespace `errorxperts`.

This is the top-level orientation doc. Sibling engineering docs drill into each
subsystem — see the detection engine, plans, content counter, permissions,
persistence, and channel-contract docs alongside this file. End users are served
by the `../info_docs/` set.

> iOS is **unsupported**: there is no AccessibilityService equivalent, so the
> app shows an "unsupported" screen and gates the entire native engine off. See
> [The native ↔ Dart boundary](#the-native--dart-boundary) and
> `lib/app/unsupported_screen.dart`.

---

## What Detoxo does (feature inventory)

| Area | What it does | Live in this build? |
|---|---|---|
| Reel/Short detection + block | Native AccessibilityService detects short-video surfaces via a 3-stage view-id scan and blocks (Back / kill / lock) | ✅ Native, real device |
| Blocking plans | `blockAll`, `curious` (user label **Conscious**), `oneReel`, `paused` | ✅ Honored by the engine |
| Conscious plan | Earn-as-you-abstain time-bank; a 1 Hz accountant lets reels play while the bank has allowance, then presses Back when drained | ✅ |
| Pause | Clock-based window (`pauseUntil`) that suspends blocking | ✅ |
| Content counter | Side-effect-free counting pass (decoupled from blocking) → overlay bubble + home-screen widget | ✅ Native, on by default |
| Blocklist | Data-driven from bundled `platforms_config.json`; install-aware | ✅ |
| App blocker / Web blocker / Daily limit | Custom whole-app blocks (HOME bounce) and web host matching run natively; daily limit is UI + persistence | ✅ App + web enforced natively; native usage/daily-limit enforcement is the remaining follow-up |
| Access protection (PIN) | PIN setup/lock/recovery, biometric, retry lockout | ✅ (`local_auth` + secure storage) |
| Permissions funnel | Accessibility, overlay, usage access, battery exemption, device admin | ✅ (Android-only) |
| Premium / entitlement | Modeled; unlocked via a **local dev-unlock** (Settings → Developer) | ⚠️ No live Play Billing (swap-in) |
| Ads | Wired with Google **test** ad-unit ids; no live init in Dart | ⚠️ Test only |
| Analytics (block-event history) | Local block-event history (rolling 500-event buffer) | ⚠️ Local buffer only (no cloud sink) |
| Firebase telemetry | Analytics + Crashlytics + Performance, anonymised | ✅ Wired ([19](19-firebase-telemetry.md)); collection on in all builds |
| Onboarding / feedback | Showcase tips (`showcaseview`); in-app feedback emails to support | ✅ |

Support contact: `errorxperts@gmail.com`.

Anything marked ⚠️ is *modeled but not wired to a real backend*; those are called
out as planned / swap-in / follow-up throughout these docs.

---

## Architecture: feature-first Clean Architecture

Detoxo is organized **feature-first**. Each feature under `lib/features/<x>/`
owns the full vertical slice and is split into the three Clean-Architecture
layers:

```
lib/features/<feature>/
  data/           models + repository implementations (talk to channels/storage)
  domain/         entities + enums + repository *contracts* (pure Dart)
  presentation/   Cubits + screens + widgets
```

**Dependency rule** (inside a feature): `presentation → domain ← data`. Domain
is pure and depends on nothing app-specific; data and presentation both depend on
domain, never on each other.

**Cross-feature rule:** a feature may import another feature's **public barrel**
(`features/<x>/<x>.dart`) or its **`domain/`** contracts and entities — never
another feature's `data/` or `presentation/` internals. This keeps features
swappable and testable in isolation.

Public barrels currently exported:

```
access_protection · analytics · blocking · dashboard · limits
onboarding · permissions · settings
additional_feature/app_feedback · additional_feature/showcase_view
```

The **blocking** context is the core bounded context and is itself sub-structured:

```
lib/features/blocking/
  shared/     domain (AppSettings, BlockTarget, enums, repo contracts)
              + data (models, repo impls) + shared SettingsCubit  ← the spine
  engine/     presentation only (ServiceCubit — live service status)
  blocklist/  presentation only (TargetsCubit + blocklist UI)
  plans/      domain (session-phase rules) + data (bundled content)
              + presentation (pause, countdown, ConsciousCubit)
```

The **content_counter** context is likewise split into cooperating sub-features
(each with its own layers): `content_counter_core` (counting + snapshots),
`content_counter_bubble` (the floating overlay), `home_content_counter` (the
home-screen widget), and `content_counter_appearance` (bubble/widget styling
screens).

### Composition roots

A handful of directories exist specifically to *wire features together* and are
therefore exempt from the cross-feature rule:

- `lib/app/**` — the app entry (`main.dart`), `splash_screen.dart`, `unsupported_screen.dart`,
  `live_accent.dart`
- `lib/core/di/**` — the `get_it` service locator
- `lib/core/navigation/**` — the `go_router` graph
- `lib/features/dashboard/**` — the home shell that hosts feature tabs
- `lib/features/settings/**` — the settings orchestrator

### The boundary rule is enforced (with a caveat)

`tool/check_boundaries.sh` walks `lib/features/**/*.dart` (excluding generated
`*.g.dart` / `*.freezed.dart`), skips the composition roots above, and flags any
file that imports another feature's `data/` or `presentation/`.

> **Fixed (Aug 2026).** The script's patterns still carried the pre-rebrand package
> prefix while the real package is `detoxo`, so the grep never matched and the check
> reported "✓ No feature-boundary violations" unconditionally from the rename onward.
> It now greps `package:detoxo/` and genuinely enforces the rule.
>
> Repairing it surfaced **12 pre-existing violations** in one go. They are listed
> in `tool/boundaries_baseline.txt` and reported as warnings so the gate can be
> enforced today; anything *not* on that list fails the build. Most share a single
> root cause: `settings_cubit` is a cross-cutting cubit six features need, but it
> is only reachable through `blocking/shared/presentation/` — exporting it from the
> blocking barrel (or moving it to `core/`) clears five entries at once. Burn the
> list down and delete it; do not add to it.

---

## Runtime wiring: Cubit + get_it + go_router

Detoxo uses **Cubits only** (flutter_bloc) — no event-driven Blocs, no Riverpod.
State flows: repository (data) → Cubit (presentation) → widget.

### 1. Boot — `lib/main.dart`

`main()`:
1. `WidgetsFlutterBinding.ensureInitialized()` and sets a transparent system UI.
2. `await configureDependencies()` — builds the service locator.
3. Registers the global feedback action button, then `runApp(DetoxoApp())`.

`DetoxoApp` installs the app-wide Cubits with a `MultiBlocProvider`, each
resolving its repository from the locator `sl`:

| Cubit | Resolves |
|---|---|
| `ServiceCubit` | `EngineRepository` |
| `ConsciousCubit` | `EngineRepository` |
| `SettingsCubit` | `SettingsRepository`, `EngineRepository` |
| `TargetsCubit` | `ConfigRepository`, `EngineRepository` |
| `PermissionsCubit` | `PermissionRepository` |
| `PinCubit` | `PinRepository` |

`SettingsCubit` doubles as the app's appearance source: a `BlocSelector` on
`AppThemeMode` drives the theme, and a `BlocListener` mirrors the vibration
preference into `AppHaptics`. The tree then renders `AppResumeSync` →
`PinAutoRelock` → `MaterialApp.router` wired to the go_router config, with
`AppTheme.light()` / `.dark()` and a `builder:` that wraps every route in
`LiveAccent` (the live accent) and the per-theme system-bar `AnnotatedRegion`
([the design system](#the-frozen-glass-design-system--libcoredesign_system)).
`AppResumeSync` (`lib/app/app_resume_sync.dart`) re-runs the Dart↔native syncs
on every app resume — cheap refreshes (permissions, service status, counter,
settings re-push) every time, the heavy config/blocklist re-push at most every
15 min (see [12-analytics-notifications-resilience.md](12-analytics-notifications-resilience.md) §3.2).

### 2. Dependency injection — `lib/core/di/injector.dart`

`get_it` instance is the global `sl`. `configureDependencies()`:

- Eagerly constructs `LocalStore` (async `create()`) and registers it as a
  singleton, plus a lazy `EngineChannel`.
- Registers every repository **interface → implementation** lazily
  (`ConfigRepository`, `SettingsRepository`, `EngineRepository`,
  `PermissionRepository`, `PinRepository`, the `limits` repos, `InsightsRepository`,
  `ContentRepository`, the content-counter repos, `FeedbackRepository`, …).

Registering by interface keeps Cubits testable — a fake repo swaps in without
touching presentation.

### 3. Navigation — `lib/core/navigation/`

`buildRouter()` (`app_router.dart`) returns a flat `GoRouter` whose paths live in
`routes.dart` (`Routes.splash`, `.onboarding`, `.permissions`, `.home`,
`.pinSetup`, `.pinLock`, `.settings`, `.webBlock`, `.appBlock`, `.dailyLimit`,
`.rules`, `.analytics`, `.bubbleStyle`, `.homeWidget`, `.unsupported`, …).
`initialLocation` is the splash route.

**Every constant in `routes.dart` is a path, and every one resolves.**
`test/routes_registered_test.dart` reads that file as text, regexes out each
`static const String`, and asserts it against the built `GoRouter`
configuration — no mirrors, no hand-kept list to drift. It exists because
`Routes.pause`, `Routes.curious` and `Routes.unsupported` sat declared but
unregistered for months: navigating to any of them failed at runtime and nothing
caught it. `pause` and `curious` were deleted (Pause and Conscious are dashboard
*modes*, not destinations); `unsupported` was registered against the
`UnsupportedScreen` that had been sitting orphaned in `lib/app/`.

**Gating is declarative: one `redirect`, reading one object.** It used to be an
imperative `context.go(...)` chain inside the splash, restated in the PIN
screen's `onUnlocked` and again (by bouncing back through the splash) at the end
of onboarding — three copies of one order.

`AppGate` (`lib/core/navigation/app_gate.dart`) is a small `ChangeNotifier`
holding `ready / supported / onboarded / pinLocked / permissionsOk`. The router
takes it as `refreshListenable` and its `redirect` is a one-liner delegating to
`AppGate.redirect(location)`. Cubits are `Stream`s and `refreshListenable` wants
a `Listenable`, so the flags are pushed in by `BlocListener`s in `main.dart`;
that also keeps `core/navigation/` free of feature imports and makes the whole
order unit-testable with no widget tree (`test/app_gate_test.dart`).

Two details that are load-bearing rather than cosmetic:

- `redirect` returns **null** when the location already *is* the destination.
  That is what stops `GoRouter` looping.
- `Routes.permissions` is **not** a pass-through screen. Once the two required
  permissions are granted the user is left on it — granting accessibility and
  overlay must not yank them away while they work through the recommended ones.
  They leave via its own Continue button. `splash`, `onboarding`, `pinLock` and
  `unsupported` *are* pass-throughs and eject to `home` once satisfied.
- The permissions gate only *applies* from a pass-through or `/home`
  (`_permissionsGateApplies`). The `PermissionsCubit` listener that feeds the
  gate fires on every app resume, so an unscoped gate destroyed in-progress work:
  lose accessibility while composing a rule at `/rules/edit` and the editor, its
  unsaved rule and its `state.extra` went with it. The user is funnelled on the
  next trip through home instead.
- `pinLocked` is a **session** flag, not a derived one: armed once by the
  bootstrap, cleared by a successful unlock. Re-locking on resume is
  `PinAutoRelock`'s job and does not route.
- `relocking` is a separate `ValueNotifier<bool>`, **not** a routing input
  (the redirect never reads it, and it doesn't refresh the router): raised by
  `PinAutoRelock` from a resume until its lock is decided or dismissed, so the
  builder-mounted listeners that open a screen on resume (`PendingUnblockListener`,
  `WidgetTapListener`) don't push above the pageless lock ([08](08-pin-lock-recovery.md)).

### 4. Bootstrap and gating order — `lib/app/bootstrap.dart`

The splash no longer routes; it renders the brand moment and calls
`runBootstrap(context)`, which ends by opening the gate. `_bootstrap()` used to
do four jobs in one method — cubit hydration, first-run seeding, native drift
repair *and* routing — of which only the last ~14 lines were routing.

`runBootstrap` is three phases, each step individually wrapped in the existing
`guardedSync` (`lib/app/engine_sync.dart`), so **one failing leg can never stop
app start**. Before this, a throw anywhere in the inline sequence left the user
on the spinner forever.

1. **Blocking** — only what the gate decision reads, in parallel:
   `settings.bootstrap()`, `permissions.refresh()`, `pin.load()`.
2. **First run only, strictly ordered** — seed the enabled-platform set from
   every target that is both `defaultEnabled` and `isInstalled`. Genuinely
   sequential: the seed needs `targets.load()` (native config push +
   installed-package scan, the slow leg) to have finished. Apps the user does
   not have are never pre-enabled.
3. **Gate opens**, then **background** — the home-widget re-render, blocklist
   drift repair (`syncEngineBlocklists()`, also the resume path's heavy leg),
   and the `rules` / `dailyLimit` / `streak` reloads, all fire-and-forget.
   Nothing routes on any of it, so making the user watch it would be pure
   latency. On a non-first run `targets.load()` moves into this phase.

The first-run predicate is captured **before** phase 2, not re-read after it:
`SettingsCubit._commit` emits synchronously, so the seed makes the enabled set
non-empty and a re-read would run the slow leg a second time on the one launch
that can least afford it. Those three cubit reloads live here and **only** here —
`main.dart` deliberately does not `..load()` them at provider construction, which
used to run every one of them twice per cold start (and `RulesCubit.load()` ends
in a resync, so that was two UsageStats reads and two native pushes).

The whole body is wrapped in try/finally, and **the finally opens the gate
regardless**. The per-step guards cover the phases but not the prologue's
`context.read`s or the `gate.update` argument list — a throw there left `ready`
false, which pins every location to `/`, and the splash does not re-run its
post-frame callback, so the spinner was forever. On that path `onboarded` is read
from the repository rather than the cubit that may be what failed: opening the
gate with a default `false` would walk an already-onboarded user back through the
entire first run, a worse outcome than the failure being recovered from.

The order the gate then applies:

```
unsupported  →  onboarding  →  PIN lock  →  permissions  →  home
```

1. `!ready` → `Routes.splash` (nothing routes on unloaded state)
2. `!supported` (`PlatformCapabilities.isBlockingPreviewOnly`) → `Routes.unsupported`
3. `!onboarded` → `Routes.onboarding`
4. `pinLocked` (PIN configured and guards `PinScope.app`) → `Routes.pinLock`
5. `!permissionsOk` (`allRequiredGranted`) → `Routes.permissions`
6. otherwise → `Routes.home`

**"Reset app data" re-enters the splash without restarting the process**, so
`settings_screen.dart` calls `AppGate.reset()` before `context.go(Routes.splash)`.
Without it the gate would still hold the pre-wipe flags, wave the user straight
back to home, and the bootstrap would never run.

### The home shell — `lib/features/dashboard/presentation/home_shell.dart`

`HomeShell` is a two-tab surface (**Dashboard** / **Activity**) over the ground
gradient, with a floating glass bottom bar. The former "More" tab now lives in
a right-side `AppDrawer`. Deeper screens (settings, blockers, daily limit,
analytics, content-counter appearance) are reached via routes.

`Routes.blocklist` used to register a *second* `HomeShell` on `/blocklist`,
which is how the two tabs came to share one navigation stack; that constant is
gone and `/home` is the only registration.

**Why no `StatefulShellRoute.indexedStack`, and no per-tab deep link.** Both tabs
are leaves — every drawer destination pushes *above* this shell — so there is no
per-tab back stack for an indexed stack to preserve. It would, however, keep both
tabs alive at once, and `_tab()` deliberately builds **only the active one** so
the floating bar's single `ScrollController` attaches to exactly one scrollable
for hide-on-scroll. A `?tab=` query seam was briefly added and then removed: no
caller anywhere in the app produced such a URL and the gate's redirect returns a
bare `Routes.home`, so the parameter was provably never non-default. Add it back
the day something actually links to a tab.

`DashboardTab` renders its sections in order: `DashboardTopBar` → `_Hero`
(`CommandCenterCard`) → `_ModeSection` (`ModeSelector`) → `_SessionBanners` →
`RulesCard` → `BlockerSection`. The house split is that a section
needing cubits stays inline in `dashboard_tab.dart` as a private `_Xxx` widget
while its presentational half lives in `presentation/widgets/`. (The former
`ProtectionStatusCard` slot is now the `RulesCard`, styled as that status row;
service status is surfaced by the permission gate / setup screen instead.)

Rebuild/state note on the dashboard (polish):

- The `_Hero`'s Conscious countdown uses `context.select` on a **record of the
  four displayed fields** so the 1 Hz Conscious tick doesn't rebuild the whole
  hero, and the Conscious session banner is extracted into a private
  `_ConsciousBanner` widget so that tick rebuilds only that tile.

`ModeSelector` (`presentation/widgets/mode_selector.dart`) is the horizontally
scrolling strip of four mode pills (Block All, Conscious, Pause, One Reel). Each pill is an illustration "coin" over its
label: the mode's `assets/images/illustration/*.png` clipped to a ring-lit circle
— the same artwork its feature-tour step shows. The art is full-colour on an
opaque backdrop, so the circular clip is what turns it into an icon, and the
inactive state dims/shrinks the coin rather than tinting it. Every decode is
capped with `cacheWidth` (the source art is 1024²).

`BlockerSection` (`presentation/widgets/blocker_section.dart`) is the exception
that owns its own data: it renders the App Blocker / Web Blocker pair as two
`BlockerTile`s and reads the live entry counts itself. Both blocker cubits are
screen-scoped — created inside `BlocProvider`s in `app_block_screen.dart` /
`web_block_screen.dart` — so there is nothing to watch from the dashboard. The
section resolves `AppBlockRepository` and `WebBlockRepository` through `sl`
instead, counts the entries with `enabled == true`, and re-reads them when the
user pops back from either blocker screen, so the captions never go stale.

### The Frozen Glass design system — `lib/core/design_system/`

The app's look is the **"02 Frozen Glass"** design system (the claude.ai Design System
artifact *Detoxo Design System*). Light and Dark stand on equal footing: every screen sits on
one vertical ground gradient, surfaces are picked **by role**, text is Manrope in named styles
with tabular figures, and **one live accent** — chosen by the blocking mode and today's share of
the daily limit — is the only colour that moves. Screens import the single barrel
`design_system.dart` (it re-exports `flutter_animate` too) and read the tokens through
`context.tokens`; they never write a hex value or a magic number a token covers.

#### Tokens: one generated source for Flutter and the native wall

| File | Role |
|---|---|
| `tool/design/tokens.json` | A **byte copy** of the spec's `tokens.json`. Never edited, so a spec update is a plain diff |
| `tool/design/recipes.json` | Everything the spec keeps in `components/bundle.css` rather than `tokens.json`, in the same `{name, value, usage}` shape: accent strengths `k*`, component colours (pill, lens, slide track, knob, icon well, grabber, soft button, the Session sheet's `control` / `start` / `started`, the sheet `scrim`), extra shadows, surface blur/saturate, fixed constants, type variants (`eyebrow`, `numberLg`, `eyebrowLg`, `count`, `labelStrong`) and **overrides** — today one: Light `ink-3` `#7d8699` (3.03:1 on `card-to`; the spec's `#8a93a6` is 2.55:1, under its own 3:1 icon rule) |
| `tool/design/gen_design_tokens.dart` | Reads both and writes the two outputs below; `--check` exits 1 on drift. Pure helpers (CSS colour parsing, casing, the write/`--check` loop) live in `tool/tokens_common.dart`, shared with the home-widget generator |
| `tokens/app_tokens.g.dart` (`part of app_tokens.dart`) | `AppTokens.light` / `.dark` + `forBrightness`, `ConfirmTone.{caution, critical, neutral}` (`a, b, c, ink, knob`), `AppTypography`, and the spacing / radius / blur / fixed statics |
| `android/.../overlay/DxTokens.kt` | `internal object DxTokens`: flat `<TOKEN>_<THEME>` ARGB ints, `PALETTE_<P>_<THEME>` IntArrays, type in sp (tracking in em), `SHADOW_*` lists of `DxShadowLayer` — for the native wall |

Generator rules: a `P-main / -light / -deep` set becomes an `AccentPalette` (`blockall` →
`blockAll`, `onereel` → `oneReel`); `tone-<t>-<f>` becomes `ConfirmTone`; a shadow keeps the CSS
layer order and the CSS **blur radius** (painted as a Gaussian σ of blur / 2); a type style keeps
the CSS line box (`height: L / S`, even leading, tabular figures); a `%` value is a fraction.
New values go in `recipes.json`, then `dart run tool/design/gen_design_tokens.dart`; never
hand-edit either output. `bash tool/dev.sh precommit` runs the `--check`
(`design_tokens()`), and so does `test/core/design_system/design_tokens_test.dart`.

The hand-written side is small:

- `tokens/app_tokens.dart` — `AccentPalette(main, light, deep)` (`lerp` = CSS `color-mix` per
  stop), `DxShadow`, `context.tokens`, and `t.accentText(p)` / `t.statusText(c)`: coloured text
  that reads at 4.5:1 (Light mixes toward `#0b1020` by 40 %, Dark uses the `light` stop / the
  raw colour).
- `tokens/app_spacing.dart` — `AppSpacing` (the spec steps `inset 8 · gap 14 · card 16 ·
  gutter 20 · section 32`, plus `sheetSide 22`, `headerTop 54`, `floatingNavClearance 132`),
  `AppRadius` (`icon 8 · chip 20 · row 22 · cardSm 26 · card 28 · bar 32 · sheet 40 · pill`),
  `AppSizes` (`controlHeight 44`, `minTapTarget 48`), `AppInsets`.
- `tokens/app_motion.dart` — the motion tokens (below).

The fields are the spec's: ground and surfaces (`bgTop/bgBottom`, `cardFrom/To`,
`panelTop/Bottom`, `glassTop/Bottom`, `sheetTop/Bottom`, `optionBase`), the ring materials, the
ink ramp `ink / ink2 / ink3`, `hairline`, `fillQuiet`, `focus`, status `statusOn/Paused/Setup`,
`streak`, `tileApp/tileWeb`, the six palettes `brand, blockAll, conscious, pause, oneReel, over`,
the strengths and the shadow recipes (`shadowCard`, `shadowGlass`, `shadowSheet`, `shadowGroove`,
`shadowDisc`, `shadowButton`, `pillEdge`, `lensEdge`, `trackShadow`, `startShadow`,
`startedShadow`). Mixing follows the CSS: `color-mix(X k%, transparent)` is
`X.withValues(alpha: k)`, an opaque mix is `Color.lerp(optionBase, main, k)`.
`test/core/design_system/contrast_test.dart` checks every text and icon token on its real
surfaces in both themes (translucent ones composited first): 4.5:1 for text, 3:1 for icons and
the focus ring. Status dots are exempt by design — a word always carries the status.

#### Theme — `theme/app_theme.dart`

`AppTheme.light()` / `.dark()` are built once, only from `AppTokens`. The scheme carries the
**static** `brand` and the ink ramp — `primary` `brand.main` (on it the neutral tone ink, since
white is 3.84:1), `secondary` `accentText(brand)`, `error` `accentText(over)`, `onSurface` `ink`,
`onSurfaceVariant` `ink2`, `outline` `ink3`, `outlineVariant` `hairline` — so the slider,
progress, cursor and time picker take the static brand, and the live accent never enters it.
All 15 `TextTheme` slots map to a named style (`displayLarge/Medium` `number`, `headline*`
`titleXl` / `titleSheet`, `titleLarge` `title`, `titleMedium` `headline`, `bodyLarge`
`message`, `bodyMedium` `body`, `bodySmall` `subhead`, `labelMedium` `caption`, `labelSmall`
`tab`…). `AppTheme.overlay(b)` gives transparent system bars with the right icon brightness,
applied by the `AnnotatedRegion` in `MaterialApp.router(builder:)`. A theme switch snaps
(`themeAnimationDuration: Duration.zero`), and `_CalmTransitions` keeps Android's
predictive-back page transition but drops it under Reduce Motion. Appearance offers System /
Light / Dark; Dark is the default.

#### Surfaces — `foundations/glass_container.dart`

`GlassContainer(surface:, borderRadius:, padding:, color:, backdrop:)` is the **one** surface
primitive; nothing else calls `BackdropFilter` for a surface. It paints one of five roles:

| `DxSurface` | Where | Fill · radius | Shadow | Backdrop |
|---|---|---|---|---|
| `glass` | floating controls: header buttons, toasts, FABs, the tab bar | `glassTop → glassBottom` · pill | `shadowGlass` | blur 22, saturate 1.8 |
| `panel` | section panels and list groups | `panelTop → panelBottom` · 22 | `shadowCard` | **never** |
| `tile` | blocker tiles | 145° `cardFrom → cardTo` · 28 | `shadowCard` | none |
| `option` | solid choices: mode card, quick picks, segment tracks | `optionBase` (or `color:`) · 28 | none | none |
| `sheet` | bottom sheets and dialogs | `sheetTop → sheetBottom` · 40 | `shadowSheet` | blur 30, saturate 1.7 |

`DxSurfacePainter` paints a CSS box exactly as a browser stacks it: outer shadow layers in
**reverse** recipe order, each clipped to *outside* the shape (so a translucent fill is never
darkened by its own shadow) and blurred with `MaskFilter.blur(normal, blur / 2)` — never
`BoxShadow.blurRadius`; then `background-color`, then the linear gradient on the CSS angle line
(`cssLine`, corner-exact at any aspect); then inset layers inside the shape. The backdrop is
`ImageFilter.compose(saturate matrix (cssSaturate), blur)`, for `glass` and `sheet` only;
`backdrop: false` turns it off where it is invisible (header buttons over the static ground).
Panels never blur — only the smooth ground sits behind them (a `ponytail:` note marks where to
add one). Each surface sits in a `RepaintBoundary`.

The role reaches the subtree through `GlassContainer.surfaceOf(context)`: a `GlassListTile`,
`PanelGroup` or `PermissionCard` already on a panel or sheet draws **no surface of its own** —
no glass inside glass — and a standalone one wraps itself in one panel.

`foundations/glass_scaffold.dart` holds the screen chrome: `GlassScaffold` (a transparent
`Scaffold` over the static `bgTop → bgBottom` ground — one paint, no blur, nothing that moves)
and `GlassAppBar`, the plain header: transparent, 64 tall, the title in `title`, a
`GlassIconButton` back button on a pushed route, and the app-wide `globalActionsBuilder` (the
feedback button) after the screen's own actions.

#### Motion — `tokens/app_motion.dart`, `foundations/motion.dart`

| Token | Duration | Curve | Used by |
|---|---|---|---|
| `press` | 400 ms | `Cubic(.34, 1.56, .64, 1)` | every pressable |
| `chip` | 500 ms | `Cubic(.34, 1.25, .64, 1)` | a selection chip sliding to its pick |
| `lens` | 550 ms | `Cubic(.34, 1.3, .64, 1)` | the tab lens |
| `detail` | 500 ms | `Cubic(.2, .8, .2, 1)` | a detail row opening; the ring arc |
| `glide` | 1000 ms | CSS `ease` | any accent change; the sheet scrim's fade |
| `sheet` / `scrim` | 600 / 450 ms | `Cubic(.32, .72, 0, 1)` / `ease` | a bottom sheet and its scrim |

`AppCurves.squish` drives each segment of `Squish` (1 → 1.08/.93 → .98/1.03 → 1 at 30/35/35 %),
which the selection chips wear. `context.motion(d)` returns zero under Reduce Motion, and every
component routes its timing through it. `AppPressable` is the one custom tappable: scale to
`pressedScale` (cards .975, buttons .95, glass circles grow to 1.06) on the press curve, none
under Reduce Motion; a `button` semantics node with `enabled` / `selected` /
`inMutuallyExclusiveGroup` (one radio node per option); Enter / Space activation; and a
`FocusRing` — a 2 px `focus` stroke 3 px outside the shape — while focused. `minTapTarget`
pads small controls to the 48 dp floor. `PressScale` is the same press without a recognizer
(for Material buttons); `StatusDot` is a static dot. **Nothing loops**: the entrance helpers
(`EntranceX`, `EntranceList`) play once and skip under Reduce Motion, and the only exemption is
an indeterminate `LoadingState` spinner, held still under Reduce Motion.

#### The live accent — `foundations/accent.dart`, `lib/app/live_accent.dart`

`resolveAccent(t, mode, used:, pauseLeft:)` picks the palette for an `AccentMode`
(`none, blockAll, conscious, pause, oneReel`) and `used`, today's share of the daily limit:

- **none** (blocking off): `brand` up to 60 % used, blending to `pause` by 85 % and to `over`
  at 100 %;
- **a base mode or One Reel**: its own palette, warming toward that pause → over blend from 60 %
  used, at most 80 % of the way;
- **Pause**: `pause`, blending to `over` over the last two minutes of `pauseLeft`; an N-reel
  unblock passes no `pauseLeft` and stays `pause`.

The expressions are written literally, so the Kotlin `overlay/AccentResolver.kt` (double maths,
one final rounding; not wired into the wall yet) and the fixture's Python model compute the same
ARGB: `test/fixtures/accent_cases.json` is read by both `accent_test.dart` and
`AccentResolverTest.kt`.

`AccentScope(light:, dark:, glideKey:)` publishes both themes' palettes, so a theme switch snaps
like every other token. A change **glides over 1 s** on CSS `ease`, starting from the colour on
screen even mid-glide; it is **instant under Reduce Motion**; and it glides only when `glideKey`
changes with it, so a live Pause's per-second tick **snaps** instead of restarting a glide every
second. `context.accent` reads it, falling back to the static `brand` with no scope.
`accentIconFilter(accent, {saturate, opacity})` is the CSS `hue-rotate(hue − 214°)
saturate(s)` matrix that turns the blue 3D mode icons to the accent.

`LiveAccent` (`lib/app/`, a composition root) is mounted outermost in
`MaterialApp.router(builder:)`, so every route, sheet and dialog sees it. It reads
`SettingsCubit`, `ContentCounterCubit` (counting on, time today) and `DailyLimitCubit` (the
limit), maps the settings to a mode with `accentModeOf` — master switch off → none, else the
dashboard's own `modeIndex(s, pauseLive:)`, so the lit mode and the accent can never disagree —
and keys the glide on `(mode, used)`. A 1 Hz timer runs only while a Pause is live. The spec
lets the accent paint six things only — the ring arc and its glow, the mode card and its chip,
the mode icons, the Unblock pill tint, the tab lens; today `CommandCenterCard`'s ring is its
reader.

#### Components — `components/`

| Area | Components |
|---|---|
| Buttons (`buttons.dart`) | `PrimaryButton` — the spec **soft button**: a 54 px pill on the 145° `buttonFrom → buttonTo` with `shadowButton`, the label in `button` / `ink`, no accent, `.45` when disabled, `expand` / `icon`. `SecondaryButton` — an `ink2` label with no surface on a 48 dp target; `destructive: true` sets it in `accentText(over)`, never a red fill. `AnimatedIconButton` — the soft button with a morphing icon. `LiquidPill(tint:)` — the spec **accent pill**: 44 px, `tint` at `kPill` under the `pillHi → pillLo` sheen and `pillEdge`, a `tint` glow at `kPillGlow`. `GlassFab` — a floating glass pill, glyph + label. `GlassIconButton` — a 44 px glass circle, 22 px ink icon, 48 dp target, a `Tooltip` carrying its label. `InfoButton(message)` — a `GlassIconButton` that opens the message in a sheet. `DrawerMenuButton` (`menu_button.dart`) — the header's sidebar button |
| Overlays (`overlays.dart`, `dialog.dart`) | `GlassBottomSheet.show({child, title, dismissible, glow})` — the spec **SHEET**: a `sheet` surface inset 10 px from the edges, padded 0 / 22 / 22, a 40×5 grabber in a 30 px band, an optional `titleSheet` title, over the **scrim** (the backdrop blurred 8 at saturate 1.2 under a radial `scrim` dim, `120% 70% at 50% 100%`, stops `kScrim0/60/100`). It slides 600 ms, the scrim fades 450 ms; neither moves under Reduce Motion. Dragging the grabber or title down past **110 px** closes it, a shorter drag springs back on the press curve; `dismissible: false` locks the barrier, the drag and back. `glow` paints a 340×260 light behind the top edge. `AppDialog.show` / `.confirm` render **in the sheet**: an optional neutral `IconBadge`, a centred `titleSheet`, a `message` and/or `content`, the actions stacked full-width with the confirm on top. `GlassToast.show(context, message, tone:, action:)` — a glass pill with the tone's glyph (success: the spec check `Glyph`) and the message in `ink` (never a tone colour), an optional inline `action` such as **Undo**; it stays **4 s**, **6 s** with an action, **10 s** while a screen reader or switch access navigates, and drops its slide under Reduce Motion |
| Selection & input (`selection.dart`, `toggle.dart`, `inputs.dart`, `variant_carousel.dart`) | All **OPTION and accent-free**. `GlassSegmented` — a `fillQuiet` track with a solid `optionBase` chip that slides on the chip curve plus `Squish`; the picked label goes `ink2` → `ink` behind a 16 px check; tap, scrub along the track, or focus each segment as one radio. `AppChip` — `fillQuiet`, selected `optionBase` + a check, 48 dp floor; `ChipRail` lays them in two scrolling rows. `AppToggle` — 48×28: on `statusOn` with the `knob`, off `fillQuiet` with a hairline rim and an `ink3` thumb. `AppSearchField` — a `fillQuiet` pill with a focus ring. `VariantCarousel` — OPTION cards, the pick solid `optionBase` with an ink check badge |
| Spec art (`dx_icons.dart`) | `Icon3d(asset, size:, accentTint:, selected:)` — a spec 3D icon; `accentTint` turns it to the live accent through `accentIconFilter`, idle at `iconSaturateOff` / `iconOpacityOff`. `Glyph(svg, size:, color:)` — a spec SVG glyph drawn `srcIn`, `ink` by default. `DetoxoLogo(height:)` — the logo at 100:192, never recoloured, over its `logoGlow` drop-shadows (Dark σ 8; Light a σ 1 contour plus a σ 10 glow). All are decorative unless given a `semanticLabel` |
| Lists & status (`list_tiles.dart`, `section_header.dart`, `badges.dart`) | `GlassListTile` — a flat row (56 min, `label` over a two-line `subhead`), the 18 px `ink3` chevron `Glyph` when tappable with no trailing (drawer rows and the rules card use it too), a check when `selected: true`; it is its own panel only when standalone. `PanelGroup` — the section idiom: rows in **one** panel split by inset hairlines. `AppToggleTile`. `SectionHeader(label, note:)` — the uppercase `eyebrow` (caption, 1.6 tracking, `ink2`), `section` 32 above and 12 below, a header to TalkBack. `Pill` — a **status label**: an 8 px dot in `toneColor` (or `dotColor:`) or an icon in `toneText`, then the word in `subhead` `ink2`; no fill or border. `toneColor` / `toneText` map an `AppTone` to its dot and its 4.5:1 text colour. `AppBadge` — the "+N" quiet pill |
| Cards & feedback (`cards.dart`, `feedback.dart`, `permission_card.dart`) | `GlassCard` — a panel, optionally tappable; `AppCard`, `StatCard` / `StatCardPair`, a neutral `IconBadge`. `ProgressRing(progress:, size:, palette:, child:)` — the spec ring in its materials, every measure the 300 px ring scaled to `size` (stroke 24·size/300): the groove, the track, a three-stop arc of `palette` (default `brand`) with a blurred copy at `kArcGlow`, the knob with its `kHalo` halo and `knobShadow`, and the centre disc with its `discWash`; a null `progress` draws no arc and no knob. `ProgressBar`, `LoadingState`, `EmptyState` (no loop), `AppReveal`, `NoticeLine`. `PermissionCard` — a neutral badge, the title, the why and the status in words (On / Needs access / Checking…), its own panel only when not on a surface |

`adaptive/` keeps one control, `AdaptiveSlider` (a native `CNSlider` on iOS/macOS, Material
`Slider` on Android); `foundations/animated_icons.dart` wraps the Lucide `AppIcon` catalogue,
which never plays on its own.

#### Rules that hold app-wide

- **Roles, not looks.** Floating controls are glass; groups are one panel; a choice is an
  OPTION; nothing on a panel or sheet draws a second surface.
- **The accent stays in its six places.** Buttons, selection, toggles and status are neutral;
  Material affordances take the static brand from the scheme.
- **Status is a dot plus a word**, never colour alone; coloured text goes through `accentText` /
  `statusText` / `toneText`.
- **Destructive is `over` accent text**, never a red fill.
- **Nothing loops**, and every timing goes through `context.motion`, so Reduce Motion stills it.
- **Targets are 48 dp**, focus draws the ring, every custom tappable is one semantics node.
- **No raw hex and no magic numbers** a token covers; a new value is a `recipes.json` entry.

Tests: `test/core/design_system/` — `design_tokens_test` (the `--check` plus a spot value per
parser branch), `contrast_test`, `theme_test`, `glass_container_test`, `pressable_test`,
`accent_test`, `buttons_test`, `overlays_test`, `glass_segmented_test`, `app_chip_test`,
`toggle_test`, `chip_rail_test`, `list_tile_test`, `progress_ring_test`, `dx_icons_test`,
`app_icon_avatar_test`
— plus `test/app/live_accent_test.dart`, `test/design_system_text_scale_test.dart` and the
native `overlay/AccentResolverTest.kt`.

---

## The native ↔ Dart boundary

The split of responsibility is deliberate:

- **Dart owns** configuration, settings, plans, UI, and all persistence of user
  preferences. It is the control plane.
- **Native owns the hot path**: the AccessibilityService receives a11y events,
  runs detection, applies the active plan/pause gate, blocks, counts content, and
  matches web hosts — all in the main process, off the Dart isolate, so it keeps
  working even when the Flutter UI process is gone.

### One command channel, one event channel

Everything crosses through exactly **two** platform channels (names in
`lib/core/constants/channel_constants.dart`; wired natively in
`android/.../MainActivity.kt`):

| Channel | Direction | Name |
|---|---|---|
| `MethodChannel` | Dart → native (commands) | `com.errorxperts.detoxo/commands` |
| `EventChannel` | native → Dart (stream) | `com.errorxperts.detoxo/events` |

`EngineChannel` (`lib/core/platform_channels/engine_channel.dart`) is the single
low-level wrapper repositories build on. It exposes typed helpers for the command
methods — `pushConfig`, `pushSettings`, `pushWebBlocklist`, the permission
checks/launchers, `performBack` / `killApp` / `lockScreen`, `blockStats`,
`consciousState`, and the content-counter commands (`contentCounterSnapshot`,
`setContentCounterEnabled`, `setContentBubbleEnabled`, `pinContentWidget`,
`refreshContentWidget`, `setCounterStyle`, `installedPackages`). The event stream
is a single broadcast stream whose payloads are demultiplexed by a `type` field:
`serviceStatus`, `blocked`, `webBlocked`, `consciousState`, `reelSessionState`,
`contentCounted` — six types, each with a real native emitter. (The `detection` and
`foregroundChanged` constants listed in an earlier revision were inert and have been deleted;
[18-platform-channel-contracts.md](18-platform-channel-contracts.md) is authoritative.)

The command/event contract is documented in full in the platform-channel
contract doc; the native side of the hot path is in the detection-engine doc.

### Gated off non-Android

`PlatformCapabilities` (`lib/core/platform/platform_capabilities.dart`) is the
single source of truth for "what can this platform do". `EngineChannel` consults
`supportsBlockingEngine` and **no-ops off Android**: command invocations
short-circuit to safe defaults and the event stream is `Stream.empty()`, so
screens render with sane defaults instead of throwing `MissingPluginException`.
On iOS/web the router surfaces `UnsupportedScreen`.

### The native engine is a bound service run as a foreground service

There is **no separate `:as_process`** — the AccessibilityService
(`accessibility/DetoxoAccessibilityService.kt`) runs in the main process. On
connect it promotes itself with `startForeground(...)`
(`FOREGROUND_SERVICE_TYPE_SPECIAL_USE` on API 34+) behind an ongoing status
notification (channel `detoxo_protection_channel`, id `1125`). The OS re-binds
an enabled accessibility service automatically after boot;
`receivers/BootReceiver.kt` (re)arms the protection watchdog
(`receivers/WatchdogJobService.kt` — a 15-min JobScheduler check that posts a
"Protection stopped" notification when the service has been silently killed;
a rebind cannot be forced, so detect + notify is the ceiling). See
[12-analytics-notifications-resilience.md](12-analytics-notifications-resilience.md).

---

## Directory map

### `lib/`

```
lib/
  main.dart                     entry: DI → MultiBlocProvider → MaterialApp.router
  app/
    splash_screen.dart          the brand moment; calls runBootstrap, does not route
    bootstrap.dart              ordered, individually-guarded app-start work
    starter_rule_sync.dart      writes the first run's rule on the grant edge
    unsupported_screen.dart     iOS/web honest "runs on Android" state
    live_accent.dart            resolves + publishes the live accent (AccentScope)
  core/                         infra reused by 2+ features
    constants/                  app_constants (EngineTimings) · channel_constants
    di/                         injector.dart — get_it locator `sl`
    navigation/                 app_router.dart · routes.dart · app_gate.dart
    platform/                   platform_capabilities.dart (Android gate)
    platform_channels/          engine_channel.dart (MethodChannel/EventChannel wrapper)
    storage/                    local_store.dart (key-value)
    design_system/              Frozen Glass: tokens (generated) · theme · foundations · components
                                foundations: glass_container · glass_scaffold · motion · accent
    error/ utils/ widgets/      shared helpers + common widgets
  features/
    blocking/                   CORE: shared(spine) · engine · blocklist · plans
    content_counter/            core · bubble · home_content_counter · appearance
    limits/                     app_blocker · web_blocker · daily_limit
    access_protection/          PIN setup/lock/recovery
    monetization/premium/       entitlement (dev-unlock; no live billing)
    analytics/                  local block-event history
    permissions/                Android permission funnel
    onboarding/ settings/ dashboard/   presentation-only orchestration surfaces
    additional_feature/         app_feedback · showcase_view
```

### `android/app/src/main/kotlin/com/errorxperts/detoxo/`

```
MainActivity.kt                 FlutterFragmentActivity; wires the two channels
accessibility/
  DetoxoAccessibilityService.kt hot path: detect + block + count; status notification
channels/
  CommandHandler.kt             MethodChannel handler (Dart → native)
  DetoxoEventStream.kt          EventChannel stream handler (native → Dart)
engine/
  DetectionConfig.kt            parses Dart-pushed platforms_config.json
  ConfigStore.kt                SharedPreferences "detoxo_engine_prefs"
  ContentCounter.kt · ContentCounterStore.kt   decoupled counting + persistence
  WebBlockEngine.kt · BrowserUrlExtractor.kt    address-bar host blocking
  ServiceEventBus.kt · UsageLadder.kt   (UsageLadder: block screen only)
overlay/
  ContentCounterBubble.kt       WindowManager overlay bubble host (anchor, drag, edge-snap, tap = timer)
  DxTokens.kt · AccentResolver.kt   generated Frozen Glass tokens + the live-accent mirror
  bubble/                       BubbleView shell + model/envelope/look + six faces/*Face.kt
widget/
  ContentCounterWidgetProvider.kt · WidgetBitmapRenderer.kt   home-screen widget
admin/
  DetoxoDeviceAdminReceiver.kt  uninstall protection + lockNow (force-lock)
receivers/
  BootReceiver.kt               (re)arms the watchdog job (OS re-binds the a11y service)
  WatchdogJobService.kt         15-min "is protection alive?" check → "Protection stopped" notification
```

---

## Persistence & config at a glance

- **Dart preferences:** `lib/core/storage/local_store.dart` — a simple key-value
  store (not Hive/Drift/Room/ContentProvider). Secrets live in
  `flutter_secure_storage`.
- **Native state:** `SharedPreferences` file `detoxo_engine_prefs` via
  `engine/ConfigStore.kt` (settings/config the service reads cross-process) and
  `engine/ContentCounterStore.kt` (counter totals). Home-widget keys `cc_today` /
  `cc_total`.
- **Config is offline-first:** bundled `assets/config/platforms_config.json` +
  `assets/config/initial_config.json` (`AppConstants.bundledPlatformsConfig` /
  `bundledInitialConfig`). There is no live backend; a remote `ConfigRepository`
  is a documented swap-in.

Detailed treatment lives in the persistence and configuration docs.

---

## Source files

- `README.md`
- `pubspec.yaml`
- `lib/main.dart`
- `lib/app/splash_screen.dart`
- `lib/app/bootstrap.dart`
- `lib/app/starter_rule_sync.dart`
- `lib/core/navigation/app_gate.dart`
- `lib/app/unsupported_screen.dart`
- `lib/core/di/injector.dart`
- `lib/core/navigation/app_router.dart`
- `lib/core/navigation/routes.dart`
- `lib/core/constants/channel_constants.dart`
- `lib/core/platform_channels/engine_channel.dart`
- `lib/core/platform/platform_capabilities.dart`
- `lib/core/design_system/design_system.dart` (barrel)
- `lib/core/design_system/tokens/app_tokens.dart` (+ generated `app_tokens.g.dart`), `tokens/app_spacing.dart`, `tokens/app_motion.dart`
- `lib/core/design_system/theme/app_theme.dart`
- `lib/core/design_system/foundations/glass_container.dart`, `foundations/glass_scaffold.dart`, `foundations/motion.dart`, `foundations/accent.dart`
- `lib/core/design_system/components/` (`buttons`, `overlays`, `dialog`, `selection`, `toggle`, `inputs`, `variant_carousel`, `list_tiles`, `section_header`, `badges`, `cards`, `feedback`, `permission_card`, `menu_button`)
- `lib/app/live_accent.dart`
- `tool/design/tokens.json`, `tool/design/recipes.json`, `tool/design/gen_design_tokens.dart`, `tool/tokens_common.dart`
- `android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/DxTokens.kt` (generated), `overlay/AccentResolver.kt`
- `test/fixtures/accent_cases.json`
- `lib/features/dashboard/presentation/home_shell.dart`
- `lib/features/dashboard/presentation/dashboard_tab.dart`
- `lib/features/dashboard/presentation/widgets/blocker_section.dart`
- `lib/features/dashboard/presentation/widgets/blocker_tile.dart`
- `lib/features/` (feature tree: `blocking`, `content_counter`, `limits`, `access_protection`, `monetization/premium`, `analytics`, `permissions`, `onboarding`, `settings`, `dashboard`, `additional_feature`)
- `tool/check_boundaries.sh`
- `android/app/src/main/kotlin/com/errorxperts/detoxo/MainActivity.kt`
