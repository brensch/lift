package com.brensch.schlift.wear

import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import workout.v1.Wearable

object WearDataRepository {
    private val _snapshot = MutableStateFlow<Wearable.WearWorkoutSnapshot?>(null)
    val snapshot: StateFlow<Wearable.WearWorkoutSnapshot?> = _snapshot.asStateFlow()

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
        _snapshot.value = snapshot
    }
}
