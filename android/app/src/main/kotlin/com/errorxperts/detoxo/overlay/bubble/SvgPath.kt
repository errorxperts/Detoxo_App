package com.errorxperts.detoxo.overlay.bubble

import android.graphics.Path

/**
 * A tiny SVG path-data parser for the bubble marks. Grammar: commands
 * `M m L l H h V v Q q C c Z z`; numbers split by whitespace or commas, and a
 * `-` glued to the previous number starts a new one (`q0 8-8 8`). A command
 * repeats while numbers remain (`M1 1 2 2` is `M` then an implicit `L`; after
 * `m` the repeats are `l`). Any other command letter (arcs, `S`, `T`) throws
 * [IllegalArgumentException].
 */
internal object SvgPath {
    data class Cmd(val op: Char, val args: FloatArray)

    private val TOKEN = Regex("[A-Za-z]|-?\\d*\\.?\\d+")

    private fun arity(op: Char): Int = when (op) {
        'M', 'm', 'L', 'l' -> 2
        'H', 'h', 'V', 'v' -> 1
        'Q', 'q' -> 4
        'C', 'c' -> 6
        'Z', 'z' -> 0
        else -> throw IllegalArgumentException("Unsupported SVG path command '$op'")
    }

    fun commands(d: String): List<Cmd> {
        val out = ArrayList<Cmd>()
        var op = ' '
        var nums = ArrayList<Float>()
        fun flush() {
            if (op == ' ') {
                require(nums.isEmpty()) { "SVG path data must start with a command" }
                return
            }
            val n = arity(op)
            if (n == 0) {
                require(nums.isEmpty()) { "Unexpected numbers after '$op'" }
                out += Cmd(op, FloatArray(0))
            } else {
                require(nums.isNotEmpty() && nums.size % n == 0) { "Bad argument count for '$op'" }
                for (i in nums.indices step n) {
                    val o = if (i == 0) op else when (op) { 'M' -> 'L'; 'm' -> 'l'; else -> op }
                    out += Cmd(o, FloatArray(n) { nums[i + it] })
                }
            }
            nums = ArrayList()
        }
        for (m in TOKEN.findAll(d)) {
            val t = m.value
            if (t[0].isLetter()) {
                flush()
                arity(t[0]) // throws on an unknown letter
                op = t[0]
            } else {
                nums += t.toFloat()
            }
        }
        flush()
        return out
    }

    fun path(d: String): Path {
        val p = Path()
        var x = 0f
        var y = 0f
        var sx = 0f
        var sy = 0f
        for ((op, a) in commands(d)) {
            val rel = op.isLowerCase()
            val ox = if (rel) x else 0f
            val oy = if (rel) y else 0f
            when (op.uppercaseChar()) {
                'M' -> { x = ox + a[0]; y = oy + a[1]; sx = x; sy = y; p.moveTo(x, y) }
                'L' -> { x = ox + a[0]; y = oy + a[1]; p.lineTo(x, y) }
                'H' -> { x = ox + a[0]; p.lineTo(x, y) }
                'V' -> { y = oy + a[0]; p.lineTo(x, y) }
                'Q' -> { p.quadTo(ox + a[0], oy + a[1], ox + a[2], oy + a[3]); x = ox + a[2]; y = oy + a[3] }
                'C' -> {
                    p.cubicTo(ox + a[0], oy + a[1], ox + a[2], oy + a[3], ox + a[4], oy + a[5])
                    x = ox + a[4]; y = oy + a[5]
                }
                'Z' -> { p.close(); x = sx; y = sy }
            }
        }
        return p
    }
}
