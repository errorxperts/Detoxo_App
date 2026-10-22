package com.errorxperts.detoxo.overlay

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Shader
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.SystemClock
import android.text.TextPaint
import android.util.TypedValue
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.animation.PathInterpolator
import android.widget.Button
import com.errorxperts.detoxo.R
import com.errorxperts.detoxo.widget.Manrope
import com.errorxperts.detoxo.widget.withAlpha
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.sin

/**
 * "Allow for a while" on the wall, as the app's `ConfirmSheet` slide: it
 * waits 5 s from [start], then a slide past 88 % of the track confirms, in
 * the caution tone, and [onConfirmed] runs a second later.
 *
 * - **Wait** — the knob (`DxTheme.waitKnob`) counts the seconds; the track
 *   reads "Take a breath…". The wait is `postDelayed` ticks against
 *   `SystemClock.uptimeMillis()`, never an Animator, so "Remove animations"
 *   (which scales Animators to 0) still waits the full 5 s.
 * - **Ready** — a white knob with the tone's chevrons nudges once; the track
 *   reads "Slide to unblock".
 * - **Slide** — the caution fill runs to the knob's far edge, and the label
 *   is painted twice, ink-2 on the bare track and the tone ink on the fill.
 *   At 88 % or more "Release to confirm" with a tick; an earlier release
 *   springs back; a tap shows "Slide all the way →" for 1.5 s.
 * - **Confirmed** — the knob runs to the end with a check and "Confirmed".
 *
 * Accessibility: reported as a Button; disabled with "Slide to unblock,
 * available in N seconds" during the wait, then a click (TalkBack's double
 * tap, Switch Access) confirms. A drag on the knob holds its parents off the
 * gesture (`requestDisallowInterceptTouchEvent`).
 */
@SuppressLint("ViewConstructor") // built in code only, by the renderer
internal class SlideToConfirmView(
    context: Context,
    private val theme: DxTheme,
    private val onConfirmed: () -> Unit,
) : View(context) {

    private val density = resources.displayMetrics.density
    private val still = reduceMotion(context)
    private val action = context.getString(R.string.wall_slide_unblock)
    private val slop = ViewConfiguration.get(context).scaledTouchSlop

    private val track = DxDrawable(theme.track, dp(DxTokens.RADIUS_BAR), theme.trackShadow, density)
    private val readyKnob = DxDrawable(
        fill = intArrayOf(withAlpha(WHITE, 0x80), withAlpha(WHITE, 0)),
        radiusPx = dp(KNOB) / 2f,
        shadows = arrayOf(
            DxShadowLayer(withAlpha(BLACK, 0x0D), 0f, -2f, 0f, 0f, true),
            DxShadowLayer(withAlpha(DxTokens.TONE_CAUTION_B, 0x59), 0f, 8f, 18f, 0f, false),
        ),
        density = density,
        base = theme.knob,
        stops = floatArrayOf(0f, 0.6f),
    )
    private val waitPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = theme.waitKnob }
    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private var fillShader: LinearGradient? = null
    private val fillMatrix = Matrix()
    private val chevrons = glyph(R.drawable.ic_dx_chevrons_right)
    private val check = glyph(R.drawable.ic_dx_check)
    private val labelPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = Manrope.extraBold(context)
        fontFeatureSettings = "'tnum'"
    }
    private val countPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = Manrope.extraBold(context)
        textSize = sp(DxTokens.BUTTON_SIZE)
        textAlign = Paint.Align.CENTER
        color = theme.ink2
        fontFeatureSettings = "'tnum'"
    }

    private var endAt = 0L
    private var left = WAIT_S
    private var countText = "$WAIT_S"
    private var fraction = 0f
    private var armed = false
    private var hint = false
    private var confirmed = false
    private var nudge = 0f
    private var dragging = false
    private var moved = false
    private var downX = 0f
    private var from = 0f
    private var spring: ValueAnimator? = null
    private var nudger: ValueAnimator? = null

    private var label = ""
    private var labelX = 0f
    private var labelBaseline = 0f

    private val ready get() = endAt != 0L && left == 0
    private val travel get() = (width - height).toFloat()

    private val tick = object : Runnable {
        override fun run() {
            val rest = endAt - SystemClock.uptimeMillis()
            val now = waitSecondsLeft(rest)
            if (now != left) {
                left = now
                countText = "$left"
                if (ready) onReady()
                describe()
                invalidate()
            }
            // Wake again when the next whole second is up.
            if (left > 0) postDelayed(this, (rest - (left - 1) * 1000L).coerceAtLeast(1L))
        }
    }
    private val unhint = Runnable {
        hint = false
        refreshLabel()
    }
    private val done = Runnable { onConfirmed() }

    init {
        isFocusable = true
        isClickable = true
        isEnabled = false
        describe()
    }

    /** Starts the wait, once: the slide was just revealed. */
    fun start() {
        if (endAt != 0L) return
        endAt = SystemClock.uptimeMillis() + WAIT_S * 1000L
        post(tick)
    }

    private fun onReady() {
        isEnabled = true
        if (still) return
        nudger = ValueAnimator.ofFloat(0f, 1f).setDuration(NUDGE_MS).apply {
            addUpdateListener {
                nudge = sin(PI * (it.animatedValue as Float)).toFloat()
                invalidate()
            }
            start()
        }
    }

    private fun describe() {
        contentDescription = if (ready || endAt == 0L) {
            action
        } else {
            resources.getQuantityString(R.plurals.wall_slide_wait, left, action, left)
        }
        refreshLabel()
    }

    /** The track's words for this moment, sized down to fit between the knob and the end. */
    private fun refreshLabel() {
        label = context.getString(
            when {
                confirmed -> R.string.wall_confirmed
                !ready -> R.string.wall_breath
                armed -> R.string.wall_release
                hint -> R.string.wall_slide_all
                else -> R.string.wall_slide_unblock
            },
        )
        val from = dp(LABEL_START)
        val room = width - from - dp(LABEL_END)
        labelPaint.textSize = sp(DxTokens.BUTTON_SIZE)
        val want = labelPaint.measureText(label)
        if (room > 0f && want > room) labelPaint.textSize *= room / want
        labelX = from + (room - labelPaint.measureText(label)).coerceAtLeast(0f) / 2f
        val fm = labelPaint.fontMetrics
        labelBaseline = height / 2f - (fm.ascent + fm.descent) / 2f
        invalidate()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        track.setBounds(0, 0, w, h)
        readyKnob.setBounds(0, 0, dp(KNOB).toInt(), dp(KNOB).toInt())
        // The fill's gradient over the whole track, scaled to the fill each frame.
        fillShader = LinearGradient(
            0f, 0f, w.toFloat(), 0f,
            intArrayOf(DxTokens.TONE_CAUTION_A, DxTokens.TONE_CAUTION_B, DxTokens.TONE_CAUTION_C),
            floatArrayOf(0f, 0.55f, 1f),
            Shader.TileMode.CLAMP,
        )
        refreshLabel()
    }

    override fun onDraw(canvas: Canvas) {
        val w = width.toFloat()
        val h = height.toFloat()
        val r = h / 2f
        track.draw(canvas)
        val dx = fraction.coerceIn(0f, 1f) * travel
        // The fill runs to the knob's far edge plus its 4 dp gutter, so a full slide fills the track.
        val fill = if (dx > 0f || confirmed) dx + h else 0f
        val shader = fillShader
        if (fill > 0f && shader != null) {
            fillMatrix.setScale(fill / w, 1f)
            shader.setLocalMatrix(fillMatrix)
            fillPaint.shader = shader // re-set: API 24–25 copy the shader into the paint
            canvas.drawRoundRect(0f, 0f, fill, h, r, r, fillPaint)
        }
        // The label twice: ink-2 on the bare track, the tone ink on the fill.
        canvas.save()
        canvas.clipRect(fill, 0f, w, h)
        labelPaint.color = theme.ink2
        canvas.drawText(label, labelX, labelBaseline, labelPaint)
        canvas.restore()
        if (fill > 0f) {
            canvas.save()
            canvas.clipRect(0f, 0f, fill, h)
            labelPaint.color = DxTokens.TONE_CAUTION_INK
            canvas.drawText(label, labelX, labelBaseline, labelPaint)
            canvas.restore()
        }

        val inset = (h - dp(KNOB)) / 2f
        canvas.save()
        canvas.translate(inset + dx + nudge * dp(NUDGE), inset)
        val k = dp(KNOB) / 2f
        if (ready) {
            readyKnob.draw(canvas)
            (if (confirmed) check else chevrons)?.draw(canvas)
        } else {
            canvas.drawCircle(k, k, k, waitPaint)
            val fm = countPaint.fontMetrics
            canvas.drawText(countText, k, k - (fm.ascent + fm.descent) / 2f, countPaint)
        }
        canvas.restore()
    }

    @SuppressLint("ClickableViewAccessibility") // a finger slides; the semantic click (performClick) confirms
    override fun onTouchEvent(e: MotionEvent): Boolean {
        if (!ready || confirmed) return true
        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                spring?.cancel()
                downX = e.x
                from = fraction
                moved = false
                val inset = (height - dp(KNOB)) / 2f
                val knobX = inset + fraction * travel
                dragging = e.x in knobX..knobX + dp(KNOB)
                if (dragging) parent?.requestDisallowInterceptTouchEvent(true)
            }
            MotionEvent.ACTION_MOVE -> if (dragging && travel > 0f) {
                if (abs(e.x - downX) > slop) moved = true
                fraction = (from + (e.x - downX) / travel).coerceIn(0f, 1f)
                val nowArmed = slideConfirms(fraction)
                if (nowArmed != armed || hint) {
                    armed = nowArmed
                    hint = false
                    removeCallbacks(unhint)
                    if (armed) performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                    refreshLabel()
                }
                invalidate()
            }
            MotionEvent.ACTION_UP -> {
                if (dragging && moved) release() else showHint()
                dragging = false
            }
            MotionEvent.ACTION_CANCEL -> {
                if (dragging) release()
                dragging = false
            }
        }
        return true
    }

    override fun performClick(): Boolean {
        super.performClick()
        confirm()
        return true
    }

    override fun getAccessibilityClassName(): CharSequence = Button::class.java.name

    private fun release() {
        if (slideConfirms(fraction)) {
            confirm()
            return
        }
        armed = false
        refreshLabel()
        springTo(0f)
    }

    private fun confirm() {
        if (confirmed || !ready) return
        confirmed = true
        armed = false
        hint = false
        removeCallbacks(unhint)
        performHapticFeedback(
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                HapticFeedbackConstants.CONFIRM
            } else {
                HapticFeedbackConstants.VIRTUAL_KEY
            },
        )
        contentDescription = context.getString(R.string.wall_confirmed)
        refreshLabel()
        springTo(1f)
        postDelayed(done, CONFIRM_MS)
    }

    private fun showHint() {
        hint = true
        refreshLabel()
        removeCallbacks(unhint)
        postDelayed(unhint, HINT_MS)
    }

    /** `AppCurves.press` over 400 ms; the system scales it to nothing under "Remove animations". */
    private fun springTo(target: Float) {
        spring?.cancel()
        spring = ValueAnimator.ofFloat(fraction, target).setDuration(PRESS_MS).apply {
            interpolator = PathInterpolator(0.34f, 1.56f, 0.64f, 1f)
            addUpdateListener {
                fraction = it.animatedValue as Float
                invalidate()
            }
            start()
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        track.setVisible(true, false)
        readyKnob.setVisible(true, false)
    }

    override fun onDetachedFromWindow() {
        removeCallbacks(tick)
        removeCallbacks(unhint)
        removeCallbacks(done)
        spring?.cancel()
        nudger?.cancel()
        track.setVisible(false, false)
        readyKnob.setVisible(false, false)
        super.onDetachedFromWindow()
    }

    /** A 24 dp glyph, centred in the 56 dp knob, in the tone's knob colour. */
    private fun glyph(id: Int): Drawable? = context.getDrawable(id)?.mutate()?.apply {
        setTint(DxTokens.TONE_CAUTION_KNOB)
        val o = ((dp(KNOB) - dp(GLYPH)) / 2f).toInt()
        setBounds(o, o, o + dp(GLYPH).toInt(), o + dp(GLYPH).toInt())
    }

    private fun dp(v: Float): Float = v * density

    private fun sp(v: Float): Float =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, v, resources.displayMetrics)

    private companion object {
        const val WHITE = 0xFFFFFFFF.toInt()
        const val BLACK = 0xFF000000.toInt()

        /** ConfirmSheet's wait, knob and glyph, the track's label padding, the ready nudge. */
        const val WAIT_S = 5
        const val KNOB = 56f
        const val GLYPH = 24f
        const val LABEL_START = 66f
        const val LABEL_END = 18f
        const val NUDGE = 10f
        const val NUDGE_MS = 600L
        const val PRESS_MS = 400L
        const val HINT_MS = 1500L
        const val CONFIRM_MS = 1000L
    }
}
