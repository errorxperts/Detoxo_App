package com.errorxperts.detoxo.widget

import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

/**
 * The IM-02 home-widget payload: what the one writer (`ReelWidgetSync`) stores
 * in `detoxo_engine_prefs` → `widget_payload` and every face and in-app preview
 * reads. The JSON keys are the contract with the Dart `WidgetPayload`, and
 * `test/fixtures/home_widget_payloads.json` pins [parse] for both languages.
 *
 * Android-free apart from org.json, so the JVM tests run it.
 */
data class WidgetPayload(
    val reelCount: Int,
    val watchSeconds: Int,
    /** DS-01 tier 0..5, computed once by the writer ([tierOf]); readers never recompute it (IM-01). */
    val reelTier: Int,
    /** Watch seconds per local hour (index 0..23), each 0..3600. */
    val hourlySeconds: List<Int>,
    /** The soonest active reel limit today, 0..1440 once parsed; 0 = no limit. */
    val limitMinutes: Int,
    /** `system` | `light` | `dark`. */
    val theme: String,
    /** The OS "remove animations" setting; stills the in-app preview. */
    val reduceMotion: Boolean,
    /** When the data was built, epoch ms; 0 = never. */
    val updatedAt: Long,
    /** The counter is on AND the accessibility service is enabled. */
    val trackingEnabled: Boolean,
) {
    /** The palette to draw: the forced theme, else the device's [systemDark] (IM-07). */
    fun isDark(systemDark: Boolean): Boolean = when (theme) {
        "dark" -> true
        "light" -> false
        else -> systemDark
    }

    /** Exactly the nine IM-02 keys. */
    fun toJson(): String = JSONObject()
        .put("reel_count", reelCount)
        .put("watch_seconds", watchSeconds)
        .put("reel_tier", reelTier)
        .put("hourly_seconds", JSONArray(hourlySeconds))
        .put("limit_minutes", limitMinutes)
        .put("theme", theme)
        .put("reduce_motion", reduceMotion)
        .put("updated_at", updatedAt)
        .put("tracking_enabled", trackingEnabled)
        .toString()

    companion object {
        const val MAX_TIER = WidgetTokens.MAX_TIER
        private const val HOURS = 24
        private const val HOUR_SECONDS = 3600L

        /** Missing or corrupt data renders as this (IM-09): no reels, no limit, tracking on. */
        val EMPTY = WidgetPayload(
            reelCount = 0,
            watchSeconds = 0,
            reelTier = 0,
            hourlySeconds = List(HOURS) { 0 },
            limitMinutes = 0,
            theme = "system",
            reduceMotion = false,
            updatedAt = 0L,
            trackingEnabled = true,
        )

        /** The board's 152-reel day: fixture case `tier2_152`'s hours. */
        private val DEMO_HOURLY = listOf(
            177, 59, 0, 0, 0, 0, 0, 59, 118, 59, 0, 59,
            296, 118, 59, 0, 59, 118, 118, 177, 355, 355, 650, 1419,
        )

        /**
         * Lenient per key, strict per type: input that is not a JSON object is
         * [EMPTY], and a key that is missing or of the wrong type (`"12"` is not
         * a number, `1` is not a bool — hence no coercing `optLong` /
         * `optBoolean`) takes its [EMPTY] value. Numbers truncate toward zero and
         * floor at 0; the tier clamps to 0..[MAX_TIER] and the limit to a day
         * (`WidgetTokens.MAX_LIMIT_MINUTES`); `hourly_seconds` must be exactly
         * 24 numbers, each clamped to an hour.
         */
        fun parse(raw: String?): WidgetPayload {
            val o = try {
                JSONObject(raw ?: return EMPTY)
            } catch (_: JSONException) {
                return EMPTY
            }
            return WidgetPayload(
                reelCount = whole(o.opt("reel_count")).toInt(),
                watchSeconds = whole(o.opt("watch_seconds")).toInt(),
                reelTier = whole(o.opt("reel_tier"), MAX_TIER.toLong()).toInt(),
                hourlySeconds = hours(o.opt("hourly_seconds")),
                limitMinutes = whole(o.opt("limit_minutes"), WidgetTokens.MAX_LIMIT_MINUTES.toLong()).toInt(),
                theme = (o.opt("theme") as? String)?.lowercase()
                    ?.takeIf { it == "light" || it == "dark" } ?: "system",
                reduceMotion = o.opt("reduce_motion") as? Boolean ?: false,
                updatedAt = whole(o.opt("updated_at"), Long.MAX_VALUE),
                trackingEnabled = o.opt("tracking_enabled") as? Boolean ?: true,
            )
        }

        /**
         * The board's demo day (152 reels, tier 2) dated [nowMs]. Picker and pin
         * previews pass `demo(120, "system", true, now)`; the in-app demo passes
         * the real limit, theme and reduce-motion setting.
         */
        fun demo(limitMinutes: Int, theme: String, reduceMotion: Boolean, nowMs: Long) = WidgetPayload(
            reelCount = 152,
            watchSeconds = 4256,
            reelTier = tierOf(152),
            hourlySeconds = DEMO_HOURLY,
            limitMinutes = limitMinutes,
            theme = theme,
            reduceMotion = reduceMotion,
            updatedAt = nowMs,
            trackingEnabled = true,
        )

        /** DS-01: 0 for no reels, then one tier per 100 reels, capped at [MAX_TIER]. */
        fun tierOf(count: Int): Int =
            if (count <= 0) 0 else minOf(MAX_TIER, count / WidgetTokens.TIER_STEP + 1)

        /**
         * IM-03's budget: push when a count crosses a multiple of 10 or changes
         * the tier (the 0 → 1 first reel), not on every reel. The widget can lag
         * the bubble by up to 9 reels; the rule accepts that.
         */
        fun shouldPushOnCount(prev: Int, next: Int): Boolean =
            prev.floorDiv(WidgetTokens.PUSH_EVERY_REELS) != next.floorDiv(WidgetTokens.PUSH_EVERY_REELS) ||
                tierOf(prev) != tierOf(next)

        /**
         * Everything a face can show of [payload] at [nowMs]: the day, the
         * real count (TalkBack reads it uncapped), the tier, the time strings,
         * the segments, the limit, the hourly minutes and peak, the resolved
         * palette, tracking, the stale note and the 12/24 h clock. Equal keys
         * draw the same frame (bars to the minute), so the writer skips the
         * render (IM-03). [updatedZoneOffsetMin] is the UTC offset at
         * `updated_at`, as [WidgetModel] takes it. With [plan], the Plan
         * face's strings too (EVO-073).
         *
         * The derived strings stand in for whole watch minutes: the time left
         * (`limit − watch`) rounds the other way and the segments step on
         * their own seconds, so minutes alone would leave either one stale.
         */
        fun visibleKey(
            payload: WidgetPayload,
            nowMs: Long,
            zoneOffsetMin: Int,
            use24h: Boolean,
            systemDark: Boolean,
            updatedZoneOffsetMin: Int = zoneOffsetMin,
            plan: PlanState = PlanState.DEMO,
        ): String {
            val m = WidgetModel(payload, nowMs, zoneOffsetMin, use24h, updatedZoneOffsetMin, plan)
            return listOf(
                WidgetModel.localDay(nowMs, zoneOffsetMin), m.count, m.tier, m.time, m.leftBig,
                m.segmentsOn, payload.limitMinutes, m.hourlySeconds.joinToString(",") { "${it / 60}" },
                m.peakHour, payload.isDark(systemDark), payload.trackingEnabled, m.stale, m.note, use24h,
                m.planKey,
            ).joinToString("|")
        }

        /** A JSON number truncated toward zero, clamped to 0..[max]; any other value is 0. */
        private fun whole(v: Any?, max: Long = Int.MAX_VALUE.toLong()): Long =
            if (v is Number) v.toDouble().toLong().coerceIn(0L, max) else 0L

        private fun hours(v: Any?): List<Int> {
            if (v !is JSONArray || v.length() != HOURS) return EMPTY.hourlySeconds
            val out = ArrayList<Int>(HOURS)
            for (i in 0 until HOURS) {
                val bucket = v.opt(i) as? Number ?: return EMPTY.hourlySeconds
                out.add(whole(bucket, HOUR_SECONDS).toInt())
            }
            return out
        }
    }
}
