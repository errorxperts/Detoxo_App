package com.errorxperts.detoxo.widget

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins the renderer's pure geometry: how a face fits a launcher cell, the
 * CSS 135° gradient line, text shrink and the tier palette's inversion. The
 * drawing itself needs a device — compare against the Library board's tiles
 * there.
 */
class WidgetGeometryTest {

    private fun fit(cellW: Int, cellH: Int, size: WidgetSize) =
        WidgetBitmapRenderer.fitBox(cellW, cellH, size.designWidth, size.designHeight)

    @Test
    fun aCellOfTheDesignShapeFitsExactly() {
        assertEquals(Fit(320, 320, 2f, 0f, 0f, 160f, 160f), fit(320, 320, WidgetSize.SMALL))
        assertEquals(Fit(680, 320, 2f, 0f, 0f, 340f, 160f), fit(680, 320, WidgetSize.MEDIUM))
    }

    @Test
    fun aTallerCellStretchesTheFaceUpTo1point8() {
        // s = 1.25: 300 px tall is 240 units, within 1.8 × 160.
        assertEquals(Fit(200, 300, 1.25f, 0f, 0f, 160f, 240f), fit(200, 300, WidgetSize.SMALL))
        // A portrait 4×4 (276 × 456 dp at 1 px/dp): Large lays out 340 wide, 561.7 tall.
        val large = fit(276, 456, WidgetSize.LARGE)
        assertEquals(340f, large.faceW, 1e-3f)
        assertEquals(456f / (276f / 340f), large.faceH, 1e-3f)
    }

    @Test
    fun pastTheCapsTheFaceIsLetterboxedAndCentred() {
        // Vertical cap: 160 × 1.25 × 1.8 = 360 px of 400; 20 px above and below.
        assertEquals(Fit(200, 400, 1.25f, 0f, 20f, 160f, 288f), fit(200, 400, WidgetSize.SMALL))
        // Horizontal cap: 160 × 1.25 × 1.25 = 250 px of 400; 75 px each side.
        assertEquals(Fit(400, 200, 1.25f, 75f, 0f, 200f, 160f), fit(400, 200, WidgetSize.SMALL))
    }

    @Test
    fun theBitmapsLongSideIsClampedTo1200() {
        val medium = fit(2400, 1200, WidgetSize.MEDIUM)
        assertEquals(1200, medium.bitmapW)
        assertEquals(600, medium.bitmapH)
        assertEquals(1200f / 340f, medium.scale, 1e-4f)
        assertEquals(340f, medium.faceW, 1e-3f)
        assertEquals(170f, medium.faceH, 1e-3f)
    }

    @Test
    fun anUnreportedCellStillDraws() {
        val none = fit(0, 0, WidgetSize.SMALL)
        assertEquals(1, none.bitmapW)
        assertEquals(1, none.bitmapH)
        assertEquals(160f, none.faceW, 1e-3f)
    }

    @Test
    fun the135DegreeGradientRunsLikeCss() {
        // The gradient line is (w + h)·sin 45° long through the centre, so its
        // ends sit (w + h) / 4 off the centre on each axis.
        assertArrayEquals(floatArrayOf(0f, 0f, 160f, 160f), gradient135(0f, 0f, 160f, 160f), 1e-4f)
        assertArrayEquals(floatArrayOf(45f, -45f, 295f, 205f), gradient135(0f, 0f, 340f, 160f), 1e-4f)
        // Bento Medium's count module, offset from the origin.
        assertArrayEquals(floatArrayOf(18.5f, -2.5f, 183.5f, 162.5f), gradient135(8f, 8f, 194f, 152f), 1e-4f)
    }

    @Test
    fun textShrinksOnlyWhenTooWide() {
        assertEquals(1f, fitScale(100f, 120f), 0f)
        assertEquals(1f, fitScale(0f, 0f), 0f)
        assertEquals(0.8f, fitScale(150f, 120f), 1e-6f)
        assertEquals(0f, fitScale(10f, -5f), 0f)
    }

    @Test
    fun lightTierTilesInvertFromTier4() {
        val brand = 0xFF8B93FF.toInt()
        val empty = Ink.tier(0, dark = false, brand)
        assertEquals(BrandTint.at(brand, BrandTint.COUNT_LIGHT), empty.count)
        assertEquals(WidgetTokens.HAIRLINE_EMPTY, empty.hairline)
        val three = Ink.tier(3, dark = false, brand)
        assertEquals(WidgetTokens.WIDGET_INK, three.count)
        assertEquals(WidgetTokens.WIDGET_INK_MUTED, three.muted)
        assertEquals(WidgetTokens.BAND_LIGHT, three.band)
        assertEquals(0, three.hairline)
        val four = Ink.tier(4, dark = false, brand)
        assertEquals(WidgetTokens.WIDGET_INK_INVERSE, four.muted)
        assertEquals(WidgetTokens.BAND_DARK, four.band)
        assertEquals(WidgetTokens.FAINT_INVERSE, four.faint)
        // Dark: the count and fills take the tier accent on every tier.
        val dark = Ink.tier(2, dark = true, brand)
        val accent = BrandTint.ramp(brand, BrandTint.ACCENT_DARK_Y[2], BrandTint.ACCENT_DARK_S[2])
        assertEquals(accent, dark.count)
        assertEquals(accent, dark.fill)
        assertEquals(WidgetTokens.DARK_HAIRLINE, dark.hairline)
    }

    @Test
    fun everyTierTakesTheBrandRamp() {
        val brand = 0xFF37DFA0.toInt()
        for (t in 0..5) {
            val accent = BrandTint.ramp(brand, BrandTint.ACCENT_DARK_Y[t], BrandTint.ACCENT_DARK_S[t])
            val dot = BrandTint.ramp(brand, BrandTint.DOT_LIGHT[t])
            assertEquals("tier $t", accent, Ink.tier(t, dark = true, brand).count)
            assertEquals("tier $t", accent, Ink.darkAccent(t, brand))
            assertEquals("tier $t", dot, Ink.bento(t, dark = false, brand).fill)
            assertEquals("tier $t", accent, Ink.bento(t, dark = true, brand).fill)
            assertEquals("tier $t bar", dot, Ink.bonsai(t, dark = false, brand).fill)
        }
    }
}
