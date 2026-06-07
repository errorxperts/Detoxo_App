# Native Android Layer & Platform Channels

This document specifies the Kotlin code that Flutter **cannot host** and that our short-form-content blocker must implement natively, plus the clean MethodChannel/EventChannel contracts that bridge that native layer to Dart. A Flutter `MethodChannel`/`EventChannel` plugin can *talk to* an `AccessibilityService`, but it cannot *be* one: an `AccessibilityService` is a system-bound component declared in the manifest, instantiated by the framework in its own process, and given a `BIND_ACCESSIBILITY_SERVICE` lifecycle that never runs inside the Flutter engine. The same is true for the WindowManager overlay, DeviceAdmin, the boot/resurrection receivers, UsageStats, and the global "press back / kill app / lock screen" actions. Everything below is therefore marked ⚠️ **native-required** unless a mature pub package fully wraps it; for each item we name the exact package when one exists and add an `iOS:` note (the closest Apple FamilyControls/ScreenTime alternative, or "not possible").

> **Legend** — ✅ pub package handles it · ⚠️ needs native Kotlin behind a MethodChannel/EventChannel · ❌ not possible on iOS.

---

## 1. The native components Flutter cannot host

### 1.1 `AccessibilityServiceInfo` config ⚠️

The detection engine is an `android.accessibilityservice.AccessibilityService`. Its runtime behaviour is configured by an XML resource referenced from the `<service>`'s `android.accessibilityservice` meta-data. Re-create it as `android/app/src/main/res/xml/blocker_accessibility_config.xml`. Every attribute below is taken verbatim from the decompiled `resources/res/xml/site_manager_service.xml`.

| Attribute | Original verified value | Why we keep it |
|---|---|---|
| `android:accessibilityEventTypes` | `typeAllMask` | Receive every event type; the Dart layer filters to `WINDOW_STATE_CHANGED` / `WINDOW_CONTENT_CHANGED` itself. |
| `android:accessibilityFeedbackType` | `feedbackAllMask` | Required so the service can register as a generic (non-spoken) feedback provider. |
| `android:notificationTimeout` | `100` (ms) | Coalesces repeated events within 100 ms before delivery — first line of flood control, *before* our 150 ms per-package throttle. |
| `android:accessibilityFlags` | `flagRetrieveInteractiveWindows\|flagRequestFilterKeyEvents\|flagReportViewIds\|flagRequestEnhancedWebAccessibility` | `flagReportViewIds` is **mandatory** — without it `AccessibilityNodeInfo.getViewIdResourceName()` returns null and the entire FINDBYID strategy fails. `flagRequestFilterKeyEvents` lets `onKeyEvent` see BACK (used to dismiss the ONE_REEL overlay). `flagRetrieveInteractiveWindows` exposes the window list; `flagRequestEnhancedWebAccessibility` improves browser/WebView node coverage for web blocking. |
| `android:canRetrieveWindowContent` | `true` | Required to read the node tree at all. |
| `android:canRequestFilterKeyEvents` | `true` | Pairs with `flagRequestFilterKeyEvents` so the framework allows key-event filtering. |
| `android:description` | string resource | Text shown on the system Accessibility settings page. |
| `android:settingsActivity` | (optional) | Deep-link to our in-app config screen from system settings. |

```xml
<!-- android/app/src/main/res/xml/blocker_accessibility_config.xml -->
<?xml version="1.0" encoding="utf-8"?>
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:description="@string/accessibility_service_description"
    android:accessibilityEventTypes="typeAllMask"
    android:accessibilityFeedbackType="feedbackAllMask"
    android:notificationTimeout="100"
    android:accessibilityFlags="flagRetrieveInteractiveWindows|flagRequestFilterKeyEvents|flagReportViewIds|flagRequestEnhancedWebAccessibility"
    android:canRetrieveWindowContent="true"
    android:canRequestFilterKeyEvents="true" />
```

> **iOS:** ❌ There is no `AccessibilityServiceInfo` analogue. Apple's accessibility API (UIAccessibility / AX) is for making *your own* app accessible, never for reading other apps' view trees. The closest *behavioural* substitute is **FamilyControls / DeviceActivity / ManagedSettings** (parental-control, requires the Family Controls entitlement, no per-frame content inspection). Document as "not possible" for true short-video detection.

### 1.2 Manifest `<service>` declaration ⚠️

Re-create the service in `AndroidManifest.xml`. Verified shape of the original (`resources/AndroidManifest.xml`, the `NoScrollAccessibilityService` entry):

```xml
<!-- our clean re-implementation -->
<service
    android:name=".accessibility.ShortContentAccessibilityService"
    android:exported="true"
    android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE"
    android:process=":accessibility"
    android:foregroundServiceType="specialUse"
    android:canRetrieveWindowContent="true"
    android:label="@string/app_name">
    <intent-filter>
        <action android:name="android.accessibilityservice.AccessibilityService" />
    </intent-filter>
    <property
        android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
        android:value="Digital wellbeing and focus management via in-app Shorts/Reels blocking." />
    <meta-data
        android:name="android.accessibilityservice"
        android:resource="@xml/blocker_accessibility_config" />
</service>
```

Verified facts that drive this declaration:

- **`android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE"`** — every accessibility service must require this signature/system permission so only the framework can bind it.
- **Isolated process.** The original ran the service in a separate process. Note the **discrepancy in the decompiled sources**: the manifest `<service>` declares `android:process=":as_process"`, while the meta-data XML `site_manager_service.xml` declares `android:process=":accessibility_service_process"`. The manifest value (`:as_process`) is the one that actually takes effect for the service component (the `<accessibility-service>` element does not legitimately support `android:process`). We use a single clean name `:accessibility`. Isolation keeps the always-on node-tree scanner from crashing or bloating the Flutter UI process and survives independently.
- **`android:foregroundServiceType="specialUse"`** with the `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` property — required on API 34+. The original subtype string is *"Digital wellbeing and focus management via in-app Shorts/Reels blocking."* Google Play reviews this string.
- **`android:exported="true"`** — required so the system AccessibilityManager can bind it.

Required permissions (verified present in the original manifest), declared once at manifest top-level:

```xml
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
<uses-permission android:name="android.permission.KILL_BACKGROUND_PROCESSES" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE"
    android:minSdkVersion="34" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
<!-- DeviceAdmin lockNow needs no <uses-permission>; the receiver requires BIND_DEVICE_ADMIN -->
```

> The flutter project's `AndroidManifest.xml` and `xml/` resources are merged into the app at build time; declaring the service there is exactly how a Flutter app exposes a native AccessibilityService. The Flutter engine plays no part in its lifecycle.

---

## 2. Channel contracts (our names)

We split the native↔Dart boundary across **focused channels**, all under the reverse-DNS prefix `app.noscroll/`. Method/event names are ours; payloads are plain JSON-encodable maps (the only types that cross a platform channel cleanly). `AccessibilityNodeInfo` handles **never cross the boundary** — the node tree is searched in Kotlin and only a serialized `DetectedContent` map is sent to Dart.

### 2.1 Channel inventory

| Channel name | Type | Defined in (native) | Purpose |
|---|---|---|---|
| `app.noscroll/accessibility` | MethodChannel | `AccessibilityChannel.kt` | Service status query, enable-settings deep link, push config to native. |
| `app.noscroll/accessibility/events` | EventChannel | `AccessibilityChannel.kt` | Stream detections + service lifecycle native → Dart. |
| `app.noscroll/blocking` | MethodChannel | `BlockingChannel.kt` | Dart → native block commands (back / kill / lock). |
| `app.noscroll/overlay` | MethodChannel | `OverlayChannel.kt` | Show/hide system overlays. |
| `app.noscroll/overlay/events` | EventChannel | `OverlayChannel.kt` | Overlay dismissed / BACK-pressed-on-overlay native → Dart. |
| `app.noscroll/device_admin` | MethodChannel | `DeviceAdminChannel.kt` | Enable admin, `lockNow`, query admin/active state. |
| `app.noscroll/device_admin/events` | EventChannel | `DeviceAdminChannel.kt` | Admin enabled/disabled callbacks native → Dart. |
| `app.noscroll/system` | MethodChannel | `SystemChannel.kt` | Permission checks, usage-stats query, battery-optimization status, FGS start/stop. |
| `app.noscroll/system/events` | EventChannel | `SystemChannel.kt` | Boot/resurrection, screen on/off, accessibility-status broadcast native → Dart. |

### 2.2 Detailed method/event table

| Channel | Direction | Method / event | Payload | Returns |
|---|---|---|---|---|
| `…/accessibility` | Dart → native | `isServiceEnabled` | `{}` | `bool` — service present in `Settings.Secure` `enabled_accessibility_services`. |
| `…/accessibility` | Dart → native | `isServiceRunning` | `{}` | `bool` — present in `AccessibilityManager.getEnabledAccessibilityServiceList(...)`. |
| `…/accessibility` | Dart → native | `openAccessibilitySettings` | `{}` | `bool` (intent launched). Opens `Settings.ACTION_ACCESSIBILITY_SETTINGS`. |
| `…/accessibility` | Dart → native | `updateDetectionConfig` | `{ "platformsConfigJson": String, "activePlan": String, "defaultBlockMode": String, "vibration": bool, "webBlocklist": [ … ] }` | `bool` — pushes the data-driven `platforms_config.json` + runtime plan into the service process. |
| `…/accessibility` | Dart → native | `sendServiceCommand` | `{ "command": "PLAN_SWITCH" \| "REFRESH_DATA" \| "PAUSE_UPDATED" \| "CURIOUS_UPDATED", "args": {…} }` | `bool`. Mirrors the original `com.noscroll.action.APP_COMMAND` broadcast. |
| `…/accessibility/events` | native → Dart | `onContentDetected` | `DetectedContent` map (see §2.3) | — (stream) |
| `…/accessibility/events` | native → Dart | `onServiceStatusChanged` | `{ "enabled": bool }` | — (stream). Mirrors `ACCESSIBILITY_SERVICE_STATUS_CHANGED`. |
| `…/blocking` | Dart → native | `pressBack` | `{ "haptic": bool }` | `bool`. Calls `performGlobalAction(GLOBAL_ACTION_BACK)`. |
| `…/blocking` | Dart → native | `killApp` | `{ "packageName": String }` | `bool`. `ActivityManager.killBackgroundProcesses`. |
| `…/blocking` | Dart → native | `lockScreen` | `{}` | `bool`. `DevicePolicyManager.lockNow()` (requires active admin). |
| `…/blocking` | Dart → native | `vibrate` | `{ "pattern": "VIDEO_BLOCKED" \| "APP_BLOCKED" \| "DEVICE_LOCKED" \| "TAP" }` | `bool`. |
| `…/overlay` | Dart → native | `showOverlay` | `{ "type": "ONE_REEL" \| "CALIBRATION" \| "PIN_BLOCK", "touchable": bool, "packageName": String, "autoHideMs": int? }` | `bool`. |
| `…/overlay` | Dart → native | `hideOverlay` | `{ "type": String, "showToast": bool }` | `bool`. |
| `…/overlay` | Dart → native | `isOverlayPermissionGranted` | `{}` | `bool`. `Settings.canDrawOverlays(context)`. |
| `…/overlay` | Dart → native | `requestOverlayPermission` | `{}` | `bool` (intent launched). `ACTION_MANAGE_OVERLAY_PERMISSION`. |
| `…/overlay/events` | native → Dart | `onOverlayDismissed` | `{ "type": String, "reason": "BACK" \| "TIMEOUT" \| "TAP" }` | — (stream). `onKeyEvent` BACK closes ONE_REEL. |
| `…/device_admin` | Dart → native | `isAdminActive` | `{}` | `bool`. |
| `…/device_admin` | Dart → native | `requestAdmin` | `{ "explanation": String }` | `bool` (intent launched). `ACTION_ADD_DEVICE_ADMIN`. |
| `…/device_admin` | Dart → native | `removeAdmin` | `{}` | `bool`. |
| `…/device_admin/events` | native → Dart | `onAdminStateChanged` | `{ "active": bool }` | — (stream). From `DeviceAdminReceiver.onEnabled/onDisabled`. |
| `…/system` | Dart → native | `startForegroundService` | `{ "title": String, "text": String }` | `bool`. |
| `…/system` | Dart → native | `stopForegroundService` | `{}` | `bool`. |
| `…/system` | Dart → native | `hasUsageStatsPermission` | `{}` | `bool`. |
| `…/system` | Dart → native | `queryForegroundApp` | `{ "lookbackMs": int }` | `{ "packageName": String?, "lastUsedMs": int }`. `UsageStatsManager`. |
| `…/system` | Dart → native | `isIgnoringBatteryOptimizations` | `{}` | `bool`. |
| `…/system` | Dart → native | `requestIgnoreBatteryOptimizations` | `{}` | `bool` (intent launched). |
| `…/system/events` | native → Dart | `onBootCompleted` | `{ "action": "BOOT_COMPLETED" \| "MY_PACKAGE_REPLACED" \| "QUICKBOOT_POWERON" }` | — (stream). |
| `…/system/events` | native → Dart | `onScreenStateChanged` | `{ "screenOn": bool }` | — (stream). `ACTION_SCREEN_ON/OFF`. |

### 2.3 `DetectedContent` payload schema (native → Dart)

Serialized from the original `DetectedReelConfig` + `ShortContentDetectionResponse` (verified field set). The matched `AccessibilityNodeInfo` is **not** sent; instead its id and a match-reason tag are.

```jsonc
{
  "platformId":        "instagram_reels",       // string
  "platformName":      "Instagram Reels",       // string
  "packageName":       "com.instagram.android", // string (foreground app)
  "iconUrl":           "https://…/ig.png",      // string | null
  "isBrowser":         false,                   // bool
  "premiumExclusive":  false,                   // bool
  "supportedBlockModes": ["PRESS_BACK","KILL_APP","LOCK_SCREEN"], // string[]
  "defaultBlockMode":  "PRESS_BACK",            // string (PRESS_BACK|KILL_APP|LOCK_SCREEN|NONE)
  "supportsOverlay":   true,                    // bool
  "matchReason":       "[FIND]",                // "[FIND]" | "[DEEP]" | "[URL_MATCH]"
  "matchedViewId":     ":id/clips_author_username", // string (the FINDBYID identifier that hit)
  "detectedUrl":       null,                    // string | null (BROWSER only)
  "timestampMs":       1733560000000            // int (epoch ms)
}
```

Block-mode and detection enum string values are the **verified original constants**: `BlockingModesEnum = PRESS_BACK | KILL_APP | LOCK_SCREEN | NONE`; `ViewDetectorsEnum = FINDBYID | VIEWID_RES_NAME | CONT_DESC | BROWSER`; `DetectionTypeEnum = LEGACY | CALIBRATION | OVERLAY | MANUAL | NONE`. Keep them as JSON strings to stay forward-compatible with the server config.

---

## 3. Where detection logic lives: a deliberate boundary choice

The original ran *everything* (throttle → plan gate → detector dispatch → block) inside the AccessibilityService process. For the Flutter rebuild you must decide how much crosses the channel. Two viable splits:

**Option A — thin native, fat Dart (NOT recommended for the hot path).** Native forwards every raw event to Dart; Dart runs detection. ❌ Rejected: serializing the node tree per event and round-tripping through the Flutter engine on the isolated process is far too slow for the 150 ms throttle budget and the 12 000-iteration DFS, and the Flutter engine may not even be warm in the `:accessibility` process.

**Option B — fat native hot path, Dart owns config & policy (recommended).** Native keeps the latency-critical loop entirely in Kotlin (node-tree DFS, the verified throttles/debounces, `performGlobalAction`). Dart owns everything *cold*: parsing `platforms_config.json`, plan/premium/quota policy, analytics, UI. Dart pushes config down via `updateDetectionConfig` and receives `onContentDetected` for logging/UI only.

The constants the native hot path must enforce (all **verified** in `NoScrollAccessibilityService.java`):

| Constant (our name) | Verified value | Effect |
|---|---|---|
| `throttleIntervalMs` | `150` | Per-package skip window (`packageThrottleMap`). |
| `blockDebounceMs` | `1200` | `blockShortContent` skips if `now − lastBlockTime ≤ 1200`. |
| `pressBackRateLimitMs` | `1100` | BACK only fires if `lastVideoBlocked ≤ now − 1100`, then `performGlobalAction(GLOBAL_ACTION_BACK)` + haptic. |
| `oneReelOverlayGraceMs` | `500` | Grace after ONE_REEL overlay shown. |
| `oneReelOverlayPollMs` | `500` | Auto-hide poll interval. |
| `hardBlockAfterCloseTapMs` | `~10000` | Hard-block grace (Unity SCAR timeout) — skip detection while `now < hardBlockUntilMs`. |
| `appLockerDedupeMs` | `2000` | `AppLockerProcessor` dedupes restrict calls; deque capacity `4`. |

`BlockingModesEnum` ordinals are **verified**: `PRESS_BACK(1)`, `KILL_APP(2)`, `LOCK_SCREEN(3)`, `NONE(4)`. `PlansEnum = BLOCK_ALL | CURIOUS | ONE_REEL | PAUSED`.

> Block-mode resolution (verified, inside the grace window of `handleShortVideoDetection`): use `defaultBlockingMode`; else the first non-`NONE` entry of `supportedBlockModes`; else fall back to `PRESS_BACK`.

---

## 4. Package vs. custom service: when to use each

| Concern | Pub package | Verdict & trade-off |
|---|---|---|
| AccessibilityService binding + event stream | `flutter_accessibility_service` | ⚠️ **Prototype only.** It wraps a generic service and streams a flattened event/node snapshot to Dart. It does **not** expose `getViewIdResourceName`-keyed search with the 3-stage fallback (event source → `findAccessibilityNodeInfosByViewId` → 12 000-iteration DFS), couple-with child validation, or `performGlobalAction`. For a faithful, low-latency rebuild, write a **custom Kotlin service** (Option B). Use the package to validate the permission-grant UX early, then replace it. |
| System overlays | `flutter_overlay_window` | ✅/⚠️ **Adequate for ONE_REEL / cooldown / PIN UI.** It renders a real Flutter widget tree in a `TYPE_APPLICATION_OVERLAY` window and gives you a separate overlay entrypoint. Good enough that you may **not** need a custom overlay renderer. Trade-offs: limited control of exact `LayoutParams` flags/gravity, no Compose-grade animation, and the overlay runs its own engine (state must be passed in). If you need the verified touch-flag behaviour (`FLAG_NOT_FOCUSABLE` 262920 non-touchable vs `FLAG_NOT_FOCUSABLE\|FLAG_NOT_TOUCHABLE` 262936 touchable, gravity `8388659`, `layoutInDisplayCutoutMode=1`), drop to a custom `WindowManager.addView` renderer. |
| Back press / kill / lock | none mature | ⚠️ **Always custom.** `performGlobalAction`, `ActivityManager.killBackgroundProcesses`, and `DevicePolicyManager.lockNow` have no reliable pub wrapper and `performGlobalAction` *must* be called from the running AccessibilityService instance anyway. Keep on `…/blocking`. |
| Device admin | `device_admin` (immature) | ⚠️ **Custom `DeviceAdminReceiver`.** The pub options are unmaintained; you need your own `<receiver>` + `device_admin_policies.xml` for uninstall protection + `lockNow`. |
| Foreground service | `flutter_foreground_task` | ⚠️ **Useful but not for the accessibility process.** Good for a *separate* monitor/keepalive foreground service with a Dart callback. The AccessibilityService must call `startForeground` itself in Kotlin (it has its own process and lifecycle). |
| Boot / package-replaced | none | ⚠️ **Custom `BroadcastReceiver`** declared in the manifest (receivers cannot be declared in Dart). |
| Screen on/off | `screen_state` | ✅ Usable; or fold into the custom `…/system/events` receiver to avoid an extra plugin. |
| Usage stats | `usage_stats` | ✅ Usable for periodic polling; ⚠️ not real-time (the AccessibilityService is the real-time foreground-app source). |
| Vibration | `vibration` | ✅ Pure pub. Map our `VIDEO_BLOCKED / APP_BLOCKED / DEVICE_LOCKED / TAP` patterns to waveforms. |
| Biometric unlock | `local_auth` | ✅ Wraps `BiometricPrompt`. Original used error codes `10` (USER_CANCELED) and `13` (NEGATIVE_BUTTON) as "cancel"; `local_auth` surfaces these as a failed/false result. |
| Battery optimization check | `permission_handler` + custom | ⚠️ `permission_handler` requests; reading `isIgnoringBatteryOptimizations()` needs the `…/system` channel. |

**Bottom line:** use `flutter_overlay_window`, `vibration`, `local_auth`, `usage_stats`, `screen_state` off the shelf; hand-write the **AccessibilityService**, **blocking actions**, **DeviceAdmin**, and the **boot/screen/status receivers** in Kotlin behind our channels.

> **iOS:** the entire §4 table collapses to FamilyControls/ManagedSettings. No overlay-over-other-apps, no kill/lock of arbitrary apps, no node-tree read. `local_auth` and `vibration` work; everything blocking-related is ❌.

---

## 5. Foreground service, notification & resurrection ⚠️

Verified from `NoScrollAccessibilityService.java`:

- `startForeground` with **notification id `1125`**, channel id **`noscroll_protection_channel`**, channel importance **LOW**, with copy *"NoScroll is active: Monitoring and blocking short-form video content"*.
- FGS type **`specialUse`** on API 34+ (subtype string in §1.2).
- **`onTaskRemoved` re-promotes to foreground** — the resurrection trick: when the user swipes the app from recents, the service re-issues `startForeground` so the framework keeps the isolated process alive.
- Status broadcast on connect/unbind: `ACCESSIBILITY_SERVICE_STATUS_CHANGED` with extra `extra_accessibility_service_enabled` (we forward this as `onServiceStatusChanged`).
- Command intake: `com.noscroll.action.APP_COMMAND` registered `RECEIVER_NOT_EXPORTED` → an `EnumCommandToService` (we expose this as `sendServiceCommand`).

```kotlin
// inside the service
private fun goForeground() {
    val mgr = getSystemService(NotificationManager::class.java)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        mgr.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Protection", NotificationManager.IMPORTANCE_LOW)
        )
    }
    val n = NotificationCompat.Builder(this, CHANNEL_ID)
        .setContentTitle("Blocker is active")
        .setContentText("Monitoring and blocking short-form video content")
        .setSmallIcon(R.drawable.ic_shield)
        .setOngoing(true)
        .build()
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
        startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
    } else {
        startForeground(NOTIF_ID, n)
    }
}

override fun onTaskRemoved(rootIntent: Intent?) {
    goForeground() // resurrection: keep the isolated process alive after swipe-away
    super.onTaskRemoved(rootIntent)
}

private companion object {
    const val NOTIF_ID = 1125                              // verified
    const val CHANNEL_ID = "noscroll_protection_channel"  // verified
}
```

Boot/resurrection across reboots is a **separate manifest `<receiver>`** (verified original `SystemReceiver` listening `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, `QUICKBOOT_POWERON`):

```xml
<receiver android:name=".system.BootReceiver" android:enabled="true" android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        <category android:name="android.intent.category.DEFAULT" />
    </intent-filter>
</receiver>
```

> The AccessibilityService itself is auto-rebound by the framework after boot once the user has enabled it; the boot receiver mainly re-starts the *companion* foreground/monitor service and notifies Dart via `onBootCompleted`. iOS: ❌ no boot broadcast; FamilyControls restrictions persist via the system, not your code.

---

## 6. Minimal illustrative Kotlin stubs (our names)

Skeletons only — illustrative blueprints, written clean, not copied. The detection algorithm itself (3-stage FINDBYID, web URL canonicalization) is documented in the detection-engine doc; here we show the *service shell + channel wiring*.

### 6.1 Service skeleton

```kotlin
// android/app/src/main/kotlin/app/noscroll/accessibility/ShortContentAccessibilityService.kt
package app.noscroll.accessibility

class ShortContentAccessibilityService : AccessibilityService() {

    private val packageThrottle = ConcurrentHashMap<String, Long>()
    private val lastBlockTime = AtomicLong(0L)
    private val lastVideoBlocked = AtomicLong(0L)
    private val hardBlockUntilMs = AtomicLong(0L)

    @Volatile private var config: DetectionConfig = DetectionConfig.empty()

    override fun onServiceConnected() {
        super.onServiceConnected()
        goForeground()
        ServiceBus.bind(this)                 // lets channels reach the live instance
        broadcastStatus(enabled = true)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val pkg = event.packageName?.toString() ?: return
        val now = SystemClock.elapsedRealtime()

        // 1) per-package throttle (verified 150 ms)
        val last = packageThrottle[pkg]
        if (last != null && now - last < THROTTLE_MS) return
        packageThrottle[pkg] = now

        // 2) active-plan gate (PAUSED/CURIOUS phases) — policy mirrored from Dart config
        if (!config.isDetectionAllowed(pkg, now)) return

        // 3) hard-block grace
        if (now < hardBlockUntilMs.get()) return

        // 4) detector dispatch (FINDBYID / CONT_DESC / BROWSER) -> serialized result
        val detected = ViewHierarchyDetector.detect(event, rootInActiveWindow, config) ?: return

        // 5) execute + debounce, then notify Dart for logging/UI
        block(detected, now)
        AccessibilityChannel.emitDetection(detected.toMap())
    }

    private fun block(d: DetectedContent, now: Long) {
        if (now - lastBlockTime.get() <= BLOCK_DEBOUNCE_MS) return   // verified 1200
        lastBlockTime.set(now)
        when (d.resolveMode()) {                                     // default -> first non-NONE -> PRESS_BACK
            BlockMode.PRESS_BACK -> {
                if (lastVideoBlocked.get() <= now - PRESS_BACK_RL_MS) { // verified 1100
                    lastVideoBlocked.set(now)
                    performGlobalAction(GLOBAL_ACTION_BACK)
                    if (config.vibration) Haptics.play(VibePattern.VIDEO_BLOCKED)
                }
            }
            BlockMode.KILL_APP   -> AppLocker.restrict(LockAction.CLOSE_APP, d.packageName, now)
            BlockMode.LOCK_SCREEN-> AppLocker.restrict(LockAction.LOCK_SCREEN, d.packageName, now)
            BlockMode.NONE       -> Unit
        }
    }

    override fun onKeyEvent(e: KeyEvent): Boolean {
        if (e.keyCode == KeyEvent.KEYCODE_BACK) OverlayRenderer.dismissOneReel(reason = "BACK")
        return super.onKeyEvent(e)
    }

    override fun onUnbind(intent: Intent?): Boolean {
        broadcastStatus(enabled = false)
        OverlayRenderer.hideAll()
        ServiceBus.unbind()
        return super.onUnbind(intent)
    }

    override fun onInterrupt() { /* required no-op */ }

    private companion object {
        const val THROTTLE_MS = 150L
        const val BLOCK_DEBOUNCE_MS = 1200L
        const val PRESS_BACK_RL_MS = 1100L
    }
}
```

### 6.2 Channel wiring (registered in `MainActivity` / plugin `onAttachedToEngine`)

```kotlin
// android/app/src/main/kotlin/app/noscroll/channels/AccessibilityChannel.kt
object AccessibilityChannel : EventChannel.StreamHandler {
    private var events: EventChannel.EventSink? = null

    fun register(messenger: BinaryMessenger, ctx: Context) {
        MethodChannel(messenger, "app.noscroll/accessibility").setMethodCallHandler { call, result ->
            when (call.method) {
                "isServiceEnabled"        -> result.success(AccessibilityUtils.isEnabled(ctx))
                "isServiceRunning"        -> result.success(AccessibilityUtils.isRunning(ctx))
                "openAccessibilitySettings" -> result.success(AccessibilityUtils.openSettings(ctx))
                "updateDetectionConfig"   -> {
                    ServiceBus.instance?.applyConfig(DetectionConfig.fromMap(call.arguments()))
                    result.success(true)
                }
                "sendServiceCommand"      -> {
                    ServiceBus.instance?.handleCommand(call.argument("command")!!, call.argument("args"))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, "app.noscroll/accessibility/events").setStreamHandler(this)
    }

    fun emitDetection(map: Map<String, Any?>) =
        MainHandler.post { events?.success(mapOf("event" to "onContentDetected", "data" to map)) }

    fun emitStatus(enabled: Boolean) =
        MainHandler.post { events?.success(mapOf("event" to "onServiceStatusChanged", "data" to mapOf("enabled" to enabled))) }

    override fun onListen(args: Any?, sink: EventChannel.EventSink?) { events = sink }
    override fun onCancel(args: Any?) { events = null }
}
```

```kotlin
// android/app/src/main/kotlin/app/noscroll/channels/BlockingChannel.kt
object BlockingChannel {
    fun register(messenger: BinaryMessenger, ctx: Context) {
        MethodChannel(messenger, "app.noscroll/blocking").setMethodCallHandler { call, result ->
            val svc = ServiceBus.instance
            when (call.method) {
                "pressBack"  -> result.success(svc?.let { it.performGlobalAction(AccessibilityService.GLOBAL_ACTION_BACK) } ?: false)
                "killApp"    -> result.success(AppLocker.kill(ctx, call.argument("packageName")!!))
                "lockScreen" -> result.success(DeviceAdminManager.lockNow(ctx))
                "vibrate"    -> { Haptics.play(VibePattern.valueOf(call.argument("pattern")!!)); result.success(true) }
                else -> result.notImplemented()
            }
        }
    }
}
```

`ServiceBus` is a tiny holder so channels can reach the live service instance (channels run in the **main** process; the service in `:accessibility`). For cross-process calls, the original used `RECEIVER_NOT_EXPORTED` broadcasts — replicate with a signature-permission-protected internal broadcast (`updateDetectionConfig` / `sendServiceCommand` become broadcasts the service receives), since a `MethodChannel` cannot directly invoke an object in another process.

### 6.3 Dart-side channel wrapper (datasource layer)

```dart
// lib/data/datasources/platform/accessibility_datasource.dart
import 'package:flutter/services.dart';

class AccessibilityDataSource {
  static const _method = MethodChannel('app.noscroll/accessibility');
  static const _events = EventChannel('app.noscroll/accessibility/events');

  Future<bool> isServiceEnabled() async =>
      await _method.invokeMethod<bool>('isServiceEnabled') ?? false;

  Future<bool> isServiceRunning() async =>
      await _method.invokeMethod<bool>('isServiceRunning') ?? false;

  Future<void> openSettings() => _method.invokeMethod('openAccessibilitySettings');

  Future<void> pushConfig({
    required String platformsConfigJson,
    required String activePlan,
    required String defaultBlockMode,
    required bool vibration,
    required List<Map<String, dynamic>> webBlocklist,
  }) =>
      _method.invokeMethod('updateDetectionConfig', {
        'platformsConfigJson': platformsConfigJson,
        'activePlan': activePlan,
        'defaultBlockMode': defaultBlockMode,
        'vibration': vibration,
        'webBlocklist': webBlocklist,
      });

  Future<void> sendCommand(String command, [Map<String, dynamic>? args]) =>
      _method.invokeMethod('sendServiceCommand', {'command': command, 'args': args});

  /// Native -> Dart. Multiplexed event stream; demux on the `event` key.
  Stream<NativeAccessibilityEvent> watch() =>
      _events.receiveBroadcastStream().map((dynamic raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        switch (m['event'] as String) {
          case 'onContentDetected':
            return NativeAccessibilityEvent.detected(
              DetectedContent.fromJson(Map<String, dynamic>.from(m['data'] as Map)),
            );
          case 'onServiceStatusChanged':
            return NativeAccessibilityEvent.statusChanged(
              (m['data'] as Map)['enabled'] as bool,
            );
          default:
            return const NativeAccessibilityEvent.unknown();
        }
      });
}
```

```dart
// lib/data/datasources/platform/blocking_datasource.dart
class BlockingDataSource {
  static const _ch = MethodChannel('app.noscroll/blocking');

  Future<bool> pressBack({bool haptic = true}) async =>
      await _ch.invokeMethod<bool>('pressBack', {'haptic': haptic}) ?? false;

  Future<bool> killApp(String packageName) async =>
      await _ch.invokeMethod<bool>('killApp', {'packageName': packageName}) ?? false;

  Future<bool> lockScreen() async =>
      await _ch.invokeMethod<bool>('lockScreen') ?? false;
}
```

This `AccessibilityDataSource` is consumed by the `data/repositories` layer; the BLoCs in `presentation/bloc/accessibility/` subscribe to `watch()` and dispatch events, keeping all native I/O behind the Clean-Architecture data boundary.

---

## 7. Other native-required components (quick reference)

| Component | Native artifact | Verified evidence | Channel |
|---|---|---|---|
| DeviceAdmin (uninstall protection + `lockNow`) ⚠️ | `<receiver>` requiring `BIND_DEVICE_ADMIN`, `xml/device_admin_policies.xml`, `DEVICE_ADMIN_ENABLED` filter | original `NSDeviceAdminReceiver` | `…/device_admin` |
| Boot / package-replaced ⚠️ | manifest `<receiver>` | original `SystemReceiver` | `…/system/events` |
| Accessibility-status broadcast ⚠️ | manifest `<receiver>` exported | original `AccessibilityStatusReceiver` | `…/accessibility/events` |
| Cross-process settings sync ⚠️ | `ContentProvider` (authority `com.newswarajya.noswipe.provider`) | original `NoScrollContentProvider` | (use signed broadcast or shared DataStore) |
| App-usage monitor FGS ⚠️ | separate `specialUse` foreground service | original `AppMonitorService` (subtype "Monitoring app usage for PIN lock functionality.") | `…/system` |
| Usage stats ✅/⚠️ | `UsageStatsManager` | `PACKAGE_USAGE_STATS` permission present | `…/system` `queryForegroundApp` |
| Overlay window ✅/⚠️ | `flutter_overlay_window` or `WindowManager.addView` (`TYPE_APPLICATION_OVERLAY`=2032) | original `OverlayUIRenderer` (flags 262920/262936, gravity 8388659) | `…/overlay` |

> **iOS for all of §7:** ❌. DeviceAdmin → no equivalent (MDM only). Boot/usage/overlay/kill/lock → none. The only sanctioned restriction surface is FamilyControls + ManagedSettings, which can hide/limit apps system-side but cannot inspect or block in-app short-video content.

---

## Source evidence

- `resources/res/xml/site_manager_service.xml` — verified `AccessibilityServiceInfo` attributes (event types, feedback, `notificationTimeout=100`, flags, `canRetrieveWindowContent`, `canRequestFilterKeyEvents`).
- `resources/AndroidManifest.xml` — verified `<service NoScrollAccessibilityService>` (`BIND_ACCESSIBILITY_SERVICE`, `:as_process`, `specialUse` FGS + subtype), `SystemReceiver` (boot), `NSDeviceAdminReceiver`, `AccessibilityStatusReceiver`, `AppMonitorService`, `NoScrollContentProvider`, and permission set.
- `service/accessibility/NoScrollAccessibilityService.java` — verified constants (THROTTLE_INTERVAL_MS=150, 1200 ms debounce, 1100 ms BACK rate-limit, ONE_REEL grace/poll 500, notification id 1125, channel `noscroll_protection_channel`, `com.noscroll.action.APP_COMMAND`, `ACCESSIBILITY_SERVICE_STATUS_CHANGED`, `onTaskRemoved` resurrection, `onKeyEvent` BACK).
- `service/accessibility/processors/detectors/LegacyDetector.java` — FINDBYID 3-stage search, `[FIND]`/`[DEEP]` tags, 12 000-iteration DFS, web URL canonicalization (cited; algorithm detailed in sibling doc).
- `service/accessibility/processors/applocker/AppLockerProcessor.java` — 2000 ms dedupe, deque capacity 4, CLOSE_APP/LOCK_SCREEN actions.
- `service/accessibility/overlay/OverlayUIRenderer.java` — WindowManager overlay flags 262920/262936, gravity 8388659, `TYPE_APPLICATION_OVERLAY` (2032).
- Cached analysis: `/tmp/ns_analysis/accessibility-core.json`, `/tmp/ns_analysis/detectors-and-processors-accessibility-d.json`, `/tmp/ns_analysis/overlay-and-pinblock.json`, `/tmp/synth_flutterPlan.md`.

## Related docs

- `01-architecture-overview.md`
- `02-detection-engine.md`
- `03-data-model-and-config.md`
- `05-overlays-and-pin-block.md`
- `06-blocking-modes-and-plans.md`
- `07-flutter-clean-architecture.md`
- `08-ios-limitations.md`
