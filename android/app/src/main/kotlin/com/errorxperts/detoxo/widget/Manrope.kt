package com.errorxperts.detoxo.widget

import android.content.Context
import android.graphics.Typeface
import android.util.Log

/**
 * Manrope 700 / 800 from the Flutter assets, loaded once per process and
 * shared by the home widget and the bubble. A race only loads a face twice;
 * both results are equal.
 */
internal object Manrope {
    private const val TAG = "Manrope"

    @Volatile private var bold: Typeface? = null
    @Volatile private var extraBold: Typeface? = null

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
