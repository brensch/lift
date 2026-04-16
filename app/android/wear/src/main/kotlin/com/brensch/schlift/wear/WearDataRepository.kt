package com.brensch.schlift.wear

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.os.SystemClock
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import workout.v1.Wearable

object WearDataRepository {
    private const val REST_COMPLETION_CATCH_UP_WINDOW_MS = 15_000L

    private val _snapshot = MutableStateFlow<Wearable.WearWorkoutSnapshot?>(null)
    val snapshot: StateFlow<Wearable.WearWorkoutSnapshot?> = _snapshot.asStateFlow()
    private val _latestBpm = MutableStateFlow<Float?>(null)
    val latestBpm: StateFlow<Float?> = _latestBpm.asStateFlow()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    @Volatile
    private var lastSnapshotReceivedElapsedRealtimeMs: Long = 0L
    @Volatile
    private var lastSnapshotEmittedAtUnixMs: Long = 0L
    @Volatile
    private var scheduledRestCompletionForRestUntilUnix: Long = 0L
    @Volatile
    private var lastHapticForRestUntilUnix: Long = 0L
    private var restCompletionJob: kotlinx.coroutines.Job? = null

    fun updateSnapshot(context: Context, snapshot: Wearable.WearWorkoutSnapshot) {
        val previous = _snapshot.value
        // Drop-stale guard: out-of-order sends from the phone (unawaited
        // publishSnapshot + last-writer-wins native cache) could clobber newer
        // state with an older snapshot. `emittedAt` is monotonic per workout.
        val incomingEmittedAt = snapshot.emittedAt.toLong()
        if (previous != null &&
            previous.workoutId == snapshot.workoutId &&
            incomingEmittedAt > 0L &&
            incomingEmittedAt < previous.emittedAt.toLong()
        ) {
            return
        }
        if (previous == null ||
            previous.workoutId != snapshot.workoutId ||
            previous.state != snapshot.state ||
            previous.actionsList.size != snapshot.actionsList.size ||
            previous.youCard.stateLabel != snapshot.youCard.stateLabel ||
            previous.youCard.timerText != snapshot.youCard.timerText
        ) {
            Log.d(
                "SchliftWear",
                "Snapshot update workoutId=${snapshot.workoutId} state=${snapshot.state} " +
                    "actions=${snapshot.actionsList.size} stateLabel=${snapshot.youCard.stateLabel} " +
                    "timer=${snapshot.youCard.timerText}",
            )
        }
        lastSnapshotReceivedElapsedRealtimeMs = SystemClock.elapsedRealtime()
        lastSnapshotEmittedAtUnixMs = snapshot.emittedAt.toLong()
        _snapshot.value = snapshot
        reconcileRestCompletionAlert(context, snapshot)
    }

    private fun reconcileRestCompletionAlert(
        context: Context,
        snapshot: Wearable.WearWorkoutSnapshot,
    ) {
        if (snapshot.state == workout.v1.WorkoutOuterClass.WorkoutState.WORKOUT_STATE_RESTING &&
            snapshot.restUntil.toLong() > 0L
        ) {
            scheduleRestCompletionAlert(context.applicationContext, snapshot.restUntil.toLong())
            return
        }

        if (snapshot.lastRestEnd.toLong() > 0L) {
            maybeCatchUpRestCompletionAlert(
                context = context.applicationContext,
                restUntilUnix = snapshot.lastRestEnd.toLong(),
            )
        }
        cancelRestCompletionAlert()
    }

    private fun scheduleRestCompletionAlert(context: Context, restUntilUnix: Long) {
        if (restUntilUnix <= 0L) {
            cancelRestCompletionAlert()
            return
        }
        if (restUntilUnix == lastHapticForRestUntilUnix) {
            cancelRestCompletionAlert()
            return
        }

        val nowMs = synchronizedNowUnixMillis()
        val restUntilMs = restUntilUnix * 1000L
        if (nowMs >= restUntilMs) {
            maybeCatchUpRestCompletionAlert(context, restUntilUnix)
            cancelRestCompletionAlert()
            return
        }

        if (restUntilUnix == scheduledRestCompletionForRestUntilUnix && restCompletionJob?.isActive == true) {
            return
        }

        restCompletionJob?.cancel()
        scheduledRestCompletionForRestUntilUnix = restUntilUnix
        restCompletionJob = scope.launch {
            val delayMs = (restUntilMs - synchronizedNowUnixMillis()).coerceAtLeast(0L)
            if (delayMs > 0L) {
                delay(delayMs)
            }
            fireRestCompletionAlert(context, restUntilUnix)
        }
    }

    private fun maybeCatchUpRestCompletionAlert(context: Context, restUntilUnix: Long) {
        if (restUntilUnix <= 0L || restUntilUnix == lastHapticForRestUntilUnix) return
        val nowMs = synchronizedNowUnixMillis()
        val restUntilMs = restUntilUnix * 1000L
        if (nowMs < restUntilMs) return
        if (nowMs - restUntilMs > REST_COMPLETION_CATCH_UP_WINDOW_MS) return
        fireRestCompletionAlert(context, restUntilUnix)
    }

    private fun fireRestCompletionAlert(context: Context, restUntilUnix: Long) {
        if (restUntilUnix <= 0L || restUntilUnix == lastHapticForRestUntilUnix) return
        restCompletionJob?.cancel()
        restCompletionJob = null
        scheduledRestCompletionForRestUntilUnix = 0L
        lastHapticForRestUntilUnix = restUntilUnix
        playRestFinishedHaptic(context)
    }

    private fun cancelRestCompletionAlert() {
        restCompletionJob?.cancel()
        restCompletionJob = null
        scheduledRestCompletionForRestUntilUnix = 0L
    }

    private fun playRestFinishedHaptic(context: Context) {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = context.getSystemService(VibratorManager::class.java)
            manager?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
        if (vibrator?.hasVibrator() != true) return

        val pattern = longArrayOf(0L, 120L, 180L, 120L, 180L, 120L, 180L, 120L, 180L, 120L)
        val effect = VibrationEffect.createWaveform(pattern, -1)
        vibrator.vibrate(effect)
    }

    fun updateLatestBpm(bpm: Float?) {
        _latestBpm.value = bpm
    }

    fun synchronizedNowUnixMillis(): Long {
        val emittedAt = lastSnapshotEmittedAtUnixMs
        val receivedAt = lastSnapshotReceivedElapsedRealtimeMs
        if (emittedAt <= 0L || receivedAt <= 0L) {
            return System.currentTimeMillis()
        }
        val deltaMs = SystemClock.elapsedRealtime() - receivedAt
        return emittedAt + deltaMs
    }

    fun secondsSinceLastSnapshot(): Long {
        val receivedAt = lastSnapshotReceivedElapsedRealtimeMs
        if (receivedAt <= 0L) return 0L
        return (SystemClock.elapsedRealtime() - receivedAt) / 1000
    }
}
