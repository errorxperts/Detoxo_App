package com.errorxperts.detoxo.widget

import android.content.Context
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import com.errorxperts.detoxo.engine.ContentCounterStore
import kotlin.math.roundToInt

/**
 * Draws the home-screen widgets to bitmaps, because RemoteViews can't draw a
 * ring or a bonsai: one family's face for one model at one size, fitted to the
 * launcher cell. The in-app `WidgetPreview` draws the same spec in Flutter.
 */
object WidgetBitmapRenderer {

    /**
     * [family]'s face for [model] at [size] on a transparent bitmap the size
     * of a [cellWPx] × [cellHPx] launcher cell (long side ≤ 1200 px), laid out
     * per [fitBox]. The palette follows the payload's theme, `system` taking
     * the device's (IM-07).
     */
    fun render(
        context: Context,
        family: WidgetFamily,
        size: WidgetSize,
        model: WidgetModel,
        cellWPx: Int,
        cellHPx: Int,
    ): Bitmap {
        val fit = fitBox(cellWPx, cellHPx, size.designWidth, size.designHeight)
        val bitmap = Bitmap.createBitmap(fit.bitmapW, fit.bitmapH, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.translate(fit.left, fit.top)
        canvas.scale(fit.scale, fit.scale)
        val dark = model.payload.isDark(isSystemDark(context))
        val brand = ContentCounterStore(context).brand(dark)
        family.face().draw(WidgetPainter(context, canvas, fit.faceW, fit.faceH, dark, brand), size, model)
        return bitmap
    }

    /** [family]'s Small face in a [PREVIEW_PX] square, for the pin dialog and the widget picker. */
    fun preview(context: Context, family: WidgetFamily, model: WidgetModel): Bitmap =
        render(context, family, WidgetSize.SMALL, model, PREVIEW_PX, PREVIEW_PX)

    /**
     * Where a [designW] × [designH] face lands in a [cellW] × [cellH] px
     * cell. The cell first shrinks to a long side of [MAX_PX]. One
     * uniform scale s fits the design box; the face then stretches to fill
     * the cell, at most [STRETCH_X] wider and [STRETCH_Y] taller, laying out
     * in the larger box (edge-anchored, see `WidgetFace`). Past those caps
     * it is letterboxed, centred on the transparent bitmap. Pure.
     */
    internal fun fitBox(cellW: Int, cellH: Int, designW: Float, designH: Float): Fit {
        val clamp = minOf(1f, MAX_PX.toFloat() / maxOf(cellW, cellH, 1))
        val bitmapW = (cellW * clamp).roundToInt().coerceAtLeast(1)
        val bitmapH = (cellH * clamp).roundToInt().coerceAtLeast(1)
        val scale = minOf(bitmapW / designW, bitmapH / designH)
        val boxW = minOf(bitmapW.toFloat(), designW * scale * STRETCH_X)
        val boxH = minOf(bitmapH.toFloat(), designH * scale * STRETCH_Y)
        return Fit(bitmapW, bitmapH, scale, (bitmapW - boxW) / 2f, (bitmapH - boxH) / 2f, boxW / scale, boxH / scale)
    }

    internal fun isSystemDark(context: Context): Boolean =
        (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES

    private const val MAX_PX = 1200
    private const val PREVIEW_PX = 256
    private const val STRETCH_X = 1.25f
    private const val STRETCH_Y = 1.8f
}

/**
 * [fitBox]'s answer: the bitmap's size, the design-unit [scale] (px per
 * unit), the face box's top-left in px and its size in design units.
 */
internal data class Fit(
    val bitmapW: Int,
    val bitmapH: Int,
    val scale: Float,
    val left: Float,
    val top: Float,
    val faceW: Float,
    val faceH: Float,
)
