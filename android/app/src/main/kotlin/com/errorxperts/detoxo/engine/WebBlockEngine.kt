package com.errorxperts.detoxo.engine

import android.content.Context
import org.json.JSONArray
import java.util.zip.GZIPInputStream

/**
 * Matches a browser URL host against the user's website blocklist and, when
 * enabled, a bundled set of adult domains.
 *
 * The user/derived blocklist is a tiny JSON list pushed from Dart and held in
 * memory. The adult set is a large bundled asset (`adult_domains.txt.gz`) loaded
 * lazily only while the toggle is on, and freed when it is turned off so it costs
 * no heap otherwise. All matching is host-based — Android accessibility can read
 * the address bar but cannot see network traffic.
 */
class WebBlockEngine(private val context: Context) {

    private data class Rule(val pattern: String, val type: String)

    @Volatile private var rules: List<Rule> = emptyList()
    @Volatile private var adultEnabled = false
    @Volatile private var adultSet: HashSet<String>? = null

    /** Replace the active blocklist from the pushed JSON `[{pattern,matchType}]`. */
    fun setBlocklist(json: String?) {
        rules = parse(json)
    }

    /** Toggle the adult set, loading/freeing the bundled asset accordingly. */
    fun setAdultEnabled(on: Boolean) {
        adultEnabled = on
        adultSet = if (on) (adultSet ?: loadAdultSet()) else null
    }

    /** Whether anything is configured — guards the accessibility hot path. */
    fun hasAnyRules(): Boolean =
        rules.isNotEmpty() || (adultEnabled && (adultSet?.isNotEmpty() == true))

    /** True if [host] (already normalized) is blocked. */
    fun matchHost(host: String, fullUrl: String? = null): Boolean {
        if (host.isEmpty()) return false
        for (r in rules) {
            val hit = when (r.type) {
                "EXACT" -> fullUrl != null && fullUrl == r.pattern
                "WILDCARD" -> wildcardMatch(host, r.pattern)
                else -> host == r.pattern || host.endsWith("." + r.pattern)
            }
            if (hit) return true
        }
        val set = adultSet
        if (adultEnabled && set != null) {
            // Walk the host up its parent labels: foo.bar.example.com → example.com.
            var h = host
            while (true) {
                if (set.contains(h)) return true
                val dot = h.indexOf('.')
                if (dot < 0) break
                h = h.substring(dot + 1)
            }
        }
        return false
    }

    private fun parse(json: String?): List<Rule> {
        if (json.isNullOrBlank()) return emptyList()
        return try {
            val arr = JSONArray(json)
            val out = ArrayList<Rule>(arr.length())
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                val pattern = o.optString("pattern").trim().lowercase()
                if (pattern.isEmpty()) continue
                out.add(Rule(pattern, o.optString("matchType", "DOMAIN")))
            }
            out
        } catch (_: Throwable) {
            emptyList()
        }
    }

    /** Translate a glob (`*` = any run) to an anchored regex over the host. */
    private fun wildcardMatch(host: String, pattern: String): Boolean {
        val sb = StringBuilder("^")
        for (c in pattern) {
            when {
                c == '*' -> sb.append(".*")
                c.isLetterOrDigit() -> sb.append(c)
                else -> sb.append('\\').append(c)
            }
        }
        sb.append('$')
        return try {
            Regex(sb.toString()).matches(host)
        } catch (_: Throwable) {
            false
        }
    }

    private fun loadAdultSet(): HashSet<String> {
        val out = HashSet<String>(4096)
        try {
            context.assets.open(ADULT_ASSET).use { raw ->
                GZIPInputStream(raw).bufferedReader().forEachLine { line ->
                    val s = line.trim()
                    if (s.isNotEmpty() && !s.startsWith("#")) out.add(s.lowercase())
                }
            }
        } catch (_: Throwable) {
            // Asset missing / unreadable → empty set (adult blocking simply no-ops).
        }
        return out
    }

    private companion object {
        const val ADULT_ASSET = "adult_domains.txt.gz"
    }
}
