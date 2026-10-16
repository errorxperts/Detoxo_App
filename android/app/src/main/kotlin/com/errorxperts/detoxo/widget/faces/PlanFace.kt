package com.errorxperts.detoxo.widget.faces

import com.errorxperts.detoxo.widget.Align
import com.errorxperts.detoxo.widget.Ink
import com.errorxperts.detoxo.widget.ROW_GAP
import com.errorxperts.detoxo.widget.WidgetFace
import com.errorxperts.detoxo.widget.WidgetModel
import com.errorxperts.detoxo.widget.WidgetPainter
import com.errorxperts.detoxo.widget.WidgetSize
import com.errorxperts.detoxo.widget.WidgetTokens
import com.errorxperts.detoxo.widget.cnt

/**
 * 7 · Plan (EVO-073): whether blocking is on and which plan runs, on Bento's
 * neutral shell — no tier, no accent colour (DS-02). The ring is protection in
 * force: full for Block All and Conscious, filling as a One Reel / Unblock
 * allowance is spent, empty while paused or off. Dart `PlanFace` draws the same.
 */
internal object PlanFace : WidgetFace {

    private val S = cnt(30f, -1f)
    private val M = cnt(48f, -1.8f)
    private val L = cnt(64f, -2.5f)
    private val HOLE = cnt(30f, -1f)

    // Medium's ring: its outer edge (r 24 + stroke 9 / 2) at right 30.
    private const val M_RING_X = 58.5f
    private const val M_TITLE_END = M_RING_X + 28.5f + ROW_GAP

    override fun draw(p: WidgetPainter, size: WidgetSize, m: WidgetModel) {
        val ink = Ink.bento(0, p.dark, p.brand)
        p.tile(size, if (p.dark) WidgetTokens.BENTO_SHELL_DARK else WidgetTokens.BENTO_SHELL_LIGHT, ink.hairline)
        when (size) {
            WidgetSize.SMALL -> {
                p.text(m.planTitle, 18f, 20f, S, ink.ink, maxWidth = p.w - 36f)
                // Bottom-right, 8 clear of the band.
                p.ring(p.w - 39.5f, p.h - WidgetTokens.BAND_S - 29.5f, 18f, 7f, m.planRingPct, ink.faint, ink.ink)
            }
            WidgetSize.MEDIUM -> {
                p.ring(p.w - M_RING_X, (p.h - WidgetTokens.BAND_M) / 2f, 24f, 9f, m.planRingPct, ink.faint, ink.ink)
                p.text(m.planTitle, 30f, 20f, M, ink.ink, maxWidth = p.w - M_TITLE_END - 30f)
            }
            WidgetSize.LARGE -> {
                p.text(m.planTitle, 30f, 40f, L, ink.ink, maxWidth = p.w - 60f)
                // Centred between the title's line box (40..104) and the band.
                val cy = (104f + p.h - WidgetTokens.BAND_L) / 2f
                p.ring(p.w / 2f, cy, 52f, 14f, m.planRingPct, ink.faint, ink.ink)
                p.text(m.planRingText, p.w / 2f, cy - HOLE.lineHeight / 2f, HOLE, ink.ink, Align.CENTER, maxWidth = 90f)
            }
        }
        val small = size == WidgetSize.SMALL
        p.band(
            size,
            if (small) m.planLabelShort else m.planLabelLong,
            if (small) m.planValueShort else m.planValueLong,
            clock = m.planClock && !small,
            ink,
        )
    }
}
