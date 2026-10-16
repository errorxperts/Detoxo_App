package com.errorxperts.detoxo.overlay.bubble

import kotlin.math.roundToInt

/** A collapsed-body anchor (top-left, px) and the edge it docks to. */
internal data class Anchor(val x: Int, val y: Int, val dockedRight: Boolean)

/**
 * The pure curves and anchor rules behind `BubbleView` / `ContentCounterBubble` (JVM-tested;
 * the view and the host stay thin). Twins of the Dart `BubblePainter` curves.
 */
internal object BubbleGeometry {
    /** The count pop (BR-07): 1 → 1.18 by 40 % of [pop], back to 1 at the end. */
    fun popScale(pop: Float): Float =
        1f + 0.18f * (if (pop < 0.4f) pop / 0.4f else 1f - (pop - 0.4f) / 0.6f)

    /** The timer content's fade-in over the last 70 % of [expand]. */
    fun timerAlpha(expand: Float): Float = ((expand - 0.3f) / 0.7f).coerceIn(0f, 1f)

    /**
     * The open timer's next 1 Hz value from the [shown] seconds and the store's [watch]: one
     * second up, never behind the store, at most [gap] ahead of it (the store accrues only
     * between events < 12 s apart, so quiet playback stalls it); a store drop past that lead
     * (midnight) is followed at once.
     */
    fun nextShownSeconds(shown: Int, watch: Int, gap: Int = 12): Int =
        if (watch < shown - gap) watch else minOf(maxOf(shown + 1, watch), watch + gap)

    /**
     * A released or restored anchor: Y clamped to 20–70 % ([BubbleEnvelope.clampAnchor]), the
     * side picked by the body centre, X snapped [edgePx] from that side's edge.
     */
    fun snap(x: Int, y: Int, sizePx: Float, screenW: Int, screenH: Int, edgePx: Float): Anchor {
        val (cx, cy) = BubbleEnvelope.clampAnchor(x, y, sizePx, screenW, screenH, edgePx)
        val right = BubbleEnvelope.dockedRight(cx, sizePx, screenW)
        return Anchor(BubbleEnvelope.snapX(sizePx, screenW, edgePx, right), cy, right)
    }

    /**
     * The anchor to show at: the stored `cc_bubble_x/y` (an unset `-1` → the right dock at 30 %
     * height), [snap]ped — so a size or edge change (Drop clings at 0) re-docks without animation.
     */
    fun restoreAnchor(storedX: Int, storedY: Int, sizePx: Float, screenW: Int, screenH: Int, edgePx: Float): Anchor =
        snap(
            if (storedX < 0) screenW else storedX,
            if (storedY < 0) (screenH * 0.3f).roundToInt() else storedY,
            sizePx, screenW, screenH, edgePx,
        )
}
