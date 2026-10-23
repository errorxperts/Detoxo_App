package com.errorxperts.detoxo.overlay

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.PorterDuff
import android.graphics.PorterDuffColorFilter
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.drawable.Drawable
import android.util.Log
import com.errorxperts.detoxo.widget.blend
import com.errorxperts.detoxo.widget.withAlpha
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin

// The native Frozen Glass kit: what the block screen and the soft nudge draw
// with, from the generated DxTokens. The Flutter side is `GlassContainer` /
// `DxSurfacePainter`; both follow the same CSS rules.

// ── Pure helpers (file-level and free of Android types, so the JVM test loads them) ──

/**
 * The CSS gradient line of `linear-gradient(<angleDeg>deg, …)` over a [w] × [h]
 * box, as `x0, y0, x1, y1` (CSS Images 3: the corners take the end colours at
 * any aspect). 180° runs top to bottom, 145° is the card diagonal. Mirrors
 * Dart `cssLine`.
 */
internal fun cssLine(angleDeg: Float, w: Float, h: Float): FloatArray {
    val a = Math.toRadians(angleDeg.toDouble())
    val dx = sin(a)
    val dy = -cos(a)
    val half = (abs(w * sin(a)) + abs(h * cos(a))) / 2.0
    return floatArrayOf(
        (w / 2.0 - dx * half).toFloat(),
        (h / 2.0 - dy * half).toFloat(),
        (w / 2.0 + dx * half).toFloat(),
        (h / 2.0 + dy * half).toFloat(),
    )
}

/**
 * The `BlurMaskFilter` radius for a CSS blur of [cssBlur] px: the CSS blur is
 * a Gaussian sigma of blur / 2 (as the Flutter painter takes it), and HWUI
 * turns a radius into sigma as `0.57735 · r + 0.5`. No blur at sigma ≤ 0.5.
 * Not the bubble's own radius = 2 sigma convention; the bubble is separate.
 */
internal fun blurRadius(cssBlur: Float): Float {
    val sigma = cssBlur / 2f
    return if (sigma <= 0.5f) 0f else (sigma - 0.5f) / 0.57735f
}

/** The HSV hue of [argb] in degrees, 0 for a grey; Flutter's `HSVColor.fromColor(c).hue`. */
internal fun hueOf(argb: Int): Double {
    val r = ((argb shr 16) and 0xFF) / 255.0
    val g = ((argb shr 8) and 0xFF) / 255.0
    val b = (argb and 0xFF) / 255.0
    val hi = maxOf(r, g, b)
    val delta = hi - minOf(r, g, b)
    if (hi == 0.0 || delta == 0.0) return 0.0
    return when (hi) {
        r -> 60.0 * ((g - b) / delta).mod(6.0)
        g -> 60.0 * ((b - r) / delta + 2.0)
        else -> 60.0 * ((r - g) / delta + 4.0)
    }
}

/**
 * The CSS `hue-rotate(degrees) saturate(saturate)` filter chain as a 4 × 5
 * `ColorMatrix` array (Filter Effects 1): the hue matrix first, then
 * saturation, so `S · H`. Hand-built, because `ColorMatrix.setRotate` turns
 * the RGB axes and is not CSS hue-rotate. Mirrors Dart `accentIconMatrix`.
 */
internal fun hueRotateSaturate(degrees: Double, saturate: Double): FloatArray {
    val a = Math.toRadians(degrees)
    val c = cos(a)
    val s = sin(a)
    val hue = doubleArrayOf(
        0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928,
        0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, 0.072 - c * 0.072 - s * 0.283,
        0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072,
    )
    val k = saturate
    val sat = doubleArrayOf(
        0.213 + 0.787 * k, 0.715 - 0.715 * k, 0.072 - 0.072 * k,
        0.213 - 0.213 * k, 0.715 + 0.285 * k, 0.072 - 0.072 * k,
        0.213 - 0.213 * k, 0.715 - 0.715 * k, 0.072 + 0.928 * k,
    )
    val out = FloatArray(20)
    for (row in 0 until 3) {
        for (col in 0 until 3) {
            out[row * 5 + col] = (
                sat[row * 3] * hue[col] + sat[row * 3 + 1] * hue[3 + col] + sat[row * 3 + 2] * hue[6 + col]
                ).toFloat()
        }
    }
    out[18] = 1f
    return out
}

/**
 * The colour matrix that turns a blue 3D mode icon (hue `ICON_BASE_HUE`) to
 * the accent [main]: `hue-rotate(hue(main) − 214°) saturate(1.15)`, as the
 * app's `Icon3d(accentTint: true)` does.
 */
internal fun accentIconMatrix(main: Int, saturate: Float = DxTokens.ICON_SATURATE_ON): FloatArray =
    hueRotateSaturate(hueOf(main) - DxTokens.ICON_BASE_HUE, saturate.toDouble())

/**
 * A wall-clock label: "23:00" / "07:05" on a 24-hour clock ([is24]), else
 * "11 PM", "7:30 AM", "12 AM" — a zero minute dropped, as Dart's
 * `formatLocalTime` does, so a rule picked as "5:30 PM" reads back the same.
 */
internal fun clockLabel(hour: Int, minute: Int, is24: Boolean): String {
    if (is24) return "%02d:%02d".format(hour, minute)
    val h = if (hour % 12 == 0) 12 else hour % 12
    val suffix = if (hour < 12) "AM" else "PM"
    return if (minute == 0) "$h $suffix" else "$h:%02d $suffix".format(minute)
}

/** The four mode icons: the only ones the accent tints. */
internal val MODE_ICONS = setOf("icon-block-all", "icon-conscious", "icon-one-reel", "icon-pause")

/**
 * The wall's 3D icon (an `assets/images/icons/<name>.webp`) for a block
 * reason: a plan block shows its mode (an N-reel unblock is a break, so
 * Pause), the other reasons their feature. Pure; the Dart preview's
 * `heroIconFor` mirrors it.
 */
internal fun heroIconFor(reason: String, plan: String, allowance: Int): String = when (reason) {
    BlockScreenPayload.REASON_APP_BLOCK -> "icon-app-blocker"
    BlockScreenPayload.REASON_WEB_RULE, BlockScreenPayload.REASON_ADULT -> "icon-web-blocker"
    BlockScreenPayload.REASON_SCHEDULE, BlockScreenPayload.REASON_DAILY_LIMIT -> "icon-blocker-rules"
    else -> when (plan) {
        "CURIOUS" -> "icon-conscious"
        "ONE_REEL" -> if (allowance <= 1) "icon-one-reel" else "icon-pause"
        else -> "icon-block-all"
    }
}

/** What the wall's column shows: [maxLines] is `Int.MAX_VALUE` unless the quote is cut. */
internal data class WallFit(
    val header: Boolean,
    val well: Boolean,
    val headline: Boolean,
    val maxLines: Int,
    val writer: Boolean,
)

/**
 * Fits the wall's column into [room] px (above the line, the meta and the
 * buttons, which always show), shedding in order: the icon well, the quote's
 * title size for headline, quote lines (ellipsised), the writer, the header.
 * Each height includes its own gap; [headlineLine] is one headline line.
 * Pure, so landscape and 2× text are pinned on the JVM.
 */
internal fun wallFit(
    room: Float,
    header: Float,
    well: Float,
    titleQuote: Float,
    headlineQuote: Float,
    headlineLine: Float,
    writer: Float,
): WallFit {
    val all = Int.MAX_VALUE
    if (header + well + titleQuote + writer <= room) return WallFit(true, true, false, all, true)
    if (header + titleQuote + writer <= room) return WallFit(true, false, false, all, true)
    if (header + headlineQuote + writer <= room) return WallFit(true, false, true, all, true)
    fun lines(space: Float) = (space / headlineLine).toInt()
    if (lines(room - header - writer) >= 1) return WallFit(true, false, true, lines(room - header - writer), true)
    if (lines(room - header) >= 1) return WallFit(true, false, true, lines(room - header), false)
    return WallFit(false, false, true, lines(room).coerceAtLeast(1), false)
}

/** The ambient light's alpha at [distance] from its centre: [k] there, falling linearly to 0 at [radius]. */
internal fun ambientAlphaAt(distance: Float, radius: Float, k: Float): Float =
    k * (1f - distance / radius).coerceAtLeast(0f)

/** A slide confirms from this share of its travel (ConfirmSheet's threshold). */
internal const val SLIDE_THRESHOLD = 0.88f

internal fun slideConfirms(fraction: Float): Boolean = fraction >= SLIDE_THRESHOLD

/** Whole seconds still to wait with [leftMs] to go: 4001 ms is "5". */
internal fun waitSecondsLeft(leftMs: Long): Int = ceil(leftMs.coerceAtLeast(0L) / 1000.0).toInt()

/** [top] (translucent) composited over the opaque [bottom]: opaque. */
internal fun alphaOver(top: Int, bottom: Int): Int =
    blend(top or (0xFF shl 24), bottom, (top ushr 24) / 255f)

/** WCAG relative luminance of an ARGB colour (alpha ignored). */
private fun luminance(argb: Int): Double {
    fun channel(v: Int): Double {
        val c = v / 255.0
        return if (c <= 0.03928) c / 12.92 else ((c + 0.055) / 1.055).pow(2.4)
    }
    return 0.2126 * channel((argb shr 16) and 0xFF) +
        0.7152 * channel((argb shr 8) and 0xFF) +
        0.0722 * channel(argb and 0xFF)
}

/** WCAG contrast ratio between two opaque colours. */
internal fun contrastRatio(a: Int, b: Int): Double {
    val la = luminance(a)
    val lb = luminance(b)
    return (maxOf(la, lb) + 0.05) / (minOf(la, lb) + 0.05)
}

/** The DxTokens of one theme ([dark] or light), named as the Dart `AppTokens` fields. */
internal class DxTheme(val dark: Boolean) {
    val bgTop = if (dark) DxTokens.BG_TOP_DARK else DxTokens.BG_TOP_LIGHT
    val bgBottom = if (dark) DxTokens.BG_BOTTOM_DARK else DxTokens.BG_BOTTOM_LIGHT
    val ink = if (dark) DxTokens.INK_DARK else DxTokens.INK_LIGHT
    val ink2 = if (dark) DxTokens.INK_2_DARK else DxTokens.INK_2_LIGHT
    val panel = if (dark) {
        intArrayOf(DxTokens.PANEL_TOP_DARK, DxTokens.PANEL_BOTTOM_DARK)
    } else {
        intArrayOf(DxTokens.PANEL_TOP_LIGHT, DxTokens.PANEL_BOTTOM_LIGHT)
    }
    val glass = if (dark) {
        intArrayOf(DxTokens.GLASS_TOP_DARK, DxTokens.GLASS_BOTTOM_DARK)
    } else {
        intArrayOf(DxTokens.GLASS_TOP_LIGHT, DxTokens.GLASS_BOTTOM_LIGHT)
    }
    val sheet = if (dark) {
        intArrayOf(DxTokens.SHEET_TOP_DARK, DxTokens.SHEET_BOTTOM_DARK)
    } else {
        intArrayOf(DxTokens.SHEET_TOP_LIGHT, DxTokens.SHEET_BOTTOM_LIGHT)
    }
    val well = if (dark) {
        intArrayOf(DxTokens.WELL_FROM_DARK, DxTokens.WELL_TO_DARK)
    } else {
        intArrayOf(DxTokens.WELL_FROM_LIGHT, DxTokens.WELL_TO_LIGHT)
    }
    val pill = if (dark) {
        intArrayOf(DxTokens.PILL_HI_DARK, DxTokens.PILL_LO_DARK)
    } else {
        intArrayOf(DxTokens.PILL_HI_LIGHT, DxTokens.PILL_LO_LIGHT)
    }
    val track = if (dark) {
        intArrayOf(DxTokens.TRACK_FROM_DARK, DxTokens.TRACK_TO_DARK)
    } else {
        intArrayOf(DxTokens.TRACK_FROM_LIGHT, DxTokens.TRACK_TO_LIGHT)
    }
    val fillQuiet = if (dark) DxTokens.FILL_QUIET_DARK else DxTokens.FILL_QUIET_LIGHT
    val optionBase = if (dark) DxTokens.OPTION_BASE_DARK else DxTokens.OPTION_BASE_LIGHT
    val knob = if (dark) DxTokens.KNOB_DARK else DxTokens.KNOB_LIGHT
    val kAmb = if (dark) DxTokens.K_AMB_DARK else DxTokens.K_AMB_LIGHT
    val kPill = if (dark) DxTokens.K_PILL_DARK else DxTokens.K_PILL_LIGHT
    val kPillGlow = if (dark) DxTokens.K_PILL_GLOW_DARK else DxTokens.K_PILL_GLOW_LIGHT
    val shadowCard = if (dark) DxTokens.SHADOW_CARD_DARK else DxTokens.SHADOW_CARD_LIGHT
    val shadowGlass = if (dark) DxTokens.SHADOW_GLASS_DARK else DxTokens.SHADOW_GLASS_LIGHT
    val pillEdge = if (dark) DxTokens.SHADOW_PILL_EDGE_DARK else DxTokens.SHADOW_PILL_EDGE_LIGHT
    val trackShadow = if (dark) DxTokens.SHADOW_TRACK_SHADOW_DARK else DxTokens.SHADOW_TRACK_SHADOW_LIGHT
    val logoGlow = if (dark) DxTokens.SHADOW_LOGO_GLOW_DARK else DxTokens.SHADOW_LOGO_GLOW_LIGHT

    /**
     * The slide's waiting knob, mirroring Dart `ConfirmSheet.waitKnob`. Light:
     * the knob at 55 % over the track. Dark: the track mixed 18 % toward the
     * knob, because the knob at 55 % leaves the countdown at 2:1 there.
     */
    val waitKnob = if (dark) {
        blend(DxTokens.KNOB_DARK, DxTokens.TRACK_TO_DARK, 0.18f)
    } else {
        withAlpha(DxTokens.KNOB_LIGHT, (0.55f * 255f).roundToInt())
    }

    /**
     * The sheet colours composited opaque over the ground's ends: the soft
     * nudge's card, which sits over a third-party feed, where translucent
     * glass could not promise 4.5:1.
     */
    val opaqueSheet = intArrayOf(alphaOver(sheet[0], bgTop), alphaOver(sheet[1], bgBottom))

    /** The accent pill (`.dx-pill`) over [accent]: its edge plus the accent glow at (0, 10) blur 24. */
    fun pillShadows(accent: Int): Array<DxShadowLayer> = pillEdge +
        DxShadowLayer(withAlpha(accent, (kPillGlow * 255f).roundToInt()), 0f, 10f, 24f, 0f, false)
}

// ── Drawing ──────────────────────────────────────────────────────────────────

/**
 * One Frozen Glass surface as a Drawable, the native `DxSurfacePainter`:
 * [base] (a solid colour, 0 = none), then [fill] as a linear gradient along
 * the CSS line of [angleDeg] (one colour = solid; [stops] optional), with the
 * CSS [shadows] in their recipe order (the first paints on top). Corners are
 * [radiusPx], capped at half the short side (a pill or circle). The surface
 * sits [inset] px inside the bounds, so a 48 dp view can draw a 44 dp control.
 *
 * Everything is built in [onBoundsChange]; [draw] allocates nothing.
 * - Inset layers with no blur are exact hairlines: the shape minus itself
 *   shifted and shrunk (`Path.op`), on the hardware canvas.
 * - Every blurred layer is drawn once into a half-scale ARGB bitmap on a
 *   software Canvas — outer layers clipped outside the shape, inset ones
 *   inside it — and drawn upscaled. `BlurMaskFilter` is ignored on the
 *   hardware canvas below API 28; one path for every API level.
 *
 * No backdrop blur at any level: behind every surface is the wall's own
 * gradient, where a blur is invisible, and a cross-window blur would show the
 * blocked app. ponytail: add `RenderEffect` on API 31+ if imagery ever sits
 * behind a surface. The bitmaps go when the drawable is hidden (a view
 * detaching hides its background) and come back on the next show.
 */
internal class DxDrawable(
    private val fill: IntArray,
    private val radiusPx: Float,
    private val shadows: Array<DxShadowLayer>,
    private val density: Float,
    private val angleDeg: Float = 180f,
    private val base: Int = 0,
    private val stops: FloatArray? = null,
    private val inset: Rect = Rect(),
) : Drawable() {

    private val shape = RectF()
    private var radius = 0f
    private val basePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = base }
    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val bitmapPaint = Paint(Paint.FILTER_BITMAP_FLAG)
    private var hairlines: Array<Path> = emptyArray()
    private var hairlinePaints: Array<Paint> = emptyArray()
    private var outer: Bitmap? = null
    private val outerAt = RectF()
    private var inner: Bitmap? = null

    override fun onBoundsChange(bounds: Rect) {
        build(bounds)
    }

    private fun build(bounds: Rect) {
        outer = null
        inner = null
        shape.set(
            (bounds.left + inset.left).toFloat(),
            (bounds.top + inset.top).toFloat(),
            (bounds.right - inset.right).toFloat(),
            (bounds.bottom - inset.bottom).toFloat(),
        )
        val w = shape.width()
        val h = shape.height()
        if (w <= 0f || h <= 0f) return
        radius = min(radiusPx, min(w, h) / 2f)
        if (fill.size == 1) {
            fillPaint.shader = null
            fillPaint.color = fill[0]
        } else if (fill.size > 1) {
            val l = cssLine(angleDeg, w, h)
            fillPaint.shader = LinearGradient(
                shape.left + l[0], shape.top + l[1], shape.left + l[2], shape.top + l[3],
                fill, stops, Shader.TileMode.CLAMP,
            )
        }

        val lines = shadows.filter { it.inset && it.blur == 0f }.reversed()
        val box = Path().apply { addRoundRect(shape, radius, radius, Path.Direction.CW) }
        val hole = RectF()
        hairlines = Array(lines.size) { i ->
            val r = holeOf(shape, lines[i], hole)
            val inside = Path().apply { addRoundRect(hole, r, r, Path.Direction.CW) }
            Path().apply { op(box, inside, Path.Op.DIFFERENCE) }
        }
        hairlinePaints = Array(lines.size) { i ->
            Paint(Paint.ANTI_ALIAS_FLAG).apply { color = lines[i].color }
        }

        val outs = shadows.filter { !it.inset }.reversed()
        if (outs.isNotEmpty()) {
            val pad = outs.maxOf { reach(it) }
            outerAt.set(shape.left - pad, shape.top - pad, shape.right + pad, shape.bottom + pad)
            val body = RectF(pad, pad, pad + w, pad + h)
            outer = layer(outerAt.width(), outerAt.height()) { c ->
                for (s in outs) {
                    val spread = s.spread * density
                    val r = RectF(body).apply {
                        offset(s.x * density, s.y * density)
                        inset(-spread, -spread)
                    }
                    val rr = max(0f, radius + spread) * SCALE
                    c.drawRoundRect(scaled(r), rr, rr, paint(s))
                }
                // Outer layers live outside the shape only: a translucent fill
                // is never darkened by its own shadow.
                c.drawRoundRect(scaled(body), radius * SCALE, radius * SCALE, CLEAR)
            }
        }

        val ins = shadows.filter { it.inset && it.blur > 0f }.reversed()
        if (ins.isNotEmpty()) {
            val local = RectF(0f, 0f, w, h)
            inner = layer(w, h) { c ->
                for (s in ins) {
                    // Everything outside the layer's hole, blurred, then kept inside the shape.
                    val r = holeOf(local, s, hole) * SCALE
                    val far = reach(s)
                    val ring = Path().apply {
                        fillType = Path.FillType.EVEN_ODD
                        addRect(scaled(RectF(-far, -far, w + far, h + far)), Path.Direction.CW)
                        addRoundRect(scaled(hole), r, r, Path.Direction.CW)
                    }
                    c.drawPath(ring, paint(s))
                }
                val outside = Path().apply {
                    fillType = Path.FillType.EVEN_ODD
                    addRect(scaled(RectF(-1f, -1f, w + 1f, h + 1f)), Path.Direction.CW)
                    addRoundRect(scaled(local), radius * SCALE, radius * SCALE, Path.Direction.CW)
                }
                c.drawPath(outside, CLEAR)
            }
        }
    }

    /** How far layer [s] can paint from its shape, in px: its blur's 3 sigma, offset and spread. */
    private fun reach(s: DxShadowLayer): Float =
        (1.5f * s.blur + max(abs(s.x), abs(s.y)) + abs(s.spread)) * density + 1f

    /**
     * The inside edge of inset layer [s] on [r] into [out] — shifted by its
     * offset, shrunk by its spread — returning its corner radius.
     */
    private fun holeOf(r: RectF, s: DxShadowLayer, out: RectF): Float {
        val spread = s.spread * density
        out.set(r)
        out.offset(s.x * density, s.y * density)
        out.inset(spread, spread)
        return max(0f, radius - spread)
    }

    private fun layer(w: Float, h: Float, paint: (Canvas) -> Unit): Bitmap? = try {
        Bitmap.createBitmap(
            ceil(w * SCALE).toInt().coerceAtLeast(1),
            ceil(h * SCALE).toInt().coerceAtLeast(1),
            Bitmap.Config.ARGB_8888,
        ).also { paint(Canvas(it)) }
    } catch (t: OutOfMemoryError) {
        Log.w(TAG, "shadow bitmap skipped: ${t.message}")
        null
    }

    private fun scaled(r: RectF) = RectF(r.left * SCALE, r.top * SCALE, r.right * SCALE, r.bottom * SCALE)

    private fun paint(s: DxShadowLayer) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = s.color
        val r = blurRadius(s.blur * density * SCALE)
        if (r > 0f) maskFilter = BlurMaskFilter(r, BlurMaskFilter.Blur.NORMAL)
    }

    override fun draw(canvas: Canvas) {
        outer?.let { canvas.drawBitmap(it, null, outerAt, bitmapPaint) }
        if (base != 0) canvas.drawRoundRect(shape, radius, radius, basePaint)
        if (fill.isNotEmpty()) canvas.drawRoundRect(shape, radius, radius, fillPaint)
        inner?.let { canvas.drawBitmap(it, null, shape, bitmapPaint) }
        for (i in hairlines.indices) canvas.drawPath(hairlines[i], hairlinePaints[i])
    }

    override fun setVisible(visible: Boolean, restart: Boolean): Boolean {
        val changed = super.setVisible(visible, restart)
        if (!visible) {
            outer = null
            inner = null
        } else if (changed && !bounds.isEmpty) {
            build(bounds)
        }
        return changed
    }

    // ponytail: the wall's controls fade through their view's alpha, so nothing
    // sets a drawable alpha; a Paint.alpha here would overwrite each recipe
    // colour's own. Modulate the stored colours if a caller ever needs it.
    override fun setAlpha(alpha: Int) = Unit

    override fun setColorFilter(colorFilter: ColorFilter?) {
        for (p in arrayOf(basePaint, fillPaint, bitmapPaint) + hairlinePaints) p.colorFilter = colorFilter
        invalidateSelf()
    }

    @Deprecated("Deprecated in Java")
    override fun getOpacity(): Int = PixelFormat.TRANSLUCENT

    private companion object {
        const val TAG = "DxDrawable"

        /** The blurred layers' bitmap scale: a blur hides it, and memory stays small. */
        const val SCALE = 0.5f

        val CLEAR = Paint(Paint.ANTI_ALIAS_FLAG).apply { xfermode = PorterDuffXfermode(PorterDuff.Mode.CLEAR) }
    }
}

/**
 * The spec art the wall draws, decoded once per process from the Flutter
 * assets (the `widget/Manrope.kt` pattern): the 192² 3D icons and the
 * 100 × 192 logo, WebP with alpha (BitmapFactory reads it from API 24).
 * A missing or undecodable file is null: the wall then draws no icon or no
 * logo — it never fails. Main thread only, like the overlay that asks.
 */
internal object DxArt {
    private const val TAG = "DxArt"
    private const val DIR = "flutter_assets/assets/images/icons"

    private val bitmaps = HashMap<String, Bitmap?>()
    private val glows = HashMap<Boolean, Array<Glow>>()

    /** A logo glow layer: [mask] (alpha only) at ([dx], [dy]) logo pixels from the logo, in [paint]'s colour. */
    class Glow(val mask: Bitmap, val dx: Float, val dy: Float, val paint: Paint)

    /** `assets/images/icons/<name>.webp`. */
    fun icon(context: Context, name: String): Bitmap? = icon(context, name, "$name.webp")

    /** `assets/images/icons/detoxo_logo.png`: near-white, tinted per theme by [logoTint]. */
    fun logo(context: Context): Bitmap? = icon(context, "detoxo_logo", "detoxo_logo.png")

    /** The logo's blend colour (multiply), as Dart's `DetoxoLogo.tintOf`: brand-main in Light, none in Dark. */
    fun logoTint(dark: Boolean): ColorFilter? =
        if (dark) null else PorterDuffColorFilter(DxTokens.BRAND_MAIN_LIGHT, PorterDuff.Mode.MULTIPLY)

    private fun icon(context: Context, key: String, file: String): Bitmap? =
        bitmaps.getOrPut(key) { decode(context, file) }

    /**
     * The logo's `logo-glow` for [dark] as drawn at [drawnHeightPx]: each layer
     * a blurred copy of the logo's alpha (CSS `drop-shadow`), never a recolour
     * of the logo itself. Built once per process per theme, in the logo's own
     * pixels, so the caller maps them with the logo.
     */
    fun logoGlow(context: Context, dark: Boolean, drawnHeightPx: Float): Array<Glow> = glows.getOrPut(dark) {
        val logo = logo(context) ?: return@getOrPut emptyArray()
        // CSS lengths are dp at the drawn size; the masks are in logo pixels.
        val k = logo.height / drawnHeightPx * context.resources.displayMetrics.density
        val layers = if (dark) DxTokens.SHADOW_LOGO_GLOW_DARK else DxTokens.SHADOW_LOGO_GLOW_LIGHT
        layers.reversed().filter { (it.color ushr 24) > 0 }.mapNotNull { s ->
            try {
                val at = IntArray(2)
                val r = blurRadius(s.blur * k)
                val blur = Paint().apply { if (r > 0f) maskFilter = BlurMaskFilter(r, BlurMaskFilter.Blur.NORMAL) }
                val mask = logo.extractAlpha(blur, at)
                Glow(
                    mask,
                    at[0] + s.x * k,
                    at[1] + s.y * k,
                    Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply { color = s.color },
                )
            } catch (t: Throwable) {
                Log.w(TAG, "logo glow skipped: ${t.message}")
                null
            }
        }.toTypedArray()
    }

    private fun decode(context: Context, file: String): Bitmap? = try {
        context.assets.open("$DIR/$file").use { BitmapFactory.decodeStream(it) }
    } catch (t: Throwable) {
        Log.w(TAG, "$file unreadable: ${t.message}")
        null
    }
}
