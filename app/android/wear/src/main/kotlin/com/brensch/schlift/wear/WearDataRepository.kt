package com.brensch.schlift.wear

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.os.SystemClock
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import workout.v1.Wearable

object WearDataRepository {
    private val _snapshot = MutableStateFlow<Wearable.WearWorkoutSnapshot?>(null)
    val snapshot: StateFlow<Wearable.WearWorkoutSnapshot?> = _snapshot.asStateFlow()
    private val _latestBpm = MutableStateFlow<Float?>(null)
    val latestBpm: StateFlow<Float?> = _latestBpm.asStateFlow()
    @Volatile
    private var lastSnapshotReceivedElapsedRealtimeMs: Long = 0L
    @Volatile
    private var lastSnapshotEmittedAtUnixMs: Long = 0L

    fun updateSnapshot(context: Context, snapshot: Wearable.WearWorkoutSnapshot) {
        val previous = _snapshot.value
        if (shouldPlayRestFinishedHaptic(previous, snapshot)) {
            playRestFinishedHaptic(context)
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
    }

    private fun shouldPlayRestFinishedHaptic(
        previous: Wearable.WearWorkoutSnapshot?,
        current: Wearable.WearWorkoutSnapshot,
    ): Boolean {
        if (previous == null) return false
        val previousRestUntil = previous.restUntil.toLong()
        if (previousRestUntil <= 0L) return false
        val previousWasActiveCountdown =
            previous.state == workout.v1.WorkoutOuterClass.WorkoutState.WORKOUT_STATE_RESTING &&
                previous.youCard.stateLabel == "Resting"
        if (!previousWasActiveCountdown) return false
        if (current.youCard.stateLabel != "Yapping") return false

        val currentRestEnd = when {
            current.lastRestEnd.toLong() > 0L -> current.lastRestEnd.toLong()
            current.restUntil.toLong() > 0L -> current.restUntil.toLong()
            else -> 0L
        }
        return currentRestEnd == previousRestUntil
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
