package com.errorxperts.detoxo.overlay.bubble

import org.junit.Assert.assertEquals
import org.junit.Test

class BubbleStyleSpecTest {

    @Test
    fun defaultsOnNullAndEmpty() {
        assertEquals(BubbleStyleSpec(), BubbleStyleSpec.fromJson(null))
        assertEquals(BubbleStyleSpec(), BubbleStyleSpec.fromJson(""))
    }

    @Test
    fun readsTheThreeKeys() {
        val spec = BubbleStyleSpec.fromJson("""{"variant":"RING","size":72,"opacity":0.6}""")
        assertEquals("RING", spec.variant)
        assertEquals(72f, spec.sizeDp, 0.0001f)
        assertEquals(0.6f, spec.opacity, 0.0001f)
    }

    @Test
    fun clamps() {
        assertEquals(80f, BubbleStyleSpec.fromJson("""{"size":999}""").sizeDp, 0.0001f)
        assertEquals(48f, BubbleStyleSpec.fromJson("""{"size":10}""").sizeDp, 0.0001f)
        assertEquals(1f, BubbleStyleSpec.fromJson("""{"opacity":5}""").opacity, 0.0001f)
        assertEquals(0.5f, BubbleStyleSpec.fromJson("""{"opacity":0.1}""").opacity, 0.0001f)
    }

    @Test
    fun legacyAndUnknownVariantsFallBackToMascot() {
        assertEquals(
            BubbleStyleSpec(),
            BubbleStyleSpec.fromJson("""{"variant":"GLASS_ORB","textScale":1.2,"showTime":true}"""),
        )
        assertEquals(BubbleStyleSpec(), BubbleStyleSpec.fromJson("""{"variant":"NOPE"}"""))
    }

    @Test
    fun retiredStylesReadBackAsMascot() {
        for (v in listOf("NEON", "STEPS", "WEATHER", "OUTLINE")) {
            val spec = BubbleStyleSpec.fromJson("""{"variant":"$v","size":72}""")
            assertEquals(v, BubbleStyleSpec.MASCOT, spec.variant)
            assertEquals(v, 72f, spec.sizeDp, 0.0001f)
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
