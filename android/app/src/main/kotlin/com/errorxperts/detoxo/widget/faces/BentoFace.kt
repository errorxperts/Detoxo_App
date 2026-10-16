package com.errorxperts.detoxo.widget.faces

import com.errorxperts.detoxo.widget.Align
import com.errorxperts.detoxo.widget.Ink
import com.errorxperts.detoxo.widget.LBL_S
import com.errorxperts.detoxo.widget.ROW_GAP
import com.errorxperts.detoxo.widget.TextStyle
import com.errorxperts.detoxo.widget.VAL
import com.errorxperts.detoxo.widget.WidgetFace
import com.errorxperts.detoxo.widget.WidgetModel
import com.errorxperts.detoxo.widget.WidgetPainter
import com.errorxperts.detoxo.widget.WidgetSize
import com.errorxperts.detoxo.widget.WidgetTokens
import com.errorxperts.detoxo.widget.cnt
import com.errorxperts.detoxo.widget.spec

/**
 * 6 · Bento (Library L419–468): a neutral shell with calm modules; only the
 * count module, a tier tile, carries the tier colour. The modules fill the
 * shell: in a stretched box the count module takes the extra height and the
 * Large bottom pair splits the width.
 */
internal object BentoFace : WidgetFace {

    private val S = cnt(52f, -2f)
    private val M = cnt(WidgetTokens.COUNT_M, -3f)
    private val L = cnt(WidgetTokens.COUNT_L, -5f)

    // Medium's time: 28 / 800, line height 1, −0.6 (L441).
    private val TIME = TextStyle(28f, 28f, -0.6f, extraBold = true)
    private const val TIME_SPENT = "Time spent"

    override fun draw(p: WidgetPainter, size: WidgetSize, m: WidgetModel) {
        val count = Ink.tier(m.tier, p.dark, p.brand)
        val mod = Ink.bento(m.tier, p.dark, p.brand)
        p.tile(size, if (p.dark) WidgetTokens.BENTO_SHELL_DARK else WidgetTokens.BENTO_SHELL_LIGHT, mod.hairline)
        when (size) {
            WidgetSize.SMALL -> small(p, m, count, mod)
            WidgetSize.MEDIUM -> medium(p, m, count, mod)
            WidgetSize.LARGE -> large(p, m, count, mod)
        }
    }

    private fun small(p: WidgetPainter, m: WidgetModel, count: Ink, mod: Ink) {
        // Count module (8, 8)–(W − 8, 104), r28; the count at left 14 / bottom 12.
        val b = p.h - 56f
        p.tierFill(p.shape(8f, 8f, p.w - 8f, b, 28f), 8f, 8f, p.w - 8f, b, m.tier)
        p.text(m.countText, 22f, b - 12f - S.lineHeight, S, count.count, maxWidth = p.w - 44f)
        // Bottom module (8, H − 48)–(W − 8, H − 8), r16, padding 0 12: the DS-08 note takes its label.
        p.rect(8f, p.h - 48f, p.w - 8f, p.h - 8f, 16f, mod.band)
        p.row(20f, p.w - 20f, p.h - 28f, WidgetSize.SMALL.spec, m.note ?: m.todayShort, m.time, clock = false, mod)
    }

    private fun medium(p: WidgetPainter, m: WidgetModel, count: Ink, mod: Ink) {
        // Count module (8, 8)–(194, H − 8), r28: the chip at 14 / 14, the count at left 16 / bottom 14.
        val b = p.h - 8f
        p.tierFill(p.shape(8f, 8f, 194f, b, 28f), 8f, 8f, 194f, b, m.tier)
        p.chip(m.tierChip, 22f, 22f, count)
        p.text(m.countText, 24f, b - 14f - M.lineHeight, M, count.count, maxWidth = 154f)
        // Right module (202, 8)–(W − 8, H − 8), r28, padding 16, a space-between column
        // (label 16, time 28, status 16): the DS-08 note takes its label.
        p.rect(202f, 8f, p.w - 8f, b, 28f, mod.band)
        val room = p.w - 242f
        p.text(m.note ?: TIME_SPENT, 218f, 24f, LBL_S, mod.muted, maxWidth = room)
        p.text(m.time, 218f, 40f + (p.h - 108f) / 2f, TIME, mod.ink, maxWidth = room)
        p.circle(222f, p.h - 32f, 4f, mod.fill) // the 8-unit dot, then gap 6
        p.text(m.nextShort, 232f, p.h - 40f, LBL_S, mod.muted, maxWidth = room - 14f)
    }

    private fun large(p: WidgetPainter, m: WidgetModel, count: Ink, mod: Ink) {
        // Count module (10, 10)–(W − 10, 202), radii 66 66 28 28: the chip at right 28 / top 30,
        // the count at left 28 / bottom 22.
        val b = p.h - 138f
        p.tierFill(p.shape(10f, 10f, p.w - 10f, b, 66f, 66f, 28f, 28f), 10f, 10f, p.w - 10f, b, m.tier)
        p.chip(m.tierChip, p.w - 38f, 40f, count, Align.END)
        p.text(m.countText, 38f, b - 22f - L.lineHeight, L, count.count, maxWidth = p.w - 76f)
        // The bottom pair (10, H − 130)–(W − 10, H − 10), 8 apart; padding 18, 24 on the outer side.
        val top = p.h - 130f
        val mw = (p.w - 28f) / 2f
        val room = mw - 42f
        // Time module, radii 28 28 28 66: the DS-08 note takes its label.
        p.fill(p.shape(10f, top, 10f + mw, p.h - 10f, 28f, 28f, 28f, 66f), mod.band)
        p.text(m.note ?: TIME_SPENT, 34f, top + 18f, LBL_S, mod.muted, maxWidth = room)
        p.text(m.time, 34f, p.h - 28f - VAL.lineHeight, VAL, mod.ink, maxWidth = room)
        // Next module, radii 28 28 66 28: the label at 18 / 18, the 44-unit mini ring at right 18 / top 12.
        val next = p.w - 10f - mw
        p.fill(p.shape(next, top, p.w - 10f, p.h - 10f, 28f, 28f, 66f, 28f), mod.band)
        p.text(m.bentoNextLabel, next + 18f, top + 18f, LBL_S, mod.muted, maxWidth = mw - 80f - ROW_GAP)
        p.ring(p.w - 50f, top + 34f, 17f, 6f, m.ringPct, mod.faint, mod.fill)
        p.text(m.bentoNextValue, next + 18f, p.h - 28f - VAL.lineHeight, VAL, mod.ink, maxWidth = room)
    }
}
