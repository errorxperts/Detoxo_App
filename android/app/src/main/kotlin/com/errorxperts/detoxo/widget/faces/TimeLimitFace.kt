package com.errorxperts.detoxo.widget.faces

import com.errorxperts.detoxo.widget.Align
import com.errorxperts.detoxo.widget.ROW_GAP
import com.errorxperts.detoxo.widget.WidgetFace
import com.errorxperts.detoxo.widget.WidgetModel
import com.errorxperts.detoxo.widget.WidgetPainter
import com.errorxperts.detoxo.widget.WidgetSize
import com.errorxperts.detoxo.widget.cnt

/** 3 · Time limit (Library L199–239): watch time left in today's limit, in twelve segments. */
internal object TimeLimitFace : WidgetFace {

    private val S = cnt(40f, -1.5f)
    private val M = cnt(48f, -1.8f)
    private val L = cnt(88f, -3.5f)

    override fun draw(p: WidgetPainter, size: WidgetSize, m: WidgetModel) {
        val ink = p.tierTile(size, m.tier)
        when (size) {
            WidgetSize.SMALL -> {
                p.text(m.leftBig, 18f, 20f, S, ink.count, maxWidth = p.w - 36f)
                p.segments(18f, 76f, p.w - 18f, 88f, 3f, 3f, m.segmentsOn, ink)
            }
            WidgetSize.MEDIUM -> {
                val chip = p.chip(m.reelsChip, p.w - 24f, 26f, ink, Align.END)
                p.text(m.leftBig, 30f, 20f, M, ink.count, maxWidth = chip - ROW_GAP - 30f)
                p.segments(30f, 82f, p.w - 30f, 94f, 4f, 4f, m.segmentsOn, ink)
            }
            WidgetSize.LARGE -> {
                val chip = p.chip(m.reelsChip, p.w - 30f, 40f, ink, Align.END)
                p.text(m.leftBig, 30f, 40f, L, ink.count, maxWidth = chip - ROW_GAP - 30f)
                p.segments(30f, 158f, p.w - 30f, 222f, 5f, 8f, m.segmentsOn, ink)
            }
        }
        // With no limit the hero already reads the time watched, so the band carries no value.
        val value = if (m.hasLimit) m.time else ""
        p.band(size, m.note ?: m.limitLabel, value, clock = size != WidgetSize.SMALL, ink)
    }
}
