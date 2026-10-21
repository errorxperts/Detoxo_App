package com.errorxperts.detoxo.engine

import com.errorxperts.detoxo.widget.repoFile
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** `homeTabId` — where "Back to {app}" on a wall lands — parsed from the real bundled config. */
class DetectionConfigTest {

    private val bundled by lazy {
        DetectionConfig.parse(repoFile("assets/config/platforms_config.json").readText())
    }

    private fun rule(pkg: String, id: String): PlatformRule =
        bundled.platformsFor(pkg).first { it.platformId == id }

    @Test
    fun instagramWallSurfacesNameTheirHomeTab() {
        for (id in listOf("ig_reel", "ig_reel_by_friend", "ig_stories")) {
            assertEquals(id, "com.instagram.android:id/feed_tab", rule("com.instagram.android", id).homeTabId)
        }
    }

    @Test
    fun surfacesWithoutOneKeepTheOldExit() {
        // The feed is itself blockable: Back from a feed wall just closes.
        assertNull(rule("com.instagram.android", "ig_feed").homeTabId)
        assertNull(rule("com.google.android.youtube", "yt_shorts").homeTabId)
    }

    @Test
    fun aQualifiedIdIsKeptVerbatim() {
        val c = DetectionConfig.parse(
            """{"featuredApps":{"a.b":{"packageName":"a.b","platforms":[{"platformId":"x","homeTabId":"c.d:id/home"}]}}}""",
        )
        assertEquals("c.d:id/home", c.platformsFor("a.b").single().homeTabId)
    }
}
