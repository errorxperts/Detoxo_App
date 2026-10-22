package com.errorxperts.detoxo.overlay

import com.errorxperts.detoxo.widget.withAlpha
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.roundToInt

/**
 * Pins the wall's pure half: window flags, the strip-width formula at both SDK
 * branches, the plan-label mapping (the wire token `CURIOUS` must never reach
 * a screen), the payload sanitiser (EVO-018), the style spec, and the
 * contrast of every text and glyph on what it sits on, in both themes, for
 * every accent the wall can take. Window lifecycle needs a device — see the
 * device-sanity list in docs/code_docs/25-block-screen.md.
 */
class BlockScreenGeometryTest {

    /**
     * Every accent main the wall can take in [dark]: each spec palette's, and
     * the live resolver's at the warm steps (used 0 / .6 / .85 / 1) for no
     * mode, Block All and a Pause in its last second.
     */
    private fun accents(dark: Boolean): Set<Int> {
        val mains = if (dark) {
            intArrayOf(
                DxTokens.BRAND_MAIN_DARK, DxTokens.BLOCK_ALL_MAIN_DARK, DxTokens.CONSCIOUS_MAIN_DARK,
                DxTokens.PAUSE_MAIN_DARK, DxTokens.ONE_REEL_MAIN_DARK, DxTokens.OVER_MAIN_DARK,
            )
        } else {
            intArrayOf(
                DxTokens.BRAND_MAIN_LIGHT, DxTokens.BLOCK_ALL_MAIN_LIGHT, DxTokens.CONSCIOUS_MAIN_LIGHT,
                DxTokens.PAUSE_MAIN_LIGHT, DxTokens.ONE_REEL_MAIN_LIGHT, DxTokens.OVER_MAIN_LIGHT,
            )
        }
        val resolved = listOf(0.0, 0.6, 0.85, 1.0).flatMap { used ->
            listOf(
                AccentResolver.resolve(dark, AccentResolver.Mode.NONE, used, null),
                AccentResolver.resolve(dark, AccentResolver.Mode.BLOCK_ALL, used, null),
                AccentResolver.resolve(dark, AccentResolver.Mode.PAUSE, used, 0L),
            ).map { it[0] }
        }
        return mains.toSet() + resolved
    }

    /** [text] (maybe translucent, as Dark ink-2 is) on the opaque [ground]. */
    private fun reads(text: Int, ground: Int) = contrastRatio(alphaOver(text, ground), ground)

    private fun alpha(k: Float) = (k * 255f).roundToInt()

    @Test
    fun windowFlagsAre808() {
        assertEquals(808, overlayFlags())
    }

    @Test
    fun stripWidthFollowsTheGestureInsetOnApi30() {
        assertEquals(48, stripWidthPx(30, 24, 32, 2f))
        assertEquals(36, stripWidthPx(34, 24, 0, 3f))
    }

    @Test
    fun stripWidthIs50dpBelowApi30() {
        assertEquals(125, stripWidthPx(29, 24, 32, 2.5f))
        assertEquals(100, stripWidthPx(24, 0, 0, 2f))
    }

    @Test
    fun planLabelsAreTheUserFacingNames() {
        assertEquals("Conscious", planLabel("CURIOUS", 1))
        assertEquals("One Reel", planLabel("ONE_REEL", 1))
        assertEquals("Unblock", planLabel("ONE_REEL", 5))
        assertEquals("Block All", planLabel("BLOCK_ALL", 1))
        assertEquals("Paused", planLabel("PAUSED", 1))
        assertEquals("", planLabel("", 1))
        assertEquals("", planLabel("weird", 1))
    }

    @Test
    fun theWireTokenNeverReachesALabel() {
        for (token in listOf("CURIOUS", "ONE_REEL", "BLOCK_ALL", "PAUSED", "")) {
            for (allowance in listOf(1, 5)) {
                assertFalse(planLabel(token, allowance).contains("curious", ignoreCase = true))
            }
        }
    }

    @Test
    fun adultPayloadIsNeverNamedAndNeverUnblockable() {
        val p = BlockScreenPayload.fromMap(
            mapOf(
                "referenceType" to "WEBSITE",
                "referenceId" to "example.test",
                "displayName" to "example.test",
                "appLabel" to "Chrome",
                "blockReason" to "ADULT",
                "plan" to "BLOCK_ALL",
                "offersUnblock" to true,
            ),
        )!!.sanitised()
        assertEquals("", p.displayName)
        assertEquals("", p.referenceId)
        assertEquals("Chrome", p.appLabel)
        assertFalse(p.offersUnblock)
        assertEquals("", p.plan)
    }

    @Test
    fun onlyAPlanBlockKeepsItsPlan() {
        val app = BlockScreenPayload.fromMap(
            mapOf("referenceType" to "APP", "blockReason" to "APP_BLOCK", "plan" to "BLOCK_ALL"),
        )!!.sanitised()
        assertEquals("", app.plan)
        val reel = BlockScreenPayload.fromMap(
            mapOf("referenceType" to "REEL", "blockReason" to "PLAN", "plan" to "CURIOUS", "bankMs" to 0),
        )!!.sanitised()
        assertEquals("CURIOUS", reel.plan)
        assertEquals(0L, reel.bankMs)
        assertEquals(-1, reel.todayCount)
        assertEquals(-1, reel.opensToday)
        assertEquals("", reel.packageName)
        assertTrue(reel.offersOpenApp)
    }

    @Test
    fun payloadNeedsAReferenceTypeAndAReason() {
        assertNull(BlockScreenPayload.fromMap(null))
        assertNull(BlockScreenPayload.fromMap(emptyMap<String, Any>()))
        assertNull(BlockScreenPayload.fromMap(mapOf("referenceType" to "REEL")))
    }

    @Test
    fun styleSpecDefaultsKeepTheWallOn() {
        val defaults = BlockScreenStyleSpec()
        assertTrue(defaults.enabled)
        assertTrue(defaults.showCount)
        assertTrue(defaults.showOpens)
        assertEquals(5, defaults.backDelaySec)
        assertEquals(defaults, BlockScreenStyleSpec.fromJson(null))
        assertEquals(defaults, BlockScreenStyleSpec.fromJson(""))
        assertEquals(defaults, BlockScreenStyleSpec.fromJson("not json"))
        assertEquals(defaults, BlockScreenStyleSpec.fromJson("[1, 2]")) // JSON, but not an object
    }

    @Test
    fun styleSpecParsesEveryFieldAndClampsTheDelay() {
        val s = BlockScreenStyleSpec.fromJson(
            """{"enabled":false,"showCount":false,"showOpens":false,"backDelaySec":99}""",
        )
        assertEquals(BlockScreenStyleSpec(enabled = false, showCount = false, showOpens = false, backDelaySec = 60), s)
        assertEquals(0, BlockScreenStyleSpec.fromJson("""{"backDelaySec":-3}""").backDelaySec)
    }

    @Test
    fun aStyleSavedBeforeTheQuotesOnlyWallStillParsesWithItsOldKeysIgnored() {
        // What the Dart editor persisted when the wall had a design, a background and a theme of its own.
        val s = BlockScreenStyleSpec.fromJson(
            """{"enabled":true,"theme":"DARK","background":"SOLID","showCount":false,
            "showOpens":true,"accentByUsage":true,"backDelaySec":10,"design":"CLASSIC"}""",
        )
        assertEquals(BlockScreenStyleSpec(showCount = false, backDelaySec = 10), s)
    }

    @Test
    fun theWallFollowsTheAppThemeThenTheDevice() {
        assertFalse(wallIsDark("LIGHT", systemDark = true))
        assertFalse(wallIsDark("LIGHT", systemDark = false))
        assertTrue(wallIsDark("DARK", systemDark = false))
        assertTrue(wallIsDark("DARK", systemDark = true))
        assertTrue(wallIsDark("SYSTEM", systemDark = true)) // "Match system" → the device
        assertFalse(wallIsDark("SYSTEM", systemDark = false))
        assertTrue(wallIsDark("", systemDark = true)) // never pushed → the device
        assertFalse(wallIsDark("", systemDark = false))
    }

    @Test
    fun theWallReadsInBothThemesForEveryAccent() {
        for (dark in listOf(false, true)) {
            val t = DxTheme(dark)
            val tag = "dark=$dark"
            // The ground, and the panel over the ground under the ambient at 84 dp (.09 at most).
            for (bg in intArrayOf(t.bgTop, t.bgBottom)) assertTrue("ink on bg $tag", reads(t.ink, bg) >= 4.5)
            for (accent in accents(dark)) {
                val at = "$tag accent=${Integer.toHexString(accent)}"
                val lit = alphaOver(withAlpha(accent, alpha(ambientAlphaAt(84f, 120f, t.kAmb))), t.bgTop)
                for (panel in t.panel) {
                    val under = alphaOver(panel, lit)
                    assertTrue("ink-2 on panel $at", reads(t.ink2, under) >= 4.5)
                    assertTrue("ink on panel $at", reads(t.ink, under) >= 4.5)
                }
                // Open Detoxo: the accent at k-pill, then the sheen, over the ground.
                for (bg in intArrayOf(t.bgTop, t.bgBottom)) {
                    val base = alphaOver(withAlpha(accent, alpha(t.kPill)), bg)
                    for (sheen in t.pill) assertTrue("ink on pill $at", reads(t.ink, alphaOver(sheen, base)) >= 4.5)
                }
            }
            // The chips, the text exits and the slide.
            assertTrue("ink-2 on a chip $tag", reads(t.ink2, alphaOver(t.fillQuiet, t.bgBottom)) >= 4.5)
            assertTrue("ink on a picked chip $tag", reads(t.ink, t.optionBase) >= 4.5)
            assertTrue("ink-2 on the ground $tag", reads(t.ink2, t.bgBottom) >= 4.5)
            for (track in t.track) {
                assertTrue("ink-2 on the track $tag", reads(t.ink2, track) >= 4.5)
                assertTrue("the countdown on the waiting knob $tag", reads(t.ink2, alphaOver(t.waitKnob, track)) >= 4.5)
            }
            // Home's glyph on the glass circle: an icon, 3:1.
            for (glass in t.glass) assertTrue("glyph on glass $tag", reads(t.ink, alphaOver(glass, t.bgBottom)) >= 3.0)
        }
    }

    @Test
    fun theNudgeCardReadsOverAnyFeedInBothThemes() {
        for (dark in listOf(false, true)) {
            val t = DxTheme(dark)
            for (sheet in t.opaqueSheet) {
                assertEquals("opaque dark=$dark", 0xFF, sheet ushr 24)
                assertTrue("title dark=$dark", reads(t.ink, sheet) >= 4.5)
                assertTrue("body and ✕ dark=$dark", reads(t.ink2, sheet) >= 4.5)
                assertTrue("Leave dark=$dark", reads(t.ink, alphaOver(t.fillQuiet, sheet)) >= 4.5)
            }
        }
    }

    @Test
    fun theSlidesToneReadsOnItsFill() {
        // The label's fill copy is the tone ink over the caution stops it can sit on.
        for (stop in intArrayOf(DxTokens.TONE_CAUTION_A, DxTokens.TONE_CAUTION_B, DxTokens.TONE_CAUTION_C)) {
            assertTrue(Integer.toHexString(stop), contrastRatio(DxTokens.TONE_CAUTION_INK, stop) >= 4.5)
        }
        // Its chevrons on the white knob: an icon, 3:1.
        for (knob in intArrayOf(DxTokens.KNOB_LIGHT, DxTokens.KNOB_DARK)) {
            assertTrue(contrastRatio(DxTokens.TONE_CAUTION_KNOB, knob) >= 3.0)
        }
    }
}
