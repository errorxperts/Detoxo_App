package com.errorxperts.detoxo.widget

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.util.Log
import java.time.Instant
import java.time.ZoneId

/**
 * Turns the widgets over to the new day at local midnight (IM-04): without
 * it they kept showing yesterday as "today" until the first reel. A one-off
 * persisted job, re-armed after each run while a widget is pinned; a push
 * with one pinned and a widget's first update also make sure one is pending.
 *
 * ponytail: Doze can defer it, and a zone change after scheduling moves the
 * day's end without moving the job. The faces compare local days at every
 * render, so any later push draws the Empty day anyway.
 */
class MidnightJobService : JobService() {

    override fun onStartJob(params: JobParameters?): Boolean {
        ReelWidgetSync.push(this, ReelWidgetSync.Reason.MIDNIGHT) {
            jobFinished(params, false)
            // With none pinned the chain stops; the next pin's update re-arms it.
            if (HomeWidgets.pinned(this).isNotEmpty()) schedule(this, replace = true)
        }
        return true // finished from the worker
    }

    override fun onStopJob(params: JobParameters?): Boolean = false

    companion object {
        private const val TAG = "DetoxoMidnight"

        /** 1126 is the watchdog, 1127 its notification. */
        private const val JOB_ID = 1128

        /**
         * Arms the job for the next local midnight. Idempotent unless
         * [replace]: a pending job is left alone — the running one re-arms
         * itself with [replace], since it still counts as pending.
         */
        fun schedule(context: Context, replace: Boolean = false) {
            try {
                val scheduler = context.getSystemService(JobScheduler::class.java) ?: return
                if (!replace && scheduler.getPendingJob(JOB_ID) != null) return
                scheduler.schedule(
                    JobInfo.Builder(JOB_ID, ComponentName(context, MidnightJobService::class.java))
                        .setMinimumLatency(msUntilNextMidnight(System.currentTimeMillis(), ZoneId.systemDefault()))
                        .setPersisted(true) // survives reboot (RECEIVE_BOOT_COMPLETED held)
                        .build(),
                )
            } catch (t: Throwable) {
                Log.w(TAG, "schedule failed: ${t.message}")
            }
        }

        /**
         * Ms from [nowMs] to the next local midnight in [zone] — calendar
         * arithmetic, so a 23 or 25 hour DST day lands on the right instant.
         * Exactly at midnight it is a whole day away. Pure.
         */
        internal fun msUntilNextMidnight(nowMs: Long, zone: ZoneId): Long {
            val next = Instant.ofEpochMilli(nowMs).atZone(zone).toLocalDate().plusDays(1).atStartOfDay(zone)
            return next.toInstant().toEpochMilli() - nowMs
        }
    }
}
