package com.errorxperts.detoxo.overlay

import android.content.Context
import android.util.Log
import kotlin.random.Random
import org.json.JSONObject

/** One quote on the Quotes wall; [writer] is "" when the source names none. */
internal data class Quote(val text: String, val writer: String)

/**
 * The Quotes wall's quotes: `assets/content/motivational_quotes.json`, read
 * from the Flutter asset bundle (the `widget/Manrope.kt` pattern) once per
 * process, then one per wall at random — never the same one twice in a row.
 * Main thread only, like the overlay that asks.
 *
 * ponytail: the first Quotes wall pays the ~16 KB read + parse on the main
 * thread (a few ms). Upgrade path = warm it on the overlay's io executor at
 * service connect, if a trace ever shows it.
 */
internal object QuoteBook {

    private const val TAG = "QuoteBook"
    private const val ASSET = "flutter_assets/assets/content/motivational_quotes.json"

    /** When the asset is missing or unreadable — the wall never goes blank. */
    val FALLBACK = Quote("Stay focused. The feed can wait.", "")

    private var quotes: List<Quote>? = null
    private var last = -1

    fun next(context: Context, random: Random = Random.Default): Quote {
        val all = quotes ?: load(context).also { quotes = it }
        if (all.isEmpty()) return FALLBACK
        val i = pick(all.size, last, random)
        last = i
        return all[i]
    }

    private fun load(context: Context): List<Quote> = try {
        context.assets.open(ASSET).bufferedReader().use { parse(it.readText()) }
    } catch (t: Throwable) {
        Log.w(TAG, "quotes unreadable: ${t.message}")
        emptyList()
    }

    /** `{quotes: [{quote, writer}]}` → every entry with a quote; garbage → empty. Pure. */
    fun parse(json: String): List<Quote> = try {
        val arr = JSONObject(json).optJSONArray("quotes")
        val out = ArrayList<Quote>(arr?.length() ?: 0)
        for (i in 0 until (arr?.length() ?: 0)) {
            val o = arr?.optJSONObject(i) ?: continue
            val text = o.optString("quote").trim()
            if (text.isNotEmpty()) out += Quote(text, o.optString("writer").trim())
        }
        out
    } catch (_: Throwable) {
        emptyList()
    }

    /** A random index in `0 until size`, never [last] when there is a choice. Pure. */
    fun pick(size: Int, last: Int, random: Random): Int = when {
        size <= 1 -> 0
        last !in 0 until size -> random.nextInt(size)
        else -> random.nextInt(size - 1).let { if (it >= last) it + 1 else it }
    }
}
