package com.errorxperts.detoxo.overlay.bubble

import org.junit.Assert.assertEquals
import org.junit.Test

class BubbleStyleSpecTest {

    @Test
    fun defaultsOnNullAndEmpty() {
        assertEquals(BubbleStyleSpec(BubbleStyleSpec.RING, 38.4f, 1f), BubbleStyleSpec())
        assertEquals(BubbleStyleSpec(), BubbleStyleSpec.fromJson(null))
        assertEquals(BubbleStyleSpec(), BubbleStyleSpec.fromJson(""))
    }

    @Test
    fun readsTheThreeKeys() {
        val spec = BubbleStyleSpec.fromJson("""{"variant":"RING","size":60,"opacity":0.6}""")
        assertEquals("RING", spec.variant)
        assertEquals(60f, spec.sizeDp, 0.0001f)
        assertEquals(0.6f, spec.opacity, 0.0001f)
    }

    @Test
    fun clamps() {
        assertEquals(64f, BubbleStyleSpec.fromJson("""{"size":999}""").sizeDp, 0.0001f)
        assertEquals(38.4f, BubbleStyleSpec.fromJson("""{"size":10}""").sizeDp, 0.0001f)
        assertEquals(1f, BubbleStyleSpec.fromJson("""{"opacity":5}""").opacity, 0.0001f)
        assertEquals(0.5f, BubbleStyleSpec.fromJson("""{"opacity":0.1}""").opacity, 0.0001f)
    }

    @Test
    fun legacyAndUnknownVariantsFallBackToRing() {
        assertEquals(
            BubbleStyleSpec(),
            BubbleStyleSpec.fromJson("""{"variant":"GLASS_ORB","textScale":1.2,"showTime":true}"""),
        )
        assertEquals(BubbleStyleSpec(), BubbleStyleSpec.fromJson("""{"variant":"NOPE"}"""))
    }

    @Test
    fun retiredStylesReadBackAsRing() {
        for (v in listOf("NEON", "STEPS", "WEATHER", "OUTLINE")) {
            val spec = BubbleStyleSpec.fromJson("""{"variant":"$v","size":60}""")
            assertEquals(v, BubbleStyleSpec.RING, spec.variant)
            assertEquals(v, 60f, spec.sizeDp, 0.0001f)
        }
    }

    @Test
    fun wrongTypesAreDefaults() {
        assertEquals(BubbleStyleSpec(), BubbleStyleSpec.fromJson("""{"size":"big","opacity":[1]}"""))
    }

    @Test
    fun garbageJsonIsDefaults() {
        assertEquals(BubbleStyleSpec(), BubbleStyleSpec.fromJson("not json"))
    }
}
