package com.errorxperts.detoxo.widget

import com.errorxperts.detoxo.engine.ContentCounterStore
import com.errorxperts.detoxo.engine.RuleEngine
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Pins the writer's pure payload composition: [ReelWidgetSync.compose] and [ReelWidgetSync.limitMinutes]. */
class ReelWidgetSyncTest {

    private val now = 1_760_000_000_000L
    private val hours = List(24) { if (it == 21) 1_200 else 0 }

    // The global Daily Limit (always on) plus a tighter rule whose window is open now.
    private val limits = RuleEngine.parse(
        """[{"id":"${RuleEngine.DAILY_REEL_LIMIT_ID}","reason":"DAILY_LIMIT","platformIds":["*"],
            "always":true,"reelTimeLimitMs":7200000},
           {"id":"evening","reason":"DAILY_LIMIT","platformIds":["*"],
            "windows":[[${now - 1}, ${now + 1}]],"reelTimeLimitMs":1859999}]""",
    )!!

    private fun source(
        today: Int = 238,
        total: Int = 900,
        enabled: Boolean = true,
        reelLimits: List<RuleEngine.Entry> = limits,
        timeTodayMs: Long = 4_256_999L,
        hourlySeconds: List<Int> = hours,
    ) =
        ContentCounterStore.WidgetSource(
            today = today,
            timeTodayMs = timeTodayMs,
            hourlySeconds = hourlySeconds,
            reelLimits = reelLimits,
            theme = "dark",
            enabled = enabled,
            total = total,
        )

    @Test
    fun aLiveDayCarriesTheStoreWithTheTierComputedOnce() {
        val p = ReelWidgetSync.compose(source(), now, reduceMotion = true, accessibilityOn = true, demo = false)
        assertEquals(
            WidgetPayload(
                reelCount = 238,
                watchSeconds = 4256, // ms truncate to whole seconds
                reelTier = 3,
                hourlySeconds = hours,
                limitMinutes = 30, // the soonest active limit, 30.99 min rounded down
                theme = "dark",
                reduceMotion = true,
                updatedAt = now,
                trackingEnabled = true,
            ),
            p,
        )
        // Through the wire and back unchanged: the writer only emits what parse accepts.
        assertEquals(p, WidgetPayload.parse(p.toJson()))
    }

    @Test
    fun trackingNeedsTheCounterAndTheService() {
        fun tracking(enabled: Boolean, a11y: Boolean) =
            ReelWidgetSync.compose(source(enabled = enabled), now, false, a11y, demo = false).trackingEnabled
        assertTrue(tracking(enabled = true, a11y = true))
        assertFalse(tracking(enabled = false, a11y = true))
        assertFalse(tracking(enabled = true, a11y = false))
    }

    @Test
    fun theLimitIsTheSoonestActiveOneInWholeMinutes() {
        assertEquals(30, ReelWidgetSync.limitMinutes(limits, now)) // 1 859 999 ms, rounded down
        assertEquals(120, ReelWidgetSync.limitMinutes(limits, now + 10)) // the rule's window closed
        val none = ReelWidgetSync.compose(source(reelLimits = emptyList()), now, false, true, demo = false)
        assertEquals(0, none.limitMinutes)
    }

    @Test
    fun theDemoIsForcedOrPickedUntilTheFirstReelEverCounts() {
        val demo = WidgetPayload.demo(30, "dark", false, now)
        // Forced either way…
        assertEquals(demo, ReelWidgetSync.compose(source(), now, false, true, demo = true))
        assertEquals(238, ReelWidgetSync.compose(source(total = 0), now, false, true, demo = false).reelCount)
        // …or auto: the demo iff nothing was ever counted.
        assertEquals(demo, ReelWidgetSync.compose(source(today = 0, total = 0), now, false, true, demo = null))
        assertEquals(238, ReelWidgetSync.compose(source(), now, false, true, demo = null).reelCount)
    }

    @Test
    fun aNewDaysSourceIsTheEmptyDayWithLimitThemeAndFlagsKept() {
        // MIDNIGHT builds like any push: the store's read-time rollover hands
        // compose zeros for today, and the all-time total keeps it live.
        val newDay = source(today = 0, timeTodayMs = 0L, hourlySeconds = List(24) { 0 })
        val empty = ReelWidgetSync.compose(newDay, now, true, false, demo = false)
        assertEquals(
            WidgetPayload(
                reelCount = 0,
                watchSeconds = 0,
                reelTier = 0,
                hourlySeconds = WidgetPayload.EMPTY.hourlySeconds,
                limitMinutes = 30,
                theme = "dark",
                reduceMotion = true,
                updatedAt = now,
                trackingEnabled = false,
            ),
            empty,
        )
    }

    @Test
    fun aLimitPastADayIsCappedNotWrapped() {
        fun limit(ms: Long) = ReelWidgetSync.limitMinutes(
            RuleEngine.parse("""[{"id":"x","platformIds":["*"],"always":true,"reelTimeLimitMs":$ms}]""")!!,
            now,
        )
        assertEquals(1_440, WidgetTokens.MAX_LIMIT_MINUTES)
        assertEquals(1_440, limit(1_440 * 60_000L))
        assertEquals(1_440, limit(1_441 * 60_000L)) // the payload's parse caps at a day too
        assertEquals(1_440, limit(Long.MAX_VALUE)) // Long division first: no Int wrap
        assertEquals(0, limit(59_999L)) // under a minute rounds down to none
    }

    @Test
    fun anUnchangedFrameIsSkippedPinnedOrNot() {
        val key = "06-10-2026|152|2"
        assertFalse(ReelWidgetSync.isDrawn(null, key))
        assertTrue(ReelWidgetSync.isDrawn(key, key))
        // Written with nothing pinned: a later pin's onUpdate drew this payload.
        assertTrue(ReelWidgetSync.isDrawn(ReelWidgetSync.NONE_PINNED + key, key))
        assertFalse(ReelWidgetSync.isDrawn(ReelWidgetSync.NONE_PINNED + "06-10-2026|153|2", key))
        assertFalse(ReelWidgetSync.isDrawn("06-10-2026|151|2", key))
    }

    @Test
    fun aChangeInThePlanAloneIsWhatOnlyAPlanWidgetShows() {
        val p = WidgetPayload.demo(120, "system", false, now)
        fun key(payload: WidgetPayload = p, plan: PlanState = PlanState.DEMO) =
            WidgetPayload.visibleKey(payload, now, 0, false, false, plan = plan)
        val paused = PlanState.DEMO.copy(pauseUntil = now + 4 * 60_000L)
        assertTrue(ReelWidgetSync.onlyPlanDiffers(key(), key(plan = paused)))
        assertTrue(ReelWidgetSync.onlyPlanDiffers(key(), key(plan = PlanState.DEMO.copy(blockingOn = false))))
        // The reel frame changed too: the reel families must redraw.
        assertFalse(ReelWidgetSync.onlyPlanDiffers(key(), key(p.copy(reelCount = p.reelCount + 1), paused)))
        // Nothing drawn yet, or last written with nothing pinned: draw.
        assertFalse(ReelWidgetSync.onlyPlanDiffers(null, key(plan = paused)))
        assertFalse(ReelWidgetSync.onlyPlanDiffers(ReelWidgetSync.NONE_PINNED + key(), key(plan = paused)))
        // The push's gate: record without drawing only when no Plan widget shows it.
        assertTrue(ReelWidgetSync.planOnlyChange(key(), key(plan = paused), planPinned = false))
        assertFalse(ReelWidgetSync.planOnlyChange(key(), key(plan = paused), planPinned = true))
        assertFalse(ReelWidgetSync.planOnlyChange(key(), key(p.copy(reelCount = p.reelCount + 1)), planPinned = false))
    }
}
