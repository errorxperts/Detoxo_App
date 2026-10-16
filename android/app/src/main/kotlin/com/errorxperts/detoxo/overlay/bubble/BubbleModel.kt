package com.errorxperts.detoxo.overlay.bubble

import com.errorxperts.detoxo.widget.WidgetPayload
import com.errorxperts.detoxo.widget.WidgetTokens
import java.util.Locale

/**
 * Colour-free text and numbers of the floating bubble.
 *
 * MIRROR CONTRACT: the Dart `BubbleModel` (`content_counter_bubble/domain/bubble_model.dart`)
 * computes the same values; both are pinned by `test/fixtures/bubble_cases.json`.
 * Change one, change the other and the fixture. Variants are the
 * [BubbleStyleSpec] wire tokens.
 */
internal object BubbleModel {
    private const val STEP = WidgetTokens.TIER_STEP
    private const val MAX = WidgetTokens.MAX_TIER

    private val MASCOT_LINES = listOf(
        "Glass · happy to see you",
        "Green · big smile",
        "Lime · surprised, that many already?",
        "Amber · worried",
        "Orange-red · upset",
        "Deep red · palm up: stop",
    )

    enum class TierChange { NONE, DOWN, UP }

    private fun nonNeg(v: Int) = if (v < 0) 0 else v

    /** `n reel` / `n reels`: singular only for exactly 1. */
    private fun reels(n: Int) = if (n == 1) "reel" else "reels"

    /** 0 for no reels, then one tier per hundred, capped at the final tier. */
    fun tier(count: Int): Int = WidgetPayload.tierOf(count)

    fun countText(count: Int): String {
        val n = nonNeg(count)
        if (n <= 999) return "$n"
        if (n >= 10000) return "${n / 1000}k"
        val tenths = n / 100
        return if (tenths % 10 == 0) "${tenths / 10}k" else "${tenths / 10}.${tenths % 10}k"
    }

    /** `21m`, `1h 12m`, `2h`. */
    fun shortTime(seconds: Int): String {
        val s = nonNeg(seconds)
        if (s < 3600) return "${s / 60}m"
        val m = s % 3600 / 60
        return if (m == 0) "${s / 3600}h" else "${s / 3600}h ${m}m"
    }

    /** `21:56`, `1:12:08`. */
    fun clock(seconds: Int): String {
        val s = nonNeg(seconds)
        // Locale.ROOT: ASCII digits whatever the device locale (ar / fa would localise them).
        val ms = String.format(Locale.ROOT, "%02d:%02d", s % 3600 / 60, s % 60)
        val h = s / 3600
        return if (h > 0) "$h:$ms" else ms
    }

    /** Progress to the next colour, 0..100 (100 once the final tier is hit). */
    fun pct(count: Int): Int {
        val n = nonNeg(count)
        if (n == 0) return 0
        return if (tier(n) == MAX) 100 else n % STEP
    }

    fun toNext(count: Int): Int {
        val n = nonNeg(count)
        return (n / STEP + 1) * STEP - n
    }

    fun nextLine(count: Int): String {
        val n = nonNeg(count)
        if (n == 0) return "First reel turns it green."
        if (tier(n) == MAX) return "Final colour reached."
        return "${toNext(n)} ${reels(toNext(n))} to the next colour."
    }

    fun isDial(variant: String): Boolean = variant in DIALS

    /** Width of the open timer pill in dp. */
    fun timerWidth(seconds: Int, variant: String): Float = when {
        variant in WIDE -> 176f
        nonNeg(seconds) >= 3600 -> 156f
        else -> 136f
    }

    /** Spoken label of the collapsed bubble. */
    fun collapsedLabel(count: Int, seconds: Int, variant: String): String {
        val tail = when {
            !isDial(variant) -> "${shortTime(seconds)} watched"
            tier(count) == MAX -> "final colour"
            else -> "${toNext(count)} to the next colour"
        }
        return "${countText(count)} ${reels(count)} today, $tail. Tap to show the timer."
    }

    fun openLabel(seconds: Int): String =
        "Watch time today ${clock(seconds)}. Tap to show the reel count."

    /** Spoken label of the collapsed One Reel "N left" badge. */
    fun remainingLabel(n: Int): String = "$n ${reels(n)} left. Tap to show the timer."

    fun bezelLit(count: Int): Int = if (tier(count) == MAX) 10 else pct(count) / 10

    fun sandTop(pct: Int): Float = 13f + pct * 0.20f

    fun sandBottom(pct: Int): Float = 53f - pct * 0.22f

    fun mascotLine(tier: Int): String = MASCOT_LINES[tier.coerceIn(0, MAX)]

    fun transition(oldTier: Int, newTier: Int): TierChange = when {
        newTier > oldTier -> TierChange.UP
        newTier < oldTier -> TierChange.DOWN
        else -> TierChange.NONE
    }

    private val DIALS = setOf(
        BubbleStyleSpec.RING, BubbleStyleSpec.LIQUID, BubbleStyleSpec.HOURGLASS,
        BubbleStyleSpec.BEZEL,
    )
    private val WIDE = setOf(BubbleStyleSpec.RING, BubbleStyleSpec.HOURGLASS, BubbleStyleSpec.BEZEL)
}
