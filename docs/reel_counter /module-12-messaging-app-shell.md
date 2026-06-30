# Module: Messaging & App Shell

## 1. Purpose & scope
The application bootstrap and entry point: FCM push handling, notification channels, `MainActivity` (deep links, screen‑capture callback, in‑app updates, Razorpay host), the DI graph, locale override, and the app‑init/worker‑scheduling sequence. **Owns:** push routing, app startup wiring, navigation host. **Does NOT own:** the worker bodies (see [module-11-workers-background.md](module-11-workers-background.md)) or billing logic (see [module-06-subscription-billing.md](module-06-subscription-billing.md)).

## 2. Migration verdict
**DART + CHANNEL.** FCM, notifications, deep links, remote config, locale = Flutter packages. Two native touchpoints: **`ScreenCaptureCallback`** (API 34+, no package → channel) and the **Pairip integrity wrapper** (`com.pairip.application.Application` — investigate, may be droppable). App init (Hilt `@HiltAndroidApp` with ~70 injected fields) is replaced by `get_it`/`injectable` registration in `main()`.

## 3. Business logic & algorithms (load‑bearing)

### 3.1 FCM message routing (`BrainRotFirebaseMessagingService.onMessageReceived`)
Five message types (the original uses a `hashCode()` switch — **use string equality in Dart**):
| `type` | hashCode (Java) | Action |
|---|---|---|
| `sync_required` | 678756547 | `friendsRepository.sync(force=true)` |
| `config_changed` | -146003273 | queue config refresh coroutine |
| `friend_removed` | -893629505 | extract `removed_by`, dispatch friend removal |
| `invite_accepted` | 1587248157 | extract `profile_photo_url`,`title`,`body`,`deep_link`; force friends sync; rich notification w/ circular avatar |
| generic/default | — | if `title`/`body` present → standard notification |

```
deep link handling (notification tap):
  if deep_link != null && deep_link != "NA":
     uri = parse(deep_link + (contains('?')?'&':'?') + "notification_source=invite_accepted")
  PendingIntent → MainActivity (FLAG_ACTIVITY_NEW_TASK|SINGLE_TOP|CLEAR_TOP|IMMUTABLE = 201326592)
```
Avatar circular crop: square = `min(w,h)`, `BitmapShader(CLAMP)`, `drawCircle(d/2,d/2,d/2)` → Flutter `ClipOval(Image.network(...))`.

### 3.2 Notification channels (created on SDK 26+, exact IDs + importance)
| ID | Importance |
|---|---|
| `general` | DEFAULT (3) |
| `firebase_message` | MAX (4) |
| `foreground_service` | LOW (2) |
| `battle_result` | MAX (4) |
| `analytics_events` | LOW (2) |
| `offer_countdown` | MAX (4) |
| `permission_alert` | MAX (4) |
(Plus the bubble service's own `reels_counter_bubble`, see [module-02](module-02-overlays-floating-bubble.md).) **Channel IDs must match exactly** or notifications go silent.

### 3.3 App init sequence (`BrainRotApplication`)
1. (Pairip wrapper `com.pairip.application.Application` runs first → delegates to `BrainRotApplication.onCreate`.)
2. Create the 7 notification channels.
3. Bootstrap Firebase Remote Config with `rc_defaults.xml` defaults (fetch interval 3600s).
4. Register/schedule all 11–12 workers (see [module-11](module-11-workers-background.md)).
5. `SaveFCMTokenWorker` → `POST /auth/save_fcm_token`.

### 3.4 MainActivity
- Extends `lc.a` → `CheckoutActivity` (`ai.regainapp.payments.ui`); initializes **Razorpay** live key `rzp_live_SxX4XCM7fABMgJ` and Play Core `AppUpdateManager` (in‑app updates, `SHOW_IN_APP_UPDATE` RC flag).
- Registers **`ScreenCaptureCallback`** (API 34+) in `onStart`, unregisters in `onStop`; logs analytics (`mc.a.f16578v6`) on capture.
- Deep‑link parsing in `w(Intent)` (`onCreate` + `onNewIntent`).
- **Locale override:** every Activity `attachBaseContext` reads pref `app_locale_storage/language_code` (BCP‑47) and applies `Locale.setDefault` + `Configuration.setLocale` before super.

## 4. Data models
- FCM payloads: `{type, title?, body?, deep_link?, removed_by?, profile_photo_url?}`.
- Prefs: `app_locale_storage/language_code` (string), FCM token.
- Dart: `PushMessage` (sealed/freezed union by `type`), `NotificationChannelSpec { id, importance }`.

## 5. Android deps → Flutter map
| Android API | Verdict | Flutter | Notes |
|---|---|---|---|
| FCM (`FirebaseMessagingService`) | PKG | `firebase_messaging` | `onMessage`/`onMessageOpenedApp`/`getInitialMessage`; `onTokenRefresh` |
| NotificationChannel (7) | PKG | `flutter_local_notifications` | exact IDs + importance (3/4/2) |
| Deep links (PendingIntent → Activity) | PKG | `app_links` + `go_router` | `notification_source` query param routing |
| `ScreenCaptureCallback` (API 34+) | CHANNEL | `brainpal/system_events: SCREEN_CAPTURED` | no package |
| AppUpdateManager (Play Core) | PKG/CHANNEL | `in_app_update` (or channel) | flexible/immediate flow |
| Razorpay host | PKG | `razorpay_flutter` | see [module-06](module-06-subscription-billing.md) |
| Locale via attachBaseContext | PKG | `MaterialApp.locale` + `intl`/`flutter_localizations` | apply early in `main()` |
| Hilt DI (`@HiltAndroidApp`) | PKG | `get_it` + `injectable` | register singletons before `runApp` |
| Firebase Remote Config | PKG | `firebase_remote_config` | seed `rc_defaults` |
| Pairip wrapper | KEEP‑NATIVE? | investigate | may be removable (Phase 0) |

## 6. iOS strategy
- FCM via `firebase_messaging` (APNs under the hood) — works on iOS; configure APNs key + entitlement.
- Notifications via `flutter_local_notifications` (iOS categories ≈ channels; importance maps to interruption level).
- Deep links → Universal Links (`app_links`). Remote config + analytics cross‑platform.
- **No `ScreenCaptureCallback`** on iOS → use `UIScreen.capturedDidChangeNotification` (screen recording) / `userDidTakeScreenshotNotification` (bridged) if the anti‑cheat signal is needed.
- No Pairip / Play Core; in‑app updates handled by the App Store (no equivalent API).

## 7. Platform‑channel surface
- `brainpal/system_events` (Event): `SCREEN_CAPTURED` (+ date/time events shared with [module-11](module-11-workers-background.md)).
See [01-platform-channel-contracts.md](01-platform-channel-contracts.md). FCM/notifications/deep links use their plugins, not custom channels.

## 8. State management & DI
- `main()`: init Firebase, register `get_it` singletons (repositories, APIs, DBs, analytics, auth, `SyncEngine`), seed remote config, set locale, then `runApp`.
- Riverpod: `pushHandlerProvider` (routes `PushMessage` to side effects + `go_router`), `localeProvider` (`StateNotifier` persisting `language_code`), `appUpdateProvider`.
- `friendsRepository.sync` / config refresh triggered from push handler (replaces the `l0` controller).

## 9. User flows
1. **Cold start** `[dart]`: Firebase init → DI → remote config → locale → schedule workers → save FCM token → `runApp`.
2. **Push received (foreground/background)** `[dart]`: parse `type` (string switch) → side effect (sync/config/friend‑removed/invite) → show notification on correct channel.
3. **Notification tap** `[dart]`: extract `deep_link` + `notification_source` → `go_router` navigates.
4. **Screen capture** `[native→channel→dart]`: `SCREEN_CAPTURED` → analytics.
5. **Locale change** `[dart]`: persist `language_code` → rebuild `MaterialApp`.

## 10. Parity risks & validation
- **FCM type routing:** replace hashCode switch with string equality; send each of the 5 types from backend and assert the correct side effect + channel + deep link.
- **Channel ID parity:** mismatched IDs = silent notifications — assert exact IDs/importance.
- **Pairip:** determine in Phase 0 whether the integrity wrapper must stay (blocks app‑init design).
- **Deep‑link `notification_source`:** verify routing for each source value.
- **Locale early‑apply:** ensure locale set before first frame (no Android `attachBaseContext` equivalent).

## 11. Open questions
- Full deep‑link query‑param spec (only `notification_source=invite_accepted` confirmed).
- `ka.l.f14430n` WorkManager constraints content.
- FCM `deep_link` payload format (full URL vs path; "NA" sentinel).
- Screen‑capture analytics event name (`mc.a.f16578v6`).
- Is `profile_photo_url` always present in `invite_accepted` (else fetched via HTTP)?
- Pairip wrapper: removable/replaceable?

## 12. Migration checklist (Phase 3, Pairip in Phase 0)
- [ ] `firebase_messaging` handlers (fg/bg/initial) + `onTokenRefresh` → save token.
- [ ] Create 7 notification channels (exact IDs/importance) at startup via `flutter_local_notifications`.
- [ ] `PushMessage` union + string‑equality router → side effects + `go_router`.
- [ ] `brainpal/system_events: SCREEN_CAPTURED` channel + analytics.
- [ ] `firebase_remote_config` seeded with `rc_defaults`.
- [ ] DI bootstrap in `main()`; locale persistence.
- [ ] Phase 0: investigate Pairip wrapper removal.
- [ ] iOS: APNs, Universal Links, screenshot/recording notifications.
