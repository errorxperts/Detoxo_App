package com.errorxperts.detoxo.widget

import com.errorxperts.detoxo.channels.CommandHandler
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Drives [WidgetModel] through every case of the fixture the Dart
 * `home_widget_model_test` shares. Each `expected` key is read from the model
 * field of the same name, so a key the model lacks fails here.
 */
class WidgetModelTest {

    @Test
    fun everyCaseMatchesEveryExpectedKey() {
        val cases = fixture("home_widget_cases.json").getJSONArray("cases")
        assertEquals(22, cases.length())
        for (i in 0 until cases.length()) {
            val c = cases.getJSONObject(i)
            val name = c.getString("name")
            val model = WidgetModel(
                WidgetPayload.parse(c.getJSONObject("payload").toString()),
                c.getLong("nowMs"),
                c.getInt("zoneOffsetMin"),
                c.getBoolean("use24h"),
                c.getInt("updatedZoneOffsetMin"),
            )
            val expected = c.getJSONObject("expected")
            for (key in expected.keys()) {
                val want = expected.get(key)
                when (key) {
                    "describe" -> assertDescribe(name, model, want as JSONObject)
                    "bars" -> assertBars(name, model.bars, want as JSONArray)
                    else -> assertEquals("$name.$key", if (want == JSONObject.NULL) null else want, field(model, key))
                }
            }
        }
    }

    @Test
    fun aLimitBuiltInCodePastADayReadsAsTheDayNotWrapped() {
        // Int.MAX_VALUE × 60 wraps negative in Int: no limit at all.
        val model = WidgetModel(WidgetPayload.EMPTY.copy(limitMinutes = Int.MAX_VALUE), 0L, 0, false)
        assertTrue(model.hasLimit)
        assertEquals("Left of 24h", model.limitLabel)
    }

    @Test
    fun everyPlanCaseMatchesEveryExpectedKey() {
        val cases = fixture("home_widget_plan_cases.json").getJSONArray("cases")
        assertEquals(18, cases.length())
        for (i in 0 until cases.length()) {
            val c = cases.getJSONObject(i)
            val name = c.getString("name")
            val s = c.getJSONObject("state")
            val model = WidgetModel(
                WidgetPayload.EMPTY,
                c.getLong("nowMs"),
                c.getInt("zoneOffsetMin"),
                c.getBoolean("use24h"),
                plan = PlanState(
                    s.getString("plan"),
                    s.getLong("pauseUntil"),
                    s.getInt("reelAllowance"),
                    s.getInt("reelsConsumed"),
                    s.getBoolean("blockingOn"),
                    s.getBoolean("serviceOn"),
                ),
            )
            val expected = c.getJSONObject("expected")
            for (key in expected.keys()) assertEquals("$name.$key", expected.get(key), field(model, key))
            for (size in WidgetSize.entries) {
                assertEquals("$name.describe", expected.getString("planDescription"), model.describe(WidgetFamily.PLAN, size))
            }
        }
    }

    @Test
    fun thePlanLineTakesNoTrackingOrStaleNote() {
        val model = WidgetModel(WidgetPayload.EMPTY.copy(updatedAt = 1L, trackingEnabled = false), 36_000_000L, 0, false)
        assertEquals("Turn on tracking", model.note)
        assertEquals("Block All is on, every reel is blocked", model.describe(WidgetFamily.PLAN, WidgetSize.LARGE))
    }

    @Test
    fun theConsciousPlanReadsConsciousNeverItsWireToken() {
        // CURIOUS is the wire token only; every Plan string a user sees or hears says "Conscious".
        val model = WidgetModel(
            WidgetPayload.EMPTY,
            0L,
            0,
            false,
            plan = PlanState.DEMO.copy(plan = CommandHandler.PLAN_CONSCIOUS),
        )
        assertEquals("Conscious", model.planTitle)
        assertEquals("Conscious is on, earn reel time by staying off", model.planDescription)
        val shown = listOf(
            model.planTitle, model.planLabelShort, model.planLabelLong, model.planValueShort,
            model.planValueLong, model.planRingText, model.planDescription,
        )
        for (text in shown) assertFalse(text, text.contains("curious", ignoreCase = true))
    }

    @Test
    fun thePlanTickLandsOnEachMinuteStepAndOnThePauseEnd() {
        assertEquals(1L, WidgetModel.planTickDelayMs(1L))
        // The last two minutes tick at most a minute apart (uptime stops in sleep).
        assertEquals(60_000L, WidgetModel.planTickDelayMs(90_000L))
        assertEquals(60_000L, WidgetModel.planTickDelayMs(119_999L))
        assertEquals(59_999L, WidgetModel.planTickDelayMs(59_999L))
        assertEquals(1L, WidgetModel.planTickDelayMs(120_000L))
        assertEquals(60_000L, WidgetModel.planTickDelayMs(239_999L))
        assertEquals(1L, WidgetModel.planTickDelayMs(240_000L))
    }

    /** The model's public field named [key]: `final` → `getFinal()`. */
    private fun field(model: WidgetModel, key: String): Any? =
        WidgetModel::class.java.getMethod("get" + key.replaceFirstChar(Char::uppercaseChar)).invoke(model)

    private fun assertBars(name: String, bars: List<Double>, want: JSONArray) {
        assertEquals("$name.bars", want.length(), bars.size)
        for (h in bars.indices) assertEquals("$name.bars[$h]", want.getDouble(h), bars[h], 1e-9)
    }

    private fun assertDescribe(name: String, model: WidgetModel, want: JSONObject) {
        // PLAN reads no payload: home_widget_plan_cases.json pins its line.
        val reelFamilies = WidgetFamily.entries - WidgetFamily.PLAN
        assertEquals("$name.describe", reelFamilies.size * WidgetSize.entries.size, want.length())
        for (family in reelFamilies) {
            for (size in WidgetSize.entries) {
                val key = "${family.wire}:${size.wire}"
                assertEquals("$name.$key", want.getString(key), model.describe(family, size))
            }
        }
    }
}
