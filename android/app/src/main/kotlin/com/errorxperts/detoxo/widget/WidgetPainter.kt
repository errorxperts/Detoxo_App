package com.errorxperts.detoxo.widget

import android.content.Context
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.Shader
import android.graphics.Typeface

/** Where a run sits on its x: start, centre or end. */
internal enum class Align {
    START,
    CENTER,
    END,
    ;

    /** The left edge of a [width]-wide run anchored at [x]. */
    fun left(x: Float, width: Float): Float = when (this) {
        START -> x
        CENTER -> x - width / 2f
        END -> x - width
    }
}

/**
 * A board text class in design units: size, CSS line height, letter spacing
 * and weight 700 (800 when [extraBold]). A value class also carries the clock
 * icon that can lead it: box, stroke (24-grid units) and gap.
 */
internal class TextStyle(
    val size: Float,
    val lineHeight: Float,
    val letterSpacing: Float = 0f,
    val extraBold: Boolean = false,
    val clock: Float = 0f,
    val clockStroke: Float = 0f,
    val clockGap: Float = 0f,
)

/** `.cnt`: a hero number, line height 1. */
internal fun cnt(size: Float, letterSpacing: Float) = TextStyle(size, size, letterSpacing)

// The board's text classes (Library.dc.html L26–31). M bands set .lbl to 14 px
// and .valS to 17 px with a 16 px clock (L124–125).
internal val LBL_S = TextStyle(WidgetTokens.LABEL_S, WidgetTokens.LINE_LABEL_S)
internal val LBL_M = TextStyle(WidgetTokens.LABEL_M, WidgetTokens.LINE_LABEL_L)
internal val LBL = TextStyle(WidgetTokens.LABEL_L, WidgetTokens.LINE_LABEL_L)
internal val VAL_S =
    TextStyle(WidgetTokens.VALUE_S, WidgetTokens.LINE_VALUE_S, clock = 14f, clockStroke = 2.4f, clockGap = 5f)
internal val VAL_M =
    TextStyle(WidgetTokens.VALUE_M, WidgetTokens.LINE_VALUE_S, clock = 16f, clockStroke = 2.4f, clockGap = 5f)
internal val VAL =
    TextStyle(WidgetTokens.VALUE_L, WidgetTokens.LINE_VALUE_L, -0.4f, clock = 18f, clockStroke = 2.2f, clockGap = 6f)

// .chip: 12 px, its line box centred in the 24-unit pill.
private val CHIP = TextStyle(WidgetTokens.LABEL_S, WidgetTokens.CHIP_HEIGHT)

/** DS-04 per size: tile radius, inset (= band padding), band height and the band's label / value class. */
internal class SizeSpec(
    val radius: Float,
    val inset: Float,
    val band: Float,
    val label: TextStyle,
    val value: TextStyle,
)

private val SMALL_SPEC = SizeSpec(WidgetTokens.RADIUS_S, WidgetTokens.INSET_S, WidgetTokens.BAND_S, LBL_S, VAL_S)
private val MEDIUM_SPEC = SizeSpec(WidgetTokens.RADIUS_M, WidgetTokens.INSET_M, WidgetTokens.BAND_M, LBL_M, VAL_M)
private val LARGE_SPEC = SizeSpec(WidgetTokens.RADIUS_L, WidgetTokens.INSET_L, WidgetTokens.BAND_L, LBL, VAL)

internal val WidgetSize.spec: SizeSpec
    get() = when (this) {
        WidgetSize.SMALL -> SMALL_SPEC
        WidgetSize.MEDIUM -> MEDIUM_SPEC
        WidgetSize.LARGE -> LARGE_SPEC
    }

/**
 * The CSS `linear-gradient(135deg, …)` line over [l]..[b] as x0, y0, x1, y1:
 * the centre ∓ ((w + h) / 4, (w + h) / 4), so the end colours land on the
 * corners' perpendiculars exactly as a browser draws them.
 */
internal fun gradient135(l: Float, t: Float, r: Float, b: Float): FloatArray {
    val q = (r - l + b - t) / 4f
    val cx = (l + r) / 2f
    val cy = (t + b) / 2f
    return floatArrayOf(cx - q, cy - q, cx + q, cy + q)
}

/** The font scale that fits a [width]-wide run into [maxWidth]: 1 when it fits, 0 when there is no room. */
internal fun fitScale(width: Float, maxWidth: Float): Float =
    if (width <= maxWidth) 1f else (maxWidth / width).coerceAtLeast(0f)

/**
 * One face's colours — the board's `widget()` / `bonsai()` tokens: values
 * ([ink]), labels and chip text ([muted]), band / chip / panel tint ([band]),
 * idle marks ([faint]), active marks ([fill]), the hero number ([count]) and
 * the tile's inset [hairline] (0 = none).
 */
internal class Ink(
    val ink: Int,
    val muted: Int,
    val band: Int,
    val faint: Int,
    val fill: Int,
    val count: Int,
    val hairline: Int,
) {
    companion object {
        /**
         * A tier tile: light inverts to white from tier 4 (DS-05); dark takes the tier accent.
         * Every tier is in [brand]'s hue (the app theme's primary, [BrandTint]).
         */
        fun tier(tier: Int, dark: Boolean, brand: Int): Ink {
            if (dark) {
                val accent = darkAccent(tier, brand)
                return Ink(
                    ink = WidgetTokens.DARK_INK,
                    muted = WidgetTokens.DARK_MUTED,
                    band = WidgetTokens.DARK_BAND,
                    faint = WidgetTokens.DARK_FAINT,
                    fill = accent,
                    count = accent,
                    hairline = WidgetTokens.DARK_HAIRLINE,
                )
            }
            val inverse = tier >= 4
            val ink = if (inverse) WidgetTokens.WIDGET_INK_INVERSE else WidgetTokens.WIDGET_INK
            return Ink(
                ink = ink,
                muted = if (inverse) WidgetTokens.WIDGET_INK_INVERSE else WidgetTokens.WIDGET_INK_MUTED,
                band = if (inverse) WidgetTokens.BAND_DARK else WidgetTokens.BAND_LIGHT,
                faint = if (inverse) WidgetTokens.FAINT_INVERSE else WidgetTokens.FAINT_LIGHT,
                fill = ink,
                count = if (tier == 0) BrandTint.at(brand, BrandTint.COUNT_LIGHT) else ink,
                hairline = if (tier == 0) WidgetTokens.HAIRLINE_EMPTY else 0,
            )
        }

        /** Bonsai's neutral tile; the health bar takes the theme's ramp ([dot]), the tree keeps its own colours. */
        fun bonsai(tier: Int, dark: Boolean, brand: Int) = Ink(
            ink = if (dark) WidgetTokens.BONSAI_INK_DARK else WidgetTokens.BONSAI_INK_LIGHT,
            muted = if (dark) WidgetTokens.BONSAI_MUTED_DARK else WidgetTokens.BONSAI_MUTED_LIGHT,
            band = if (dark) WidgetTokens.BONSAI_BAND_DARK else WidgetTokens.BONSAI_BAND_LIGHT,
            faint = if (dark) WidgetTokens.BONSAI_TRACK_DARK else WidgetTokens.BONSAI_TRACK_LIGHT,
            fill = dot(tier, dark, brand),
            count = if (dark) WidgetTokens.BONSAI_INK_DARK else WidgetTokens.BONSAI_INK_LIGHT,
            hairline = if (dark) WidgetTokens.BONSAI_HAIRLINE_DARK else WidgetTokens.BONSAI_HAIRLINE_LIGHT,
        )

        /**
         * Bento's calm modules ([band] = the module): the tier shows only in the dot and the mini
         * ring ([dot]).
         */
        fun bento(tier: Int, dark: Boolean, brand: Int) = Ink(
            ink = if (dark) WidgetTokens.BENTO_INK_DARK else WidgetTokens.BENTO_INK_LIGHT,
            muted = if (dark) WidgetTokens.BENTO_MUTED_DARK else WidgetTokens.BENTO_MUTED_LIGHT,
            band = if (dark) WidgetTokens.BENTO_MODULE_DARK else WidgetTokens.BENTO_MODULE_LIGHT,
            faint = if (dark) WidgetTokens.BENTO_FAINT_DARK else WidgetTokens.BENTO_FAINT_LIGHT,
            fill = dot(tier, dark, brand),
            count = if (dark) WidgetTokens.BENTO_INK_DARK else WidgetTokens.BENTO_INK_LIGHT,
            hairline = if (dark) WidgetTokens.DARK_HAIRLINE else 0,
        )

        /** The dark theme's accent for [tier], in [brand]'s hue, calm → vivid. */
        fun darkAccent(tier: Int, brand: Int): Int =
            BrandTint.ramp(brand, BrandTint.ACCENT_DARK_Y[tier], BrandTint.ACCENT_DARK_S[tier])

        /** Bento's dot and Bonsai's health bar for [tier]: on a light module the ramp's dot, on a dark one the [darkAccent]. */
        fun dot(tier: Int, dark: Boolean, brand: Int): Int =
            if (dark) darkAccent(tier, brand) else BrandTint.ramp(brand, BrandTint.DOT_LIGHT[tier])
    }
}

/**
 * The home-widget primitives (DS-10) over [canvas] in DESIGN UNITS: the
 * renderer scales the canvas, so a face passes the board's numbers as they
 * are, against its [w] × [h] box. One per render; [dark] is the resolved
 * theme, [brand] the app theme's primary (tier 0's hue). Every colour comes from [WidgetTokens]; no clipPath, so every edge
 * stays anti-aliased.
 */
internal class WidgetPainter(
    context: Context,
    private val canvas: Canvas,
    val w: Float,
    val h: Float,
    val dark: Boolean,
    val brand: Int,
) {
    private val fonts = Fonts(Manrope.bold(context), Manrope.extraBold(context))
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { isDither = true }
    private val line = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }

    // Linear metrics: on a scaled canvas, advances and letter spacing hinted
    // (rounded) at design-unit sizes would land up to a pixel off per glyph.
    private val type = Paint(Paint.ANTI_ALIAS_FLAG or Paint.SUBPIXEL_TEXT_FLAG or Paint.LINEAR_TEXT_FLAG).apply {
        fontFeatureSettings = "'tnum'"
    }

    // ── Tiles ───────────────────────────────────────────────────────────────

    /** A rounded rect over [l]..[b], radii in CSS order: top-left, top-right, bottom-right, bottom-left. */
    fun shape(l: Float, t: Float, r: Float, b: Float, tl: Float, tr: Float = tl, br: Float = tl, bl: Float = tl) =
        Path().apply { addRoundRect(l, t, r, b, floatArrayOf(tl, tl, tr, tr, br, br, bl, bl), Path.Direction.CW) }

    fun fill(shape: Path, color: Int) {
        solid(color)
        canvas.drawPath(shape, paint)
    }

    fun rect(l: Float, t: Float, r: Float, b: Float, radius: Float, color: Int) {
        solid(color)
        canvas.drawRoundRect(l, t, r, b, radius, radius, paint)
    }

    fun circle(cx: Float, cy: Float, r: Float, color: Int) {
        solid(color)
        canvas.drawCircle(cx, cy, r, paint)
    }

    /** The whole box as a tier tile (Count, Next colour, Time limit, Rhythm); returns its [Ink]. */
    fun tierTile(size: WidgetSize, tier: Int): Ink {
        val radius = size.spec.radius
        tierFill(shape(0f, 0f, w, h, radius), 0f, 0f, w, h, tier)
        return Ink.tier(tier, dark, brand).also { hairline(radius, it.hairline) }
    }

    /** The whole box as a flat neutral tile (Bonsai, Bento's shell) with its inset [hairlineColor] (0 = none). */
    fun tile(size: WidgetSize, color: Int, hairlineColor: Int) {
        val radius = size.spec.radius
        rect(0f, 0f, w, h, radius, color)
        hairline(radius, hairlineColor)
    }

    /**
     * Fills [shape], bounds [l]..[b], as a tier tile (DS-02 / DS-06), in the
     * brand's hue. Light: the ramp's 135° gradient ([BrandTint.TILE_FROM] →
     * [BrandTint.TILE_TO]); tier 0 is flat. Dark: the surface (`darkEmpty`
     * at tier 0) plus the tier's glow, an ellipse 130 % × 100 % from the top-left
     * fading out at 62 %. Both then take
     * the sheen, 90 % × 70 % at (12 %, 0) fading out at 60 % (board L21, L566).
     */
    fun tierFill(shape: Path, l: Float, t: Float, r: Float, b: Float, tier: Int) {
        val tw = r - l
        val th = b - t
        when {
            dark -> {
                fill(shape, if (tier > 0) WidgetTokens.DARK_SURFACE else WidgetTokens.DARK_EMPTY)
                val glow = withAlpha(Ink.darkAccent(tier, brand), WidgetTokens.DARK_GLOW_ALPHA)
                fill(shape, radial(l, t, 1.3f * tw, th, glow, 0.62f))
            }
            tier > 0 -> {
                val g = gradient135(l, t, r, b)
                val from = BrandTint.ramp(brand, BrandTint.TILE_FROM[tier - 1])
                val to = BrandTint.ramp(brand, BrandTint.TILE_TO[tier - 1])
                fill(shape, LinearGradient(g[0], g[1], g[2], g[3], from, to, Shader.TileMode.CLAMP))
            }
            else -> fill(shape, BrandTint.at(brand, BrandTint.TILE_LIGHT))
        }
        fill(shape, radial(l + 0.12f * tw, t, 0.9f * tw, 0.7f * th, WidgetTokens.SHEEN, 0.6f))
    }

    /** CSS `inset 0 0 0 1px`: a 1-unit ring just inside the box's edge; 0 = none. */
    private fun hairline(radius: Float, color: Int) {
        if (color == 0) return
        line.strokeWidth = 1f
        line.color = color
        canvas.drawRoundRect(0.5f, 0.5f, w - 0.5f, h - 0.5f, radius - 0.5f, radius - 0.5f, line)
    }

    // ── Band, row, chip, panel ──────────────────────────────────────────────

    /**
     * The bottom band (DS-04): the tile's bottom [SizeSpec.band] units cut to
     * its rounded outline, holding [label] | [value] (led by the clock when
     * [clock]). An empty [value] leaves the label the whole row.
     */
    fun band(size: WidgetSize, label: String, value: String, clock: Boolean, ink: Ink) {
        val spec = size.spec
        val top = h - spec.band
        val band = Path().apply { addRect(0f, top, w, h, Path.Direction.CW) }
        band.op(shape(0f, 0f, w, h, spec.radius), Path.Op.INTERSECT)
        fill(band, ink.band)
        row(spec.inset, w - spec.inset, top + spec.band / 2f, spec, label, value, clock, ink)
    }

    /**
     * A band row centred on [mid] (`.band`: space-between, gap 8): [label] in
     * muted from [l], [value] in ink ending at [r]. The value shrinks to fit
     * the row; the label shrinks into what the value leaves.
     */
    fun row(l: Float, r: Float, mid: Float, spec: SizeSpec, label: String, value: String, clock: Boolean, ink: Ink) {
        val valueTop = mid - spec.value.lineHeight / 2f
        val used = if (value.isEmpty()) {
            0f
        } else {
            valueLine(value, r, valueTop, spec.value, ink.ink, clock, Align.END, maxWidth = r - l) +
                WidgetTokens.BAND_GAP
        }
        text(label, l, mid - spec.label.lineHeight / 2f, spec.label, ink.muted, maxWidth = r - l - used)
    }

    /** A chip (`.chip`): a pill in the band tint with muted 12 px text, at [x] per [align]; returns its left edge. */
    fun chip(s: String, x: Float, top: Float, ink: Ink, align: Align = Align.START): Float {
        val width = measure(s, CHIP) + 2f * WidgetTokens.CHIP_PAD
        val left = align.left(x, width)
        rect(left, top, left + width, top + WidgetTokens.CHIP_HEIGHT, WidgetTokens.CHIP_HEIGHT / 2f, ink.band)
        text(s, left + WidgetTokens.CHIP_PAD, top, CHIP, ink.muted)
        return left
    }

    /** A panel (`.panel`) in [color] over [l]..[b]; returns the top of a [content]-high column centred in it. */
    fun panel(l: Float, t: Float, r: Float, b: Float, color: Int, content: Float): Float {
        rect(l, t, r, b, WidgetTokens.PANEL_RADIUS, color)
        return (t + b - content) / 2f
    }

    // ── Text ────────────────────────────────────────────────────────────────

    /**
     * [s] on a CSS line box (DS-03): [top] is the box's top and the style's
     * line height its height, so the baseline is top + lh/2 − (ascent +
     * descent)/2; [x] anchors it per [align]. Wider than [maxWidth], it
     * shrinks to fit. Returns the drawn width.
     */
    fun text(
        s: String,
        x: Float,
        top: Float,
        style: TextStyle,
        color: Int,
        align: Align = Align.START,
        maxWidth: Float = Float.MAX_VALUE,
    ): Float {
        var width = measure(s, style)
        val scale = fitScale(width, maxWidth)
        if (scale <= 0f) return 0f
        if (scale < 1f) {
            type.textSize = style.size * scale
            width = type.measureText(s)
        }
        val fm = type.fontMetrics
        type.color = color
        canvas.drawText(s, align.left(x, width), top + style.lineHeight / 2f - (fm.ascent + fm.descent) / 2f, type)
        return width
    }

    /**
     * A value (`.valS` / `.val`), led by its style's clock when [clock], at
     * [x] per [align]. Wider than [maxWidth], the whole line, clock and all,
     * shrinks to fit about its anchor, as the Dart painter does. Returns the
     * drawn width.
     */
    fun valueLine(
        s: String,
        x: Float,
        top: Float,
        style: TextStyle,
        color: Int,
        clock: Boolean,
        align: Align,
        maxWidth: Float = Float.MAX_VALUE,
    ): Float {
        val lead = if (clock) style.clock + style.clockGap else 0f
        val natural = lead + measure(s, style)
        val scale = fitScale(natural, maxWidth)
        if (scale <= 0f) return 0f
        val left = align.left(x, natural * scale)
        canvas.save()
        canvas.scale(scale, scale, left, top + style.lineHeight / 2f)
        if (clock) clock(left, top + (style.lineHeight - style.clock) / 2f, style, color)
        text(s, left + lead, top, style, color)
        canvas.restore()
        return natural * scale
    }

    /** [s]'s width in [style]; leaves [type] set up to draw it. */
    private fun measure(s: String, style: TextStyle): Float {
        type.typeface = if (style.extraBold) fonts.extraBold else fonts.bold
        type.textSize = style.size
        type.letterSpacing = style.letterSpacing / style.size // em, so a shrink keeps it in proportion
        return type.measureText(s)
    }

    // ── Marks ───────────────────────────────────────────────────────────────

    /** The clock icon: the board's 24-grid circle r9 + `M12 7v5l3 2`, round caps, in [style]'s icon box. */
    private fun clock(x: Float, top: Float, style: TextStyle, color: Int) {
        val u = style.clock / 24f
        line.strokeWidth = style.clockStroke * u
        line.color = color
        canvas.drawCircle(x + 12f * u, top + 12f * u, 9f * u, line)
        canvas.drawLine(x + 12f * u, top + 7f * u, x + 12f * u, top + 12f * u, line)
        canvas.drawLine(x + 12f * u, top + 12f * u, x + 15f * u, top + 14f * u, line)
    }

    /** A ring: the [track], then [pct] % in [color] clockwise from 12 o'clock with round caps; nothing at 0. */
    fun ring(cx: Float, cy: Float, r: Float, width: Float, pct: Int, track: Int, color: Int) {
        line.strokeWidth = width
        line.color = track
        canvas.drawCircle(cx, cy, r, line)
        if (pct <= 0) return
        line.color = color
        canvas.drawArc(cx - r, cy - r, cx + r, cy + r, -90f, 3.6f * pct.coerceAtMost(100), false, line)
    }

    /**
     * The [WidgetModel.SEGMENT_COUNT] limit segments across [l]..[r] ×
     * [t]..[b] (`.segs`): the first [on] in fill, the rest faint.
     */
    fun segments(l: Float, t: Float, r: Float, b: Float, gap: Float, radius: Float, on: Int, ink: Ink) {
        val sw = (r - l - gap * (WidgetModel.SEGMENT_COUNT - 1)) / WidgetModel.SEGMENT_COUNT
        for (i in 0 until WidgetModel.SEGMENT_COUNT) {
            val x = l + i * (sw + gap)
            rect(x, t, x + sw, b, radius, if (i < on) ink.fill else ink.faint)
        }
    }

    /** The hour bars across [l]..[r] (`.bars`), [shares] of [t]..[b] tall from the bottom; [peak] in fill. */
    fun bars(
        l: Float,
        t: Float,
        r: Float,
        b: Float,
        gap: Float,
        radius: Float,
        shares: List<Double>,
        peak: Int,
        ink: Ink,
    ) {
        val bw = (r - l - gap * (shares.size - 1)) / shares.size
        for ((i, share) in shares.withIndex()) {
            val x = l + i * (bw + gap)
            rect(x, b - (b - t) * share.toFloat(), x + bw, b, radius, if (i == peak) ink.fill else ink.faint)
        }
    }

    /**
     * The bonsai at [tier] (board L301–328, tables in `bonsai()` L608–623):
     * its 100-unit box drawn [size] wide at ([x], [y]), in SVG order. It
     * stands still here; the sway and the falling leaf are the in-app
     * preview's (IM-06).
     */
    fun tree(x: Float, y: Float, size: Float, tier: Int) {
        canvas.save()
        canvas.translate(x, y)
        canvas.scale(size / 100f, size / 100f)
        val leaf = WidgetTokens.BONSAI_LEAF[tier]
        val bark = WidgetTokens.BONSAI_BARK[tier]
        val ground = if (dark) WidgetTokens.BONSAI_GROUND_DARK else WidgetTokens.BONSAI_GROUND_LIGHT
        oval(50f, 91f, 24f, 2.6f, ground)
        for (i in 0 until FALLEN[tier]) {
            val f = FALLEN_LEAVES[i]
            oval(f[0], f[1], f[2], f[3], leaf)
        }
        stroke(TRUNK, 4.6f, bark)
        stroke(BRANCH_LEFT, 2.6f, bark)
        stroke(BRANCH_RIGHT, 2.4f, bark)
        if (tier >= 4) {
            val alpha = if (tier == WidgetPayload.MAX_TIER) 255 else CRACKS_ALPHA
            stroke(CRACKS, 0.8f, withAlpha(WidgetTokens.BONSAI_CRACK, alpha), Paint.Cap.BUTT)
        }
        for ((i, pad) in PADS.withIndex()) {
            if (i !in KEEP[tier]) continue
            val r = pad[2] * PAD_SIZE[tier]
            circle(pad[0], pad[1], r, leaf)
            circle(pad[3], pad[4], r * 0.5f, WidgetTokens.BONSAI_HIGHLIGHT[tier])
        }
        if (tier == 0) {
            for (b in BLOSSOMS) circle(b[0], b[1], b[2], WidgetTokens.BONSAI_BLOSSOM)
        }
        fill(POT, WidgetTokens.BONSAI_POT)
        rect(27f, 67f, 73f, 72f, 2f, WidgetTokens.BONSAI_RIM)
        if (tier <= 1) {
            val cheek = withAlpha(WidgetTokens.BONSAI_CHEEK, CHEEK_ALPHA)
            circle(39.5f, 82f, 2f, cheek)
            circle(60.5f, 82f, 2f, cheek)
        }
        val eyes = when {
            tier == 0 -> EYES_CLOSED
            tier >= 4 -> EYES_WORRIED
            else -> EYES_OPEN
        }
        stroke(eyes, 1.8f, WidgetTokens.BONSAI_FACE)
        stroke(MOUTHS[tier], 1.6f, WidgetTokens.BONSAI_FACE)
        if (tier == WidgetPayload.MAX_TIER) circle(57.6f, 81.4f, 1f, WidgetTokens.BONSAI_TEAR)
        canvas.restore()
    }

    // ── Plumbing ────────────────────────────────────────────────────────────

    private fun solid(color: Int) {
        paint.shader = null
        paint.color = color
    }

    private fun fill(shape: Path, shader: Shader) {
        paint.alpha = 255 // the shader carries the colour; the paint's alpha would scale it
        paint.shader = shader
        canvas.drawPath(shape, paint)
        paint.shader = null
    }

    private fun oval(cx: Float, cy: Float, rx: Float, ry: Float, color: Int) {
        solid(color)
        canvas.drawOval(cx - rx, cy - ry, cx + rx, cy + ry, paint)
    }

    private fun stroke(path: Path, width: Float, color: Int, cap: Paint.Cap = Paint.Cap.ROUND) {
        line.strokeWidth = width
        line.color = color
        line.strokeCap = cap
        canvas.drawPath(path, line)
        line.strokeCap = Paint.Cap.ROUND
    }

    /** A CSS elliptical radial gradient: [color] at ([cx], [cy]) fading to transparent at [stop] of [rx] × [ry]. */
    private fun radial(cx: Float, cy: Float, rx: Float, ry: Float, color: Int, stop: Float): Shader {
        val colors = intArrayOf(color, withAlpha(color, 0))
        return RadialGradient(0f, 0f, 1f, colors, floatArrayOf(0f, stop), Shader.TileMode.CLAMP).apply {
            // A unit circle scaled to the ellipse: Android's radial gradients are circular.
            setLocalMatrix(Matrix().apply { setScale(rx, ry); postTranslate(cx, cy) })
        }
    }

    private class Fonts(val bold: Typeface, val extraBold: Typeface)

    private companion object {
        // ── The bonsai, transcribed from the board's SVG (L301–328) and bonsai() ──

        // `.tr` opacities .45 (cracks at Withering) and .55 (cheeks), as alpha.
        const val CRACKS_ALPHA = 115
        const val CHEEK_ALPHA = 140

        /** Fallen leaves f1..f6 as cx, cy, rx, ry; the first `FALLEN[tier]` show. */
        val FALLEN_LEAVES = arrayOf(
            floatArrayOf(29f, 89.6f, 2.3f, 1f),
            floatArrayOf(70f, 89.8f, 2.3f, 1f),
            floatArrayOf(34f, 90.4f, 2.1f, 0.9f),
            floatArrayOf(65f, 90.6f, 2.1f, 0.9f),
            floatArrayOf(24f, 90.6f, 2f, 0.9f),
            floatArrayOf(75f, 90.2f, 2f, 0.9f),
        )
        val FALLEN = intArrayOf(0, 0, 1, 3, 5, 6)

        /** Foliage pads p0..p4 as cx, cy, R, highlight cx, highlight cy; `KEEP` / `SIZE` per tier. */
        val PADS = arrayOf(
            floatArrayOf(33f, 41f, 10f, 30.5f, 38.5f),
            floatArrayOf(66f, 34f, 11f, 63.5f, 31.5f),
            floatArrayOf(51f, 25f, 13f, 48f, 22f),
            floatArrayOf(40f, 30f, 9f, 38f, 28f),
            floatArrayOf(60f, 45f, 8.5f, 58f, 43f),
        )
        val KEEP = arrayOf(
            setOf(0, 1, 2, 3, 4),
            setOf(0, 1, 2, 3, 4),
            setOf(0, 1, 2, 4),
            setOf(1, 2, 4),
            setOf(0, 2),
            emptySet(),
        )
        val PAD_SIZE = floatArrayOf(1f, 1f, 0.92f, 0.82f, 0.62f, 0f)

        /** Blooming's blossoms as cx, cy, r. */
        val BLOSSOMS = arrayOf(
            floatArrayOf(29f, 37f, 1.6f),
            floatArrayOf(37f, 44f, 1.4f),
            floatArrayOf(47f, 20f, 1.6f),
            floatArrayOf(56f, 27f, 1.4f),
            floatArrayOf(69f, 31f, 1.6f),
            floatArrayOf(62f, 47f, 1.4f),
        )

        // M50 70 C49 62 46 58 47 50 C48 44 53 41 52 32
        val TRUNK = Path().apply {
            moveTo(50f, 70f)
            cubicTo(49f, 62f, 46f, 58f, 47f, 50f)
            cubicTo(48f, 44f, 53f, 41f, 52f, 32f)
        }

        // M47.5 52 C42 50 38 47 34 43
        val BRANCH_LEFT = Path().apply {
            moveTo(47.5f, 52f)
            cubicTo(42f, 50f, 38f, 47f, 34f, 43f)
        }

        // M51 43 C56 41 60 39 65 36
        val BRANCH_RIGHT = Path().apply {
            moveTo(51f, 43f)
            cubicTo(56f, 41f, 60f, 39f, 65f, 36f)
        }

        // M48.5 60 L46.5 63 M52 46 L54.2 48.4 M40 48 L38.6 46
        val CRACKS = Path().apply {
            moveTo(48.5f, 60f)
            lineTo(46.5f, 63f)
            moveTo(52f, 46f)
            lineTo(54.2f, 48.4f)
            moveTo(40f, 48f)
            lineTo(38.6f, 46f)
        }

        // M29 70 H71 L66.5 90 H33.5 Z
        val POT = Path().apply {
            moveTo(29f, 70f)
            lineTo(71f, 70f)
            lineTo(66.5f, 90f)
            lineTo(33.5f, 90f)
            close()
        }

        // M42 78.6 Q44 76.6 46 78.6 M54 78.6 Q56 76.6 58 78.6
        val EYES_CLOSED = Path().apply {
            moveTo(42f, 78.6f)
            quadTo(44f, 76.6f, 46f, 78.6f)
            moveTo(54f, 78.6f)
            quadTo(56f, 76.6f, 58f, 78.6f)
        }

        // M44 78 L44 78.4 M56 78 L56 78.4
        val EYES_OPEN = Path().apply {
            moveTo(44f, 78f)
            lineTo(44f, 78.4f)
            moveTo(56f, 78f)
            lineTo(56f, 78.4f)
        }

        // M44 78.4 L44 78.8 M56 78.4 L56 78.8 M41.6 75.6 L45.6 74.4 M58.4 75.6 L54.4 74.4
        val EYES_WORRIED = Path().apply {
            moveTo(44f, 78.4f)
            lineTo(44f, 78.8f)
            moveTo(56f, 78.4f)
            lineTo(56f, 78.8f)
            moveTo(41.6f, 75.6f)
            lineTo(45.6f, 74.4f)
            moveTo(58.4f, 75.6f)
            lineTo(54.4f, 74.4f)
        }

        /** MOUTH[tier]: a smile that flattens, then turns down. */
        val MOUTHS = listOf(
            mouth(45f, 82.5f, 50f, 87.5f, 55f), // M45 82.5 Q50 87.5 55 82.5
            mouth(46f, 83f, 50f, 86.5f, 54f), // M46 83 Q50 86.5 54 83
            mouth(47f, 83.5f, 50f, 85.2f, 53f), // M47 83.5 Q50 85.2 53 83.5
            Path().apply { // M46.5 84.2 L53.5 84.2
                moveTo(46.5f, 84.2f)
                lineTo(53.5f, 84.2f)
            },
            mouth(46.5f, 85.5f, 50f, 82.8f, 53.5f), // M46.5 85.5 Q50 82.8 53.5 85.5
            mouth(46f, 86f, 50f, 82.3f, 54f), // M46 86 Q50 82.3 54 86
        )

        /** `M x0 y Q cx cy x1 y`: the mouths are level quadratic curves. */
        fun mouth(x0: Float, y: Float, cx: Float, cy: Float, x1: Float) = Path().apply {
            moveTo(x0, y)
            quadTo(cx, cy, x1, y)
        }
    }
}
