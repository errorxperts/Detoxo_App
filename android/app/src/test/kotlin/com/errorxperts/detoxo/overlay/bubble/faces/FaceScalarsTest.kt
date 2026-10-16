package com.errorxperts.detoxo.overlay.bubble.faces

import android.graphics.RectF
import com.errorxperts.detoxo.overlay.bubble.BubbleFace
import com.errorxperts.detoxo.overlay.bubble.BubbleFrame
import com.errorxperts.detoxo.overlay.bubble.BubbleLook
import com.errorxperts.detoxo.overlay.bubble.BubbleStyleSpec
import com.errorxperts.detoxo.overlay.bubble.BubbleTokens
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test

/** Pins the scalar table of the six faces (spec §6.2); no Canvas. */
class FaceScalarsTest {
    private class Row(
        val face: BubbleFace,
        val token: String,
        val countSize: Float = 24f,
        val timerPaddingLeft: Float = 15f,
        val edgeDp: Float = 12f,
        val shellCount: Boolean = true,
        val loopsClosed: Boolean = false,
        val loopsOpen: Boolean = false,
        val loopPeriodMs: Int = 0,
        val countGlow: Float = 0f,
        val timerGrain: Boolean = false,
        val radiusEdge: Float = 34f,
    )

    private val rows = listOf(
        Row(MascotFace, BubbleStyleSpec.MASCOT, shellCount = false),
        Row(RingFace, BubbleStyleSpec.RING, countSize = 22f, timerPaddingLeft = 72f),
        Row(
            LiquidFace, BubbleStyleSpec.LIQUID,
            loopsClosed = true, loopsOpen = true, loopPeriodMs = BubbleTokens.MS_WAVE,
        ),
        Row(
            HourglassFace, BubbleStyleSpec.HOURGLASS,
            countSize = 20f, timerPaddingLeft = 70f, loopsOpen = true, loopPeriodMs = BubbleTokens.MS_SAND,
            countGlow = 8f, timerGrain = true,
        ),
        Row(BezelFace, BubbleStyleSpec.BEZEL, countSize = 21f, timerPaddingLeft = 70f),
        Row(
            DropFace, BubbleStyleSpec.DROP,
            edgeDp = 0f, loopsClosed = true, loopsOpen = true, loopPeriodMs = BubbleTokens.MS_BREATH, radiusEdge = 10f,
        ),
    )

    @Test
    fun scalarsMatchTheTable() {
        for (r in rows) {
            val n = r.token
            val f = r.face
            assertEquals("$n countSize", r.countSize, f.countSize, 0f)
            assertEquals("$n timerPaddingLeft", r.timerPaddingLeft, f.timerPaddingLeft, 0f)
            assertEquals("$n edgeDp", r.edgeDp, f.edgeDp, 0f)
            assertEquals("$n shellCount", r.shellCount, f.shellCount)
            assertEquals("$n loops(false)", r.loopsClosed, f.loops(false))
            assertEquals("$n loops(true)", r.loopsOpen, f.loops(true))
            assertEquals("$n loopPeriodMs", r.loopPeriodMs, f.loopPeriodMs)
            assertEquals("$n countGlow", r.countGlow, f.countGlow, 0f)
            assertEquals("$n timerGrain", r.timerGrain, f.timerGrain)
            assertEquals("$n radiusEdge", r.radiusEdge, f.radiusEdge, 0f)
        }
    }

    @Test
    fun ofReturnsTheMatchingFaceForEveryToken() {
        assertEquals(BubbleStyleSpec.ALL.size, rows.size)
        for (r in rows) assertSame(r.token, r.face, BubbleFace.of(r.token))
        assertEquals(BubbleStyleSpec.ALL.toSet(), rows.map { it.token }.toSet())
    }

    private fun frame(tier: Int, pct: Int) = BubbleFrame(
        body = RectF(), s = 1f, look = BubbleLook.of(tier), tier = tier, prevTier = tier, blend = 1f,
        count = 0, pct = pct, countText = "", clock = "", shortTime = "", expand = 0f, pop = 0f,
        pulse = 0f, pill = 0f, loopT = 0f, open = false, dockedRight = true,
    )

    @Test
    fun liquidInk() {
        assertEquals(WHITE, LiquidFace.countColor(frame(4, 60)))
        assertEquals(BubbleTokens.PILL_INK, LiquidFace.countColor(frame(2, 60)))
        assertEquals(BubbleTokens.PILL_INK, LiquidFace.countColor(frame(4, 55)))
        assertEquals(0x80FFFFFF.toInt(), LiquidFace.markFill(BubbleLook.of(0)))
    }

    private companion object {
        const val WHITE = 0xFFFFFFFF.toInt()
    }
}
