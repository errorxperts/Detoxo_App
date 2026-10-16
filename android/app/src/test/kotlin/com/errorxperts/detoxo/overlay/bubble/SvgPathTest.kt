package com.errorxperts.detoxo.overlay.bubble

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class SvgPathTest {
    @Test
    fun `glued negatives tokenize`() {
        val cmds = SvgPath.commands("M1 1 q0 8-8 8z")
        assertEquals(listOf('M', 'q', 'z'), cmds.map { it.op })
        assertEquals(listOf(1f, 1f), cmds[0].args.toList())
        assertEquals(listOf(0f, 8f, -8f, 8f), cmds[1].args.toList())
    }

    @Test
    fun `implicit repeats become L`() {
        val cmds = SvgPath.commands("M1 1 2 2 l3 3 4 4")
        assertEquals(listOf('M', 'L', 'l', 'l'), cmds.map { it.op })
        assertEquals(listOf(2f, 2f), cmds[1].args.toList())
    }

    @Test
    fun `the mark parses to 20 commands`() {
        val mark = "M9 3 H31 Q37 3 37 9 V17 Q37 23 30 29 L27 32 L30 35 Q37 41 37 47 V55 " +
            "Q37 61 31 61 H9 Q3 61 3 55 V47 Q3 41 10 35 L13 32 L10 29 Q3 23 3 17 V9 Q3 3 9 3 Z"
        val cmds = SvgPath.commands(mark)
        assertEquals(20, cmds.size)
        assertEquals('M', cmds.first().op)
        assertEquals(listOf(9f, 3f), cmds.first().args.toList())
        assertEquals('Z', cmds.last().op)
    }

    @Test
    fun `unknown command throws`() {
        assertThrows(IllegalArgumentException::class.java) {
            SvgPath.commands("M0 0 A1 1 0 0 1 2 2")
        }
    }
}
