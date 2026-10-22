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
 * (the palette and every accent-on-ground rule, for each spec palette main).
 * Window lifecycle needs a device — see the device-sanity list in
 * docs/code_docs/25-block-screen.md.
 */
class BlockScreenGeometryTest {

    // Every accent the wall can take: the main of each spec palette (brand, Block All,
    // Conscious, Pause, One Reel, over) in each theme, from the generated DxTokens.
    private val darkMains = intArrayOf(
        DxTokens.BRAND_MAIN_DARK, DxTokens.BLOCK_ALL_MAIN_DARK, DxTokens.CONSCIOUS_MAIN_DARK,
        DxTokens.PAUSE_MAIN_DARK, DxTokens.ONE_REEL_MAIN_DARK, DxTokens.OVER_MAIN_DARK,
    )
    private val lightMains = intArrayOf(
        DxTokens.BRAND_MAIN_LIGHT, DxTokens.BLOCK_ALL_MAIN_LIGHT, DxTokens.CONSCIOUS_MAIN_LIGHT,
        DxTokens.PAUSE_MAIN_LIGHT, DxTokens.ONE_REEL_MAIN_LIGHT, DxTokens.OVER_MAIN_LIGHT,
    )

    /** `BrandTint.FALLBACK`: the accent before Dart has ever pushed one. */
    private val fallback = 0xFF1C3D78.toInt()
    private val everyAccent = darkMains + lightMains + fallback

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
        assertEquals(
            Palette(0xFFECEFF4.toInt(), 0xFF12151B.toInt(), 0xFF5A6170.toInt()),
            wallPalette(false, DxTokens.BRAND_MAIN_LIGHT),
        )
        // The dark ground carries a breath of the accent: two accents, two grounds.
        assertNotEquals(
            wallPalette(true, DxTokens.BRAND_MAIN_DARK).ground,
            wallPalette(true, DxTokens.ONE_REEL_MAIN_DARK).ground,
        )
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
        for (accent in darkMains + fallback) {
            val p = wallPalette(true, accent)
            val lit = blend(accent, blend(accent, p.ground, GLOW_ALPHA / 255f), LIT_LOGO_ALPHA / 255f)
            assertTrue(Integer.toHexString(accent), contrastRatio(p.muted, lit) >= 4.5)
        }
    }

    @Test
    fun legibleOnLeavesAnAccentThatAlreadyReadsAlone() {
        val light = wallPalette(false, DxTokens.BRAND_MAIN_LIGHT)
        // The light wall deepens every light main (each is under 4.5:1 on #ECEFF4), not the fallback.
        for (c in lightMains) assertNotEquals(c, legibleOn(c, light.ground, light.ink))
        assertEquals(fallback, legibleOn(fallback, light.ground, light.ink))
        // The dark wall leaves every dark main alone and lifts only the fallback navy.
        for (c in darkMains) {
            val p = wallPalette(true, c)
            assertEquals(c, legibleOn(c, p.ground, p.ink))
        }
        val p = wallPalette(true, fallback)
        assertNotEquals(fallback, legibleOn(fallback, p.ground, p.ink))
        assertEquals(p.ink, legibleOn(p.ink, p.ground, p.ink))
    }

    @Test
    fun legibleFillDarkensOnlyWhatNeedsIt() {
        // Only Light over-main (#e5384f) needs darkening; every other accent already reads.
        val over = DxTokens.OVER_MAIN_LIGHT
        val fixed = legibleFill(over)
        assertNotEquals(over, fixed)
        assertTrue(contrastRatio(onColorFor(fixed), fixed) >= 4.5)
        for (ok in everyAccent) {
            if (ok != over) assertEquals(Integer.toHexString(ok), ok, legibleFill(ok))
        }
    }
}
