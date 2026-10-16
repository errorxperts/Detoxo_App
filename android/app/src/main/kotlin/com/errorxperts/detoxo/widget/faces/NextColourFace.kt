package com.errorxperts.detoxo.widget.faces

import com.errorxperts.detoxo.widget.Align
import com.errorxperts.detoxo.widget.Ink
import com.errorxperts.detoxo.widget.LBL_S
import com.errorxperts.detoxo.widget.TextStyle
import com.errorxperts.detoxo.widget.VAL
import com.errorxperts.detoxo.widget.VAL_S
import com.errorxperts.detoxo.widget.WidgetFace
import com.errorxperts.detoxo.widget.WidgetModel
import com.errorxperts.detoxo.widget.WidgetPainter
import com.errorxperts.detoxo.widget.WidgetSize
import com.errorxperts.detoxo.widget.cnt

/** 2 · Next colour (Library L148–189): the ring fills over each block of 100 reels, then the tile changes colour. */
internal object NextColourFace : WidgetFace {

    private val S = cnt(30f, -1f)
    private val M = cnt(36f, -1.2f)
    private val L = cnt(64f, -2.5f)

    // The M panel's column: lblS 16 + 6 + val 26 + 6 + valS 18.
    private const val PANEL_COLUMN = 72f

    override fun draw(p: WidgetPainter, size: WidgetSize, m: WidgetModel) {
        val ink = p.tierTile(size, m.tier)
        // The ring is a centred item: a taller box keeps it in the middle.
        val dy = (p.h - size.designHeight) / 2f
        when (size) {
            WidgetSize.SMALL -> {
                ring(p, m, ink, p.w / 2f, 64f + dy, 44f, 10f, S) // the 104 box at ((W − 104) / 2, 12)
                p.chip(m.note ?: m.nextShort, p.w / 2f, 124f + dy, ink, Align.CENTER)
            }
            WidgetSize.MEDIUM -> {
                ring(p, m, ink, 80f, 80f + dy, 52f, 12f, M) // the 124 box at (18, 18)
                val top = p.panel(160f, 18f, p.w - 18f, p.h - 18f, ink.band, PANEL_COLUMN)
                val room = p.w - 210f // the panel's width inside its 16-unit padding
                p.text(m.note ?: m.nextLabel, 176f, top, LBL_S, ink.muted, maxWidth = room)
                p.text(m.nextValue, 176f, top + 22f, VAL, ink.ink, maxWidth = room)
                p.valueLine(m.time, 176f, top + 54f, VAL_S, ink.ink, clock = true, Align.START, maxWidth = room)
            }
            WidgetSize.LARGE -> {
                ring(p, m, ink, p.w / 2f, 126f + dy, 86f, 18f, L) // the 200 box at ((W − 200) / 2, 26)
                p.band(size, m.note ?: m.nextLong, m.time, clock = true, ink)
            }
        }
    }

    /** The ring and the count centred in its hole. */
    private fun ring(p: WidgetPainter, m: WidgetModel, ink: Ink, cx: Float, cy: Float, r: Float, width: Float, style: TextStyle) {
        p.ring(cx, cy, r, width, m.ringPct, ink.faint, ink.fill)
        p.text(m.countText, cx, cy - style.lineHeight / 2f, style, ink.count, Align.CENTER, maxWidth = 2f * r - width)
    }
}
