package com.errorxperts.detoxo.overlay.bubble

import kotlin.math.roundToInt

/**
 * Pure window geometry for the reel bubble (no Android classes, JVM-testable).
 *
 * The host persists an *anchor*: the top-left, in px, of the collapsed `size x size` body. The
 * overlay window is larger than the body: it adds transparent *outsets* for the glow, pulse ring
 * and time pill. The window rect is derived from anchor + state, so the body
 * never moves on screen when the envelope changes. A capsule grows inward from the docked edge.
 */

/** Transparent room around the body, px. */
internal data class Outsets(val left: Float, val top: Float, val right: Float, val bottom: Float) {
    operator fun plus(o: Outsets) = Outsets(left + o.left, top + o.top, right + o.right, bottom + o.bottom)

    companion object {
        fun all(v: Float) = Outsets(v, v, v, v)
    }
}

/** Current body size, px, and which extras are showing. */
internal data class EnvelopeState(
    val bodyW: Float,
    val bodyH: Float,
    val pulsing: Boolean,
    val pill: Boolean,
)

/** Window rect in screen px; [bodyLeft]/[bodyTop] = body offset inside the view, px. */
internal data class WindowBox(
    val x: Int,
    val y: Int,
    val w: Int,
    val h: Int,
    val bodyLeft: Float,
    val bodyTop: Float,
)

internal object BubbleEnvelope {
    /** The pill's spring overshoot above its resting spot, dp. */
    private const val PILL_OVERSHOOT = 6f

    /** Total outsets in px: dp constants scaled by [density]. */
    fun outsets(s: EnvelopeState, density: Float): Outsets {
        var o = Outsets.all(BubbleTokens.GLOW * density)
        if (s.pulsing) o += Outsets.all(BubbleTokens.PULSE_HALO * density)
        if (s.pill) {
            val zone = (BubbleTokens.PILL_GAP + BubbleTokens.PILL_H + PILL_OVERSHOOT) * density
            o += Outsets(0f, zone, 0f, 0f)
        }
        return o
    }

    fun window(
        anchorX: Int,
        anchorY: Int,
        sizePx: Float,
        dockedRight: Boolean,
        s: EnvelopeState,
        density: Float,
    ): WindowBox {
        val bodyLeftPx = if (dockedRight) anchorX + sizePx - s.bodyW else anchorX.toFloat()
        val o = outsets(s, density)
        return WindowBox(
            x = (bodyLeftPx - o.left).roundToInt(),
            y = (anchorY - o.top).roundToInt(),
            w = (s.bodyW + o.left + o.right).roundToInt(),
            h = (s.bodyH + o.top + o.bottom).roundToInt(),
            bodyLeft = o.left,
            bodyTop = o.top,
        )
    }

    /** Docked right when the anchor's body centre is in the right half. */
    fun dockedRight(anchorX: Int, sizePx: Float, screenW: Int): Boolean =
        anchorX + sizePx / 2f >= screenW / 2f

    fun snapX(sizePx: Float, screenW: Int, edgePx: Float, dockedRight: Boolean): Int =
        if (dockedRight) (screenW - sizePx - edgePx).roundToInt() else edgePx.roundToInt()

    fun clampAnchor(x: Int, y: Int, sizePx: Float, screenW: Int, screenH: Int, edgePx: Float): Pair<Int, Int> {
        val minX = edgePx.roundToInt()
        val maxX = (screenW - sizePx - edgePx).roundToInt()
        val minY = (screenH * BubbleTokens.MIN_Y_PCT / 100f).roundToInt()
        val maxY = (screenH * BubbleTokens.MAX_Y_PCT / 100f - sizePx).roundToInt()
        // min wins on a degenerate screen (coerceIn would throw when min > max)
        return x.coerceAtMost(maxX).coerceAtLeast(minX) to y.coerceAtMost(maxY).coerceAtLeast(minY)
    }
}
