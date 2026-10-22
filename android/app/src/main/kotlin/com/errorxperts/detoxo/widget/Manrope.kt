package com.errorxperts.detoxo.widget

import android.content.Context
import android.graphics.Typeface
import android.util.Log

/**
 * Manrope 600 / 700 / 800 from the Flutter assets, loaded once per process and
 * shared by the home widget, the bubble and the block screen. A race only loads
 * a face twice; both results are equal.
 */
internal object Manrope {
    private const val TAG = "Manrope"

    @Volatile private var semiBold: Typeface? = null
    @Volatile private var bold: Typeface? = null
    @Volatile private var extraBold: Typeface? = null

    fun semiBold(context: Context): Typeface =
        semiBold ?: load(context, "Manrope-SemiBold.ttf").also { semiBold = it }

    fun bold(context: Context): Typeface =
        bold ?: load(context, "Manrope-Bold.ttf").also { bold = it }

    fun extraBold(context: Context): Typeface =
        extraBold ?: load(context, "Manrope-ExtraBold.ttf").also { extraBold = it }

    private fun load(context: Context, file: String): Typeface = try {
        Typeface.createFromAsset(context.assets, "flutter_assets/assets/fonts/$file")
    } catch (e: RuntimeException) {
        // createFromAsset throws when the asset is missing; draw in the system bold instead.
        Log.w(TAG, "Manrope $file unavailable, using the system bold", e)
        Typeface.DEFAULT_BOLD
    }
}
