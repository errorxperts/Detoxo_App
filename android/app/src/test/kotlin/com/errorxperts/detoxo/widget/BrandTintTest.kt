package com.errorxperts.detoxo.widget

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test

/** Runs `brand_tints.json`, the vectors the Dart `BrandTint` test shares. */
class BrandTintTest {
    private val roles = mapOf(
        "glassTo" to BrandTint.GLASS_TO,
        "glassRing" to BrandTint.GLASS_RING,
        "glassInk" to BrandTint.GLASS_INK,
        "glassHalo" to BrandTint.GLASS_HALO,
        "glassShadow" to BrandTint.GLASS_SHADOW,
        "tileLight" to BrandTint.TILE_LIGHT,
        "countLight" to BrandTint.COUNT_LIGHT,
    )

    private fun doubles(a: org.json.JSONArray) = DoubleArray(a.length()) { a.getDouble(it) }

    private fun hexes(a: org.json.JSONArray) = List(a.length()) { Integer.toHexString(a.getLong(it).toInt()) }

    @Test
    fun rolesAndSaturationMatchTheFixture() {
        val f = fixture("brand_tints.json")
        assertEquals(BrandTint.MAX_SATURATION, f.getDouble("maxSaturation"), 0.0)
        val fixed = f.getJSONObject("roles")
        assertEquals(fixed.keys().asSequence().toSet(), roles.keys)
        for ((k, l) in roles) assertEquals(k, fixed.getDouble(k), l, 0.0)
        val ramp = f.getJSONObject("ramp")
        assertArrayEquals(doubles(ramp.getJSONArray("tileFrom")), BrandTint.TILE_FROM, 0.0)
        assertArrayEquals(doubles(ramp.getJSONArray("tileTo")), BrandTint.TILE_TO, 0.0)
        assertArrayEquals(doubles(ramp.getJSONArray("accentDarkY")), BrandTint.ACCENT_DARK_Y, 0.0)
        assertArrayEquals(doubles(ramp.getJSONArray("accentDarkS")), BrandTint.ACCENT_DARK_S, 0.0)
        assertArrayEquals(doubles(ramp.getJSONArray("dotLight")), BrandTint.DOT_LIGHT, 0.0)
    }

    @Test
    fun everyBrandRampsEveryTier() {
        val cases = fixture("brand_tints.json").getJSONArray("cases")
        for (i in 0 until cases.length()) {
            val c = cases.getJSONObject(i)
            val brand = c.getLong("brand").toInt()
            val want = c.getJSONObject("ramp")
            fun got(ys: DoubleArray) = ys.map { Integer.toHexString(BrandTint.ramp(brand, it)) }
            val hex = c.getString("hex")
            assertEquals("$hex.tileFrom", hexes(want.getJSONArray("tileFrom")), got(BrandTint.TILE_FROM))
            assertEquals("$hex.tileTo", hexes(want.getJSONArray("tileTo")), got(BrandTint.TILE_TO))
            assertEquals(
                "$hex.accentDark",
                hexes(want.getJSONArray("accentDark")),
                List(6) { Integer.toHexString(BrandTint.ramp(brand, BrandTint.ACCENT_DARK_Y[it], BrandTint.ACCENT_DARK_S[it])) },
            )
            assertEquals("$hex.dotLight", hexes(want.getJSONArray("dotLight")), got(BrandTint.DOT_LIGHT))
        }
    }

    @Test
    fun everyBrandTintsEveryRole() {
        val cases = fixture("brand_tints.json").getJSONArray("cases")
        for (i in 0 until cases.length()) {
            val c = cases.getJSONObject(i)
            val brand = c.getLong("brand").toInt()
            val tints = c.getJSONObject("tints")
            for ((k, l) in roles) {
                val want = tints.getLong(k).toInt()
                assertEquals("${c.getString("hex")}.$k", Integer.toHexString(want), Integer.toHexString(BrandTint.at(brand, l)))
            }
        }
    }
}
