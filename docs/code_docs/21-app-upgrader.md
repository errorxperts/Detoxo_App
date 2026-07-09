# App Upgrader

The **app upgrader** is Detoxo's in-app "update available" prompt. It checks the Google Play
listing for a newer build and, when one exists, surfaces an on-brand glass dialog to send the
user to the store. It lives under
[`lib/features/additional_feature/app_upgrader/`](../../lib/features/additional_feature/app_upgrader/)
and is reached only through its barrel
[`app_upgrader.dart`](../../lib/features/additional_feature/app_upgrader/app_upgrader.dart).

It is **offline-first and additive**: the check is **Android-only** and **fails closed** — a
non-Android platform, a failed Play scrape, or no network all resolve to "nothing to show", so
the prompt can never block launch.

## Engine vs. UI

The feature uses the [`upgrader`](https://pub.dev/packages/upgrader) package (**v13.5.0**) purely
as the **engine**: it scrapes the Play Store listing for the latest version, compares it to the
installed build, persists the user's "Later"/"Skip" choices, and launches the store. Detoxo does
**not** mount `upgrader`'s `UpgradeAlert` widget — the prompt is rendered as the app's own glass
[`AppDialog`](../../lib/core/design_system/components/dialog.dart) so it matches the design
system. In `upgrader` 13.x the controller is decoupled from its widget, so driving a custom UI
from it is the sanctioned pattern.

`upgrader` persists its own dismissal state (ignored version / last-alerted timestamp) in **its
own** `SharedPreferences` — the app's Hive [`LocalStore`](../../lib/core/storage/local_store.dart)
is untouched, and the feature adds **no** new `StoreKeys`.

## Layers

Feature-first Clean Architecture, mirroring the sibling `app_feedback`:

### Domain
- [`UpgradeStatus`](../../lib/features/additional_feature/app_upgrader/domain/entities/upgrade_status.dart)
  — an `Equatable` entity: `installedVersion`, `storeVersion`, `releaseNotes` (all nullable),
  `isUpdateAvailable`, `isCritical`, `isBelowMinVersion`. Derived: `isBlocking = isCritical ||
  isBelowMinVersion` and `canDismiss = !isBlocking`.
- [`AppUpgradeService`](../../lib/features/additional_feature/app_upgrader/domain/repositories/app_upgrade_service.dart)
  — `abstract interface class` with `check({bool force})`, `openStore()`, `remindLater()`,
  `skipThisVersion()`.

### Data
- [`UpgraderAppUpgradeService`](../../lib/features/additional_feature/app_upgrader/data/repositories/upgrader_app_upgrade_service.dart)
  wraps one lazily-built `Upgrader` (`UpgraderStoreController(onAndroid: UpgraderPlayStore.new)`,
  `durationUntilAlertAgain: 1 day`, `debugLogging`/`debugDisplayAlways: kDebugMode`). `check`
  guards on [`PlatformCapabilities.supportsBlockingEngine`](../../lib/core/platform/platform_capabilities.dart)
  (Android-only), then `initialize()`s and maps the engine to `UpgradeStatus`:
  - **Automatic** check (`force: false`) gates on `shouldDisplayUpgrade()` — honours the "Later"
    throttle, the ignored version, and `debugDisplayAlways` in dev.
  - **Manual** check (`force: true`) gates on `isUpdateAvailable()` — bypasses the throttle so a
    user-initiated check always reports an available update.
  - `isCritical` ← `versionInfo?.isCriticalUpdate`; `isBelowMinVersion` ← `belowMinAppVersion()`.
  - Actions map to `sendUserToAppStore()` / `saveLastAlerted()` (Later) / `saveIgnored()` (Skip).
  - Every call is wrapped in try/catch and returns `null`/no-ops on failure.

### Presentation
- [`UpgradeCubit` + `UpgradeState`](../../lib/features/additional_feature/app_upgrader/presentation/upgrade_cubit.dart)
  — `Cubit` + `Equatable` state (`UpgradeView { idle, checking, updateAvailable, upToDate, error }`,
  the `UpgradeStatus?`, and a `manual` flag). `check({manual})` calls the service with
  `force: manual`; `openStore()`, `remindLater()`, `skip()` delegate and reset to idle. Created
  inline via `BlocProvider` (not registered in `get_it`), like the app's other cubits.
- [`AppUpgradeDialog`](../../lib/features/additional_feature/app_upgrader/presentation/app_upgrade_dialog.dart)
  — `abstract final class` with `static show(context, status, {onUpdate, onLater, onSkip})`,
  built on `AppDialog.show` (icon `Icons.system_update`, muted version message, optional
  scrollable "What's new" release-notes box). Optional update → `[GhostButton('Later'),
  PrimaryButton('Update now')]` plus a subtle "Skip this version". **Blocking** update
  (`!canDismiss`) → title "Update required", warning accent, **only** "Update now", and
  `barrierDismissible: false` + `blocking: true` so the barrier tap **and** the back button are
  disabled; "Update now" does not pop (the user stays gated until they actually update).
- [`UpgradeGate`](../../lib/features/additional_feature/app_upgrader/presentation/upgrade_gate.dart)
  — provides the `UpgradeCubit` (`..check()` on mount) and a `BlocListener` that shows the dialog
  on `updateAvailable` (one-shot guarded) or a "You're on the latest version" `GlassToast` on a
  **manual** `upToDate`.

## Wiring

- **DI:** one line in the [`injector.dart`](../../lib/core/di/injector.dart) cascade —
  `..registerLazySingleton<AppUpgradeService>(UpgraderAppUpgradeService.new)`.
- **Automatic check:** `UpgradeGate` wraps the `GlassScaffold` in
  [`home_shell.dart`](../../lib/features/dashboard/presentation/home_shell.dart). It is mounted on
  `HomeShell` (not the `MaterialApp.router` `builder:`) so the dialog is shown from a context
  under the go_router `Navigator` (no `navigatorKey` plumbing) and only after the splash →
  onboarding → PIN → permissions gating completes.
- **Manual check:** the app-version `InfoBanner` on the **Settings** screen
  ([`settings_screen.dart`](../../lib/features/settings/presentation/settings_screen.dart), the
  `_VersionBanner` widget). Settings is a separate route (not under `UpgradeGate`), so it hosts
  its **own** screen-local `UpgradeCubit` that `..check()`s on open. Tapping the banner runs a
  `check(manual: true)` (toasting "You're on the latest version" when current); when an update is
  available the banner reveals a **compact "Update" button** (`_UpdateButton`) that calls
  `openStore()`. This surface shows the inline button rather than the blocking dialog — the dialog
  is the launch-gate (`HomeShell`) path only. The `InfoBanner`
  ([`daily_limit_screen.dart`](../../lib/features/limits/daily_limit/presentation/daily_limit_screen.dart))
  gained optional `trailing` (the compact button) and `onTap` (the manual check) params for this.
- **Design system:** [`GlassDialog.show`](../../lib/core/design_system/components/overlays.dart)
  and [`AppDialog.show`](../../lib/core/design_system/components/dialog.dart) gained
  `barrierDismissible` (default `true`) and `blocking` (default `false`) params; `blocking` wraps
  the dialog in `PopScope(canPop: false)`. This is the only shared-component change and is
  reusable by any future mandatory dialog.
- **Manifest:** none needed — the `<queries>` for `VIEW`+`https` already exists in
  [`AndroidManifest.xml`](../../android/app/src/main/AndroidManifest.xml), so the store launch
  works.
- **Dependency:** `upgrader: ^13.5.0` added to `pubspec.yaml` (see
  [14-flutter-package-map.md](14-flutter-package-map.md)). It pulls `shared_preferences` /
  `url_launcher` / `http` transitively for its own use.

## Force-update source

A blocking update is triggered when the installed build is below a minimum, or the listing is
tagged critical. The minimum comes from either `Upgrader(minAppVersion: 'x.y.z')` (compiled in)
or the Play listing tag `[Minimum supported app version: x.y.z]`; `[Critical update: ...]` sets
`isCriticalUpdate`. No `minAppVersion` is compiled in today, so force-update is driven entirely
by the Play listing tags until one is set.

## Testing & dev notes

- Play scraping only returns a real store version once the app is **published** under
  `com.errorxperts.detoxo`. Debug builds behave like production (no forced prompt) so the dialog
  doesn't pop during unrelated work. To preview it on an unpublished build, temporarily add
  `debugDisplayAlways: true` to the `Upgrader` in `UpgraderAppUpgradeService` and reset persisted
  state between runs with the static `Upgrader.clearSavedSettings()`.
- To exercise the **blocking** path locally, temporarily pass `minAppVersion: '2.0.0'` (the app
  is `1.0.0`) → `belowMinAppVersion()`/`blocked()` become true.
- Unit coverage: [`test/app_upgrader_test.dart`](../../test/app_upgrader_test.dart) exercises the
  `UpgradeStatus` blocking/dismissible logic and the `UpgradeCubit` state machine (including the
  `force` flag) against a fake service.

## Source files

- `lib/features/additional_feature/app_upgrader/app_upgrader.dart`
- `lib/features/additional_feature/app_upgrader/domain/entities/upgrade_status.dart`
- `lib/features/additional_feature/app_upgrader/domain/repositories/app_upgrade_service.dart`
- `lib/features/additional_feature/app_upgrader/data/repositories/upgrader_app_upgrade_service.dart`
- `lib/features/additional_feature/app_upgrader/presentation/upgrade_cubit.dart`
- `lib/features/additional_feature/app_upgrader/presentation/app_upgrade_dialog.dart`
- `lib/features/additional_feature/app_upgrader/presentation/upgrade_gate.dart`
- `lib/core/design_system/components/overlays.dart` (`GlassDialog.show` gained `barrierDismissible`/`blocking`)
- `lib/core/design_system/components/dialog.dart` (`AppDialog.show` pass-through)
- `lib/core/di/injector.dart` (`AppUpgradeService` registration)
- `lib/features/dashboard/presentation/home_shell.dart` (`UpgradeGate` wrap — automatic check)
- `lib/features/settings/presentation/settings_screen.dart` (`_VersionBanner`/`_UpdateButton` — manual check + compact Update button)
- `lib/features/limits/daily_limit/presentation/daily_limit_screen.dart` (`InfoBanner` gained `trailing`/`onTap`)
- `pubspec.yaml` (`upgrader` dependency)
- `test/app_upgrader_test.dart`

## Related
- [15 iOS / Cross-Platform Reality](15-ios-cross-platform.md) — why the check is Android-only.
- [14 Flutter Package Map](14-flutter-package-map.md) — the `upgrader` dependency.
- User-facing: [Feature Walkthroughs](../info_docs/02-feature-walkthroughs.md),
  [FAQs](../info_docs/04-faqs.md).
