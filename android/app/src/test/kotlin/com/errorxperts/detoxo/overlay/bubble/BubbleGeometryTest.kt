package com.errorxperts.detoxo.overlay.bubble

import org.junit.Assert.assertEquals
import org.junit.Test

class BubbleGeometryTest {
    private val w = 1080
    private val h = 2000
    private val size = 68f

    @Test fun popRisesTo118AtFortyPercentAndSettles() {
        assertEquals(1f, BubbleGeometry.popScale(0f), 1e-5f)
        assertEquals(1.18f, BubbleGeometry.popScale(0.4f), 1e-5f)
        assertEquals(1.09f, BubbleGeometry.popScale(0.7f), 1e-5f)
        assertEquals(1f, BubbleGeometry.popScale(1f), 1e-5f)
    }

    @Test fun timerFadesInOverTheLastSeventyPercent() {
        assertEquals(0f, BubbleGeometry.timerAlpha(0.3f), 1e-5f)
        assertEquals(0.5f, BubbleGeometry.timerAlpha(0.65f), 1e-5f)
        assertEquals(1f, BubbleGeometry.timerAlpha(1.1f), 1e-5f)
        assertEquals(0f, BubbleGeometry.timerAlpha(-0.1f), 1e-5f)
    }

    @Test fun openTimerStepsOnceASecondAheadOfTheStore() =
        assertEquals(101, BubbleGeometry.nextShownSeconds(shown = 100, watch = 95))

    @Test fun openTimerCatchesUpWithTheStore() =
        assertEquals(130, BubbleGeometry.nextShownSeconds(shown = 100, watch = 130))

    @Test fun openTimerLeadsTheStoreByAtMostTwelveSeconds() {
        assertEquals(112, BubbleGeometry.nextShownSeconds(shown = 111, watch = 100))
        assertEquals(112, BubbleGeometry.nextShownSeconds(shown = 112, watch = 100))
    }

    @Test fun openTimerFollowsAStoreDrop() {
        assertEquals(2, BubbleGeometry.nextShownSeconds(shown = 3600, watch = 2)) // midnight
        // Past the 12 s lead is a drop: the store went down, so follow it.
        assertEquals(100, BubbleGeometry.nextShownSeconds(shown = 113, watch = 100))
    }

    @Test fun unsetAnchorIsTheRightDockAtThirtyPercent() =
        assertEquals(Anchor(1000, 600, true), BubbleGeometry.restoreAnchor(-1, -1, size, w, h, 12f))

    @Test fun storedAnchorIsClampedAndSnappedToItsSide() =
        assertEquals(Anchor(12, 400, false), BubbleGeometry.restoreAnchor(300, 100, size, w, h, 12f))

    @Test fun dropClingsAtZero() =
        assertEquals(Anchor(1012, 600, true), BubbleGeometry.restoreAnchor(1000, 600, size, w, h, 0f))

    @Test fun releaseOffScreenSnapsBackOn() =
        assertEquals(Anchor(12, 1332, false), BubbleGeometry.snap(-50, 1900, size, w, h, 12f))
}
