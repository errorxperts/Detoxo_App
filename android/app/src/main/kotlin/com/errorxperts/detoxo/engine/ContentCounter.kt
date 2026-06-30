package com.errorxperts.detoxo.engine

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.errorxperts.detoxo.overlay.ContentCounterBubble
import com.errorxperts.detoxo.widget.ContentCounterWidgetProvider
import java.text.SimpleDateFormat
import java.util.Locale

/**
 * Decides WHEN a distinct short video is counted, persists via
 * [ContentCounterStore], emits the live `contentCounted` event, and drives the
 * home-screen widget + floating bubble.
 *
 * Counting is intentionally INDEPENDENT of blocking: the AccessibilityService
 * feeds it raw signals (foreground app, reel-surface detection, scrolls) from a
 * side-effect-free pass placed before the block logic, so it tallies reels
 * whether or not blocking is enabled, paused, or master-off.
 *
 * Distinct-reel heuristic (dwell-based, to avoid random inflation):
 *  - A reel is counted ONLY after its surface has been on screen for
 *    [MIN_VIEW_MS] (2s) — actually watched, not flicked past.
 *  - A scroll ends the current reel's dwell; the next detected surface starts a
 *    fresh window. Lingering on one reel counts it once.
 *
 * Bubble visibility:
 *  - SHOWN while a reel/short surface is on screen; stays up the whole time you
 *    watch (even during a passive, event-quiet video — a detection gap never
 *    hides it).
 *  - HIDDEN only on POSITIVE evidence you left reels: a checked window with no
 *    reel surface ([onNoReelSurface], e.g. the feed) after a short grace, or the
 *    foreground switching to another real app ([onForegroundChanged]).
 *  - Ignores our own overlay + system UI so it can't self-toggle (no blink).
 *
 * All state mutates on the accessibility service's single main thread; timers
 * post to that same main Looper, so no locks are needed.
 */
class ContentCounter(private val context: Context) {

    private val store = ContentCounterStore(context)
    private val bubble by lazy { ContentCounterBubble(context) }
    private val handler = Handler(Looper.getMainLooper())
    private val dwellRunnable = Runnable { onDwellElapsed() }
    private val hideRunnable = Runnable { hideBubble() }

    private var lastReelSurfaceAtMs = 0L
    private var reelActive = false
    private var reelCounted = false
    private var currentReelPkg: String? = null
    private var lastForegroundPkg: String? = null
    private var bubbleVisible = false
    private var hidePending = false
    private var lastWidgetPushMs = 0L

    val isEnabled: Boolean get() = store.enabled

    /**
     * Foreground app changed. Tracks the current reel app and hides the bubble
     * when the user leaves for another real app. Ignores our own overlay windows
     * and transient system UI so it can't cause a show/hide loop; the bubble is
     * SHOWN by [onReelSurfaceSeen], not here.
     */
    fun onForegroundChanged(pkg: String, isReelApp: Boolean) {
        if (pkg == context.packageName || pkg in TRANSIENT_PKGS) return
        if (pkg == lastForegroundPkg) return
        lastForegroundPkg = pkg
        endReel()
        if (isReelApp && store.enabled) {
            currentReelPkg = pkg
            // Wait for an actual reel surface before showing (reel/short context).
        } else {
            currentReelPkg = null
            hideBubble()
        }
    }

    /** A reel/short surface is on screen for [pkg] right now — show + keep it up. */
    fun onReelSurfaceSeen(pkg: String) {
        if (!store.enabled) return
        lastReelSurfaceAtMs = now()
        if (currentReelPkg == null) {
            currentReelPkg = pkg
            lastForegroundPkg = pkg
        }
        cancelHide()
        if (store.bubbleEnabled) {
            bubble.show(store.todayCount(dateKey()))
            bubbleVisible = true
        }
        if (!reelActive) startReel()
    }

    /**
     * A reel app's window was checked and had NO reel surface (e.g. the feed).
     * Schedule a short-grace hide (once) so between-reel transitions don't
     * flicker but leaving reels does hide the bubble. Passive watching never
     * reaches here (no event = no check), so it stays visible.
     */
    fun onNoReelSurface(pkg: String) {
        if (!store.enabled || !bubbleVisible || hidePending) return
        endReel() // no reel on screen → stop the dwell timer
        hidePending = true
        handler.postDelayed(hideRunnable, HIDE_GRACE_MS)
    }

    /** A scroll happened in [pkg]: still reel context, but advance the dwell. */
    fun onScroll(pkg: String) {
        if (!store.enabled || currentReelPkg == null) return
        if (reelActive) endReel()
    }

    fun setEnabled(on: Boolean) {
        store.enabled = on
        if (!on) {
            endReel()
            hideBubble()
        }
    }

    fun setBubbleEnabled(on: Boolean) {
        store.bubbleEnabled = on
        if (on) {
            // Reflect immediately if we're currently on a reel surface.
            if (store.enabled && now() - lastReelSurfaceAtMs < HIDE_GRACE_MS) {
                bubble.show(store.todayCount(dateKey()))
                bubbleVisible = true
                cancelHide()
            }
        } else {
            hideBubble()
        }
    }

    /** Current counter snapshot (for the pull command). */
    fun snapshot(): Map<String, Any?> = store.snapshot(dateKey())

    /**
     * The bubble's appearance changed (pushed from Dart). Re-render the visible
     * bubble from the freshly-persisted style; the widget is refreshed separately
     * by the command handler. No-op when nothing is on screen.
     */
    fun onStyleChanged() {
        if (bubbleVisible) bubble.onStyleChanged()
    }

    /** Cleanup hook called from the service's onUnbind/onDestroy. */
    fun dispose() {
        handler.removeCallbacks(dwellRunnable)
        handler.removeCallbacks(hideRunnable)
        bubble.hide()
        bubbleVisible = false
        hidePending = false
    }

    // ── Bubble hide (grace, only on positive "no reel" evidence) ────────────────

    private fun cancelHide() {
        hidePending = false
        handler.removeCallbacks(hideRunnable)
    }

    private fun hideBubble() {
        cancelHide()
        bubble.hide()
        bubbleVisible = false
    }

    // ── Dwell timing (counting) ────────────────────────────────────────────────

    private fun startReel() {
        reelActive = true
        reelCounted = false
        handler.removeCallbacks(dwellRunnable)
        handler.postDelayed(dwellRunnable, MIN_VIEW_MS)
    }

    private fun endReel() {
        reelActive = false
        reelCounted = false
        handler.removeCallbacks(dwellRunnable)
    }

    private fun onDwellElapsed() {
        val pkg = currentReelPkg ?: return
        if (!reelActive || reelCounted) return
        // Only count if the reel surface is still fresh — i.e. still watching.
        if (now() - lastReelSurfaceAtMs > REEL_SURFACE_STALE_MS) return
        reelCounted = true
        count(pkg)
    }

    // ── Persistence + fan-out ──────────────────────────────────────────────────

    private fun count(pkg: String) {
        if (!store.enabled) return
        store.recordCount(pkg, dateKey())
        val snap = store.snapshot(dateKey())
        val today = snap["today"] as? Int ?: 0
        ServiceEventBus.post(
            "contentCounted",
            mapOf(
                "package" to pkg,
                "today" to today,
                "total" to (snap["total"] as? Int ?: 0),
                "perAppToday" to snap["perAppToday"],
                "perAppTotal" to snap["perAppTotal"],
            ),
        )
        pushWidget(snap)
        if (store.bubbleEnabled && bubbleVisible) bubble.onCounted(today)
    }

    private fun pushWidget(snapshot: Map<String, Any?>) {
        val t = now()
        if (t - lastWidgetPushMs < WIDGET_MIN_INTERVAL_MS) return
        lastWidgetPushMs = t
        try {
            ContentCounterWidgetProvider.pushUpdate(context, snapshot)
        } catch (_: Throwable) {
        }
    }

    private fun now() = System.currentTimeMillis()

    private fun dateKey(): String =
        SimpleDateFormat("dd-MM-yyyy", Locale.US).format(System.currentTimeMillis())

    private companion object {
        /** A reel must be on screen this long to count as "watched" (anti-inflation). */
        const val MIN_VIEW_MS = 2000L

        /** A detection within this window means "still on a reel surface". */
        const val REEL_SURFACE_STALE_MS = 2000L

        /**
         * After a checked frame with no reel surface, wait this long before
         * hiding — bridges between-reel transitions without flicker, but hides
         * shortly after the user lands on a non-reel screen.
         */
        const val HIDE_GRACE_MS = 1500L

        /** Throttle native widget pushes so a count can't hammer the launcher. */
        const val WIDGET_MIN_INTERVAL_MS = 1000L

        /**
         * Windows that must NOT be treated as a foreground-app change — our own
         * overlay (would self-trigger a show/hide loop) and the system UI.
         */
        val TRANSIENT_PKGS = setOf("com.android.systemui")
    }
}
