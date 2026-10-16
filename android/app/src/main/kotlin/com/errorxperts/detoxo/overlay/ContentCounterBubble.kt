package com.errorxperts.detoxo.overlay

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.view.animation.OvershootInterpolator
import com.errorxperts.detoxo.engine.ContentCounterStore
import com.errorxperts.detoxo.overlay.bubble.BubbleEnvelope
import com.errorxperts.detoxo.overlay.bubble.BubbleFace
import com.errorxperts.detoxo.overlay.bubble.BubbleGeometry
import com.errorxperts.detoxo.overlay.bubble.BubbleStyleSpec
import com.errorxperts.detoxo.overlay.bubble.BubbleTokens
import com.errorxperts.detoxo.overlay.bubble.BubbleView
import com.errorxperts.detoxo.widget.WidgetBitmapRenderer
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * The window host of the floating reel bubble ([BubbleView] draws it; spec §6.1).
 *
 *  - Persists an *anchor*: the collapsed body's top-left in px (`cc_bubble_x/y`; unset → the
 *    right dock at 30 % height). The window is the body plus the view's envelope outsets
 *    ([BubbleEnvelope.window]), so the body never moves when the pill, pulse or timer capsule
 *    change the window; every envelope change is one [relayout].
 *  - Touch: a press on the body scales it to .9; a move past slop (from anywhere in the window)
 *    drags the anchor; release snaps to the nearer edge (12 dp, Drop 0) with Y clamped to
 *    20–70 %; an open timer folds as the drag starts. A tap (no drag) on the body — not the
 *    outsets — is the view's click, as TalkBack's is: it toggles the timer, which ticks once a
 *    second while open. Nothing here launches the app.
 *  - Silently no-ops without overlay permission. Lives in the existing accessibility FGS — no
 *    new service. All view ops run on the main Looper.
 *
 * [watchMs] is today's watch time including the counter's unflushed tail.
 */
class ContentCounterBubble(private val context: Context, private val watchMs: () -> Long) {

    private val wm by lazy {
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }
    private val mainHandler = Handler(Looper.getMainLooper())
    private val store by lazy { ContentCounterStore(context) }

    private var view: BubbleView? = null
    private var params: WindowManager.LayoutParams? = null
    private var shown = false
    private var warnedNoOverlay = false
    private var overlayDeniedAtMs = 0L
    private var snapAnimator: ValueAnimator? = null

    /** The collapsed body's top-left, px, and its docked side (see the class KDoc). */
    private var anchorX = 0
    private var anchorY = 0
    private var dockedRight = true

    /** Last count shown — replayed when the view is rebuilt on a style change. */
    private var lastCount = 0

    /**
     * One Reel / Unblock "reels left" override. Non-null → the bubble shows this
     * remaining count with a `left` caption instead of the today total; null →
     * the normal count. Replayed when the view is rebuilt.
     */
    private var lastRemaining: Int? = null

    /** The open timer's shown seconds (see [BubbleGeometry.nextShownSeconds]). */
    private var shownSec = 0

    // ponytail: the store accrues only between events < 12 s apart, so quiet playback stalls it;
    // the display leads it by at most 12 s and follows a drop (midnight) at once. Upgrade = the
    // 1 Hz foreground ticker in ContentCounter, then the display is the store.
    private val tick = object : Runnable {
        override fun run() {
            val v = view ?: return
            if (!v.isOpen) return
            shownSec = BubbleGeometry.nextShownSeconds(shownSec, watchSeconds())
            v.setWatchSeconds(shownSec)
            mainHandler.postDelayed(this, TICK_MS)
        }
    }

    // ── Public API (called by ContentCounter on the main thread) ───────────────

    fun show(count: Int) = runOnMain {
        lastCount = count
        // Steady state first — no binder call while the window is alive. The
        // attach check matters: on an overlay revoke the OS removes the window
        // but our fields survive, and without it a later re-grant would update
        // a detached view forever.
        val existing = view
        if (shown && existing != null && existing.isAttachedToWindow) {
            existing.setCount(count, pop = false)
            return@runOnMain
        }
        if (view != null) detach() // OS tore the window down — reset for re-add
        // show() runs on every surface check; without the grant each one was a
        // binder round-trip to AppOps. Remember a denial briefly — a fresh
        // grant is picked up on the first check after OVERLAY_RECHECK_MS.
        val t = SystemClock.uptimeMillis()
        if (t - overlayDeniedAtMs < OVERLAY_RECHECK_MS) return@runOnMain
        if (!Settings.canDrawOverlays(context)) {
            overlayDeniedAtMs = t
            // Once per process: a revoked overlay grant otherwise reads as "the
            // counter stopped" with zero trace (counting itself keeps running).
            if (!warnedNoOverlay) {
                warnedNoOverlay = true
                Log.w(TAG, "bubble suppressed: overlay permission missing")
            }
            return@runOnMain
        }
        overlayDeniedAtMs = 0L
        val v = newView()
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply { gravity = Gravity.TOP or Gravity.START }
        place(v, lp)
        attachTouch(v)
        try {
            wm.addView(v, lp)
            view = v
            params = lp
            shown = true
            appear(v)
            v.showPill()
        } catch (t: Throwable) {
            Log.w(TAG, "addView failed: ${t.message}")
        }
    }

    /**
     * Set the One Reel / Unblock "reels left" override (null → normal count).
     * Driven by the AccessibilityService as a reel session arms / ticks / reverts.
     */
    fun setRemaining(n: Int?) = runOnMain {
        lastRemaining = n
        view?.setRemaining(n)
    }

    /** A reel was counted: refresh the watch time, then the number (pop, or the tier change). */
    fun onCounted(count: Int) = runOnMain {
        lastCount = count
        val v = view ?: return@runOnMain
        shownSec = if (v.isOpen) max(shownSec, watchSeconds()) else watchSeconds()
        v.setWatchSeconds(shownSec)
        v.setCount(count, pop = true)
    }

    fun hide() = runOnMain { detach() }

    /** Synchronous teardown (main thread only) — shared by [hide] and [show]. */
    private fun detach() {
        snapAnimator?.end() // lands and saves an in-flight snap
        mainHandler.removeCallbacks(tick)
        val v = view ?: return
        v.stopLoops()
        try {
            wm.removeView(v)
        } catch (_: Throwable) {
        }
        view = null
        params = null
        shown = false
    }

    /**
     * Appearance changed while shown: rebuild the view from the freshly-persisted
     * style, collapsed, at the stored anchor (the dock side is recomputed and a new
     * edge — Drop clings at 0 — re-snaps without animation). No pill, no appear.
     * No-op when hidden — the next [show] picks up the new style.
     */
    fun onStyleChanged() = runOnMain {
        if (!shown) return@runOnMain
        val lp = params ?: return@runOnMain
        // Land a live snap first: it saves the anchor the rebuild restores from.
        snapAnimator?.end()
        mainHandler.removeCallbacks(tick)
        val old = view
        old?.stopLoops()
        val v = newView()
        place(v, lp)
        attachTouch(v)
        try {
            if (old != null) wm.removeView(old)
            wm.addView(v, lp)
            view = v
        } catch (t: Throwable) {
            Log.w(TAG, "restyle failed: ${t.message}")
        }
    }

    // ── View + window ──────────────────────────────────────────────────────────

    /** A collapsed view for the persisted style at the stored anchor (sets [anchorX]/[anchorY]/[dockedRight]). */
    private fun newView(): BubbleView {
        val spec = BubbleStyleSpec.fromJson(store.bubbleStyleJson)
        val a = BubbleGeometry.restoreAnchor(
            store.bubbleX, store.bubbleY, sizePx(spec), screenWidth(), screenHeight(), edgePx(BubbleFace.of(spec.variant)),
        )
        anchorX = a.x
        anchorY = a.y
        dockedRight = a.dockedRight
        // The bubble has no theme of its own: it takes the device's brightness, like a
        // System-theme widget.
        val brand = store.brand(WidgetBitmapRenderer.isSystemDark(context))
        return BubbleView(context, spec, brand, a.dockedRight, reduceMotion(), { view?.let(::toggleTimer) }) {
            relayout()
        }.apply {
            setCount(lastCount, pop = false)
            setWatchSeconds(watchSeconds())
            setRemaining(lastRemaining)
        }
    }

    /** Writes the window rect for the anchor + [v]'s envelope into [lp]. */
    private fun place(v: BubbleView, lp: WindowManager.LayoutParams) {
        val box = BubbleEnvelope.window(anchorX, anchorY, sizePx(v.spec), dockedRight, v.envelope, density())
        lp.x = box.x
        lp.y = box.y
        lp.width = box.w
        lp.height = box.h
    }

    /** Re-places the live window (one `updateViewLayout`). */
    private fun relayout() {
        val v = view ?: return
        val lp = params ?: return
        place(v, lp)
        try {
            wm.updateViewLayout(v, lp)
        } catch (_: Throwable) {
        }
    }

    /** The 500 ms appear spring (scale .6 → 1 + fade in). */
    private fun appear(v: BubbleView) {
        v.scaleX = 0.6f
        v.scaleY = 0.6f
        v.alpha = 0f
        v.animate()
            .scaleX(1f).scaleY(1f).alpha(1f)
            .setInterpolator(OvershootInterpolator())
            .setDuration(if (v.reduceMotion) 0L else BubbleTokens.MS_APPEAR.toLong())
            .start()
    }

    // ── Drag + press + tap + edge snap ─────────────────────────────────────────

    private fun attachTouch(v: BubbleView) {
        val slop = ViewConfiguration.get(context).scaledTouchSlop
        var startX = 0
        var startY = 0
        var downRawX = 0f
        var downRawY = 0f
        var dragging = false
        var downInBody = false

        v.setOnTouchListener { _, e ->
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    snapAnimator?.end()
                    startX = anchorX
                    startY = anchorY
                    downRawX = e.rawX
                    downRawY = e.rawY
                    dragging = false
                    downInBody = v.inBody(e.x, e.y)
                    if (downInBody) v.animate().scaleX(0.9f).scaleY(0.9f).setDuration(90).start()
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - downRawX
                    val dy = e.rawY - downRawY
                    if (!dragging && (abs(dx) > slop || abs(dy) > slop)) {
                        dragging = true
                        v.animate().scaleX(1f).scaleY(1f).setDuration(90).start()
                        // Fold first: the capsule never changes sides while open.
                        if (v.isOpen) toggleTimer(v)
                    }
                    if (dragging) {
                        anchorX = startX + dx.roundToInt()
                        anchorY = startY + dy.roundToInt()
                        relayout()
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    v.animate().scaleX(1f).scaleY(1f).setDuration(120).start()
                    // The tap is the view's click (as TalkBack's): it alone toggles.
                    if (dragging) snapToEdge(v) else if (downInBody) v.performClick()
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    v.animate().scaleX(1f).scaleY(1f).setDuration(120).start()
                    if (dragging) snapToEdge(v)
                    true
                }
                else -> false
            }
        }
    }

    /** The click (and a drag's fold): open (fresh seconds, ticking) or fold the timer. */
    private fun toggleTimer(v: BubbleView) {
        if (!v.isOpen) {
            shownSec = watchSeconds()
            v.setWatchSeconds(shownSec)
        }
        v.toggleTimer()
        mainHandler.removeCallbacks(tick)
        if (v.isOpen) mainHandler.postDelayed(tick, TICK_MS)
    }

    private fun snapToEdge(v: BubbleView) {
        val target = BubbleGeometry.snap(
            anchorX, anchorY, sizePx(v.spec), screenWidth(), screenHeight(), edgePx(v.face),
        )
        val fromX = anchorX
        val fromY = anchorY
        snapAnimator?.end()
        snapAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = if (v.reduceMotion) 0L else SNAP_MS
            interpolator = DecelerateInterpolator()
            addUpdateListener {
                val t = it.animatedValue as Float
                anchorX = (fromX + (target.x - fromX) * t).roundToInt()
                anchorY = (fromY + (target.y - fromY) * t).roundToInt()
                relayout()
            }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    snapAnimator = null
                    anchorX = target.x
                    anchorY = target.y
                    dockedRight = target.dockedRight
                    view?.setDockedRight(target.dockedRight)
                    relayout()
                    savePosition(anchorX, anchorY)
                }
            })
            start()
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    private fun watchSeconds(): Int = (watchMs() / 1000L).toInt()

    private fun reduceMotion(): Boolean =
        Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f

    private fun savePosition(x: Int, y: Int) {
        store.bubbleX = x
        store.bubbleY = y
    }

    private fun sizePx(spec: BubbleStyleSpec) = spec.sizeDp * density()
    private fun edgePx(face: BubbleFace) = face.edgeDp * density()
    private fun density() = context.resources.displayMetrics.density
    private fun screenWidth() = context.resources.displayMetrics.widthPixels
    private fun screenHeight() = context.resources.displayMetrics.heightPixels

    // overlayType() is shared with the block screen — see OverlayWindows.kt in this package.

    private fun runOnMain(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) block() else mainHandler.post(block)
    }

    private companion object {
        const val TAG = "CounterBubble"

        /** The open timer's tick. */
        const val TICK_MS = 1000L

        /** The edge snap after a drag. */
        const val SNAP_MS = 240L

        /** After a denied overlay check, skip the binder re-check for this long. */
        const val OVERLAY_RECHECK_MS = 5000L
    }
}
