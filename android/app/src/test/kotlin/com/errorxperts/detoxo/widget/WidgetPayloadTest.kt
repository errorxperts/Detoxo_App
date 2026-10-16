package com.errorxperts.detoxo.widget

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins [WidgetPayload] against the parse vectors shared with the Dart
 * `home_widget_payload_test`, plus the writer's pure helpers.
 */
class WidgetPayloadTest {

    private val vectors = fixture("home_widget_payloads.json")

    @Test
    fun everySharedVectorParses() {
        assertEquals(WidgetPayload.EMPTY, payloadOf(vectors.getJSONObject("empty")))
        val cases = vectors.getJSONArray("cases")
        assertEquals(19, cases.length())
        for (i in 0 until cases.length()) {
            val c = cases.getJSONObject(i)
            val parsed = WidgetPayload.parse(c.getString("raw"))
            assertEquals(c.getString("name"), payloadOf(c.getJSONObject("expected")), parsed)
        }
        assertEquals(WidgetPayload.EMPTY, WidgetPayload.parse(null))
    }

    @Test
    fun boolsAreNeverReadFromStrings() {
        // The coercion `optBoolean` would apply; the shared vectors' "yes" / 1 don't reach it.
        val p = WidgetPayload.parse("""{"reduce_motion": "true", "tracking_enabled": "false"}""")
        assertFalse(p.reduceMotion)
        assertTrue(p.trackingEnabled)
    }

    @Test
    fun toJsonRoundTripsWithExactlyTheNineKeys() {
        val now = 1_791_668_400_000L
        val cases = vectors.getJSONArray("cases")
        val payloads = List(cases.length()) { WidgetPayload.parse(cases.getJSONObject(it).getString("raw")) } +
            WidgetPayload.demo(30, "dark", true, now)
        for (p in payloads) {
            assertEquals(p, WidgetPayload.parse(p.toJson()))
            assertEquals(KEYS, JSONObject(p.toJson()).keys().asSequence().toSet())
        }
    }

    @Test
    fun demoIsTheBoardsDay() {
        val demo = WidgetPayload.demo(120, "system", true, 42L)
        assertEquals(152, demo.reelCount)
        assertEquals(4256, demo.watchSeconds)
        assertEquals(2, demo.reelTier)
        assertEquals(42L, demo.updatedAt)
        assertTrue(demo.trackingEnabled)
        val cases = fixture("home_widget_cases.json").getJSONArray("cases")
        val board = (0 until cases.length()).map { cases.getJSONObject(it) }
            .single { it.getString("name") == "tier2_152" }
        val hours = board.getJSONObject("payload").getJSONArray("hourly_seconds")
        assertEquals(List(hours.length()) { hours.getInt(it) }, demo.hourlySeconds)
    }

    @Test
    fun tierStepsEveryHundredReelsUpToFive() {
        val tiers = mapOf(0 to 0, 1 to 1, 99 to 1, 100 to 2, 101 to 2, 399 to 4, 400 to 5, 500 to 5)
        for ((count, tier) in tiers) assertEquals("count $count", tier, WidgetPayload.tierOf(count))
    }

    @Test
    fun countPushesEveryTenReelsAndOnTheFirst() {
        assertTrue(WidgetPayload.shouldPushOnCount(0, 1)) // tier 0 → 1
        assertTrue(WidgetPayload.shouldPushOnCount(9, 10))
        assertFalse(WidgetPayload.shouldPushOnCount(10, 11))
        assertTrue(WidgetPayload.shouldPushOnCount(99, 100))
        assertFalse(WidgetPayload.shouldPushOnCount(100, 101))
    }

    @Test
    fun visibleKeyChangesOnlyWhenSomethingVisibleChanges() {
        val now = 1_791_668_400_000L // 21:40 UTC
        val base = WidgetPayload.demo(120, "system", false, now)
        fun key(p: WidgetPayload = base, at: Long = now, use24h: Boolean = false, systemDark: Boolean = false) =
            WidgetPayload.visibleKey(p, at, 0, use24h, systemDark)
        val k = key()

        // Invisible: seconds inside the same minute, a newer build, the motion
        // flag (home screens never animate), the device theme under a forced one.
        val hours = base.hourlySeconds.toMutableList().apply { this[23] += 3 }
        assertEquals(k, key(base.copy(watchSeconds = base.watchSeconds + 3, hourlySeconds = hours)))
        assertEquals(k, key(base.copy(updatedAt = now - 5 * MIN)))
        assertEquals(k, key(base.copy(reduceMotion = true)))
        assertEquals(key(base.copy(theme = "light")), key(base.copy(theme = "light"), systemDark = true))

        // Visible.
        assertNotEquals(k, key(base.copy(reelCount = 153)))
        assertNotEquals(k, key(base.copy(reelTier = 3)))
        assertNotEquals(k, key(base.copy(watchSeconds = base.watchSeconds + 60)))
        val hour = base.hourlySeconds.toMutableList().apply { this[3] += 60 }
        assertNotEquals(k, key(base.copy(hourlySeconds = hour)))
        assertNotEquals(k, key(base.copy(limitMinutes = 90)))
        assertNotEquals(k, key(systemDark = true))
        assertNotEquals(key(base.copy(theme = "light")), key(base.copy(theme = "dark")))
        assertNotEquals(k, key(base.copy(trackingEnabled = false)))
        assertNotEquals(k, key(use24h = true))
        assertNotEquals(k, key(at = now + 61 * MIN)) // goes stale
        val later = now + 70 * MIN
        assertNotEquals(key(at = later), key(base.copy(updatedAt = now - MIN), at = later)) // the stale clock
        assertNotEquals(key(WidgetPayload.EMPTY), key(WidgetPayload.EMPTY, at = now + DAY)) // the day alone
        // The time left of 2 h flips one second past a minute of watch time.
        val atMinute = base.copy(watchSeconds = 4260)
        assertNotEquals(key(atMinute), key(atMinute.copy(watchSeconds = 4261)))
    }

    @Test
    fun visibleKeyReadsUpdatedAtAtItsOwnOffset() {
        // 23:30 GMT on 28 Mar, read at 02:10 BST after the spring change: yesterday.
        val updated = 1_774_740_600_000L
        val p = WidgetPayload.demo(120, "system", false, updated)
        val now = updated + 100 * MIN
        val atNowOffset = WidgetPayload.visibleKey(p, now, 60, false, false)
        assertEquals(atNowOffset, WidgetPayload.visibleKey(p, now, 60, false, false, updatedZoneOffsetMin = 60))
        assertNotEquals(atNowOffset, WidgetPayload.visibleKey(p, now, 60, false, false, updatedZoneOffsetMin = 0))
    }

    @Test
    fun visibleKeyFollowsWhatThePlanFaceShows() {
        val now = 1_791_000_000_000L
        val p = WidgetPayload.demo(120, "system", false, now)
        fun key(plan: PlanState, at: Long = now) = WidgetPayload.visibleKey(p, at, 0, false, false, plan = plan)
        val paused = PlanState.DEMO.copy(pauseUntil = now + 4 * MIN)
        // Block All draws no count: the count alone changes nothing.
        assertEquals(key(PlanState.DEMO), key(PlanState.DEMO.copy(reelsConsumed = 3)))
        assertNotEquals(key(PlanState.DEMO), key(paused))
        // 4m left at `now`; 3m30s and 3m00s both floor to "3m".
        assertNotEquals(key(paused), key(paused, at = now + 30_000L))
        assertEquals(key(paused, at = now + 30_000L), key(paused, at = now + MIN))
        assertNotEquals(key(PlanState.DEMO), key(PlanState.DEMO.copy(blockingOn = false)))
        assertNotEquals(key(PlanState.DEMO), key(PlanState.DEMO.copy(serviceOn = false)))
    }

    private fun payloadOf(o: JSONObject): WidgetPayload {
        val hours = o.getJSONArray("hourly_seconds")
        return WidgetPayload(
            reelCount = o.getInt("reel_count"),
            watchSeconds = o.getInt("watch_seconds"),
            reelTier = o.getInt("reel_tier"),
            hourlySeconds = List(hours.length()) { hours.getInt(it) },
            limitMinutes = o.getInt("limit_minutes"),
            theme = o.getString("theme"),
            reduceMotion = o.getBoolean("reduce_motion"),
            updatedAt = o.getLong("updated_at"),
            trackingEnabled = o.getBoolean("tracking_enabled"),
        )
    }

    private companion object {
        const val MIN = 60_000L
        const val DAY = 86_400_000L
        val KEYS = setOf(
            "reel_count", "watch_seconds", "reel_tier", "hourly_seconds", "limit_minutes",
            "theme", "reduce_motion", "updated_at", "tracking_enabled",
        )
    }
}
