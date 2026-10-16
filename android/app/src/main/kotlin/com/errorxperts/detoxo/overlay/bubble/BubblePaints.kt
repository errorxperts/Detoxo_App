package com.errorxperts.detoxo.overlay.bubble

import android.content.Context
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Region
import android.graphics.Shader
import android.os.Build
import android.util.SparseArray
import com.errorxperts.detoxo.widget.Manrope
import com.errorxperts.detoxo.widget.withAlpha
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

/** Board path data (SVG `d` strings) shared by the shell and the faces; box sizes noted per path. */
internal object BubblePaths {
    /** The hourglass timer mark, a 40 × 64 box. */
    const val MARK =
        "M9 3 H31 Q37 3 37 9 V17 Q37 23 30 29 L27 32 L30 35 Q37 41 37 47 V55 Q37 61 31 61 " +
            "H9 Q3 61 3 55 V47 Q3 41 10 35 L13 32 L10 29 Q3 23 3 17 V9 Q3 3 9 3 Z"

    /** The Hourglass face's big glass, the 68 board box. */
    const val HOURGLASS_BIG =
        "M26 12 H42 Q46 12 46 16 V22 Q46 26 41 30 L39 32 L41 34 Q46 38 46 42 V50 Q46 54 42 54 " +
            "H26 Q22 54 22 50 V42 Q22 38 27 34 L29 32 L27 30 Q22 26 22 22 V16 Q22 12 26 12 Z"

    /** Clip for [HOURGLASS_BIG]'s top bulb, 68 box. */
    const val CLIP_TOP = "M23 13 H45 V24 Q45 27 40 31 L34 32 L28 31 Q23 27 23 24 Z"

    /** Clip for [HOURGLASS_BIG]'s bottom bulb, 68 box. */
    const val CLIP_BOTTOM = "M23 53 H45 V40 Q45 37 40 33 L34 32 L28 33 Q23 37 23 40 Z"

    /** Mascot: the raised hand (tier 5), 68 board box. */
    const val MASCOT_HAND =
        "M48 54 v-10 q0-2 2-2 q2 0 2 2 v6 v-9 q0-2 2-2 q2 0 2 2 v9 v-8 q0-2 2-2 q2 0 2 2 v8 v-5 " +
            "q0-2 2-2 q2 0 2 2 v9 q0 8-8 8 h-2 q-6 0-6-6z"

    /** Mascot: the sweat drop (tiers 3, 4), 68 box. */
    const val MASCOT_SWEAT = "M52 20 q3 5 0 8 q-3 -3 0 -8z"

    /** Mascot: the two tear lines (tiers 4, 5), 68 box. */
    const val MASCOT_TEARS = "M21 38 q-1 6 0 10 M47 38 q1 6 0 10"

    private const val BROWS_CALM = "M19 22 q6 -4 12 -1 M37 21 q6 -3 12 1"
    private const val BROWS_WIDE = "M19 20 q6 -5 12 -2 M37 18 q6 -3 12 2"
    private const val BROWS_WORRIED = "M19 20 q6 2 12 3 M37 23 q6 -1 12 -3"
    private const val BROWS_DISTRESSED = "M19 19 q6 3 12 5 M37 24 q6 -2 12 -5"

    /** Mascot brows per mood (= tier 0..5), 68 box. */
    val MASCOT_BROWS = arrayOf(
        BROWS_CALM, BROWS_CALM, BROWS_WIDE, BROWS_WORRIED, BROWS_DISTRESSED, BROWS_DISTRESSED,
    )

    /** Mascot mouths per mood, 68 box; mood 2 is an oval (no path; the face draws it), hence "". */
    val MASCOT_MOUTHS = arrayOf(
        "M26 42 q8 8 16 0", "M25 41 q9 10 18 0", "", "M27 44 h14", "M26 46 q8 -7 16 0", "M26 47 q8 -8 16 0",
    )
}

/**
 * The bubble's reusable drawing kit, twin of the Dart `BubbleBrush`. Every call takes the
 * [Canvas]; geometry arguments are view px unless a parameter says board units. Paints, paths
 * and blur filters are allocated once and reused; parsed SVG paths are cached per `d` string.
 * The body gradient shader is rebuilt only when its colours or rect change (the cross-fade and
 * the capsule spring). Blurs ([BlurMaskFilter]) need the software layer the view runs on.
 *
 * Blur convention: where the spec or the Dart twin gives a blur **sigma**, the native
 * [BlurMaskFilter] radius is `sigma × 2`. [blur] and [text]'s `glowPx` both take the radius
 * (a face's `countGlow` is already the board's CSS blur radius).
 *
 * [opacity] (0.5..1, the user's setting) scales the body fill's alpha only (spec D2).
 */
internal class BubblePaints(context: Context, private val opacity: Float) {
    private val bold = Manrope.bold(context)
    private val extraBold = Manrope.extraBold(context)

    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { isDither = true }
    private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeJoin = Paint.Join.ROUND
    }

    // Linear metrics: advances and letter spacing stay exact at any scaled size (as WidgetPainter).
    private val type = Paint(Paint.ANTI_ALIAS_FLAG or Paint.SUBPIXEL_TEXT_FLAG or Paint.LINEAR_TEXT_FLAG).apply {
        fontFeatureSettings = "'tnum'"
        textAlign = Paint.Align.CENTER
    }
    private val metrics = Paint.FontMetrics()

    private val bodyPath = Path()
    private val scratch = Path()
    private val radii = FloatArray(8)
    private val rect = RectF()
    private val svgCache = HashMap<String, Path>()
    private val blurs = SparseArray<BlurMaskFilter>()

    private var gradient: Shader? = null
    private var gradientFrom = 0
    private var gradientTo = 0
    private val gradientRect = RectF()

    /** The shared fill paint set to [color] (no shader, no blur) — e.g. for [path]. */
    fun solid(color: Int): Paint = fillPaint.apply {
        shader = null
        maskFilter = null
        this.color = color
    }

    /** The shared stroke paint set to [color], [widthPx] (in the units of the canvas it draws on) and [cap]. */
    fun pen(color: Int, widthPx: Float, cap: Paint.Cap = Paint.Cap.ROUND): Paint = strokePaint.apply {
        shader = null
        maskFilter = null
        this.color = color
        strokeWidth = widthPx
        strokeCap = cap
    }

    /** A normal blur of **radius** [px] (cached per 0.1 px; sigma × 2, see the class KDoc); [px] must be > 0. */
    fun blur(px: Float): BlurMaskFilter {
        val key = (px * 10f).roundToInt().coerceAtLeast(1)
        return blurs[key] ?: BlurMaskFilter(key / 10f, BlurMaskFilter.Blur.NORMAL).also { blurs.put(key, it) }
    }

    /** Advance of [s] at [sizePx] in the same Manrope paint [text] uses (weight 800, or 700 when not [extraBold]). */
    fun textWidth(s: String, sizePx: Float, extraBold: Boolean = true): Float {
        type.typeface = if (extraBold) this.extraBold else bold
        type.textSize = sizePx
        type.letterSpacing = 0f
        return type.measureText(s)
    }

    /** [color] with its alpha scaled by the user's body opacity (what [shell] does to its fills). */
    fun fade(color: Int): Int = faded(color)

    /** The parsed path for SVG data [d] (board units), cached; for clips and custom draws. */
    fun svg(d: String): Path = svgCache.getOrPut(d) { SvgPath.path(d) }

    /**
     * The body shape of [f] grown by [outsetPx] (negative shrinks), written into [into]
     * (default: a scratch path valid until the next call that uses it). Corners on the docked
     * edge get [radiusEdge], the others [radiusOuter] (board units; each moves with the outset).
     */
    fun shape(
        f: BubbleFrame,
        outsetPx: Float = 0f,
        radiusOuter: Float = 34f,
        radiusEdge: Float = 34f,
        into: Path = scratch,
    ): Path {
        val outer = (radiusOuter * f.s + outsetPx).coerceAtLeast(0f)
        val edge = (radiusEdge * f.s + outsetPx).coerceAtLeast(0f)
        val left = if (f.dockedRight) outer else edge
        val right = if (f.dockedRight) edge else outer
        // top-left, top-right, bottom-right, bottom-left (x, y each)
        radii[0] = left; radii[1] = left
        radii[2] = right; radii[3] = right
        radii[4] = right; radii[5] = right
        radii[6] = left; radii[7] = left
        val b = f.body
        rect.set(b.left - outsetPx, b.top - outsetPx, b.right + outsetPx, b.bottom + outsetPx)
        into.rewind()
        into.addRoundRect(rect, radii, Path.Direction.CW)
        return into
    }

    /**
     * The default body: soft shadow ([shadow], sigma 6·s = blur radius 12·s, dy 3·s) and the 7·s
     * [halo] band, both outside the body only (CSS box-shadow is not drawn under the box); then
     * the 160° gradient [fillFrom] → [fillTo] at alpha × opacity; then the 1.5·s [ring] band just
     * OUTSIDE the body edge (0..1.5·s out) and the 1.5·s white hairline just INSIDE it (0..1.5·s
     * in; alpha .95 at tier 0, .55 above, cross-faded with the tier). Null colours fall back to
     * [BubbleFrame.look].
     */
    fun shell(
        c: Canvas,
        f: BubbleFrame,
        fillFrom: Int? = null,
        fillTo: Int? = null,
        radiusOuter: Float = 34f,
        radiusEdge: Float = 34f,
        ring: Int? = null,
        halo: Int? = null,
        shadow: Int? = null,
    ) {
        val l = f.look
        val body = shape(f, 0f, radiusOuter, radiusEdge, bodyPath)

        c.save()
        clipOut(c, body)
        solid(shadow ?: l.shadow).maskFilter = blur(12f * f.s) // sigma 6·s
        c.save()
        c.translate(0f, 3f * f.s)
        c.drawPath(body, fillPaint)
        c.restore()
        c.drawPath(shape(f, 7f * f.s, radiusOuter, radiusEdge), solid(halo ?: l.halo))
        c.restore()

        // Opaque paint colour: a shader is modulated by the paint's alpha (the halo's, until now).
        solid(WHITE).shader = bodyGradient(f.body, faded(fillFrom ?: l.fillFrom), faded(fillTo ?: l.fillTo))
        c.drawPath(body, fillPaint)
        fillPaint.shader = null

        val hw = 1.5f * f.s
        // Drawn after the clip is restored: the ring sits on top of the halo, outside the body.
        c.drawPath(shape(f, hw / 2f, radiusOuter, radiusEdge), pen(ring ?: l.ring, hw))
        val hair = hairAlpha(f.prevTier) + (hairAlpha(f.tier) - hairAlpha(f.prevTier)) * f.blend
        c.drawPath(shape(f, -hw / 2f, radiusOuter, radiusEdge), pen(withAlpha(WHITE, (hair * 255f).roundToInt()), hw))
    }

    /**
     * [s] centred on ([cx], [cy]) (vertically by the font metrics), Manrope 800 (or 700 when
     * not [extraBold]) at [sizePx] × [scale], [letterSpacing] in px, [color] at × [alpha]. A
     * [glowPx] > 0 (a blur **radius** in px, e.g. `face.countGlow · s`) first draws the same
     * text blurred in [glowColor] (0 = [color]).
     */
    fun text(
        c: Canvas,
        s: String,
        cx: Float,
        cy: Float,
        sizePx: Float,
        color: Int,
        extraBold: Boolean = true,
        scale: Float = 1f,
        letterSpacing: Float = 0f,
        alpha: Float = 1f,
        glowPx: Float = 0f,
        glowColor: Int = 0,
    ) {
        val size = sizePx * scale
        if (size <= 0f || alpha <= 0f) return
        type.typeface = if (extraBold) this.extraBold else bold
        type.textSize = size
        type.letterSpacing = letterSpacing / sizePx // em, so it scales with the text
        type.getFontMetrics(metrics)
        val baseline = cy - (metrics.ascent + metrics.descent) / 2f
        if (glowPx > 0f) {
            type.color = faded(if (glowColor == 0) color else glowColor, alpha)
            type.maskFilter = blur(glowPx)
            c.drawText(s, cx, baseline, type)
            type.maskFilter = null
        }
        type.color = faded(color, alpha)
        c.drawText(s, cx, baseline, type)
    }

    /**
     * The hourglass mark ([BubblePaths.MARK], a 40 × 64 box) scaled into [w] × [h] at
     * ([left], [top]): [fill] (null = none), a [stroke] outline 4 box units wide, the two
     * resting grains in [stroke], and — when [grainT] is set (0..1 loop phase) — the falling
     * grain at y −6 + 16·[grainT] fading in and out as sin(π·[grainT]). All at × [alpha].
     */
    @Suppress("UNUSED_PARAMETER") // f: kept for parity with the Dart `BubbleBrush.mark`
    fun mark(
        c: Canvas,
        f: BubbleFrame,
        left: Float,
        top: Float,
        w: Float,
        h: Float,
        fill: Int?,
        stroke: Int,
        grainT: Float?,
        alpha: Float = 1f,
    ) {
        if (alpha <= 0f) return
        val mark = svg(BubblePaths.MARK)
        c.save()
        c.translate(left, top)
        c.scale(w / 40f, h / 64f)
        if (fill != null) c.drawPath(mark, solid(faded(fill, alpha)))
        c.drawPath(mark, pen(faded(stroke, alpha), 4f))
        val resting = solid(faded(stroke, alpha))
        grain(c, 15.5f, 12f, 9f, 2.2f, 20f, 16.5f, resting)
        grain(c, 14.5f, 44f, 11f, 2.6f, 20f, 49.5f, resting)
        if (grainT != null) {
            val a = sin(PI * grainT).toFloat().coerceIn(0f, 1f)
            c.translate(0f, -6f + 16f * grainT)
            grain(c, 17.8f, 27.8f, 4.4f, 1.1f, 20f, 30f, solid(faded(stroke, alpha * a)))
        }
        c.restore()
    }

    /** [d] (board units, cached) drawn with [paint] at ([ox], [oy]) scaled by [scale]. */
    fun path(c: Canvas, d: String, ox: Float, oy: Float, scale: Float, paint: Paint) {
        c.save()
        c.translate(ox, oy)
        c.scale(scale, scale)
        c.drawPath(svg(d), paint)
        c.restore()
    }

    /** A disc ([strokePx] 0) or a ring of that width. */
    fun circle(c: Canvas, cx: Float, cy: Float, r: Float, color: Int, strokePx: Float = 0f) {
        c.drawCircle(cx, cy, r, paintFor(color, strokePx))
    }

    /** A round-capped arc on the circle ([cx], [cy], [r]) from [startDeg] (0 = 3 o'clock) sweeping [sweepDeg] clockwise. */
    fun arc(c: Canvas, cx: Float, cy: Float, r: Float, startDeg: Float, sweepDeg: Float, color: Int, strokePx: Float) {
        rect.set(cx - r, cy - r, cx + r, cy + r)
        c.drawArc(rect, startDeg, sweepDeg, false, pen(color, strokePx))
    }

    /** A rounded rect, filled ([strokePx] 0) or outlined with that width. */
    fun roundRect(c: Canvas, l: Float, t: Float, r: Float, b: Float, radius: Float, color: Int, strokePx: Float = 0f) {
        c.drawRoundRect(l, t, r, b, radius, radius, paintFor(color, strokePx))
    }

    /** A round-capped line. */
    fun line(c: Canvas, x0: Float, y0: Float, x1: Float, y1: Float, color: Int, strokePx: Float) {
        c.drawLine(x0, y0, x1, y1, pen(color, strokePx))
    }

    private fun paintFor(color: Int, strokePx: Float): Paint =
        if (strokePx > 0f) pen(color, strokePx) else solid(color)

    /** A [size] square grain at ([l], [t]) with corner [r], rotated 45° about ([px], [py]). */
    private fun grain(c: Canvas, l: Float, t: Float, size: Float, r: Float, px: Float, py: Float, paint: Paint) {
        c.save()
        c.rotate(45f, px, py)
        c.drawRoundRect(l, t, l + size, t + size, r, r, paint)
        c.restore()
    }

    /** The 160° CSS linear gradient over [b], rebuilt only when the colours or rect change. */
    private fun bodyGradient(b: RectF, from: Int, to: Int): Shader {
        val cached = gradient
        if (cached != null && from == gradientFrom && to == gradientTo && b == gradientRect) return cached
        // CSS: the line runs along (sin θ, −cos θ) through the centre, |w·sin θ| + |h·cos θ| long.
        val half = (abs(b.width() * SIN_160) + abs(b.height() * COS_160)) / 2f
        val dx = SIN_160 * half
        val dy = -COS_160 * half
        val shader = LinearGradient(
            b.centerX() - dx, b.centerY() - dy, b.centerX() + dx, b.centerY() + dy,
            from, to, Shader.TileMode.CLAMP,
        )
        gradientFrom = from
        gradientTo = to
        gradientRect.set(b)
        gradient = shader
        return shader
    }

    /** [color] with its alpha × [alpha] (default: the body-fill opacity). */
    private fun faded(color: Int, alpha: Float = opacity): Int =
        if (alpha >= 1f) color else withAlpha(color, ((color ushr 24) * alpha).roundToInt().coerceIn(0, 255))

    private fun hairAlpha(tier: Int) = if (tier == 0) 0.95f else 0.55f

    /** Clip [c] to everything outside [p]. */
    fun clipOut(c: Canvas, p: Path) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            c.clipOutPath(p)
        } else {
            @Suppress("DEPRECATION")
            c.clipPath(p, Region.Op.DIFFERENCE)
        }
    }

    private companion object {
        const val WHITE = 0xFFFFFFFF.toInt()
        val SIN_160 = sin(160.0 * PI / 180.0).toFloat()
        val COS_160 = cos(160.0 * PI / 180.0).toFloat()
    }
}

/** A shader cached until its colours or rect change (faces rebuild it only while the tier cross-fades or the level moves). */
internal class GradientCache {
    private var shader: Shader? = null
    private var from = 0
    private var to = 0
    private val at = RectF()
    private var diagonal = false

    /** Top → bottom over [top]..[bottom] at x = [x]. */
    fun vertical(x: Float, top: Float, bottom: Float, from: Int, to: Int): Shader {
        val s = shader
        if (s != null && !diagonal && at.left == x && from == this.from && to == this.to && at.top == top && at.bottom == bottom) return s
        return remember(LinearGradient(x, top, x, bottom, from, to, Shader.TileMode.CLAMP), from, to, x, top, x, bottom, false)
    }

    /** The CSS 160° gradient over [b]. */
    fun css160(b: RectF, from: Int, to: Int): Shader {
        val s = shader
        if (s != null && diagonal && from == this.from && to == this.to && at == b) return s
        val half = (abs(b.width() * SIN_160) + abs(b.height() * COS_160)) / 2f
        val dx = SIN_160 * half
        val dy = -COS_160 * half
        return remember(
            LinearGradient(b.centerX() - dx, b.centerY() - dy, b.centerX() + dx, b.centerY() + dy, from, to, Shader.TileMode.CLAMP),
            from, to, b.left, b.top, b.right, b.bottom, true,
        )
    }

    private fun remember(s: Shader, from: Int, to: Int, l: Float, t: Float, r: Float, b: Float, diag: Boolean): Shader {
        this.from = from; this.to = to; at.set(l, t, r, b); diagonal = diag; shader = s
        return s
    }

    private companion object {
        val SIN_160 = sin(160.0 * PI / 180.0).toFloat()
        val COS_160 = cos(160.0 * PI / 180.0).toFloat()
    }
}
