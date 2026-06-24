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
import android.os.Handler
import android.os.Looper
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

    // ── Conscious (earn-as-you-abstain) ──────────────────────────────────────
    // A 1 Hz accountant runs while the active plan is Conscious so the bank keeps
    // ticking even when the Flutter UI is dead.
    private val consciousHandler = Handler(Looper.getMainLooper())
    private var consciousRunning = false
    @Volatile private var lastReelAtMs = 0L
    // Foreground package, tracked for the Conscious accountant: "abstaining"
    // means the foreground app has no reel surfaces, so the bank only accrues
    // when the user is genuinely off a reel-bearing app.
    @Volatile private var foregroundPkg: String? = null
    private val consciousTick = object : Runnable {
        override fun run() {
            accountConscious()
            consciousHandler.postDelayed(this, CONSCIOUS_TICK_MS)
        }
    }

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
        syncConscious()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val pkg = event.packageName?.toString() ?: return

        // Track the foreground app for the Conscious accountant (every package,
        // including ours). Leaving a reel-bearing app for one without reel
        // surfaces immediately ends "watching" so the bank can start earning.
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            foregroundPkg = pkg
            if (config.platformsFor(pkg).isEmpty()) lastReelAtMs = 0L
        }

        if (pkg == packageName) return
        if (!store.masterEnabled) return

        // Plan gate: a live Pause window suspends ALL blocking (every app is
        // allowed) until pauseUntil, after which the active plan resumes. Gated
        // purely on the clock so it works regardless of the pushed plan name.
        if (System.currentTimeMillis() < store.pauseUntil) return

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
                    // Conscious mode: a reel is on screen. While there's allowance,
                    // mark "watching" (so the accountant drains the bank) and let
                    // it play. With an empty bank we leave "watching" untouched and
                    // fall through to block — so a bounced reel counts as
                    // abstaining and the bank starts refilling.
                    if (store.activePlan == PLAN_CONSCIOUS && store.consciousBankMs > 0L) {
                        lastReelAtMs = now
                        return
                    }
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
            "KILL_APP" -> { blockVibrate(); performBackInternal(); killApp(pkg) }
            "LOCK_SCREEN" -> { blockVibrate(); performBackInternal(); lockScreen() }
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
        blockVibrate()
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

    /** Vibrate for a block, honoring the user's haptics setting. */
    private fun blockVibrate() {
        if (store.vibrationEnabled) vibrate()
    }

    private fun vibrate() {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            // Firm, clearly-felt block buzz. On devices without amplitude control
            // the 255 is ignored and it plays at default strength.
            vibrator.vibrate(VibrationEffect.createOneShot(BLOCK_VIBRATION_MS, 255))
        } catch (_: Throwable) {
        }
    }

    private fun dateKey(): String =
        SimpleDateFormat("dd-MM-yyyy", Locale.US).format(System.currentTimeMillis())

    // ---- Conscious accountant ----------------------------------------------

    /** Start/stop the 1 Hz Conscious accountant to match the active plan. */
    private fun syncConscious() {
        val conscious = store.activePlan == PLAN_CONSCIOUS
        when {
            conscious && !consciousRunning -> {
                consciousRunning = true
                // Anchor to now so we don't retroactively credit service downtime
                // (the persisted bank carries over; the elapsed clock restarts).
                store.consciousAnchorMs = System.currentTimeMillis()
                lastReelAtMs = 0L
                consciousHandler.removeCallbacks(consciousTick)
                consciousHandler.postDelayed(consciousTick, CONSCIOUS_TICK_MS)
                emitConsciousState()
            }
            !conscious && consciousRunning -> {
                consciousRunning = false
                consciousHandler.removeCallbacks(consciousTick)
            }
            conscious -> emitConsciousState() // already running; refresh the UI
        }
    }

    /** One accounting step: drain while watching, accrue while abstaining. */
    private fun accountConscious() {
        if (store.activePlan != PLAN_CONSCIOUS) return
        val now = System.currentTimeMillis()
        val anchor = store.consciousAnchorMs.let { if (it <= 0L) now else it }
        val elapsed = (now - anchor).coerceAtLeast(0L)
        store.consciousAnchorMs = now // advance first, even when we freeze below

        // Master protection off → freeze the bank: neither drain nor accrue. The
        // anchor is already advanced so re-enabling doesn't dump a huge credit.
        if (!store.masterEnabled) {
            emitConsciousState()
            return
        }

        // "Watching": a reel was detected very recently. "In a reel app": the
        // foreground app has reel surfaces but detection has gone quiet (a paused
        // video / a non-feed overlay). We only accrue when genuinely off reels,
        // so a paused reel can never refill the bank (and never drains for free).
        val watching = (now - lastReelAtMs) < WATCH_STALE_MS
        val inReelApp = foregroundPkg?.let { config.platformsFor(it).isNotEmpty() } ?: false
        var bank = store.consciousBankMs
        if (watching) {
            bank -= elapsed.coerceAtMost(CONSCIOUS_MAX_STEP_MS)
            if (bank <= 0L) {
                bank = 0L
                lastReelAtMs = 0L
                pressBackWithRateLimit() // allowance spent → boot the reel
            }
        } else if (!inReelApp) {
            bank = (bank + elapsed / store.consciousEarnDivisor)
                .coerceAtMost(store.consciousMaxBankMs)
        }
        // else: lingering on a reel app with no fresh detection → hold steady.
        if (bank < 0L) bank = 0L
        store.consciousBankMs = bank
        emitConsciousState(bank = bank, watching = watching)
    }

    private fun emitConsciousState(
        bank: Long = store.consciousBankMs,
        watching: Boolean = (System.currentTimeMillis() - lastReelAtMs) < WATCH_STALE_MS,
    ) {
        ServiceEventBus.post("consciousState", consciousSnapshot(bank, watching))
    }

    /** Current Conscious bank state (also used for the pull query). */
    fun consciousSnapshot(
        bank: Long = store.consciousBankMs,
        watching: Boolean = (System.currentTimeMillis() - lastReelAtMs) < WATCH_STALE_MS,
    ): Map<String, Any?> {
        val active = store.activePlan == PLAN_CONSCIOUS
        return mapOf(
            "bankMs" to bank,
            "maxBankMs" to store.consciousMaxBankMs,
            "watching" to (active && watching),
            "blocked" to (active && bank <= 0L),
            "active" to active,
        )
    }

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
        consciousRunning = false
        consciousHandler.removeCallbacks(consciousTick)
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
        consciousRunning = false
        consciousHandler.removeCallbacks(consciousTick)
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

        /** Firm single block buzz — longer/stronger than a stray system tap. */
        private const val BLOCK_VIBRATION_MS = 60L

        /** Active-plan token for Conscious (shares the legacy "CURIOUS" wire). */
        private const val PLAN_CONSCIOUS = "CURIOUS"

        /** Conscious accountant cadence. */
        private const val CONSCIOUS_TICK_MS = 1000L

        /** A reel detected within this window counts as "still watching". */
        private const val WATCH_STALE_MS = 2500L

        /** Cap a single drain step so a delayed tick can't dump the whole bank. */
        private const val CONSCIOUS_MAX_STEP_MS = 5000L

        @Volatile
        var instance: DetoxoAccessibilityService? = null
            private set

        fun isRunning(): Boolean = instance != null
    }
}
