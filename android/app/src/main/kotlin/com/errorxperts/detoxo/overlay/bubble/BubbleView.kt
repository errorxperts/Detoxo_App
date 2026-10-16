package com.errorxperts.detoxo.overlay.bubble

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.TimeInterpolator
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.RectF
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.View
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.LinearInterpolator
import android.view.animation.OvershootInterpolator
import com.errorxperts.detoxo.overlay.bubble.faces.fade
import kotlin.math.roundToInt

/**
 * The floating reel bubble's shell (spec §6.2): state, animators and the draw pass; the style's
 * look lives in [face]. The body (a `size` square, widening into the timer capsule inward from
 * the docked edge) sits at the [envelope]'s outsets inside the view; the host sizes and places
 * the window from [envelope] on every [onEnvelopeChanged]. Twin of the Dart `BubblePainter` +
 * `BubblePreview`; the curves live in [BubbleGeometry], the text in [BubbleModel].
 *
 * Clickable: the host's touch release on the body and TalkBack's `ACTION_CLICK` both reach
 * [performClick], which runs [onTap] (the host's toggle) — the one tap path.
 *
 * Main thread only. Under [reduceMotion] every animator runs 0 ms and the loop never starts.
 */
internal class BubbleView(
    context: Context,
    val spec: BubbleStyleSpec,
    /** The app theme's primary (ARGB): the 0-reel glass takes its hue. */
    private val brand: Int,
    dockedRight: Boolean,
    val reduceMotion: Boolean,
    private val onTap: () -> Unit,
    private val onEnvelopeChanged: () -> Unit,
) : View(context) {
    val face: BubbleFace = BubbleFace.of(spec.variant)

    private val density = resources.displayMetrics.density
    private val sizePx = spec.sizeDp * density
    private val s = sizePx / BubbleTokens.SIZE
    private val paints = BubblePaints(context, spec.opacity)
    private val body = RectF()
    private val ticker = Handler(Looper.getMainLooper())

    // ── State ──
    private var dockedRight = dockedRight
    private var count = -1 // unset: the first setCount takes its tier without a transition
    private var tier = 0
    private var prevTier = 0
    private var look = BubbleLook.of(0, brand)
    private var prevLook = look
    private var open = false
    private var remaining: Int? = null
    private var watchSeconds = 0

    // Strings cached per change, so a looping frame allocates only its BubbleFrame.
    private var countText = "0"
    private var pct = 0
    private var remainingText = ""
    private var clock = BubbleModel.clock(0)
    private var shortTime = BubbleModel.shortTime(0)

    // ── Animated values ──
    private var blend = 1f
    private var pop = 0f
    private var pulse = 0f
    private var expand = 0f
    private var pill = 0f
    private var pulsing = false
    private var pillShown = false

    private var blendAnim: ValueAnimator? = null
    private var popAnim: ValueAnimator? = null
    private var pulseAnim: ValueAnimator? = null
    private var expandAnim: ValueAnimator? = null
    private var pillAnim: ValueAnimator? = null

    private var looping = false
    private var loopStart = 0L
    private val loopTick = object : Runnable {
        override fun run() {
            invalidate()
            ticker.postDelayed(this, 1000L / BubbleTokens.LOOP_FPS)
        }
    }
    private val pillRevert = Runnable { hidePill() }

    /** Current body size and extras, px; the host turns it into the window rect. */
    var envelope: EnvelopeState = EnvelopeState(sizePx, sizePx, false, false)
        private set
    private var outsetsPx = BubbleEnvelope.outsets(envelope, density)

    /** The body width, px: the square, widening to the timer capsule (board units, like its content) with `expand`. */
    val bodyWidthPx: Float get() = sizePx + (timerWidthPx() - sizePx) * expand

    val isOpen: Boolean get() = open

    /** Whether ([x], [y]), view px, lands on the body — the touch target (BR-08), not the outsets. */
    fun inBody(x: Float, y: Float): Boolean =
        x >= outsetsPx.left && x < outsetsPx.left + bodyWidthPx &&
            y >= outsetsPx.top && y < outsetsPx.top + sizePx

    init {
        // Blurs (BlurMaskFilter: glows, shadows) render only in software.
        setLayerType(LAYER_TYPE_SOFTWARE, null)
        isClickable = true // exposes ACTION_CLICK, which the label promises
        updateEnvelope()
    }

    override fun performClick(): Boolean {
        super.performClick()
        onTap()
        return true
    }

    // ── API (the host) ──

    /** Shows [newCount]: a tier up cross-fades, pulses and shows the pill; down cross-fades; else [pop]s. */
    fun setCount(newCount: Int, pop: Boolean) {
        val first = count < 0
        if (newCount == count) return
        val newTier = BubbleModel.tier(newCount)
        count = newCount
        countText = BubbleModel.countText(newCount)
        pct = BubbleModel.pct(newCount)
        if (first) {
            tier = newTier
            prevTier = newTier
            look = BubbleLook.of(newTier, brand)
        } else {
            when (BubbleModel.transition(tier, newTier)) {
                BubbleModel.TierChange.UP -> {
                    crossFade(newTier)
                    startPulse()
                    showPill()
                }
                BubbleModel.TierChange.DOWN -> crossFade(newTier)
                BubbleModel.TierChange.NONE -> if (pop) startPop()
            }
        }
        updateLabel()
        invalidate()
    }

    fun setWatchSeconds(seconds: Int) {
        if (seconds == watchSeconds) return
        val oldWidth = timerWidthPx()
        watchSeconds = seconds
        clock = BubbleModel.clock(seconds)
        shortTime = BubbleModel.shortTime(seconds)
        updateLabel()
        if (expand > 0f && timerWidthPx() != oldWidth) envelopeChanged() else invalidate()
    }

    /**
     * Slides the time pill in; it folds away after [BubbleTokens.MS_PILL]. Never while open.
     * Under reduce motion it is information, not motion: shown at once, hidden at once.
     */
    fun showPill() {
        if (open) return
        ticker.removeCallbacks(pillRevert)
        if (!pillShown) {
            pillShown = true
            envelopeChanged()
        }
        if (reduceMotion) {
            pillAnim?.quiet()
            pill = 1f
            invalidate()
        } else {
            pillAnim = tween(pillAnim, pill, 1f, BubbleTokens.MS_PILL_IN, OVERSHOOT) { pill = it }
        }
        ticker.postDelayed(pillRevert, BubbleTokens.MS_PILL.toLong())
    }

    /** Opens or folds the timer capsule (the tap). */
    fun toggleTimer() {
        open = !open
        if (open) hidePill()
        expandAnim = tween(expandAnim, expand, if (open) 1f else 0f, BubbleTokens.MS_TAP, OVERSHOOT) {
            expand = it.coerceAtLeast(0f) // the fold's overshoot would undercut the square
            envelopeChanged()
        }
        syncLoop()
        updateLabel()
    }

    /** One Reel's "N left" override; null → the normal count. */
    fun setRemaining(n: Int?) {
        if (n == remaining) return
        remaining = n
        remainingText = n?.toString() ?: ""
        updateLabel()
        invalidate()
    }

    fun setDockedRight(right: Boolean) {
        if (right == dockedRight) return
        dockedRight = right
        invalidate()
    }

    /** Cancels every animator, the loop and the pill revert (detach / rebuild). */
    fun stopLoops() {
        for (a in arrayOf(blendAnim, popAnim, pulseAnim, expandAnim, pillAnim)) a?.quiet()
        ticker.removeCallbacks(loopTick)
        ticker.removeCallbacks(pillRevert)
        looping = false
    }

    // ── Animators ──

    private fun crossFade(newTier: Int) {
        prevLook = look
        prevTier = tier
        tier = newTier
        val target = BubbleLook.of(newTier, brand)
        blendAnim = tween(blendAnim, 0f, 1f, BubbleTokens.MS_CROSSFADE, EASE, onEnd = {
            prevTier = tier
            blend = 1f
            look = target
        }) {
            blend = it
            look = BubbleLook.blend(prevLook, target, it)
        }
    }

    private fun startPop() {
        popAnim = tween(popAnim, 0f, 1f, BubbleTokens.MS_POP, LINEAR, onEnd = { pop = 0f }) { pop = it }
    }

    private fun startPulse() {
        if (!pulsing) {
            pulsing = true
            envelopeChanged()
        }
        pulseAnim = tween(pulseAnim, 0f, 1f, BubbleTokens.MS_PULSE, LINEAR, onEnd = {
            pulse = 0f
            pulsing = false
            envelopeChanged()
        }) { pulse = it }
    }

    private fun hidePill() {
        ticker.removeCallbacks(pillRevert)
        if (!pillShown) return
        val folded = {
            pill = 0f
            pillShown = false
            envelopeChanged()
        }
        if (reduceMotion) {
            pillAnim?.quiet()
            folded()
        } else {
            pillAnim = tween(pillAnim, pill, 0f, BubbleTokens.MS_PILL_OUT, EASE, onEnd = folded) { pill = it }
        }
    }

    /**
     * Replaces [prev] (silently: its end action is the new one's to own) with [from] → [to]
     * over [ms] (0 under reduce motion), redrawing on every value.
     */
    private fun tween(
        prev: ValueAnimator?,
        from: Float,
        to: Float,
        ms: Int,
        interpolator: TimeInterpolator,
        onEnd: (() -> Unit)? = null,
        onValue: (Float) -> Unit,
    ): ValueAnimator {
        prev?.quiet()
        onValue(from)
        return ValueAnimator.ofFloat(from, to).apply {
            duration = if (reduceMotion) 0L else ms.toLong()
            this.interpolator = interpolator
            addUpdateListener {
                onValue(it.animatedValue as Float)
                invalidate()
            }
            if (onEnd != null) {
                addListener(object : AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: Animator) {
                        onEnd()
                        invalidate()
                    }
                })
            }
            start()
        }
    }

    private fun ValueAnimator.quiet() {
        removeAllListeners()
        removeAllUpdateListeners()
        cancel()
    }

    // ── Loop ──

    private fun syncLoop() {
        val want = face.loops(open) && face.loopPeriodMs > 0 && isAttachedToWindow && !reduceMotion
        if (want == looping) return
        looping = want
        ticker.removeCallbacks(loopTick)
        if (want) {
            loopStart = SystemClock.uptimeMillis()
            ticker.post(loopTick)
        } else {
            invalidate() // settle the loop's phase at 0
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        syncLoop()
    }

    override fun onDetachedFromWindow() {
        stopLoops()
        super.onDetachedFromWindow()
    }

    // ── Envelope ──

    private fun timerWidthPx() = BubbleModel.timerWidth(watchSeconds, spec.variant) * s

    private fun updateEnvelope() {
        val w = bodyWidthPx
        envelope = EnvelopeState(w, sizePx, pulsing, pillShown)
        outsetsPx = BubbleEnvelope.outsets(envelope, density)
        // Press / appear scale about the body, not the window's centre.
        pivotX = outsetsPx.left + w / 2f
        pivotY = outsetsPx.top + sizePx / 2f
    }

    private fun envelopeChanged() {
        updateEnvelope()
        requestLayout()
        onEnvelopeChanged()
        invalidate()
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        setMeasuredDimension(
            (bodyWidthPx + outsetsPx.left + outsetsPx.right).roundToInt(),
            (sizePx + outsetsPx.top + outsetsPx.bottom).roundToInt(),
        )
    }

    private fun updateLabel() {
        if (count < 0) return
        val rem = remaining
        contentDescription = when {
            open -> BubbleModel.openLabel(watchSeconds)
            rem != null -> BubbleModel.remainingLabel(rem)
            else -> BubbleModel.collapsedLabel(count, watchSeconds, spec.variant)
        }
    }

    // ── Draw (spec §6.2 order, as the Dart BubblePainter) ──

    override fun onDraw(canvas: Canvas) {
        body.set(outsetsPx.left, outsetsPx.top, outsetsPx.left + bodyWidthPx, outsetsPx.top + sizePx)
        val period = face.loopPeriodMs
        val loopT = if (looping && period > 0) {
            ((SystemClock.uptimeMillis() - loopStart) % period).toFloat() / period
        } else {
            0f
        }
        val f = BubbleFrame(
            body, s, look, tier, prevTier, blend, count.coerceAtLeast(0), pct, countText, clock, shortTime,
            expand, pop, pulse, pill, loopT, open, dockedRight,
        )
        val c = canvas
        val breathes = face.loops(open)
        if (breathes) {
            val k = face.breathScale(loopT)
            c.save()
            c.scale(k, k, if (dockedRight) body.right else body.left, body.centerY())
        }
        face.drawBackground(c, f, paints)
        val rem = remaining
        if (rem == null) face.drawDial(c, f, paints)

        val countAlpha = 1f - expand
        val countScale = BubbleGeometry.popScale(pop) * (1f - 0.4f * expand)
        val glow = face.countGlow * s
        val glowColor = face.glowColor(look) ?: 0 // 0 = the text's own colour
        if (rem != null) {
            val ink = face.countColor(f)
            paints.text(
                c, remainingText, f.x(34f), f.y(29f), f.u(face.countSize), ink,
                scale = countScale, letterSpacing = f.u(-0.6f), alpha = countAlpha,
                glowPx = glow, glowColor = glowColor,
            )
            paints.text(c, "left", f.x(34f), f.y(52f), f.u(11f), ink, extraBold = false, alpha = countAlpha)
        } else if (face.shellCount) {
            paints.text(
                c, countText, f.x(34f), f.y(34f), f.u(face.countSize), face.countColor(f),
                scale = countScale, letterSpacing = f.u(-0.6f), alpha = countAlpha,
                glowPx = glow, glowColor = glowColor,
            )
        }

        drawTimer(c, f, glow, glowColor)
        if (rem == null) face.drawOverlay(c, f, paints)
        drawPulse(c, f)
        drawPill(c, f)
        if (breathes) c.restore()
    }

    /** The mark (20 × 31) then the clock, from the body's left, fading in over the last 70 % of expand. */
    private fun drawTimer(c: Canvas, f: BubbleFrame, glow: Float, glowColor: Int) {
        val alpha = BubbleGeometry.timerAlpha(expand)
        if (alpha <= 0f) return
        val left = body.left + f.u(face.timerPaddingLeft)
        val cy = body.centerY()
        paints.mark(
            c, f, left, cy - f.u(31f) / 2f, f.u(20f), f.u(31f),
            face.markFill(look), look.ink,
            if (face.timerGrain && open) f.loopT else null, alpha,
        )
        val size = f.u(BubbleTokens.TIMER_TEXT)
        val spacing = f.u(-0.4f)
        // Letter spacing adds to every glyph's advance (as Flutter's), so the run is n × spacing wider.
        val w = paints.textWidth(clock, size) + spacing * clock.length
        paints.text(
            c, clock, left + f.u(20f + 8f) + w / 2f, cy, size, f.look.ink,
            letterSpacing = spacing, alpha = alpha, glowPx = glow, glowColor = glowColor,
        )
    }

    /** The milestone ring (BR-06): the body shape growing by 23.8 units while fading out. */
    private fun drawPulse(c: Canvas, f: BubbleFrame) {
        if (pulse <= 0f) return
        val ring = paints.shape(f, f.u(23.8f) * pulse, 34f, face.radiusEdge)
        c.drawPath(ring, paints.pen(fade(look.ring, 0.9f * (1f - pulse)), f.u(2.5f)))
    }

    /** The time pill (BR-02) centred over the docked square, folding down as it hides; never while open. */
    private fun drawPill(c: Canvas, f: BubbleFrame) {
        if (pill <= 0f || open) return
        val alpha = pill.coerceIn(0f, 1f)
        val size = f.u(BubbleTokens.PILL_TEXT)
        val h = f.u(BubbleTokens.PILL_H)
        val w = paints.textWidth(shortTime, size) + 2f * f.u(9f)
        val cx = (if (dockedRight) body.right - sizePx else body.left) + sizePx / 2f
        val cy = body.top - f.u(BubbleTokens.PILL_GAP) - h / 2f + f.u(28f) * (1f - pill)
        val l = cx - w / 2f
        val t = cy - h / 2f
        paints.roundRect(c, l, t, l + w, t + h, h / 2f, fade(BubbleTokens.PILL_BG, alpha))
        val o = f.u(0.5f) // a 1-unit outline just outside the chip
        paints.roundRect(
            c, l - o, t - o, l + w + o, t + h + o, h / 2f + o,
            fade(look.ring, alpha), strokePx = f.u(1f),
        )
        paints.text(c, shortTime, cx, cy, size, BubbleTokens.PILL_INK, alpha = alpha)
    }

    private companion object {
        val OVERSHOOT = OvershootInterpolator()
        val LINEAR = LinearInterpolator()
        val EASE = AccelerateDecelerateInterpolator()
    }
}
