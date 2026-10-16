package com.errorxperts.detoxo.overlay.bubble

import com.errorxperts.detoxo.widget.fixture
import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Locale

/**
 * Drives [BubbleModel] through every case of `bubble_cases.json`, the fixture
 * the Dart `BubbleModel` test shares. Each `expected` key maps to the function
 * of the same name; a key with no mapping fails, so the two sides cannot drift.
 */
class BubbleModelTest {

    @Test
    fun everyCaseMatchesEveryExpectedKey() {
        val cases = fixture("bubble_cases.json").getJSONArray("cases")
        assertEquals(14, cases.length())
        for (i in 0 until cases.length()) {
            val c = cases.getJSONObject(i)
            val name = c.getString("name")
            val count = c.getInt("count")
            val seconds = c.getInt("seconds")
            val variant = c.getString("variant")
            val tier = BubbleModel.tier(count)
            val pct = BubbleModel.pct(count)
            val expected = c.getJSONObject("expected")
            for (key in expected.keys()) {
                val want = expected.get(key)
                val got: Any = when (key) {
                    "tier" -> tier
                    "countText" -> BubbleModel.countText(count)
                    "shortTime" -> BubbleModel.shortTime(seconds)
                    "clock" -> BubbleModel.clock(seconds)
                    "pct" -> pct
                    "toNext" -> BubbleModel.toNext(count)
                    "nextLine" -> BubbleModel.nextLine(count)
                    "isDial" -> BubbleModel.isDial(variant)
                    "timerWidth" -> BubbleModel.timerWidth(seconds, variant)
                    "collapsedLabel" -> BubbleModel.collapsedLabel(count, seconds, variant)
                    "openLabel" -> BubbleModel.openLabel(seconds)
                    "bezelLit" -> BubbleModel.bezelLit(count)
                    "sandTop" -> BubbleModel.sandTop(pct)
                    "sandBottom" -> BubbleModel.sandBottom(pct)
                    "mascotLine" -> BubbleModel.mascotLine(tier)
                    else -> error("$name: expected key '$key' has no BubbleModel mapping")
                }
                when (got) {
                    is Float -> assertEquals("$name.$key", (want as Number).toFloat(), got, 1e-4f)
                    else -> assertEquals("$name.$key", want, got)
                }
            }
        }
    }

    @Test
    fun transitionsMatch() {
        val ts = fixture("bubble_cases.json").getJSONArray("transitions")
        for (i in 0 until ts.length()) {
            val t = ts.getJSONObject(i)
            assertEquals(
                "${t.getInt("from")}->${t.getInt("to")}",
                t.getString("expected"),
                BubbleModel.transition(t.getInt("from"), t.getInt("to")).name.lowercase(),
            )
        }
    }

    @Test
    fun remainingLabelSingular() =
        assertEquals("1 reel left. Tap to show the timer.", BubbleModel.remainingLabel(1))

    @Test
    fun remainingLabelPlural() =
        assertEquals("3 reels left. Tap to show the timer.", BubbleModel.remainingLabel(3))

    @Test
    fun clockKeepsAsciiDigitsUnderAnArabicLocale() {
        val before = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag("ar-EG"))
            assertEquals("1:12:08", BubbleModel.clock(4328))
        } finally {
            Locale.setDefault(before)
        }
    }
}
