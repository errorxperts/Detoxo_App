# Monetization (premium & ads)

> **Status up front: nothing here is live.** Detoxo ships with premium, ads, and
> billing *modelled* but not *wired*. There is **no live Google Play Billing**,
> **no ad is ever loaded or shown**, and there is **no functioning dev-unlock UI**.
> Everything documented below is either (a) a parsed-but-unconsumed config field,
> (b) inert UI scaffolding, or (c) a reserved storage key. Treat the whole area as
> a **swap-in / follow-up** surface. Where the code implies a feature that does not
> actually run, this doc says so explicitly.

There is deliberately **no `lib/features/monetization/` module**. Premium is not a
feature with data/domain/presentation layers; it exists only as a handful of fields
scattered across the blocking config models, one design-system pill, one reserved
`StoreKeys` constant, and some Android manifest metadata.

---

## 1. What actually exists (map)

| Concern | Where it lives | Live? |
| --- | --- | --- |
| Entitlement / plan model | `ActivePlanDetailsModel` in `initial_config_model.dart` | Parsed, **never consumed** |
| Per-feature premium gate | `FeatureFlagModel.premiumOnly` | Parsed, **never consumed** |
| Per-platform premium gate | `PlatformModel.premiumExclusive` → `BlockTarget.premiumExclusive` | Carried into the domain entity, **never read** |
| Upgrade CTA | `PromoCtaModel premiumPurchaseCTA` | Parsed, **never consumed** |
| Ad slot config | `Map<String, AdSlotModel> admobConfig` | Parsed, **never consumed** |
| Premium-exclusive notices | `InAppNotificationModel.premiumExclusive` | Parsed, **never consumed** |
| Dev-unlock flag | `StoreKeys.premiumDevUnlock` (`'premium_dev_unlock'`) | **Declared only** — no read/write, no UI |
| "Premium" lock pill | `AdaptiveSwitchTile.locked` → `Pill(label: 'Premium')` | Scaffolding, **never triggered** |
| Premium/crown icon | `AppIcon.premium` → `CrownIcon` | Defined, **never referenced** |
| AdMob app id | `AndroidManifest.xml` meta-data (Google **test** id) | Metadata only, no init |
| Ads SDK | `google_mobile_ads` (pubspec) | Plugin auto-registered, **dormant** |
| Billing SDK | `in_app_purchase` (pubspec) + `com.android.vending.BILLING` perm | **Unused** — no Dart code |

---

## 2. The premium entitlement model (config-only)

Premium is described entirely by data in `initial_config.json`, deserialized by the
freezed models in `initial_config_model.dart`. It is loaded through
`ConfigRepositoryImpl` (offline-first, from the bundled asset
`AppConstants.bundledInitialConfig`).

### `ActivePlanDetailsModel` — the entitlement shape

```dart
const factory ActivePlanDetailsModel({
  @Default(false) bool aiFeatures,
  @Default(false) bool blockAds,
  @Default(false) bool premiumFeatures,
  @Default(false) bool parentalFeatures,
  @Default(false) bool topTierPlan,
  @Default(true)  bool promptUpgrades,
  @Default(<String>[]) List<String> plans,
}) = _ActivePlanDetailsModel;
```

This is the model for "what is the signed-in user entitled to." In the bundled
config every flag is `false` (except `promptUpgrades: true`) and `plans` is empty —
i.e. a free/guest user. **Nothing in the app reads `activePlanDetails`.** There is no
entitlement service, no `isPremium` getter, and no cubit that exposes it.

### `FeatureFlagModel.premiumOnly` — per-feature gate

```dart
const factory FeatureFlagModel({
  required String featureId,
  @Default(0)   int minOSVersion,
  @Default(999) int maxOSVersion,
  @Default('')  String params,
  @Default(true)  bool enabled,
  @Default(false) bool premiumOnly,   // <- the gate
}) = _FeatureFlagModel;
```

Feature flags arrive as `featuresAvailability: Map<String, FeatureFlagModel>`
(bundled examples: `smart_mode`, `memory_warning`, `feed_blocker`,
`reels_by_friends`). The `premiumOnly` bit is the intended "this flag requires a
paid plan" marker — but the map is **never read** by any feature. There is no
flag-evaluation seam that combines `enabled` + `premiumOnly` + `activePlanDetails`.

### `PlatformModel.premiumExclusive` → `BlockTarget.premiumExclusive`

This is the **only** premium field that flows out of the config layer into the
domain layer. `ConfigRepositoryImpl._toTarget(...)` copies it onto the
`BlockTarget` domain entity:

```dart
// config_repository_impl.dart
return BlockTarget(
  ...
  premiumExclusive: platform.premiumExclusive,
  ...
);
```

But `BlockTarget.premiumExclusive` is a **dead read**: nothing consumes it. The
blocklist tile (`block_app_tile.dart`) builds an `AdaptiveSwitchTile` from a target
and never passes `locked:` — so a "premium-exclusive" platform renders as a normal,
fully-usable toggle. No app or platform is actually gated at runtime.

### `PromoCtaModel premiumPurchaseCTA` — upgrade CTA

```dart
const factory PromoCtaModel({
  @Default('') String id, @Default('') String title, @Default('') String desc,
  @Default('') String cta, @Default('') String whatsNew, @Default(false) bool active,
}) = _PromoCtaModel;
```

Intended to drive an "Upgrade" banner/paywall. **Never rendered** — no widget reads
`premiumPurchaseCTA`. See the config-hygiene follow-up in §6: the bundled value for
this field still carries the *previous* app's branding and must be rewritten before
any paywall is switched on.

### What the repository actually consumes

For completeness: `ConfigRepositoryImpl.loadNotices()` is the *only* consumer of
`InitialConfigModel`, and it maps **only** `inappNotification[]` into `AppNotice`
entities. Every premium/ad field (`admobConfig`, `activePlanDetails`,
`premiumPurchaseCTA`, `featuresAvailability`, `warningMessages`) is deserialized and
then dropped. (The bundled JSON also contains keys the model does **not** declare —
`adsConfig`, `videoConfig`, `inhouseNativeAdConfig` — which `fromJson` silently
ignores.)

---

## 3. The local dev-unlock (`premium_dev_unlock`)

`StoreKeys.premiumDevUnlock` is defined in `local_store.dart`:

```dart
static const String premiumDevUnlock = 'premium_dev_unlock';
```

That is the **entire** implementation. This key:

- is **never written** anywhere in the codebase,
- is **never read** anywhere in the codebase,
- has **no Settings → Developer screen** behind it — the settings feature contains
  no "developer", "unlock", "premium", or "upgrade" affordance at all.

So the intended flow ("flip a local flag in a hidden Developer menu to unlock
premium for testing") is **not implemented**. The constant is a reserved seam only.

**To make it real (swap-in):** add a Developer section in
`lib/features/settings/presentation/settings_screen.dart` that toggles
`localStore.write(StoreKeys.premiumDevUnlock, 'true')`, expose an `isPremium`
entitlement resolver that reads this key (OR `ActivePlanDetails`), and have the
gating call sites in §4 consult it. None of that plumbing exists yet.

Storage backend: `premium_dev_unlock` would live in the plain (non-secret) Hive box
`detoxo` via `LocalStore.read/write` — it is a non-secret UI flag, not a secret.
See [09-persistence-data-model.md](09-persistence-data-model.md).

---

## 4. Premium gating in the UI (inert scaffolding)

The design system ships the *visual* language for gating, but nothing drives it.

### `AdaptiveSwitchTile.locked`

`lib/core/design_system/components/list_tiles.dart` defines a switch row that swaps
its trailing switch for a lock pill when `locked` is `true`:

```dart
final trailing = locked
    ? const Pill(label: 'Premium', tone: AppTone.warning, icon: Icons.lock_outline)
    : AdaptiveSwitch(value: value, onChanged: onChanged, enabled: enabled);
return GlassListTile(
  ..., trailing: trailing, onTap: locked ? onLockedTap : null,
);
```

`locked` defaults to `false`. Across **all** ~15 call sites (settings, blocklist,
web blocker, content-counter appearance, PIN setup) **none pass `locked: true`** and
none pass `onLockedTap`. The "Premium" pill and its tap handler therefore never
appear in the shipped app. Wiring `locked: target.premiumExclusive` (plus a resolved
entitlement) is the intended hook — see §2 for the missing read.

### `Pill(label: 'Premium')`

The reusable status chip (`lib/core/design_system/components/badges.dart`,
`class Pill`) supports a `'Premium'` label with `AppTone.warning`. It is a generic
component ("Required" / "Premium" / "Active"); the only premium usage is the inert
`AdaptiveSwitchTile.locked` branch above.

### `AppIcon.premium` / `CrownIcon`

`lib/core/design_system/foundations/animated_icons.dart` registers
`AppIcon.premium → CrownIcon`. `AppIcon.premium` / `CrownIcon` are **not referenced
anywhere** outside their own declaration — a ready-to-use crown glyph for a future
paywall, currently unused.

---

## 5. AdMob & billing wiring (present but dormant)

### AndroidManifest

`android/app/src/main/AndroidManifest.xml` declares:

```xml
<!-- AdMob test App ID (swap for your real App ID for release). -->
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-3940256099942544~3347511713"/>
```

`ca-app-pub-3940256099942544~3347511713` is **Google's public sample/test AdMob app
id**, not a real Detoxo publisher id. The manifest also declares the ad/billing
permissions:

- `com.google.android.gms.permission.AD_ID`
- `com.android.vending.BILLING`

### Dart / plugin state

| Package (pubspec) | State |
| --- | --- |
| `google_mobile_ads: ^8.0.0` | `GoogleMobileAdsPlugin` is auto-registered in `GeneratedPluginRegistrant`, but **no Dart code imports it**. There is no `MobileAds.instance.initialize()`, no `BannerAd`/`InterstitialAd`, no ad widget. The SDK is present and dormant. |
| `in_app_purchase: ^3.3.0` | **No Dart usage at all** — no `InAppPurchase`, no product query, no purchase stream. No native `BillingClient` code either. |

So: **no ad is initialized or loaded**, and **no purchase flow can be started**.
The bundled `admobConfig` in `initial_config.json` maps ad-slot paths (e.g.
`/home/dashboard/banner`) to `AdSlotModel { adTag, adType }`, but since nothing reads
`admobConfig` those slots are never realized.

**Swap-in checklist (ads):** replace the manifest app id with the real publisher id,
call `MobileAds.instance.initialize()` at bootstrap (`lib/main.dart`), build ad
widgets that resolve unit ids from `admobConfig`, and gate them on
`ActivePlanDetails.blockAds` (ad-free entitlement).

**Swap-in checklist (billing):** implement an `in_app_purchase` (or RevenueCat)
repository, map SKUs → `plans` in `ActivePlanDetails`, persist the resulting
entitlement, and replace the reserved `premium_dev_unlock` dev path (§3) as the sole
unlock mechanism for release builds.

---

## 6. Config-hygiene follow-up (bundled data still carries old-app values)

The bundled `assets/config/initial_config.json` was carried over from the prior
codebase and still contains **stale, previous-app values** in the monetization
fields. Because nothing consumes these fields today it is harmless at runtime, but it
**must be corrected before any paywall/ads are switched on**:

- `premiumPurchaseCTA` — its `id`, `desc`, and `whatsNew` copy still reference the
  **previous app's brand name**, not "Detoxo". Rewrite before showing an upgrade CTA.
- `admobConfig` ad units are under a **third-party publisher account**
  (`ca-app-pub-1071824559641088/…`), i.e. **not** Detoxo's and **not** the Google
  test ids in the manifest. Replace with Detoxo's own ad units (or test ids) before
  enabling ads.

Treat both as **infra / config follow-ups**, analogous to the leftover legacy
config strings noted elsewhere (the app-icon URLs are already fixed — icons now
ship locally in `assets/images/social_icon_pack/`). Do not go live on this bundled data.

---

## 7. Summary

- Premium is a **data model + inert UI scaffolding**, not a working feature.
- **No entitlement is ever evaluated**; `activePlanDetails`, `premiumOnly`,
  `premiumExclusive`, `premiumPurchaseCTA`, and `admobConfig` are all
  parsed-then-dropped (only `inappNotification` is consumed).
- **`premium_dev_unlock` is a declared key with zero read/write and no Developer UI.**
- **AdMob** = Google test app id in the manifest + a dormant, auto-registered plugin;
  **no ad is initialized or loaded**.
- **Billing** = `in_app_purchase` dependency + `BILLING` permission; **no code**.
- Making any of this real is a discrete swap-in; see the checklists in §3 and §5, and
  the config-hygiene fixes in §6. Related: config loading in
  [10-networking-config-sync.md](10-networking-config-sync.md), the `BlockTarget`
  entity in [02-detection-config-schema.md](02-detection-config-schema.md), storage
  keys in [09-persistence-data-model.md](09-persistence-data-model.md), and the
  package inventory in [14-flutter-package-map.md](14-flutter-package-map.md). For the
  user-facing framing, see ../info_docs/00-index.md.

---

## Source files

- `lib/core/storage/local_store.dart` (`StoreKeys.premiumDevUnlock` = `premium_dev_unlock`)
- `lib/core/constants/app_constants.dart` (billing/ad-id "swap without touching feature code" note)
- `lib/features/blocking/shared/data/models/initial_config_model.dart` (`ActivePlanDetailsModel`, `FeatureFlagModel.premiumOnly`, `PromoCtaModel premiumPurchaseCTA`, `AdSlotModel`, `admobConfig`, `InAppNotificationModel.premiumExclusive`)
- `lib/features/blocking/shared/data/models/platform_config_model.dart` (`PlatformModel.premiumExclusive`)
- `lib/features/blocking/shared/domain/entities/block_target.dart` (`BlockTarget.premiumExclusive`)
- `lib/features/blocking/shared/data/repositories/config_repository_impl.dart` (copies `premiumExclusive`; consumes only `inappNotification`)
- `lib/core/design_system/components/list_tiles.dart` (`AdaptiveSwitchTile.locked` → `Pill('Premium')`)
- `lib/core/design_system/components/badges.dart` (`Pill`)
- `lib/core/design_system/foundations/animated_icons.dart` (`AppIcon.premium` → `CrownIcon`)
- `lib/features/blocking/blocklist/presentation/widgets/block_app_tile.dart` (uses `AdaptiveSwitchTile`, never `locked`)
- `assets/config/initial_config.json` (bundled `admobConfig` / `activePlanDetails` / `premiumPurchaseCTA` — carries stale old-app values)
- `pubspec.yaml` (`google_mobile_ads: ^8.0.0`, `in_app_purchase: ^3.3.0`)
- `android/app/src/main/AndroidManifest.xml` (AdMob test `APPLICATION_ID`, `AD_ID` + `com.android.vending.BILLING` permissions)
- `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java` (`GoogleMobileAdsPlugin` auto-registration)
