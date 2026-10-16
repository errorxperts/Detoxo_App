package com.errorxperts.detoxo.overlay.bubble

import android.graphics.Canvas
import com.errorxperts.detoxo.overlay.bubble.faces.BezelFace
import com.errorxperts.detoxo.overlay.bubble.faces.DropFace
import com.errorxperts.detoxo.overlay.bubble.faces.HourglassFace
import com.errorxperts.detoxo.overlay.bubble.faces.LiquidFace
import com.errorxperts.detoxo.overlay.bubble.faces.MascotFace
import com.errorxperts.detoxo.overlay.bubble.faces.RingFace

/**
 * One bubble style: the scalars and colours it changes on the shared shell, plus its one
 * ability drawn in [drawBackground] / [drawDial] / [drawOverlay] (spec §6.2 order). Sizes are
 * board units at size 68 unless noted. Twin of the Dart `BubbleFace`.
 */
internal interface BubbleFace {
    /** Count text size, board units. */
    val countSize: Float get() = 24f

    /** Timer content's left padding inside the open capsule, board units. */
    val timerPaddingLeft: Float get() = 15f

    /** Gap to the screen edge when docked, dp (Drop: 0, it clings). */
    val edgeDp: Float get() = 12f

    /** Whether the shell draws the count (false: the face draws its own, e.g. Mascot's chip). */
    val shellCount: Boolean get() = true

    /**
     * Text glow: the board's CSS blur **radius**, board units (0 = none). The view applies it to
     * the count, the timer clock and the One Reel remaining number, passing `countGlow · s` to
     * `BubblePaints.text` as the native blur radius.
     */
    val countGlow: Float get() = 0f

    /** The text glow's colour; null = the text's own colour. */
    fun glowColor(l: BubbleLook): Int? = null

    /** Whether the timer mark shows the falling grain; the view draws it only while also open. */
    val timerGrain: Boolean get() = false

    /** The docked-edge corner radius, board units; used by both the shell and the pulse ring. */
    val radiusEdge: Float get() = 34f

    /** Whether the face runs the ~30 fps loop in this state ([open] = timer open). */
    fun loops(open: Boolean): Boolean = false

    /** One loop's length, ms ([BubbleFrame.loopT] goes 0 → 1 over it); 0 = no loop. */
    val loopPeriodMs: Int get() = 0

    /** The whole-bubble scale at loop phase [loopT], about the docked edge's centre; 1 = none (only Drop breathes). */
    fun breathScale(loopT: Float): Float = 1f

    /** Count ink. Takes the frame: Liquid's ink depends on tier and pct. */
    fun countColor(f: BubbleFrame): Int = f.look.ink

    /** The timer mark's fill; null = outline only. */
    fun markFill(l: BubbleLook): Int? = l.mark

    fun drawBackground(c: Canvas, f: BubbleFrame, p: BubblePaints) = p.shell(c, f, radiusEdge = radiusEdge)

    fun drawDial(c: Canvas, f: BubbleFrame, p: BubblePaints) {}

    fun drawOverlay(c: Canvas, f: BubbleFrame, p: BubblePaints) {}

    companion object {
        /**
         * The face for a [BubbleStyleSpec] variant token. One branch per token in
         * [BubbleStyleSpec.ALL]; a string `when` cannot be compiler-exhaustive, so
         * `BubbleLookTest.faceOfCoversEveryStyle` pins that each token maps to its own face.
         */
        fun of(variant: String): BubbleFace = when (variant) {
            BubbleStyleSpec.MASCOT -> MascotFace
            BubbleStyleSpec.RING -> RingFace
            BubbleStyleSpec.LIQUID -> LiquidFace
            BubbleStyleSpec.HOURGLASS -> HourglassFace
            BubbleStyleSpec.BEZEL -> BezelFace
            BubbleStyleSpec.DROP -> DropFace
            else -> MascotFace
        }
    }
}
