package com.errorxperts.detoxo.overlay

import com.errorxperts.detoxo.widget.blend

/**
 * The wall's flat ground and its two text colours; the Dart `wallPaletteFor`
 * mirrors it for the in-app preview. The accent itself is not here: it is the
 * app theme's primary (`ContentCounterStore.brand`).
 */
internal data class Palette(
    val ground: Int,
    val ink: Int,
    val muted: Int,
)

/**
 * The canvas boards' grounds. Face Down (light) is the board's `#ECEFF4` with
 * ink at 15.9:1 and muted at 5.4:1. Spotlight (dark) carries a breath of
 * [accent], as the board's mint-black `#0B1510` does, and keeps ink ≥ 17:1 and
 * muted ≥ 7.8:1 for every theme primary. Pure; pinned by the JVM test.
 */
internal fun wallPalette(dark: Boolean, accent: Int): Palette = if (dark) {
    Palette(
        ground = blend(accent, 0xFF07090E.toInt(), 0.07f),
        ink = blend(accent, 0xFFFFFFFF.toInt(), 0.06f),
        muted = blend(accent, 0xFFAEB6C6.toInt(), 0.14f),
    )
} else {
    Palette(
        ground = 0xFFECEFF4.toInt(),
        ink = 0xFF12151B.toInt(),
        muted = 0xFF5A6170.toInt(),
    )
}
