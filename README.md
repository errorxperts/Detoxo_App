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
(enforced by `tool/check_boundaries.sh`; pre-existing violations are grandfathered in
`tool/boundaries_baseline.txt` — new ones fail).

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
    access_protection/     PIN setup + lock (no recovery) (data/domain/presentation)
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
features together. Run `bash tool/check_boundaries.sh` to enforce this (there is no CI yet; `bash tool/dev.sh precommit` runs it).

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
bash tool/dev.sh precommit   # format + analyze + test + boundaries — the whole gate
flutter analyze              # clean
flutter test                 # 188 unit/widget tests across 25 files
```

### QA automation
Three layers behind one driver. Layer 1 is host-only; the rest need an attached Android device.
```bash
bash tool/qa.sh functional          # = dev.sh precommit
bash tool/qa.sh -d <serial> e2e     # real-boot walk (app.main()) + screenshots -> build/qa/shots/
bash tool/qa.sh -d <serial> perf    # cold start + frame timeline + memory + apk size, vs a baseline
bash tool/qa.sh -d <serial> blocking # accessibility-engine smoke (half manual)
bash tool/qa.sh restore             # put accessibility + stay-awake back as they were
```
Artifacts land in `build/qa/`. Run configurations for **Android Studio**
(`.idea/runConfigurations/`) and **VS Code** (`.vscode/launch.json` + `tasks.json`) are checked in
and drive the same script.

Runbooks: [`docs/code_docs/23-testing-runbook.md`](docs/code_docs/23-testing-runbook.md) (human) ·
`.claude/skills/detoxo-auto-test/SKILL.md` (agent, `/detoxo-auto-test`).

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
| Ads | **None** — the ads/billing SDKs were removed (see `docs/code_docs/11-monetization.md`) |
| Analytics / notifications | ✅ local block-event history; **Firebase Analytics + Crashlytics + Performance are bundled and live** (anonymous, collection unconditional — an opt-out is the main open gap) |

### Swap in real services (config points)
- **Backend API** — implement a remote `ConfigRepository`. Base URL belongs in `core/config/`. (PIN recovery is deliberately *not* on this list: a client-side recovery code is a lock bypass, not a recovery, so the OTP stub was removed rather than wired. See `docs/code_docs/08-pin-lock-recovery.md`.)
- **Firebase** — already wired (`google-services.json`, `firebase_options.dart`, Crashlytics/GMS Gradle plugins). Still open: a telemetry consent/opt-out toggle, and FCM push.
- **AdMob** — nothing to swap: the SDK, the test App ID and the `AD_ID` permission were all removed. Re-adding is a deliberate act that must also correct the in-app "no ads" copy.
- **Play Billing** — implement `PremiumRepositoryImpl.purchase/restore` against Play Console products. The `in_app_purchase` dependency was removed (nothing used it, and it declared Billing to Play); re-add it as part of that work. See `docs/code_docs/11-monetization.md`.
- **Release signing** — done: `android/app/build.gradle.kts` loads `android/key.properties` (gitignored) and falls back to debug signing with a warning when absent. Build the upload artifact with `bash tool/dev.sh release`.

---

## Native ↔ Dart channels

- MethodChannel `com.errorxperts.detoxo/commands` — `pushConfig`, `pushSettings`,
  permission checks/launchers, `performBack`, `killApp`, `lockScreen`, `blockStats`.
- EventChannel `com.errorxperts.detoxo/events` — `serviceStatus`, `blocked` events.

## Compliance notes
Shipping an AccessibilityService on Google Play requires a qualifying use + a prominent in-app
disclosure (implemented in `permission_actions.dart`, shown before the grant). Device-admin
uninstall protection and overlays have their own policy/OEM constraints.

Note that Android 13+ **restricted settings** / 15+ **ECM** block the accessibility and overlay
toggles for sideloaded installs — expected, not a bug, and handled in-app with a "Fix this"
walkthrough. Play installs are exempt.

The declaration text, data-safety answers and the signed-`.aab` build steps live in
[`docs/code_docs/22-play-release.md`](docs/code_docs/22-play-release.md); broader status in
[`docs/code_docs/16-implementation-roadmap.md`](docs/code_docs/16-implementation-roadmap.md).
