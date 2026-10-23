package com.errorxperts.detoxo.overlay

import android.content.Context
import android.graphics.Canvas
import android.graphics.ColorMatrixColorFilter
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.os.SystemClock
import android.provider.Settings
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.util.TypedValue
import android.view.View
import android.view.animation.PathInterpolator
import com.errorxperts.detoxo.R
import com.errorxperts.detoxo.widget.Manrope
import com.errorxperts.detoxo.widget.withAlpha
import kotlin.math.max
import kotlin.math.roundToInt

/** "Remove animations" (animator duration scale 0): the wall holds still and nothing scales on press. */
internal fun reduceMotion(context: Context): Boolean =
    Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f

/**
 * The wall's backdrop: one Frozen Glass layout for both themes, only the
 * [theme]'s token values change. Top down, at the 20 dp gutter:
 * - the ground, bg-top → bg-bottom, with a static ambient light of the
 *   [accent] (radius 120, centred on the well, drawn only with the well);
 * - the header, from max(54, status bar + 8): `detoxo_logo.png` 23 × 44 with
 *   its glow, blended into brand-main in Light (white in Dark), then "Detoxo"
 *   in title-xl;
 * - the 88 icon well holding the reason's 3D [icon] at 58 — a mode icon takes
 *   the accent's hue, the others keep their own colour;
 * - the quote in a frosted panel (title 22/28) with its writer as an eyebrow;
 * - the "{name} can wait" line and one meta line (the block reason and every
 *   stat, the late ones included).
 *
 * The renderer's button column sits over the foot ([reservedBottom]); when
 * the column is short (landscape, 2× text) [wallFit] sheds the well, then the
 * quote's title size, then quote lines, the writer and the header. [fadeIn]
 * is a newly raised wall: the quote fades up and its writer follows, and the
 * frame loop ends with that (≤ 1.5 s). Nothing loops.
 *
 * Smooth by construction: layouts, shaders and the panel's drawable are built
 * on a size, inset, reserve or stats change — never per frame; no
 * `saveLayer`, and every blur is pre-rendered ([DxDrawable], [DxArt]).
 */
internal class QuoteWallView(
    context: Context,
    private val copy: WallCopy,
    private val quote: Quote,
    private val theme: DxTheme,
    private val accent: Int,
    private val icon: String,
    private val fadeIn: Boolean,
) : View(context) {

    /** The button column's laid-out height — the text never draws into it. */
    var reservedBottom: Int = 0
        set(value) {
            if (field == value) return
            field = value
            relayout()
        }

    /** The status bar's height: the window draws under it. */
    var topInset: Int = 0
        set(value) {
            if (field == value) return
            field = value
            relayout()
        }

    /** Stat lines that land after build: EVO-027's opens count and EVO-034's time today. */
    var extraStats: List<String> = emptyList()
        set(value) {
            if (field == value) return
            field = value
            refreshDescription()
            relayout()
        }

    private val density = resources.displayMetrics.density
    private val animating = fadeIn && !reduceMotion(context)
    private var startMs = 0L

    private val line = context.getString(R.string.wall_line, copy.name)
    private val writer = quote.writer.uppercase()

    // ── Type: the app's named styles, Manrope with tabular figures ──
    private val heavy = Manrope.extraBold(context)
    private val bold = Manrope.bold(context)
    private val semi = Manrope.semiBold(context)
    private val wordmark = text(heavy, DxTokens.TITLE_XL_SIZE, DxTokens.TITLE_XL_TRACKING_EM, theme.ink)
    private val titlePaint = text(heavy, DxTokens.TITLE_SIZE, DxTokens.TITLE_TRACKING_EM, theme.ink)
    private val headlinePaint = text(heavy, DxTokens.HEADLINE_SIZE, DxTokens.HEADLINE_TRACKING_EM, theme.ink)
    private val writerPaint = text(bold, DxTokens.EYEBROW_SIZE, DxTokens.EYEBROW_TRACKING_EM, theme.ink2)
    private val linePaint = text(semi, DxTokens.BODY_SIZE, DxTokens.BODY_TRACKING_EM, theme.ink2)
    private val metaPaint = text(semi, DxTokens.SUBHEAD_SIZE, DxTokens.SUBHEAD_TRACKING_EM, theme.ink2)

    /**
     * A laid-out text block, faded from its colour's own [alpha] (ink-2 is
     * translucent in Dark). Taken from the token, not the shared paint, which
     * a relayout mid-fade would catch part-faded.
     */
    private class Block(val layout: StaticLayout, val x: Float, val y: Float, val alpha: Int)

    private var foot: List<Block> = emptyList()
    private var quoteBlock: Block? = null
    private var writerBlock: Block? = null

    // ── Art ──
    private val logo = DxArt.logo(context)
    private val glows = if (logo != null) DxArt.logoGlow(context, theme.dark, dp(LOGO_H)) else emptyArray()
    private val glowAt = Array(glows.size) { RectF() }
    private val logoAt = RectF()
    private val art = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
        colorFilter = DxArt.logoTint(theme.dark)
    }
    private val hero = DxArt.icon(context, icon)
    private val heroPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
        if (icon in MODE_ICONS) colorFilter = ColorMatrixColorFilter(accentIconMatrix(accent))
    }
    private val heroAt = RectF()
    private var showHeader = true
    private var showWell = true
    private var wellX = 0f
    private var wellY = 0f
    private var wordX = 0f
    private var wordBaseline = 0f

    private val ground = Paint()
    private val ambient = Paint(Paint.ANTI_ALIAS_FLAG)
    private val well = Paint(Paint.ANTI_ALIAS_FLAG)
    private val panel = DxDrawable(theme.panel, dp(DxTokens.RADIUS_CARD), theme.shadowCard, density)
    private val fadeEase = PathInterpolator(0.25f, 0.1f, 0.25f, 1f)

    init {
        refreshDescription()
    }

    private fun refreshDescription() {
        contentDescription = listOf(copy.headline, quote.text, quote.writer, line, copy.reason)
            .plus(copy.stats)
            .plus(extraStats)
            .filter { it.isNotBlank() }
            .joinToString(". ")
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        ground.shader = LinearGradient(0f, 0f, 0f, h.toFloat(), theme.bgTop, theme.bgBottom, Shader.TileMode.CLAMP)
        relayout()
    }

    /** Lays out the column for the current size, insets and reserve, fitting it with [wallFit]. */
    private fun relayout() {
        val w = width
        val h = height
        if (w == 0 || h == 0) return
        val side = dp(DxTokens.SPACE_GUTTER)
        val pad = dp(DxTokens.SPACE_CARD)
        val cw = (w - 2 * side).toInt().coerceAtLeast(1)
        val inner = (cw - 2 * pad).toInt().coerceAtLeast(1)
        val top = max(dp(DxTokens.SPACE_HEADER_TOP), topInset + dp(8f))
        val bottom = h - reservedBottom - dp(12f)

        // The foot always shows: the line, then one meta line.
        val meta = (listOf(copy.reason) + copy.stats + extraStats).filter { it.isNotBlank() }.joinToString(" · ")
        val lineLayout = layout(line, linePaint, cw, DxTokens.BODY_LINE, 2)
        val metaLayout = if (meta.isEmpty()) null else layout(meta, metaPaint, cw, DxTokens.SUBHEAD_LINE, 3)
        val footH = dp(16f) + lineLayout.height + (metaLayout?.let { dp(6f) + it.height } ?: 0f)

        val title = layout(quote.text, titlePaint, inner, DxTokens.TITLE_LINE)
        val headline = layout(quote.text, headlinePaint, inner, DxTokens.HEADLINE_LINE)
        val writerLayout = layout(writer, writerPaint, inner, DxTokens.EYEBROW_LINE, 2)
        val writerH = dp(12f) + writerLayout.height
        val fit = wallFit(
            room = bottom - top - footH - 2 * pad,
            header = dp(LOGO_H) + dp(24f),
            well = dp(WELL) + dp(24f),
            titleQuote = title.height.toFloat(),
            headlineQuote = headline.height.toFloat(),
            headlineLine = headline.height.toFloat() / headline.lineCount.coerceAtLeast(1),
            writer = writerH,
        )
        val q = when {
            !fit.headline -> title
            fit.maxLines == Int.MAX_VALUE -> headline
            else -> layout(quote.text, headlinePaint, inner, DxTokens.HEADLINE_LINE, fit.maxLines)
        }

        // Place, top down.
        var y = top
        showHeader = fit.header
        if (showHeader) {
            val logoW = if (logo != null) dp(LOGO_H) * logo.width / logo.height else 0f
            logoAt.set(side, y, side + logoW, y + dp(LOGO_H))
            if (logo != null) {
                val k = logoAt.height() / logo.height
                for (i in glows.indices) {
                    val g = glows[i]
                    glowAt[i].set(
                        logoAt.left + g.dx * k,
                        logoAt.top + g.dy * k,
                        logoAt.left + (g.dx + g.mask.width) * k,
                        logoAt.top + (g.dy + g.mask.height) * k,
                    )
                }
            }
            val fm = wordmark.fontMetrics
            wordX = side + logoW + if (logo != null) dp(10f) else 0f
            wordBaseline = y + dp(LOGO_H) / 2f - (fm.ascent + fm.descent) / 2f
            y += dp(LOGO_H) + dp(24f)
        }
        showWell = fit.well
        if (showWell) {
            val r = dp(WELL) / 2f
            wellX = side + r
            wellY = y + r
            // CSS `radial-gradient(circle at 35% 30%, …)`: its farthest corner is .955 of the side.
            well.shader = RadialGradient(
                side + 0.35f * dp(WELL), y + 0.30f * dp(WELL), 0.955f * dp(WELL),
                theme.well[0], theme.well[1], Shader.TileMode.CLAMP,
            )
            ambient.shader = RadialGradient(
                wellX, wellY, dp(AMBIENT_R),
                withAlpha(accent, (theme.kAmb * 255f).roundToInt()), withAlpha(accent, 0), Shader.TileMode.CLAMP,
            )
            val ir = dp(ICON) / 2f
            heroAt.set(wellX - ir, wellY - ir, wellX + ir, wellY + ir)
            y += dp(WELL) + dp(24f)
        }
        val body = q.height + if (fit.writer) writerH else 0f
        panel.setBounds(side.roundToInt(), y.roundToInt(), (w - side).roundToInt(), (y + 2 * pad + body).roundToInt())
        quoteBlock = Block(q, side + pad, y + pad, theme.ink ushr 24)
        writerBlock = if (fit.writer) {
            Block(writerLayout, side + pad, y + pad + q.height + dp(12f), theme.ink2 ushr 24)
        } else {
            null
        }
        y += 2 * pad + body + dp(16f)
        foot = buildList {
            add(Block(lineLayout, side, y, theme.ink2 ushr 24))
            if (metaLayout != null) add(Block(metaLayout, side, y + lineLayout.height + dp(6f), theme.ink2 ushr 24))
        }
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        val now = SystemClock.uptimeMillis()
        if (startMs == 0L) startMs = now
        val t = if (animating) (now - startMs) / 1000f else ENTRANCE_S
        canvas.drawPaint(ground)
        if (showWell) {
            canvas.drawCircle(wellX, wellY, dp(AMBIENT_R), ambient)
            canvas.drawCircle(wellX, wellY, dp(WELL) / 2f, well)
            hero?.let { canvas.drawBitmap(it, null, heroAt, heroPaint) }
        }
        if (showHeader) {
            if (logo != null) {
                for (i in glows.indices) canvas.drawBitmap(glows[i].mask, null, glowAt[i], glows[i].paint)
                canvas.drawBitmap(logo, null, logoAt, art)
            }
            canvas.drawText(WORDMARK, wordX, wordBaseline, wordmark)
        }
        panel.draw(canvas)
        for (i in foot.indices) draw(canvas, foot[i], 1f) // no iterator per frame
        // A new wall's quote fades up over 1.2 s; its writer follows 0.3 s later.
        val fq = fadeEase.getInterpolation((t / FADE_S).coerceIn(0f, 1f))
        val fw = fadeEase.getInterpolation(((t - WRITER_DELAY_S) / FADE_S).coerceIn(0f, 1f))
        quoteBlock?.let { draw(canvas, it, fq) }
        writerBlock?.let { draw(canvas, it, fw) }
        if (animating && t < ENTRANCE_S && isAttachedToWindow) postInvalidateOnAnimation()
    }

    private fun draw(canvas: Canvas, b: Block, fade: Float) {
        b.layout.paint.alpha = (b.alpha * fade).roundToInt()
        canvas.save()
        canvas.translate(b.x, b.y + dp(10f) * (1f - fade))
        b.layout.draw(canvas)
        canvas.restore()
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        panel.setVisible(true, false)
    }

    override fun onDetachedFromWindow() {
        panel.setVisible(false, false) // drops its shadow bitmap
        super.onDetachedFromWindow()
    }

    private fun text(face: Typeface, sizeSp: Float, trackingEm: Float, color: Int) =
        TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = face
            textSize = sp(sizeSp)
            letterSpacing = trackingEm
            this.color = color
            fontFeatureSettings = "'tnum'"
        }

    /** Start-aligned, at the line height the style names, ellipsised past [maxLines]. */
    private fun layout(
        text: String,
        paint: TextPaint,
        width: Int,
        lineSp: Float,
        maxLines: Int = Int.MAX_VALUE,
    ): StaticLayout =
        StaticLayout.Builder.obtain(text, 0, text.length, paint, width)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setIncludePad(false)
            .setLineSpacing(sp(lineSp) - paint.fontSpacing, 1f)
            .setMaxLines(maxLines)
            .setEllipsize(TextUtils.TruncateAt.END)
            .build()

    private fun dp(v: Float): Float = v * density

    private fun sp(v: Float): Float =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, v, resources.displayMetrics)

    private companion object {
        const val WORDMARK = "Detoxo"

        /** The logo's height beside the wordmark, the icon well and its icon. */
        const val LOGO_H = 44f
        const val WELL = 88f
        const val ICON = 58f

        /**
         * The ambient's reach. At 120 the nearest ink-2 text (the panel's, 44 + 24 + 16
         * below the well's centre) sits under it at .09 at most, which keeps 4.5:1 for
         * every palette (BlockScreenGeometryTest).
         */
        const val AMBIENT_R = 120f

        /** The quote's fade-up (10 dp), how long the writer waits behind it, and the frame loop's end. */
        const val FADE_S = 1.2f
        const val WRITER_DELAY_S = 0.3f
        const val ENTRANCE_S = WRITER_DELAY_S + FADE_S
    }
}
