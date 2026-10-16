package com.errorxperts.detoxo.widget.faces

import com.errorxperts.detoxo.widget.Align
import com.errorxperts.detoxo.widget.ROW_GAP
import com.errorxperts.detoxo.widget.WidgetFace
import com.errorxperts.detoxo.widget.WidgetModel
import com.errorxperts.detoxo.widget.WidgetPainter
import com.errorxperts.detoxo.widget.WidgetSize
import com.errorxperts.detoxo.widget.WidgetTokens
import com.errorxperts.detoxo.widget.cnt

/** 1 · Count (Library L107–138): today's reels on the tier tile, watch time in the band. */
internal object CountFace : WidgetFace {

    private val S = cnt(WidgetTokens.COUNT_S, -2.5f)
    private val M = cnt(WidgetTokens.COUNT_M, -3f)
    private val L = cnt(WidgetTokens.COUNT_L, -5f)

    override fun draw(p: WidgetPainter, size: WidgetSize, m: WidgetModel) {
        val ink = p.tierTile(size, m.tier)
        when (size) {
            WidgetSize.SMALL -> p.text(m.countText, 18f, 20f, S, ink.count, maxWidth = p.w - 36f)
            WidgetSize.MEDIUM -> {
                val chip = p.chip(m.tierChip, p.w - 24f, 26f, ink, Align.END)
                p.text(m.countText, 30f, 22f, M, ink.count, maxWidth = chip - ROW_GAP - 30f)
            }
            WidgetSize.LARGE -> {
                val chip = p.chip(m.tierChip, p.w - 30f, 40f, ink, Align.END)
                p.text(m.countText, 30f, 40f, L, ink.count, maxWidth = chip - ROW_GAP - 30f)
            }
        }
        val label = if (size == WidgetSize.SMALL) m.todayShort else m.todayLong
        p.band(size, m.note ?: label, m.time, clock = true, ink)
    }
}
