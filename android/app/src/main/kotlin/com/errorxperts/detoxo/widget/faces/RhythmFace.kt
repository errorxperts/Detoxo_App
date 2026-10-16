package com.errorxperts.detoxo.widget.faces

import com.errorxperts.detoxo.widget.Align
import com.errorxperts.detoxo.widget.ROW_GAP
import com.errorxperts.detoxo.widget.WidgetFace
import com.errorxperts.detoxo.widget.WidgetModel
import com.errorxperts.detoxo.widget.WidgetPainter
import com.errorxperts.detoxo.widget.WidgetSize
import com.errorxperts.detoxo.widget.cnt

/** 4 · Rhythm (Library L249–289): when today's scrolling happened, hour by hour, with the peak hour called out. */
internal object RhythmFace : WidgetFace {

    private val S = cnt(30f, -1f)
    private val M = cnt(34f, -1.2f)
    private val L = cnt(64f, -2.5f)

    override fun draw(p: WidgetPainter, size: WidgetSize, m: WidgetModel) {
        val ink = p.tierTile(size, m.tier)
        when (size) {
            WidgetSize.SMALL -> {
                p.text(m.time, 18f, 20f, S, ink.count, maxWidth = p.w - 36f)
                p.bars(18f, 60f, p.w - 18f, 100f, 1.5f, 2f, m.bars, m.peakHour, ink)
            }
            WidgetSize.MEDIUM -> {
                p.text(m.time, 30f, 24f, M, ink.count, maxWidth = 172f - ROW_GAP - 30f)
                p.chip(m.reelsChip, 30f, 66f, ink)
                p.bars(172f, 24f, p.w - 30f, 92f, 2f, 2f, m.bars, m.peakHour, ink)
            }
            WidgetSize.LARGE -> {
                val chip = p.chip(m.reelsChip, p.w - 30f, 46f, ink, Align.END)
                p.text(m.time, 30f, 40f, L, ink.count, maxWidth = chip - ROW_GAP - 30f)
                p.bars(30f, 128f, p.w - 30f, 228f, 4f, 3f, m.bars, m.peakHour, ink)
            }
        }
        p.band(size, m.note ?: m.peakLabel, m.peakValue, clock = false, ink)
    }
}
