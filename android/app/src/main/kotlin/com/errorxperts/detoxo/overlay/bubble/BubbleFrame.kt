package com.errorxperts.detoxo.overlay.bubble

import android.graphics.RectF

/**
 * One frame's worth of shell state, handed to every [BubbleFace] draw call. Board numbers
 * are units of the 68-unit square; [x] / [y] / [u] turn them into view px. Twin of the
 * Dart `BubbleFrame`.
 *
 * @property body the (possibly widened) body rect in view px; it grows inward from the docked edge.
 * @property s px per board unit (`size px / 68`).
 * @property look the tier look, already blended between [prevTier] and [tier] by [blend].
 * @property tier the current tier, 0..5.
 * @property prevTier the tier the cross-fade comes from (equals [tier] once settled).
 * @property blend the tier cross-fade, 0 = [prevTier]'s look, 1 = [tier]'s look.
 * @property count today's reel count.
 * @property pct progress to the next colour, 0..100 (100 at tier 5).
 * @property countText the collapsed count string (`152`, `1.2k`).
 * @property clock the timer string (`MM:SS` / `H:MM:SS`).
 * @property shortTime the time pill's text (`BubbleModel.shortTime(seconds)`: `42m`, `1h 5m`).
 * @property expand the timer capsule, 0 = collapsed square, 1 = fully open (may overshoot past 1).
 * @property pop the count pop's progress, 0 = at rest / not started, 1 = finished (scale 1 → 1.18 → 1).
 * @property pulse the milestone ring's progress, 0 = none, 0..1 = ring growing and fading out.
 * @property pill the time pill's visibility, 0 = folded away, 1 = fully shown.
 * @property loopT the style loop's phase, 0..1 over the face's `loopPeriodMs` (0 when not looping).
 * @property open whether the timer is open (the target of [expand]).
 * @property dockedRight whether the bubble sits on the right edge (the capsule grows leftwards).
 */
internal class BubbleFrame(
    val body: RectF,
    val s: Float,
    val look: BubbleLook,
    val tier: Int,
    val prevTier: Int,
    val blend: Float,
    val count: Int,
    val pct: Int,
    val countText: String,
    val clock: String,
    val shortTime: String,
    val expand: Float,
    val pop: Float,
    val pulse: Float,
    val pill: Float,
    val loopT: Float,
    val open: Boolean,
    val dockedRight: Boolean,
) {
    /** Board x → view px. */
    fun x(bx: Float): Float = body.left + bx * s

    /** Board y → view px. */
    fun y(by: Float): Float = body.top + by * s

    /** Board length → px. */
    fun u(v: Float): Float = v * s
}
