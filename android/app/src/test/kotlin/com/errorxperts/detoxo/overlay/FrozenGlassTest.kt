package com.errorxperts.detoxo.overlay

import com.errorxperts.detoxo.widget.repoFile
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The native Frozen Glass kit's pure half: CSS geometry, blur, colour matrices, labels and icons. */
class FrozenGlassTest {

    @Test
    fun cssLineIsTheGradientLineOfEachAngle() {
        assertArrayEquals(floatArrayOf(50f, 0f, 50f, 50f), cssLine(180f, 100f, 50f), 0.01f)
        assertArrayEquals(floatArrayOf(0f, 25f, 100f, 25f), cssLine(90f, 100f, 50f), 0.01f)
        assertArrayEquals(floatArrayOf(10.05f, -7.05f, 89.95f, 107.05f), cssLine(145f, 100f, 100f), 0.01f)
    }

    @Test
    fun blurRadiusTakesTheCssBlurAsTwiceSigma() {
        assertEquals(26.846f, blurRadius(32f), 0.001f)
        assertEquals(0f, blurRadius(1f), 0f)
        assertEquals(0f, blurRadius(0f), 0f)
    }

    @Test
    fun hueOfIsTheHsvHue() {
        assertEquals(0.0, hueOf(0xFFFF0000.toInt()), 1e-9)
        assertEquals(120.0, hueOf(0xFF00FF00.toInt()), 1e-9)
        assertEquals(240.0, hueOf(0xFF0000FF.toInt()), 1e-9)
        assertEquals(0.0, hueOf(0xFF808080.toInt()), 1e-9)
        assertEquals(300.0, hueOf(0xFFFF00FF.toInt()), 1e-9) // max red, negative difference: wraps
    }

    @Test
    fun noRotationAndNoSaturationIsTheIdentity() {
        val identity = floatArrayOf(1f, 0f, 0f, 0f, 0f, 0f, 1f, 0f, 0f, 0f, 0f, 0f, 1f, 0f, 0f, 0f, 0f, 0f, 1f, 0f)
        assertArrayEquals(identity, hueRotateSaturate(0.0, 1.0), 1e-6f)
    }

    @Test
    fun theDarkPauseAccentTurnsTheBlueIconWarm() {
        val m = accentIconMatrix(DxTokens.PAUSE_MAIN_DARK)
        val blue = 0xFF3D8DF5.toInt() // a 214° blue, as the 3D mode icons are drawn
        assertEquals(214.0, hueOf(blue), 1.0)
        val r = ((blue shr 16) and 0xFF).toFloat()
        val g = ((blue shr 8) and 0xFF).toFloat()
        val b = (blue and 0xFF).toFloat()
        fun ch(row: Int) = (m[row * 5] * r + m[row * 5 + 1] * g + m[row * 5 + 2] * b).toInt().coerceIn(0, 255)
        val out = (0xFF shl 24) or (ch(0) shl 16) or (ch(1) shl 8) or ch(2)
        assertTrue(hueOf(out).toString(), hueOf(out) in 15.0..60.0)
        assertEquals(1f, m[18], 0f) // alpha untouched
    }

    @Test
    fun clockLabelsFollowTheDeviceClock() {
        assertEquals("11 PM", clockLabel(23, 0, false))
        assertEquals("7:30 AM", clockLabel(7, 30, false))
        assertEquals("12 AM", clockLabel(0, 0, false))
        assertEquals("12:05 PM", clockLabel(12, 5, false))
        assertEquals("23:00", clockLabel(23, 0, true))
        assertEquals("07:05", clockLabel(7, 5, true))
    }

    @Test
    fun everyBlockReasonHasItsOwnIconAndEveryIconShips() {
        val table = mapOf(
            Triple("PLAN", "BLOCK_ALL", 1) to "icon-block-all",
            Triple("PLAN", "", 1) to "icon-block-all",
            Triple("PLAN", "CURIOUS", 1) to "icon-conscious",
            Triple("PLAN", "ONE_REEL", 1) to "icon-one-reel",
            Triple("PLAN", "ONE_REEL", 3) to "icon-pause",
            Triple("APP_BLOCK", "", 1) to "icon-app-blocker",
            Triple("WEB_RULE", "", 1) to "icon-web-blocker",
            Triple("ADULT", "", 1) to "icon-web-blocker",
            Triple("SCHEDULE", "", 1) to "icon-blocker-rules",
            Triple("DAILY_LIMIT", "", 1) to "icon-blocker-rules",
        )
        for ((k, want) in table) assertEquals(k.toString(), want, heroIconFor(k.first, k.second, k.third))
        // Only the plan's mode icons take the accent.
        assertTrue(heroIconFor("PLAN", "CURIOUS", 1) in MODE_ICONS)
        assertFalse(heroIconFor("APP_BLOCK", "", 1) in MODE_ICONS)
        for (name in table.values.toSet()) {
            val bytes = repoFile("assets/images/icons/$name.webp").readBytes()
            assertEquals(name, "RIFF", String(bytes, 0, 4, Charsets.US_ASCII))
            assertEquals(name, "WEBP", String(bytes, 8, 4, Charsets.US_ASCII))
        }
        val logo = repoFile("assets/images/icons/detoxo_logo.png").readBytes()
        assertEquals("PNG", String(logo, 1, 3, Charsets.US_ASCII))
    }

    @Test
    fun aShortColumnShedsTheWellThenTheSizeThenLinesThenTheWriterThenTheHeader() {
        // header 68, well 112, the quote 112 at title / 88 at headline (4 lines of 22), writer 28.
        fun fit(room: Float) = wallFit(room, 68f, 112f, 112f, 88f, 22f, 28f)
        val all = Int.MAX_VALUE
        assertEquals(WallFit(true, true, false, all, true), fit(400f)) // roomy
        assertEquals(WallFit(true, false, false, all, true), fit(300f)) // tight: no well
        assertEquals(WallFit(true, false, true, all, true), fit(190f)) // tighter: headline
        assertEquals(WallFit(true, false, true, 2, true), fit(140f)) // fewer lines
        assertEquals(WallFit(true, false, true, 1, false), fit(100f)) // no writer
        assertEquals(WallFit(false, false, true, 2, false), fit(50f)) // no header
        assertEquals(WallFit(false, false, true, 1, false), fit(10f)) // never no quote
    }

    @Test
    fun theSlideConfirmsFrom88Percent() {
        assertFalse(slideConfirms(0.879f))
        assertTrue(slideConfirms(0.88f))
        assertEquals(5, waitSecondsLeft(4001L))
        assertEquals(1, waitSecondsLeft(1L))
        assertEquals(0, waitSecondsLeft(0L))
    }

    @Test
    fun theAmbientFadesLinearlyToItsEdge() {
        assertEquals(0.09f, ambientAlphaAt(84f, 120f, 0.30f), 1e-6f)
        assertEquals(0.30f, ambientAlphaAt(0f, 120f, 0.30f), 1e-6f)
        assertEquals(0f, ambientAlphaAt(200f, 120f, 0.30f), 0f)
    }

    @Test
    fun alphaOverCompositesOntoAnOpaqueGround() {
        assertEquals(0xFF808080.toInt(), alphaOver(0x80FFFFFF.toInt(), 0xFF000000.toInt()))
        assertEquals(0xFF123456.toInt(), alphaOver(0xFF123456.toInt(), 0xFFFFFFFF.toInt()))
        assertEquals(0xFF000000.toInt(), alphaOver(0x00FFFFFF, 0xFF000000.toInt()))
    }

    @Test
    fun theWaitingKnobMirrorsConfirmSheet() {
        assertEquals(0x8CFFFFFF.toInt(), DxTheme(dark = false).waitKnob) // knob @ 55 %
        val dark = DxTheme(dark = true)
        assertTrue(contrastRatio(alphaOver(dark.ink2, dark.waitKnob), dark.waitKnob) >= 4.5)
    }
}
