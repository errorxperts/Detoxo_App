package com.errorxperts.detoxo.overlay

import com.errorxperts.detoxo.widget.PlanState
import com.errorxperts.detoxo.widget.fixture
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test

/** Every row of the shared test/fixtures/accent_cases.json, which the Dart accent tests read too. */
class AccentResolverTest {
    private fun mode(token: String) = when (token) {
        "none" -> AccentResolver.Mode.NONE
        "blockAll" -> AccentResolver.Mode.BLOCK_ALL
        "conscious" -> AccentResolver.Mode.CONSCIOUS
        "pause" -> AccentResolver.Mode.PAUSE
        else -> AccentResolver.Mode.ONE_REEL
    }

    @Test
    fun reproducesEveryFixtureRow() {
        val cases = fixture("accent_cases.json").getJSONArray("cases")
        for (i in 0 until cases.length()) {
            val c = cases.getJSONObject(i)
            val left = if (c.isNull("pauseLeftMs")) null else c.getLong("pauseLeftMs")
            val got = AccentResolver.resolve(c.getString("theme") == "dark", mode(c.getString("mode")), c.getDouble("used"), left)
            val want = intArrayOf(c.getLong("main").toInt(), c.getLong("light").toInt(), c.getLong("deep").toInt())
            assertArrayEquals("row $i: $c", want, got)
        }
    }

    @Test
    fun picksTheModeTheTodayScreenLightsForEveryModesRow() {
        val now = 1_700_000_000_000L
        val rows = fixture("accent_cases.json").getJSONArray("modes")
        for (i in 0 until rows.length()) {
            val r = rows.getJSONObject(i)
            val plan = PlanState(
                plan = r.getString("plan"),
                pauseUntil = if (r.getBoolean("pauseLive")) now + 60_000L else 0L,
                reelAllowance = r.getInt("allowance"),
                reelsConsumed = 0,
                blockingOn = r.getBoolean("masterEnabled"),
                serviceOn = true,
            )
            assertEquals("row $i: $r", mode(r.getString("mode")), AccentResolver.modeOf(plan, now))
        }
    }

    @Test
    fun aPauseThatEndedIsNoLongerLive() {
        val plan = PlanState("BLOCK_ALL", pauseUntil = 1000L, reelAllowance = 1, reelsConsumed = 0, blockingOn = true, serviceOn = true)
        assertEquals(AccentResolver.Mode.BLOCK_ALL, AccentResolver.modeOf(plan, 1000L))
    }

    @Test
    fun usedFractionIsWholeSecondsOverTheDailyLimit() {
        assertEquals(0.0, AccentResolver.usedFraction(false, 2_700_000L, 10_800_000L), 0.0)
        assertEquals(0.0, AccentResolver.usedFraction(true, 2_700_000L, 0L), 0.0)
        assertEquals(0.25, AccentResolver.usedFraction(true, 2_700_000L, 10_800_000L), 1e-12)
        assertEquals(0.25, AccentResolver.usedFraction(true, 2_700_999L, 10_800_000L), 1e-12)
    }
}
