package com.errorxperts.detoxo.overlay

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Camera
import android.graphics.Canvas
import android.graphics.ComposeShader
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffColorFilter
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
import android.util.Log
import android.util.TypedValue
import android.view.MotionEvent
import android.view.View
import android.view.animation.PathInterpolator
import com.errorxperts.detoxo.R
import com.errorxperts.detoxo.widget.Manrope
import com.errorxperts.detoxo.widget.withAlpha
import kotlin.math.PI
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sin

// ── Pure maths (file-level and free of Android objects, so the JVM test loads it) ──

/**
 * The Face Down card's Y rotation in degrees at [t] ∈ [0, 1) of its 8 s loop —
 * the board's keyframes: face up until 30 %, face down by 42 %, held to 82 %,
 * home by 94 %. [ease] is the board's cubic-bezier(.6, 0, .3, 1), applied per
 * segment and passed in so this stays pure. Inline, so the per-frame call
 * allocates no function object and boxes nothing.
 */
internal inline fun flipDegrees(t: Float, ease: (Float) -> Float): Float = when {
    t < 0.30f -> 0f
    t < 0.42f -> 180f * ease((t - 0.30f) / 0.12f)
    t < 0.82f -> 180f
    t < 0.94f -> 180f + 180f * ease((t - 0.82f) / 0.12f)
    else -> 360f
}

/** Spotlight's glow at the light's centre: the accent at α .14. */
internal const val GLOW_ALPHA = 0x24

/**
 * The big logo's peak under the light (α .157). The writer and meta can sit on
 * the glow and the logo at once; this keeps the muted text at 4.5:1 there for
 * every theme primary, with margin (0x2B is the edge; JVM-pinned).
 */
internal const val LIT_LOGO_ALPHA = 0x28

/** How far the card has turned away: 0 face up … 1 face down. Drives the floor shadow. */
internal fun turnedAway(degrees: Float): Float =
    ((1.0 - cos(Math.toRadians(degrees.toDouble()))) / 2.0).toFloat()

/** Spotlight's idle drift at [t] seconds: the board's Lissajous path on a [w]-wide wall… */
internal fun lissajousX(t: Float, w: Float): Float = w / 2f + 0.31f * w * sin(0.8f * t)

/** …and on an [h]-tall one. */
internal fun lissajousY(t: Float, h: Float): Float = 0.47f * h + 0.24f * h * sin(0.5f * t)

/**
 * The phone illustration's scale for the height left after the text: 1 at its
 * [full] height, down to 0.5, else 0 — hidden (a short screen or a large font
 * scale). The quote only starts to shrink once the phone is gone.
 */
internal fun phoneScale(available: Float, full: Float): Float {
    val s = (available / full).coerceAtMost(1f)
    return if (s < 0.5f) 0f else s
}

/** "Remove animations" (animator duration scale 0): the Quotes wall holds still. */
internal fun reduceMotion(context: Context): Boolean =
    Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f

/**
 * Where the logo sits in `assets/images/Detoxo_logo.png` — a 1024² RGBA square
 * with a transparent margin — as fractions left, top, right, bottom: the
 * visible logo (alpha ≥ 32) plus a 16 px margin. Pinned against the asset by
 * the JVM test; the Dart preview's `_logoCrop` mirrors it.
 */
internal val LOGO_CROP = floatArrayOf(0.297f, 0.132f, 0.704f, 0.888f)

/**
 * The app logo, decoded once per process from the Flutter assets (the
 * `widget/Manrope.kt` pattern) and cropped to [LOGO_CROP]. Null when the asset
 * is missing or undecodable: the wall then draws no logo — it never fails.
 * Main thread only, like the overlay that asks.
 *
 * ponytail: the first Quotes wall pays the 1024² PNG decode (tens of ms) on the
 * main thread, and the crop stays resident (~1.2 MB). Upgrade path = decode it
 * on the overlay's io executor at service connect, or ship it pre-cropped.
 */
internal object DetoxoLogo {

    private const val TAG = "DetoxoLogo"
    private const val ASSET = "flutter_assets/assets/images/Detoxo_logo.png"

    private var tried = false
    private var bitmap: Bitmap? = null

    fun get(context: Context): Bitmap? {
        if (!tried) {
            tried = true
            bitmap = load(context)
        }
        return bitmap
    }

    private fun load(context: Context): Bitmap? = try {
        context.assets.open(ASSET).use { BitmapFactory.decodeStream(it) }?.let { full ->
            val left = (LOGO_CROP[0] * full.width).roundToInt()
            val top = (LOGO_CROP[1] * full.height).roundToInt()
            val right = (LOGO_CROP[2] * full.width).roundToInt()
            val bottom = (LOGO_CROP[3] * full.height).roundToInt()
            Bitmap.createBitmap(full, left, top, right - left, bottom - top).also {
                if (it !== full) full.recycle()
            }
        }
    } catch (t: Throwable) {
        Log.w(TAG, "logo unreadable: ${t.message}")
        null
    }
}

// ── The view ─────────────────────────────────────────────────────────────────

/**
 * The wall's backdrop, one design per brightness ([dark]):
 * - **Face Down** (light): a centred column whose phone card turns face down
 *   and back on an 8 s loop.
 * - **Spotlight** (dark): a dot grid and a large Detoxo mark that show only
 *   under a soft light, which follows the finger and drifts when idle.
 *
 * Both carry the quote and its writer, then at the foot the "{name} can wait"
 * line and one meta line (the block reason and every stat, joined), above the
 * renderer's button column ([reservedBottom]). The app logo ([DetoxoLogo])
 * sits in the header, on the card's back and — lit only near the light —
 * behind Spotlight. Colours: the flat [Palette] ground and its text colours,
 * the accent (the app theme's primary) for the dots, the glow and the big
 * logo; the white logo takes the accent on the light wall, where white would
 * vanish, and the phone keeps its own colours. [fadeIn] is a newly raised wall: its quote
 * fades up and the writer follows. A rebuild draws them settled.
 *
 * Smooth by construction: layouts, shaders and paths are built on a size,
 * reserve or stats change — never per frame; a frame is a few shader matrices,
 * one camera matrix and draw calls. No `saveLayer`, no clip under the camera
 * and no blur filter (each costs, or is ignored, on the GPU renderer below
 * API 28): every soft edge is a radial gradient.
 *
 * ponytail: the loop redraws every frame for as long as the wall stands.
 * Upgrade path = pause it after a minute without a touch if a battery trace
 * ever shows it.
 */
internal class QuoteWallView(
    context: Context,
    private val copy: WallCopy,
    private val quote: Quote,
    private val palette: Palette,
    private val accent: Int,
    private val dark: Boolean,
    private val fadeIn: Boolean,
) : View(context) {

    /** The button column's laid-out height — the text never draws into it. */
    var reservedBottom: Int = 0
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
    private val animating = !reduceMotion(context)
    private var startMs = 0L
    private var lastFrameMs = 0L

    private val title = if (dark) "" else context.getString(R.string.wall_facedown_title)
    private val line = context.getString(
        if (dark) R.string.wall_spotlight_line else R.string.wall_facedown_line,
        copy.name,
    )
    private val writer = if (dark) quote.writer.uppercase() else quote.writer

    // ── Paints (all built once; sizes are the compact set the preview shares) ──
    private val heavy = Manrope.extraBold(context)
    private val bold = Manrope.bold(context)
    private val wordmark = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = palette.ink
        typeface = if (dark) bold else heavy
        textSize = sp(if (dark) 15f else 16f)
    }
    private val titlePaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = palette.ink
        typeface = heavy
        textSize = sp(24f)
        letterSpacing = -0.02f
    }
    private val quotePaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = palette.ink
        typeface = if (dark) Typeface.SERIF else Typeface.create(Typeface.SERIF, Typeface.ITALIC)
    }
    private val writerPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = palette.muted
        typeface = bold
        textSize = sp(if (dark) 11f else 13f)
        if (dark) letterSpacing = 0.1f
    }
    private val linePaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = palette.muted
        textSize = sp(13f)
    }
    private val metaPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = palette.muted
        textSize = sp(12f)
    }

    // ── Laid-out text ──
    private class Block(val layout: StaticLayout, val x: Float, val y: Float)

    private var blocks: List<Block> = emptyList() // title + the bottom group: drawn as they are
    private var quoteBlock: Block? = null
    private var writerBlock: Block? = null

    // ── The app logo (cropped to its visible mark) ──
    private val logo: Bitmap? = DetoxoLogo.get(context)
    private val logoAspect = logo?.let { it.width.toFloat() / it.height }
        ?: ((LOGO_CROP[2] - LOGO_CROP[0]) / (LOGO_CROP[3] - LOGO_CROP[1]))
    // The logo is white: on the light wall (and the card's light back) it would
    // vanish, so there it takes the theme primary, as the board's coloured logo
    // does. Spotlight keeps it white.
    private val logoPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
        if (!dark) colorFilter = PorterDuffColorFilter(legibleOn(accent, palette.ground, palette.ink), PorterDuff.Mode.SRC_IN)
    }
    private val headerLogo = RectF()
    private var wordX = 0f
    private var wordBaseline = 0f
    private val m = Matrix()
    private val tmp = RectF()

    // ── Face Down: the phone card ──
    private var phoneS = 0f
    private val card = RectF()
    private val frontRim = RectF()
    private val backRim = RectF()
    private var cardR = 0f
    private var cx = 0f
    private var cy = 0f
    private val bars = arrayOf(RectF(), RectF(), RectF())
    private var barR = 0f
    private val bump = RectF()
    private var bumpR = 0f
    private val backLogo = RectF()
    private var shadowY = 0f
    private var shadowRx = 0f
    private var shadowRy = 0f
    private var pinkX = 0f
    private var pinkY = 0f
    private var pinkR = 0f
    private var blueX = 0f
    private var blueY = 0f
    private var blueR = 0f
    private var driftX = 0f
    private var driftY = 0f
    private val camera = Camera()
    private val flipEase = PathInterpolator(0.6f, 0f, 0.3f, 1f)
    private val front = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFF1C1F26.toInt() }
    private val frontEdge = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = 0xFF2A2E37.toInt()
    }
    private val back = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFFF7F8FA.toInt() }
    private val backEdge = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = 0xFFD5DAE3.toInt()
    }
    private val bumpPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFFE3E7EE.toInt() }
    private val barPaints = intArrayOf(0x24, 0x1A, 0x1F).map {
        Paint(Paint.ANTI_ALIAS_FLAG).apply { color = withAlpha(0xFFFFFFFF.toInt(), it) }
    }
    private val pinkShader = unitGlow(withAlpha(0xFFFF5C8A.toInt(), 0xCC))
    private val blueShader = unitGlow(withAlpha(0xFF5C8AFF.toInt(), 0xCC))
    private val shadowShader = unitGlow(0xFF12151B.toInt())
    private val pink = Paint(Paint.ANTI_ALIAS_FLAG)
    private val blue = Paint(Paint.ANTI_ALIAS_FLAG)
    private val shadow = Paint(Paint.ANTI_ALIAS_FLAG)

    // ── Spotlight: the light, the dots and the big mark ──
    private val pitch = dp(16f)
    private val dotSize = dp(1.2f)
    private val dotR = dp(160f)
    private val logoR = dp(180f)
    private val glowR = dp(220f)
    private val dotShader = unitGlow(withAlpha(accent, 0x8C))
    private val logoShader = logo?.let { BitmapShader(it, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP) }
    // Alpha only: the light's falloff, LIT_LOGO_ALPHA at its centre.
    private val logoMask = unitGlow(LIT_LOGO_ALPHA shl 24)
    private val glowShader = unitGlow(withAlpha(accent, GLOW_ALPHA))
    private val dots = Paint(Paint.ANTI_ALIAS_FLAG)

    // The big logo in the accent, as the board hue-shifts its logo to the wall's.
    private val litLogo = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
        colorFilter = PorterDuffColorFilter(accent, PorterDuff.Mode.SRC_IN)
    }
    private val glow = Paint(Paint.ANTI_ALIAS_FLAG)
    private val headerGlow = Paint(Paint.ANTI_ALIAS_FLAG)
    private var headerGlowX = 0f
    private var headerGlowY = 0f
    private var headerGlowR = 0f
    private val bigLogo = RectF()
    private val fadeEase = PathInterpolator(0.25f, 0.1f, 0.25f, 1f)
    private var lightX = -1f
    private var lightY = -1f
    private var fingerX = 0f
    private var fingerY = 0f
    private var touching = false

    init {
        // The board's perspective is 900 dp; Camera units are 72-dpi inches.
        camera.setLocation(0f, 0f, -900f * density / 72f)
        refreshDescription()
    }

    private fun refreshDescription() {
        contentDescription = listOf(copy.headline, title, quote.text, quote.writer, line, copy.reason)
            .plus(copy.stats)
            .plus(extraStats)
            .filter { it.isNotBlank() }
            .joinToString(". ")
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        if (lightX < 0f) {
            lightX = w / 2f
            lightY = if (animating) lissajousY(0f, h.toFloat()) else 0.45f * h
        }
        relayout()
    }

    /** Lays out the column (and the art that sits in it) for the current size and reserve. */
    private fun relayout() {
        val w = width
        val h = height
        if (w == 0 || h == 0) return
        val side = dp(24f)
        val cw = (w - 2 * side).toInt().coerceAtLeast(1)
        val align = if (dark) Layout.Alignment.ALIGN_NORMAL else Layout.Alignment.ALIGN_CENTER
        val top = dp(48f)
        val bottom = h - reservedBottom - dp(12f)
        val gap = dp(if (dark) 16f else 14f)
        val writerGap = dp(if (dark) 12f else 6f)

        // Header: the logo beside the wordmark — centred (Face Down) or leading (Spotlight).
        val logoH = dp(if (dark) 22f else 20f)
        val logoW = if (logo != null) logoH * logoAspect else 0f
        val wordGap = if (logo != null) dp(7f) else 0f
        val fm = wordmark.fontMetrics
        val headerH = max(logoH, fm.descent - fm.ascent)
        val headerW = logoW + wordGap + wordmark.measureText(WORDMARK)
        val hx = if (dark) side else (w - headerW) / 2f
        headerLogo.set(hx, top + (headerH - logoH) / 2f, hx + logoW, top + (headerH + logoH) / 2f)
        wordX = hx + logoW + wordGap
        wordBaseline = top + headerH / 2f - (fm.ascent + fm.descent) / 2f
        if (dark) {
            headerGlowX = hx + logoW / 2f
            headerGlowY = top + headerH / 2f
            headerGlowR = logoH * 1.6f
            headerGlow.shader = RadialGradient(
                headerGlowX, headerGlowY, headerGlowR,
                withAlpha(accent, 0x66), withAlpha(accent, 0), Shader.TileMode.CLAMP,
            )
        }

        // The foot sits on the buttons: the line, then one meta line — the
        // reason and every stat, the late ones included.
        val meta = (listOf(copy.reason) + copy.stats + extraStats).filter { it.isNotBlank() }.joinToString(" · ")
        val bottomLayouts = buildList {
            add(layout(line, linePaint, cw, align))
            if (meta.isNotEmpty()) add(layout(meta, metaPaint, cw, align))
        }
        val lineGap = dp(3f)
        val bottomH = bottomLayouts.sumOf { it.height }.toFloat() + lineGap * (bottomLayouts.size - 1)
        val column = bottom - top - headerH - bottomH

        val titleLayout = if (dark) null else layout(title, titlePaint, cw, align, maxLines = 2)
        val titleH = titleLayout?.height?.toFloat() ?: 0f
        val textFixed = if (dark) 2 * gap else 3 * gap + titleH

        // Fit, in order: the phone 1 → 0.5, then no phone, then the quote
        // shrinks (to 13 sp in Face Down, 14 in Spotlight), then it is cut
        // with an ellipsis.
        var size = if (dark) 24f else 18f
        val minSize = if (dark) 14f else 13f
        var (q, wr) = quoteLayouts(size, cw, align, Int.MAX_VALUE)
        fun quoteH() = q.height + writerGap + wr.height
        val phoneFull = dp(PHONE_BLOCK_DP)
        phoneS = if (dark) 0f else phoneScale(column - textFixed - quoteH(), phoneFull)
        val fixed = textFixed + phoneFull * phoneS
        while (fixed + quoteH() > column && size > minSize) {
            size -= 1f
            val r = quoteLayouts(size, cw, align, Int.MAX_VALUE)
            q = r.first
            wr = r.second
        }
        if (fixed + quoteH() > column && q.lineCount > 1) {
            val perLine = q.height.toFloat() / q.lineCount
            val fit = ((column - fixed - (quoteH() - q.height)) / perLine).toInt().coerceAtLeast(1)
            val r = quoteLayouts(size, cw, align, fit)
            q = r.first
            wr = r.second
        }
        // Still too tall (a landscape wall, or a small one at a big font
        // scale): shed the title, then the writer, rather than run the quote
        // into the foot.
        var spare = column - fixed - quoteH()
        val showTitle = titleLayout != null && spare >= 0f
        if (titleLayout != null && !showTitle) spare += titleH + gap
        val showWriter = spare >= 0f
        val quoteBlockH = if (showWriter) quoteH() else q.height.toFloat()

        // Place, top down.
        val placed = ArrayList<Block>(6)
        var y = top + headerH + gap
        if (phoneS > 0f) {
            layoutPhone(w / 2f, y + dp(14f) * phoneS, phoneS)
            y += phoneFull * phoneS
        }
        if (showTitle && titleLayout != null) {
            placed += Block(titleLayout, side, y)
            y += titleH + gap
        }
        var by = bottom - bottomH
        val regionTop = y
        val regionBottom = by - gap
        val qy = (regionTop + (regionBottom - regionTop - quoteBlockH) / 2f).coerceAtLeast(regionTop)
        quoteBlock = Block(q, side, qy)
        writerBlock = if (showWriter) Block(wr, side, qy + q.height + writerGap) else null
        for (l in bottomLayouts) {
            placed += Block(l, side, by)
            by += l.height + lineGap
        }
        blocks = placed

        if (dark && logo != null && logoShader != null) {
            // The big logo: the board's 240 / 390 of the width, capped at half the height.
            var lw = 0.615f * w
            var lh = lw / logoAspect
            if (lh > 0.5f * h) {
                lh = 0.5f * h
                lw = lh * logoAspect
            }
            bigLogo.set((w - lw) / 2f, 0.21f * h, (w + lw) / 2f, 0.21f * h + lh)
            m.setRectToRect(
                RectF(0f, 0f, logo.width.toFloat(), logo.height.toFloat()),
                bigLogo,
                Matrix.ScaleToFit.FILL,
            )
            logoShader.setLocalMatrix(m)
        }
        invalidate()
    }

    /** The phone card, its face details and its floor shadow, at scale [s] around [x]. */
    private fun layoutPhone(x: Float, top: Float, s: Float) {
        val cw = dp(150f) * s
        val ch = dp(290f) * s
        card.set(x - cw / 2f, top, x + cw / 2f, top + ch)
        cx = card.centerX()
        cy = card.centerY()
        cardR = dp(30f) * s
        frontEdge.strokeWidth = dp(4f) * s
        backEdge.strokeWidth = max(1f, dp(1f) * s)
        frontRim.set(card)
        frontRim.inset(frontEdge.strokeWidth / 2f, frontEdge.strokeWidth / 2f)
        backRim.set(card)
        backRim.inset(backEdge.strokeWidth / 2f, backEdge.strokeWidth / 2f)
        fun at(l: Float, t: Float, r: Float, b: Float, out: RectF) =
            out.set(card.left + dp(l) * s, card.top + dp(t) * s, card.right - dp(r) * s, card.top + dp(b) * s)
        at(14f, 24f, 14f, 58f, bars[0])
        at(14f, 66f, 30f, 100f, bars[1])
        at(14f, 108f, 14f, 142f, bars[2])
        barR = dp(12f) * s
        bump.set(card.left + dp(14f) * s, card.top + dp(14f) * s, card.left + dp(56f) * s, card.top + dp(56f) * s)
        bumpR = dp(12f) * s
        // The logo on the back, as the board draws it: 77 dp tall.
        val lh = dp(77f) * s
        val lw = lh * logoAspect
        backLogo.set(cx - lw / 2f, cy - lh / 2f, cx + lw / 2f, cy + lh / 2f)
        shadowY = card.bottom + dp(19f) * s
        shadowRx = dp(63f) * s
        shadowRy = dp(15f) * s
        // The board's blobs, kept inside the card (no clip may run under the camera).
        pinkX = card.left + dp(55f) * s
        pinkY = card.top + dp(85f) * s
        pinkR = dp(46f) * s
        blueX = card.left + dp(105f) * s
        blueY = card.top + dp(185f) * s
        blueR = dp(34f) * s
        driftX = dp(10f) * s
        driftY = dp(-14f) * s
    }

    override fun onDraw(canvas: Canvas) {
        val now = SystemClock.uptimeMillis()
        if (startMs == 0L) {
            startMs = now
            lastFrameMs = now
        }
        val t = if (animating) (now - startMs) / 1000f else 0f
        val dt = (now - lastFrameMs).toFloat()
        lastFrameMs = now
        canvas.drawColor(palette.ground)
        if (dark) drawSpotlight(canvas, t, dt) else if (phoneS > 0f) drawPhone(canvas, t)
        if (dark) canvas.drawCircle(headerGlowX, headerGlowY, headerGlowR, headerGlow)
        logo?.let { canvas.drawBitmap(it, null, headerLogo, logoPaint) }
        canvas.drawText(WORDMARK, wordX, wordBaseline, wordmark)
        drawText(canvas, t)
        // A Face Down wall whose phone is hidden still runs until its quote has faded up.
        val moving = dark || phoneS > 0f || (fadeIn && t < WRITER_DELAY_S + FADE_S)
        if (animating && moving && isAttachedToWindow) postInvalidateOnAnimation()
    }

    private fun drawPhone(canvas: Canvas, t: Float) {
        val deg = flipDegrees((t % 8f) / 8f, flipEase::getInterpolation)
        val away = turnedAway(deg)
        // The floor shadow does not turn: it narrows and fades as the card lifts away.
        m.setScale(shadowRx * (1f - 0.15f * away), shadowRy)
        m.postTranslate(cx, shadowY)
        shadowShader.setLocalMatrix(m)
        shadow.shader = shadowShader
        shadow.alpha = ((0.35f - 0.13f * away) * 255f).roundToInt()
        tmp.set(cx - shadowRx, shadowY - shadowRy, cx + shadowRx, shadowY + shadowRy)
        canvas.drawOval(tmp, shadow)

        camera.save()
        camera.rotateY(deg)
        camera.getMatrix(m)
        camera.restore()
        m.preTranslate(-cx, -cy)
        m.postTranslate(cx, cy)
        canvas.save()
        canvas.concat(m)
        if (cos(Math.toRadians(deg.toDouble())) < 0.0) {
            canvas.scale(-1f, 1f, cx, cy) // the far side reads the right way round
            canvas.drawRoundRect(card, cardR, cardR, back)
            canvas.drawRoundRect(bump, bumpR, bumpR, bumpPaint)
            logo?.let { canvas.drawBitmap(it, null, backLogo, logoPaint) }
            canvas.drawRoundRect(backRim, cardR, cardR, backEdge)
        } else {
            canvas.drawRoundRect(card, cardR, cardR, front)
            // Two soft blobs drift (10, −14) dp and back over 4 s, half a cycle apart.
            blob(canvas, pinkShader, pink, pinkX, pinkY, pinkR, drift(t))
            blob(canvas, blueShader, blue, blueX, blueY, blueR, drift(t + 2f))
            for (i in bars.indices) canvas.drawRoundRect(bars[i], barR, barR, barPaints[i])
            canvas.drawRoundRect(frontRim, cardR, cardR, frontEdge)
        }
        canvas.restore()
    }

    private fun drift(t: Float): Float = ((1.0 - cos(2.0 * PI * t / 4.0)) / 2.0).toFloat()

    private fun blob(canvas: Canvas, shader: RadialGradient, paint: Paint, x0: Float, y0: Float, r: Float, d: Float) {
        val x = x0 + driftX * d
        val y = y0 + driftY * d
        m.setScale(r, r)
        m.postTranslate(x, y)
        shader.setLocalMatrix(m)
        paint.shader = shader
        canvas.drawCircle(x, y, r, paint)
    }

    private fun drawSpotlight(canvas: Canvas, t: Float, dtMs: Float) {
        val w = width.toFloat()
        val h = height.toFloat()
        val tx = if (touching) fingerX else if (animating) lissajousX(t, w) else lightX
        val ty = if (touching) fingerY else if (animating) lissajousY(t, h) else lightY
        if (animating) {
            // Eased, so a lifted finger glides back onto the idle path.
            val k = 1f - exp(-dtMs.coerceIn(0f, 100f) / 90f)
            lightX += (tx - lightX) * k
            lightY += (ty - lightY) * k
        } else {
            lightX = tx
            lightY = ty
        }
        placeOnLight(glowShader, glowR, glow)
        canvas.drawCircle(lightX, lightY, glowR, glow)
        if (logoShader != null) {
            // The big logo, kept only where the light's falloff has alpha. A
            // fresh ComposeShader each frame: on API 24–25 one built once would
            // keep the mask's old native shader after setLocalMatrix.
            m.setScale(logoR, logoR)
            m.postTranslate(lightX, lightY)
            logoMask.setLocalMatrix(m)
            litLogo.shader = ComposeShader(logoShader, logoMask, PorterDuff.Mode.DST_IN)
            canvas.drawRect(bigLogo, litLogo)
        }
        // Only the grid points the light can reach.
        placeOnLight(dotShader, dotR, dots)
        val half = pitch / 2f
        val i0 = ceil((lightX - dotR - half) / pitch).toInt()
        val i1 = floor((lightX + dotR - half) / pitch).toInt()
        val j0 = ceil((lightY - dotR - half) / pitch).toInt()
        val j1 = floor((lightY + dotR - half) / pitch).toInt()
        val r2 = dotR * dotR
        for (j in j0..j1) {
            val y = j * pitch + half
            val dy = y - lightY
            for (i in i0..i1) {
                val x = i * pitch + half
                val dx = x - lightX
                if (dx * dx + dy * dy <= r2) canvas.drawCircle(x, y, dotSize, dots)
            }
        }
    }

    /** Centres a unit gradient on the light at radius [r]; re-set on the paint (API 24–25 copy it there). */
    private fun placeOnLight(shader: RadialGradient, r: Float, paint: Paint) {
        m.setScale(r, r)
        m.postTranslate(lightX, lightY)
        shader.setLocalMatrix(m)
        paint.shader = shader
    }

    private fun drawText(canvas: Canvas, t: Float) {
        for (i in blocks.indices) draw(canvas, blocks[i], 1f) // no iterator per frame
        // A new wall's quote fades up over 1.2 s; its writer follows 0.3 s later.
        val fading = fadeIn && animating
        val fq = if (fading) fadeEase.getInterpolation((t / FADE_S).coerceIn(0f, 1f)) else 1f
        val fw = if (fading) fadeEase.getInterpolation(((t - WRITER_DELAY_S) / FADE_S).coerceIn(0f, 1f)) else 1f
        quoteBlock?.let { draw(canvas, it, fq) }
        writerBlock?.let { draw(canvas, it, fw) }
    }

    private fun draw(canvas: Canvas, b: Block, alpha: Float) {
        b.layout.paint.alpha = (alpha * 255f).roundToInt()
        canvas.save()
        canvas.translate(b.x, b.y + dp(10f) * (1f - alpha))
        b.layout.draw(canvas)
        canvas.restore()
    }

    @SuppressLint("ClickableViewAccessibility") // steers the decorative light only; every action is a real Button
    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (!dark) return false
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE -> {
                touching = true
                fingerX = event.x
                fingerY = event.y
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> touching = false
        }
        if (!animating) invalidate() // no frame loop to pick the move up
        return true
    }

    private fun quoteLayouts(sizeSp: Float, width: Int, align: Layout.Alignment, maxLines: Int): Pair<StaticLayout, StaticLayout> {
        quotePaint.textSize = sp(sizeSp)
        return layout(quote.text, quotePaint, width, align, maxLines) to layout(writer, writerPaint, width, align, 2)
    }

    private fun layout(
        text: String,
        paint: TextPaint,
        width: Int,
        align: Layout.Alignment,
        maxLines: Int = 3,
    ): StaticLayout =
        StaticLayout.Builder.obtain(text, 0, text.length, paint, width)
            .setAlignment(align)
            .setIncludePad(false)
            .setMaxLines(maxLines)
            .setEllipsize(TextUtils.TruncateAt.END)
            .build()

    /** A radial gradient of [color] fading to clear on a unit circle — placed per draw by its local matrix. */
    private fun unitGlow(color: Int): RadialGradient =
        RadialGradient(0f, 0f, 1f, color, color and 0x00FFFFFF, Shader.TileMode.CLAMP)

    private fun dp(v: Float): Float = v * density

    private fun sp(v: Float): Float =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, v, resources.displayMetrics)

    private companion object {
        const val WORDMARK = "Detoxo"

        /** The phone card's share of the column at full size: 14 above + 290 + 22 below. */
        const val PHONE_BLOCK_DP = 326f

        /** The quote's fade-up (10 dp), and how long the writer waits behind it. */
        const val FADE_S = 1.2f
        const val WRITER_DELAY_S = 0.3f
    }
}
