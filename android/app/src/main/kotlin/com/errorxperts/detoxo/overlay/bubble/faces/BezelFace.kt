package com.errorxperts.detoxo.overlay.bubble.faces

import android.graphics.Canvas
import com.errorxperts.detoxo.overlay.bubble.BubbleFace
import com.errorxperts.detoxo.overlay.bubble.BubbleFrame
import com.errorxperts.detoxo.overlay.bubble.BubbleModel
import com.errorxperts.detoxo.overlay.bubble.BubblePaints

/** Bezel: ten ticks round the rim light up every ten reels; the bezel stays while open. */
internal object BezelFace : BubbleFace {
    override val countSize = 21f
    override val timerPaddingLeft = 70f

    override fun drawDial(c: Canvas, f: BubbleFrame, p: BubblePaints) {
        val lit = BubbleModel.bezelLit(f.count)
        val cx = f.x(34f)
        val cy = f.y(34f)
        for (i in 0 until 10) {
            c.save()
            c.rotate(36f * i, cx, cy)
            p.line(c, cx, f.y(6f), cx, f.y(12f), if (i < lit) f.look.ink else f.look.faint, f.u(3f))
            c.restore()
        }
    }
}
