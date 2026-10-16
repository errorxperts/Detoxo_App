package com.errorxperts.detoxo.overlay.bubble.faces

import android.graphics.Canvas
import android.graphics.RectF
import com.errorxperts.detoxo.overlay.bubble.BubbleFace
import com.errorxperts.detoxo.overlay.bubble.BubbleFrame
import com.errorxperts.detoxo.overlay.bubble.BubblePaints
import com.errorxperts.detoxo.overlay.bubble.BubblePaths
import com.errorxperts.detoxo.overlay.bubble.BubbleTokens
import com.errorxperts.detoxo.widget.withAlpha
import kotlin.math.roundToInt

/** Mascot: a face whose mood follows the tier; the count sits in its own chip (drawn by the face). */
internal object MascotFace : BubbleFace {
    override val shellCount = false

    private const val WHITE = 0xFFFFFFFF.toInt()
    private val rect = RectF()

    // Per mood (= tier): blush, sweat, tears, hand alpha; pupil dx, dy.
    private val BLUSH = floatArrayOf(.7f, .7f, 0f, 0f, 0f, 0f)
    private val SWEAT = floatArrayOf(0f, 0f, 0f, .9f, .9f, 0f)
    private val TEARS = floatArrayOf(0f, 0f, 0f, 0f, .8f, 1f)
    private val HAND = floatArrayOf(0f, 0f, 0f, 0f, 0f, 1f)
    private val PUPIL_DX = floatArrayOf(0f, 0f, 0f, 1f, 0f, 0f)
    private val PUPIL_DY = floatArrayOf(0f, 0f, -1f, 0f, 1f, 1f)

    override fun drawOverlay(c: Canvas, f: BubbleFrame, p: BubblePaints) {
        val a = (1f - f.expand).coerceIn(0f, 1f)
        if (a <= 0f) return
        val m = f.tier.coerceIn(0, 5)
        val ink = fade(f.look.ink, a)
        val pupil = fade(BubbleTokens.MASCOT_PUPIL, a)

        c.save()
        c.translate(f.x(0f), f.y(0f))
        c.scale(f.s, f.s)

        rect.set(13f, 14f, 31f, 22f)
        c.drawOval(rect, p.solid(fade(WHITE, .55f * a)))
        p.circle(c, 25f, 30f, 7f, fade(BubbleTokens.MASCOT_EYE, a))
        p.circle(c, 43f, 30f, 7f, fade(BubbleTokens.MASCOT_EYE, a))
        p.circle(c, 26f + PUPIL_DX[m], 31f + PUPIL_DY[m], 3.6f, pupil)
        p.circle(c, 44f + PUPIL_DX[m], 31f + PUPIL_DY[m], 3.6f, pupil)
        p.circle(c, 27.2f, 29.6f, 1.1f, fade(WHITE, a))
        p.circle(c, 45.2f, 29.6f, 1.1f, fade(WHITE, a))

        c.drawPath(p.svg(BubblePaths.MASCOT_BROWS[m]), p.pen(ink, 2.2f))

        // Mouth: moods 1 and 2 are filled open mouths.
        val fill = if (m == 1 || m == 2) fade(BubbleTokens.MASCOT_PUPIL, .9f * a) else 0
        if (m == 2) {
            rect.set(30f, 36f, 38f, 46f) // oval centre (34,41), rx 4, ry 5 (no arcs in SvgPath)
            c.drawOval(rect, p.solid(fill))
            c.drawOval(rect, p.pen(ink, 2.4f))
        } else {
            val mouth = p.svg(BubblePaths.MASCOT_MOUTHS[m])
            if (fill != 0) c.drawPath(mouth, p.solid(fill))
            c.drawPath(mouth, p.pen(ink, 2.4f))
        }

        if (BLUSH[m] > 0f) {
            val blush = fade(BubbleTokens.MASCOT_BLUSH, BLUSH[m] * a)
            p.circle(c, 16f, 40f, 3f, blush)
            p.circle(c, 52f, 40f, 3f, blush)
        }
        if (SWEAT[m] > 0f) c.drawPath(p.svg(BubblePaths.MASCOT_SWEAT), p.solid(fade(BubbleTokens.MASCOT_WATER, SWEAT[m] * a)))
        if (TEARS[m] > 0f) c.drawPath(p.svg(BubblePaths.MASCOT_TEARS), p.pen(fade(BubbleTokens.MASCOT_WATER, TEARS[m] * a), 2f))
        if (HAND[m] > 0f) {
            val hand = p.svg(BubblePaths.MASCOT_HAND)
            c.drawPath(hand, p.solid(fade(WHITE, HAND[m] * a)))
            c.drawPath(hand, p.pen(fade(BubbleTokens.MASCOT_PUPIL, HAND[m] * a), 1.6f))
        }
        c.restore()

        // The count chip, px space (the shadow blur radius is device px).
        val w = p.textWidth(f.countText, f.u(11.5f)) + f.u(14f)
        val l = f.x(34f) - w / 2f
        val t = f.y(56f) - f.u(9f)
        val r = l + w
        val b = t + f.u(18f)
        val shadow = p.solid(fade(BubbleTokens.CHIP_SHADOW, a))
        shadow.maskFilter = p.blur(f.u(4f)) // CSS blur 4 = sigma 2 = radius 4
        c.drawRoundRect(l, t + f.u(1f), r, b + f.u(1f), f.u(9f), f.u(9f), shadow)
        p.roundRect(c, l, t, r, b, f.u(9f), fade(BubbleTokens.BADGE_BG, a))
        p.text(c, f.countText, f.x(34f), f.y(56f), f.u(11.5f), BubbleTokens.PILL_INK, alpha = a)
    }
}

// ---- helpers shared by the faces (the faces package is the only place that needs them) ----

/** [color] with its alpha × [a]. */
internal fun fade(color: Int, a: Float): Int =
    withAlpha(color, ((color ushr 24) * a.coerceIn(0f, 1f)).roundToInt())
