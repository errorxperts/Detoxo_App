package com.errorxperts.detoxo.overlay.bubble

import com.errorxperts.detoxo.widget.BrandTint
import com.errorxperts.detoxo.widget.WidgetTokens
import com.errorxperts.detoxo.widget.withAlpha
import org.junit.Assert.assertEquals
import org.junit.Test

class BubbleLookTest {

    private fun fields(l: BubbleLook) =
        listOf(l.fillFrom, l.fillTo, l.ring, l.ink, l.faint, l.mark, l.halo, l.shadow)

    @Test
    fun inkPerTier() {
        assertEquals(BrandTint.FALLBACK, BubbleLook.of(0).ink)
        assertEquals(WidgetTokens.WIDGET_INK, BubbleLook.of(3).ink)
        assertEquals(WidgetTokens.WIDGET_INK_INVERSE, BubbleLook.of(4).ink)
    }

    @Test
    fun ringIsTheTierToStop() {
        assertEquals(BrandTint.ramp(BrandTint.FALLBACK, BrandTint.TILE_TO[1]), BubbleLook.of(2).ring)
    }

    @Test
    fun haloIsTheTierToStopAtAlpha2E() {
        assertEquals(withAlpha(BrandTint.ramp(BrandTint.FALLBACK, BrandTint.TILE_TO[0]), 0x2E), BubbleLook.of(1).halo)
    }

    @Test
    fun blendEndsAreTheTwoLooks() {
        val a = BubbleLook.of(1)
        val b = BubbleLook.of(2)
        assertEquals(fields(b), fields(BubbleLook.blend(a, b, 1f)))
        assertEquals(fields(a), fields(BubbleLook.blend(a, b, 0f)))
    }

    @Test
    fun everyTierTakesTheBrandHue() {
        val brand = 0xFF37DFA0.toInt()
        val glass = BubbleLook.of(0, brand)
        assertEquals(BrandTint.at(brand, BrandTint.GLASS_RING), glass.ring)
        assertEquals(BrandTint.at(brand, BrandTint.GLASS_INK), glass.ink)
        assertEquals(withAlpha(BrandTint.at(brand, BrandTint.GLASS_HALO), 0x29), glass.halo)
        assertEquals(BrandTint.FALLBACK, BubbleLook.of(0).ink) // the fallback keeps the old navy
        for (t in 1..5) {
            val look = BubbleLook.of(t, brand)
            assertEquals("tier $t", BrandTint.ramp(brand, BrandTint.TILE_FROM[t - 1]), look.fillFrom)
            assertEquals("tier $t", BrandTint.ramp(brand, BrandTint.TILE_TO[t - 1]), look.fillTo)
        }
    }

    // A string `when` cannot be compiler-exhaustive: pin one distinct face per style token.
    @Test
    fun faceOfCoversEveryStyle() {
        assertEquals(BubbleStyleSpec.ALL.size, BubbleStyleSpec.ALL.map { BubbleFace.of(it) }.toSet().size)
        assertEquals(BubbleFace.of(BubbleStyleSpec.MASCOT), BubbleFace.of("NOPE"))
    }
}
