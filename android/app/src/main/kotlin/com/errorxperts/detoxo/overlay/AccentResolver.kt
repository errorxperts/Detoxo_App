package com.errorxperts.detoxo.overlay

import android.content.Context
import com.errorxperts.detoxo.engine.ContentCounterStore
import com.errorxperts.detoxo.engine.DateKeys
import com.errorxperts.detoxo.engine.RuleEngine
import com.errorxperts.detoxo.widget.PlanState
import com.errorxperts.detoxo.widget.ReelWidgetSync
import kotlin.math.floor

/**
 * The live accent, mirroring Dart's `resolveAccent` (lib/core/design_system/foundations/accent.dart)
 * operation for operation, so the block screen paints the colour the app shows. Pinned by the shared
 * test/fixtures/accent_cases.json.
 *
 * All maths is Double: a channel is byte / 255.0, a blend is `a * (1 - t) + b * t`, and only the final
 * channel rounds (half up). Not `widget/ColorMath.blend`, which works in Float and rounds every step.
 *
 * The block screen takes its accent from [forWall], from the same inputs the
 * Today screen reads.
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
     * The mode the Today screen lights for [plan] at [nowMs], row for row with
     * Dart `accentModeOf` (pinned by the fixture's `modes` rows): none while
     * blocking is off; a live Pause; the base mode; One Reel, or Pause for an
     * N-reel unblock (a break too). An unknown token is none (brand).
     */
    fun modeOf(plan: PlanState, nowMs: Long): Mode = when {
        !plan.blockingOn -> Mode.NONE
        plan.pauseUntil > nowMs -> Mode.PAUSE
        else -> when (plan.plan) {
            "BLOCK_ALL" -> Mode.BLOCK_ALL
            "CURIOUS" -> Mode.CONSCIOUS
            "ONE_REEL" -> if (plan.reelAllowance <= 1) Mode.ONE_REEL else Mode.PAUSE
            "PAUSED" -> Mode.PAUSE
            else -> Mode.NONE
        }
    }

    /**
     * Today's share of the daily limit, as the Today ring reads it: 0 while
     * counting is off or there is no limit, else whole seconds over whole
     * seconds (Dart's `inSeconds` division).
     */
    fun usedFraction(enabled: Boolean, timeTodayMs: Long, limitMs: Long): Double =
        if (!enabled || limitMs / 1000L <= 0L) 0.0 else (timeTodayMs / 1000L).toDouble() / (limitMs / 1000L)

    /**
     * The wall's accent (main, light, deep ARGB) in the [dark] or light theme,
     * read once per build from a bare Context, so a preview works with the
     * service dead: the engine's own plan ([ReelWidgetSync.plan]), today's reel
     * time and the daily reel limit (`RuleEngine.DAILY_REEL_LIMIT_ID` in the
     * rules mirror — not `soonestReelLimitMs`, which counts rule windows too).
     * Never `payload.plan`: `sanitised()` blanks it for every non-plan block.
     */
    fun forWall(context: Context, dark: Boolean, nowMs: Long = System.currentTimeMillis()): IntArray {
        val plan = ReelWidgetSync.plan(context)
        val store = ContentCounterStore(context.applicationContext)
        val limitMs = store.reelLimits().firstOrNull { it.id == RuleEngine.DAILY_REEL_LIMIT_ID }?.reelTimeLimitMs ?: 0L
        val used = usedFraction(store.enabled, store.timeTodayMs(DateKeys.today(nowMs)), limitMs)
        val pauseLeft = if (plan.pauseUntil > nowMs) plan.pauseUntil - nowMs else null
        return resolve(dark, modeOf(plan, nowMs), used, pauseLeft)
    }

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
