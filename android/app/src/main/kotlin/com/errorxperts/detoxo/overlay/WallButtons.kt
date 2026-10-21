package com.errorxperts.detoxo.overlay

import android.animation.Animator
import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.animation.StateListAnimator
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.LinearGradient
import android.graphics.Outline
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.SweepGradient
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.InsetDrawable
import android.graphics.drawable.LayerDrawable
import android.graphics.drawable.RippleDrawable
import android.os.Build
import android.text.TextUtils
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.ImageButton
import android.widget.ImageView
import androidx.core.graphics.ColorUtils
import com.errorxperts.detoxo.R
import com.errorxperts.detoxo.widget.Manrope
import com.errorxperts.detoxo.widget.blend
import com.errorxperts.detoxo.widget.withAlpha
import kotlin.math.roundToInt

/**
 * The wall's controls in the app's own button language (`buttons.dart`), drawn
 * natively because the wall is not a Flutter surface:
 * - [primary] is `LiquidPill`, the one filled-brand control;
 * - [home] and [chip] are `SecondaryButton`'s outlined brand;
 * - [ghost] is `GhostButton`, text only.
 *
 * Every control is a 48 dp tall view (the app's tap floor) with its visual
 * inset inside it, the native `AppPressable.minTapTarget`, and squishes to 0.96
 * while pressed over AppPressable's 90 ms. Each is a real button, so TalkBack
 * gets one focusable target per action, and each ripple is masked to its
 * visual. The outlined glyph and the text labels take the accent made legible
 * on what they sit on ([legibleOn]): the ground, or a chip's own tinted fill.
 */
internal class WallButtons(
    private val context: Context,
    palette: Palette,
    private val accent: Int,
    private val dark: Boolean,
) {
    private val density = context.resources.displayMetrics.density
    private val bold = Manrope.bold(context)
    private val tint = legibleOn(accent, palette.ground, palette.ink)
    private val chipTint = legibleOn(accent, outlinedFill(accent, palette.ground), palette.ink)
    private val ripple = ColorStateList.valueOf(withAlpha(palette.ink, 0x29)) // ink α .16

    /** Open Detoxo: a 44 dp `LiquidPill` in the flexible slot, floating on a 6 dp shadow of its own colour. */
    fun primary(text: String, onClick: () -> Unit): Button {
        val fill = legibleFill(accent)
        return label(text, 15f, onColorFor(fill), onClick).apply {
            background = ripple(LiquidPill(fill, dark, dp(2f), density), mask(oval = false, v = 2f))
            elevation = 6f * density
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                // The app's coloured glow; below API 28 the shadow stays black.
                outlineSpotShadowColor = fill
                outlineAmbientShadowColor = fill
            }
            setPadding(dp(20f), 0, dp(20f), 0)
        }
    }

    /** Home: the house glyph at 20 dp in a 44 dp outlined brand circle. */
    fun home(onClick: () -> Unit): ImageButton = ImageButton(context).apply {
        setImageResource(R.drawable.ic_wall_home)
        imageTintList = ColorStateList.valueOf(tint)
        scaleType = ImageView.ScaleType.FIT_CENTER
        contentDescription = context.getString(R.string.wall_go_home)
        background = ripple(outlined(oval = true, v = 2f), mask(oval = true, v = 2f))
        setPadding(dp(14f), dp(14f), dp(14f), dp(14f))
        pressable(this, onClick)
    }

    /** Back / Allow: text only, with a pill-shaped ripple. */
    fun ghost(text: String, onClick: () -> Unit): Button = label(text, 14f, tint, onClick).apply {
        background = ripple(null, mask(oval = false, v = 2f))
        setPadding(dp(16f), 0, dp(16f), 0)
    }

    /** A duration chip: a 36 dp outlined brand pill. */
    fun chip(text: String, onClick: () -> Unit): Button = label(text, 13f, chipTint, onClick).apply {
        background = ripple(outlined(oval = false, v = 6f), mask(oval = false, v = 6f))
        setPadding(dp(4f), 0, dp(4f), 0)
    }

    /** One line of Manrope Bold, centred and ellipsised: a 48 dp control has no room for a second. */
    private fun label(text: String, sizeSp: Float, color: Int, onClick: () -> Unit): Button = Button(context).apply {
        this.text = text
        contentDescription = text
        isAllCaps = false
        typeface = bold
        textSize = sizeSp
        setTextColor(color)
        gravity = Gravity.CENTER
        maxLines = 1
        ellipsize = TextUtils.TruncateAt.END
        includeFontPadding = false
        pressable(this, onClick)
    }

    private fun pressable(view: View, onClick: () -> Unit) {
        view.isFocusable = true
        view.stateListAnimator = squish()
        view.setOnClickListener { onClick() }
    }

    /** `SecondaryButton`'s outlined brand: fill α .12, a 1 dp ring α .45. */
    private fun outlined(oval: Boolean, v: Float) = shape(oval, v, withAlpha(accent, OUTLINED_FILL), withAlpha(accent, 0x73))

    /**
     * Built in code, a RippleDrawable nests its layers' padding (only an inflated
     * one stacks it), so an inset content layer would inset the mask a second time.
     */
    private fun ripple(content: Drawable?, mask: Drawable) = RippleDrawable(ripple, content, mask).apply {
        paddingMode = LayerDrawable.PADDING_MODE_STACK
    }

    /** A ripple mask needs full alpha: the ripple keeps only what the mask covers. */
    private fun mask(oval: Boolean, v: Float) = shape(oval, v, 0xFF000000.toInt(), ring = null)

    /** A circle inset [v] dp all round ([oval]), or a pill inset [v] dp top and bottom, in a 48 dp view. */
    private fun shape(oval: Boolean, v: Float, fill: Int, ring: Int?): Drawable {
        val d = GradientDrawable().apply {
            if (oval) shape = GradientDrawable.OVAL else cornerRadius = (24f - v) * density
            setColor(fill)
            if (ring != null) setStroke(dp(1f), ring)
        }
        val side = if (oval) dp(v) else 0
        return InsetDrawable(d, side, dp(v), side, dp(v))
    }

    private fun dp(v: Float): Int = (v * density).roundToInt()

    private companion object {
        /** AppPressable's press: `AppDurations.instant`, to `pressedScale` .96. */
        const val PRESS_MS = 90L
        const val PRESSED_SCALE = 0.96f

        /** A fresh one per view: a StateListAnimator binds to the view it is set on. */
        fun squish() = StateListAnimator().apply {
            addState(intArrayOf(android.R.attr.state_pressed), scaleTo(PRESSED_SCALE))
            addState(intArrayOf(), scaleTo(1f))
        }

        fun scaleTo(s: Float): Animator = ObjectAnimator.ofPropertyValuesHolder(
            null,
            PropertyValuesHolder.ofFloat(View.SCALE_X, s),
            PropertyValuesHolder.ofFloat(View.SCALE_Y, s),
        ).setDuration(PRESS_MS)
    }
}

/** The outlined brand's fill alpha (.12): [outlinedFill] is what a chip's label sits on. */
internal const val OUTLINED_FILL = 0x1F

/** The accent at [OUTLINED_FILL] over [ground], opaque. Pure. */
internal fun outlinedFill(accent: Int, ground: Int): Int = blend(accent, ground, OUTLINED_FILL / 255f)

/**
 * The app's `LiquidPill` as a Drawable, its pill inset [inset] px top and
 * bottom inside the 48 dp view:
 * - the fill, swept top-left to bottom-right from lit (HSL lightness + .09)
 *   through [fill] at .55 to shade (- .13);
 * - the `LiquidGlassBorder` rim, a 1 dp sweep that stays dim but for a key
 *   light at the top-left and a tighter, dimmer bounce at the bottom-right;
 * - its thickness cue, 0.8 dp at 1.2 dp inside the edge, white α .25 fading
 *   out by half height.
 *
 * [getOutline] is the pill, so the view's elevation shadow follows it rather
 * than the 48 dp box. Shaders are built on a bounds change, never per draw.
 */
private class LiquidPill(
    private val fill: Int,
    private val dark: Boolean,
    private val inset: Int,
    private val density: Float,
) : Drawable() {

    private val lit = lightness(fill, 0.09f)
    private val shade = lightness(fill, -0.13f)
    private val body = Paint(Paint.ANTI_ALIAS_FLAG)
    private val rim = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = density
    }
    private val inner = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 0.8f * density
    }
    private val pill = RectF()
    private val innerPill = RectF()

    override fun onBoundsChange(bounds: Rect) {
        pill.set(bounds)
        pill.inset(0f, inset.toFloat())
        innerPill.set(pill)
        innerPill.inset(1.2f * density, 1.2f * density)
        body.shader = LinearGradient(
            pill.left, pill.top, pill.right, pill.bottom,
            intArrayOf(lit, fill, shade), floatArrayOf(0f, 0.55f, 1f), Shader.TileMode.CLAMP,
        )
        // The rim's colours, as LiquidPill hands them to LiquidGlassBorder: key = white α .9,
        // bounce = .55 of it; dim is the glass border token on a dark wall, or on a light one.
        val key = withAlpha(WHITE, 0xE6)
        val bounce = withAlpha(WHITE, 0x7E)
        val dim = if (dark) 0x2EFFFFFF else 0x33101625
        rim.shader = SweepGradient(
            pill.centerX(), pill.centerY(),
            intArrayOf(dim, dim, bounce, dim, dim, key, dim, dim),
            floatArrayOf(0f, 0.07f, 0.125f, 0.18f, 0.52f, 0.625f, 0.73f, 1f),
        )
        inner.shader = LinearGradient(
            0f, pill.top, 0f, pill.centerY(),
            withAlpha(WHITE, 0x40), withAlpha(WHITE, 0), Shader.TileMode.CLAMP,
        )
    }

    override fun draw(canvas: Canvas) {
        val r = pill.height() / 2f
        canvas.drawRoundRect(pill, r, r, body)
        canvas.drawRoundRect(pill, r, r, rim)
        val ri = innerPill.height() / 2f
        canvas.drawRoundRect(innerPill, ri, ri, inner)
    }

    override fun getOutline(outline: Outline) {
        val b = bounds
        outline.setRoundRect(b.left, b.top + inset, b.right, b.bottom - inset, (b.height() - 2 * inset) / 2f)
    }

    override fun setAlpha(alpha: Int) {
        for (p in arrayOf(body, rim, inner)) p.alpha = alpha
        invalidateSelf()
    }

    override fun setColorFilter(colorFilter: ColorFilter?) {
        for (p in arrayOf(body, rim, inner)) p.colorFilter = colorFilter
        invalidateSelf()
    }

    @Deprecated("Deprecated in Java")
    override fun getOpacity(): Int = PixelFormat.TRANSLUCENT

    private companion object {
        const val WHITE = 0xFFFFFFFF.toInt()

        /** [color] with its HSL lightness moved by [delta], as Flutter's `HSLColor` does it. */
        fun lightness(color: Int, delta: Float): Int {
            val hsl = FloatArray(3)
            ColorUtils.colorToHSL(color, hsl)
            hsl[2] = (hsl[2] + delta).coerceIn(0f, 1f)
            return ColorUtils.HSLToColor(hsl)
        }
    }
}
