package com.errorxperts.detoxo.widget.faces

import com.errorxperts.detoxo.widget.Align
import com.errorxperts.detoxo.widget.Ink
import com.errorxperts.detoxo.widget.LBL_S
import com.errorxperts.detoxo.widget.VAL
import com.errorxperts.detoxo.widget.VAL_S
import com.errorxperts.detoxo.widget.WidgetFace
import com.errorxperts.detoxo.widget.WidgetModel
import com.errorxperts.detoxo.widget.WidgetPainter
import com.errorxperts.detoxo.widget.WidgetSize
import com.errorxperts.detoxo.widget.WidgetTokens

/**
 * 5 · Bonsai (Library L299–409): a living tree on a neutral tile, losing a
 * stage every 100 reels from Blooming to Leafless.
 */
internal object BonsaiFace : WidgetFace {

    // The M panel's column: lblS 16 + 6 + val 26 + 6 + health bar 6 + 6 + valS 18.
    private const val PANEL_COLUMN = 84f

    override fun draw(p: WidgetPainter, size: WidgetSize, m: WidgetModel) {
        val ink = Ink.bonsai(m.tier, p.dark, p.brand)
        p.tile(size, if (p.dark) WidgetTokens.BONSAI_BG_DARK else WidgetTokens.BONSAI_BG_LIGHT, ink.hairline)
        // The tree is a centred item: a taller box keeps it in the middle.
        val dy = (p.h - size.designHeight) / 2f
        when (size) {
            WidgetSize.SMALL -> {
                p.tree((p.w - 112f) / 2f, 2f + dy, 112f, m.tier)
                p.band(size, m.note ?: m.bonsaiStage, m.countText, clock = false, ink)
            }
            WidgetSize.MEDIUM -> {
                p.tree(8f, 4f + dy, 148f, m.tier)
                val top = p.panel(160f, 18f, p.w - 18f, p.h - 18f, ink.band, PANEL_COLUMN)
                val room = p.w - 210f // the panel's width inside its 16-unit padding
                p.text(m.note ?: m.stageHealth, 176f, top, LBL_S, ink.muted, maxWidth = room)
                p.text(m.reelsChip, 176f, top + 22f, VAL, ink.ink, maxWidth = room)
                p.rect(176f, top + 54f, 176f + room, top + 60f, 3f, ink.faint)
                if (m.bonsaiHealth > 0) {
                    p.rect(176f, top + 54f, 176f + room * m.bonsaiHealth / 100f, top + 60f, 3f, ink.fill)
                }
                p.valueLine(m.time, 176f, top + 66f, VAL_S, ink.ink, clock = true, Align.START, maxWidth = room)
            }
            WidgetSize.LARGE -> {
                p.chip(m.reelsChip, 30f, 30f, ink)
                p.tree((p.w - 236f) / 2f, 10f + dy, 236f, m.tier)
                p.band(size, m.note ?: m.stageHealth, m.time, clock = true, ink)
            }
        }
    }
}
