package com.errorxperts.detoxo.widget

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pins [WidgetSize.of] on launcher cells from the Android sizing formula
 * (`n` columns × `m` rows ≈ (a·n − 16) × (b·m − 16) dp, portrait). Each
 * expectation is derived from the rule: MEDIUM if w ≥ 1.15·h, else LARGE if
 * w ≥ 0.55·screenShort, else SMALL.
 */
class WidgetSizeTest {

    private fun cell(cols: Int, rows: Int, colDp: Int, rowDp: Int, screenShortDp: Int) =
        WidgetSize.of(colDp * cols - 16, rowDp * rows - 16, screenShortDp)

    @Test
    fun aPortrait411dpPhone() {
        // 73n−16 × 118m−16; LARGE needs w ≥ 226.05.
        fun phone(cols: Int, rows: Int) = cell(cols, rows, 73, 118, 411)
        assertEquals(WidgetSize.SMALL, phone(2, 2)) // 130 × 220
        assertEquals(WidgetSize.SMALL, phone(3, 2)) // 203 × 220: not wide (< 253), < 226
        assertEquals(WidgetSize.MEDIUM, phone(4, 2)) // 276 × 220: 276 ≥ 253
        assertEquals(WidgetSize.MEDIUM, phone(5, 2)) // 349 × 220
        assertEquals(WidgetSize.SMALL, phone(3, 3)) // 203 × 338
        assertEquals(WidgetSize.LARGE, phone(4, 4)) // 276 × 456: 276 ≥ 226
        assertEquals(WidgetSize.SMALL, phone(2, 4)) // 130 × 456
    }

    @Test
    fun aFourColumnGrid() {
        // 92n−16 × 125m−16 on the same 411 dp screen.
        fun grid(cols: Int, rows: Int) = cell(cols, rows, 92, 125, 411)
        assertEquals(WidgetSize.SMALL, grid(2, 2)) // 168 × 234
        assertEquals(WidgetSize.MEDIUM, grid(4, 2)) // 352 × 234: 352 ≥ 269.1
        assertEquals(WidgetSize.LARGE, grid(3, 3)) // 260 × 359: 260 ≥ 226.05
        assertEquals(WidgetSize.LARGE, grid(4, 4)) // 352 × 484
    }

    @Test
    fun aFiveColumn360dpPhone() {
        // 72n−16 × 118m−16; LARGE needs w ≥ 198.
        fun phone(cols: Int, rows: Int) = cell(cols, rows, 72, 118, 360)
        assertEquals(WidgetSize.SMALL, phone(2, 2)) // 128 × 220
        assertEquals(WidgetSize.MEDIUM, phone(4, 2)) // 272 × 220: 272 ≥ 253
        assertEquals(WidgetSize.MEDIUM, phone(5, 2)) // 344 × 220
        assertEquals(WidgetSize.LARGE, phone(3, 3)) // 200 × 338: 200 ≥ 198
        assertEquals(WidgetSize.LARGE, phone(4, 4)) // 272 × 456
    }

    @Test
    fun anUnreportedSizeIsSmallAndThresholdsAreInclusive() {
        assertEquals(WidgetSize.SMALL, WidgetSize.of(0, 0, 411))
        assertEquals(WidgetSize.MEDIUM, WidgetSize.of(115, 100, 411)) // exactly 1.15·h
        assertEquals(WidgetSize.SMALL, WidgetSize.of(114, 100, 411))
        assertEquals(WidgetSize.LARGE, WidgetSize.of(220, 400, 400)) // exactly 0.55·short
        assertEquals(WidgetSize.SMALL, WidgetSize.of(219, 400, 400))
    }

    @Test
    fun wireTokensRoundTrip() {
        for (size in WidgetSize.entries) assertEquals(size, WidgetSize.fromWire(size.wire))
        for (family in WidgetFamily.entries) assertEquals(family, WidgetFamily.fromWire(family.wire))
        assertEquals(null, WidgetSize.fromWire("HUGE"))
        assertEquals(null, WidgetFamily.fromWire(null))
        assertEquals(
            listOf("COUNT", "NEXT_COLOUR", "TIME_LIMIT", "RHYTHM", "BONSAI", "BENTO", "PLAN"),
            WidgetFamily.entries.map { it.wire },
        )
        assertEquals(
            listOf(160f to 160f, 340f to 160f, 340f to 340f),
            WidgetSize.entries.map { it.designWidth to it.designHeight },
        )
    }
}
