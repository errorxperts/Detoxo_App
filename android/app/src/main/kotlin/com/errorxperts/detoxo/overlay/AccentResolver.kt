package com.errorxperts.detoxo.overlay

import kotlin.math.floor

/**
 * The live accent, mirroring Dart's `resolveAccent` (lib/core/design_system/foundations/accent.dart)
 * operation for operation, so the block screen paints the colour the app shows. Pinned by the shared
 * test/fixtures/accent_cases.json.
 *
 * All maths is Double: a channel is byte / 255.0, a blend is `a * (1 - t) + b * t`, and only the final
 * channel rounds (half up). Not `widget/ColorMath.blend`, which works in Float and rounds every step.
 *
 * Ready for the block-screen phase; nothing calls it yet.
 */
internal object AccentResolver {
    enum class Mode { NONE, BLOCK_ALL, CONSCIOUS, PAUSE, ONE_REEL }

    /** One palette as three RGB triples (main, light, deep), channels 0..1. */
    private class Pal(val stops: Array<DoubleArray>) {
        fun lerp(o: Pal, t: Double) = Pal(
            Array(3) { i -> DoubleArray(3) { c -> stops[i][c] * (1 - t) + o.stops[i][c] * t } },
        )

        fun argb() = IntArray(3) { i ->
            val s = stops[i]
            (0xFF shl 24) or (byte(s[0]) shl 16) or (byte(s[1]) shl 8) or byte(s[2])
        }

        private fun byte(v: Double) = floor(v * 255.0 + 0.5).toInt().coerceIn(0, 255)
    }

    private fun pal(argb: IntArray) = Pal(
        Array(3) { i ->
            val c = argb[i]
            doubleArrayOf(((c shr 16) and 0xFF) / 255.0, ((c shr 8) and 0xFF) / 255.0, (c and 0xFF) / 255.0)
        },
    )

    /**
     * The accent (main, light, deep ARGB) for [mode] in the [dark] or light theme, with [used] the
     * share of the daily limit spent and [pauseLeftMs] a live Pause's time left (null for an N-reel
     * unblock, which stays `pause`).
     */
    fun resolve(dark: Boolean, mode: Mode, used: Double, pauseLeftMs: Long?): IntArray {
        val brand = pal(if (dark) DxTokens.PALETTE_BRAND_DARK else DxTokens.PALETTE_BRAND_LIGHT)
        val pause = pal(if (dark) DxTokens.PALETTE_PAUSE_DARK else DxTokens.PALETTE_PAUSE_LIGHT)
        val over = pal(if (dark) DxTokens.PALETTE_OVER_DARK else DxTokens.PALETTE_OVER_LIGHT)
        val f = used.coerceIn(0.0, 1.0)
        val warm = if (f < 0.85) pause else pause.lerp(over, (f - 0.85) / 0.15)
        val out = when (mode) {
            Mode.NONE -> when {
                f < 0.6 -> brand
                f < 0.85 -> brand.lerp(pause, (f - 0.6) / 0.25)
                else -> warm
            }
            Mode.PAUSE ->
                if (pauseLeftMs == null) pause
                else pause.lerp(over, (1 - pauseLeftMs / 120000.0).coerceIn(0.0, 1.0))
            else -> {
                val p = pal(
                    when (mode) {
                        Mode.BLOCK_ALL -> if (dark) DxTokens.PALETTE_BLOCK_ALL_DARK else DxTokens.PALETTE_BLOCK_ALL_LIGHT
                        Mode.CONSCIOUS -> if (dark) DxTokens.PALETTE_CONSCIOUS_DARK else DxTokens.PALETTE_CONSCIOUS_LIGHT
                        else -> if (dark) DxTokens.PALETTE_ONE_REEL_DARK else DxTokens.PALETTE_ONE_REEL_LIGHT
                    },
                )
                if (f <= 0.6) p else p.lerp(warm, 0.8 * (f - 0.6) / 0.4)
            }
        }
        return out.argb()
    }
}
