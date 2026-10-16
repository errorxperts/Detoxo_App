package com.errorxperts.detoxo.overlay.bubble

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BubbleEnvelopeTest {
    private val d = 1f
    private val size = 68f
    private fun st(
        bodyW: Float = 68f,
        pulsing: Boolean = false,
        pill: Boolean = false,
    ) = EnvelopeState(bodyW, 68f, pulsing, pill)

    private fun assertOutsets(l: Float, t: Float, r: Float, b: Float, o: Outsets) {
        assertEquals(l, o.left, 1e-4f)
        assertEquals(t, o.top, 1e-4f)
        assertEquals(r, o.right, 1e-4f)
        assertEquals(b, o.bottom, 1e-4f)
    }

    @Test fun collapsedOutsetsAreTheGlow() =
        assertOutsets(12f, 12f, 12f, 12f, BubbleEnvelope.outsets(st(), d))

    @Test fun pulsingAddsTheHalo() =
        assertOutsets(36f, 36f, 36f, 36f, BubbleEnvelope.outsets(st(pulsing = true), d))

    @Test fun thePillAddsItsZoneOnTop() =
        assertOutsets(12f, 48f, 12f, 12f, BubbleEnvelope.outsets(st(pill = true), d))

    @Test fun rightDockCollapsed() =
        assertEquals(WindowBox(308, 288, 92, 92, 12f, 12f), BubbleEnvelope.window(320, 300, size, true, st(), d))

    @Test fun rightDockGrowsInward() {
        val w = BubbleEnvelope.window(320, 300, size, true, st(bodyW = 156f), d)
        assertEquals(220, w.x)
        assertEquals(180, w.w)
        assertEquals(12f, w.bodyLeft, 1e-4f)
        assertEquals(388f, w.x + w.bodyLeft + 156f, 1e-4f)
    }

    @Test fun leftDockGrowsOutward() {
        val w = BubbleEnvelope.window(12, 300, size, false, st(bodyW = 156f), d)
        assertEquals(0, w.x)
        assertEquals(180, w.w)
    }

    @Test fun everythingAtOnceStaysAnchored() {
        val s = st(bodyW = 156f, pulsing = true, pill = true)
        assertOutsets(36f, 72f, 36f, 36f, BubbleEnvelope.outsets(s, d))
        val w = BubbleEnvelope.window(320, 300, size, true, s, d)
        assertEquals(196, w.x)
        assertEquals(228, w.y)
        assertEquals(228, w.w)
        assertEquals(176, w.h)
        assertEquals(388f, w.x + w.bodyLeft + 156f, 1e-4f)
        assertEquals(300f, w.y + w.bodyTop, 1e-4f)
    }

    @Test fun dockedRightByTheAnchorCentre() {
        assertTrue(BubbleEnvelope.dockedRight(320, size, 400))
        assertFalse(BubbleEnvelope.dockedRight(12, size, 400))
        assertTrue(BubbleEnvelope.dockedRight(166, size, 400))
    }

    @Test fun snapX() {
        assertEquals(332, BubbleEnvelope.snapX(size, 400, 0f, true))
        assertEquals(0, BubbleEnvelope.snapX(size, 400, 0f, false))
        assertEquals(320, BubbleEnvelope.snapX(size, 400, 12f, true))
        assertEquals(12, BubbleEnvelope.snapX(size, 400, 12f, false))
    }

    @Test fun clampAnchor() {
        assertEquals(12 to 160, BubbleEnvelope.clampAnchor(-50, 10, size, 400, 800, 12f))
        assertEquals(320 to 492, BubbleEnvelope.clampAnchor(390, 790, size, 400, 800, 12f))
        assertEquals(100 to 300, BubbleEnvelope.clampAnchor(100, 300, size, 400, 800, 12f))
    }

    @Test fun clampAnchorNarrowScreenDoesNotThrow() =
        assertEquals(12 to 300, BubbleEnvelope.clampAnchor(50, 300, size, 80, 800, 12f))

    @Test fun clampAnchorShortScreenDoesNotThrow() =
        assertEquals(100 to 20, BubbleEnvelope.clampAnchor(100, 50, size, 400, 100, 12f))
}
