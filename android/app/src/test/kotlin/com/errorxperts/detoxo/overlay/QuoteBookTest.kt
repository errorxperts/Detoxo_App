package com.errorxperts.detoxo.overlay

import com.errorxperts.detoxo.widget.repoFile
import kotlin.random.Random
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** The Quotes wall's quotes: the real shipped file, and the no-repeat pick. */
class QuoteBookTest {

    private val shipped by lazy {
        QuoteBook.parse(repoFile("assets/content/motivational_quotes.json").readText())
    }

    @Test
    fun theShippedFileHasAHundredUsableQuotes() {
        assertEquals(100, shipped.size)
        assertTrue(shipped.all { it.text.isNotBlank() && it.writer.isNotBlank() })
        // The wall's fit budget: the quote shrinks to 14 sp, then ellipsises.
        assertTrue(shipped.maxOf { it.text.length } <= 220)
        assertTrue(shipped.maxOf { it.writer.length } <= 30)
    }

    @Test
    fun garbageParsesToNothing() {
        assertTrue(QuoteBook.parse("not json").isEmpty())
        assertTrue(QuoteBook.parse("{}").isEmpty())
        assertTrue(QuoteBook.parse("""{"quotes":[{"quote":"  ","writer":"x"},{"writer":"y"}]}""").isEmpty())
    }

    @Test
    fun aQuoteWithoutAWriterStillCounts() {
        assertEquals(listOf(Quote("Breathe.", "")), QuoteBook.parse("""{"quotes":[{"quote":"Breathe."}]}"""))
    }

    @Test
    fun aPickNeverRepeatsTheLastQuote() {
        val r = Random(7)
        var last = -1
        repeat(500) {
            val i = QuoteBook.pick(5, last, r)
            assertTrue(i in 0 until 5)
            assertNotEquals(last, i)
            last = i
        }
    }

    @Test
    fun aFirstPickCanLandAnywhere() {
        val r = Random(1)
        assertEquals((0 until 4).toSet(), (0 until 400).map { QuoteBook.pick(4, -1, r) }.toSet())
    }

    @Test
    fun aSingleQuoteIsAlwaysIndexZero() {
        assertEquals(0, QuoteBook.pick(1, 0, Random(3)))
        assertEquals(0, QuoteBook.pick(1, -1, Random(3)))
    }
}
