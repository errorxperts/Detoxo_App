# Detection Config Schema (platforms_config / initial_config / calibration)

This document is the exhaustive, field-by-field specification of the **data-driven configuration** that powers the short-form-content blocker. The detection engine never hard-codes which apps to block: it is told by JSON. Three config trees exist — (1) `platforms_config.json` (the master "what app → what view IDs → how to block" map, bundled in `res/raw` and refreshed from the server), (2) `initial_config.json` (feature flags, ad units, version gating, in-app notifications, premium CTA), and (3) the **calibration config** fetched per-device from `POST /getCalibrationConfig` (pixel/margin "zones" for in-app webview content that has no accessibility view-ids). This doc gives the complete schema, the real enum value sets, the literal OVERLAY `params` sub-JSON, ~10 representative platforms verified in the JSON, and clean Dart `freezed` + `json_serializable` models for the entire tree, so a new Flutter app can deserialize and consume the exact same server payloads.

> **Legend:** ✅ = a pub.dev package handles it in Dart · ⚠️ = needs a native MethodChannel/EventChannel · ❌ = not possible on iOS.

---

## 1. The three config sources

| Config | Where it lives | How it is loaded | Purpose |
|---|---|---|---|
| **platforms_config** | `resources/res/raw/platforms_config.json` (bundled fallback) **and** server (`PlatformConfigResponse`) | Bundled JSON shipped as a seed; server response overrides it; gated by `configVersion` | Master map: apps → platforms → detectors (view-id rules) → block modes |
| **initial_config** | `resources/res/raw/initial_config.json` + server | Fetched at startup; merged into app state | Feature flags, AdMob unit map, version availability, in-app notifications, premium CTA, tutorial video ids |
| **calibration config** | server only: `POST /getCalibrationConfig` (`CalibrationConfigRequest` → `CalibrationConfigResponse`) | Fetched with device width/height + installed app versions; cached under `CALIBRATION_CONFIG` key | Device-specific pixel zones for `CALIBRATION` detection (in-app YouTube, browsers, FB Lite, etc.) |

**Flutter mapping:**
- Network fetch → ✅ `dio` (or `http`) + `retrofit` for typed clients.
- JSON → typed models → ✅ `freezed` + `json_serializable`.
- Persisting the cached config → ✅ `hive` / `drift` / `shared_preferences` (store the raw JSON string or the typed model).
- Reactive push to the detection layer → ✅ `flutter_bloc` (emit a `ConfigLoaded` state carrying the parsed tree).
- The detection engine that *consumes* the config (accessibility tree walk) → ⚠️ native + `flutter_accessibility_service`. **iOS:** ❌ no AccessibilityService; only `FamilyControls`/`ManagedSettings` token-level app shielding, which cannot read view-ids — calibration/legacy detection is Android-only.

---

## 2. `platforms_config.json` — complete schema

Verified against `resources/res/raw/platforms_config.json` (`configVersion: 32`, `responsecode: 200`).

### 2.1 Top-level envelope (`PlatformConfigResponse`)

| Field | Type | Meaning | Example (literal) |
|---|---|---|---|
| `responsecode` | int | HTTP-style status of the payload; `200` = usable | `200` |
| `message` | string | Server status text | `"Success"` |
| `configVersion` | int | Monotonic version; client hot-reloads when server > stored | `32` |
| `featuredApps` | map<packageName, AppDetails> | The whole app catalogue, keyed by Android package name | `{"com.google.android.youtube": {...}}` |
| `updateMessage` | string | Optional toast/banner text when a new config exists | `""` |
| `updateIcon` | string | Optional icon URL for that banner | `""` |

> Verified key spelling: it is `responsecode` (all lowercase, no separator) and `configVersion` (camelCase). `featuredApps` keys are real Android package names, **except** synthetic keys used for in-app webviews, e.g. `"com_google_android_youtube"` (underscores) for *In-App YouTube*.

### 2.2 `AppDetails` (value of each `featuredApps` entry)

| Field | Type | Meaning | Example |
|---|---|---|---|
| `packageName` | string | Android package (or synthetic in-app key) | `"com.instagram.android"` |
| `appName` | string | Human label | `"Instagram"` |
| `actionOnLaunch` | enum `AppLockAction` | What to do the instant the app opens (before any reel) | `"NONE"` / `"KILL_APP"` |
| `paramsClass` | int | App-level params discriminator; `-1` = none | `-1` |
| `params` | string (JSON) | App-level extra params; `"{}"` when unused | `"{}"` |
| `priority` | int | Catalogue ordering / detection precedence (0 highest) | `0` … `52` |
| `iconUrl` | string | Remote icon | `"https://curizic.com/NoScroll/icons/ic_yt_shorts.png"` |
| `premiumExclusive` | bool | Whole app is a premium-only target | `true` for *In-App YouTube*, *YouTube Music* |
| `minAppVersion` | long | Min installed app version to apply rules; `-1` = any | `-1` |
| `maxAppVersion` | long | Max installed app version; `-1` = any | `-1` |
| `supportInAppYtShorts` | bool | This app embeds a YouTube webview that can show Shorts | `true` (X, LinkedIn, Reddit, browsers) |
| `platforms` | list<Platform> | The detectable surfaces inside this app | `[ {ig_feed}, {ig_reel}, … ]` |
| `showInDashboard` | bool | Show this app on the home dashboard | `true` |
| `showIfNotInstalled` | bool | Show even when not installed (discovery) | `true` for YouTube, Instagram |
| `appOpenActions` | list<AppOpenAction> | Quick deep-link shortcuts shown for the app | YouTube → Search, Subscriptions |
| `browser` | bool | App is a web browser (enables web/canonical-host detection) | `true` for Opera, Jio Web |

### 2.3 `Platform` (each entry of `AppDetails.platforms`)

| Field | Type | Meaning | Example |
|---|---|---|---|
| `platformId` | string | Stable unique id for the surface | `"yt_shorts"`, `"ig_feed"`, `"ig_reel"` |
| `platformName` | string | Human label | `"YouTube Shorts"` |
| `packageName` | string | Owning package (mirrors parent) | `"com.google.android.youtube"` |
| `iconUrl` | string | Remote icon | `…/ic_yt_shorts.png` |
| `detectors` | map<ViewDetector, Detector> | Detection rules keyed by detector type; `{}` for CALIBRATION/learned | `{"FINDBYID": {...}}` |
| `manualConfig` | map<EnumDeviceConfig, ManualConfig> | Width-breakpoint rules for `MANUAL` detection; `{}` if unused | `{}` |
| `detectionType` | enum `DetectionType` | Which algorithm to use | `"LEGACY"`, `"CALIBRATION"`, `"OVERLAY"` |
| `defaultStatus` | bool | Whether this surface is blocked by default | `true` / `false` |
| `customizable` | bool | User may toggle/edit this surface | `true` (Instagram "Allow Reels By Friends" = `false`) |
| `showInDashboard` | bool | Show this platform row in dashboard | `true` |
| `showAlwaysInBlockList` | bool | Pin into the block list regardless of install state | `true` for core reels surfaces |
| `premiumExclusive` | bool | Surface requires premium | `true` for `ig_feed` (OVERLAY) |

> Note the field is `showAlwaysInBlockList` at the platform level (vs `showIfNotInstalled` at the app level). `manualConfig` is present in the schema but **empty (`{}`) in every entry** of the shipped JSON.

### 2.4 `Detector` (value of each `detectors` map entry)

The `detectors` map is keyed by a **`ViewDetector` enum string** (`FINDBYID`, `VIEWID_RES_NAME`, `CONT_DESC`, `BROWSER`). Each value:

| Field | Type | Meaning | Example |
|---|---|---|---|
| `identifiers` | list<string> | The view-ids / resource-names / content-descriptions to match | `[":id/reel_player_underlay"]` |
| `supportedBlockModes` | list<enum `BlockingMode`> | Block modes the user may pick for this detector | `["PRESS_BACK","KILL_APP"]` |
| `defaultBlockMode` | enum `BlockingMode` | Mode applied if user hasn't chosen | `"PRESS_BACK"` (TikTok: `"KILL_APP"`) |
| `priority` | int | Order within the platform (lower first) | `0` … `3` |
| `childNodeLimit` | int | Max nodes to descend in the subtree search; `-1` = unlimited | `-1`, `500` (Snapchat Stories res-name) |
| `actionOnLaunch` | enum `AppLockAction` | Detector-level launch action | `"NONE"` |
| `paramsClass` | int | Discriminator for `params` JSON: `0` = none, `1` = OVERLAY (Instagram custom) | `0` / `1` |
| `params` | string (JSON) | The OVERLAY sub-JSON when `paramsClass == 1`, else `""` | see §2.6 |
| `message` | string | Optional block message | `""` |
| `detectionParams` | `AdditionalDetectionParams`? | Extra accessibility attribute filters; usually `null` | `null` |
| `haltOnDetect` | bool | Stop scanning siblings/other detectors once matched | `true` |
| `coupleWith` | list<string> | Chain: only act if these platformIds also matched; empty everywhere shipped | `[]` |

> `supportsOverlay` is part of the runtime detector model (see `DetectedReelConfig` / web detection) but is **not** present as a literal key in the shipped `detectors{}` objects — it is derived (e.g. web/OVERLAY ⇒ `supportsOverlay = true`).

### 2.5 `AdditionalDetectionParams` (nullable enrichment on a detector)

Used to add accessibility-attribute constraints beyond the bare id match. `null` in all shipped LEGACY detectors, but the schema exists and is reused by calibration (`PlatformHolder.detectionParams`).

| Field | Type | Meaning |
|---|---|---|
| `paramId` | string | The view id this param block applies to |
| `focusable` | bool | Require `isFocusable` |
| `visibleToUser` | bool | Require `isVisibleToUser` |
| `text` | string | Match node text |
| `exactText` | bool | Exact vs contains for `text` |
| `description` | string | Match content-description |
| `exactDescription` | bool | Exact vs contains for `description` |
| `viewId` | string | Secondary view id |
| `className` | string | Require node `className` |

### 2.6 OVERLAY `params` sub-JSON (`paramsClass == 1`) — the Instagram-Feed custom config

Verified literal value of `featuredApps["com.instagram.android"].platforms[ig_feed].detectors.FINDBYID.params` (it is a **string** containing escaped JSON). Parsed, it is:

```json
{
  "primary_id": ":id/media_group",
  "config": {
    "curious_support": true,
    "block_all_support": true,
    "overlay_support": false,
    "blackout_message": ""
  },
  "footer": {
    "primary_footer": ":id/feed_tab",
    "blackout_footer": ":id/feed_tab"
  },
  "header": {
    "primary_header": ":id/action_bar_title_view",
    "blackout_header": ":id/outer_container"
  },
  "primary_addons": [
    ":id/carousel_media_group"
  ],
  "secondary": [
    {
      "id": ":id/inline_follow_button",
      "location": 0
    }
  ]
}
```

Field-by-field:

| Path | Type | Meaning | Example |
|---|---|---|---|
| `primary_id` | string (view id) | The anchor node identifying a feed item to cover/blur | `":id/media_group"` |
| `config.curious_support` | bool | Allow "curious" (peek) plan behaviour on this surface | `true` |
| `config.block_all_support` | bool | Allow full block-all on this surface | `true` |
| `config.overlay_support` | bool | Render a system overlay vs back-press | `false` |
| `config.blackout_message` | string | Text drawn on the blackout overlay | `""` |
| `header.primary_header` | string (view id) | Top anchor that overlay should leave visible | `":id/action_bar_title_view"` |
| `header.blackout_header` | string (view id) | Top anchor for blackout-mode bound | `":id/outer_container"` |
| `footer.primary_footer` | string (view id) | Bottom anchor (e.g. tab bar) overlay should leave visible | `":id/feed_tab"` |
| `footer.blackout_footer` | string (view id) | Bottom anchor for blackout-mode bound | `":id/feed_tab"` |
| `primary_addons` | list<string> | Extra item containers that also count as feed items | `[":id/carousel_media_group"]` |
| `secondary[]` | list<{id, location}> | Secondary controls to suppress; `location` is a position hint (0 = inline) | `[{":id/inline_follow_button", 0}]` |

> The overlay rendering of this block is ⚠️ native (`WindowManager TYPE_APPLICATION_OVERLAY`) or ✅ `flutter_overlay_window`. **iOS:** ❌ no system overlay over other apps.

### 2.7 `ManualConfig` / `DisplayParams` (width-breakpoint detection, schema-only here)

`manualConfig` is `{}` everywhere shipped, but the schema is:

| Object | Field | Type | Meaning |
|---|---|---|---|
| `ManualConfig` | `width` | list<float> | Width breakpoints (px/dp) defining responsive buckets |
| `ManualConfig` | `small` / `default` / `large` / `larger` / `largest` | `DisplayParams` | Per-bucket coordinate params |
| `ManualConfig` | `platformId` | string | Owning platform |
| `DisplayParams` | `x` | list<float> | X-axis thresholds for that bucket |

The map key is `EnumDeviceConfig` (`MOBILE` / `TABLET` / `LANDSCAPE` / `LANDSCAPE_TABLET`).

### 2.8 `AppOpenAction` (quick links)

| Field | Type | Meaning | Example |
|---|---|---|---|
| `name` | string | Button label | `"Search"`, `"Subscriptions"` |
| `url` | string | Deep link / URL to open | `"https://www.youtube.com/feed/subscriptions"` |

Only YouTube ships actions; every other app has `appOpenActions: []`.

---

## 3. `initial_config.json` — complete schema

Verified against `resources/res/raw/initial_config.json` (`platformConfigVersion: 32`).

### 3.1 Top-level

| Field | Type | Meaning |
|---|---|---|
| `versionAvailability` | object | App-update gating (see 3.2) |
| `inappNotification` | list<Notification> | Soft in-app cards (feedback, rating, community…) |
| `warningMessages` | list<Notification> | Hard warnings (accessibility off, battery optimization) |
| `adsConfig` | object? | Legacy ad config; `null` here |
| `admobConfig` | map<placement, AdUnit> | AdMob unit ids keyed by UI placement path |
| `activePlanDetails` | object | Current subscription capabilities (see 3.4) |
| `inhouseNativeAdConfig` | object | Self-promo native ad (cross-promote LinkWall) |
| `premiumPurchaseCTA` | object | Home "Upgrade" card content |
| `videoConfig` | map<key, youtubeId> | Tutorial video ids (config access, plan selection, curious) |
| `featuresAvailability` | map<featureId, FeatureFlag> | Feature flags (see 3.3) |
| `platformConfigVersion` | int | Mirror of `platforms_config.configVersion` to keep them in sync |

### 3.2 `versionAvailability` → `versionInfo`

| Field | Type | Meaning | Example |
|---|---|---|---|
| `versionInfo.versionCode` | int | Latest build code | `93` |
| `versionInfo.versionName` | string | Latest version name | `"2.0.0_beta_1"` |
| `versionInfo.promptUpdate` | bool | Show optional update prompt | `true` |
| `versionInfo.forceUpdate` | bool | Block app until updated | `false` |
| `versionInfo.beta` | bool | Build is a beta | `true` |
| `versionInfo.changelog` | string | Release notes | `"1. Complete Revamp\r\n…"` |
| `warningCode` | string | Update banner code | `"UPDATE_PROMPT"` |
| `title` / `desc` / `icon` | string | Banner content | `"Update Available!"` |
| `available` | bool | Update exists | `true` |
| `beta` | bool | Banner is beta-channel | `false` |

### 3.3 `featuresAvailability` (each `FeatureFlag`)

Verified flags: `smart_mode`, `memory_warning`, `feed_blocker` (premium), `reels_by_friends`.

| Field | Type | Meaning | Example |
|---|---|---|---|
| `featureId` | string | Stable flag id | `"feed_blocker"` |
| `minOSVersion` | int | Min Android SDK | `0` |
| `maxOSVersion` | int | Max Android SDK | `999` |
| `params` | string | Flag-specific data (e.g. a view id) | `":id/reply_bar_edittext"` for `reels_by_friends` |
| `enabled` | bool | Flag on | `true` |
| `premiumOnly` | bool | Requires premium | `true` for `feed_blocker` |

### 3.4 `activePlanDetails` / ad config / CTAs

| Object | Field | Type | Meaning | Example |
|---|---|---|---|---|
| `activePlanDetails` | `aiFeatures` | bool | AI features unlocked | `false` |
| `activePlanDetails` | `blockAds` | bool | Ads suppressed | `false` |
| `activePlanDetails` | `premiumFeatures` | bool | Premium unlocked | `false` |
| `activePlanDetails` | `parentalFeatures` | bool | Parental controls unlocked | `false` |
| `activePlanDetails` | `topTierPlan` | bool | Highest tier | `false` |
| `activePlanDetails` | `promptUpgrades` | bool | Nudge to upgrade | `true` |
| `activePlanDetails` | `plans` | list | Owned plan ids | `[]` |
| `admobConfig[path]` | `adTag` | string | AdMob unit id | `"ca-app-pub-1071824559641088/6443357830"` |
| `admobConfig[path]` | `adType` | enum | `BANNER` / `LARGE_BANNER` / `REWARDED` | `"REWARDED"` |
| `inhouseNativeAdConfig` | `id`,`logo`,`title`,`desc`,`cta`,`target`,`active` | mixed | Self-promo ad | `target: "com.swarajyadev.linkprotector"` |
| `premiumPurchaseCTA` | `id`,`title`,`desc`,`cta`,`whatsNew`,`active` | mixed | Upgrade card | `cta: "Upgrade"` |
| `videoConfig` | `CONFIG_ACCESS_VID`,`PLAN_SELECTION_VID`,`CONFIG_CURIOUS_VID`,`STRESSED_DEVICE` | string | YouTube ids | `"--xp1ybU7Kw"` |

### 3.5 Notification objects (`inappNotification[]` and `warningMessages[]`)

Both arrays share one shape:

| Field | Type | Meaning | Example |
|---|---|---|---|
| `notificationId` | string | Stable id / path | `"/noscroll/accessibility"` |
| `title` | string | Card title | `"Accessibility Service Required"` |
| `description` | string | Body | `"NoScroll relies on Accessibility Service…"` |
| `cta` | string | Button label | `"Turn On"` |
| `priority` | int | Sort order (0 highest) | `0` |
| `ctaAction` | enum | Action type | `URL`, `NOTIFICATION`, `RATING`, `ACCESSIBILITY`, `BATTERY_OPTIMIZATION` |
| `ctaUrl` | string | URL or target package | `"https://forms.gle/…"` |
| `metadata` | string | Extra payload (often `"{}"`) | `"true"` |
| `expiry` | long (epoch ms) | Hide after this time | `4068124200000` |
| `icon` | string | Icon URL | `""` |
| `premiumExclusive` | bool | Show only to premium | `true` |
| `guestExclusive` | bool | Show only to guests | `true` |
| `dismissible` | bool | User can dismiss | `false` for hard warnings |

> `ctaAction` mapping in Flutter: `URL` → ✅ `url_launcher`; `RATING` → ✅ `in_app_review`; `NOTIFICATION` → ✅ `permission_handler`; `ACCESSIBILITY`/`BATTERY_OPTIMIZATION` → ⚠️ native intent (`Settings.ACTION_ACCESSIBILITY_SETTINGS`, `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`). **iOS:** ❌ no accessibility/battery intents.

---

## 4. Calibration config schema

Sourced from the decompiled calibration data classes (`network/data/calibrationconfig/...`). Used when `Platform.detectionType == CALIBRATION` and `detectors == {}` (the view-ids are unknown, so the server ships pixel zones instead). Fetched via `POST /getCalibrationConfig` with headers `isTablet`, `isFoldingPhone`.

### 4.1 Request — `CalibrationConfigRequest`

| Field | Type | Meaning |
|---|---|---|
| `width` | int | Device screen width (px) |
| `height` | int | Device screen height (px) |
| `deviceConfig` | string (`EnumDeviceConfig`) | `MOBILE` / `TABLET` / `LANDSCAPE` / `LANDSCAPE_TABLET` |
| `platforms` | map<platformId, InstalledPlatformConfig> | Installed app versions per platform |

`InstalledPlatformConfig`: `platformVersion` (long, installed app version), `version` (int, platform-config version).

### 4.2 Response — `CalibrationConfigResponse`

| Field | Type | Meaning |
|---|---|---|
| `responseCode` | int | `200` = success |
| `message` | string | Status text |
| `platforms` | map<platformId, PlatformConfigMetaData> | Calibration per platform |

### 4.3 `PlatformConfigMetaData`

| Field | Type | Meaning |
|---|---|---|
| `supportStatusEnum` | enum `SupportStatus` | `UPDATE_REQUIRED` / `NOT_SUPPORTED` / `FRESH` / `SUPPORTED` |
| `configVersion` | int | Version of this platform's calibration |
| `config` | map<string, map<string, PlatformHolder>> | Nested configs (by device class → variant) |

### 4.4 `PlatformHolder`

| Field | Type | Meaning |
|---|---|---|
| `version` | int | Calibration version |
| `name` | string | Platform name |
| `platformId` | string | Platform id |
| `config` | map<EnumDeviceConfig, PlatformCalibrationConfig> | Per device-class zone |
| `detectionParams` | `AdditionalDetectionParams` | Optional attribute filters (see §2.5) |
| `priority` | int | Precedence (lower first) |
| `coupleWith` | list<string> | Coupled platformIds |
| `haltOnDetect` | bool | Stop after match |
| `supportedBlockModes` | list<enum `BlockingMode`> | Allowed block modes |

### 4.5 `PlatformCalibrationConfig`

| Field | Type | Meaning |
|---|---|---|
| `width` | float | Zone width |
| `height` | float | Zone height |
| `constraints` | map<`CalibrationConstrainPosition`, double> | Margins: `TOP`/`BOTTOM`/`RIGHT`/`LEFT` |
| `minPlatformVersion` | int | Min installed app version |
| `maxPlatformVersion` | int | Max installed app version |
| `supportStatus` | string | Per-zone support status |
| `version` | int | Zone version |

### 4.6 `Constraints` (server) / `CalibrationConstraints` (UI)

- Server `Constraints`: a single `double` (e.g. right-margin). In `PlatformCalibrationConfig` the constraints are a **map** keyed by position enum → double.
- UI `CalibrationConstraints` (curious editor): `{ position: CalibrationConstrainPosition, margin: double }` — a **list** of these, easier for draggable handles.

### 4.7 Runtime view — `CalibratedConfig` / `DisplayConfig`

| Object | Field | Type | Meaning |
|---|---|---|---|
| `CalibratedConfig` | `x` | float | Left edge of the detect zone |
| `CalibratedConfig` | `width` | float | Zone width (right edge = `x + width`) |
| `CalibratedConfig` | `platformId`,`packageName` | string | Owner |
| `CalibratedConfig` | `supportedBlockActions` | list | Allowed actions |
| `CalibratedConfig` | `detectionParams` | `AdditionalDetectionParams` | Attribute filters |
| `CalibratedConfig` | `coupleWith` | list<string> | Coupled platforms |
| `CalibratedConfig` | `haltOnDetect` | bool | Stop after match |
| `CalibratedConfig` | `priority` | int | Precedence |
| `CalibratedConfig` | `supportsOverlay` | bool | Overlay allowed |
| `DisplayConfig` | `width`,`height` | int | Current screen size |
| `DisplayConfig` | `deviceConfig` | `EnumDeviceConfig` | Current device class |
| `DisplayConfig` | `metrics` | DisplayMetrics | ⚠️ native; in Flutter use `MediaQuery` |
| `DisplayConfig` | `calibratedConfig` | map<platformId, CalibratedConfig> | In-memory cache |

**Flutter:** all calibration *logic* is pure Dart ✅ (zone math, support-status gating). The *bounds* of the detected node (`getBoundsInScreen`) come from ⚠️ native accessibility; Dart receives them and runs the zone comparison. **iOS:** ❌ no node bounds available.

---

## 5. Enum tables (real value sets)

### 5.1 `DetectionType` (`DetectionTypeEnum`)

| Value | Meaning | Seen in JSON |
|---|---|---|
| `LEGACY` | Accessibility view-id tree match (default, fragile) | YouTube, Instagram Reels, TikTok, Snapchat… |
| `CALIBRATION` | Server-tuned pixel zones for view-id-less in-app webviews | In-App YouTube, FB Lite, Opera, Jio Web, CleanTube, PhysicsWala, Insta Lite |
| `OVERLAY` | Custom overlay/blackout using `paramsClass:1` sub-JSON | Instagram Feed (`ig_feed`) |
| `MANUAL` | Width-breakpoint coordinate rules (`manualConfig`) | (schema present; empty in shipped JSON) |
| `NONE` | No detection (allow-list/override) | used by allow surfaces |

### 5.2 `ViewDetector` (`ViewDetectorsEnum`)

| Value | Meaning | Match input | Example identifier |
|---|---|---|---|
| `FINDBYID` | Match `getViewIdResourceName()` against `pkg + identifier` | view id | `":id/reel_player_underlay"` |
| `VIEWID_RES_NAME` | Match full resource-entry name (not pkg-prefixed) | resource name | `"content_video_view"` (Reddit), `"context_vertical_actions/context_vertical_action_share"` (Snapchat) |
| `CONT_DESC` | Match node content-description text | localized strings | `"Add a comment…"` (Facebook, 17 locales) |
| `BROWSER` | Web/canonical-host match (strips scheme + `www.`/`m.`, wildcard subdomains) | host/path | reserved; web detection path |

### 5.3 `BlockingMode` (`BlockingModesEnum`) — ordinals matter

| Value | Ordinal | Action | Flutter |
|---|---|---|---|
| `PRESS_BACK` | 1 | `performGlobalAction(GLOBAL_ACTION_BACK)` | ⚠️ `flutter_accessibility_service` global action |
| `KILL_APP` | 2 | Force-stop the foreground app (`ActivityManager`) | ⚠️ native; needs privileged API |
| `LOCK_SCREEN` | 3 | Lock the device (DeviceAdmin `lockNow()`) | ⚠️ native DeviceAdmin |
| `NONE` | 4 | No-op (used by allow surfaces) | ✅ |

> Default block mode is `PRESS_BACK` for most; **TikTok defaults to `KILL_APP`**. The Instagram "Allow Reels By Friends" surface uses `supportedBlockModes: ["NONE"]` / `defaultBlockMode: "NONE"`.

### 5.4 `AppLockAction` (`actionOnLaunch` values)

| Value | Meaning |
|---|---|
| `NONE` | Do nothing on app launch (default) |
| `KILL_APP` | Force-close the app the moment it is opened (e.g. TikTok `com.ss.android.ugc.trill`) |

### 5.5 `Plans` (`PlansEnum`)

| Value | Meaning |
|---|---|
| `BLOCK_ALL` | Block every enabled surface, always |
| `CURIOUS` | Allow a brief peek then block ("curious" mode) |
| `ONE_REEL` | Allow exactly one reel, then block the next |
| `PAUSED` | Blocking temporarily paused |

### 5.6 `WebMatchType` (`WebMatchTypeEnum`)

| Value | Meaning |
|---|---|
| `DOMAIN` | Match the canonical host (after stripping scheme + `www.`/`m.`) |
| `EXACT` | Exact URL/path match |
| `WILDCARD` | `*.domain` subdomain wildcard via `matchesSubdomainWildcard` |

### 5.7 `PlatformRestriction` (`PlatformRestrictionEnum`)

| Value | `millis` | `coolDown` | Meaning |
|---|---|---|---|
| `ONE_MIN` | 60000 | 15s | Block for 1 minute |
| `FIVE_MIN` | 300000 | 60s | Block for 5 minutes |
| `TEN_MIN` | 600000 | 120s | Block for 10 minutes |
| `NEVER` | `Long.MAX_VALUE` | — | Never auto-unblock |
| `ALWAYS` | 0 | — | Always blocked |
| `AS_PER_PLAN` | -1 | — | Defer to active `PlansEnum` |

### 5.8 `EnumDeviceConfig` / `SupportStatus` / `CalibrationConstrainPosition`

| Enum | Values |
|---|---|
| `EnumDeviceConfig` | `MOBILE`, `TABLET`, `LANDSCAPE`, `LANDSCAPE_TABLET` |
| `SupportStatus` | `UPDATE_REQUIRED`, `NOT_SUPPORTED`, `FRESH`, `SUPPORTED` |
| `CalibrationConstrainPosition` | `TOP`, `BOTTOM`, `RIGHT`, `LEFT` |

---

## 6. Dart models (freezed + json_serializable)

Clean, from-scratch models for the new Flutter app. Place under `data/models/`. These deserialize the exact server payloads above.

### 6.1 Enums

```dart
// data/models/config_enums.dart
import 'package:json_annotation/json_annotation.dart';

enum DetectionType { LEGACY, CALIBRATION, OVERLAY, MANUAL, NONE }

@JsonEnum(alwaysCreate: true)
enum ViewDetector { FINDBYID, VIEWID_RES_NAME, CONT_DESC, BROWSER }

enum BlockingMode { PRESS_BACK, KILL_APP, LOCK_SCREEN, NONE }

enum AppLockAction { NONE, KILL_APP }

enum BlockPlan { BLOCK_ALL, CURIOUS, ONE_REEL, PAUSED }

enum WebMatchType { DOMAIN, EXACT, WILDCARD }

enum DeviceClass { MOBILE, TABLET, LANDSCAPE, LANDSCAPE_TABLET }

enum SupportStatus { UPDATE_REQUIRED, NOT_SUPPORTED, FRESH, SUPPORTED }

enum ConstraintEdge { TOP, BOTTOM, RIGHT, LEFT }

/// PlatformRestrictionEnum mapped with payload.
enum PlatformRestriction {
  oneMin(60000, 15000),
  fiveMin(300000, 60000),
  tenMin(600000, 120000),
  never(9223372036854775807, 0), // Long.MAX_VALUE
  always(0, 0),
  asPerPlan(-1, 0);

  const PlatformRestriction(this.millis, this.coolDownMs);
  final int millis;
  final int coolDownMs;
}
```

### 6.2 platforms_config models

```dart
// data/models/platform_config_response.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'config_enums.dart';

part 'platform_config_response.freezed.dart';
part 'platform_config_response.g.dart';

@freezed
class PlatformConfigResponse with _$PlatformConfigResponse {
  const factory PlatformConfigResponse({
    @JsonKey(name: 'responsecode') @Default(0) int responseCode,
    @Default('') String message,
    @Default(0) int configVersion,
    @Default('') String updateMessage,
    @Default('') String updateIcon,
    @Default(<String, AppDetails>{}) Map<String, AppDetails> featuredApps,
  }) = _PlatformConfigResponse;

  factory PlatformConfigResponse.fromJson(Map<String, dynamic> json) =>
      _$PlatformConfigResponseFromJson(json);
}

@freezed
class AppDetails with _$AppDetails {
  const factory AppDetails({
    required String packageName,
    required String appName,
    @Default(AppLockAction.NONE) AppLockAction actionOnLaunch,
    @Default(-1) int paramsClass,
    @Default('{}') String params,
    @Default(0) int priority,
    @Default('') String iconUrl,
    @Default(false) bool premiumExclusive,
    @Default(-1) int minAppVersion,
    @Default(-1) int maxAppVersion,
    @Default(false) bool supportInAppYtShorts,
    @Default(<Platform>[]) List<Platform> platforms,
    @Default(false) bool showInDashboard,
    @Default(false) bool showIfNotInstalled,
    @Default(<AppOpenAction>[]) List<AppOpenAction> appOpenActions,
    @Default(false) bool browser,
  }) = _AppDetails;

  factory AppDetails.fromJson(Map<String, dynamic> json) =>
      _$AppDetailsFromJson(json);
}

@freezed
class Platform with _$Platform {
  const factory Platform({
    required String platformId,
    required String platformName,
    required String packageName,
    @Default('') String iconUrl,
    @Default(<ViewDetector, Detector>{}) Map<ViewDetector, Detector> detectors,
    @Default(<DeviceClass, ManualConfig>{}) Map<DeviceClass, ManualConfig> manualConfig,
    @Default(DetectionType.LEGACY) DetectionType detectionType,
    @Default(false) bool defaultStatus,
    @Default(true) bool customizable,
    @Default(true) bool showInDashboard,
    @Default(false) bool showAlwaysInBlockList,
    @Default(false) bool premiumExclusive,
  }) = _Platform;

  factory Platform.fromJson(Map<String, dynamic> json) =>
      _$PlatformFromJson(json);
}

@freezed
class Detector with _$Detector {
  const factory Detector({
    @Default(<String>[]) List<String> identifiers,
    @Default(<BlockingMode>[]) List<BlockingMode> supportedBlockModes,
    @Default(BlockingMode.PRESS_BACK) BlockingMode defaultBlockMode,
    @Default(0) int priority,
    @Default(-1) int childNodeLimit,
    @Default(AppLockAction.NONE) AppLockAction actionOnLaunch,
    @Default(0) int paramsClass,
    @Default('') String params, // OVERLAY sub-JSON when paramsClass == 1
    @Default('') String message,
    AdditionalDetectionParams? detectionParams,
    @Default(true) bool haltOnDetect,
    @Default(<String>[]) List<String> coupleWith,
  }) = _Detector;

  factory Detector.fromJson(Map<String, dynamic> json) =>
      _$DetectorFromJson(json);
}

@freezed
class AdditionalDetectionParams with _$AdditionalDetectionParams {
  const factory AdditionalDetectionParams({
    @Default('') String paramId,
    @Default(false) bool focusable,
    @Default(false) bool visibleToUser,
    @Default('') String text,
    @Default(false) bool exactText,
    @Default('') String description,
    @Default(false) bool exactDescription,
    @Default('') String viewId,
    @Default('') String className,
  }) = _AdditionalDetectionParams;

  factory AdditionalDetectionParams.fromJson(Map<String, dynamic> json) =>
      _$AdditionalDetectionParamsFromJson(json);
}

@freezed
class AppOpenAction with _$AppOpenAction {
  const factory AppOpenAction({
    required String name,
    required String url,
  }) = _AppOpenAction;

  factory AppOpenAction.fromJson(Map<String, dynamic> json) =>
      _$AppOpenActionFromJson(json);
}

@freezed
class ManualConfig with _$ManualConfig {
  const factory ManualConfig({
    @Default(<double>[]) List<double> width,
    DisplayParams? small,
    @JsonKey(name: 'default') DisplayParams? defaultParams,
    DisplayParams? large,
    DisplayParams? larger,
    DisplayParams? largest,
    @Default('') String platformId,
  }) = _ManualConfig;

  factory ManualConfig.fromJson(Map<String, dynamic> json) =>
      _$ManualConfigFromJson(json);
}

@freezed
class DisplayParams with _$DisplayParams {
  const factory DisplayParams({@Default(<double>[]) List<double> x}) = _DisplayParams;
  factory DisplayParams.fromJson(Map<String, dynamic> json) =>
      _$DisplayParamsFromJson(json);
}
```

### 6.3 OVERLAY params (`paramsClass == 1`) — parse the embedded string

```dart
// data/models/overlay_params.dart  (parse Detector.params as JSON when paramsClass == 1)
@freezed
class OverlayParams with _$OverlayParams {
  const factory OverlayParams({
    @JsonKey(name: 'primary_id') required String primaryId,
    required OverlayConfig config,
    required OverlayHeader header,
    required OverlayFooter footer,
    @JsonKey(name: 'primary_addons') @Default(<String>[]) List<String> primaryAddons,
    @Default(<OverlaySecondary>[]) List<OverlaySecondary> secondary,
  }) = _OverlayParams;

  factory OverlayParams.fromJson(Map<String, dynamic> json) =>
      _$OverlayParamsFromJson(json);
}

@freezed
class OverlayConfig with _$OverlayConfig {
  const factory OverlayConfig({
    @JsonKey(name: 'curious_support') @Default(false) bool curiousSupport,
    @JsonKey(name: 'block_all_support') @Default(false) bool blockAllSupport,
    @JsonKey(name: 'overlay_support') @Default(false) bool overlaySupport,
    @JsonKey(name: 'blackout_message') @Default('') String blackoutMessage,
  }) = _OverlayConfig;
  factory OverlayConfig.fromJson(Map<String, dynamic> j) => _$OverlayConfigFromJson(j);
}

@freezed
class OverlayHeader with _$OverlayHeader {
  const factory OverlayHeader({
    @JsonKey(name: 'primary_header') required String primaryHeader,
    @JsonKey(name: 'blackout_header') required String blackoutHeader,
  }) = _OverlayHeader;
  factory OverlayHeader.fromJson(Map<String, dynamic> j) => _$OverlayHeaderFromJson(j);
}

@freezed
class OverlayFooter with _$OverlayFooter {
  const factory OverlayFooter({
    @JsonKey(name: 'primary_footer') required String primaryFooter,
    @JsonKey(name: 'blackout_footer') required String blackoutFooter,
  }) = _OverlayFooter;
  factory OverlayFooter.fromJson(Map<String, dynamic> j) => _$OverlayFooterFromJson(j);
}

@freezed
class OverlaySecondary with _$OverlaySecondary {
  const factory OverlaySecondary({
    required String id,
    @Default(0) int location,
  }) = _OverlaySecondary;
  factory OverlaySecondary.fromJson(Map<String, dynamic> j) => _$OverlaySecondaryFromJson(j);
}

// Usage: when detector.paramsClass == 1, decode the string:
//   final overlay = OverlayParams.fromJson(jsonDecode(detector.params));
```

### 6.4 initial_config models (abridged signatures)

```dart
// data/models/initial_config.dart
@freezed
class InitialConfig with _$InitialConfig {
  const factory InitialConfig({
    required VersionAvailability versionAvailability,
    @Default(<AppNotification>[]) List<AppNotification> inappNotification,
    @Default(<AppNotification>[]) List<AppNotification> warningMessages,
    @Default(<String, AdUnit>{}) Map<String, AdUnit> admobConfig,
    required ActivePlanDetails activePlanDetails,
    InhouseNativeAd? inhouseNativeAdConfig,
    PremiumCTA? premiumPurchaseCTA,
    @Default(<String, String>{}) Map<String, String> videoConfig,
    @Default(<String, FeatureFlag>{}) Map<String, FeatureFlag> featuresAvailability,
    @Default(0) int platformConfigVersion,
  }) = _InitialConfig;
  factory InitialConfig.fromJson(Map<String, dynamic> j) => _$InitialConfigFromJson(j);
}

@freezed
class AppNotification with _$AppNotification {
  const factory AppNotification({
    required String notificationId,
    required String title,
    @Default('') String description,
    @Default('') String cta,
    @Default(0) int priority,
    required String ctaAction, // URL | NOTIFICATION | RATING | ACCESSIBILITY | BATTERY_OPTIMIZATION
    @Default('') String ctaUrl,
    @Default('') String metadata,
    @Default(0) int expiry,
    @Default('') String icon,
    @Default(false) bool premiumExclusive,
    @Default(false) bool guestExclusive,
    @Default(true) bool dismissible,
  }) = _AppNotification;
  factory AppNotification.fromJson(Map<String, dynamic> j) => _$AppNotificationFromJson(j);
}

@freezed
class FeatureFlag with _$FeatureFlag {
  const factory FeatureFlag({
    required String featureId,
    @Default(0) int minOSVersion,
    @Default(999) int maxOSVersion,
    @Default('') String params,
    @Default(false) bool enabled,
    @Default(false) bool premiumOnly,
  }) = _FeatureFlag;
  factory FeatureFlag.fromJson(Map<String, dynamic> j) => _$FeatureFlagFromJson(j);
}

@freezed
class AdUnit with _$AdUnit {
  const factory AdUnit({required String adTag, required String adType}) = _AdUnit;
  factory AdUnit.fromJson(Map<String, dynamic> j) => _$AdUnitFromJson(j);
}
// ActivePlanDetails / VersionAvailability / VersionInfo / InhouseNativeAd / PremiumCTA: see §3.2–3.4 for fields.
```

### 6.5 Calibration models (abridged signatures)

```dart
// data/models/calibration_config.dart
@freezed
class CalibrationConfigRequest with _$CalibrationConfigRequest {
  const factory CalibrationConfigRequest({
    required int width,
    required int height,
    required DeviceClass deviceConfig,
    @Default(<String, InstalledPlatformConfig>{})
        Map<String, InstalledPlatformConfig> platforms,
  }) = _CalibrationConfigRequest;
  factory CalibrationConfigRequest.fromJson(Map<String, dynamic> j) =>
      _$CalibrationConfigRequestFromJson(j);
}

@freezed
class InstalledPlatformConfig with _$InstalledPlatformConfig {
  const factory InstalledPlatformConfig({
    required int platformVersion,
    required int version,
  }) = _InstalledPlatformConfig;
  factory InstalledPlatformConfig.fromJson(Map<String, dynamic> j) =>
      _$InstalledPlatformConfigFromJson(j);
}

@freezed
class CalibrationConfigResponse with _$CalibrationConfigResponse {
  const factory CalibrationConfigResponse({
    @Default(0) int responseCode,
    @Default('') String message,
    @Default(<String, PlatformConfigMetaData>{})
        Map<String, PlatformConfigMetaData> platforms,
  }) = _CalibrationConfigResponse;
  factory CalibrationConfigResponse.fromJson(Map<String, dynamic> j) =>
      _$CalibrationConfigResponseFromJson(j);
}

@freezed
class PlatformConfigMetaData with _$PlatformConfigMetaData {
  const factory PlatformConfigMetaData({
    required SupportStatus supportStatusEnum,
    @Default(0) int configVersion,
    @Default(<String, Map<String, PlatformHolder>>{})
        Map<String, Map<String, PlatformHolder>> config,
  }) = _PlatformConfigMetaData;
  factory PlatformConfigMetaData.fromJson(Map<String, dynamic> j) =>
      _$PlatformConfigMetaDataFromJson(j);
}

@freezed
class PlatformHolder with _$PlatformHolder {
  const factory PlatformHolder({
    @Default(0) int version,
    required String name,
    required String platformId,
    @Default(<DeviceClass, PlatformCalibrationConfig>{})
        Map<DeviceClass, PlatformCalibrationConfig> config,
    AdditionalDetectionParams? detectionParams,
    @Default(0) int priority,
    @Default(<String>[]) List<String> coupleWith,
    @Default(false) bool haltOnDetect,
    @Default(<BlockingMode>[]) List<BlockingMode> supportedBlockModes,
  }) = _PlatformHolder;
  factory PlatformHolder.fromJson(Map<String, dynamic> j) =>
      _$PlatformHolderFromJson(j);
}

@freezed
class PlatformCalibrationConfig with _$PlatformCalibrationConfig {
  const factory PlatformCalibrationConfig({
    @Default(0) double width,
    @Default(0) double height,
    @Default(<ConstraintEdge, double>{}) Map<ConstraintEdge, double> constraints,
    @Default(0) int minPlatformVersion,
    @Default(0) int maxPlatformVersion,
    @Default('') String supportStatus,
    @Default(0) int version,
  }) = _PlatformCalibrationConfig;
  factory PlatformCalibrationConfig.fromJson(Map<String, dynamic> j) =>
      _$PlatformCalibrationConfigFromJson(j);
}
```

> `freezed` + `json_serializable` auto-generate enum (de)serialization. For map keys that are enums (`Map<ViewDetector, Detector>`, `Map<ConstraintEdge, double>`), write a small custom `fromJson`/`toJson` converter (`JsonConverter`) since codegen serializes map keys as strings only.

---

## 7. Representative platforms in the shipped JSON

10 verified rows (from `platforms_config.json`, `configVersion: 32`):

| App (package) | platformId | Detector → identifier(s) | detectionType | defaultBlockMode (supported) |
|---|---|---|---|---|
| YouTube (`com.google.android.youtube`) | `yt_shorts` | `FINDBYID` → `:id/reel_player_underlay` | LEGACY | PRESS_BACK (PRESS_BACK, KILL_APP) |
| In-App YouTube (`com_google_android_youtube`) | `yt_inapp_shorts` | _none_ (`detectors: {}`) | CALIBRATION | server-tuned zone |
| Instagram (`com.instagram.android`) | `ig_feed` | `FINDBYID` → `:id/media_group` (paramsClass 1) | OVERLAY | PRESS_BACK (PRESS_BACK, KILL_APP) |
| Instagram (`com.instagram.android`) | `ig_reel` | `FINDBYID` → `:id/clips_author_username` | LEGACY | PRESS_BACK (PRESS_BACK, KILL_APP) |
| Insta PRO (`com.instapro.android`) | `insta_pro` | `FINDBYID` → `:id/reel_viewer_title` | LEGACY | PRESS_BACK (PRESS_BACK, KILL_APP) |
| Facebook (`com.facebook.katana`) | `fb_reel` | `CONT_DESC` → `"Add a comment…"` (+16 locales) | LEGACY | PRESS_BACK (PRESS_BACK, KILL_APP) |
| Snapchat (`com.snapchat.android`) | `snap_stories` | `FINDBYID` → `:id/view_profile` **and** `VIEWID_RES_NAME` → `context_vertical_actions/context_vertical_action_share` (childNodeLimit 500) | LEGACY | PRESS_BACK (PRESS_BACK, KILL_APP) |
| TikTok (`com.ss.android.ugc.trill`) | `tiktok_clips` | `FINDBYID` → `:id/desc` | LEGACY | **KILL_APP** (PRESS_BACK, KILL_APP) |
| X / Twitter (`com.twitter.android`) | `x_twitter` | `FINDBYID` → `:id/mediacontroller_progress` | LEGACY | PRESS_BACK (PRESS_BACK, KILL_APP) |
| Reddit (`com.reddit.frontpage`) | `reddit_watch` | `VIEWID_RES_NAME` → `content_video_view` | LEGACY | PRESS_BACK (PRESS_BACK, KILL_APP) |

Other notable rows: LinkedIn `linkedin_video` → `:id/media_viewer_actor_bottom` (premium); YouTube Music `ytm_shorts` → `:id/reel_player_page_container` (premium app); WhatsApp `wa_status` → `:id/status_header` (premium); SnapTube `snaptube_premium` → `:id/playback_gesture_detector`, `:id/anp`; VK `vk_clips` → `:id/fullscreen_clip_overlay_like_text`, `:id/clip_owner_view`; Opera/Jio Web/CleanTube/PhysicsWala/FB Lite/Insta Lite all use `CALIBRATION` with empty `detectors`. Instagram `ig_reel_by_friend` is an **allow** surface: `FINDBYID` → `:id/reply_bar_edittext`, `defaultBlockMode: NONE`, `customizable: false`.

---

## Source evidence

- `resources/res/raw/platforms_config.json` (read in full; `configVersion: 32`, `responsecode: 200`, 26 `featuredApps`, including the literal `ig_feed` OVERLAY `params` sub-JSON).
- `resources/res/raw/initial_config.json` (read in full; `platformConfigVersion: 32`; feature flags `smart_mode`/`memory_warning`/`feed_blocker`/`reels_by_friends`; AdMob unit map; in-app + warning notifications).
- `sources/.../network/data/platformsconfig/response/` — `PlatformConfigResponse.java`, `AppDetails.java`, `Platform.java`, `Detectors.java`, `DetectionTypeEnum.java`, `ViewDetectorsEnum.java`, `ManualConfig.java`, `custom/instagram/InstagramCustomConfig.java`.
- `sources/.../network/data/calibrationconfig/` — `request/CalibrationConfigRequest.java`, `request/InstalledPlatformConfig.java`, `response/CalibrationConfigResponse.java`, `response/PlatformConfigMetaData.java`, `response/PlatformHolder.java`, `response/PlatformCalibrationConfig.java`, `response/EnumDeviceConfig.java`, `response/SupportStatusEnum.java`, `response/Constraints.java`.
- `sources/.../service/data/CalibratedConfig.java`, `service/data/DisplayConfig.java`, `service/mappers/PlatformRestrictionEnum.java`, `service/data/platformconfig/PlatformLite.java`.
- Cached analysis: `/tmp/ns_analysis/platform-config.json`, `/tmp/ns_analysis/calibration.json`.

Field bodies marked obfuscated in the analysis (e.g. exact priority of detector ordering at runtime) are labelled **(inferred)** above where relevant; all enum value sets, JSON keys, and the OVERLAY sub-JSON are quoted verbatim from the read files.

---

## Related docs

- `01-architecture-overview.md`
- `03-accessibility-service-engine.md`
- `04-blocking-modes-and-actions.md`
- `05-calibration-and-overlay.md`
- `06-plans-and-premium-gating.md`
- `07-config-fetch-and-persistence.md`
