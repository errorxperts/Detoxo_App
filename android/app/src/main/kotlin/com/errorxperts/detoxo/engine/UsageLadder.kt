package com.errorxperts.detoxo.engine

/**
 * Native mirror of the counter's usage-reactive visuals.
 *
 * MUST stay byte-identical to the Dart source of truth in
 * `lib/features/content_counter/content_counter_core/domain/usage_ladder.dart`
 * so the bubble, the home widget, and the in-app previews render the same color
 * and emoji at the same count. Both step once per 50 reels and cap at [CAP].
 */
object UsageLadder {

    /** Highest count the ladders resolve; beyond this the darkest stop holds. */
    const val CAP = 500

    /** 11 ARGB stops, one per 50 reels (0..500), green → darkest brown-red. */
    val BAND = intArrayOf(
        0xFF30A46C.toInt(), // 0    success green
        0xFF56B450.toInt(), // 50   light green
        0xFF8FC33A.toInt(), // 100  yellow-green
        0xFFC7C21F.toInt(), // 150  chartreuse
        0xFFF5A623.toInt(), // 200  amber
        0xFFF07C1E.toInt(), // 250  orange
        0xFFE5484D.toInt(), // 300  red
        0xFFC63A3E.toInt(), // 350  deep red
        0xFF9E2B2E.toInt(), // 400  darker red
        0xFF742021.toInt(), // 450  maroon
        0xFF4A1A14.toInt(), // 500+ darkest brown
    )

    /** 11 emoji, one per 50 reels: content → distressed. */
    val EMOJI = arrayOf("😄", "🙂", "😌", "😐", "😕", "😟", "😣", "😖", "😫", "😵", "💀")

    /** Ladder index for [count] — `(count coerced to 0..CAP) / 50`, giving 0..10. */
    fun index(count: Int): Int = count.coerceIn(0, CAP) / 50

    /** The usage band color (ARGB int) for [count]. */
    fun color(count: Int): Int = BAND[index(count)]

    /** The usage mood emoji for [count]. */
    fun emoji(count: Int): String = EMOJI[index(count)]
}
