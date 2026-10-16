package com.errorxperts.detoxo.overlay.bubble.faces

import android.graphics.Canvas
import android.graphics.RectF
import com.errorxperts.detoxo.overlay.bubble.BubbleFace
import com.errorxperts.detoxo.overlay.bubble.GradientCache
import com.errorxperts.detoxo.overlay.bubble.BubbleFrame
import com.errorxperts.detoxo.overlay.bubble.BubbleLook
import com.errorxperts.detoxo.overlay.bubble.BubblePaints
import com.errorxperts.detoxo.overlay.bubble.BubbleTokens
import com.errorxperts.detoxo.widget.withAlpha
import kotlin.math.PI
import kotlin.math.sin

/** Liquid: the tier colour fills the glass to `pct` under a moving crest. */
internal object LiquidFace : BubbleFace {
    private const val WHITE = 0xFFFFFFFF.toInt()
    private val gradient = GradientCache()
    private val rect = RectF()

    override fun loops(open: Boolean) = true
    override val loopPeriodMs = BubbleTokens.MS_WAVE

    /** White once a dark tier's liquid has risen past the count. */
    override fun countColor(f: BubbleFrame) =
        if (f.tier >= 4 && f.pct > 55) WHITE else BubbleTokens.PILL_INK

    override fun markFill(l: BubbleLook): Int? = withAlpha(WHITE, 0x80)

    override fun drawBackground(c: Canvas, f: BubbleFrame, p: BubblePaints) {
        p.shell(
            c, f,
            fillFrom = BubbleTokens.LIQUID_GLASS, fillTo = BubbleTokens.LIQUID_GLASS,
            shadow = BubbleTokens.LIQUID_SHADOW,
        )
        val b = f.body
        val level = f.y(68f * (1f - f.pct.coerceIn(0, 100) / 100f))
        c.save()
        c.clipPath(p.shape(f))
        val fill = p.solid(WHITE)
        fill.shader = gradient.vertical(b.left, level, b.bottom, f.look.fillFrom, f.look.fillTo)
        c.drawRect(b.left, level, b.right, b.bottom, fill)
        fill.shader = null

        // Crest: half-ellipses rx 14 ry 8 every 28 along the level, clipped to the 12 units above it.
        c.clipRect(b.left, level - f.u(12f), b.right, level)
        val crest = p.solid(withAlpha(WHITE, 0x8C)) // white .55
        val rx = f.u(14f)
        val ry = f.u(8f)
        val x0 = b.left + f.u(-14f * sin(PI * f.loopT).toFloat()) - rx
        var cx = x0
        while (cx - rx < b.right) {
            rect.set(cx - rx, level - ry, cx + rx, level + ry)
            c.drawArc(rect, 180f, 180f, true, crest)
            cx += f.u(28f)
        }
        c.restore()
    }
}
