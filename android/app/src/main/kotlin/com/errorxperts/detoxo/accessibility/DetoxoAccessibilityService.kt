package com.errorxperts.detoxo.accessibility

import android.accessibilityservice.AccessibilityService
import android.app.ActivityManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import androidx.core.app.NotificationCompat
import com.errorxperts.detoxo.R
import com.errorxperts.detoxo.admin.DetoxoDeviceAdminReceiver
import com.errorxperts.detoxo.engine.ConfigStore
import com.errorxperts.detoxo.engine.DetectionConfig
import com.errorxperts.detoxo.engine.DetectorRule
import com.errorxperts.detoxo.engine.ServiceEventBus
import java.text.SimpleDateFormat
import java.util.ArrayDeque
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap

/**
 * The detection + block engine. Verified behaviour from the reference app:
 *  - per-package event throttle (150 ms)
 *  - active-plan gate (paused window suspends blocking)
 *  - 3-stage view-id detection (source check -> findByViewId -> DFS, cap 12000)
 *  - block execution with a 1200 ms debounce and a 1100 ms back rate-limit
 */
class DetoxoAccessibilityService : AccessibilityService() {

    private lateinit var store: ConfigStore
    @Volatile private var config: DetectionConfig = DetectionConfig.EMPTY

    private val lastEventByPackage = ConcurrentHashMap<String, Long>()
    @Volatile private var lastBlockTime = 0L
    @Volatile private var lastBackTime = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        store = ConfigStore(this)
        reload()
        startAsForeground()
        ServiceEventBus.post("serviceStatus", mapOf("running" to true))
        Log.i(TAG, "service connected")
    }

    /** Reload config + settings (called after Dart pushes changes). */
    fun reload() {
        config = DetectionConfig.parse(store.platformsConfigJson)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val pkg = event.packageName?.toString() ?: return
        if (pkg == packageName) return
        if (!store.masterEnabled) return

        // Plan gate: a live pause window suspends all blocking.
        if (store.activePlan == "PAUSED" && System.currentTimeMillis() < store.pauseUntil) return

        // Per-package throttle.
        val now = System.currentTimeMillis()
        val last = lastEventByPackage[pkg] ?: 0L
        if (now - last < THROTTLE_MS) return
        lastEventByPackage[pkg] = now

        val platforms = config.platformsFor(pkg)
        if (platforms.isEmpty()) return

        val enabled = store.enabledPlatforms
        val root = rootInActiveWindow ?: return

        for (platform in platforms) {
            if (platform.detectionType != "LEGACY" && platform.detectionType != "OVERLAY") continue
            // Respect user enable/disable; fall back to defaultStatus if unset.
            val isOn = if (enabled.isEmpty()) platform.defaultStatus
            else enabled.contains(platform.platformId)
            if (!isOn) continue

            for (detector in platform.detectors) {
                if (detector.viewDetector != "FINDBYID" && detector.viewDetector != "VIEWID_RES_NAME") continue
                if (matches(root, event, detector, pkg)) {
                    onDetected(pkg, platform.platformId, detector)
                    if (detector.haltOnDetect) return
                }
            }
        }
    }

    // ---- Detection (3-stage view-id search) --------------------------------

    private fun matches(
        root: AccessibilityNodeInfo,
        event: AccessibilityEvent,
        detector: DetectorRule,
        pkg: String,
    ): Boolean {
        val byResName = detector.viewDetector == "VIEWID_RES_NAME"

        // Stage 1: the event source itself.
        val source = event.source
        val sourceId = source?.viewIdResourceName
        if (sourceId != null) {
            for (id in detector.identifiers) {
                val target = if (byResName) id else "$pkg$id"
                if (sourceId == target && source.isVisibleToUser) return true
            }
        }

        // Stage 2: direct resource-id lookup.
        for (id in detector.identifiers) {
            val target = if (byResName) id else "$pkg$id"
            val hits = root.findAccessibilityNodeInfosByViewId(target)
            if (!hits.isNullOrEmpty()) {
                for (n in hits) if (n != null && n.isVisibleToUser) return true
            }
        }

        // Stage 3: bounded DFS over the tree.
        val deque = ArrayDeque<AccessibilityNodeInfo>()
        deque.addLast(root)
        var i = 0
        while (deque.isNotEmpty() && i < MAX_NODES) {
            val node = deque.removeLast()
            i++
            val resName = node.viewIdResourceName
            if (resName != null) {
                for (id in detector.identifiers) {
                    val target = if (byResName) id else "$pkg$id"
                    if (resName == target && node.isVisibleToUser) return true
                }
            }
            for (c in node.childCount - 1 downTo 0) {
                node.getChild(c)?.let { deque.addLast(it) }
            }
        }
        return false
    }

    // ---- Block execution ---------------------------------------------------

    private fun onDetected(pkg: String, platformId: String, detector: DetectorRule) {
        val now = System.currentTimeMillis()
        if (now - lastBlockTime <= BLOCK_DEBOUNCE_MS) return
        lastBlockTime = now

        val mode = resolveBlockMode(detector)
        store.recordBlock(dateKey())
        val (today, total, _) = store.blockStats()
        ServiceEventBus.post(
            "blocked",
            mapOf("package" to pkg, "platformId" to platformId, "mode" to mode,
                "today" to today, "total" to total),
        )
        Log.i(TAG, "blocked $platformId in $pkg via $mode")

        when (mode) {
            "KILL_APP" -> { performBackInternal(); killApp(pkg) }
            "LOCK_SCREEN" -> { performBackInternal(); lockScreen() }
            "NONE" -> { /* no-op */ }
            else -> pressBackWithRateLimit()
        }
    }

    private fun resolveBlockMode(detector: DetectorRule): String {
        val def = store.defaultBlockMode
        val supported = detector.supportedBlockModes
        if (def != "NONE" && (supported.isEmpty() || supported.contains(def))) return def
        val firstSupported = supported.firstOrNull { it != "NONE" }
        return firstSupported ?: detector.defaultBlockMode.ifBlank { "PRESS_BACK" }
    }

    private fun pressBackWithRateLimit() {
        val now = System.currentTimeMillis()
        if (now - lastBackTime <= BACK_RATE_LIMIT_MS) return
        lastBackTime = now
        performBackInternal()
        if (store.vibrationEnabled) vibrate()
    }

    private fun performBackInternal() {
        performGlobalAction(GLOBAL_ACTION_BACK)
    }

    fun performBackPublic() = performBackInternal()

    fun killApp(pkg: String) {
        try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            am.killBackgroundProcesses(pkg)
        } catch (t: Throwable) {
            Log.w(TAG, "killApp failed: ${t.message}")
        }
    }

    fun lockScreen() {
        try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val admin = ComponentName(this, DetoxoDeviceAdminReceiver::class.java)
            if (dpm.isAdminActive(admin)) dpm.lockNow()
        } catch (t: Throwable) {
            Log.w(TAG, "lockScreen failed: ${t.message}")
        }
    }

    private fun vibrate() {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            vibrator.vibrate(VibrationEffect.createOneShot(40, VibrationEffect.DEFAULT_AMPLITUDE))
        } catch (_: Throwable) {
        }
    }

    private fun dateKey(): String =
        SimpleDateFormat("dd-MM-yyyy", Locale.US).format(System.currentTimeMillis())

    // ---- Foreground service + lifecycle ------------------------------------

    private fun startAsForeground() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Detoxo Service Status", NotificationManager.IMPORTANCE_LOW,
            ).apply {
                setShowBadge(false)
                description = "Focus protection active"
            }
            nm.createNotificationChannel(channel)
        }
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Detoxo is active")
            .setContentText("Monitoring and blocking short-form video.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .build()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(NOTIF_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            } else {
                startForeground(NOTIF_ID, notification)
            }
        } catch (t: Throwable) {
            Log.w(TAG, "startForeground failed: ${t.message}")
        }
    }

    override fun onInterrupt() {
        ServiceEventBus.post("serviceStatus", mapOf("running" to false))
    }

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        ServiceEventBus.post("serviceStatus", mapOf("running" to false))
        return super.onUnbind(intent)
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        // Keep the foreground service alive when the app is swiped away.
        try {
            startAsForeground()
        } catch (_: Throwable) {
        }
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    companion object {
        private const val TAG = "DetoxoService"
        private const val CHANNEL_ID = "detoxo_protection_channel"
        private const val NOTIF_ID = 1125
        private const val THROTTLE_MS = 150L
        private const val BLOCK_DEBOUNCE_MS = 1200L
        private const val BACK_RATE_LIMIT_MS = 1100L
        private const val MAX_NODES = 12000

        @Volatile
        var instance: DetoxoAccessibilityService? = null
            private set

        fun isRunning(): Boolean = instance != null
    }
}
