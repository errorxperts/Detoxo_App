package com.errorxperts.detoxo.overlay.bubble.faces

import android.graphics.Canvas
import android.graphics.RectF
import com.errorxperts.detoxo.overlay.bubble.BubbleFace
import com.errorxperts.detoxo.overlay.bubble.BubbleFrame
import com.errorxperts.detoxo.overlay.bubble.BubblePaints
import com.errorxperts.detoxo.overlay.bubble.BubbleTokens
import kotlin.math.PI
import kotlin.math.sin

/** Drop: a droplet that clings to the screen edge and breathes (the view applies the breath scale). */
internal object DropFace : BubbleFace {
    private val rect = RectF()

    override val edgeDp = 0f

    /** The docked side narrows to a point into the edge. */
    override val radiusEdge = 10f
    override fun loops(open: Boolean) = true
    override val loopPeriodMs = BubbleTokens.MS_BREATH

    /** Breath 1 → 1.06 → 1 over the loop. */
    override fun breathScale(loopT: Float) = 1f + 0.06f * sin(PI * loopT).toFloat()

    override fun drawOverlay(c: Canvas, f: BubbleFrame, p: BubblePaints) {
        // Sheen on the free side: x 23, mirrored to 45 when docked left.
        val cx = f.x(if (f.dockedRight) 23f else 45f)
        val cy = f.y(15f)
        rect.set(cx - f.u(11f), cy - f.u(5f), cx + f.u(11f), cy + f.u(5f))
        c.drawOval(rect, p.solid(BubbleTokens.SHEEN))
    }
}
