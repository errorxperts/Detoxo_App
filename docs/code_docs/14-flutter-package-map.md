# Flutter Package Map

This document is the authoritative map of Detoxo's Dart/Flutter dependencies: what
each package in `pubspec.yaml` is, and — crucially — whether it is **actually wired**
into the shipped code or merely **declared** (a scaffold / swap-in that carries no
runtime behaviour yet). Every "wired" claim below is grounded in a real import in
`lib/`; every "declared, not wired" entry was verified to have **zero** import sites.

- **App identity:** `name: detoxo`, `version: 1.0.1+4`, `environment.sdk: ^3.12.1`,
  `publish_to: 'none'` (private app, never published to pub.dev). The launcher-icon
  package writes the app icon from `tool/branding/detoxo_app_icon.png` — **outside**
  `assets/`, because `pubspec.yaml` declares whole asset directories and a
  build-time input placed in one of them (`assets/images/icons/`, …) ships inside the APK. See
  [22-play-release.md](22-play-release.md#artifact-size).
- **Architecture recap:** Cubit-only state (`flutter_bloc`), a single `get_it`
  service locator (`sl`), declarative routing (`go_router`), feature-first Clean
  Architecture. See [01-overview-architecture.md](01-overview-architecture.md) and
  [01-overview-architecture.md](01-overview-architecture.md) for how these compose.

> Legend: **Wired** = imported and used in `lib/`. **Declared / swap-in** = present
> in `pubspec.yaml` but no `lib/` import — a placeholder for a planned capability or
> a native-side responsibility handled elsewhere. Do not assume a declared package
> is live.

---

## 1. Core architecture (state, DI, routing)

| Package | Version | Status | Role in Detoxo |
| --- | --- | --- | --- |
| `flutter_bloc` | `^9.1.1` | **Wired** (35 files) | The only state-management library. Every feature exposes **Cubits** (no event-driven Blocs, no Riverpod). Provides `BlocProvider`, `BlocBuilder`, `BlocSelector`, `BlocListener` used across screens (e.g. `main.dart` selects `AppThemeMode` off `SettingsCubit`). |
| `bloc` | `^9.2.1` | **Wired (transitive)** | Foundation library re-exported by `flutter_bloc`; `Cubit`/`Emitter` come from here. Not imported directly (`package:bloc/bloc.dart` appears nowhere) but pinned so the version is explicit. |
| `equatable` | `^2.0.8` | **Wired** (21 files) | Value equality for Cubit states and domain entities/value-objects, so `BlocBuilder`/`BlocSelector` can skip no-op rebuilds. |
| `get_it` | `^9.2.1` | **Wired** | The service locator. Single registration surface in `lib/core/di/injector.dart` exposed as `sl`. All repositories/cubits/data sources are resolved through it. |
| `go_router` | `^17.3.0` | **Wired** (10 files) | Declarative navigation. Route table + splash gating (onboarding → PIN → permissions → home) route through it (`lib/core/navigation/`, `lib/app/splash_screen.dart`, onboarding). |

---

## 2. Code generation (models, assets)

| Package | Version | Status | Role in Detoxo |
| --- | --- | --- | --- |
| `freezed_annotation` | `^3.1.0` | **Wired** | Annotations for immutable data classes / unions. Backs the config models (`initial_config_model`, `platform_config_model` under `lib/features/blocking/shared/data/models/`) with generated `*.freezed.dart`. |
| `json_annotation` | `^4.12.0` | **Wired (generated)** | `@JsonSerializable` annotations consumed by the generated `*.g.dart` serializers for the same config models. No hand-written import; it lives in generated code. |

Codegen for these runs through `build_runner` + `freezed` + `json_serializable`
(dev dependencies, §7). Regenerate with `dart run build_runner build`.

**FlutterGen is a CLI, not a dependency.** `lib/gen/assets.gen.dart` is produced by
the standalone `fluttergen` binary (`brew install FlutterGen/tap/fluttergen`), not
by `build_runner`, and the generated file imports only `flutter` + `flutter_svg`.
The `flutter_gen` *package* was therefore removed from `dependencies:` — it never
contributed runtime code. Behaviour is configured by the `flutter_gen:` block in
`pubspec.yaml` (output `lib/gen/`, `flutter_svg` integration on so SVGs generate as
`SvgGenImage`). Regenerate with
`bash tool/dev.sh assets`.

> **Re-run `fluttergen` after any asset rename.** Accessor names drop the extension,
> so a `.png` → `.webp` swap regenerates to the same identifier and every call site
> keeps compiling — but only once the file is regenerated.

**Design tokens come from a script, not `build_runner`.** `tool/design/gen_design_tokens.dart`
turns `tool/design/tokens.json` (a byte copy of the Detoxo Design System spec; never edit it) and
`tool/design/recipes.json` (the spec `bundle.css` values tokens.json lacks, plus documented local
overrides such as Light `ink-3` #7d8699) into `lib/core/design_system/tokens/app_tokens.g.dart`
(a `part` of `app_tokens.dart`) and the native `overlay/DxTokens.kt`. It shares
`tool/tokens_common.dart` with the home-widget generator `tool/home_widget/gen_tokens.dart`.
Re-run it after editing either JSON; precommit and `test/core/design_system/design_tokens_test.dart`
run it with `--check` and fail on drift. The root `build.yaml` keeps source_gen's combining
builder off `app_tokens.dart`: that builder would otherwise claim `app_tokens.g.dart` as its own
output and delete it on every `build_runner build`.

`tool/dev.sh` wraps the routine command combos (fresh build, codegen, quality,
pre-commit, full validation, dependency refresh, reset, FlutterFire, assets,
launcher icons) — run it bare for a menu or pass an entry name/number.

---

## 3. Storage, security & auth

| Package | Version | Status | Role in Detoxo |
| --- | --- | --- | --- |
| `hive` | `^2.2.3` | **Wired (backing)** | Key-value box engine. |
| `hive_flutter` | `^1.1.0` | **Wired (backing)** | Flutter init for Hive. Together they back `LocalStore` (`lib/core/storage/local_store.dart`), which opens a single `Box<String>` named `detoxo` and exposes a deliberately **simple key→JSON-string** seam (`read`/`write`/`delete`). The rest of the app never touches Hive types directly. Keys are centralised in `StoreKeys` (`app_settings`, `web_blocklist`, `app_blocklist`, `daily_limit`, `premium_dev_unlock`, `usage_daily`, `dismissed_notices`, `install_id`, …). |
| `flutter_secure_storage` | `^10.3.1` | **Wired** | Secret partition of `LocalStore` (`readSecret`/`writeSecret`). Holds the PIN config (`StoreKeys.pinConfig`). `clearAll()` wipes both the Hive box and every secret for "Reset app data". |
| `local_auth` | `^3.0.1` | **Wired** | Biometric / device-credential unlock for the app-lock (PIN) flow (`lib/features/access_protection/`). |
| `crypto` | `^3.0.6` | **Wired** | Hashing the app-lock PIN before storage — `lib/features/access_protection/domain/pin_hasher.dart` (PINs are never stored in plaintext). |
| `path` | `^1.9.1` | **Wired** | Filesystem path composition (used alongside `path_provider`). |
| `path_provider` | `^2.1.5` | **Wired** | Resolves platform directories (e.g. for Hive init / file locations). |

> Native persistence is separate: the engine writes its own Android
> `SharedPreferences` file `detoxo_engine_prefs` (config + content-counter). That is
> documented in [09-persistence-data-model.md](09-persistence-data-model.md), not here.

---

## 4. Platform, device & permissions

| Package | Version | Status | Role in Detoxo |
| --- | --- | --- | --- |
| `permission_handler` | `^12.0.3` | **Wired** | Runtime permission checks/requests in `lib/features/permissions/data/repositories/permission_repository_impl.dart` (imported as `ph`). Also provides `openAppSettings()` (→ `ACTION_APPLICATION_DETAILS_SETTINGS`) for the restricted-settings recovery flow. Note: the *specialised* Android permissions (accessibility, overlay, usage-access, battery exemption, device admin) are driven natively over the MethodChannel, not through this package. |
| `device_info_plus` | `^13.1.0` | **Wired** | Device/OS metadata (model, Android version) for diagnostics/feedback. |
| `package_info_plus` | `^10.1.0` | **Wired** | App version/build number surfaced in Settings / feedback. Also supplies `installerStore` (→ `getInstallSourceInfo().initiatingPackageName`) for the restricted-settings / ECM detection in [13-onboarding-permissions.md](13-onboarding-permissions.md) §3.4. |

---

## 5. UI, design system & motion

| Package | Version | Status | Role in Detoxo |
| --- | --- | --- | --- |
| `flutter_animate` | `^4.5.2` | **Wired** (re-exported by `design_system.dart`) | Declarative entrance/motion effects across the design system (`foundations/motion.dart`'s `.entrance()` helpers). |
| `showcaseview` | `^5.1.0` | **Wired** | Onboarding coach-marks / feature tour (`lib/features/additional_feature/showcase_view/`). |
| `flutter_svg` | `^2.3.0` | **Wired** (through FlutterGen's `SvgGenImage`) | Renders the spec glyphs in `assets/svg/` through `Glyph` (`components/dx_icons.dart`), §9. |
| `cached_network_image` | `^3.4.1` | **Wired** | Remote-icon fallback in `AppIconAvatar` (`app_icon_avatar.dart`, used by blocklist tiles + the reel-counter card). App icons ship **locally** in `assets/images/social_icon_pack/` as 160² quantised PNGs; this only handles `http…` `iconUrl`s from remote config. Note it drags `flutter_cache_manager` → `sqflite` → the `sqflite_android` native plugin. |
| `intl` | `^0.20.2` | **Wired** (2 files) | Number/date formatting and localisation-safe strings. |

---

## 6. User feedback

| Package | Version | Status | Role in Detoxo |
| --- | --- | --- | --- |
| `feedback` | `^3.2.0` | **Wired** (5 files) | In-app feedback capture (annotate-a-screenshot flow) in `lib/features/additional_feature/app_feedback`. |
| `flutter_email_sender` | `^10.0.1` | **Wired** | Sends the captured feedback via the device email client to **errorxperts@gmail.com**. |
| `webview_flutter` | `^4.13.0` | **Wired** | In-app browser for the hosted **Privacy Policy** / **Terms & Conditions** pages, rendered in the app's `GlassScaffold` via the reusable `LegalWebViewScreen` (`lib/features/help/legal`). JavaScript is enabled (the pages route by URL fragment). Android-only in practice (iOS shows the unsupported screen). See [20-help-support.md](20-help-support.md). |
| `upgrader` | `^13.5.0` | **Wired** | Play Store version-check engine behind the in-app "update available" prompt (`lib/features/additional_feature/app_upgrader`). Used **only** as the engine — scrape latest version, compare, persist Later/Skip, launch store — the UI is the app's own glass dialog. Android-only, fails closed. Pulls `shared_preferences` / `url_launcher` / `http` transitively for its own use. See [21-app-upgrader.md](21-app-upgrader.md). |

---

## 6a. Firebase telemetry (Analytics · Crashlytics · Performance)

Wired in this build — the app's one **off-device** data path, isolated under
`lib/core/services/firebase/` behind interfaces. See
[19-firebase-telemetry.md](19-firebase-telemetry.md).

| Package | Version | Status | Role in Detoxo |
| --- | --- | --- | --- |
| `firebase_core` | `^4.11.0` | **Wired** | `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` in `main.dart` (config in `lib/firebase_options.dart`). |
| `firebase_analytics` | `^12.4.3` | **Wired** | Screen views (`FirebaseAnalyticsObserver` on the router) + semantic usage events, behind `AnalyticsService`. |
| `firebase_crashlytics` | `^5.2.4` | **Wired** | Fatal handlers, cubit-error capture, `AppLogger.e` non-fatals, context keys — behind `CrashReportingService`. |
| `firebase_performance` | `^0.11.4+3` | **Wired** | Manual `traceAsync` custom traces (e.g. `load_block_targets`) behind `PerformanceService`. The auto-trace Gradle plugin is **not** applied — incompatible with AGP 9 (see doc 19). |
| `uuid` | `^4.5.3` | **Wired** | Generates the anonymous per-install id (`StoreKeys.installId`) set as the Analytics/Crashlytics user id. |

> Collection is **on in every build** (no debug gate); data is anonymised (privacy rules in doc 19).
> A consent / opt-out surface is a follow-up.

---

## 7. Declared but NOT wired (scaffolds / swap-ins / native-owned)

These packages are in `pubspec.yaml` but have **zero import sites in `lib/`**. They
are placeholders for planned capabilities, or the responsibility is handled on the
native side / by another package. Treat them as follow-ups, not live behaviour.

| Package | Version | Why it's inert today | Cost of keeping it | Correct framing |
| --- | --- | --- | --- | --- |
| `drift` | `^2.33.0` | No relational DB in the Dart tree; `LocalStore` uses a Hive `Box<String>` instead. | **~1.63 MB per user.** Its transitive `sqlite3` compiles `libsqlite3.so` from source into every ABI. | Swap-in for a future relational store. Planned / follow-up. |
| `sqlite3_flutter_libs` | `^0.6.0+eol` | Only meaningful with `drift`; unused. Its own README says *"Starting from version 0.6.0, this package no longer does anything."* | 0 bytes — pure noise. | Ships with the `drift` scaffold. Planned / follow-up. |
| `flutter_local_notifications` | `^22.0.0` | No Dart notification code. The persistent service notification is created **natively** (channel `detoxo_protection_channel`, `NOTIF_ID 1125`). It is also why core-library desugaring is enabled in `build.gradle.kts`. | Registered Android plugin → native code + manifest entries merge in regardless, plus ~157 KB of `j$.time` in `classes.dex` from the desugaring it forces. | Swap-in for future Dart-scheduled notifications. Planned / follow-up. |
| `app_settings` | `^7.0.0` | The package (`package:app_settings`) is never imported; grep hits are the unrelated `AppSettings` domain entity. Settings screens are opened via the native MethodChannel (`openAccessibilitySettings`, `openUsageAccessSettings`, …) and `permission_handler`. | Registered Android plugin. | Redundant / follow-up cleanup candidate. |
| `collection` | `^1.19.1` | No direct import found; available transitively via `freezed_annotation`. | 0 bytes. | Utility dep; not directly consumed. |

> When any of these graduates from "declared" to "wired", update this table **and**
> the corresponding feature doc so the two stay in sync.

### Removed

| Package | Why it went | Reclaimed |
| --- | --- | --- |
| `workmanager` | Nothing in `lib/` used it, and `androidx.work` merged `FOREGROUND_SERVICE` / `WAKE_LOCK` / `RECEIVE_BOOT_COMPLETED` / `ACCESS_NETWORK_STATE` into the manifest Play reads. Background work is the native accessibility service. | manifest surface |
| `google_mobile_ads`, `in_app_purchase` | Would declare Advertising ID + Billing to Play while the in-app FAQ promises "no ads, no ad tracking". | — |
| `cupertino_icons` | `CupertinoIcons` is referenced zero times; it only ever shipped a font asset for an unused API. | icon font entry |
| `dio` | No HTTP client is instantiated anywhere. This build is offline-first with no backend; `upgrader` brings its own client for the Play version check. | dex / AOT |
| `liquid_swipe` | Onboarding uses a `PageView`-style flow; `LiquidSwipe` was imported nowhere. | dex / AOT |
| `ms_undraw` | No `UnDraw` usage — every illustration is a local asset. | dex / AOT |
| `lottie_tgs` | Nothing rendered a Lottie file anywhere in `lib/`. The unreferenced `assets/lottie/` folder (25 JSON, 4.86 MB install / ~0.59 MB download) was deleted too (Frozen Glass M13). | dex / AOT |
| `flutter_gen` | A build-time CLI mis-declared as a runtime dependency — see §2. | dex / AOT |
| `sleek_circular_slider` | Its one user, the old dashboard hero's countdown ring, went with the Today rebuild: a live Pause now counts down in the `TimeLeftRing` (the design system's `ProgressRing`). | dex / AOT |
| `flutter_floating_bottom_bar` | Its one user, the old hide-on-scroll home bar, went with the Frozen Glass shell: `HomeShell` floats the static glass `AppTabBar` (`components/navigation.dart`) in the `GlassScaffold`'s bottom-bar slot, with no scroll listener. | dex / AOT |
| `google_fonts` | Manrope 600/700/800 is bundled (§9), so the generated `AppTypography` names the family directly: no runtime font fetch, and widget tests no longer stall on one. | dex / AOT |
| `cupertino_native` | Its one user, `AdaptiveSlider` (a native `CNSlider` on iOS/macOS), went when the sliders moved to the themed Material `Slider`; iOS only shows the `UnsupportedScreen` ([15](15-ios-cross-platform.md)). `lib/core/design_system/adaptive/` (`AdaptiveSlider`, `PlatformAdaptive`) was deleted with it (Frozen Glass M12). | iOS plugin + dex / AOT |
| `not_static_icons` | The animated Lucide icons (`foundations/animated_icons.dart`: `AppAnimatedIcon`, the `AppIcon` catalogue, `AnimatedIconButton`, `EmptyState.animatedIcon`) lost their last users to the Frozen Glass `Icon3d` / `Glyph` set and Material icons, and were deleted with the package (Frozen Glass M12). | dex / AOT |

Re-add any of these only when something actually imports them.

---

## 8. Dev dependencies (build, lint, test)

| Package | Version | Role |
| --- | --- | --- |
| `flutter_test` (sdk) | — | Widget/unit test harness. |
| `integration_test` (sdk) | — | End-to-end integration tests. |
| `flutter_driver` (sdk) | — | Host side of the perf run. Pulled in transitively by `integration_test`, but declared because `test_driver/perf_driver.dart` imports it directly (`depend_on_referenced_packages`). Only `flutter drive` can read `binding.reportData`, which is why the frame timeline cannot come from `flutter test`. |
| `lints` | `^6.1.0` | Dart core/recommended lint set (extended in `analysis_options.yaml`). |
| `flutter_lints` | `^6.0.0` | Flutter-specific lints layered on `lints`. |
| `build_runner` | `^2.15.0` | Code-gen driver for freezed/json/drift. |
| `freezed` | `^3.2.6-dev.1` | Generates `*.freezed.dart` for the config models. |
| `json_serializable` | `^6.14.0` | Generates `*.g.dart` JSON serializers. |
| `drift_dev` | `^2.33.0` | Drift generator — inert (no drift tables defined). Pairs with the unused `drift` runtime dep. Removing all three is worth ~1.63 MB per user; see §7. |
| `bloc_test` | `^10.0.0` | Testing utilities for Cubits. |
| `mocktail` | `^1.0.5` | Mocking in tests (no codegen). |
| `flutter_launcher_icons` | `^0.14.4` | Generates launcher/adaptive icons (see §9). |

---

## 9. Assets & launcher-icon configuration

**Bundled asset roots** (declared under `flutter.assets`):

- `assets/config/` — offline-first config JSON (`platforms_config.json`,
  `initial_config.json`; loaded as `AppConstants.bundledPlatformsConfig` /
  `bundledInitialConfig`).
- `assets/content/` — only the block screen's motivational quotes
  (`motivational_quotes.json`, read natively by `overlay/QuoteBook.kt`). The five emoji-band
  JSONs and `mindful_timer_quotes.json` went with the unmounted emoji/quote engine
  (Frozen Glass M13; [05](05-plans-pause-conscious.md) §8).
- `assets/images/` — no longer an asset root, only the parent of `icons/` and
  `social_icon_pack/` below. Its two logo files went in Frozen Glass M12 once the splash, the
  onboarding hero and the block screen (Dart and native) all drew `icons/detoxo-logo.webp`:
  `Detoxo_logo.png` (1,463,289 B) and `detox_logo_no_bg.webp` (12,658 B).
- `assets/fonts/OFL.txt` — Manrope's licence, registered on the licence page by
  `LicenseRegistry.addLicense` in `main()`. The three font files (all upstream
  Version 4.504) are declared under `flutter.fonts` as family **`Manrope`**
  (`Manrope-SemiBold.ttf` 600, `Manrope-Bold.ttf` 700, `Manrope-ExtraBold.ttf` 800).
  They carry the app's type ramp — the generated `AppTypography`
  (`lib/core/design_system/tokens/app_tokens.g.dart`), which every `TextTheme` slot
  maps to (600–800; a 400/500 request falls back to 600) — and the home-widget and
  bubble text (700/800). One copy serves Flutter and the native renderers, which
  read them from `flutter_assets/assets/fonts/` through `widget/Manrope.kt`
  (`semiBold`, `bold`, `extraBold`; [17](17-content-counter.md) §5.2).
- `assets/images/icons/` — the Frozen Glass **3D icons**, byte copies of the design-system
  artifact's 192² WebPs (≈ 9–16 KB each): `icon-block-all`, `icon-conscious`, `icon-pause`,
  `icon-one-reel` (the four modes, hue-shifted to the live accent), `icon-app-blocker`,
  `icon-web-blocker`, `icon-blocker-rules`, plus `icon-reel-count` (256², the Session sheet's
  By reel count header) and `detoxo-logo.webp` (100×192, never recoloured). Drawn only through
  `Icon3d` / `DetoxoLogo` (`components/dx_icons.dart`), never cropped: the mode card, the blocker
  tiles, the rules row, the ConfirmSheet and Session sheet headers and the feature tour's badges.
- `assets/svg/` — the spec's single-ink **glyphs** (24 × 24 SVGs, drawn `srcIn` by `Glyph`):
  `check` (the success toast, the confirmed knob), `chevron-right` (list and drawer rows, the
  rules row), `chevrons-right` (the ready slide knob), `flame` (the streak), `lock` / `lock-open`
  (the ring's Block now / Unblock pill), `play-circle` (the reels line) and `sidebar` (the tab
  header's Menu button).
- `assets/images/illustration/` — **removed** (Frozen Glass C12). The 23 512² hero illustrations
  (≈ 700 KB) lost their last users when the mode selector, the old blocker tiles and the feature
  tour moved to the 3D icons above.
- `assets/images/social_icon_pack/` — bundled app icons: one icon per app
  (`<base>.png`, a white glyph on the app's brand-colored tile) plus `a.png`–`z.png`
  letter-tile fallbacks, all **160² quantised PNG**. Rendered by `AppIconAvatar`
  (`app_icon_avatar.dart`).
- `assets/lottie/` — **removed** (Frozen Glass M13). Nothing rendered its 25 Lottie files
  (4.86 MB install).

**These are all *directory* entries**, so anything dropped into one of these folders
ships to every user forever. Keep build-time inputs (launcher-icon artwork, design
sources) **outside** `assets/` — see §9's note on `tool/branding/`.

> **Format rule.** Artwork reached only through a FlutterGen accessor → **WebP**
> (`cwebp -q 80 -m 6 -alpha_q 100 -resize <2×max-dp> 0`), because the accessor name
> is extension-free and no call site changes. Artwork reached by a *string* — the
> `social_icon_pack`, whose paths appear in `platforms_config.json` `iconUrl`s and in
> `'$_iconPackDir$letter.png'` — stays **PNG**, downscaled and quantised with
> `pngquant`, so the wire format stays compatible with remote config.

`uses-material-design: true` bundles the Material Icons font — tree-shaken to
~16 KB in the release bundle. See [22-play-release.md](22-play-release.md#artifact-size).

**Launcher icons** (`flutter_launcher_icons` block): source
`tool/branding/detoxo_app_icon.png` for both the legacy icon and the adaptive
foreground, on a `#1E4DE5` background (sampled from the artwork's outer rim, so
the corners the adaptive/iOS mask cuts away blend instead of showing a seam).
The foreground keeps the package default 16% inset — the artwork is full-bleed
and its glyph gets clipped inside the adaptive safe zone without it.
`remove_alpha_ios: true` flattens iOS onto the same `#1E4DE5`. Regenerate with
`dart run flutter_launcher_icons`. (iOS is generated but the app is **not
supported on iOS** — see [00-index.md](00-index.md).)

The source artwork lives in `tool/branding/`, **not** `assets/`. It is a build-time
input: the generated icons land in `android/app/src/main/res/**` (which Play
density-splits), so shipping the 1254² source inside `flutter_assets` too was
costing every user 2.3 MB for a file no code ever loads. Any future design source
belongs in `tool/branding/` for the same reason.

---

## Source files

- `pubspec.yaml`
- `lib/core/storage/local_store.dart`
- `lib/core/di/injector.dart`
- `lib/core/services/firebase/firebase.dart`
- `lib/core/services/firebase/firebase_services.dart`
- `lib/features/permissions/data/repositories/permission_repository_impl.dart`
- `lib/features/access_protection/domain/pin_hasher.dart`
- `lib/features/blocking/shared/data/models/initial_config_model.freezed.dart`
- `lib/features/blocking/shared/data/models/initial_config_model.g.dart`
- `lib/features/blocking/shared/data/models/platform_config_model.freezed.dart`
- `lib/features/blocking/shared/data/models/platform_config_model.g.dart`
- `lib/gen/assets.gen.dart`
- `tool/design/gen_design_tokens.dart`, `tool/design/{tokens,recipes}.json`, `tool/tokens_common.dart`, `build.yaml`
- `lib/core/design_system/tokens/app_tokens.dart` (+ generated `app_tokens.g.dart`), `android/app/src/main/kotlin/com/errorxperts/detoxo/overlay/DxTokens.kt` (generated)
- `lib/core/design_system/components/dx_icons.dart` (`Icon3d`, `Glyph`, `DetoxoLogo` — the only widgets that draw `assets/images/icons/` and `assets/svg/`)
- `lib/core/design_system/components/navigation.dart` (`AppTabBar`, which replaced `flutter_floating_bottom_bar`)
- `lib/features/onboarding/presentation/onboarding_screen.dart`
- `lib/features/blocking/blocklist/presentation/widgets/block_app_tile.dart`
- `lib/main.dart`
- `lib/features/content_counter/content_counter_core/domain/brand_tint.dart` — pure `BrandTint` (the theme primary's hue at fixed lightness per role, for the bubble's and widgets' 0-reel look), mirrored by Kotlin `widget/BrandTint.kt` and pinned by `test/fixtures/brand_tints.json`
- `lib/features/content_counter/content_counter_bubble/domain/bubble_model.dart` — pure `BubbleModel` (+ `TierChange`), mirrored in Kotlin and pinned by `test/fixtures/bubble_cases.json`
- `lib/features/content_counter/content_counter_bubble/presentation/` — `bubble_tokens.g.dart` (generated by `tool/home_widget/gen_tokens.dart`), `svg_path`, `bubble_look`, `bubble_frame`, `bubble_brush`, `bubble_face`, `bubble_painter`, `bubble_preview` and `faces/*_face.dart` ×6 (the floating-bubble preview; it moved here from `content_counter_appearance/presentation/widgets/bubble_preview.dart`, which is deleted, along with `formatBubbleClock`)
