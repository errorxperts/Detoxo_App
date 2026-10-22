package com.errorxperts.detoxo.overlay

import android.animation.Animator
import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.animation.StateListAnimator
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Rect
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.InsetDrawable
import android.graphics.drawable.StateListDrawable
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.animation.PathInterpolator
import android.widget.Button
import android.widget.ImageButton
import android.widget.ImageView
import com.errorxperts.detoxo.R
import com.errorxperts.detoxo.widget.Manrope
import com.errorxperts.detoxo.widget.withAlpha
import kotlin.math.roundToInt

/**
 * The wall's controls in the app's Frozen Glass button language, drawn
 * natively because the wall is not a Flutter surface:
 * - [primary] is the accent pill (spec `.dx-pill`): the
 *   [accent] at k-pill under the pill-hi → pill-lo sheen, the pill edge and
 *   an accent glow, its label in ink;
 * - [home] is a 44 glass circle (`GlassIconButton`), the house glyph in ink;
 * - [text] is a calm ink-2 label (`SecondaryButton`): no fill, no ripple;
 * - [chip] is an option chip: fill-quiet, or the solid option base with a
 *   check once [select]ed.
 *
 * Every control is a 48 dp tall view (the app's tap floor) with its visual
 * inset inside it. A press grows glass to 1.06 and presses the rest to .975
 * over `AppPressable`'s 400 ms spring; under "Remove animations" nothing
 * scales. Each is a real button, so TalkBack gets one focusable target per
 * action.
 */
internal class WallButtons(
    private val context: Context,
    private val theme: DxTheme,
    private val accent: Int,
) {
    private val density = context.resources.displayMetrics.density
    private val bold = Manrope.bold(context)
    private val still = reduceMotion(context)

    /** Open Detoxo: the 44 dp accent pill in the flexible slot. */
    fun primary(text: String, onClick: () -> Unit): Button = label(text, theme.ink, PRESSED, onClick).apply {
        background = DxDrawable(
            fill = theme.pill,
            radiusPx = dp(DxTokens.RADIUS_PILL).toFloat(),
            shadows = theme.pillShadows(accent),
            density = density,
            base = withAlpha(accent, (theme.kPill * 255f).roundToInt()),
            inset = Rect(0, dp(2f), 0, dp(2f)),
        )
        setPadding(dp(16f), 0, dp(20f), 0)
    }

    /** Home: the house glyph at 20 dp in a 44 dp glass circle. */
    fun home(onClick: () -> Unit): ImageButton = ImageButton(context).apply {
        setImageResource(R.drawable.ic_wall_home)
        imageTintList = ColorStateList.valueOf(theme.ink)
        scaleType = ImageView.ScaleType.FIT_CENTER
        contentDescription = context.getString(R.string.wall_go_home)
        val v = dp(2f)
        background = DxDrawable(
            fill = theme.glass,
            radiusPx = dp(DxTokens.RADIUS_PILL).toFloat(),
            shadows = theme.shadowGlass,
            density = density,
            inset = Rect(v, v, v, v),
        )
        setPadding(dp(14f), dp(14f), dp(14f), dp(14f))
        pressable(this, GLASS_PRESSED, onClick)
    }

    /** Back / Allow: a calm label, text only. */
    fun text(text: String, onClick: () -> Unit): Button = label(text, theme.ink2, PRESSED, onClick).apply {
        background = null
        setPadding(dp(16f), 0, dp(16f), 0)
    }

    /** A duration chip: a 36 dp pill, fill-quiet, or the option base once selected. */
    fun chip(text: String, onClick: () -> Unit): Button = label(text, theme.ink2, PRESSED, onClick).apply {
        background = StateListDrawable().apply {
            addState(intArrayOf(android.R.attr.state_selected), pill(theme.optionBase))
            addState(intArrayOf(), pill(theme.fillQuiet))
        }
        setTextColor(
            ColorStateList(
                arrayOf(intArrayOf(android.R.attr.state_selected), intArrayOf()),
                intArrayOf(theme.ink, theme.ink2),
            ),
        )
        compoundDrawablePadding = dp(CHECK_GAP)
        setPadding(dp(4f), 0, dp(4f), 0)
    }

    /** Marks [chip] picked or not: the option base, a 16 dp check and ink. */
    fun select(chip: Button, on: Boolean) {
        chip.isSelected = on
        val check = if (on) {
            context.getDrawable(R.drawable.ic_dx_check)?.mutate()?.apply {
                setTint(theme.ink)
                setBounds(0, 0, dp(CHECK), dp(CHECK))
            }
        } else {
            null
        }
        chip.setCompoundDrawablesRelative(check, null, null, null)
    }

    /** The width a selected chip's check takes beside its label. */
    fun checkRoom(): Int = dp(CHECK) + dp(CHECK_GAP)

    /** One line of Manrope Bold at `label` size, centred and ellipsised: a 48 dp control has no room for a second. */
    private fun label(text: String, color: Int, pressed: Float, onClick: () -> Unit): Button = Button(context).apply {
        this.text = text
        contentDescription = text
        isAllCaps = false
        typeface = bold
        setTextSize(TypedValue.COMPLEX_UNIT_SP, DxTokens.LABEL_SIZE)
        setTextColor(color)
        gravity = Gravity.CENTER
        maxLines = 1
        ellipsize = TextUtils.TruncateAt.END
        includeFontPadding = false
        pressable(this, pressed, onClick)
    }

    private fun pressable(view: View, pressed: Float, onClick: () -> Unit) {
        view.isFocusable = true
        view.stateListAnimator = if (still) null else press(pressed)
        view.setOnClickListener { onClick() }
    }

    /** A solid 36 dp pill inset 6 dp top and bottom in its 48 dp view. */
    private fun pill(fill: Int) = InsetDrawable(
        GradientDrawable().apply {
            cornerRadius = dp(18f).toFloat()
            setColor(fill)
        },
        0, dp(6f), 0, dp(6f),
    )

    private fun dp(v: Float): Int = (v * density).roundToInt()

    private companion object {
        /** `AppPressable`: cards and pills press to .975, glass grows to 1.06, over `AppDurations.press`. */
        const val PRESSED = 0.975f
        const val GLASS_PRESSED = 1.06f
        const val PRESS_MS = 400L

        const val CHECK = 16f
        const val CHECK_GAP = 4f

        /** A fresh one per view: a StateListAnimator binds to the view it is set on. */
        fun press(scale: Float) = StateListAnimator().apply {
            addState(intArrayOf(android.R.attr.state_pressed), scaleTo(scale))
            addState(intArrayOf(), scaleTo(1f))
        }

        /** `AppCurves.press`: cubic-bezier(.34, 1.56, .64, 1), which overshoots on the way. */
        fun scaleTo(s: Float): Animator = ObjectAnimator.ofPropertyValuesHolder(
            null,
            PropertyValuesHolder.ofFloat(View.SCALE_X, s),
            PropertyValuesHolder.ofFloat(View.SCALE_Y, s),
        ).setDuration(PRESS_MS).apply { interpolator = PathInterpolator(0.34f, 1.56f, 0.64f, 1f) }
    }
}
