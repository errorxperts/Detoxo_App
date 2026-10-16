package com.errorxperts.detoxo.widget

import com.errorxperts.detoxo.widget.faces.BentoFace
import com.errorxperts.detoxo.widget.faces.BonsaiFace
import com.errorxperts.detoxo.widget.faces.CountFace
import com.errorxperts.detoxo.widget.faces.NextColourFace
import com.errorxperts.detoxo.widget.faces.PlanFace
import com.errorxperts.detoxo.widget.faces.RhythmFace
import com.errorxperts.detoxo.widget.faces.TimeLimitFace

/**
 * One family's drawing (DS-10): stateless, its S / M / L transcribed from the
 * Library board against [WidgetPainter]'s box — edge-anchored as the board
 * places them, so a stretched box spreads them out. A band (or the label
 * standing in for one) shows [WidgetModel.note] when there is one (DS-08).
 */
internal interface WidgetFace {
    fun draw(p: WidgetPainter, size: WidgetSize, m: WidgetModel)
}

/** The one family → face lookup; exhaustive, so a new family needs its face to compile. */
internal fun WidgetFamily.face(): WidgetFace = when (this) {
    WidgetFamily.COUNT -> CountFace
    WidgetFamily.NEXT_COLOUR -> NextColourFace
    WidgetFamily.TIME_LIMIT -> TimeLimitFace
    WidgetFamily.RHYTHM -> RhythmFace
    WidgetFamily.BONSAI -> BonsaiFace
    WidgetFamily.BENTO -> BentoFace
    WidgetFamily.PLAN -> PlanFace
}

/**
 * Room text keeps from the next item on its row (a chip, Rhythm M's bars,
 * Bento's mini ring). The board lets them collide; here the text shrinks.
 */
internal const val ROW_GAP = 8f
