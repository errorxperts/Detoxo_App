package com.errorxperts.detoxo.widget

/**
 * The Plan widget's second source (EVO-073): the engine's own plan, read live from
 * `ConfigStore` by [ReelWidgetSync.plan] at every push and draw — never stored in the
 * IM-02 payload, which stays nine keys. [plan] is the stored wire token verbatim
 * (`BLOCK_ALL` | `CURIOUS`, Conscious's | `ONE_REEL`). Android-free, so the JVM tests
 * build it; mirrored by Dart `PlanState` and `tool/home_widget/ref_model.py`.
 */
data class PlanState(
    val plan: String,
    /** Epoch ms a live Pause ends; 0 or past = no pause. */
    val pauseUntil: Long,
    val reelAllowance: Int,
    val reelsConsumed: Int,
    /** `ConfigStore.masterEnabled`: the "Blocking active" switch. */
    val blockingOn: Boolean,
    /** The accessibility service is running (`DetoxoAccessibilityService.isRunning`). */
    val serviceOn: Boolean,
) {
    companion object {
        /** Block All, on: the picker's, pin dialog's and in-app preview's plan. */
        val DEMO = PlanState("BLOCK_ALL", 0L, 1, 0, blockingOn = true, serviceOn = true)

        /** `ConfigStore.reelAllowance` is 1..this. */
        const val MAX_ALLOWANCE = 20
    }
}
