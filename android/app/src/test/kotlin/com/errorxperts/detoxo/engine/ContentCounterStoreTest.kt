package com.errorxperts.detoxo.engine

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Pins the store's pure steps: the hourly buckets (the `cc_hourly_today`
 * CSV, ms per local hour) and when the `cc_reel_limits` mirror is written.
 */
class ContentCounterStoreTest {

    private fun next(stored: String?, rollover: Boolean = false, hour: Int = 21, deltaMs: Long = 5_000L) =
        ContentCounterStore.nextHourly(stored, rollover, hour, deltaMs)

    @Test
    fun deltasAccumulateInTheirHour() {
        val first = next(null)
        assertEquals(5_000L, first[21])
        assertEquals(5_000L, first.sum())
        val second = next(first.joinToString(","), hour = 22, deltaMs = 2_000L)
        assertEquals(5_000L, second[21])
        assertEquals(2_000L, second[22])
        assertArrayEquals(second, ContentCounterStore.hourlyOf(second.joinToString(",")))
    }

    @Test
    fun rolloverZeroesEvenWithoutADelta() {
        // The day's first reel can carry no pending usage; it must still clear yesterday.
        val yesterday = LongArray(24) { 60_000L }.joinToString(",")
        assertArrayEquals(LongArray(24), next(yesterday, rollover = true, deltaMs = 0L))
        assertEquals(5_000L, next(yesterday, rollover = true, hour = 0).sum())
    }

    @Test
    fun theHourIsClamped() {
        assertEquals(1L, next(null, hour = 24, deltaMs = 1L)[23])
        assertEquals(1L, next(null, hour = -1, deltaMs = 1L)[0])
    }

    @Test
    fun garbageReadsAsZeros() {
        val ones = LongArray(24) { 1L }
        val tail = LongArray(23).joinToString(",")
        for (bad in listOf("", "x", "1,2,3", ones.joinToString(",") + ",1", "x,$tail", "-5,$tail")) {
            assertArrayEquals(bad, LongArray(24), ContentCounterStore.hourlyOf(bad))
        }
        assertArrayEquals(ones, ContentCounterStore.hourlyOf(ones.joinToString(",")))
        assertEquals(24L, next(ones.joinToString(","), deltaMs = -9L).sum()) // a negative delta adds nothing
    }

    @Test
    fun theReelLimitMirrorIsWrittenOnlyWhenItsMetersChange() {
        val meter = """{"id":"m","platformIds":["*"],"always":true,"reelTimeLimitMs":60000}"""
        val schedule = """{"id":"s","packages":["com.instagram.android"]}"""
        val meters = RuleEngine.reelMetersJson("[$meter]")!! // org.json picks the key order
        assertEquals(meters, ContentCounterStore.reelLimitsToWrite(null, "[$schedule,$meter]"))
        // A snapshot whose meters are already stored writes nothing, even when the rest changed.
        assertNull(ContentCounterStore.reelLimitsToWrite(meters, "[$meter]"))
        assertNull(ContentCounterStore.reelLimitsToWrite(meters, "[$schedule,$meter]"))
        // Meters gone is a change: the empty mirror is written.
        assertEquals("[]", ContentCounterStore.reelLimitsToWrite(meters, "[$schedule]"))
        // Not an array: the stored mirror stays.
        assertNull(ContentCounterStore.reelLimitsToWrite(meters, "{not json"))
    }
}
