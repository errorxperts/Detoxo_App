package com.errorxperts.detoxo.overlay.bubble

import org.json.JSONObject

/**
 * The reel-counter bubble style, parsed from the three-key JSON the Dart
 * `BubbleStyle` persists (`{"variant": <token>, "size": <dp>, "opacity": <0..1>}`).
 * It mirrors the Dart `BubbleStyle` wire: the same tokens, keys and clamp
 * ranges. [ALL] is the source of truth for variant validation.
 */
internal data class BubbleStyleSpec(
    val variant: String = RING,
    val sizeDp: Float = 48f,
    val opacity: Float = 1f,
) {
    companion object {
        const val MASCOT = "MASCOT"
        const val RING = "RING"
        const val LIQUID = "LIQUID"
        const val HOURGLASS = "HOURGLASS"
        const val BEZEL = "BEZEL"
        const val DROP = "DROP"

        val ALL: List<String> = listOf(MASCOT, RING, LIQUID, HOURGLASS, BEZEL, DROP)

        /**
         * Parses the persisted style. Null, empty, or malformed input yields
         * the defaults (the Ring at the smallest 48 dp); an unknown variant
         * (including the retired NEON, STEPS, WEATHER and OUTLINE) becomes
         * [RING]; a wrong-typed
         * field falls back to its default; size and opacity are clamped.
         */
        fun fromJson(json: String?): BubbleStyleSpec = try {
            if (json.isNullOrEmpty()) {
                BubbleStyleSpec()
            } else {
                val obj = JSONObject(json)
                BubbleStyleSpec(
                    variant = obj.optString("variant", RING).takeIf { it in ALL } ?: RING,
                    sizeDp = obj.optDouble("size", 48.0).takeUnless { it.isNaN() }
                        ?.toFloat()?.coerceIn(48f, 80f) ?: 48f,
                    opacity = obj.optDouble("opacity", 1.0).takeUnless { it.isNaN() }
                        ?.toFloat()?.coerceIn(0.5f, 1f) ?: 1f,
                )
            }
        } catch (t: Throwable) {
            BubbleStyleSpec()
        }
    }
}
