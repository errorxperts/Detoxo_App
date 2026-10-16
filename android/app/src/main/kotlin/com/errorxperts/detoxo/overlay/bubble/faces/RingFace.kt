package com.errorxperts.detoxo.overlay.bubble.faces

import android.graphics.Canvas
import com.errorxperts.detoxo.overlay.bubble.BubbleFace
import com.errorxperts.detoxo.overlay.bubble.BubbleFrame
import com.errorxperts.detoxo.overlay.bubble.BubblePaints

/** Ring: a progress arc toward the next colour; the arc stays while the timer is open. */
internal object RingFace : BubbleFace {
    override val countSize = 22f
    override val timerPaddingLeft = 72f

    override fun drawDial(c: Canvas, f: BubbleFrame, p: BubblePaints) {
        val cx = f.x(34f)
        val cy = f.y(34f)
        val r = f.u(30f)
        p.circle(c, cx, cy, r, f.look.faint, f.u(4f))
        if (f.pct > 0) p.arc(c, cx, cy, r, -90f, f.pct * 3.6f, f.look.ink, f.u(4f))
    }
}
