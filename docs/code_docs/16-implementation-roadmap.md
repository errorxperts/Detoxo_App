# Status & Roadmap

The honest "what actually runs in this build vs. what needs your accounts / a follow-up" for
**Detoxo** (`com.errorxperts.detoxo`). Authored from the shipped source, not aspirations.

Bottom line: this is an **Android-only** build whose config is **offline-first** (bundled assets, no
custom backend) with **no live billing/ads**. It does bundle a **Firebase telemetry layer**
(Analytics / Crashlytics / Performance) — the one path that sends data off-device; see
[19-firebase-telemetry.md](19-firebase-telemetry.md). The native detection/block engine is real and
works on a physical device; the network-, account-, and store-dependent layers are deliberately left
as clearly-marked swap-in points. iOS is unsupported (see
[15-ios-cross-platform.md](15-ios-cross-platform.md)).

---

## 1. What works in this build

These are wired end-to-end and enforced by the native engine or Dart runtime — no external service
required.

| Area | Status | Where |
|---|---|---|
| Reel/Short detection + block (AccessibilityService) | **Works on a real device** — 3-stage view-id detection, `PRESS_BACK`/`KILL_APP`/`LOCK_SCREEN`/`NONE` block modes, native throttle/debounce/rate-limit | [03-detection-engine.md](03-detection-engine.md), `DetoxoAccessibilityService.kt` |
| Blocking plans (`blockAll` / `curious`=**Conscious** / `oneReel` / `paused`) + pause window | **Honored by the engine** — `activePlan` gate + `pauseUntil` clock window + Conscious time-bank accountant | [05-plans-pause-conscious.md](05-plans-pause-conscious.md) |
| Web blocklist enforcement | **Wired natively** — `WebBlockEngine` reads the browser address bar in the hot path, matches wildcards, presses Back with per-host debounce, records stats | [06-app-and-web-blocker.md](06-app-and-web-blocker.md), `engine/WebBlockEngine.kt` |
| Content counter (decoupled from blocking) + bubble + home-screen widget | **Works** — side-effect-free counting pass runs even when blocking is off; drives overlay bubble + `home_widget` | [17-content-counter.md](17-content-counter.md) |
| Blocklist (data-driven) | **Works** — parsed from bundled `assets/config/platforms_config.json`; per-platform enable/disable persisted natively | [02-detection-config-schema.md](02-detection-config-schema.md) |
| PIN lock + biometric + retry-lockout ladder | **Works** — `local_auth` + `flutter_secure_storage`. **No recovery channel by design**; the `000000` dev backdoor was removed, not wired | [08-pin-lock-recovery.md](08-pin-lock-recovery.md) |
| Analytics (block-event history) | **Works, local only** — capped in-memory/JSON block-event buffer (recent ~100); no cloud sink | [12-analytics-notifications-resilience.md](12-analytics-notifications-resilience.md) |
| Firebase telemetry | **Wired** — Analytics (screen views + usage events), Crashlytics, Performance; anonymised, collection on in every build | [19-firebase-telemetry.md](19-firebase-telemetry.md) |
| Persistence | **Works, on-device only** — Dart `local_store` + native `detoxo_engine_prefs` + secure storage + widget keys `cc_today`/`cc_total` | [09-persistence-data-model.md](09-persistence-data-model.md) |
| Config load | **Works, offline** — bundled JSON assets via `ConfigRepositoryImpl`; no live fetch | [10-networking-config-sync.md](10-networking-config-sync.md) |

> Note vs. the top-level `README.md` status table: the README groups "app/web/usage native
> enforcement" as a single follow-up. That is conservative — in the actual code the **web blocklist
> path is already wired natively** (`WebBlockEngine` is instantiated in the service and invoked on
> the browser branch of `onAccessibilityEvent`). What remains a follow-up is **full-app blocking**
> and **daily-limit / usage enforcement** (see §2).

---

## 2. Native enforcement scope (v1) — what is *not* enforced yet

The v1 native engine focuses on the **reel/short view-id path** plus **web host blocking**. Two
limit features are UI + persistence in Dart with **no native enforcement yet**:

| Feature | What exists | What's missing (follow-up) |
|---|---|---|
| **App blocker** (`lib/features/limits/app_blocker`) | Full UI, blocked-app selection, Dart persistence; `killApp(pkg)` exists but only as a **reel block *mode***, not standalone app enforcement | `ConfigStore` has **no blocked-apps package set**; the service never bounces a fully-blocked app on foreground. Needs: push a blocked-package list to the engine + a foreground-package guard in `onAccessibilityEvent` |
| **Daily limit** (`lib/features/limits/daily_limit`) | Full UI, quota math, reset logic, Dart persistence, unit-tested | `ConfigStore` has **no daily-limit/usage keys**; native does only permission checks (`hasUsageAccess`), no `UsageStats` polling or quota-triggered block. Needs: usage sampling + a native quota gate |

The reason web works but app/usage don't: web blocking needs only the *host string already on
screen* (cheap, in-tree), whereas full-app and usage enforcement need a package-level allow/deny
model and usage sampling the engine doesn't carry yet. See
[06-app-and-web-blocker.md](06-app-and-web-blocker.md) and
[07-daily-limit-scheduler.md](07-daily-limit-scheduler.md).

---

## 3. Swap-in points (needs your accounts / infra)

Every external dependency is isolated behind a repository or a single config value so it can be
replaced without touching feature code.

### Backend API (config)
- **Config:** `ConfigRepositoryImpl` (`lib/features/blocking/shared/data/repositories/config_repository_impl.dart`)
  reads bundled JSON assets. A remote refresh is a documented swap-in — implement a networked
  `ConfigRepository` and point a base URL at it (README notes `core/config/` as the home for
  base URLs / product ids). No live endpoint is bundled.
- **PIN recovery is deliberately not a swap-in.** The old `_devOtp = '000000'` stub — which
  `validateOtp` accepted against any email, with the code shown to the user — was **removed**.
  A client-side code is a lock bypass, not a recovery, so there is nothing here to wire later.
  Reinstalling is the documented escape hatch. See [08-pin-lock-recovery.md](08-pin-lock-recovery.md).

### Firebase / FCM
- **Telemetry is now bundled.** `android/app/google-services.json`, `lib/firebase_options.dart`, and
  the google-services + Crashlytics Gradle plugins are wired; Analytics, Crashlytics and Performance
  are live (see [19-firebase-telemetry.md](19-firebase-telemetry.md)). Performance runs with **manual
  traces only** — the auto-trace Gradle plugin is omitted (its 1.4.2 release is incompatible with
  AGP 9). Collection is unconditional — a **consent / opt-out gate is the main follow-up** (see §6).
- **Still swap-ins:** FCM push is not bundled, and the local `AnalyticsRepository` block-event buffer
  has no cloud sink (it stays on-device).

### Play Billing / Premium & AdMob — SDKs removed
- `in_app_purchase` and `google_mobile_ads` were **deleted from `pubspec.yaml`**, along with the
  `BILLING` / `AD_ID` permissions and the Google **test** AdMob App ID in the manifest. Nothing
  imported either SDK, but shipping them declared Advertising ID and Billing to Play while the
  in-app FAQ promised "no ads, no ad tracking" — a data-safety contradiction, plus a test ad id in a
  production listing. Re-add deliberately, with real ad units and corrected in-app copy, when
  monetization is actually built. See [11-monetization.md](11-monetization.md) §5.

### Release signing & build — done
- `android/app/build.gradle.kts` loads a real keystore from the gitignored `android/key.properties`,
  registering the signing config **only when that file exists** (an unguarded cast previously broke
  configuration for *all* build types on a fresh clone). Missing keystore → debug signing + a warning.
- `bash tool/dev.sh release` builds the signed `.aab` with `--obfuscate --split-debug-info` and
  refuses to run without the keystore. See [22-play-release.md](22-play-release.md).
---

## 4. Premium, ads & billing — honest state

The README status table shows "Premium gating ✅ via local dev-unlock". In the **current source
that is scaffolding only**, so be precise:

- **No `lib/features/monetization` / premium feature directory exists.** There is no entitlement
  model, no premium gating, and no dev-unlock UI wired into any screen.
- The only premium artifact is a single constant `LocalStore.premiumDevUnlock = 'premium_dev_unlock'`
  in `lib/core/storage/local_store.dart` — **declared but referenced nowhere else** in `lib/`.
- `in_app_purchase` and `google_mobile_ads` are **declared dependencies with registered plugins but
  zero Dart call sites** (no `InAppPurchase`, no `MobileAds.instance.initialize()`, no ad widgets).
- The manifest carries billing/ad-id permissions + the AdMob **test** App ID.

Net: premium, ads, and billing are **dependency- and manifest-level scaffolding**, not a working
feature in this build. Treat monetization as greenfield (repository + entitlement gate + UI) rather
than a swap of existing wiring. See [11-monetization.md](11-monetization.md).

---

## 5. Testing strategy

### Dart (runs today: `flutter test`)
Twelve domain/logic unit tests under `test/` — pure Dart, no device needed. They cover the exact
places business rules live:

| Test | Covers |
|---|---|
| `test/domain_test.dart` | Core enums / domain invariants |
| `test/app_settings_test.dart` | `AppSettings` model |
| `test/plans_pause_curious_test.dart` | Pause-window math + `curious`/Conscious plan logic |
| `test/usage_ladder_test.dart` | PIN retry-lockout ladder |
| `test/access_protection_test.dart` | PIN setup / verify flow |
| `test/web_blocker_test.dart` | Web blocklist wildcard matching |
| `test/blocklist_install_filter_test.dart` | Installed-app filtering of the blocklist |
| `test/counter_style_test.dart` | Content-counter appearance/style |
| `test/app_feedback_test.dart` | Feedback report building |
| `test/core/services/firebase/firebase_bloc_observer_test.dart` | Cubit-state → analytics events + Crashlytics keys |
| `test/core/services/firebase/native_event_reporter_test.dart` | Native events → analytics + reel batching + host omission |
| `test/core/services/firebase/analytics_service_test.dart` | Semantic analytics API → Firebase event mapping |

`flutter analyze` is clean.

### Boundary / architecture check
`tool/check_boundaries.sh` enforces the feature-isolation rule (a feature may import another
feature's public barrel or `domain/`, never its `data/`/`presentation/`).
**Fixed (Aug 2026).** The script used to grep a pre-rebrand package prefix, so it matched nothing
and passed vacuously from the rename onward. It now greps `package:detoxo/` and genuinely enforces
the rule. Repairing it surfaced 12 pre-existing violations, grandfathered in
`tool/boundaries_baseline.txt`; anything new fails the build.

### Native (Kotlin)
- **No instrumented/unit tests are bundled** for the engine. The detection/block hot path is
  validated manually on a device.
- **Real reel/short blocking requires a physical device with the target apps installed**
  (Instagram, YouTube, …). On a bare emulator you can verify the service starts, status/config
  parsing, plans, and navigation — but not live blocking, since those apps aren't present.

---

## 6. Compliance & policy notes

Shipping this app has real Play Store policy obligations. None of these are optional for a store
release.

- **AccessibilityService use + prominent disclosure.** Google Play requires a qualifying use for
  `BIND_ACCESSIBILITY_SERVICE` **plus a prominent in-app disclosure** of what the service does with
  on-screen content. The app ships a disclosure string in
  `android/app/src/main/res/values/strings.xml` (`accessibility_service_description`: it detects
  short-form video and blocks it, "reads on-screen content only to find and block distracting
  feeds; it does not collect or transmit your screen content") and the permission funnel explains
  the grant. Keep the disclosure prominent, accurate, and shown **before** requesting the grant.
- **Special-use foreground service.** The service runs in the **main process** as a
  `FOREGROUND_SERVICE_TYPE_SPECIAL_USE` FGS with a persistent notification (channel
  `detoxo_protection_channel`, id `1125`). The manifest declares
  `PROPERTY_SPECIAL_USE_FGS_SUBTYPE`; Play requires a justification for the special-use subtype.
- **Device admin.** `DetoxoDeviceAdminReceiver` (uninstall protection + `lockNow`) is subject to
  device-admin policy and OEM behavior; use it sparingly and disclose it.
- **Overlays.** The content-counter bubble uses `SYSTEM_ALERT_WINDOW` (Display over apps) with a
  `TYPE_APPLICATION_OVERLAY` → `TYPE_PHONE` fallback — its own policy/OEM constraints apply.
- **`QUERY_ALL_PACKAGES` — removed.** `queryLaunchablePackages()` only needs the manifest's
  `<queries>` MAIN entry, so the restricted permission (and its Console declaration) was dropped
  entirely.
- **Restricted settings / ECM.** Android 13+/15+ block the accessibility, overlay and device-admin
  toggles for non-Play installs. Handled in-app with a detection + walkthrough flow;
  `android:isAccessibilityTool` **stays unset** (Detoxo is not an assistive tool — claiming
  otherwise to dodge the gate is a policy violation). See
  [13-onboarding-permissions.md](13-onboarding-permissions.md) §3.4.
- **Data collection disclosure (Play Data safety / GDPR).** The app now sends anonymised usage
  analytics, crash reports, and performance traces to Firebase
  ([19-firebase-telemetry.md](19-firebase-telemetry.md)). This must be declared in the Play **Data
  safety** form and the privacy policy, and — depending on region/consent rules — may require an
  in-app consent or opt-out control, which is **not yet built** (collection is currently
  unconditional). No PII is sent; the user id is a random install UUID.

---

## 7. Known infra follow-ups (grab-bag)

- **Inherited vendor strings in bundled config — done.** `platforms_config.json` `iconUrl`s point
  at bundled local assets. `assets/config/initial_config.json` was rewritten: the inherited
  notification ids, prior-vendor CTA PDF, community link and dead package references, the
  third-party `inhouseNativeAdConfig` promo and the foreign `admobConfig` ad units are all gone.
  `assets/content/pause_countdown_pause_emojis.json` was rebranded too (6 user-visible strings).
  The repo now contains **zero** prior-app / prior-vendor names in any file, folder, asset or doc
  — including the orphaned `android/*.iml` IDE module file, which was deleted.
- **Boundary check package prefix — done.** Repointed at the real package. Fixing it revealed **12
  pre-existing violations** the gate had never caught (it had matched nothing since the rebrand).
  They are grandfathered in `tool/boundaries_baseline.txt` and reported as warnings; anything new
  fails. Most share one root cause — `settings_cubit` is cross-cutting but only reachable through
  `blocking/shared/presentation/`. **Burn the list down.**
- **Telemetry consent / opt-out** — still the main open compliance gap (§6).
- **Release signing** (see §3) — replace debug signing.
- **Backend + OTP + FCM + Billing + real ads** — remaining §3 swap-ins (Firebase telemetry is wired;
  a telemetry consent/opt-out gate is the follow-up).

---

## Source files

- `README.md`
- `pubspec.yaml`
- `tool/check_boundaries.sh`
- `test/domain_test.dart`, `test/app_settings_test.dart`, `test/plans_pause_curious_test.dart`, `test/usage_ladder_test.dart`, `test/access_protection_test.dart`, `test/web_blocker_test.dart`, `test/blocklist_install_filter_test.dart`, `test/counter_style_test.dart`, `test/app_feedback_test.dart`
- `lib/core/storage/local_store.dart`
- `lib/features/blocking/shared/data/repositories/config_repository_impl.dart`
- `lib/features/access_protection/data/repositories/pin_repository_impl.dart`
- `lib/features/analytics/data/repositories/analytics_repository_impl.dart`
- `lib/features/limits/app_blocker/`, `lib/features/limits/daily_limit/`, `lib/features/limits/web_blocker/`
- `lib/features/settings/presentation/settings_screen.dart`
- `lib/main.dart`
- `lib/core/services/firebase/` (Firebase telemetry layer — see [19-firebase-telemetry.md](19-firebase-telemetry.md))
- `android/app/build.gradle.kts`
- `android/settings.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/res/values/strings.xml`
- `android/app/src/main/kotlin/com/errorxperts/detoxo/accessibility/DetoxoAccessibilityService.kt`
- `android/app/src/main/kotlin/com/errorxperts/detoxo/engine/ConfigStore.kt`
- `android/app/src/main/kotlin/com/errorxperts/detoxo/engine/WebBlockEngine.kt`
- `android/app/src/main/kotlin/com/errorxperts/detoxo/channels/CommandHandler.kt`
- `assets/config/platforms_config.json`, `assets/config/initial_config.json`
