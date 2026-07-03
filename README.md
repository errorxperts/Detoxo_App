# Detoxo (Flutter)

A short-form–content blocker built in **Flutter + flutter_bloc + Clean Architecture**, with a
native **Android AccessibilityService** engine. It detects Reels / Shorts / infinite feeds in other
apps and pulls you out (Back / close / lock), plus blocking plans, pause, PIN lock, app/website
blockers, daily limit, premium gating and analytics.

Full documentation lives in [`docs/`](docs/): [`docs/code_docs/`](docs/code_docs/00-index.md)
(engineering reference, written from this source) and
[`docs/info_docs/`](docs/info_docs/00-index.md) (end-user & marketing). When you change a
feature, update its mapped doc — see [`CLAUDE.md`](CLAUDE.md) and run `/docs-sync`.

---

## Architecture

**Feature-first + Clean Architecture.** Each feature is self-contained with its own
`data / domain / presentation` layers; cross-feature code talks only through a feature's public
barrel (`features/<x>/<x>.dart`) or its `domain/` contracts — never another feature's internals
(enforced by `tool/check_boundaries.sh`).

```
lib/
  app/                     composition root: main wiring, splash, unsupported(iOS) screen
  core/                    infra reused by 2+ features
    di · navigation · network · storage · platform_channels · theme · constants · error · utils · widgets
  features/
    blocking/              ── CORE bounded context ──
      shared/              domain (AppSettings, BlockTarget, enums, repo contracts) + data (models, repo impls)
      engine/  presentation (ServiceCubit, live status)
      blocklist/ presentation (TargetsCubit, blocklist UI)
      plans/   domain (session phase rules) + data (content) + presentation (pause, countdown)
    limits/                app_blocker · web_blocker · daily_limit   (each: data/domain/presentation)
    access_protection/     PIN setup/lock/recovery        (data/domain/presentation)
    monetization/premium/  subscriptions + entitlement     (data/domain/presentation)
    analytics/             block-event history             (data/domain/presentation)
    permissions/           permission funnel               (data/domain/presentation)
    onboarding/ settings/ dashboard/   presentation-only orchestration surfaces
android/app/src/main/kotlin/com/errorxperts/detoxo/
  accessibility/   DetoxoAccessibilityService.kt   ← the detection + block engine (hot path)
  channels/        CommandHandler (MethodChannel) · DetoxoEventStream (EventChannel)
  engine/          ConfigStore · DetectionConfig · ServiceEventBus
  receivers/ admin/  BootReceiver · DetoxoDeviceAdminReceiver
```

Dependency rule: `presentation → domain ← data` inside a feature; a feature may depend on `core/*`
and on another feature's `domain/` (contracts + entities) only. Composition roots
(`app/`, `core/di`, `core/navigation`, `dashboard`, `settings`) are the only places allowed to wire
features together. Run `bash tool/check_boundaries.sh` in CI to enforce this.

**The hot path runs natively** (per-package 150 ms throttle → active-plan gate → 3-stage view-id
detection, max 12 000 nodes → block with a 1200 ms debounce / 1100 ms back rate-limit). Dart owns
configuration, settings and UI; settings are persisted natively (`ConfigStore`) so the service reads
them even when the UI process is gone. Native → Dart status/detection events flow over an
`EventChannel`; Dart → native commands over a `MethodChannel`.

---

## Run it

Requirements: Flutter 3.44+, Android SDK 35, a device/emulator (Android **only** — iOS shows an
“unsupported” screen because there is no AccessibilityService equivalent).

```bash
flutter pub get
dart run build_runner build      # generates freezed / json models
flutter run                      # or: flutter build apk --debug
```

On the device: **Onboarding → Permissions** → grant **Accessibility** + **Display over apps**
(required) → **Dashboard**. Toggle platforms on the **Blocklist** tab; pick a plan; the foreground
notification confirms the service is alive.

> Real reel/short blocking needs a **physical device with the target apps installed**
> (Instagram, YouTube, …). On a bare emulator you can verify the service starts, the UI/status,
> config parsing, plans and navigation — but not live blocking, since those apps aren’t present.

### Tests / analysis
```bash
flutter analyze     # clean
flutter test        # domain unit tests (enums, pause math, lockout ladder, daily reset)
```

---

## What works offline (this build) vs. needs your accounts

This build is **offline-first**: it runs fully standalone with no backend.

| Area | Status in this build |
|---|---|
| Reel/Short detection + block (Accessibility) | ✅ Native engine, works on a real device |
| Blocking plans (Block-all / Curious / One-reel / Paused) + pause | ✅ Plan + pause window honored by the engine |
| Blocklist (data-driven from bundled `platforms_config.json`) | ✅ |
| PIN lock + biometric + retry lockout | ✅ (`local_auth` + secure storage) |
| Daily limit / app blocker / web blocker | ✅ UI + persistence; **native enforcement of app/web/usage is a follow-up** (the v1 native engine focuses on the reel/short view-id path) |
| Premium gating | ✅ via local **dev-unlock** (Settings → Developer); real Play Billing is a swap-in |
| Ads | Wired with Google **test** ad-unit IDs |
| Analytics / notifications | ✅ local; Firebase is optional, not bundled |

### Swap in real services (config points)
- **Backend API** — implement a remote `ConfigRepository` / OTP calls (`PinRepositoryImpl.sendRecoveryOtp/validateOtp`, currently a documented dev code `000000`). Base URL belongs in `core/config/`.
- **Firebase** — add `android/app/google-services.json` + the Firebase plugins, then back `AnalyticsRepository` / FCM with it.
- **AdMob** — replace the test App ID in `AndroidManifest.xml` (`ca-app-pub-3940256099942544~3347511713`) and the test ad-unit IDs with yours.
- **Play Billing** — implement `PremiumRepositoryImpl.purchase/restore` with `in_app_purchase` + Play Console products.
- **Release signing** — add a keystore + `signingConfig` in `android/app/build.gradle.kts`.

---

## Native ↔ Dart channels

- MethodChannel `com.errorxperts.detoxo/commands` — `pushConfig`, `pushSettings`,
  permission checks/launchers, `performBack`, `killApp`, `lockScreen`, `blockStats`.
- EventChannel `com.errorxperts.detoxo/events` — `serviceStatus`, `blocked` events.

## Compliance notes
Shipping an AccessibilityService on Google Play requires a qualifying use + a prominent in-app
disclosure. Device-admin uninstall protection and overlays have their own policy/OEM constraints.
See [`docs/code_docs/16-implementation-roadmap.md`](docs/code_docs/16-implementation-roadmap.md).
