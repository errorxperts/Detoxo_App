package com.errorxperts.detoxo.overlay

import com.errorxperts.detoxo.widget.fixture
import org.junit.Assert.assertArrayEquals
import org.junit.Test

/** Every row of the shared test/fixtures/accent_cases.json, which the Dart accent test reads too. */
class AccentResolverTest {
    @Test
    fun reproducesEveryFixtureRow() {
        val cases = fixture("accent_cases.json").getJSONArray("cases")
        for (i in 0 until cases.length()) {
            val c = cases.getJSONObject(i)
            val mode = when (c.getString("mode")) {
                "none" -> AccentResolver.Mode.NONE
                "blockAll" -> AccentResolver.Mode.BLOCK_ALL
                "conscious" -> AccentResolver.Mode.CONSCIOUS
                "pause" -> AccentResolver.Mode.PAUSE
                else -> AccentResolver.Mode.ONE_REEL
            }
            val left = if (c.isNull("pauseLeftMs")) null else c.getLong("pauseLeftMs")
            val got = AccentResolver.resolve(c.getString("theme") == "dark", mode, c.getDouble("used"), left)
            val want = intArrayOf(c.getLong("main").toInt(), c.getLong("light").toInt(), c.getLong("deep").toInt())
            assertArrayEquals("row $i: $c", want, got)
        }
    }
}
