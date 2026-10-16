package com.errorxperts.detoxo.widget

import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * The app theme's primary carried onto the counter's surfaces: the bubble's glass and the
 * widgets' empty tile at 0 reels ([at], a fixed lightness per role), and the usage ramp at every
 * tier ([ramp], a fixed brightness per tier). Either way only the brand's hue (and its
 * saturation, capped) is kept, so every role keeps its contrast whichever theme is picked. ARGB
 * ints.
 *
 * MIRROR CONTRACT: Dart `content_counter_core/domain/brand_tint.dart` computes the same ints;
 * both are pinned by `test/fixtures/brand_tints.json`.
 */
internal object BrandTint {
    /** Until the app first pushes its theme: the original glass navy. */
    const val FALLBACK: Int = 0xFF1C3D78.toInt()

    const val MAX_SATURATION = 0.75

    // Lightness per role, 0..1.
    const val GLASS_TO = 0.945
    const val GLASS_RING = 0.83
    const val GLASS_INK = 0.29
    const val GLASS_HALO = 0.676
    const val GLASS_SHADOW = 0.49
    const val TILE_LIGHT = 0.94
    const val COUNT_LIGHT = 0.34

    // The usage ramp: a target brightness per tier for [ramp], pale → deep.

    /** The light tile's 135° gradient (and the bubble's body), tiers 1..5 at index 0..4. Tiers 1–3 take dark ink, 4–5 white. */
    val TILE_FROM = doubleArrayOf(0.82, 0.66, 0.53, 0.17, 0.09)
    val TILE_TO = doubleArrayOf(0.71, 0.54, 0.42, 0.11, 0.045)

    /** The dark theme's accent (count, fill, glow), tiers 0..5: its brightness and saturation cap, calm → vivid. */
    val ACCENT_DARK_Y = doubleArrayOf(0.50, 0.52, 0.47, 0.43, 0.40, 0.37)
    val ACCENT_DARK_S = doubleArrayOf(0.18, 0.36, 0.50, 0.62, 0.72, 0.80)

    /** Bento's status dot and Bonsai's health bar on a light module, tiers 0..5 (dark uses the accent). */
    val DOT_LIGHT = doubleArrayOf(0.40, 0.28, 0.22, 0.17, 0.12, 0.07)

    /** Bisection steps in [ramp]: the lightness lands within 2⁻²⁴. */
    private const val STEPS = 24

    /** [brand]'s hue at [lightness], opaque. */
    fun at(brand: Int, lightness: Double): Int {
        val (h, s) = hueSat(brand)
        return pack(h, min(s, MAX_SATURATION), lightness)
    }

    /**
     * [brand]'s hue, its saturation capped at [saturation], at the lightness whose brightness
     * (0..1, `.2126 r² + .7152 g² + .0722 b²`, a squared gamma: plain arithmetic, so Dart lands
     * on the same ints) reaches [brightness].
     */
    fun ramp(brand: Int, brightness: Double, saturation: Double = MAX_SATURATION): Int {
        val (h, s0) = hueSat(brand)
        val s = min(s0, saturation)
        var lo = 0.0
        var hi = 1.0
        repeat(STEPS) {
            val mid = (lo + hi) / 2
            val c = rgb(h, s, mid)
            if (0.2126 * c[0] * c[0] + 0.7152 * c[1] * c[1] + 0.0722 * c[2] * c[2] < brightness) lo = mid else hi = mid
        }
        return pack(h, s, (lo + hi) / 2)
    }

    /** [brand]'s HSL hue and saturation, 0..1. */
    private fun hueSat(brand: Int): Pair<Double, Double> {
        val r = (brand shr 16 and 0xFF) / 255.0
        val g = (brand shr 8 and 0xFF) / 255.0
        val b = (brand and 0xFF) / 255.0
        val hi = max(r, max(g, b))
        val lo = min(r, min(g, b))
        val d = hi - lo
        var h = 0.0
        var s = 0.0
        if (d > 0) {
            s = if ((hi + lo) / 2 > 0.5) d / (2 - hi - lo) else d / (hi + lo)
            h = when (hi) {
                r -> (g - b) / d + (if (g < b) 6 else 0)
                g -> (b - r) / d + 2
                else -> (r - g) / d + 4
            }
            h /= 6
        }
        return h to s
    }

    /** HSL → RGB channels, 0..1, unrounded. */
    private fun rgb(h: Double, s: Double, l: Double): DoubleArray {
        val q = if (l < 0.5) l * (1 + s) else l + s - l * s
        val p = 2 * l - q
        fun channel(t: Double): Double {
            val u = if (t < 0) t + 1 else if (t > 1) t - 1 else t
            return when {
                u < 1.0 / 6 -> p + (q - p) * 6 * u
                u < 1.0 / 2 -> q
                u < 2.0 / 3 -> p + (q - p) * (2.0 / 3 - u) * 6
                else -> p
            }
        }
        return doubleArrayOf(channel(h + 1.0 / 3), channel(h), channel(h - 1.0 / 3))
    }

    private fun pack(h: Double, s: Double, l: Double): Int {
        val c = rgb(h, s, l)
        return (0xFF shl 24) or ((c[0] * 255).roundToInt() shl 16) or ((c[1] * 255).roundToInt() shl 8) or
            (c[2] * 255).roundToInt()
    }
}
