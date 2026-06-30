# Module: Manifest, Permissions & Assets

## 1. Purpose & scope
The full Android platform surface declared in `AndroidManifest.xml` plus bundled assets — the authoritative inventory of permissions, components, intent‑filters, and resources. **Owns:** the "what the OS sees" map. **Does NOT own:** the behavior behind each component (linked per row to its module doc).

## 2. Migration verdict
**Reference doc (mixed).** The Flutter app keeps a (smaller) native `AndroidManifest.xml` for the retained native components ([99-native-retained-modules.md](99-native-retained-modules.md)); runtime permissions move to `permission_handler`; deep links to `app_links`. This doc is the checklist to reproduce the manifest surface correctly. iOS has a parallel `Info.plist` + entitlements surface (see §6).

## 3. Business logic & algorithms (load‑bearing)
High‑level behaviors the manifest enables (detailed in their modules):
- Reel detection/blocking on IG/YT/TikTok/Snap/FB via accessibility ([module-01](module-01-reels-detection-core.md)); midnight counter reset ([module-11](module-11-workers-background.md)).
- Cooldown durations offered to users: **1 hour, rest of day, 7 days, till tomorrow** (maps to `cooldownTimeInMillis`/`hardBlockValidTill`).
- NFC/sensor unlock challenges ([module-02](module-02-overlays-floating-bubble.md)).
- Floating bubble FGS (`FOREGROUND_SERVICE_SPECIAL_USE`, subtype "Floating bubble overlay").
- Friend duels + push ([module-05](module-05-duel-friends-stats.md), [module-12](module-12-messaging-app-shell.md)); back‑press subscription offer ([module-06](module-06-subscription-billing.md)).
- **Cloud backup disabled** (local data only) — privacy‑critical.

## 4. Data models (component & permission inventory)

### 4.1 Permissions → why → Flutter handling
| Permission | Why | Flutter |
|---|---|---|
| `INTERNET`, `ACCESS_NETWORK_STATE` | API/sync | implicit / `connectivity_plus` |
| `BIND_ACCESSIBILITY_SERVICE` | reel detection | native service ([module-01](module-01-reels-detection-core.md)) |
| `SYSTEM_ALERT_WINDOW` | overlay/bubble | channel ([module-02](module-02-overlays-floating-bubble.md)) |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE` | bubble service | native FGS |
| `POST_NOTIFICATIONS` | notifications (API 33+) | `permission_handler` |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | survive Doze | channel/`flutter_background` |
| `RECEIVE_BOOT_COMPLETED` | restart on reboot | native receiver |
| `VIBRATE` | haptics | `vibration` |
| `DETECT_SCREEN_CAPTURE` | anti‑cheat analytics | channel (`SCREEN_CAPTURED`) |
| `NFC` | tap‑card challenge | `nfc_manager` |
| `ACTIVITY_RECOGNITION` | step/jump challenges | `permission_handler` + `pedometer`/`sensors_plus` |
| `com.android.vending.BILLING` | Play Billing fallback | `in_app_purchase` |
| (`<queries>` 60+ packages: social + UPI/bank apps) | detect target/social apps + UPI payment availability | native `PackageManager` via channel; manifest `<queries>` retained |
| Device admin (`disable-uninstall`) | anti‑uninstall | native `DeviceAdminReceiver` |

### 4.2 Components
| Component | Type | Role | Module |
|---|---|---|---|
| `MainActivity` | activity (LAUNCHER) | entry, deep links, Razorpay host, screen‑capture | [module-12](module-12-messaging-app-shell.md) |
| `BlockReelsOverlayActivity` | activity | block overlay (NFC reader) | [module-02](module-02-overlays-floating-bubble.md) |
| `PermissionStepsOverlayActivity` | activity | onboarding steps (PiP) | [module-04](module-04-permissions-onboarding.md) |
| `RatingPromptOverlayActivity` | activity | post‑block rating | [module-02](module-02-overlays-floating-bubble.md) |
| `services.ReelsAccessibilityService` | service | detection | [module-01](module-01-reels-detection-core.md) |
| `floating_bubble.ReelsCounterFloatingService` | service (specialUse) | bubble | [module-02](module-02-overlays-floating-bubble.md) |
| `services.BrainRotFirebaseMessagingService` | service | FCM | [module-12](module-12-messaging-app-shell.md) |
| `feature_widget…ReelsCounterWidgetReceiver` / `…ExpandedReceiver` | receiver | home widgets | [module-03](module-03-widgets-homescreen.md) |
| `…WidgetPinResultReceiver`, `…AppUpdateReceiver` | receiver | widget pin / app update | [module-03](module-03-widgets-homescreen.md) |
| `…WidgetVisibilityProvider` | service/provider | widget visibility | [module-03](module-03-widgets-homescreen.md) |
| `core.receiver.DateChangedReceiver` | receiver | date/time reset | [module-11](module-11-workers-background.md) |
| `feature_subscription…BackPressOfferExpiryNotificationReceiver` | receiver | offer expiry | [module-06](module-06-subscription-billing.md) |

### 4.3 Intent‑filters / deep links
- App Links (`autoVerify=true`): hosts `brainpalapp.ai`, `brainrotapp.ai`, `join.brainpalapp.ai`, `join.brainrotapp.ai` (scheme `https`); custom scheme `brainrot://`.
- Payment schemes: `upi`, `razorpay`, host `pay`; `mailto`.
- Two accessibility configs: `accessibility_service_config.xml` (the real one) **and** a second `site_manager_service.xml` (process `:accessibility_service_process`, `settingsActivity=com.example.android…`) → **OPEN QUESTION: dead/sample config? remove.**

### 4.4 XML configs & assets
| Resource | Purpose |
|---|---|
| `res/xml/accessibility_service_config.xml` | typeAllMask, 500ms, canPerformGestures, flags (see [module-01](module-01-reels-detection-core.md)) |
| `res/xml/rc_defaults.xml` | Firebase Remote Config defaults (blocking bounds, RC SKUs, Mixpanel tokens, challenge options) |
| `res/xml/network_security_config.xml` | cleartext off; LE roots for the 2 domains |
| `res/xml/device_admin_policies.xml` | `disable-uninstall` |
| `res/xml/reels_counter_widget_info.xml` / `_expanded_info.xml` | widget metadata (sizes) |
| `res/xml/backup_rules.xml` / `data_extraction_rules.xml` | **backup disabled** |
| `res/xml/file_provider_path_checkout.xml`, `payments_file_paths.xml`, `image_share_filepaths.xml` | FileProvider paths |
| `assets/mindful_timer_quotes.json` | 50 cooldown quotes (key `quotes`) |
| `assets/ad-viewer/omsdk-v1.js`, `omid-session-client-v1.js` | OMID viewability (AdMob ads, free tier) |
| `assets/logback.xml` | logging config |
| `assets/PublicSuffixDatabase.list` | OkHttp public‑suffix DB |
| `assets/dexopt/`, Firebase `google-services` (project `646203309306`, bucket `com-brainrot-android.firebasestorage.app`) | build/Firebase |

## 5. Android deps → Flutter map
| Surface | Verdict | Flutter |
|---|---|---|
| Runtime permissions | PKG | `permission_handler` |
| `<queries>` package detection | CHANNEL | native `PackageManager` (Flutter can't query directly) |
| Deep links / App Links | PKG | `app_links` + backend `assetlinks.json` |
| FileProvider paths | KEEP‑NATIVE | needed for share/checkout |
| Backup disabled | config | replicate `android:allowBackup=false` + rules |
| Assets (quotes/OMID/logback) | PKG | bundle in `pubspec.yaml` `assets:` |
| Native components | KEEP‑NATIVE | declared in retained manifest ([99](99-native-retained-modules.md)) |

## 6. iOS strategy
The Android manifest maps to **`Info.plist` + entitlements** but most native components have no iOS analog:
- Permissions → `Info.plist` usage strings + `FamilyControls` entitlement (Screen Time), NFC entitlement (`com.apple.developer.nfc.readersession.formats`), motion usage (`NSMotionUsageDescription`).
- Deep links → Associated Domains (Universal Links) + `apple-app-site-association`.
- No accessibility service, overlay, widgets‑as‑Android, device admin, or `<queries>` concept on iOS.
- Ads (OMID) — only if AdMob is shipped on iOS.
- Backup: exclude data from iCloud via `isExcludedFromBackup` on the DB files if matching the "local only" stance.

## 7. Platform‑channel surface
- `<queries>` package availability → bundled into `brainpal/permissions` or a small `brainpal/packages` method. Otherwise this doc references channels owned by other modules.

## 8. State management & DI
N/A (declarative). The manifest is reproduced by the Android build; Flutter merges plugin manifests automatically — verify the merged result matches this inventory.

## 9. User flows
Indirect — the manifest enables flows documented in each linked module. Key cross‑cutting one: **midnight reset** (DateChangedReceiver) → daily counter reset across detection/stats/widgets.

## 10. Parity risks & validation
- **Permission completeness:** diff the Flutter merged manifest against this table; nothing dropped.
- **`<queries>` visibility:** without the 60+ `<queries>` entries, package detection silently returns "not installed" on Android 11+ — retain them.
- **Backup disabled:** assert `allowBackup=false` + iOS iCloud exclusion (privacy).
- **assetlinks.json:** App Links won't auto‑verify without it.
- **Remove dead `site_manager_service`** if confirmed unused.
- **Certificate roots:** ensure HTTPS to both domains still trusts LE roots.

## 11. Open questions
- Is `site_manager_service.xml` (second accessibility config) live or dead/sample? (likely removable)
- Are the UPI/bank `<queries>` for a real in‑app UPI payment path or just Razorpay's intent resolution?
- Is device‑admin `disable-uninstall` actually activated, or declared‑but‑unused?
- Which assets are actually loaded at runtime (ad‑viewer/OMID only if ads enabled).

## 12. Migration checklist (cross‑phase)
- [ ] Author the retained native `AndroidManifest.xml` (native components + permissions + `<queries>` + App Links).
- [ ] Map runtime permissions to `permission_handler` requests in the right flows.
- [ ] Bundle assets (`mindful_timer_quotes.json`, OMID if ads, logback) in `pubspec.yaml`.
- [ ] Backend: `assetlinks.json` (+ iOS `apple-app-site-association`).
- [ ] Disable backup (Android rules + iOS iCloud exclusion).
- [ ] Remove dead `site_manager_service` if confirmed.
- [ ] iOS `Info.plist`/entitlements (FamilyControls, NFC, motion, Associated Domains).
