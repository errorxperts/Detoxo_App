package com.errorxperts.detoxo.overlay.bubble.faces

import android.graphics.Canvas
import android.graphics.Color
import com.errorxperts.detoxo.overlay.bubble.BubbleFace
import com.errorxperts.detoxo.overlay.bubble.BubbleFrame
import com.errorxperts.detoxo.overlay.bubble.BubbleLook
import com.errorxperts.detoxo.overlay.bubble.BubbleModel
import com.errorxperts.detoxo.overlay.bubble.BubblePaints
import com.errorxperts.detoxo.overlay.bubble.BubblePaths
import com.errorxperts.detoxo.overlay.bubble.BubbleTokens
import com.errorxperts.detoxo.widget.withAlpha

/** Hourglass: sand moves from the top bulb to the bottom with `pct`; the grain falls while open. */
internal object HourglassFace : BubbleFace {
    override val countSize = 20f
    override val timerPaddingLeft = 70f
    override fun loops(open: Boolean) = open
    override val loopPeriodMs = BubbleTokens.MS_SAND

    /** A soft white glow behind the count, blur radius 8 board units. */
    override val countGlow = 8f
    override fun glowColor(l: BubbleLook): Int? = withAlpha(Color.WHITE, 0x99)

    /** The timer mark's grain falls while the timer is open. */
    override val timerGrain = true

    override fun drawDial(c: Canvas, f: BubbleFrame, p: BubblePaints) {
        c.save()
        c.translate(f.x(0f), f.y(0f))
        c.scale(f.s, f.s)
        // The glass at group alpha .55: applied per element (a layer per frame is too heavy).
        val glass = p.svg(BubblePaths.HOURGLASS_BIG)
        c.drawPath(glass, p.solid(fade(Color.WHITE, .35f * .55f)))
        c.drawPath(glass, p.pen(fade(f.look.ink, .55f), 2f))

        val sand = fade(f.look.ink, .5f)
        c.save()
        c.clipPath(p.svg(BubblePaths.CLIP_TOP))
        c.drawRect(23f, BubbleModel.sandTop(f.pct), 45f, BubbleModel.sandTop(f.pct) + 20f, p.solid(sand))
        c.restore()
        c.save()
        c.clipPath(p.svg(BubblePaths.CLIP_BOTTOM))
        c.drawRect(23f, BubbleModel.sandBottom(f.pct), 45f, BubbleModel.sandBottom(f.pct) + 22f, p.solid(sand))
        c.restore()
        c.restore()
    }
}
