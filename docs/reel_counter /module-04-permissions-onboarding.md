# Module: Permissions & Onboarding

## 1. Purpose & scope
Detecting, requesting, guiding, and **continuously monitoring** the OS permissions BrainPal needs, plus the step‑by‑step onboarding overlay. **Owns:** permission‑state detection, the guided‑steps UI flow, and re‑prompt logic when a permission is revoked. **Does NOT own:** what the permissions are *used for* (accessibility detection → [module-01](module-01-reels-detection-core.md); overlay → [module-02](module-02-overlays-floating-bubble.md)) or the worker scheduling internals (see [module-11](module-11-workers-background.md)).

## 2. Migration verdict
**DART + CHANNEL.** Runtime permissions (notifications, activity recognition, NFC) use **`permission_handler`**. But the load‑bearing ones — **accessibility‑service enabled state**, **overlay (`SYSTEM_ALERT_WINDOW`)**, **battery‑optimization exemption**, **device‑admin** — have no `permission_handler` coverage and must be checked/opened via a native channel (`brainpal/permissions`, `brainpal/accessibility`). The onboarding UI itself is pure Flutter. iOS uses an entirely different authorization model (Screen Time `AuthorizationCenter`, see §6).

## 3. Business logic & algorithms (load‑bearing)

### 3.1 Permission inventory
| Permission | Why | Detection | Flutter |
|---|---|---|---|
| Accessibility (`BIND_ACCESSIBILITY_SERVICE`) | core reel detection | `Settings.Secure` `enabled_accessibility_services` contains `com.brainrot.android.services.ReelsAccessibilityService` | CHANNEL |
| Overlay (`SYSTEM_ALERT_WINDOW`) | bubble + block overlay | `Settings.canDrawOverlays(ctx)` | CHANNEL |
| Notifications (`POST_NOTIFICATIONS`, API 33+) | daily counts/alerts | runtime grant | `permission_handler` |
| Battery opt (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) | survive Doze | `PowerManager.isIgnoringBatteryOptimizations` | CHANNEL / `flutter_background` |
| Activity recognition | step/jump challenges | runtime grant | `permission_handler` |
| NFC | tap‑card challenge | `NfcAdapter` availability | `nfc_manager` (+ confirm dialog) |
| Boot completed | restart workers/service on reboot | manifest only | native |
| Device admin (`disable-uninstall`) | anti‑uninstall | `DevicePolicyManager.isAdminActive` | CHANNEL |

### 3.2 Accessibility‑enabled detection (verbatim)
```
isAccessibilityServiceEnabled(ctx, "com.brainrot.android.services.ReelsAccessibilityService"):
  s = Settings.Secure.getString(ctx, "enabled_accessibility_services")
  return s != null && s.split(":").any { it == serviceComponentName }
```
Overlay fast‑fail: `ReelsCounterFloatingService.onCreate` → if `!canDrawOverlays` → `stopSelf()`, log, never add views (replicate).

### 3.3 Guided steps UI
- `PermissionStepsOverlayActivity` reads intent extra `extra_permission_type` (enum via `valueOf`, throws on invalid); shows branded device‑specific instructions (`Build.MANUFACTURER`/`MODEL`: Samsung/Xiaomi/OnePlus…). Optional **Picture‑in‑Picture** (API 31+, `Rational(9,16)`, auto‑enter).
- Self‑dismiss on broadcast `com.brainrot.android.FINISH_ACTIVITY` (sent after grant detected).
- Remote‑config flag `SETUP_ACCESSIBILITY_FIRST_PERMISSION_ORDER_V1` (default false) toggles whether accessibility is requested first.

### 3.4 Monitoring & re‑prompt (`PermissionMonitorWorker`, 6h)
```
every 6h (21,600,000ms):
  for each core permission: validate via Settings/PowerManager
  if revoked: insert permission_logs(type, asked_at=now)
  if accessibility revoked: notify (channel 'permission_alert',
       title=accessibility_stopped_notification_title/body)
  reschedule (6h periodic; also re-check on boot)
```
Fresh‑start throttle: store `fresh_start_last_shown_day` (day‑of‑year) in prefs; show onboarding only if `(currentDay - storedDay) >= 1`.

## 4. Data models
- `permission_logs` Room table: `id` PK auto, `permission_type` TEXT, `asked_at` long (see [module-09](module-09-core-data-storage.md)).
- Prefs: `fresh_start_last_shown_day` (long).
- Dart: `PermissionState { type, isGranted, lastAskedAt }`, `PermissionStep { type, title, body, deviceImageAsset, settingsIntent }`.

## 5. Android deps → Flutter map
| Android API | Verdict | Flutter | Notes |
|---|---|---|---|
| `Settings.Secure` accessibility query | CHANNEL | `brainpal/accessibility.isServiceEnabled` | no package |
| `Settings.canDrawOverlays` | CHANNEL | `brainpal/permissions` | |
| `ACTION_ACCESSIBILITY_SETTINGS` / overlay settings intent | CHANNEL | `brainpal/accessibility.openSettings` | or `android_intent_plus` |
| `POST_NOTIFICATIONS`, activity recognition | PKG | `permission_handler` | |
| Battery opt exemption | CHANNEL | `flutter_background` / `brainpal/permissions` | `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` |
| Device admin | CHANNEL | `brainpal/permissions` | no package |
| `Build.MANUFACTURER`/`MODEL` | PKG | `device_info_plus` | device‑specific instructions |
| PiP (API 31+) | CHANNEL | native | low priority |
| `PermissionMonitorWorker` | PKG+CHANNEL | `workmanager` + channel | see [module-11](module-11-workers-background.md) |

## 6. iOS strategy
Completely different. There is no accessibility/overlay/battery permission model. The single gateway is **`FamilyControls` `AuthorizationCenter.requestAuthorization(for: .individual)`** (presents Apple's Screen Time consent). Once authorized, the app uses `DeviceActivity` + `ManagedSettings` (no per‑app runtime perms like Android). Onboarding on iOS = one Screen Time authorization screen + selecting apps to shield via `FamilyActivityPicker`. Notification permission via `permission_handler` still applies. Document the Android permission list as **N/A on iOS** except notifications.

## 7. Platform‑channel surface
- `brainpal/accessibility` (Method): `isServiceEnabled()`, `openSettings()`.
- `brainpal/accessibility_status` (Event): enabled/disabled transitions (drives onboarding auto‑advance, replaces the `FINISH_ACTIVITY` broadcast).
- `brainpal/permissions` (Method): `check(type)`, `request(type)` for overlay/battery/device‑admin.
- `brainpal/permission_status` (Event): grant/revoke transitions.
See [01-platform-channel-contracts.md](01-platform-channel-contracts.md).

## 8. State management & DI
- Riverpod `permissionsProvider` (`StreamProvider<List<PermissionState>>` fed by `permission_status` + polling), `onboardingStepProvider` (`StateNotifier` advancing on `accessibility_status`/`permission_status` events).
- `get_it`: `PermissionGateway` (channel facade), `OnboardingController`.

## 9. User flows
1. **First launch** `[dart]`: compute missing permissions → show onboarding stepper.
2. **Accessibility step** `[dart→channel]` `openSettings()` → user enables → `accessibility_status: enabled` → `[dart]` auto‑advance.
3. **Overlay step** `[channel]` request overlay settings → on grant advance.
4. **Battery/notifications/activity** `[dart]` via `permission_handler`/channel.
5. **Revoke later** `[worker+channel]`: `PermissionMonitorWorker` detects → `permission_alert` notification → tapping reopens onboarding.

## 10. Parity risks & validation
- **Accessibility detection correctness:** unit/integration test the `enabled_accessibility_services` parse across OEMs (some prepend/append component names).
- **Overlay fast‑fail:** assert bubble never starts without overlay grant.
- **Re‑prompt cadence:** verify 6h monitor + boot re‑check; throttle (day‑of‑year) prevents nagging within 24h.
- **Device‑specific instructions:** snapshot tests per `MANUFACTURER`.
- **iOS auth:** test Screen Time authorization denied/granted paths.

## 11. Open questions
- Full `PermissionMonitorWorker` logic (notify vs log only).
- Exact onboarding step ordering and the effect of `SETUP_ACCESSIBILITY_FIRST_PERMISSION_ORDER_V1`.
- Whether device‑admin (`disable-uninstall`) is actually requested in onboarding or optional.
- NFC permission gating (only when a challenge requires it).

## 12. Migration checklist (Phase 1–3)
- [ ] Implement `brainpal/accessibility` + `brainpal/permissions` channels (Kotlin).
- [ ] `permission_handler` for notifications/activity‑recognition/NFC.
- [ ] Battery‑opt + device‑admin via channel/`flutter_background`.
- [ ] Flutter onboarding stepper with device‑specific instructions (`device_info_plus`).
- [ ] Fresh‑start day‑of‑year throttle in prefs.
- [ ] `PermissionMonitorWorker` (6h) + `permission_alert` notifications.
- [ ] iOS: `FamilyControls` authorization + `FamilyActivityPicker` onboarding.
