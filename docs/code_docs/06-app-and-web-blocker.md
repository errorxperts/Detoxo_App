# App Blocker & Web Blocklist

Two sibling features under `lib/features/limits/` that let the user block whole
apps and distracting websites:

- **App Blocker** (`limits/app_blocker`) — a user-managed list of whole apps to
  lock, plus a management surface that also drives the curated built-in feed
  toggles.
- **Web Blocklist** (`limits/web_blocker`) — a searchable website blocklist
  (custom domains + one-tap popular sites), two category toggles (adult content,
  "web versions of blocked apps"), and a live stats dashboard.

Both follow the feature-first Clean Architecture used across Detoxo
(`data` / `domain` / `presentation`, Cubits, `get_it` locator `sl`, persistence
through `lib/core/storage/local_store.dart`). The `limits` public barrel
(`lib/features/limits/limits.dart`) re-exports only `domain/` symbols — the
entities, repository contracts and the two sync helpers (`syncAppBlocklist`,
`syncWebBlocklist`) — other features never reach into `data/` or
`presentation/`.

> **Enforcement at a glance.** Both are natively enforced. The Web Blocklist is
> enforced by the native `WebBlockEngine` (address-bar host read → back press).
> The App Blocker's enabled packages are pushed to the engine via
> **`pushAppBlocklist`** (`syncAppBlocklist`), and the accessibility service
> bounces any blocked app **HOME** the moment it's foregrounded (see
> [Native enforcement — custom whole-app blocks](#app-block-native)). The Web
> Blocklist can additionally *derive* website rules from enabled App Blocker
> apps (see [App→domain derivation](#appdomain-derivation)). Per-entry
> `lockAction` / `dailyLimitMinutes` remain **unused natively** — every
> whole-app block acts as HOME-bounce; per-entry actions are still future work.

---

## Part A — App Blocker

### Entity: `AppBlockEntry`

`lib/features/limits/app_blocker/domain/entities/app_block_entry.dart`

An `Equatable` value object for one fully-blocked app.

| Field | Type | Notes |
|---|---|---|
| `packageName` | `String` | Identity; unique within the list. |
| `appName` | `String` | Friendly label (falls back to the package). |
| `enabled` | `bool` | Default `true`. |
| `lockAction` | `AppLockAction` | `OVERLAY` / `CLOSE_APP` (default) / `LOCK_SCREEN`. **Unused natively** — enforcement is always a HOME bounce today. |
| `dailyLimitMinutes` | `int` | Default `0`. Persisted but **unused anywhere** (no producer, no consumer — the sibling `daily_limit` feature never reads it); dropping it is a schema touch. |

`AppLockAction` is defined in the shared enums
(`lib/features/blocking/shared/domain/entities/enums.dart`); each variant carries
a wire token, and `fromWire` falls back to `closeApp`. JSON round-trips via
`fromJson` / `toJson`; there is no separate `toWire` because the entry is not
pushed to the channel directly — only the enabled `packageName`s cross the wire
(see the sync below).

### Repository & persistence

- Contract: `app_blocker/domain/repositories/app_block_repository.dart` — just
  `load()` / `save(entries)`.
- Impl: `app_blocker/data/repositories/app_block_repository_impl.dart` —
  JSON-encodes the list into `LocalStore` under `StoreKeys.appBlocklist`
  (`"app_blocklist"`). Simple key-value; no Hive/Room/ContentProvider.

### Cubit

`app_blocker/presentation/app_block_cubit.dart` — `Cubit<List<AppBlockEntry>>`.
Straight CRUD over the repository:

- `load()` — hydrate from storage. A corrupt blob is **logged, not thrown**
  (the screen fires `..load()` unawaited; `syncAppBlocklist` aborts its own
  push on the same failure, so native keeps its last-good set).
- `add(packageName, appName)` — validates and returns an `AppBlockAddResult`
  (`added` / `invalid` / `sensitive` / `duplicate` / `failed`); defaults
  `appName` to the package when blank. See the screen's toast contract below.
- `toggle(index, enabled:)` / `removeAt(index)`.
- `restore(entry, index)` — the screen's Remove Undo: re-inserts the removed
  entry at its old index with its fields intact; a no-op (`false`) once its
  package is listed again.
- `_commit(entries)` — `emit` then `save` (optimistic UI, persist after). A
  **failed save reverts** the emit and returns `false` (so `add` reports
  `failed` and nothing is pushed) — the same contract as `WebBlockCubit`;
  on success it fires the optional `onChanged` callback fire-and-forget.

No engine push happens here directly — the cubit takes an optional
`onChanged` callback, which the screen wires to **`syncAppBlocklist` +
`syncWebBlocklist`** (fire-and-forget) so both the native whole-app blocklist
and the app-derived web rules update the moment the list changes. A failed sync
never blocks the app-blocker UI.

### Sync to native — `syncAppBlocklist`

`app_blocker/domain/app_block_sync.dart` (exported via the `limits.dart`
barrel) is the single push path, the whole-app twin of
[`syncWebBlocklist`](#pushall):

1. `AppBlockRepository.load()` — persisted state, not cubit state.
2. `EngineRepository.pushAppBlocklist([...])` with the `packageName` of every
   **enabled** entry (disabled entries are simply omitted).

Same fail-safe contract as `syncWebBlocklist`: the body is try/caught →
`AppLogger.e`, and a **failed load aborts the push** — native keeps enforcing
its last-good persisted set, and a corrupt Dart store can never push `[]` and
wipe it. Its three callers:

1. `AppBlockCubit.onChanged` (wired in `app_block_screen.dart`) — every
   add/toggle/remove.
2. The splash `_bootstrap()` (fire-and-forget) — repairs Dart→native drift at
   every cold start.
3. The resume re-sync heavy leg (`lib/app/app_resume_sync.dart`, throttled to
   once per 15 min).

**Wire + native side.** `EngineRepository.pushAppBlocklist` →
`EngineChannel.pushAppBlocklist` → method `pushAppBlocklist`
(`{packages: List<String>}`). `CommandHandler.kt` handles it exactly like
`pushProtectedApps`: an absent/malformed arg is a **no-op, never a wipe**
(clearing requires an explicit empty list), and an unchanged set skips both the
prefs rewrite and the service refresh. The set persists in
`ConfigStore.blockedAppPackages` (`app_blocklist_packages` StringSet in
`detoxo_engine_prefs`) and is applied live via
`DetoxoAccessibilityService.refreshAppBlocklist()`.

<a id="app-block-native"></a>**Native enforcement**
(`DetoxoAccessibilityService.kt`). The service caches the set in a `@Volatile
blockedApps` field (refreshed by `reload()` and `refreshAppBlocklist()` — the
hot path never touches SharedPreferences). In `onAccessibilityEvent`, after the
privacy guard and the master-enable gate but **above the Pause gate** (and
before the per-package throttle and reel detection):

```kotlin
if (pkg in blockedApps &&
    (event.eventType == TYPE_WINDOW_STATE_CHANGED || pkg == foregroundPkg)
) {
    onAppBlocked(pkg)
    return
}
```

**Pause does not unlock whole-app locks.** The check sits above the pause gate:
a Pause taken for reels suspends reel/web blocking only — a fully-locked app
stays bounced through the whole Pause window. (The master switch, above both,
still disables everything.)

**A per-target grant DOES lift it** (M8). The branch reads
`!appUnblocked && pkg in blockedApps && …`, where `appUnblocked` is
`UnblockRegistry.isUnblocked("APP", pkg, …)`. That is the point of the feature:
"Unblock Instagram for 15 minutes" has to work from an app-block wall and from
the blocklist row, or the only way in is turning protection off entirely. The
grant expires natively and re-arms on its own; a Pause still does not lift the
lock ([31](31-locked-rules-and-unblock.md) §2).

The branch is **anchored to the foreground**: a backgrounded blocked app posts
notifications carrying its own `packageName` (the event mask still delivers
events stamped with it), and acting on those would HOME-bounce the user out of
an unrelated app on every incoming message. Window-state events mark the app
foregrounding; the `pkg == foregroundPkg` leg still bounces a user already
inside the app when the block lands. `onAppBlocked(pkg)`:

1. **Belt-and-braces skips** — a stale push must never bounce a
   privacy-protected app, Detoxo itself, any HOME-capable launcher (`homePkgs`, re-resolved on every push and reload — the resolver alone would read as package "android" while no default is set;
   resolved on `reload()`), or `com.android.systemui`.
2. **Own 1200 ms debounce** (`lastAppBlockTime`, same `BLOCK_DEBOUNCE_MS`
   constant but a separate timestamp — a whole-app bounce must not consume the
   reel-block window or vice versa).
3. Records to the **shared reel-block counter** (`store.recordBlock(dateKey)`)
   and emits a `blocked` event with `platformId: "app_block"`, `mode: "HOME"`,
   plus the fresh `today`/`total` — so app blocks appear in the same
   blocks-today stat as reel blocks.
4. Toast **"\<app label\> is blocked by Detoxo"** (label resolved via
   PackageManager, falling back to the package; the copy is the shared
   `strings.xml` `toast_blocked` — one string for both whole-app and web
   blocks so they can never drift apart), block vibration, then
   `performGlobalAction(GLOBAL_ACTION_HOME)` — HOME, not BACK, because BACK
   would just navigate within the blocked app.

### Screen

`app_blocker/presentation/app_block_screen.dart` — titled **"App Blocker"**
(Title Case: feature names are Title Case, everything else sentence case). It
is a *management* surface unifying two systems that **enforce differently**.
Each section is an uppercase `SectionHeader` over **one `PanelGroup`** of flat
rows split by hairlines (no card per row); the list keeps the 20 px gutters
(`AppSpacing.gutter`) and clears the FAB at the bottom.

1. **Custom apps** — the whole-app locks above (`AppBlockCubit`). An "Add app"
   `GlassFab` opens the shared installed-app picker (`core/widgets/app_picker_sheet.dart`
   → `showAppPickerSheet`): a searchable, multi-select bottom sheet of the
   device's launchable apps (icon + name + package, from
   `EngineRepository.installedApps()` — cached process-wide), drawn as flat
   `GlassListTile` rows on the sheet with hairlines between them; a picked row
   shows the tile's check and the CTA counts the picks ("Block (1)"). Apps already
   in the custom list show an "Added" badge (`AppBadge.label`) and can't be
   re-picked, and **protected apps can't be blocked** (one role per app): catalog
   packages show an "Auto-protected" badge, user-protected packages (loaded from
   `ProtectedAppsRepository` before the sheet opens) a "Protected" badge. A
   manual name + package form remains as the fallback for apps the system hides
   (work profiles, engine unavailable) — it enforces the same `unavailable` map
   (inline hint + disabled confirm), keeps any list selections when confirming,
   and configures the package field like the web-blocker host field
   (`autocorrect: false`, URL keyboard). A refresh button beside the search
   field rescans (`installedApps(refresh: true)`) for mid-session installs.
   Each selection routes through `cubit.add`, which returns an
   `AppBlockAddResult` (`added | invalid | sensitive | duplicate`, EVO-006):
   garbage package ids never persist (`isValidPackageName`,
   `lib/core/utils/package_name.dart`), and sensitive catalog packages
   (`ProtectedAppCatalog.byPackage`) are refused regardless of entry path. The
   toast reads **"Added X"** and counts only landed adds, and an
   all-refused batch shows the refusal reason as a warning instead. Each saved
   row is a `GlassListTile`: the app's real device icon (from the cached scan;
   letter-tile fallback) and its name — no package id — then only an "Allow
   {app} for a while" timer button (only while the lock is on). The row is a
   `Slidable` with the Web Blocker row's shell (`SlidableAutoCloseBehavior`
   around the `PanelGroup`, `groupTag: 'app-blocklist'`, `DrawerMotion`,
   `extentRatio` 0.52). Its end pane holds two shared `RowAction`s
   (`core/design_system/components/blockers.dart`): **Unblock** ("Unblock
   {app}", while the lock is on) or **Block** ("Block {app}",
   `toggle(i, enabled: true)`, while it is off), then **Remove** ("Remove
   {app}", `over` tone). Swiping left or tapping the row opens the pane. The
   row is one `Semantics(container: true)` button with the hint "Opens block
   and remove actions" — a container, not a `MergeSemantics`, so the timer and
   **Block now** stay their own TalkBack nodes. An off lock dims its icon
   (0.45, like the web row) and reads **"Not blocked"**. A row with a live grant swaps
   the timer for a status line under the name: `AllowedUntil` (the paused dot
   and "Allowed until 11:37 PM", `limits/unblock/presentation/widgets/
   allowed_until.dart`, shared with the Web Blocker rows; not a `Pill`, whose
   0.4x width cap ellipsised the clock) and a **Block now** `SecondaryButton`
   that ends the grant (`UnblockCubit.endEarly`). Once a lock is live and
   Notification silence is off, the panel's last row is the EVO-037 hint
   "Locked apps can still notify you", which opens Settings. When the custom
   list is empty the section is hidden entirely (the FAB is the entry point).
   **Undo toasts (C10):** the pane's Unblock and Remove act at once, with no confirm.
   Once the cubit's state shows the change landed (a failed save reverts, so
   no toast), a `GlassToast` reads **"{app} unblocked"** / **"{app} removed"**
   with an inline **Undo**. Undo re-resolves the entry by package at tap time
   (`toggle(indexOf(package), enabled: true)` / `restore(entry, index)`) and
   does nothing if it is gone or already back, or once the route-scoped cubit
   has closed (a toast outlives its route). The toast speaks from the screen's
   own `State.context`, since a removed row unmounts with its entry. The pane's
   Block is direct, with no toast.
2. **Apps & feeds** — the curated, install-aware catalog of built-in feed
   surfaces. This section is driven by the *blocking* feature's global
   `TargetsCubit` (install-aware target list) and `SettingsCubit`
   (`enabledPlatformIds`), **not** by `AppBlockCubit`. Toggling a row here calls
   `SettingsCubit.togglePlatform(...)` — i.e. it flips a `platforms_config.json`
   platform on/off, which the native reel/short detection path honors.
   Switching a feed off toasts **"{displayName} unblocked"** with Undo
   (`togglePlatform(id, enabled: true)`, only while `TargetsCubit` still lists
   the platform as installed); `SettingsCubit._commit` throws on a failed save,
   which is what keeps that toast from showing. Browsers
   are split into their own section and panel. A search field appears once there
   are more than 8 targets. Each app is one `BlockAppTile`
   (`blocking/blocklist/presentation/widgets/block_app_tile.dart`, also used by
   onboarding's selection step), a flat row with no surface of its own: a
   single-surface app is a switch row (surface name over the app name); a
   multi-surface app is a header ("Instagram" over "1 of 3 blocked", ink-3 spec
   chevron turning down when open, `Semantics(expanded:)`) that expands
   (`AnimatedSize` on `context.motion`) to indented switch rows split by
   hairlines. Every switch is named "Block {surface}" for TalkBack. No selected
   glow; uninstalled apps are dimmed, read-only and never expand.

Only the `AppBlockCubit` is route-scoped (`BlocProvider` in the screen);
`TargetsCubit` and `SettingsCubit` are global (created in `main.dart`).

Like the Web Blocker, the screen carries no intro paragraph: the app-bar
`InfoButton` explains the feed-vs-whole-app split in at most three lines, and
section labels use the shared `SectionHeader`
(`design_system/components/section_header.dart`).

The practical takeaway: adding a *custom app* takes effect immediately — the
list syncs to native and the service HOME-bounces the app on open; toggling a
*curated feed* also takes effect immediately, through the reel/short detection
engine (see [03-detection-engine.md](03-detection-engine.md) and the
blocklist/settings docs). The two paths enforce differently: whole app vs
just its feed surfaces.

---

## Part B — Web Blocklist (Dart)

### Entity: `WebBlockEntry`

`web_blocker/domain/entities/web_block_entry.dart`

| Field | Type | Notes |
|---|---|---|
| `pattern` | `String` | The host (`youtube.com`); also the entry's `id`. |
| `matchType` | `WebMatchType` | `DOMAIN` (default) / `WILDCARD`. |
| `enabled` | `bool` | Default `true`. |
| `displayName` | `String?` | Friendly label; falls back to `pattern`. |
| `source` | `WebBlockSource` | `CUSTOM` / `POPULAR` / `ADULT` / `APP_DERIVED`. |
| `brandColor` | `int?` | ARGB for the leading badge. |
| `createdAt` | `DateTime?` | Newest-first ordering. |

Derived getters: `label` (display name or pattern) and `isActive == enabled`.

> **M8 removed `pausedUntil` from this entity and from the wire.** EVO-012's
> per-site pause was Detoxo's only per-target, time-expiring escape; M8
> generalised it into `TemporaryUnblock`, so an allowed site is now a `WEBSITE`
> grant in `UnblockRegistry` — the same mechanism that frees an app or a reel
> feed — and the entry itself is unconditional. Native ignores the old key, so a
> downgrade cannot resurrect a stale pause, and `migrateWebPauses` carries a
> live one across once at bootstrap. See
> [31](31-locked-rules-and-unblock.md) §3.

Serialization is `toJson()` / `fromJson()` — the full persistence shape. The
minimal `{pattern, matchType}` wire payload is built by `syncWebBlocklist`
(there is no `toWire()` on the entity: the wire list also contains alias and
app-derived patterns that never exist as entries). Enable state, source and
colors stay Dart-side. `blockMode` was removed from the entity (dead: native
hardcodes `PRESS_BACK`; `fromJson` ignores the legacy key).

`WebBlockSource` lives in `web_blocker/domain/entities/web_block_source.dart`;
`WebMatchType` in the shared enums
(`blocking/shared/domain/entities/enums.dart`).

### Domain validation

`web_blocker/domain/utils/domain_validator.dart` — `DomainValidator.normalize()`
accepts `example.com`, `www.example.com`, `sub.example.com`, trailing-dot FQDNs
(`example.com.`) and full URLs (`https://user:pass@example.com:8080/path?x#y`),
then strips scheme → path → query/fragment → userinfo → port → leading `www.` →
trailing dot, lowercases, and validates against a host regex (dotted labels +
a 2–24 char TLD). Rejects empty input, spaces, scheme-only text, and
single-label hosts.

`DomainValidator.check(input, existingPatterns, ignoring:)` is the single
validate+dedupe rule (returns `(host, error)`), shared by the add/edit sheet's
inline validation and the cubit — the error strings live only here.

Deliberate limits, mirrored from the native matcher's `HOST_GUARD` (accepting
more here would create entries native can never match): ASCII hostnames only
(no IDN — users can paste the punycode form), no IPv4/IPv6 literals.

### Curated catalogs

- **`PopularSites`** (`web_blocker/domain/entities/popular_site.dart`) — 15
  one-tap sites (YouTube, Instagram, Facebook, X, Reddit, Netflix, Prime Video,
  Disney+, Twitch, TikTok, Pinterest, Snapchat, LinkedIn, Quora, Tumblr). Each
  `PopularSite` lists every reachable host; `primaryDomain` (`domains.first`) is
  what gets stored, and the rest are **aliases**. `aliasesFor(primaryDomain)`
  returns the non-primary hosts. Rationale: a `DOMAIN` match on `youtube.com`
  already covers `m.`/`www.` subdomains, so only cross-registrable aliases like
  `youtu.be`, `twitter.com` (for X), or `fb.com` need their own rule.
- <a id="appdomain-derivation"></a>**The category catalog's `domainsForPackage`**
  (`Catalog.bundled`, [26](26-catalog-and-usage-signal.md) — it replaced the
  18-entry `AppDomainCatalog` map) is what the "Block sites for blocked apps"
  toggle derives from. `syncWebBlocklist` reads the *existing* App Blocker list
  and derives web rules from it, so the **package list itself never crosses the
  channel** — only the resulting domains do. Every seeded service carries its
  domains, so the derivation now covers more apps than the old map (blocking
  WhatsApp with the toggle on also blocks `web.whatsapp.com`); the 18 legacy
  pairs are preserved exactly (`test/catalog_test.dart`).

### Persistence & stats

- **Blocklist:** `web_block_repository_impl.dart` → `LocalStore` key
  `StoreKeys.webBlocklist` (`"web_blocklist"`), JSON list of full entries. A
  corrupt blob **throws** (no silent `[]`): `syncWebBlocklist` must abort
  rather than push an empty list, which native would honor as an intentional
  clear. The screen surfaces the error via the cubit's `load()` catch, and a
  user re-add overwrites the blob.
- **Stats:** `web_block_stats_repository_impl.dart` → `LocalStore` key
  `StoreKeys.webBlockStats` (`"web_block_stats"`). This repo is the Dart mirror
  of website-block analytics:
  - `load()` reads the stored `{date, today, total, hosts{}}` blob and rolls the
    `today` counter to `0` when the stored calendar date is stale.
  - `watch()` subscribes to the native EventChannel and reacts to
    `ChannelEvents.webBlocked` events: it bumps a **per-host tally** (so the
    dashboard can show "most blocked") when the event carries a `host` —
    adult-list hits (`source: "ADULT"`) arrive without one and are therefore
    counted but never named (EVO-018) — then prefers the engine-supplied
    `today`/`total` counters (falling back to a local increment if omitted),
    persists, and yields a fresh `WebBlockStats`.
  - `WebBlockStats` (`web_block_stats.dart`) carries `totalBlocked`,
    `blockedToday`, `mostBlockedHost`, and a derived `focusMinutesSaved` using
    the app-wide 30 s/block heuristic (`secondsSavedPerBlock`).

The native `ConfigStore` keeps its **own** authoritative today/total web-block
counters (survives the UI process dying); the Dart repo mirrors those and adds
the per-host breakdown that native does not track.

### Cubit & state

`web_blocker/presentation/web_block_cubit.dart` +
`web_block_state.dart`. The cubit owns the blocklist plus two settings toggles
and is constructed with five dependencies: `WebBlockRepository`,
`SettingsRepository`, `AppBlockRepository`, `WebBlockStatsRepository`, and
`EngineRepository`.

Key operations:

- `load()` — hydrates entries + stats + `blockAdultWebsites` /
  `blockWebsitesForBlockedApps` from settings, subscribes to the stats stream,
  and **re-syncs native** via `_pushAll()` on every (re)entry.
- `addCustom(domain)` — validates + dedupes, appends a `CUSTOM`
  `WebBlockEntry`.
- `togglePopular(site)` — adds/removes by `primaryDomain`; a new entry carries
  the site name, `POPULAR` source, and brand color.
- `toggleEntry` / `removeEntry` / `editEntry` — CRUD; only custom entries are
  editable (re-validated + deduped).
- `restoreEntry(entry, index)` — the screen's Undo after a removal (Delete or a
  deselected popular chip): re-inserts the entry at its old index with its
  fields intact; a no-op (`false`) once its pattern is listed again.
- `setBlockAdult(value:)` / `setBlockForApps(value:)` — optimistic emit, then
  `_saveSettings` (load-modify-write of `AppSettings` + best-effort
  **`_engine.pushSettings(next)`**). A failed save reverts the toggle and
  surfaces "Couldn't save — try again" (same contract as `_commit`); a failed
  push is only logged — the value is persisted and `SettingsCubit.resync()`
  re-pushes a fresh load of the repository on the next resume. `setBlockForApps`
  also re-runs `_pushAll()` because the derived app→domain rules changed.
- `search` / `clearError`.
- `_commit(entries)` — `emit` → `_repo.save` → `_pushAll()`.

<a id="pushall"></a>**`syncWebBlocklist` — building the native payload.** The
merged blocklist is assembled and shipped in one place:
`web_blocker/domain/web_block_sync.dart` (exported via the `limits.dart`
barrel). It reads persisted state (`WebBlockRepository.load()`,
`SettingsRepository.load()`, `AppBlockRepository.load()`) rather than cubit
state — safe because every caller persists before pushing.

**Best-effort by contract:** the whole body is wrapped in try/catch →
`AppLogger.e` (non-fatal Crashlytics). A failed `load()` — e.g. a corrupt
blocklist blob, which `WebBlockRepositoryImpl.load()` deliberately rethrows —
**aborts the push**: native keeps enforcing its last-good persisted list (the
fail-safe direction). Pushing `"[]"` on corruption would be interpreted by
native as an intentional clear and wipe it. The catch also keeps the
fire-and-forget call sites from booking `fatal: true` pseudo-crashes via
`PlatformDispatcher.onError`. Its four callers:

1. `WebBlockCubit._pushAll()` (a one-line delegate) — screen load and every
   list mutation.
2. The splash `_bootstrap()` (fire-and-forget, next to
   `syncProtectedAppsAtBoot`) — repairs Dart→native drift at every launch,
   e.g. after "Reset app data", without the Web Blocker screen ever opening.
3. `AppBlockCubit.onChanged` (wired in `app_block_screen.dart`) — so
   adding/toggling/removing a blocked app immediately updates the derived
   web rules.
4. The resume re-sync heavy leg (`lib/app/app_resume_sync.dart`, throttled to
   once per 15 min).

The algorithm:

1. For each **enabled** entry add `{pattern, matchType}`. Disabled entries are
   omitted. Nothing about an allowed site rides this payload any more — that is
   a grant on `pushTemporaryUnblocks` (M8).
2. For any enabled **popular** entry, add each
   `PopularSites.aliasesFor(pattern)` as a `DOMAIN` rule (`putIfAbsent`, so
   explicit rules win). Because an alias is its own pattern on the wire, an
   allow on the primary mints its own grant for each alias too — exactly what
   the pause used to duplicate onto them. **Resume passes the same alias set**
   (`UnblockCubit.endEarly(..., alsoEnd:)`): ending only the exact id left
   `twitter.com` open for the rest of the window while the row's pill cleared
   and the screen read as protected. One tap out has to undo one tap in.
3. If `blockWebsitesForBlockedApps` is on, load the App Blocker list and, for
   each **enabled** app, add every `Catalog.bundled.domainsForPackage(package)`
   as a `DOMAIN` rule.
4. Serialize the deduped `pattern → matchType` map to a JSON array of
   `{pattern, matchType}` and call `engine.pushWebBlocklist(json)`.

Because active-state, pausing, alias expansion, and app-derivation are all
resolved here, the native side only ever sees a flat, already-filtered rule
list. In practice every rule the cubit emits is `matchType: "DOMAIN"` — nothing
in the UI creates `WILDCARD` entries today, though the entity and the native
engine support them.

### Screen

`web_blocker/presentation/web_block_screen.dart` — titled **"Web
Blocker"**. `BlocConsumer` surfaces transient `error` strings as a toast; no
`buildWhen` — stats ticks are rare while this screen is visible (blocks happen
while the user is in the browser), so the full rebuild beats selector
plumbing. The stats `Row` deliberately does **not** use
`CrossAxisAlignment.stretch`: inside the `ListView` its height is unbounded,
and stretch hands the cards an infinite height constraint — layout aborts the
frame (blank body) and then `!semantics.parentDataDirty` spams every frame.
Latent since inception, first triggered 2026-08-17 by the first on-device
`webBlocked` stat while the screen was open; guarded by
`test/web_block_screen_semantics_test.dart`. The stats section carries the
screen's one `.entrance()` (it appears with the first block, often while the
screen is open); nothing else animates on the emits that follow. Layout (20 px
gutters; the chip rail alone bleeds off the right edge):

- **Stats dashboard** (`_StatsSection`) — three `StatCard`s (Blocked today,
  Total blocked, Focus saved as `formatHm`, e.g. "1h 20m") plus a "Most
  blocked" line; only shown when `state.hasStats`.
- **Popular sites** — `AppChip`s from `PopularSites.all` in a `ChipRail`
  (design system, `components/selection.dart`: two rows inside one horizontal
  scroll, both rows scroll together; the rule editor's categories use the same
  widget); the chips are OPTION chips, selected state driven by
  `state.activePopularIds`. A trailing "Add website" chip closes the second
  row and opens the same add sheet as the FAB.
  Tapping a chip whose domain already exists as a *custom* entry upgrades that
  entry to the popular one in place (never deletes the user's entry).
- **Protection row** (`_ProtectionRow`) — one standalone `GlassListTile` under
  the chips: a neutral shield glyph, "Protection" over "N of 2 on", and the
  ink-3 chevron that says it opens a screen. It is one button node TalkBack
  reads ("Protection, 1 of 2 on") and activates — the old pill's
  `Semantics(excludeSemantics)` wrapper hid the tap action. It pushes
  `Routes.webProtection` and re-`load()`s the cubit on return so the count is
  fresh.
- **Your blocklist** — searchable rows in one `PanelGroup` (search appears past
  8 entries, matching the sibling screens, and stays visible while a query is
  active so the filter can always be cleared; the section header's note shows
  "N sites"). Each row is a `GlassListTile` led by a 34 px `SiteLetter` (the
  entry's brand colour, else `tileWeb`), the label, and for popular rows the
  domain under it; it keeps only the enable toggle inline (with a site-named
  `semanticLabel`);
  allow/resume (EVO-012, generalised by M8: the shared
  `showUnblockDurationSheet` — the caution `ConfirmSheet` "Unblock {site}?" with
  `iconWebBlocker`, 5/15/30/60-minute chips (5 picked) and the allowances line,
  committed only after its 5 s wait and slide, then toasted "{site} unblocked for
  15 min"; the same sheet the App Blocker rows ("Unblock {app}?",
  `iconAppBlocker`) and the block screen use; allowed rows show
  the shared `AllowedUntil` line (paused dot, "Allowed until 11:37 PM") under
  the row, **selected off `UnblockCubit`'s derived `active` list**, so the row
  actually rebuilds when the grant lapses instead of holding a dead countdown;
  native re-arms the block at expiry; allowed/disabled rows dim their site
  letter), edit (custom
  only — also enforced in `editEntry`) and delete live in a **flutter_slidable
  end action pane** (`DrawerMotion`; each `RowAction` (shared, `core/design_system/components/blockers.dart`) is a solid
  `option` tile at the row radius, `optionBase` washed with its tone at `kChip`, inset
  `xs` before it and `xxs` above and below so the pane reads as calm sibling pills; the
  icon sits in a tone disc in `startInk`, the label is ink, and a large text scale shrinks
  the pair rather than spilling; site-named `Semantics` labels for TalkBack).
  Swiping left or tapping the row opens the pane; `SlidableAutoCloseBehavior`
  keeps one pane open at a time. The App Blocker's custom-app rows reuse the same shell and `RowAction`. The primary empty state is
  an `EmptyState` with a flat "Add website" CTA (`PrimaryButton(flat: true)`). Add/edit use a `GlassBottomSheet` with inline feedback from the
  shared `DomainValidator.check` rule; the sheet awaits the cubit commit and
  only announces success ("Blocked X") after persist + push landed — a failed
  save reverts the optimistic list and shows the error toast instead.
- **Undo toasts (C10).** A row switched off, a row's Delete and a deselected
  popular chip all stay one tap. Once the cubit's state shows the change landed
  (a failed save reverts and toasts its own error instead), a `GlassToast`
  reads **"{site} unblocked"** (switch, chip) or **"{site} removed"** (Delete)
  with an inline **Undo**: `toggleEntry(…, enabled: true)` or
  `restoreEntry(entry, index)`, re-resolved by pattern at tap time and a no-op
  if the site is gone, already back, or the screen's cubit has closed. A chip
  lit by a *custom* entry upgrades it rather than removing it, so it toasts
  nothing. The toast speaks from `Scaffold.of(context).context` (a deleted row
  unmounts with its entry). Turning anything on shows no toast.

- **Unsupported browsers** (EVO-047) — a `NoticeLine` "Not covered: {names}"
  at the bottom, only when native answered with a non-empty list; its tap opens
  an `AppDialog` explaining that the blocklist and the 18+ filter don't apply
  there.

On-screen explanatory copy is kept to a minimum: the app-bar `InfoButton`
(a sheet of at most three lines) carries the feature explanation instead of an
intro paragraph.

### Protection screen

`web_blocker/presentation/web_protection_screen.dart` — titled
**"Protection"**, route `Routes.webProtection` (`/web-block/protection`). The
two batch toggles, split out of the main screen to keep it clean: "Block
websites of blocked apps" (`setBlockForApps`) and "Block adult content (18+)"
(`setBlockAdult`), two `AppToggleTile` rows in **one `PanelGroup`** with
neutral ink-2 glyphs and one-sentence subtitles (no selected highlight, no
entrance animation), under a one-line intro. The 18+ subtitle states the scope
— "200+ known adult sites and every .xxx, .porn, .sex or .adult address" — and
`test/adult_blocklist_test.dart` pins that "200+" to the shipped list.
Turning either one **on** is direct. Turning one **off** opens a critical
`ConfirmSheet` first (`_turnOff`; `iconWebBlocker`, "Slide to turn off"): "Turn
off the 18+ filter?" / "Adult sites open again in every browser." / "Keep it on",
and "Unblock sites of blocked apps?" / "Their websites open again in your
browser." / "Keep them blocked". The setter runs only after the slide, and the
toast ("18+ filter off" / "Sites of blocked apps unblocked") only once the state
shows it landed — a failed save reverts and toasts its own error. The switch is
bound to the state, so a cancelled sheet snaps it back.
It creates its **own `WebBlockCubit`** (same DI as the main screen) — safe
because the toggles live in settings and both screens re-load on entry, so two
instances never drift.

---

## The `pushWebBlocklist` contract

**Wire payload** (from `_pushAll`, JSON string argument `json`):

```json
[
  {"pattern": "youtube.com", "matchType": "DOMAIN"},
  {"pattern": "youtu.be",    "matchType": "DOMAIN"}
]
```

**Dart side.** `EngineRepository.pushWebBlocklist(String json)` →
`EngineChannel.pushWebBlocklist` →
`invokeVoid(ChannelMethods.pushWebBlocklist, {'json': json})` over MethodChannel
`com.errorxperts.detoxo/commands`. The whole engine layer no-ops off Android via
`PlatformCapabilities`. The two category toggles ride the **`pushSettings`**
command instead (`blockAdultWebsites`, `blockWebsitesForBlockedApps` fields).

**Native side** (`channels/CommandHandler.kt`):

- `"pushWebBlocklist"` → fail-safe like `pushProtectedApps`: a null or
  non-JSON-array `json` arg is a **no-op, never a wipe** (clearing requires an
  explicit `"[]"`); a valid payload is stored
  (`store.webBlocklistJson = json`) and applied via
  `DetoxoAccessibilityService.instance?.refreshWebBlocklist()` — the rule set
  only (`webEngine.setBlocklist`), not a full `reload()` (which re-parses the
  31 KB platforms config). A payload identical to the stored one is skipped
  entirely: every Web Blocker screen entry re-pushes.
- `"pushSettings"` → among other fields, sets `store.blockAdultWebsites` /
  `store.blockWebsitesForBlockedApps`, then `reload()`.

`ConfigStore` (`engine/ConfigStore.kt`) persists these to SharedPreferences file
`detoxo_engine_prefs` (`webBlocklistJson`, `blockAdultWebsites`,
`blockWebsitesForBlockedApps`) plus the separate web-block counters
(`recordWebBlock(dateKey)` / `webBlockStats()`), kept distinct from the
reel-block counter. On `reload()` the service re-applies both:

```kotlin
webEngine.setBlocklist(store.webBlocklistJson)
webEngine.setAdultEnabled(store.blockAdultWebsites)
```

> Note: `blockWebsitesForBlockedApps` is persisted natively but the derivation is
> entirely Dart-side — native just receives the already-merged domain rules via
> `pushWebBlocklist`, so the native flag is effectively informational.

---

## Native enforcement

### `WebBlockEngine`

`android/app/src/main/kotlin/com/errorxperts/detoxo/engine/WebBlockEngine.kt` —
the host matcher. Holds a `@Volatile` in-memory `List<Rule(pattern, type)>` and
an optional adult-domain `HashSet`.

- `setBlocklist(json)` — parses the pushed `[{pattern,matchType}]`, lowercasing
  and trimming patterns, dropping blanks; `matchType` defaults to `"DOMAIN"`.
- `setAdultEnabled(on)` — **lazily loads** the bundled asset
  `adult_domains.txt.gz` (gzipped, `#`-comment-aware) into a `HashSet` only while
  the toggle is on, and frees it when off (so it costs no heap otherwise). A
  missing/unreadable asset degrades to an empty set (adult blocking no-ops).
  The asset is **generated** (EVO-017): `tool/web_blocker/blocked_websites.json`
  (`domains` — 272 registrable hosts, incl. the ones folded in from the user's
  scrape; `tlds` — the four ICANN adult TLDs `adult`/`porn`/`sex`/`xxx`;
  `allow` — hosts the compiler refuses, e.g. `google.com`, `twitter.com`) is
  compiled by `bash tool/dev.sh adultlist` (`tool/web_blocker/compile_adult_list.py`,
  byte-stable output), and `test/adult_blocklist_test.dart` fails whenever
  source and asset drift. Edit the JSON, never the `.gz`.
- `hasAnyRules()` — cheap guard for the accessibility hot path (any rules, or
  adult enabled with a non-empty set).
- `matchHost(host)` — returns which list blocks the host:
  `Match.RULE` (the user's/derived blocklist), `Match.ADULT` (the bundled set)
  or `null`. The caller uses the distinction to name RULE hits but never ADULT
  ones (EVO-018). Rule matching:

| `matchType` | Rule |
|---|---|
| `DOMAIN` (default) | `host == pattern` **or** `host.endsWith("." + pattern)` — covers subdomains. |
| `WILDCARD` | glob (`*` = any run) — regex precompiled once at `parse()`, never on the per-event path. |

**One grant check gates the whole rule loop** (M8): before iterating,
`matchHost` asks `UnblockRegistry.isUnblocked("WEBSITE", host, elapsedRealtime)`
— a `WEBSITE` grant matches the host exactly or as a subdomain of it, so
allowing `youtube.com` covers `m.youtube.com`, the coverage `pausedUntil` had.
The deadline is on the **monotonic** clock (EVO-048), converted once per parse,
so rolling the device clock back in Settings cannot hold an allow open. The
`DOMAIN` subdomain check is allocation-free (`isSubdomainOf` — no
`"." + pattern` concat per event).

If adult blocking is on, the host is additionally walked up its parent labels
**down to the bare TLD** (`foo.bar.example.com → bar.example.com → example.com
→ com`), returning `Match.ADULT` on any set hit — so a bare-TLD line in the
asset (`porn`) blocks every `*.porn` address, and a TLD entry can only ever
match as the *last* label (`sussex.ac.uk` never reaches `sex`).

That walk lives in `matchesAdult`, called **outside** the grant check above —
not merely skipped by a `continue` inside the loop — so an 18+ hit can never be
lifted by a `WEBSITE` grant (EVO-018). The wall also refuses to offer "Unblock
for a while" for a host that is on **both** lists: the rule arm wins the match,
so the button would otherwise mint a grant the adult walk immediately overrules.

> All matching is **host-based**. Android accessibility can read the address bar
> but cannot see network traffic, so there is no URL/path/network-level
> filtering. An `EXACT` arm once existed and needed a full URL this flow never
> supplies, so it matched NOTHING; it was removed, and any `EXACT` rehydrated
> from an old blob now falls through to `DOMAIN`, which does block.

### `BrowserUrlExtractor`

`android/app/src/main/kotlin/com/errorxperts/detoxo/engine/BrowserUrlExtractor.kt` —
stateless host extraction from a browser's accessibility tree.

- **`isBrowser(pkg)`** — membership test over `KNOWN_BROWSERS` (the mapped
  address-bar packages **plus** extra recognized browsers that rely on the
  generic fallback, e.g. Lightning, Adblock Browser, Puffin, Tor). This gates the
  whole web branch in the service.
- **`extractHost(root, pkg, maxNodes)`** — two-stage:
  1. **Fast path:** a per-browser address-bar resource-id lookup
     (`URL_BAR_IDS`, ~22 packages incl. Chrome/Beta/Dev/Canary, Samsung
     Internet, Firefox/Fenix, Edge, Brave, Opera/Mini/GX, DuckDuckGo, Kiwi,
     Vivaldi, Mi/Mini, AOSP, UC, Yandex, Ecosia) via
     `findAccessibilityNodeInfosByViewId`.
  2. **Generic fallback:** a bounded DFS (`ArrayDeque`, capped at `maxNodes` =
     `MAX_NODES` = 12000, same cap as reel detection) over `EditText` /
     `url`-ish nodes. It widens coverage **within `KNOWN_BROWSERS`** — the eight
     recognized-but-unmapped packages — and not beyond it: `isBrowser` gates the
     whole branch first, so a browser absent from that set is never read at all
     and neither the user's blocklist nor the 18+ filter applies in it. The UI
     says "any **supported** browser" for this reason.

  Both stages **skip focused nodes**: a focused address bar means the user is
  typing, so half-typed hosts never trigger a back press mid-edit. Once
  navigation commits, focus moves to the page and the load's content-change
  events re-run extraction on the then-unfocused bar, so the block still
  fires. Ceiling: a browser that kept its bar focused after page load would
  never be blocked — none of the mapped ones do.
- **`normalizeHost(raw)`** — lowercases, rejects strings containing spaces
  (search queries / "Search or type URL" placeholders), strips
  scheme/path/query/fragment/port, leading `www.` and a trailing dot (the FQDN
  form `example.com.` resolves identically and used to fail the guard — a
  one-keystroke bypass; Dart's `DomainValidator` strips it too), and validates
  against a registrable-host guard (min length 4, must contain a dot).

### Flow in the accessibility service

`accessibility/DetoxoAccessibilityService.kt`. The web branch sits in
`onAccessibilityEvent`, after the master-enable and pause-window gates and the
per-package `THROTTLE_MS` (150 ms) throttle:

```kotlin
if (BrowserUrlExtractor.isBrowser(pkg)) {
    // `!paused` keeps a Pause's meaning for the browser: web blocking has
    // never survived a Pause (strict websites are EVO-030's follow-up).
    if (!paused &&
        (webEngine.hasAnyRules() || ruleEngine.hasHostRules()) &&
        (event.type == WINDOW_STATE_CHANGED || event.type == WINDOW_CONTENT_CHANGED))
        handleBrowser(pkg)
    return   // a browser carries no reel surfaces
}
```

`handleBrowser(pkg)`:

1. Bail unless the focused root's package **is** `pkg` — in split-screen
   `rootInActiveWindow` is the focused pane, and the generic fallback would
   otherwise harvest any url-ish `EditText` from the *other* app and BACK out
   of it. Then `extractHost(root, pkg, MAX_NODES)`; bail if null.
2. `webEngine.matchHost(host)` → `Match?`; when `null`, a **website schedule**
   from the rules snapshot is tried next (`ruleEngine.blockingForHost(host, now)`,
   [27](27-rules-engine.md)). If both are null (allowed), remember the host as
   `lastUrlByPkg` and return. A rule hit follows the same path as a `RULE` hit
   below (named host, `source: "RULE"`), with the wall's `blockReason` set to the
   rule's reason (`SCHEDULE`) instead of `WEB_RULE`.
3. **Per-host debounce:** if the host equals the last one and it is within
   `BLOCK_DEBOUNCE_MS` (1200 ms), skip — so a content-change storm on the same
   blocked page yields at most one back press.
4. `store.recordWebBlock(dateKey())`, read `(today, total)`, and post a
   `webBlocked` event: `{source:"RULE"|"ADULT", mode:"PRESS_BACK", today,
   total, host?}` — **`host` is present only for `RULE` hits.** Adult-list hits
   are counted but never named (EVO-018): without a host, Dart's per-host tally
   and the "Most blocked" line skip them.
5. **Raise the wall** (`raiseWall`, [25](25-block-screen.md)) with
   `TYPE_WEBSITE` and the host as `referenceId`/`displayName` — empty for ADULT
   hits, which are never named (EVO-018). Only if no wall could be raised
   (`!shown`) does a toast stand in (EVO-011), so the bounce is still
   attributable rather than looking like a browser glitch — **"$host is blocked
   by Detoxo"** (`toast_blocked`, shared with the whole-app block) for RULE
   hits, **"Adult site blocked by Detoxo"** (`toast_blocked_adult`) for ADULT
   hits. Then `pressBackWithRateLimit()` (global back action, rate-limited by
   `BACK_RATE_LIMIT_MS` = 1100 ms).

The block **mode is always `PRESS_BACK`** here — only `{pattern, matchType}`
crosses the channel, so native has no per-entry mode to honor. The log line never includes the host (browsing data
must not reach logcat); the `webBlocked` event is consumed by
`WebBlockStatsRepositoryImpl.watch()` to update the Dart-side dashboard.

---

## Enforcement status (this build)

| Capability | Status |
|---|---|
| App Blocker — custom whole-app locks | **Live** — `pushAppBlocklist` + native HOME bounce (`onAppBlocked`). Per-entry `lockAction`/`dailyLimitMinutes` still unused (future work). |
| App Blocker — curated feed toggles | Live, via existing reel/short detection (`SettingsCubit.togglePlatform`). |
| Web Blocklist — custom + popular domains | **Live** — native `WebBlockEngine` + address-bar read → back press. |
| Web Blocklist — "block sites for blocked apps" | Live; domains derived Dart-side from enabled App Blocker apps. |
| Web Blocklist — adult category | **Live** — 272 registrable domains + the 4 ICANN adult TLDs, compiled from `tool/web_blocker/blocked_websites.json` into `adult_domains.txt.gz` (EVO-017); hits are counted but never named (EVO-018). No-ops if the asset is missing. |
| Web match types beyond `DOMAIN` (`WILDCARD`) | Supported natively; not produced by the current UI. |

## Source files

- `lib/features/limits/limits.dart`
- `lib/features/limits/app_blocker/domain/entities/app_block_entry.dart`
- `lib/features/limits/app_blocker/domain/repositories/app_block_repository.dart`
- `lib/features/limits/app_blocker/domain/app_block_sync.dart` (`syncAppBlocklist` — the single push path)
- `lib/features/limits/app_blocker/data/repositories/app_block_repository_impl.dart`
- `lib/features/limits/app_blocker/presentation/app_block_cubit.dart`
- `lib/features/limits/app_blocker/presentation/app_block_screen.dart` (custom-app rows: `Slidable` + `RowAction` pane)
- `lib/core/design_system/components/blockers.dart` (`RowAction` — the swipe-pane action shared by the app and web rows)
- `lib/app/app_resume_sync.dart` (resume-time blocklist re-sync)
- `test/app_block_sync_test.dart`
- `test/app_block_screen_undo_test.dart` (C10 Undo toasts: pane Unblock, feed off, pane Remove; an off row's "Not blocked" + pane Block; the row's one-button semantics with the timer as its own node; a grant's "Allowed until" line + Block now)
- `test/web_block_screen_semantics_test.dart` (semantics regressions + C10 Undo toasts: site off, chip, Delete; the Protection row's one button node; "Allowed until")
- `lib/features/blocking/blocklist/presentation/widgets/block_app_tile.dart` (`BlockAppTile` / `BlockAppGroup` — the Apps & feeds rows)
- `test/blocklist_install_filter_test.dart` (install-aware catalog, `BlockAppGroup`, `BlockAppTile` rows and "Block {surface}" switches)
- `lib/features/limits/unblock/presentation/widgets/allowed_until.dart` (`AllowedUntil` — a granted row's status line)
- `lib/core/widgets/app_picker_sheet.dart` (shared installed-app picker)
- `lib/core/platform_channels/installed_app.dart`
- `lib/core/utils/package_name.dart` (package-id validation)
- `lib/features/limits/web_blocker/domain/entities/web_block_entry.dart`
- `lib/features/limits/unblock/**` (the grant that replaced `pausedUntil` — [31](31-locked-rules-and-unblock.md))
- `android/app/src/main/kotlin/com/errorxperts/detoxo/engine/UnblockRegistry.kt`
- `lib/features/limits/web_blocker/domain/entities/web_block_source.dart`
- `lib/features/limits/web_blocker/domain/entities/web_block_stats.dart`
- `lib/features/limits/web_blocker/domain/entities/popular_site.dart`
- `lib/features/limits/web_blocker/domain/repositories/web_block_repository.dart`
- `lib/features/limits/web_blocker/domain/repositories/web_block_stats_repository.dart`
- `lib/features/limits/web_blocker/domain/utils/domain_validator.dart`
- `lib/features/limits/web_blocker/domain/web_block_sync.dart`
- `lib/features/limits/web_blocker/data/repositories/web_block_repository_impl.dart`
- `lib/features/limits/web_blocker/data/repositories/web_block_stats_repository_impl.dart`
- `lib/features/limits/web_blocker/presentation/web_block_cubit.dart`
- `lib/features/limits/web_blocker/presentation/web_block_state.dart`
- `lib/features/limits/web_blocker/presentation/web_block_screen.dart` (rows: `Slidable` + the shared `RowAction`)
- `lib/features/limits/web_blocker/presentation/web_protection_screen.dart`
- `lib/features/blocking/shared/domain/entities/enums.dart` (`WebMatchType`, `AppLockAction`, `BlockingMode`)
- `lib/core/constants/channel_constants.dart` (`pushWebBlocklist`, `pushAppBlocklist`, `webBlocked`)
- `lib/core/platform_channels/engine_channel.dart` (`pushWebBlocklist`, `pushAppBlocklist`)
- `lib/core/storage/local_store.dart` (`appBlocklist`, `webBlocklist`, `webBlockStats` keys)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/engine/WebBlockEngine.kt`
- `android/app/src/main/kotlin/com/errorxperts/detoxo/engine/BrowserUrlExtractor.kt`
- `android/app/src/main/kotlin/com/errorxperts/detoxo/accessibility/DetoxoAccessibilityService.kt` (`handleBrowser` web branch; `onAppBlocked` + `refreshAppBlocklist`)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/channels/CommandHandler.kt` (`pushWebBlocklist`, `pushAppBlocklist`, `pushSettings`)
- `android/app/src/main/kotlin/com/errorxperts/detoxo/engine/ConfigStore.kt` (web-block persistence + counters; `blockedAppPackages`)
- `android/app/src/main/res/values/strings.xml` (`toast_blocked` — shared web/whole-app block toast; `toast_blocked_adult` — unnamed adult-list toast)
- `android/app/src/main/assets/adult_domains.txt.gz` (GENERATED 18+ list — never hand-edited)
- `tool/web_blocker/blocked_websites.json` (18+ list source: `domains`, `tlds`, `allow`)
- `tool/web_blocker/compile_adult_list.py` (`bash tool/dev.sh adultlist` — compiles the source into the asset)
- `test/adult_blocklist_test.dart` (source ↔ asset drift guard + suffix-walk semantics)
