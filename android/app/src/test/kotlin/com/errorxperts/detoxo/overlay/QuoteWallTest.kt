package com.errorxperts.detoxo.overlay

import com.errorxperts.detoxo.widget.repoFile
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** The Quotes wall's motion and fit maths — the parts that are pure. */
class QuoteWallTest {

    private val linear: (Float) -> Float = { it }

    @Test
    fun theCardRestsFlipsFaceDownAndComesHome() {
        assertEquals(0f, flipDegrees(0.15f, linear), 0.01f)
        assertEquals(90f, flipDegrees(0.36f, linear), 0.01f)
        assertEquals(180f, flipDegrees(0.60f, linear), 0.01f)
        assertEquals(270f, flipDegrees(0.88f, linear), 0.01f)
        assertEquals(360f, flipDegrees(0.97f, linear), 0.01f)
    }

    @Test
    fun theShadowFollowsHowFarTheCardHasTurned() {
        assertEquals(0f, turnedAway(0f), 1e-4f)
        assertEquals(0.5f, turnedAway(90f), 1e-4f)
        assertEquals(1f, turnedAway(180f), 1e-4f)
        assertEquals(0f, turnedAway(360f), 1e-4f)
    }

    @Test
    fun theIdleLightStartsCentredAndNeverLeavesTheWall() {
        assertEquals(195f, lissajousX(0f, 390f), 1e-3f)
        assertEquals(0.47f * 844f, lissajousY(0f, 844f), 1e-3f)
        var t = 0f
        while (t < 120f) {
            assertTrue(lissajousX(t, 390f) in 0.18f * 390f..0.82f * 390f)
            assertTrue(lissajousY(t, 844f) in 0.22f * 844f..0.72f * 844f)
            t += 0.05f
        }
    }

    @Test
    fun thePhoneShrinksToHalfThenHides() {
        assertEquals(1f, phoneScale(400f, 320f), 1e-4f)
        assertEquals(0.75f, phoneScale(240f, 320f), 1e-4f)
        assertEquals(0.5f, phoneScale(160f, 320f), 1e-4f)
        assertEquals(0f, phoneScale(150f, 320f), 1e-4f)
        assertEquals(0f, phoneScale(-10f, 320f), 1e-4f)
    }

    @Test
    fun theLogoCropHoldsTheWholeVisibleLogo() {
        // The wall draws `assets/images/Detoxo_logo.png` cropped to LOGO_CROP;
        // a reframed asset must not lose its edges to a stale crop.
        // javax.imageio is on the host JVM but not in android.jar: reached reflectively.
        val img = Class.forName("javax.imageio.ImageIO").getMethod("read", File::class.java)
            .invoke(null, repoFile("assets/images/Detoxo_logo.png"))!!
        val w = img.javaClass.getMethod("getWidth").invoke(img) as Int
        val h = img.javaClass.getMethod("getHeight").invoke(img) as Int
        val int = Int::class.javaPrimitiveType!!
        val argb = img.javaClass
            .getMethod("getRGB", int, int, int, int, IntArray::class.java, int, int)
            .invoke(img, 0, 0, w, h, null, 0, w) as IntArray
        var l = w
        var t = h
        var r = -1
        var b = -1
        for (y in 0 until h) {
            for (x in 0 until w) {
                if ((argb[y * w + x] ushr 24) >= 32) {
                    if (x < l) l = x
                    if (x > r) r = x
                    if (y < t) t = y
                    if (y > b) b = y
                }
            }
        }
        assertTrue("no visible logo", r >= 0)
        assertTrue(l >= LOGO_CROP[0] * w && t >= LOGO_CROP[1] * h)
        assertTrue(r <= LOGO_CROP[2] * w && b <= LOGO_CROP[3] * h)
    }
}
