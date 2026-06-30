package com.errorxperts.detoxo.overlay

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.view.animation.OvershootInterpolator
import com.errorxperts.detoxo.engine.ContentCounterStore
import com.errorxperts.detoxo.engine.UsageLadder
import kotlin.math.abs
import kotlin.math.roundToInt
import org.json.JSONObject

/**
 * Floating bubble showing the live "reels seen today" count.
 *
 *  - On-brand glass badge: dark glass fill, seed→accent gradient ring, soft mint
 *    glow, white count — matching the app's glassmorphism.
 *  - Interactive: press-scale feedback, tap opens the app, drag moves it and it
 *    springs to the nearest horizontal edge; position is clamped on-screen and
 *    persisted across shows / restarts.
 *  - Silently no-ops without overlay permission. Lives in the existing
 *    accessibility FGS — no new service. All view ops run on the main Looper.
 */
class ContentCounterBubble(private val context: Context) {

    private val wm by lazy {
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }
    private val mainHandler = Handler(Looper.getMainLooper())
    private val store by lazy { ContentCounterStore(context) }

    private var view: BubbleView? = null
    private var params: WindowManager.LayoutParams? = null
    private var shown = false
    private var snapAnimator: ValueAnimator? = null

    /** Last count shown — replayed when the view is rebuilt on a style change. */
    private var lastCount = 0

    // ── Public API (called by ContentCounter on the main thread) ───────────────

    fun show(count: Int) = runOnMain {
        if (!Settings.canDrawOverlays(context)) return@runOnMain
        lastCount = count
        val existing = view
        if (shown && existing != null) {
            existing.setCount(count)
            return@runOnMain
        }
        val spec = BubbleStyleSpec.fromJson(store.bubbleStyleJson)
        val v = BubbleView(context, spec).apply { setCount(count) }
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType(),
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            val (px, py) = restorePosition()
            x = px
            y = py
        }
        attachTouch(v, lp)
        try {
            wm.addView(v, lp)
            view = v
            params = lp
            shown = true
            v.scaleX = 0.5f
            v.scaleY = 0.5f
            v.alpha = 0f
            v.animate()
                .scaleX(1f).scaleY(1f).alpha(1f)
                .setInterpolator(OvershootInterpolator())
                .setDuration(220)
                .start()
        } catch (t: Throwable) {
            Log.w(TAG, "addView failed: ${t.message}")
        }
    }

    /** A reel was counted: refresh the number with a springy pop. */
    fun onCounted(count: Int) = runOnMain {
        lastCount = count
        val v = view ?: return@runOnMain
        v.setCount(count)
        v.animate().scaleX(1.22f).scaleY(1.22f).setDuration(120).withEndAction {
            v.animate().scaleX(1f).scaleY(1f)
                .setInterpolator(OvershootInterpolator())
                .setDuration(170).start()
        }.start()
    }

    fun hide() = runOnMain {
        snapAnimator?.cancel()
        val v = view ?: return@runOnMain
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
     * style at the same position (any variant/size can change its measured bounds,
     * so a rebuild is simpler and safer than an in-place re-measure). No-op when
     * hidden — the next [show] picks up the new style.
     */
    fun onStyleChanged() = runOnMain {
        if (!shown) return@runOnMain
        val lp = params ?: return@runOnMain
        val spec = BubbleStyleSpec.fromJson(store.bubbleStyleJson)
        val old = view
        val v = BubbleView(context, spec).apply { setCount(lastCount) }
        attachTouch(v, lp)
        try {
            if (old != null) wm.removeView(old)
            wm.addView(v, lp)
            view = v
        } catch (t: Throwable) {
            Log.w(TAG, "restyle failed: ${t.message}")
        }
    }

    // ── Drag + press + edge snap ───────────────────────────────────────────────

    private fun attachTouch(v: View, lp: WindowManager.LayoutParams) {
        val slop = ViewConfiguration.get(context).scaledTouchSlop
        var startX = 0
        var startY = 0
        var downRawX = 0f
        var downRawY = 0f
        var dragging = false

        v.setOnTouchListener { _, e ->
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    snapAnimator?.cancel()
                    startX = lp.x
                    startY = lp.y
                    downRawX = e.rawX
                    downRawY = e.rawY
                    dragging = false
                    v.animate().scaleX(0.9f).scaleY(0.9f).setDuration(90).start()
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - downRawX
                    val dy = e.rawY - downRawY
                    if (!dragging && (abs(dx) > slop || abs(dy) > slop)) {
                        dragging = true
                        v.animate().scaleX(1f).scaleY(1f).setDuration(90).start()
                    }
                    if (dragging) {
                        lp.x = startX + dx.roundToInt()
                        lp.y = clampY(startY + dy.roundToInt())
                        updateLayout(v, lp)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    v.animate().scaleX(1f).scaleY(1f).setDuration(120).start()
                    if (dragging) snapToEdge(v, lp) else launchApp()
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    v.animate().scaleX(1f).scaleY(1f).setDuration(120).start()
                    if (dragging) snapToEdge(v, lp)
                    true
                }
                else -> false
            }
        }
    }

    private fun snapToEdge(v: View, lp: WindowManager.LayoutParams) {
        val screenW = screenWidth()
        val bubble = if (v.width > 0) v.width else dp(BUBBLE_DP)
        val margin = dp(MARGIN_DP)
        val targetX =
            if (lp.x + bubble / 2 < screenW / 2) margin else screenW - bubble - margin
        snapAnimator?.cancel()
        snapAnimator = ValueAnimator.ofInt(lp.x, targetX).apply {
            duration = 240
            interpolator = DecelerateInterpolator()
            addUpdateListener {
                lp.x = it.animatedValue as Int
                updateLayout(v, lp)
            }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) = savePosition(lp.x, lp.y)
            })
            start()
        }
    }

    private fun launchApp() {
        try {
            val intent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                } ?: return
            context.startActivity(intent)
        } catch (t: Throwable) {
            Log.w(TAG, "launchApp failed: ${t.message}")
        }
    }

    // ── Geometry helpers ───────────────────────────────────────────────────────

    private fun restorePosition(): Pair<Int, Int> {
        val w = screenWidth()
        val bubble = dp(BUBBLE_DP)
        val margin = dp(MARGIN_DP)
        val sx = store.bubbleX
        val sy = store.bubbleY
        val x = if (sx < 0) {
            w - bubble - margin
        } else {
            sx.coerceIn(margin, (w - bubble - margin).coerceAtLeast(margin))
        }
        val y = if (sy < 0) (screenHeight() * 0.3f).roundToInt() else clampY(sy)
        return x to y
    }

    private fun clampY(y: Int): Int {
        val bubble = dp(BUBBLE_DP)
        val top = dp(24f)
        val bottom = (screenHeight() - bubble - dp(40f)).coerceAtLeast(top)
        return y.coerceIn(top, bottom)
    }

    private fun savePosition(x: Int, y: Int) {
        store.bubbleX = x
        store.bubbleY = y
    }

    private fun updateLayout(v: View, lp: WindowManager.LayoutParams) {
        try {
            wm.updateViewLayout(v, lp)
        } catch (_: Throwable) {
        }
    }

    private fun screenWidth() = context.resources.displayMetrics.widthPixels
    private fun screenHeight() = context.resources.displayMetrics.heightPixels
    private fun dp(v: Float) = (v * context.resources.displayMetrics.density).roundToInt()

    private fun overlayType(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

    private fun runOnMain(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) block() else mainHandler.post(block)
    }

    private companion object {
        const val TAG = "CounterBubble"

        /** Full view size incl. the transparent glow margin (see [BubbleView]). */
        const val BUBBLE_DP = 64f
        const val MARGIN_DP = 4f
    }
}

/**
 * Immutable appearance for the bubble, parsed from the JSON persisted by the
 * Dart `BubbleStyle`. Fields are re-clamped here so a malformed payload can
 * never produce an unusable bubble.
 */
data class BubbleStyleSpec(
    val variant: String = GLASS_ORB,
    val sizeDp: Float = 48f,
    val textScale: Float = 1f,
    val spacing: Float = 1f,
    val opacity: Float = 0.95f,
    val showLabel: Boolean = false,
) {
    companion object {
        const val GLASS_ORB = "GLASS_ORB"
        const val USAGE_RING = "USAGE_RING"
        const val EMOJI_MOOD = "EMOJI_MOOD"
        const val MINIMAL_PILL = "MINIMAL_PILL"

        fun fromJson(json: String?): BubbleStyleSpec {
            if (json.isNullOrEmpty()) return BubbleStyleSpec()
            return try {
                val o = JSONObject(json)
                BubbleStyleSpec(
                    variant = o.optString("variant", GLASS_ORB),
                    sizeDp = o.optDouble("size", 48.0).toFloat().coerceIn(40f, 72f),
                    textScale = o.optDouble("textScale", 1.0).toFloat().coerceIn(0.8f, 1.4f),
                    spacing = o.optDouble("spacing", 1.0).toFloat().coerceIn(0.8f, 1.3f),
                    opacity = o.optDouble("opacity", 0.95).toFloat().coerceIn(0.5f, 1f),
                    showLabel = o.optBoolean("showLabel", false),
                )
            } catch (_: Throwable) {
                BubbleStyleSpec()
            }
        }
    }
}

/**
 * The bubble face. Renders one of four glass variants from a [BubbleStyleSpec]:
 *  - GLASS_ORB   dark glass circle, seed→accent ring, mint glow, centered count.
 *  - USAGE_RING  dark glass disc with a usage-colored progress ring (green→brown).
 *  - EMOJI_MOOD  a mood emoji (happy→worst per 50 reels) over a small count.
 *  - MINIMAL_PILL compact capsule: count + a usage-colored dot; width wraps text.
 *
 * The color/emoji ladders come from [UsageLadder] (shared with the widget and
 * the Flutter previews). Hardware-light: redraws only when the count changes.
 */
private class BubbleView(
    context: Context,
    private val spec: BubbleStyleSpec,
) : View(context) {

    private val density = resources.displayMetrics.density
    private val glowMargin = 8f * density
    private val diameter = spec.sizeDp * density // circle diameter / pill height
    private val contentRadius = diameter / 2f
    private val borderStroke = 2f * density
    private val isPill = spec.variant == BubbleStyleSpec.MINIMAL_PILL
    private val hasGlow =
        spec.variant == BubbleStyleSpec.GLASS_ORB || spec.variant == BubbleStyleSpec.EMOJI_MOOD

    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = borderStroke
    }
    private val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = 0x22FFFFFF
    }
    private val arcPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }
    private val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xFFFFFFFF.toInt()
        textAlign = Paint.Align.CENTER
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    }
    private val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xB3FFFFFF.toInt()
        textAlign = Paint.Align.CENTER
    }
    private val emojiPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
    }

    private var count = 0

    init {
        // Software layer so the mint glow (shadow layer) renders; the view only
        // redraws on count change, so there's no per-frame cost.
        setLayerType(LAYER_TYPE_SOFTWARE, null)
        if (hasGlow) {
            fillPaint.setShadowLayer(6f * density, 0f, 1.5f * density, 0x8044E2CD.toInt())
        }
    }

    fun setCount(value: Int) {
        if (value == count) return
        count = value
        if (isPill) requestLayout() // pill width depends on the number of digits
        invalidate()
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        if (isPill) {
            setMeasuredDimension(
                (pillContentWidth() + glowMargin * 2f).roundToInt(),
                (pillHeight() + glowMargin * 2f).roundToInt(),
            )
        } else {
            val s = ((contentRadius + glowMargin) * 2f).roundToInt()
            setMeasuredDimension(s, s)
        }
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        fillPaint.shader = LinearGradient(
            0f, 0f, 0f, h.toFloat(),
            withOpacity(0xF21C2544.toInt()), withOpacity(0xF20B1326.toInt()),
            Shader.TileMode.CLAMP,
        )
        borderPaint.shader = LinearGradient(
            0f, 0f, w.toFloat(), h.toFloat(),
            0xFF6D3BD7.toInt(), 0xFF44E2CD.toInt(),
            Shader.TileMode.CLAMP,
        )
    }

    override fun onDraw(canvas: Canvas) {
        when (spec.variant) {
            BubbleStyleSpec.USAGE_RING -> drawUsageRing(canvas)
            BubbleStyleSpec.EMOJI_MOOD -> drawEmoji(canvas)
            BubbleStyleSpec.MINIMAL_PILL -> drawPill(canvas)
            else -> drawOrb(canvas)
        }
    }

    // ── Variants ────────────────────────────────────────────────────────────────

    private fun drawOrb(canvas: Canvas) {
        val cx = width / 2f
        val cy = height / 2f
        canvas.drawCircle(cx, cy, contentRadius, fillPaint)
        canvas.drawCircle(cx, cy, contentRadius - borderStroke / 2f, borderPaint)
        drawCount(canvas, cx, cy)
    }

    private fun drawUsageRing(canvas: Canvas) {
        val cx = width / 2f
        val cy = height / 2f
        val ringStroke = contentRadius * 0.16f
        canvas.drawCircle(cx, cy, contentRadius, fillPaint)
        val r = contentRadius - ringStroke
        val rect = RectF(cx - r, cy - r, cx + r, cy + r)
        trackPaint.strokeWidth = ringStroke
        canvas.drawArc(rect, 0f, 360f, false, trackPaint)
        arcPaint.strokeWidth = ringStroke
        arcPaint.color = UsageLadder.color(count)
        val sweep = count.coerceIn(0, UsageLadder.CAP).toFloat() / UsageLadder.CAP * 360f
        if (count > 0) canvas.drawArc(rect, -90f, sweep.coerceAtLeast(8f), false, arcPaint)
        drawCount(canvas, cx, cy)
    }

    private fun drawEmoji(canvas: Canvas) {
        val cx = width / 2f
        val cy = height / 2f
        canvas.drawCircle(cx, cy, contentRadius, fillPaint)
        canvas.drawCircle(cx, cy, contentRadius - borderStroke / 2f, borderPaint)
        emojiPaint.textSize = contentRadius * 0.78f
        val efm = emojiPaint.fontMetrics
        canvas.drawText(
            UsageLadder.emoji(count),
            cx,
            cy - contentRadius * 0.12f - (efm.ascent + efm.descent) / 2f,
            emojiPaint,
        )
        textPaint.color = 0xFFFFFFFF.toInt()
        textPaint.textSize = contentRadius * 0.30f * spec.textScale
        val tfm = textPaint.fontMetrics
        canvas.drawText(
            count.toString(),
            cx,
            cy + contentRadius * 0.52f - (tfm.ascent + tfm.descent) / 2f,
            textPaint,
        )
    }

    private fun drawPill(canvas: Canvas) {
        val cy = height / 2f
        val rect = RectF(glowMargin, glowMargin, width - glowMargin, height - glowMargin)
        val radius = pillHeight() / 2f
        canvas.drawRoundRect(rect, radius, radius, fillPaint)
        canvas.drawRoundRect(rect, radius, radius, borderPaint)

        val dotR = pillDotRadius()
        val dotCx = rect.left + pillPadH() + dotR
        dotPaint.color = UsageLadder.color(count)
        canvas.drawCircle(dotCx, cy, dotR, dotPaint)

        textPaint.color = 0xFFFFFFFF.toInt()
        textPaint.textAlign = Paint.Align.LEFT
        textPaint.textSize = pillTextSize()
        val tfm = textPaint.fontMetrics
        canvas.drawText(count.toString(), dotCx + dotR + pillGap(), cy - (tfm.ascent + tfm.descent) / 2f, textPaint)
    }

    // ── Shared count drawing (orb / ring), with optional caption ─────────────────

    private fun drawCount(canvas: Canvas, cx: Float, cy: Float) {
        val label = count.toString()
        textPaint.color = 0xFFFFFFFF.toInt()
        textPaint.textAlign = Paint.Align.CENTER
        textPaint.textSize = baseTextSize(label) * spec.textScale
        if (spec.showLabel) {
            val fm = textPaint.fontMetrics
            canvas.drawText(
                label,
                cx,
                cy - (fm.ascent + fm.descent) / 2f - contentRadius * 0.16f,
                textPaint,
            )
            labelPaint.textSize = contentRadius * 0.26f
            canvas.drawText("reels", cx, cy + contentRadius * 0.52f, labelPaint)
        } else {
            val fm = textPaint.fontMetrics
            canvas.drawText(label, cx, cy - (fm.ascent + fm.descent) / 2f, textPaint)
        }
    }

    /** Base count size proportional to the radius (preserves the old 48dp ladder). */
    private fun baseTextSize(label: String): Float = contentRadius * when {
        label.length >= 4 -> 0.52f
        label.length == 3 -> 0.62f
        else -> 0.75f
    }

    // ── Pill metrics ─────────────────────────────────────────────────────────────

    private fun pillHeight() = diameter * 0.66f
    private fun pillTextSize() = pillHeight() * 0.42f * spec.textScale
    private fun pillDotRadius() = pillHeight() * 0.15f
    private fun pillPadH() = pillHeight() * 0.32f * spec.spacing
    private fun pillGap() = pillHeight() * 0.20f * spec.spacing

    private fun pillContentWidth(): Float {
        textPaint.textSize = pillTextSize()
        val tw = textPaint.measureText(count.toString())
        return pillPadH() + pillDotRadius() * 2f + pillGap() + tw + pillPadH()
    }

    /** Scales a color's alpha by the style opacity (fills only; borders stay solid). */
    private fun withOpacity(color: Int): Int {
        val a = (((color ushr 24) and 0xFF) * spec.opacity).roundToInt().coerceIn(0, 255)
        return (a shl 24) or (color and 0x00FFFFFF)
    }
}
