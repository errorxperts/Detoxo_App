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
| App Blocker / Web Blocker / Daily limit / Blocker rules | Custom whole-app blocks (HOME bounce), web host matching, the daily reel limit and the schedule / time / open-limit rules ([27](27-rules-engine.md)) | ✅ All enforced natively |
| Access protection (PIN) | PIN setup/lock/recovery, biometric, retry lockout | ✅ (`local_auth` + secure storage) |
| Permissions funnel | Accessibility, overlay, notifications, usage access, battery exemption, device admin, notification access | ✅ (Android-only) |
| Premium / entitlement | Modeled; a local dev-unlock key is declared but has no UI ([11](11-monetization.md)) | ⚠️ No live Play Billing (swap-in) |
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
access_protection · analytics · blocking · catalog · content_counter · dashboard · help
limits · onboarding · permissions · protected_apps · settings · usage
additional_feature/app_feedback · additional_feature/app_upgrader · additional_feature/showcase_view
help/{faq, feature_tutorial, legal, report_issue, share_ideas}
```

The **blocking** context is the core bounded context and is itself sub-structured:

```
lib/features/blocking/
  shared/     domain (AppSettings, BlockTarget, enums, repo contracts)
              + data (models, repo impls) + shared SettingsCubit  ← the spine
  engine/     presentation only (ServiceCubit — live service status)
  blocklist/  presentation only (TargetsCubit + blocklist UI)
  plans/      domain (session-phase rules) + data (bundled content)
              + presentation (session dialogs, ConsciousCubit, ReelSessionCubit)
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
1. `WidgetsFlutterBinding.ensureInitialized()`, registers Manrope's licence, initialises
   Firebase (best-effort, `guardedSync`) and installs the Crashlytics error handlers, then
   sets transparent system bars.
2. `await configureDependencies()` — builds the service locator; then the telemetry
   `Bloc.observer` and `FirebaseServices.start` ([19](19-firebase-telemetry.md)).
3. Registers the global feedback action button, then `runApp(DetoxoApp())`.

`DetoxoApp` installs the app-wide Cubits with a `MultiBlocProvider`, each
resolving its repositories from the locator `sl`:

| Cubit | Resolves |
|---|---|
| `ServiceCubit`, `ConsciousCubit`, `ReelSessionCubit` | `EngineRepository` |
| `SettingsCubit` | `SettingsRepository`, `EngineRepository` |
| `TargetsCubit` | `ConfigRepository`, `EngineRepository` (+ `PerformanceService`) |
| `PermissionsCubit` | `PermissionRepository` |
| `PinCubit` | `PinRepository` |
| `ContentCounterCubit` | `ContentCounterRepository`, `BubbleRepository` |
| `CounterAppearanceCubit` | `CounterAppearanceRepository` |
| `BlockScreenStyleCubit` | `BlockScreenRepository` |
| `DailyLimitCubit` | `DailyLimitRepository` |
| `StreakCubit` | `StreakRepository` |
| `InsightsCubit` | `InsightsRepository`, `EngineRepository` |
| `RulesCubit` | `RuleRepository`, `DailyLimitRepository`, `UsageRepository`, `EngineRepository`, `BypassLedgerRepository` |
| `UnblockCubit` | `TemporaryUnblockRepository`, `BypassLedgerRepository`, `EngineRepository` |

`SettingsCubit` doubles as the app's appearance source: a `BlocSelector` on
`AppThemeMode` alone drives the theme (no other setting rebuilds the router), and a
`BlocListener` mirrors the vibration preference into `AppHaptics`. Two more listeners feed
`AppGate` (`onboarded`, `allRequiredGranted`), and a saved daily limit re-pushes the rules
snapshot (`RulesCubit.resync`). The tree then renders `AppResumeSync` →
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
  the content-counter repos, `FeedbackRepository`, …).

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

`HomeShell` holds the two tabs, **Today** (`DashboardTab`) and **Insights** (`AnalyticsTab`),
over the ground gradient. The tab bar is the static glass `AppTabBar` (Today
`Icons.dashboard_outlined` / `dashboard`, Insights `leaderboard_outlined` / `leaderboard`) in
the `GlassScaffold`'s `bottomBar` slot, which is what keeps floating toasts above it.
`_TabBarHost` floats it 30 above the bottom inset over a fade to `bgBottom` that reaches
`AppSpacing.xl` above the bar and never takes a touch, so the list under it keeps scrolling. The
bar never hides; nothing in the shell listens to scroll.

- **Analytics.** Tabs do not change the route, so a switch logs `screen_view` itself, under the
  **pre-rename names** `'Dashboard'` / `'Activity'`: the series run on unbroken
  ([19](19-firebase-telemetry.md)). A tap on the current tab does nothing.
- **`/home?dashboard=<n>`** (a Plan widget tap, EVO-073) switches to Today whenever `n` changes,
  even from Insights.
- **The sidebar** is the end drawer `AppDrawer` (`widgets/app_drawer.dart`), opened by each tab
  header's Menu button (`TabHeader(onMenu:)`, a bare sidebar glyph). It is a `sheet` surface inset 10 from the
  screen edges: the "Detoxo" title and a close button, one `PanelGroup` of flat `GlassListTile`
  rows (Daily limit, Appearance, PIN lock, Settings, Help & support) and
  `v<AppConstants.appVersion>` at the foot. It has **no Activity row**, and no blocker rows: the
  numbers are the Insights tab and the blockers sit on Today. The pushed `/analytics` route
  stays for deep links (a home-widget tap). Each row closes the drawer, then pushes.
- **Hosts.** `UpgradeGate` (the automatic update check, [21](21-app-upgrader.md)) wraps the
  scaffold, and `buildFeatureShowcaseScope(onSeen:)` (the tour host; finishing or skipping the
  tour sets `hasSeenFeatureShowcase`) wraps the body. The body's `SafeArea` keeps a top minimum of
  `headerTop − inset`, so with the lists' own `inset` the tab header sits 54 below the screen
  top, or `inset` below a taller status bar.
- **`tabBuilder`** is a `@visibleForTesting` seam that swaps the tab bodies, so
  `test/home_shell_test.dart` pumps the shell without every cubit the real tabs read.

`Routes.blocklist` used to register a *second* `HomeShell` on `/blocklist`,
which is how the two tabs came to share one navigation stack; that constant is
gone and `/home` is the only registration.

**Why no `StatefulShellRoute.indexedStack`, and no per-tab deep link.** Both tabs
are leaves — every sidebar destination pushes *above* this shell — so there is no
per-tab back stack for an indexed stack to preserve. It would, however, keep both
tabs alive at once, and `_tab()` deliberately builds **only the active one**. A
`?tab=` query seam was briefly added and then removed: no caller anywhere in the app
produced such a URL and the gate's redirect returns a bare `Routes.home`, so the
parameter was provably never non-default. `?dashboard=` is the one seam, and it
only ever selects Today; add a tab parameter the day something links to Insights.

`DashboardTab` (the **Today** tab) is one short page built whole: a `SingleChildScrollView`
over a `Stack`, so every section mounts once and rises in once with `.entrance()`. Behind the
content, `AmbientLights` fills the stack (`Positioned.fill`, its top pulled up
`headerTop − inset` so the two lights sit where V02 measures them from the screen top) and
scrolls with it. In front, a column padded with `TabHeader.listPadding` (gutter 20, inset 8 on
top, 132 plus the bottom inset below): `TabHeader('Detoxo')` → 14 → `_TodayLive` (the
`TimeLeftRing` with its reels / streak line, 20, the `ModeCard`) → 32 → `BlockerSection`
(rising one stagger later; it ends with the `BlockerRulesRow`). The house split is that a
section needing cubits stays inline in `dashboard_tab.dart` as a private `_Xxx` widget while its
presentational half lives in the design system or `presentation/widgets/`. (Service status is
surfaced by the permission gate / setup screen.)

**Every word and state branch lives in one pure file**, `presentation/today_copy.dart`
(tested by `test/today_copy_test.dart`):

- `modeIndex(settings, pauseLive:)` is the lit mode, in the card's order Block All, Conscious,
  One Reel, Pause, Unblock. A live Pause (or a `paused` plan) is 3; `oneReel` is 2 at an
  allowance of 1, else 4 (Unblock, an N-reel unblock); `curious` is 1; `blockAll` is 0.
  `LiveAccent` maps the same index to the accent (2 One Reel; 3 and 4 the Pause accent).
- `ringFace(...)` returns a `RingFace` record; the first match wins:
  - a live Pause: "Reels allowed" in accent text, mm:ss left, "of a 10 min break";
  - an N-reel unblock: the reels left, "of 5 reels";
  - counting off: "—" and "Counting is off", no arc;
  - no limit: "Today", the time so far, "No daily limit", no arc;
  - over: "0m" and "45m over your 3h limit";
  - else the time left, "45m of 3h used".

  Before the first counter read the placeholder reads normally.
- `modeCopy(...)` is the mode card's description, or null. With the master switch off it reads
  "Blocking is off" / "Turn it on in Settings"; otherwise nothing for Block All (the row stays
  closed), "Conscious mode" with the
  bank ("Spending banked time, 04:12 left", "04:12 banked to spend" or "Earning 1 min for every
  10 min away"), "Reels allowed" with "Blocking resumes in 09:42" or "3 reels left, then blocked
  again", or "One reel left".
- `blockerStatus(...)` gives each blocker tile its status.

**Taps.**

- The ring has no button; every mode change is a ModeCard option:
  - Block All calls `setPlan(blockAll)` directly; this also ends a Pause or a reel session.
  - Conscious opens `SessionDialogs.showConscious`: the intro, or the live sheet when it is on.
  - One Reel is direct (the user dropped its confirm, 2026-10-23): `setOneReel(count: 1)`,
    then the toast "One reel unblocked" with **Undo** (blocks now).
  - Pause opens `SessionDialogs.showPause` (By time).
  - Unblock (the tinted `iconReelCount`) opens `SessionDialogs.showReels` (By reel count).
- A repeat tap on the lit Block All does nothing; on the lit One Reel, Pause or Unblock it blocks
  now: `resumeNow()` during a Pause, else `setPlan(baseMode)`, with no confirm, since it only
  makes blocking stricter.
- The options are feature-tour steps 0–4, through `ModeCard.decorateOption` and `showcaseTarget`.

Rebuild/state notes on Today:

- `_TodayLive` owns the only Timer on Today: a 1 Hz ticker, running only while
  `isPauseContractLive`, because a Pause's time left falls without a cubit emit. Conscious
  self-emits each second; `_TodayLive` `select`s `ConsciousCubit` only while Conscious is lit.
- The streak `observe` runs post-frame, and only once the counter and the limit are read and
  counting is on, so an unmeasured day never counts as a day under the limit.
- `TimeLeftRing` is keyed on "counter and limit read", so its one-time count-up replays on the
  real numbers instead of finishing on the placeholder.
- `test/today_screen_test.dart` covers the composition and its gaps, every tap above, the
  ticker, the tour targets, the streak guard, and 2× text on a 360 dp phone in both themes.

`BlockerSection` (`presentation/widgets/blocker_section.dart`) is the exception
that owns its own data. It lays out the "Blockers" title with "N of 2 on", the
`ActiveUnblocksCard` (only while something is allowed), the App Blocker / Web Blocker pair as two
design-system `BlockerTile`s (`iconAppBlocker` / `iconWebBlocker`; feature-tour steps 4 and 5,
spotlit at `AppRadius.card`), then the `BlockerRulesRow` ([27](27-rules-engine.md)). Both blocker
cubits are screen-scoped — created inside `BlocProvider`s in `app_block_screen.dart` /
`web_block_screen.dart` — so there is nothing to watch from Today. The section resolves
`AppBlockRepository` and `WebBlockRepository` (and the two web protections) through `sl` in a
try/catch that keeps the last good lists, and re-reads them when the user pops back from either
blocker screen, so the tiles never go stale. The master switch and the built-in feeds come live
from `SettingsCubit` / `TargetsCubit`.

- **App Blocker** stacks the custom locks that are on (every lock when nothing is), then the
  installed feeds that are on, one icon per package (Instagram's Reels and Stories count as one
  app): the first three, "+N", and "N apps".
- **Web Blocker** stacks the sites that are on (every site when none is) as `SiteLetter`s (brand
  colour, else `tileWeb`), "N sites", and "Protection on" when a web protection is on.
- **Status** is `blockerStatus(total:, enabled:, masterOn:)` from `today_copy.dart`: nothing set
  up → Not set up; master off or nothing on → Paused; else On. A web protection counts as an
  entry that is on.

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
| `sheet` / `sheetOut` / `scrim` | 450 / 300 / 300 ms | `easeOutCubic` (out: flipped) / `ease` | a bottom sheet in, out, and its scrim |

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
one final rounding; the block screen reads it through `AccentResolver.forWall`,
[25](25-block-screen.md) §6) and the fixture's Python model compute the same ARGB: `test/fixtures/accent_cases.json` is read by both `accent_test.dart` and
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
lets the accent paint six things only — the ring arc and its glow, the mode card's chip and picked icon,
the mode icons, the accent pill tint (the block screen's primary action), the tab lens. On Today the `TimeLeftRing`, the
`ModeCard` and the `AmbientLights` read it; the shell's tab lens does too.

#### Components — `components/`

| Area | Components |
|---|---|
| Buttons (`buttons.dart`) | `PrimaryButton` — the spec **soft button**: a 54 px pill on the 145° `buttonFrom → buttonTo`, the label in `button` / `ink`, no accent, `.45` when disabled, `expand` / `icon`. Its `shadowButton` shows only on the bare ground: inside any `GlassContainer` (cards, sheets, dialogs, the tour card) it sits flat, as with `flat: true` (empty-state actions) — no elevation inside elevation. `SecondaryButton` — an `ink2` label with no surface on a 48 dp target; `destructive: true` sets it in `accentText(over)`, never a red fill. `LiquidPill(tint:)` — the spec **accent pill**: 44 px, `tint` at `kPill` under the `pillHi → pillLo` sheen and `pillEdge`, a `tint` glow at `kPillGlow`. `GlassFab` — a floating glass pill, glyph + label. `GlassIconButton` — a 44 px glass circle, 22 px ink icon, 48 dp target, a `Tooltip` carrying its label; `bare: true` drops the circle and keeps the rest (the tab header's Menu). `InfoButton(message)` — a `GlassIconButton` that opens the message in a sheet |
| Overlays (`overlays.dart`, `dialog.dart`) | `GlassBottomSheet.show({child, title, dismissible, glow})` — the spec **SHEET**: a `sheet` surface inset 10 px from the edges, padded 0 / 22 / 22, a 40×5 grabber in a 30 px band, an optional `titleSheet` title, over the **scrim** (the backdrop blurred 8 at saturate 1.2 under a radial `scrim` dim, `120% 70% at 50% 100%`, stops `kScrim0/60/100`). It slides in 450 ms on `easeOutCubic` and out 300 ms, the scrim fades 300 ms; neither moves under Reduce Motion. While it moves the blurs stay cheap: the scrim scales its blur, lift and dim with its fade (no opacity layer over a backdrop filter), and the sheet's own blur (`GlassContainer(backdrop:)`, flipped through `BackdropFilter.enabled`, so the content keeps its state) switches on once it settles. Dragging the grabber or title down past **110 px** closes it, a shorter drag springs back on the press curve; `dismissible: false` locks the barrier, the drag and back. `glow` paints a 340×260 light behind the top edge. `AppDialog.show` / `.confirm` render **in the sheet**: an optional neutral `IconBadge`, a centred `titleSheet`, a `message` and/or `content`, the actions stacked full-width with the confirm on top. `GlassToast.show(context, message, tone:, action:)` — a glass pill with the tone's glyph (success: the spec check `Glyph`) and the message in `ink` (never a tone colour), an optional inline `action` such as **Undo**; it stays **4 s**, **6 s** with an action, **10 s** while a screen reader or switch access navigates, and drops its slide under Reduce Motion. While a sheet or dialog covers the page (the caller's route is a popup or not current) it floats on the root overlay under the status bar instead of as a SnackBar, which would sit beneath the sheet |
| Selection & input (`selection.dart`, `toggle.dart`, `inputs.dart`, `variant_carousel.dart`) | All **OPTION and accent-free**. `GlassSegmented` — a `fillQuiet` track with a solid `optionBase` chip that slides on the chip curve plus `Squish`; the picked label goes `ink2` → `ink` behind a 16 px check; tap, scrub along the track, or focus each segment as one radio. `AppChip` — `fillQuiet`, selected `optionBase` + a check, 48 dp floor; `ChipRail` lays them in two scrolling rows. `AppToggle` — 48×28: on `statusOn` with the `knob`, off `fillQuiet` with a hairline rim and an `ink3` thumb. `AppSearchField` — a `fillQuiet` pill with a focus ring. `VariantCarousel` — OPTION cards, the pick solid `optionBase` with an ink check badge |
| Spec art (`dx_icons.dart`) | `Icon3d(asset, size:, accentTint:, selected:)` — a spec 3D icon; `accentTint` turns it to the live accent through `accentIconFilter`, idle at `iconSaturateOff` / `iconOpacityOff`. `Glyph(svg, size:, color:)` — a spec SVG glyph drawn `srcIn`, `ink` by default. `DetoxoLogo(height:)` — the near-white `detoxo_logo.png` at 100:192, blended (`modulate`) into brand-main in Light and left white in Dark (`DetoxoLogo.tintOf`; the native wall mirrors it), over its `logoGlow` drop-shadows (Dark σ 8; Light a σ 1 contour plus a σ 10 glow). All are decorative unless given a `semanticLabel`. The art: the 3D icons and logo in `assets/images/icons/`, the glyphs in `assets/svg/` ([14](14-flutter-package-map.md) §9) |
| Lists & status (`list_tiles.dart`, `section_header.dart`, `badges.dart`) | `GlassListTile` — a flat row (56 min, `label` over a two-line `subhead`), the 18 px `ink3` chevron `Glyph` when tappable with no trailing (drawer rows and the Blocker rules row use it too), a check when `selected: true`; it is its own panel only when standalone. `PanelGroup` — the section idiom: rows in **one** panel split by inset hairlines. `AppToggleTile`. `SectionHeader(label, note:)` — the uppercase `eyebrow` (caption, 1.6 tracking, `ink2`), `section` 32 above and 12 below, a header to TalkBack. `Pill` — a **status label**: an 8 px dot in `toneColor` (or `dotColor:`) or an icon in `toneText`, then the word in `subhead` `ink2`; no fill or border. `toneColor` / `toneText` map an `AppTone` to its dot and its 4.5:1 text colour. `AppBadge` — the "+N" quiet pill |
| Cards & feedback (`cards.dart`, `feedback.dart`, `permission_card.dart`) | `GlassCard` — a panel, optionally tappable; `flat: true` drops its drop shadow and keeps the inset edge light (every Insights card; `GlassContainer(flat:)` underneath); `StatCard` / `StatCardPair` (neutral figures, no trend arrows), a neutral `IconBadge`. `ProgressRing(progress:, size:, palette:, child:)` — the spec ring in its materials, every measure the 300 px ring scaled to `size` (stroke 24·size/300): the groove, the track, a three-stop arc of `palette` (default `brand`) with a blurred copy at `kArcGlow`, the knob with its `kHalo` halo and `knobShadow`, and the centre disc with its `discWash`; a null `progress` draws no arc and no knob. `ProgressBar`, `LoadingState`, `EmptyState` (no loop), `AppReveal`, `NoticeLine`. `PermissionCard` — a neutral badge, the title, the why and the status in words (On / Needs access / Checking…), its own panel only when not on a surface |
| Confirm (`confirm_sheet.dart`) | `ConfirmSheet.show(context, icon:, title:, message:, content:, action:, cancel:, tone:, waitSeconds: 5) → Future<bool>` — the one confirm for actions that weaken protection, in the sheet: an 88 well with a 6 px tone halo and a 4 px wait ring, a `titleSheet` title (≤ 2 lines), a message (≤ 3 lines), optional content, then a 64 px track and a 56 knob. It waits `waitSeconds` (1–30; `AnimationBehavior.preserve`, so Reduce Motion never shortens it) showing "Take a breath…"; the ready knob shows tone chevrons and nudges once. A release at ≥ 88 % ("Release to confirm") shows a check and "Confirmed", then closes true after 1 s; an earlier release springs back; a tap hints "Slide all the way →". During the wait the knob reads "X, available in N seconds" and is disabled; afterwards TalkBack, Enter or Space confirm. The cancel is a full-width text `SecondaryButton`; cancel, barrier, back and drag return false. Callers commit, then toast. `ConfirmSheet.iconSize` (58) sizes the callers' icon; `ConfirmSheet.waitKnob(t)` is the waiting-knob recipe (Light `knob` @ 55 %, Dark `lerp(trackTo, knob, .18)`) |
| Session (`session_sheet.dart`) | `SessionSheet.show(context, kind:, min:, max:, initial:, picks:, note:, startLabel:, onStart:)` — the **Session blocker** (Pause and N-reel unblocks) on `GlassBottomSheet` with the static brand glow, 434 tall for both kinds: a 40 px icon, "Session blocker" over "By reel count" / "By time", a 32 px `control` close. By reel count: a −/+ stepper (44 `control` circles with `accentText(brand)` glyphs, `number` over a REEL(S) eyebrow, hold to repeat 420 ms × .78 down to 60 ms, .35 and disabled at a bound, "One fewer reel" / "One more reel", a live-region value). By time: one 160 px `SleekCircularSlider` (the old Pause picker's ring: 240° open at the bottom from 150°, an 8 `control` track, a 12 bar on the dial's three brand stops, an 8 white handle, no shadow, no easing) around `numberLg` over `eyebrowLg`; drag rounds to whole minutes while the handle follows the finger; arrows ±1, PgUp/PgDn ±5, Home/End; a slider node "Session length", since the package has no semantics of its own. Four quick picks on a `control` card with a sliding `controlOn` chip (+ `Squish`), hidden on a custom value. A note line, then the 52 px start pill: `onStart` true → the started colours, "Session started" with a drawn check, held by `PopScope`, closes after 1.1 s; false → stays. Reduce Motion drops the slide, squish, number bump and check draw |
| Today ring (`time_left_ring.dart`) | `TimeLeftRing(eyebrow:, value:, format:, sub:, progress:, live:, reels:, streak:)` — the spec hero on `ProgressRing` in the live accent: the uppercase eyebrow (`ink2`, or accent text in a Pause), the value in `number` and the `body` line, the face scaled down inside the disc. While a Pause or reel session is `live` the ring is the pre-migration countdown gauge instead: a read-only `SleekCircularSlider` (240° open at the bottom, an 8 `control` track, a 12 bar in the accent main → deep → main, no handle) draining with the time or reels left, easing between ticks except under Reduce Motion, the reels / streak line 22 below. Value, counts and arc count up once per mount over `glide`; later changes snap; nothing moves under Reduce Motion; 210 px (30 % under the spec's 300; `ProgressRing`'s default stays 300) unless its box is narrower. `AmbientLights` — Today's two accent lights (main at `kAmb`, 380 px at (5, 45), raised with the ring's centre; deep at `kAmbDeep`, 400 px at (120, 560)), mounted with `Positioned.fill` behind the scroll content |
| Today (`mode_card.dart`) | `ModeCard(options:, selectedIndex:, onSelected:, title:, detail:, decorateOption:)` — the spec **MODE CARD**, kept calm: one solid `option` surface in plain `optionBase` (radius 28, inset 8, no shadow or border). The five options on Today (Block All, Conscious, One Reel, Pause, Unblock) are each 76 wide (wider when all fit), 8 apart, in a horizontal scroll clipped to the inner radius (grown 5 px for the focus ring); a new pick scrolls into view (detail curve; a jump under Reduce Motion). Each option is a 34 px `Icon3d(accentTint:)` — accent and vivid at 1.08 when picked, neutral grey (`Icon3d.idleFilter`, greyscale at .8) at .94 idle, .88 while pressed — over a verbatim `caption` label (`ink2`; picked `accentText` in Light, `ink` in Dark). Behind the pick a radius-20 chip at `kChip` is an `AnimatedPositioned` on the chip curve plus `Squish`, fading out with no pick. With a pick and a `title`, a hairline and a row (accent dot, `title`, `detail`) open on the detail curve; Block All passes none. Each option is one radio (`AppPressable` selected + `inMutuallyExclusiveGroup`, focus ring) in a "Blocking mode" group and reports every tap, the picked one too; `decorateOption` wraps each one for the tour |
| Blockers (`blockers.dart`) | `BlockerTile` — a `tile` surface for App / Web Blocker: a 3D icon, the name, the status as dot + word (On / Paused / Not set up), the first few apps (or `SiteLetter`s) with a "+N" badge, or a note; `BlockerRulesRow` — the 64 px "Blocker rules" panel row with the count on and what happens next (`RuleSummary.nextEvent`, 12-hour forms such as "Next: Bedtime at 11 PM") and the chevron `Glyph`. Today's `blocker_section.dart` lays out "Blockers" + "N of 2 on", `ActiveUnblocksCard`, the tile pair, then the rules row |
| Navigation (`navigation.dart`) | `AppTabBar(items:, current:, onSelect:)` — the 208×64 glass bar (radius 32, padding 6) with a half-width accent **lens** (`lensHi → lensLo` over main @ `kTab`, `lensEdge`, a main @ `kTabGlow` glow) that slides on the lens curve with a `Squish`; the current tab's filled icon in accent text at 1.08, its label in accent text (Light) or `ink` (Dark, where accent text misses 4.5:1 on the lens), others `ink2`; text scale clamped at 1.3; still under Reduce Motion. `TabHeader(title, onMenu:, actions:)` — `titleLg` (28/34, the recipe `title-lg`) ink, actions and the Menu button (a bare `sidebar` glyph, no glass circle), at `max(54, safe top + 8)`; `TabHeader.listPadding` is gutter 20, 8 on top, 132 + inset below |

#### Where the ConfirmSheet, the Session sheet and Undo are used

**ConfirmSheet** guards every action that weakens protection — 11 call sites (One Reel left
the list on 2026-10-23: it unblocks a single reel at once, with Undo on its toast). Each one awaits
`true`, then commits, then toasts only once the state shows the commit landed; a failed commit
toasts its own error, and a cancel changes nothing.

| Action | Where | Tone · icon | Title · slide | Toast |
|---|---|---|---|---|
| Allow an app · a site · the wall fallback · an override | `showUnblockDurationSheet` (`limits/unblock`), called from `app_block_screen.dart`, `web_block_screen.dart`, `pending_unblock_listener.dart`, `override_tile.dart` | caution · `iconAppBlocker` / `iconWebBlocker` / `iconBlockerRules` | "Unblock {app}?", "Unblock {site}?", "Unblock this app?", "Lift {rule} for a while?", with 5 / 15 / 30 / 60-minute chips | "{app} unblocked for 15 min", "Unblocked for 15 min", "{rule} lifted for 15 min" ([31](31-locked-rules-and-unblock.md)) |
| 18+ filter off · sites of blocked apps off | `web_protection_screen.dart` | critical · `iconWebBlocker` | "Turn off the 18+ filter?" · "Unblock sites of blocked apps?" · "Slide to turn off" | "18+ filter off" · "Sites of blocked apps unblocked" |
| Blocking off (master switch) | `settings_screen.dart` | critical · `iconBlockAll`, tinted | "Turn off blocking?" · "Slide to turn off" | "Blocking is off" |
| PIN lock off (the Settings switch and the setup screen's None) | `confirmPinOff` in `pin_gate.dart` | critical · `DetoxoLogo` | "Turn off PIN lock?" · "Slide to turn off" | "PIN lock turned off" |
| Reset app data | `settings_screen.dart` | critical · `DetoxoLogo` | "Reset app data?" · "Slide to reset" | none (the splash is the feedback) |
| Delete a rule | `rule_editor_screen.dart` | critical · `iconBlockerRules` | "Delete {rule}?" · "Slide to delete" | "{rule} deleted", then pop |

- **PIN first.** Where a PIN guards the action (blocking off, PIN off, reset) the order is the PIN
  (`requirePin(context, PinScope.settings)`, or the setup route's `PinGuard` for None), then the
  sheet, then the commit ([08](08-pin-lock-recovery.md) §9). The override asks for its reason
  first and has no PIN, by design.
- **Switches stay bound to state**, so a cancelled PIN or sheet snaps them back. Turning anything
  back on is direct, with no sheet.
- `AppDialog.confirm` remains only for asks that weaken nothing: "Set a PIN first" (Settings) and
  "Lock this rule?" (the rule editor).

**Session sheet** — Pause and N-reel unblocks start here, with no wait and no slide
([05](05-plans-pause-conscious.md) §9). The `ModeCard`'s **Pause** opens `SessionDialogs.showPause`
**By time**: 1–10 min, default 5, picks 1 · 3 · 5 · 10. The `ModeCard`'s **Unblock** opens
`SessionDialogs.showReels` **By reel count**: 1–20 reels, default 10, picks 5 · 10 · 15 · 20. The
bounds live in `SessionDefaults`, and native clamps a reel allowance to 1..20 as well. Neither sheet
has a switch inside.

**Undo toasts** — switching a target off stays one tap; once the state shows it landed, a
`GlassToast` with an inline **Undo** confirms it. Undo re-resolves the target at tap time and does
nothing if it is gone or already back. Turning anything on shows no toast.

| Switch off | Where | Toast | Undo |
|---|---|---|---|
| A custom app lock (swipe Unblock) · swipe Remove | `app_block_screen.dart` | "{app} unblocked" · "{app} removed" | toggle it on · re-insert it ([06](06-app-and-web-blocker.md)) |
| A built-in feed | `app_block_screen.dart` | "{feed} unblocked" | `togglePlatform(id, enabled: true)` |
| A site · swipe Delete | `web_block_screen.dart` | "{site} unblocked" · "{site} removed" | `toggleEntry` · `restoreEntry` |
| A popular-site chip | `web_block_screen.dart` | "{site} unblocked" | `togglePopular` |
| A rule | `rules_screen.dart` | "{rule} off" | `setEnabled(id, enabled: true)` ([27](27-rules-engine.md)) |

**Removed in the Frozen Glass sweep (M12)**, each once nothing used it: `adaptive/`
(`AdaptiveSlider`, `PlatformAdaptive`; sliders are the themed Material `Slider`) with
`cupertino_native`; `foundations/animated_icons.dart` (`AppAnimatedIcon`, `AppIcon`,
`AnimatedIconController`), `AnimatedIconButton` and `EmptyState.animatedIcon` with
`not_static_icons`; `AppCard`, `TrendDelta` (`StatCard.trend`), `SectionCard`
(`core/widgets`), `AppToggleTile.locked` / `onLockedTap`, `GlassSegmented`'s
`selectedIndex: -1`, `AppInsets.screenH`, `AppRadius.sm` / `xl` / `brSm` / `brMd`,
`AppDurations.instant`, `AppCurves.gentle`; `InfoBanner` (`daily_limit_screen.dart`) and
`CountdownCubit` (`blocking/plans`); and the old logo files in `assets/images/`
([14](14-flutter-package-map.md)).

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
`mode_card_test`, `confirm_sheet_test`, `session_sheet_test`, `time_left_ring_test`,
`navigation_test`, `app_icon_avatar_test`
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
    services/                   Firebase telemetry (analytics, crash, performance)
    storage/                    local_store.dart (key-value)
    design_system/              Frozen Glass: tokens (generated) · theme · foundations · components
                                foundations: glass_container · glass_scaffold · motion · accent
    error/ utils/ widgets/      shared helpers + common widgets
  features/
    blocking/                   CORE: shared(spine) · engine · blocklist · plans · block_screen
    content_counter/            core · bubble · home_content_counter · appearance
    limits/                     app_blocker · web_blocker · daily_limit · rules · unblock · streak
    access_protection/          PIN setup/lock/recovery
    protected_apps/             apps Detoxo never touches
    catalog/ usage/             the app catalog + the usage-stats layer
    analytics/                  local block-event history + insights (the Insights tab)
    permissions/                Android permission funnel
    help/                       Help & support hub, FAQ, tutorials, share ideas, legal
    onboarding/ settings/ dashboard/   orchestration surfaces (dashboard = the Today tab)
    additional_feature/         app_feedback · app_upgrader · appearance · showcase_view
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
  ServiceEventBus.kt
overlay/
  ContentCounterBubble.kt       WindowManager overlay bubble host (anchor, drag, edge-snap, tap = timer)
  BlockScreenOverlay.kt · BlockScreenRenderer.kt · QuoteWall.kt · WallButtons.kt · SlideToConfirmView.kt
                                the block screen (one Frozen Glass layout, native wait + slide; [25])
  NudgeOverlay.kt               the soft nudge card ([30])
  FrozenGlass.kt · DxTokens.kt · AccentResolver.kt   the native kit, generated tokens, the live accent
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
- `lib/core/design_system/components/` (`buttons`, `overlays`, `dialog`, `selection`, `toggle`, `inputs`, `variant_carousel`, `list_tiles`, `section_header`, `badges`, `cards`, `feedback`, `permission_card`, `dx_icons`, `confirm_sheet`, `session_sheet`, `time_left_ring`, `mode_card`, `blockers`, `navigation`)
- `lib/app/live_accent.dart`
- `tool/design/tokens.json`, `tool/design/recipes.json`, `tool/design/gen_design_tokens.dart`, `tool/tokens_common.dart`
- `android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/DxTokens.kt` (generated), `overlay/AccentResolver.kt`
- `test/fixtures/accent_cases.json`
- `lib/features/dashboard/presentation/home_shell.dart`
- `lib/features/dashboard/presentation/dashboard_tab.dart`, `presentation/today_copy.dart`
- `lib/features/dashboard/presentation/widgets/blocker_section.dart`, `widgets/app_drawer.dart`
- `lib/features/blocking/plans/presentation/widgets/session_dialogs.dart`, `lib/features/blocking/plans/domain/entities/session_defaults.dart`
- `lib/features/access_protection/presentation/pin_gate.dart` (`confirmPinOff`), `lib/features/limits/unblock/presentation/widgets/unblock_duration_sheet.dart`
- the other ConfirmSheet and Undo call sites: `lib/features/settings/presentation/settings_screen.dart`, `lib/features/limits/web_blocker/presentation/{web_block_screen,web_protection_screen}.dart`, `lib/features/limits/app_blocker/presentation/app_block_screen.dart`, `lib/features/limits/rules/presentation/{rules_screen,rule_editor_screen}.dart`, `lib/features/limits/rules/presentation/widgets/override_tile.dart`, `lib/features/limits/unblock/presentation/widgets/pending_unblock_listener.dart`
- `assets/images/icons/`, `assets/svg/` (the spec 3D icons and glyphs; [14](14-flutter-package-map.md) §9)
- `lib/features/` (feature tree: `blocking`, `content_counter`, `limits`, `access_protection`, `protected_apps`, `catalog`, `usage`, `analytics`, `permissions`, `help`, `onboarding`, `settings`, `dashboard`, `additional_feature`)
- `tool/check_boundaries.sh`
- `android/app/src/main/kotlin/com/errorxperts/detoxo/MainActivity.kt`
