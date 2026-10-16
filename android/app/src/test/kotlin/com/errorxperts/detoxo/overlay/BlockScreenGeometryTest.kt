package com.errorxperts.detoxo.overlay

import com.errorxperts.detoxo.widget.blend
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pins the wall's pure half: window flags, the strip-width formula at both SDK
 * branches, the plan-label mapping (the wire token `CURIOUS` must never reach
 * a screen), the payload sanitiser (EVO-018), the style spec, and the colours
 * (the palette and every accent-on-ground rule, for each theme primary).
 * Window lifecycle needs a device — see the device-sanity list in
 * docs/code_docs/25-block-screen.md.
 */
class BlockScreenGeometryTest {

    // Every theme primary in `brandFor()` (`app_theme.dart`): Aurora dark and dark1–6,
    // then light1 (Sky), light2 (Teal), light4 (Rose), Aurora light, light3 and light5.
    private val darkPrimaries = intArrayOf(
        0xFF8B93FF.toInt(), 0xFF5B8CFF.toInt(), 0xFFA78BFF.toInt(), 0xFF9B7CFF.toInt(),
        0xFFFF6FB0.toInt(), 0xFF5AA0FF.toInt(), 0xFF37DFA0.toInt(),
    )
    private val sky = 0xFF2F6BFF.toInt()
    private val teal = 0xFF0B7E8C.toInt()
    private val rose = 0xFFC0367A.toInt()
    private val alreadyLegibleLight = intArrayOf(0xFF4F46E5.toInt(), 0xFFC21D9E.toInt(), 0xFF5257DB.toInt())

    /** `BrandTint.FALLBACK`: the accent before Dart has ever pushed one. */
    private val fallback = 0xFF1C3D78.toInt()
    private val everyAccent = darkPrimaries + intArrayOf(sky, teal, rose) + alreadyLegibleLight + fallback

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
    fun primaryButtonTextFollowsItsFill() {
        val navy = 0xFF0B1326.toInt()
        val white = 0xFFFFFFFF.toInt()
        assertEquals(navy, onColorFor(0xFF12A594.toInt())) // light accent: navy 6.0:1, white 3.1:1
        assertEquals(navy, onColorFor(0xFF44E2CD.toInt())) // dark accent
        assertEquals(navy, onColorFor(0xFF30A46C.toInt())) // green
        assertEquals(white, onColorFor(0xFFC63A3E.toInt())) // deep red: navy 3.6:1
        assertTrue(contrastRatio(navy, 0xFF12A594.toInt()) >= 4.5)
        assertTrue(contrastRatio(white, 0xFFC63A3E.toInt()) >= 4.5)
        assertEquals(21.0, contrastRatio(navy.and(0xFF000000.toInt()), white), 0.01) // black on white
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
    fun theWallPaletteReadsForEveryThemePrimary() {
        for (dark in listOf(false, true)) {
            for (accent in everyAccent) {
                val p = wallPalette(dark, accent)
                val tag = "dark=$dark accent=${Integer.toHexString(accent)}"
                assertTrue("ink $tag", contrastRatio(p.ink, p.ground) >= 7.0)
                assertTrue("muted $tag", contrastRatio(p.muted, p.ground) >= 4.5)
            }
        }
        // The light wall is the board's own, whatever the accent.
        assertEquals(Palette(0xFFECEFF4.toInt(), 0xFF12151B.toInt(), 0xFF5A6170.toInt()), wallPalette(false, sky))
        // The dark ground carries a breath of the accent: two accents, two grounds.
        assertNotEquals(wallPalette(true, sky).ground, wallPalette(true, rose).ground)
    }

    @Test
    fun legibleOnMakesEveryAccentReadOnBothWalls() {
        for (dark in listOf(false, true)) {
            for (accent in everyAccent) {
                val p = wallPalette(dark, accent)
                val c = legibleOn(accent, p.ground, p.ink)
                assertTrue("dark=$dark accent=${Integer.toHexString(accent)}", contrastRatio(c, p.ground) >= 4.5)
            }
        }
    }

    @Test
    fun chipLabelsReadOnTheirOwnTintedFill() {
        for (dark in listOf(false, true)) {
            for (accent in everyAccent) {
                val p = wallPalette(dark, accent)
                val fill = outlinedFill(accent, p.ground)
                val tag = "dark=$dark accent=${Integer.toHexString(accent)}"
                assertTrue(tag, contrastRatio(legibleOn(accent, fill, p.ink), fill) >= 4.5)
            }
        }
    }

    @Test
    fun theSpotlightKeepsItsMutedTextReadableUnderTheLight() {
        // At the light's centre the writer and meta sit on the glow AND the lit logo.
        for (accent in darkPrimaries + fallback) {
            val p = wallPalette(true, accent)
            val lit = blend(accent, blend(accent, p.ground, GLOW_ALPHA / 255f), LIT_LOGO_ALPHA / 255f)
            assertTrue(Integer.toHexString(accent), contrastRatio(p.muted, lit) >= 4.5)
        }
    }

    @Test
    fun legibleOnLeavesAnAccentThatAlreadyReadsAlone() {
        val light = wallPalette(false, sky)
        // The light wall deepens Sky (3.9:1), Teal and Rose a little, and nothing else of the light set.
        for (c in intArrayOf(sky, teal, rose)) assertNotEquals(c, legibleOn(c, light.ground, light.ink))
        for (c in alreadyLegibleLight + fallback) assertEquals(c, legibleOn(c, light.ground, light.ink))
        // The dark wall leaves every dark primary alone and lifts only the fallback navy.
        for (c in darkPrimaries) {
            val p = wallPalette(true, c)
            assertEquals(c, legibleOn(c, p.ground, p.ink))
        }
        val p = wallPalette(true, fallback)
        assertNotEquals(fallback, legibleOn(fallback, p.ground, p.ink))
        assertEquals(p.ink, legibleOn(p.ink, p.ground, p.ink))
    }

    @Test
    fun legibleFillDarkensOnlyWhatNeedsIt() {
        val sky = 0xFF2F6BFF.toInt() // light1: white text 4.499:1, navy worse
        val fixed = legibleFill(sky)
        assertNotEquals(sky, fixed)
        assertTrue(contrastRatio(onColorFor(fixed), fixed) >= 4.5)
        // Theme primaries that already read, the fallback brand, and the old teal accent.
        for (ok in intArrayOf(0xFF4F46E5.toInt(), 0xFF5B8CFF.toInt(), 0xFF1C3D78.toInt(), 0xFF44E2CD.toInt())) {
            assertEquals(ok, legibleFill(ok))
        }
    }
}
