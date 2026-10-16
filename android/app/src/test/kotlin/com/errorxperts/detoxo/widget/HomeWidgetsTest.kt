package com.errorxperts.detoxo.widget

import android.content.Intent
import java.time.LocalDateTime
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the widget glue's pure parts: the family → provider lookup (and the
 * Count class name already-pinned widgets point at), the tap string Dart's
 * `WidgetTap.parse` reads, the tap target rule, when a launch drops a stale
 * tap, the per-instance render loop, the instance bounds and the midnight
 * job's delay.
 */
class HomeWidgetsTest {

    @Test
    fun everyFamilyHasItsOwnProviderAndCountKeepsItsClassName() {
        val providers = WidgetFamily.entries.map { HomeWidgets.providerFor(it) }
        assertEquals(WidgetFamily.entries.size, providers.toSet().size)
        assertEquals(
            "com.errorxperts.detoxo.widget.ContentCounterWidgetProvider",
            HomeWidgets.providerFor(WidgetFamily.COUNT).name,
        )
    }

    @Test
    fun theTapStringIsWhatDartParses() {
        assertEquals(
            "BONSAI|LARGE|PERMISSIONS",
            HomeWidgets.tapWire(WidgetFamily.BONSAI, WidgetSize.LARGE, WidgetTapTarget.PERMISSIONS),
        )
        // Dart `WidgetTap.parse`: exactly three `|` parts, each a wire token.
        assertEquals(listOf("ACTIVITY", "APPEARANCE", "PERMISSIONS", "SETTINGS"), WidgetTapTarget.entries.map { it.name })
        for (family in WidgetFamily.entries) {
            for (size in WidgetSize.entries) {
                for (target in WidgetTapTarget.entries) {
                    val (f, s, t) = HomeWidgets.tapWire(family, size, target).split('|').also { assertEquals(3, it.size) }
                    assertEquals(family, WidgetFamily.fromWire(f))
                    assertEquals(size, WidgetSize.fromWire(s))
                    assertEquals(target, WidgetTapTarget.valueOf(t))
                }
            }
        }
    }

    @Test
    fun aTapLeadsToWhatFixesTracking() {
        fun of(counterOn: Boolean, accessibilityOn: Boolean) =
            WidgetTapTarget.of(WidgetFamily.COUNT, counterOn = counterOn, accessibilityOn = accessibilityOn, plan = PlanState.DEMO)
        assertEquals(WidgetTapTarget.ACTIVITY, of(counterOn = true, accessibilityOn = true))
        assertEquals(WidgetTapTarget.PERMISSIONS, of(counterOn = true, accessibilityOn = false))
        // Counter off wins: turning it on comes first.
        assertEquals(WidgetTapTarget.APPEARANCE, of(counterOn = false, accessibilityOn = false))
        assertEquals(WidgetTapTarget.APPEARANCE, of(counterOn = false, accessibilityOn = true))
    }

    @Test
    fun aPlanTapLeadsToWhatFixesBlocking() {
        fun plan(counterOn: Boolean = true, state: PlanState = PlanState.DEMO) =
            WidgetTapTarget.of(WidgetFamily.PLAN, counterOn, accessibilityOn = true, plan = state)
        assertEquals(WidgetTapTarget.ACTIVITY, plan())
        // The counter has nothing to do with blocking.
        assertEquals(WidgetTapTarget.ACTIVITY, plan(counterOn = false))
        assertEquals(WidgetTapTarget.SETTINGS, plan(state = PlanState.DEMO.copy(blockingOn = false)))
        // The grant first: without the service the switch changes nothing.
        assertEquals(
            WidgetTapTarget.PERMISSIONS,
            plan(state = PlanState.DEMO.copy(blockingOn = false, serviceOn = false)),
        )
        // The reel families ignore the switch.
        assertEquals(
            WidgetTapTarget.ACTIVITY,
            WidgetTapTarget.of(WidgetFamily.COUNT, true, true, PlanState.DEMO.copy(blockingOn = false)),
        )
    }

    @Test
    fun onlyAPlainLauncherOpenDropsAnUntakenTap() {
        // The launcher's own flags on a cold or warm open.
        val launcher = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
        assertTrue(HomeWidgets.isPlainLaunch(Intent.ACTION_MAIN, launcher))
        assertTrue(HomeWidgets.isPlainLaunch(Intent.ACTION_MAIN, 0))
        // Recents replays the task's root intent: not a new visit.
        assertFalse(HomeWidgets.isPlainLaunch(Intent.ACTION_MAIN, launcher or Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY))
        // A tap sets the tap; anything else leaves it.
        assertFalse(HomeWidgets.isPlainLaunch(HomeWidgets.ACTION_TAP, launcher))
        assertFalse(HomeWidgets.isPlainLaunch(null, 0))
    }

    @Test
    fun oneInstanceThatThrowsLeavesTheRestDrawnAndThePushUnfinished() {
        val drawn = mutableListOf<Int>()
        val failed = mutableListOf<Int>()
        val ok = HomeWidgets.tryEach(listOf(1, 2, 3), { id, _ -> failed += id }) { id ->
            if (id == 2) error("binder died")
            drawn += id
        }
        assertFalse(ok) // so the rendered key is not written and the next push retries
        assertEquals(listOf(1, 3), drawn)
        assertEquals(listOf(2), failed)
        assertTrue(HomeWidgets.tryEach(listOf(1, 2), { _, _ -> }) { drawn += it })
        assertTrue(HomeWidgets.tryEach(emptyList<Int>(), { _, _ -> }) {})
    }

    @Test
    fun aPhoneUsesPortraitBoundsAndATabletItsCurrentOnes() {
        // min 130 × 110, max 180 × 220 dp.
        fun bounds(sw: Int, landscape: Boolean) = HomeWidgets.instanceDp(130, 110, 180, 220, sw, landscape)
        assertEquals(130 to 220, bounds(411, landscape = false))
        assertEquals(130 to 220, bounds(411, landscape = true))
        assertEquals(130 to 220, bounds(800, landscape = false))
        assertEquals(180 to 110, bounds(800, landscape = true))
        assertEquals(180 to 110, bounds(600, landscape = true)) // 600 is a tablet
    }

    @Test
    fun theMidnightJobWaitsForTheNextLocalMidnight() {
        fun delay(at: String, zone: String): Long {
            val z = ZoneId.of(zone)
            val now = LocalDateTime.parse(at).atZone(z).toInstant().toEpochMilli()
            return MidnightJobService.msUntilNextMidnight(now, z)
        }
        val hour = 3_600_000L
        assertEquals(2 * hour, delay("2026-10-11T22:00:00", "Asia/Kolkata"))
        assertEquals(1L, delay("2026-10-11T23:59:59.999", "UTC"))
        assertEquals(24 * hour, delay("2026-10-11T00:00:00", "UTC")) // at midnight: the next one
        // DST days are 23 and 25 hours long (New York, 2026-03-08 and 2026-11-01).
        assertEquals(23 * hour, delay("2026-03-08T00:00:00", "America/New_York"))
        assertEquals(25 * hour, delay("2026-11-01T00:00:00", "America/New_York"))
    }
}
