package com.errorxperts.detoxo.overlay.bubble

import com.errorxperts.detoxo.widget.BrandTint
import com.errorxperts.detoxo.widget.WidgetTokens
import com.errorxperts.detoxo.widget.blendArgb
import com.errorxperts.detoxo.widget.withAlpha

/**
 * The shell colours for one tier (BR-04 / BR-05), as ARGB ints: the 160° body fill
 * [fillFrom] → [fillTo], the [ring] / outline / glow colour, the count [ink], the [faint]
 * track and [mark] tick colours (light or dark by tier), and the [halo] / [shadow] around
 * the body. Every tier is in the app theme's hue: tier 0 the glass look ([BrandTint.at]), 1–5
 * the usage ramp the widgets' tiles share ([BrandTint.ramp]). Twin of the Dart `BubbleLook`.
 */
internal class BubbleLook(
    val fillFrom: Int,
    val fillTo: Int,
    val ring: Int,
    val ink: Int,
    val faint: Int,
    val mark: Int,
    val halo: Int,
    val shadow: Int,
) {
    companion object {
        /** The six looks of the last brand asked for (the theme rarely changes). */
        private var cache: Pair<Int, Array<BubbleLook>>? = null

        /**
         * The look for [tier], clamped to 0..5, in [brand]'s hue (the app theme's primary); all
         * six are built once per brand. Main thread only.
         */
        fun of(tier: Int, brand: Int = BrandTint.FALLBACK): BubbleLook {
            val looks = cache?.takeIf { it.first == brand }?.second
                ?: Array(6) { if (it == 0) glassOf(brand) else tierOf(it, brand) }.also { cache = brand to it }
            return looks[tier.coerceIn(0, 5)]
        }

        private fun glassOf(brand: Int): BubbleLook {
            fun tint(l: Double, alpha: Int = 0xFF) = withAlpha(BrandTint.at(brand, l), alpha)
            return BubbleLook(
                fillFrom = BubbleTokens.GLASS_FROM,
                fillTo = tint(BrandTint.GLASS_TO),
                ring = tint(BrandTint.GLASS_RING),
                ink = tint(BrandTint.GLASS_INK),
                faint = BubbleTokens.FAINT_LIGHT,
                mark = BubbleTokens.MARK_LIGHT,
                halo = tint(BrandTint.GLASS_HALO, 0x29),
                shadow = tint(BrandTint.GLASS_SHADOW, 0x61),
            )
        }

        /** Per-field ARGB blend: [t] 0 → [a], 1 → [b] (the 700 ms tier cross-fade). */
        fun blend(a: BubbleLook, b: BubbleLook, t: Float): BubbleLook {
            fun m(x: Int, y: Int) = blendArgb(y, x, t)
            return BubbleLook(
                m(a.fillFrom, b.fillFrom), m(a.fillTo, b.fillTo), m(a.ring, b.ring), m(a.ink, b.ink),
                m(a.faint, b.faint), m(a.mark, b.mark),
                m(a.halo, b.halo), m(a.shadow, b.shadow),
            )
        }

        /** Usage tier [n] (1..5) in [brand]'s ramp. */
        private fun tierOf(n: Int, brand: Int): BubbleLook {
            val to = BrandTint.ramp(brand, BrandTint.TILE_TO[n - 1])
            return BubbleLook(
                fillFrom = BrandTint.ramp(brand, BrandTint.TILE_FROM[n - 1]),
                fillTo = to,
                ring = to,
                ink = if (n <= 3) WidgetTokens.WIDGET_INK else WidgetTokens.WIDGET_INK_INVERSE,
                faint = if (n >= 4) BubbleTokens.FAINT_DARK else BubbleTokens.FAINT_LIGHT,
                mark = if (n >= 4) BubbleTokens.MARK_DARK else BubbleTokens.MARK_LIGHT,
                halo = withAlpha(to, 0x2E),
                shadow = withAlpha(to, 0x73),
            )
        }
    }
}
