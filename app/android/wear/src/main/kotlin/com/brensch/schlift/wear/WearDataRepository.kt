package com.brensch.schlift.wear

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

    fun updateSnapshot(snapshot: Wearable.WearWorkoutSnapshot) {
        val previous = _snapshot.value
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
