package com.errorxperts.detoxo.widget

import kotlin.math.roundToInt

// ARGB helpers shared by the widget faces and the block screen. Hand-written,
// beside the generated WidgetTokens.kt, which must hold no code.

/** Linear RGB blend of [a] over [b] by [t] (0 = b, 1 = a); result is opaque. */
internal fun blend(a: Int, b: Int, t: Float): Int {
    fun ch(shift: Int): Int =
        (((a ushr shift) and 0xFF) * t + ((b ushr shift) and 0xFF) * (1f - t))
            .roundToInt().coerceIn(0, 255)
    return (0xFF shl 24) or (ch(16) shl 16) or (ch(8) shl 8) or ch(0)
}

internal fun withAlpha(color: Int, alpha: Int): Int = (alpha shl 24) or (color and 0x00FFFFFF)

/** Like [blend], but the alpha channel blends too; [a] over [b] by [t]. */
internal fun blendArgb(a: Int, b: Int, t: Float): Int {
    fun ch(shift: Int): Int =
        (((a ushr shift) and 0xFF) * t + ((b ushr shift) and 0xFF) * (1f - t))
            .roundToInt().coerceIn(0, 255)
    return (ch(24) shl 24) or (ch(16) shl 16) or (ch(8) shl 8) or ch(0)
}
